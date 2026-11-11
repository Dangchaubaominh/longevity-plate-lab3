import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_failure.dart';
import '../services/cloud/cloudinary_report_service.dart';
import '../services/fake_services.dart';
import '../services/local_services.dart';
import '../services/meal_photo_service.dart';
import '../services/device_meal_photo_service.dart';
import '../services/fake_meal_photo_service.dart';
import '../services/resilient_telemetry.dart';
import '../services/firebase/firebase_analytics_service.dart';
import '../services/firebase/firebase_auth_service.dart';
import '../services/firebase/firebase_crash_service.dart';
import '../services/firebase/firebase_messaging_service.dart';
import '../services/firebase/firebase_remote_config_service.dart';
import '../services/report_builder.dart';
import '../services/repositories.dart';
import '../services/service_interfaces.dart';

/// Toàn bộ phụ thuộc của app. ViewModel nhận từ đây nên test đổi được bản giả lập.
class AppServices {
  AppServices({
    required this.prefs,
    required this.faults,
    required this.auth,
    required this.storage,
    required this.messaging,
    required this.analytics,
    required this.crash,
    required this.remoteConfig,
    this.isFake = false,
    this.isLocal = false,
    MealPhotoService? mealPhotos,
    Future<bool> Function(Uri uri)? linkOpener,
  }) : openLink = linkOpener ?? _launch,
       goals = GoalRepository(prefs, faults),
       plans = PlanRepository(prefs, faults),
       content = ContentRepository(faults),
       notifications = NotificationRepository(prefs),
       reports = ReportBuilder() {
    photos =
        mealPhotos ??
        (isFake && !isLocal
            ? FakeMealPhotoService(currentUid: () => auth.currentUser?.uid)
            : DeviceMealPhotoService(
                prefs: prefs,
                currentUid: () => auth.currentUser?.uid,
              ));
    meals = MealRepository(prefs, faults, photos: photos);
  }

  factory AppServices.firebase(SharedPreferences prefs) {
    final faults = FaultInjector();
    final auth = FirebaseAuthService();
    return AppServices(
      prefs: prefs,
      faults: faults,
      auth: auth,
      storage: CloudinaryReportStorageService(
        auth: auth,
        faults: faults,
        // Địa chỉ server báo cáo, truyền khi build: --dart-define=REPORT_API_URL=...
        apiBase: const String.fromEnvironment('REPORT_API_URL'),
      ),
      messaging: FirebaseMessagingService(),
      analytics: ResilientAnalyticsService(FirebaseAnalyticsService()),
      crash: FirebaseCrashService(),
      remoteConfig: FirebaseRemoteConfigService(),
    );
  }

  factory AppServices.local(SharedPreferences prefs) {
    final faults = FaultInjector();
    return AppServices(
      prefs: prefs,
      faults: faults,
      auth: LocalAuthService(prefs),
      storage: DeviceReportStorageService(faults),
      messaging: FakeMessagingService(),
      analytics: FakeAnalyticsService(),
      crash: FakeCrashService(),
      remoteConfig: FakeRemoteConfigService(),
      isFake: true,
      isLocal: true,
      linkOpener: (uri) => uri.scheme == 'content'
          ? DeviceReportStorageService.open(uri)
          : _launch(uri),
    );
  }

  factory AppServices.fake(
    SharedPreferences prefs, {
    FakeAuthService? auth,
    FakeRemoteConfigService? remoteConfig,
    Future<bool> Function(Uri uri)? linkOpener,
    MealPhotoService? mealPhotos,
  }) {
    final faults = FaultInjector();
    return AppServices(
      prefs: prefs,
      faults: faults,
      auth: auth ?? FakeAuthService(),
      storage: FakeReportStorageService(faults),
      messaging: FakeMessagingService(),
      analytics: FakeAnalyticsService(),
      crash: FakeCrashService(),
      remoteConfig: remoteConfig ?? FakeRemoteConfigService(),
      isFake: true,
      linkOpener: linkOpener,
      mealPhotos: mealPhotos,
    );
  }

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  final Future<bool> Function(Uri uri) openLink;
  final SharedPreferences prefs;
  final FaultInjector faults;
  final AuthService auth;
  final ReportStorageService storage;
  final MessagingService messaging;
  final AnalyticsService analytics;
  final CrashService crash;
  final RemoteConfigService remoteConfig;
  final bool isFake;
  final bool isLocal;

  final GoalRepository goals;
  late final MealPhotoService photos;
  late final MealRepository meals;
  final PlanRepository plans;
  final ContentRepository content;
  final NotificationRepository notifications;
  final ReportBuilder reports;
}
