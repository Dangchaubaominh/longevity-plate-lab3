import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../app_failure.dart';
import '../service_interfaces.dart';

/// Lưu báo cáo PDF trên Cloudinary thay cho Firebase Storage, vì Firebase
/// Storage cần gói Blaze.
///
/// App không giữ khóa bí mật Cloudinary. Server trong thư mục `server/` kiểm tra
/// ID token Firebase, ký lệnh tải lên vào `reports/<uid>/` của chính người đó và
/// chỉ cấp link có hạn dùng cho chủ tệp, tức là giữ vai trò của storage.rules.
class CloudinaryReportStorageService implements ReportStorageService {
  CloudinaryReportStorageService({
    required this._auth,
    required this._faults,
    required String apiBase,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _apiBase = apiBase.replaceAll(RegExp(r'/+$'), ''),
       _client = client ?? http.Client();

  /// Báo cáo của một UID không có thật, dùng để thử truy cập trái phép.
  static const foreignReportId =
      'reports/UidKhacDeKiemThu/meal-report-1700000000000';
  static const _chunkSize = 16 * 1024;

  final AuthService _auth;
  final FaultInjector _faults;
  final String _apiBase;
  final http.Client _client;
  final Duration timeout;

  @override
  Stream<UploadProgress> upload({
    required String uid,
    required String fileName,
    required Uint8List bytes,
  }) {
    final events = StreamController<UploadProgress>();
    unawaited(
      _upload(fileName, bytes, events.add)
          .then(
            (url) => events.add(UploadProgress(1, downloadUrl: url)),
            onError: events.addError,
          )
          .whenComplete(events.close),
    );
    return events.stream;
  }

  Future<String> _upload(
    String fileName,
    Uint8List bytes,
    void Function(UploadProgress) report,
  ) async {
    _faults.check(FaultPoint.uploadReport);
    // Server tự lấy uid từ ID token, không dùng uid do app gửi lên.
    final ticket = await _callApi('reports/sign', {'fileName': fileName});
    report(const UploadProgress(0.05));

    final fields = ticket['fields'] as Map<String, dynamic>;
    final multipart =
        http.MultipartRequest('POST', Uri.parse(ticket['uploadUrl'] as String))
          ..fields.addAll({
            for (final entry in fields.entries) entry.key: '${entry.value}',
          })
          ..files.add(
            http.MultipartFile(
              'file',
              Stream.fromIterable(_chunks(bytes)),
              bytes.length,
              filename: fileName,
              contentType: MediaType('application', 'pdf'),
            ),
          );
    final request = _ProgressRequest(
      multipart,
      (fraction) => report(UploadProgress(0.05 + fraction * 0.9)),
    );
    final response = await _guard(
      () async => http.Response.fromStream(await _client.send(request)),
    );
    if (response.statusCode != 200) {
      final error = _decode(response)['error'];
      throw AppFailure(
        'cloudinary_${response.statusCode}',
        error is Map ? error['message'] as String? : null,
      );
    }

    final link = await _callApi('reports/url', {'publicId': ticket['publicId']});
    return link['url'] as String;
  }

  @override
  Future<String> probeForeignReport() async {
    try {
      await _callApi('reports/url', {'publicId': foreignReportId});
      return 'allowed';
    } on AppFailure catch (e) {
      return e.code;
    }
  }

  Future<Map<String, dynamic>> _callApi(
    String path,
    Map<String, Object?> body,
  ) async {
    if (_apiBase.isEmpty) throw const AppFailure('report_api_not_configured');
    final token = await _auth.idToken();
    if (token == null) throw const AppFailure('unauthenticated');
    final response = await _guard(
      () => _client.post(
        Uri.parse('$_apiBase/$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ),
    );
    final data = _decode(response);
    final error = data['error'] as String?;
    return switch (response.statusCode) {
      200 => data,
      401 => throw AppFailure('unauthenticated', error),
      403 => throw AppFailure('unauthorized', error),
      final status => throw AppFailure('report_api_$status', error),
    };
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run().timeout(timeout);
    } on TimeoutException {
      throw const AppFailure('network-timeout');
    } on http.ClientException catch (e) {
      throw AppFailure('network-request-failed', e.message);
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      return value is Map<String, dynamic> ? value : const {};
    } on FormatException {
      return const {};
    }
  }

  static Iterable<List<int>> _chunks(Uint8List bytes) sync* {
    for (var start = 0; start < bytes.length; start += _chunkSize) {
      yield Uint8List.sublistView(
        bytes,
        start,
        min(start + _chunkSize, bytes.length),
      );
    }
  }
}

/// Đếm số byte http client đã lấy đi để hiện tiến độ tải lên.
class _ProgressRequest extends http.BaseRequest {
  _ProgressRequest(this._inner, this._onProgress)
    : super(_inner.method, _inner.url);

  final http.MultipartRequest _inner;
  final void Function(double fraction) _onProgress;

  @override
  http.ByteStream finalize() {
    final body = _inner.finalize();
    final total = _inner.contentLength;
    headers.addAll(_inner.headers);
    contentLength = total;
    super.finalize();
    var sent = 0;
    return http.ByteStream(
      body.map((chunk) {
        sent += chunk.length;
        _onProgress(sent / total);
        return chunk;
      }),
    );
  }
}
