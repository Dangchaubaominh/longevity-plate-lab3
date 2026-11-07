import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_failure.dart';
import 'service_interfaces.dart';

// Bản giả lập dùng cho test và xem trước giao diện trên web, chạy bằng
// --dart-define=USE_FAKE_SERVICES=true. Không gửi gì lên Firebase.

class FakeAuthService implements AuthService {
  FakeAuthService({AppUser? initialUser}) : _user = initialUser;

  AppUser? _user;
  final _controller = StreamController<AppUser?>.broadcast();

  /// Lỗi lần đăng nhập kế tiếp: `cancel`, hoặc một mã AppFailure như `network`.
  String? nextSignInResult;

  @override
  Stream<AppUser?> get userChanges async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _user;

  @override
  Future<void> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final result = nextSignInResult;
    nextSignInResult = null;
    if (result == 'cancel') throw const SignInCancelled();
    if (result != null) throw AppFailure(result);
    _user = const AppUser(
      uid: 'demo-user',
      displayName: 'Mai',
      email: 'mai@example.com',
    );
    _controller.add(_user);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<String?> idToken() async => _user == null ? null : 'fake-id-token';
}

class FakeReportStorageService implements ReportStorageService {
  FakeReportStorageService(this._faults);

  final FaultInjector _faults;
  String? lastPath;

  @override
  Stream<UploadProgress> upload({
    required String uid,
    required String fileName,
    required Uint8List bytes,
  }) async* {
    _faults.check(FaultPoint.uploadReport);
    for (final fraction in const [0.25, 0.5, 0.75]) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      yield UploadProgress(fraction);
    }
    lastPath = 'reports/$uid/$fileName';
    yield UploadProgress(
      1,
      downloadUrl: 'https://example.invalid/fake-storage/$lastPath',
    );
  }

  @override
  Future<String> probeForeignReport() async => 'unauthorized';
}

class FakeMessagingService implements MessagingService {
  final _foreground = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();
  PushPermission permission = PushPermission.notDetermined;
  PushPermission grantOnRequest = PushPermission.granted;
  PushMessage? launchMessage;

  void emitForeground(PushMessage message) => _foreground.add(message);
  void emitOpened(PushMessage message) => _opened.add(message);

  @override
  Stream<PushMessage> get onForeground => _foreground.stream;

  @override
  Stream<PushMessage> get onOpened => _opened.stream;

  @override
  Future<PushMessage?> initialMessage() async {
    final message = launchMessage;
    launchMessage = null;
    return message;
  }

  @override
  Future<PushPermission> permissionStatus() async => permission;

  @override
  Future<PushPermission> requestPermission() async =>
      permission = grantOnRequest;

  @override
  Future<String?> token() async => 'fake-fcm-token';
}

class RecordedEvent {
  const RecordedEvent(this.name, this.parameters);

  final String name;
  final Map<String, Object> parameters;
}

class FakeAnalyticsService implements AnalyticsService {
  final events = <RecordedEvent>[];
  final screens = <String>[];
  String? userId;

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object> parameters = const {},
  ]) async {
    events.add(RecordedEvent(name, parameters));
    debugPrint('[analytics] $name $parameters');
  }

  @override
  Future<void> logScreen(String name) async => screens.add(name);

  @override
  Future<void> setUserId(String? uid) async => userId = uid;
}

class FakeCrashService implements CrashService {
  final errors = <String>[];
  final keys = <String, String>{};
  String? userId;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    required String reason,
  }) async {
    errors.add(reason);
    debugPrint('[crash] $reason: $error');
  }

  @override
  Future<void> setUserId(String uid) async => userId = uid;

  @override
  Future<void> setKey(String key, String value) async => keys[key] = value;

  @override
  void testCrash() => throw StateError('Crash thử nghiệm');
}

class FakeRemoteConfigService extends RemoteConfigService {
  FakeRemoteConfigService({int? maxResults, bool? recipesEnabled})
    : _maxResults =
          maxResults ?? RemoteConfigKeys.defaults[RemoteConfigKeys.maxKnowledgeResults]! as int,
      _recipesEnabled =
          recipesEnabled ?? RemoteConfigKeys.defaults[RemoteConfigKeys.suggestedRecipesEnabled]! as bool;

  int _maxResults;
  bool _recipesEnabled;

  /// Giả lập việc đổi giá trị trên Console.
  void publish({int? maxResults, bool? recipesEnabled}) {
    _maxResults = maxResults ?? _maxResults;
    _recipesEnabled = recipesEnabled ?? _recipesEnabled;
    notifyListeners();
  }

  @override
  int get maxKnowledgeResults => _maxResults;

  @override
  bool get suggestedRecipesEnabled => _recipesEnabled;

  @override
  String get status => 'Bản giả lập, không kết nối Firebase.';

  @override
  Future<void> init() async {}

  @override
  Future<void> refresh() async => notifyListeners();
}
