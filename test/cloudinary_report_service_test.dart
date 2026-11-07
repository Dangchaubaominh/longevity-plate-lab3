import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:longevity_plate/services/app_failure.dart';
import 'package:longevity_plate/services/cloud/cloudinary_report_service.dart';
import 'package:longevity_plate/services/fake_services.dart';
import 'package:longevity_plate/services/service_interfaces.dart';

const _api = 'https://reports.example.test';
const _uploadUrl = 'https://api.cloudinary.com/v1_1/demo/image/upload';
const _publicId = 'reports/uidA/meal-report-1762500000000';
const _fileName = 'meal-report-1762500000000.pdf';

Future<FakeAuthService> _signedIn() async {
  final auth = FakeAuthService();
  await auth.signInWithGoogle();
  return auth;
}

CloudinaryReportStorageService _service(
  MockClient client, {
  required AuthService auth,
  String apiBase = '$_api/',
}) => CloudinaryReportStorageService(
  auth: auth,
  faults: FaultInjector(),
  apiBase: apiBase,
  client: client,
);

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('xin chữ ký, tải lên Cloudinary rồi lấy link có hạn dùng', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url}');
      if (request.url.toString() == '$_api/reports/sign') {
        expect(request.headers['Authorization'], 'Bearer fake-id-token');
        expect(jsonDecode(request.body), {'fileName': _fileName});
        return _json({
          'publicId': _publicId,
          'uploadUrl': _uploadUrl,
          'fields': {
            'public_id': _publicId,
            'type': 'authenticated',
            'timestamp': 1762500000,
            'api_key': '1234',
            'signature': 'sig',
          },
        });
      }
      if (request.url.toString() == _uploadUrl) {
        expect(request.headers['content-type'], startsWith('multipart/form-data'));
        expect(request.body, contains('name="signature"\r\n\r\nsig'));
        expect(request.body, contains('name="timestamp"\r\n\r\n1762500000'));
        expect(request.body, contains('filename="$_fileName"'));
        expect(request.body, contains('%PDF-'));
        return _json({'public_id': _publicId});
      }
      if (request.url.toString() == '$_api/reports/url') {
        expect(jsonDecode(request.body), {'publicId': _publicId});
        return _json({'url': 'https://api.cloudinary.com/download?x=1'});
      }
      return http.Response('not found', 404);
    });
    final service = _service(client, auth: await _signedIn());
    // Đủ lớn để chia thành nhiều phần khi đếm tiến độ.
    final bytes = Uint8List.fromList([
      ...'%PDF-'.codeUnits,
      ...List.filled(40 * 1024, 32),
    ]);

    final updates = await service
        .upload(uid: 'uidA', fileName: _fileName, bytes: bytes)
        .toList();

    expect(calls, [
      'POST $_api/reports/sign',
      'POST $_uploadUrl',
      'POST $_api/reports/url',
    ]);
    final fractions = updates.map((u) => u.fraction).toList();
    expect(fractions.first, 0.05);
    expect(fractions.length, greaterThan(3));
    for (var i = 1; i < fractions.length; i++) {
      expect(fractions[i], greaterThanOrEqualTo(fractions[i - 1]));
    }
    expect(updates.last.fraction, 1);
    expect(updates.last.downloadUrl, 'https://api.cloudinary.com/download?x=1');
  });

  test('server từ chối link báo cáo của UID khác', () async {
    final client = MockClient((request) async {
      expect(jsonDecode(request.body), {
        'publicId': CloudinaryReportStorageService.foreignReportId,
      });
      return _json({'error': 'forbidden'}, 403);
    });
    final service = _service(client, auth: await _signedIn());

    expect(await service.probeForeignReport(), 'unauthorized');
  });

  test('chưa đăng nhập thì không gọi server', () async {
    final client = MockClient((_) async => fail('không được gọi mạng'));
    final service = _service(client, auth: FakeAuthService());

    await expectLater(
      service.upload(uid: 'x', fileName: _fileName, bytes: Uint8List(1)).drain<void>(),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'unauthenticated')),
    );
  });

  test('mất mạng báo lỗi mạng', () async {
    final client = MockClient((_) async => throw http.ClientException('Failed host lookup'));
    final service = _service(client, auth: await _signedIn());

    await expectLater(
      service.upload(uid: 'x', fileName: _fileName, bytes: Uint8List(1)).drain<void>(),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'network-request-failed')),
    );
  });

  test('Cloudinary từ chối thì giữ lại thông báo lỗi', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/reports/sign') {
        return _json({'publicId': _publicId, 'uploadUrl': _uploadUrl, 'fields': {}});
      }
      return _json({
        'error': {'message': 'Invalid Signature'},
      }, 401);
    });
    final service = _service(client, auth: await _signedIn());

    await expectLater(
      service.upload(uid: 'x', fileName: _fileName, bytes: Uint8List(1)).drain<void>(),
      throwsA(
        isA<AppFailure>()
            .having((e) => e.code, 'code', 'cloudinary_401')
            .having((e) => e.message, 'message', 'Invalid Signature'),
      ),
    );
  });

  test('thiếu REPORT_API_URL thì báo lỗi cấu hình', () async {
    final client = MockClient((_) async => fail('không được gọi mạng'));
    final service = _service(client, auth: await _signedIn(), apiBase: '');

    await expectLater(
      service.upload(uid: 'x', fileName: _fileName, bytes: Uint8List(1)).drain<void>(),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'report_api_not_configured')),
    );
  });
}
