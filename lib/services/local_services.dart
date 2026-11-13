import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_failure.dart';
import 'service_interfaces.dart';

/// Hồ sơ trên điện thoại, không giả làm đăng nhập Google/Firebase.
class LocalAuthService implements AuthService {
  LocalAuthService(this._prefs);

  static const _sessionKey = 'local.signed_in';
  static const user = AppUser(uid: 'local-user', displayName: 'Bạn');
  final SharedPreferences _prefs;
  final _changes = StreamController<AppUser?>.broadcast();

  @override
  AppUser? get currentUser => _prefs.getBool(_sessionKey) == true ? user : null;

  @override
  Stream<AppUser?> get userChanges async* {
    yield currentUser;
    yield* _changes.stream;
  }

  @override
  Future<String?> idToken({bool forceRefresh = false}) async => null;

  @override
  Future<void> signInWithGoogle() async {
    if (!await _prefs.setBool(_sessionKey, true)) {
      throw const AppFailure('local_session_failed');
    }
    _changes.add(user);
  }

  @override
  Future<void> signOut() async {
    if (!await _prefs.remove(_sessionKey)) {
      throw const AppFailure('local_session_failed');
    }
    _changes.add(null);
  }
}

/// Android Storage Access Framework: người dùng chọn nơi lưu PDF.
/// Không cấp URL cloud giả và không cần quyền truy cập toàn bộ bộ nhớ.
class DeviceReportStorageService implements ReportStorageService {
  DeviceReportStorageService(this._faults);

  static const channel = MethodChannel('com.longevityplate/documents');
  final FaultInjector _faults;

  @override
  Stream<UploadProgress> upload({
    required String uid,
    required String fileName,
    required Uint8List bytes,
  }) async* {
    _faults.check(FaultPoint.uploadReport);
    yield const UploadProgress(0);
    try {
      final uri = await channel.invokeMethod<String>('savePdf', {
        'name': fileName,
        'bytes': bytes,
      });
      if (uri == null) throw const AppFailure('save_cancelled');
      yield UploadProgress(1, downloadUrl: uri);
    } on PlatformException catch (e) {
      throw AppFailure(e.code, e.message);
    }
  }

  static Future<bool> open(Uri uri) async =>
      await channel.invokeMethod<bool>('openPdf', {'uri': '$uri'}) ?? false;

  @override
  Future<String> probeForeignReport() async => 'offline';
}
