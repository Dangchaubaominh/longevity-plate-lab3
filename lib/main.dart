import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'firebase_options.dart';

/// Chạy bằng dịch vụ giả lập, ví dụ để xem trước giao diện trên web:
/// flutter run -d chrome --dart-define=USE_FAKE_SERVICES=true
const _useFakeServices = bool.fromEnvironment('USE_FAKE_SERVICES');
const _useLocalServices = bool.fromEnvironment('USE_LOCAL_SERVICES');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  if (_useLocalServices) {
    runApp(LongevityPlateApp(services: AppServices.local(prefs)));
    return;
  }

  if (_useFakeServices) {
    runApp(LongevityPlateApp(services: AppServices.fake(prefs)));
    return;
  }

  final AppServices services;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    services = await AppServices.connectedFirebase(prefs);
    await services.remoteConfig.init();
    // Chờ Firebase khôi phục phiên để không hiện nhầm màn đăng nhập.
    await services.auth.userChanges.first.timeout(
      const Duration(seconds: 3),
      onTimeout: () => null,
    );
  } catch (error) {
    runApp(
      FirebaseSetupErrorApp(
        error: error,
        onContinueOffline: () =>
            runApp(LongevityPlateApp(services: AppServices.local(prefs))),
      ),
    );
    return;
  }
  runApp(LongevityPlateApp(services: services));
}
