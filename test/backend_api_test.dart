import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:longevity_plate/services/fake_services.dart';
import 'package:longevity_plate/services/sync/backend_api.dart';

void main() {
  test(
    '401 refresh retries once and owner is checked before response use',
    () async {
      final auth = FakeAuthService();
      await auth.signInWithGoogle();
      var calls = 0;
      final api = BackendApi(
        baseUrl: 'https://backend.test',
        auth: auth,
        client: MockClient((r) async {
          expect(r.headers['Authorization'], startsWith('Bearer '));
          calls++;
          return calls == 1
              ? http.Response('{"error":{"code":"invalid_token"}}', 401)
              : http.Response('{"uid":"demo-user"}', 200);
        }),
      );
      expect((await api.call('demo-user', '/me'))['uid'], 'demo-user');
      expect(calls, 2);
      await auth.signOut();
      await expectLater(api.call('demo-user', '/me'), throwsException);
      expect(calls, 2);
    },
  );
  test('logout during request rejects response instead of exposing old session data', () async {
    final auth = FakeAuthService();
    await auth.signInWithGoogle();
    final response = Completer<http.Response>();
    final api = BackendApi(
      baseUrl: 'https://backend.test',
      auth: auth,
      client: MockClient((_) => response.future),
    );
    final work = api.call('demo-user', '/me');
    await Future<void>.delayed(Duration.zero);
    await auth.signOut();
    response.complete(http.Response(jsonEncode({'private': 'old data'}), 200));
    await expectLater(work, throwsException);
  });
  test('network timeout is bounded and retryable; insecure remote HTTP is rejected', () async {
    final auth = FakeAuthService();
    await auth.signInWithGoogle();
    final api = BackendApi(
      baseUrl: 'https://backend.test',
      auth: auth,
      timeout: const Duration(milliseconds: 5),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      api.call('demo-user', '/me'),
      throwsA(
        isA<BackendFailure>().having((e) => e.retryable, 'retryable', true),
      ),
    );
    expect(
      () => BackendApi(baseUrl: 'http://remote.test', auth: auth),
      throwsException,
    );
  });
}
