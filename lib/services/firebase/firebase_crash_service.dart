import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../service_interfaces.dart';

class FirebaseCrashService implements CrashService {
  FirebaseCrashService() {
    FlutterError.onError = _crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  final _crashlytics = FirebaseCrashlytics.instance;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    required String reason,
  }) => _crashlytics.recordError(error, stack, reason: reason);

  @override
  Future<void> setUserId(String? uid) =>
      _crashlytics.setUserIdentifier(uid ?? '');

  @override
  Future<void> setKey(String key, String value) =>
      _crashlytics.setCustomKey(key, value);

  @override
  void testCrash() => _crashlytics.crash();
}
