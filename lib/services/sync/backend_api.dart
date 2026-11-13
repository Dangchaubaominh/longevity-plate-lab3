import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../app_failure.dart';
import '../service_interfaces.dart';

class BackendFailure extends AppFailure {
  const BackendFailure(super.code, {this.status = 0, this.retryable = false});
  final int status;
  final bool retryable;
}

class BackendApi {
  BackendApi({
    required String baseUrl,
    required this.auth,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : base = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       client = client ?? http.Client() {
    final uri = Uri.parse(base);
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' &&
            ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host))) {
      throw const AppFailure('insecure_api_url');
    }
  }
  final String base;
  final AuthService auth;
  final http.Client client;
  final Duration timeout;
  void check(String uid) {
    if (auth.currentUser?.uid != uid) {
      throw const AppFailure('sync_session_changed');
    }
  }

  Future<Map<String, dynamic>> call(
    String uid,
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      check(uid);
      final token = await auth.idToken(forceRefresh: attempt > 0);
      check(uid);
      if (token == null) {
        throw const BackendFailure('unauthenticated', status: 401);
      }
      final request = http.Request(method, Uri.parse('$base/api/v1$path'))
        ..headers['Authorization'] = 'Bearer $token';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      http.Response response;
      try {
        response = await client
            .send(request)
            .then(http.Response.fromStream)
            .timeout(timeout);
      } on TimeoutException {
        throw const BackendFailure('network-timeout', retryable: true);
      } on http.ClientException {
        throw const BackendFailure('network-request-failed', retryable: true);
      }
      check(uid);
      if (response.statusCode == 401 && attempt == 0) continue;
      Map<String, dynamic> data;
      try {
        data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      } catch (_) {
        throw const BackendFailure('invalid_api_response');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = data['error'] as Map?;
        throw BackendFailure(
          error?['code'] as String? ?? 'api_error',
          status: response.statusCode,
          retryable: error?['retryable'] == true,
        );
      }
      return data;
    }
    throw const BackendFailure('unauthenticated', status: 401);
  }

  Future<Map<String, dynamic>> upload(
    String uid, {
    required Uint8List bytes,
    required String kind,
    String? mealId,
    int? mealVersion,
    void Function(double)? onProgress,
  }) async {
    check(uid);
    final hash = sha256.convert(bytes).toString();
    final max = kind == 'photo' ? 5 * 1024 * 1024 : 10 * 1024 * 1024;
    if (bytes.isEmpty || bytes.length > max) {
      throw const AppFailure('photo_too_large');
    }
    final ticket = await call(
      uid,
      '/media/sign',
      method: 'POST',
      body: {
        'kind': kind,
        'contentHash': hash,
        'mealId': ?mealId,
        'mealVersion': ?mealVersion,
      },
    );
    final assetId = ticket['assetId'] as String;
    // Recover safely when Cloudinary accepted an earlier request whose response was lost.
    try {
      final recovered = await call(
        uid,
        '/media/$assetId/reconcile',
        method: 'POST',
        body: {},
      );
      onProgress?.call(1);
      return recovered;
    } on BackendFailure catch (e) {
      if (e.code != 'asset_not_uploaded') rethrow;
    }
    final url = Uri.parse(ticket['uploadUrl'] as String);
    if (url.scheme != 'https' ||
        url.host != 'api.cloudinary.com' ||
        !url.path.endsWith('/image/upload')) {
      throw const AppFailure('invalid_upload_destination');
    }
    final fields = Map<String, dynamic>.from(ticket['fields'] as Map);
    final request = http.MultipartRequest('POST', url)
      ..fields.addAll(fields.map((k, v) => MapEntry(k, '$v')))
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: kind == 'photo' ? 'meal.jpg' : 'report.pdf',
          contentType: MediaType(
            kind == 'photo' ? 'image' : 'application',
            kind == 'photo' ? 'jpeg' : 'pdf',
          ),
        ),
      );
    onProgress?.call(.05);
    http.Response response;
    try {
      response = await client
          .send(
            _ProgressRequest(request, (v) => onProgress?.call(.05 + v * .9)),
          )
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on TimeoutException {
      throw const BackendFailure('network-timeout', retryable: true);
    } on http.ClientException {
      throw const BackendFailure('network-request-failed', retryable: true);
    }
    check(uid);
    if (response.statusCode != 200) {
      throw BackendFailure(
        'cloudinary_${response.statusCode}',
        retryable: response.statusCode >= 500 || response.statusCode == 429,
      );
    }
    // Reconcile always checks provider metadata server-side; no client-supplied size/type is trusted.
    final completed = await call(
      uid,
      '/media/$assetId/reconcile',
      method: 'POST',
      body: {},
    );
    onProgress?.call(1);
    return completed;
  }

  Future<Uint8List> image(String uid, String assetId) async {
    final link = await call(
      uid,
      '/media/$assetId/url',
      method: 'POST',
      body: {},
    );
    check(uid);
    final url = Uri.parse(link['url'] as String);
    if (url.scheme != 'https' || url.host != 'api.cloudinary.com') {
      throw const AppFailure('invalid_download_destination');
    }
    final response = await client
        .send(http.Request('GET', url))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw const BackendFailure('image_download_failed', retryable: true);
    }
    final bytes = BytesBuilder(copy: false);
    var size = 0;
    await for (final chunk in response.stream.timeout(timeout)) {
      size += chunk.length;
      if (size > 5 * 1024 * 1024) throw const AppFailure('photo_too_large');
      bytes.add(chunk);
    }
    check(uid);
    return bytes.takeBytes();
  }
}

class _ProgressRequest extends http.BaseRequest {
  _ProgressRequest(this.inner, this.progress) : super(inner.method, inner.url);
  final http.MultipartRequest inner;
  final void Function(double) progress;
  @override
  http.ByteStream finalize() {
    final stream = inner.finalize();
    headers.addAll(inner.headers);
    contentLength = inner.contentLength;
    super.finalize();
    var sent = 0;
    return http.ByteStream(
      stream.map((bytes) {
        sent += bytes.length;
        progress(sent / inner.contentLength);
        return bytes;
      }),
    );
  }
}
