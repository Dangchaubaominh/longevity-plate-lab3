import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:longevity_plate/app/app.dart';
import 'package:longevity_plate/app/app_services.dart';
import 'package:longevity_plate/app/router.dart';
import 'package:longevity_plate/models/models.dart';
import 'package:longevity_plate/services/fake_services.dart';
import 'package:longevity_plate/services/meal_photo_service.dart';
import 'package:longevity_plate/services/service_interfaces.dart';
import 'package:longevity_plate/views/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

const demoUser = AppUser(
  uid: 'demo-user',
  displayName: 'Trần Thị Mai',
  email: 'mai@example.com',
);

class TestApp {
  TestApp(this.tester, this.services);

  final WidgetTester tester;
  final AppServices services;

  FakeAuthService get auth => services.auth as FakeAuthService;
  FakeAnalyticsService get analytics => services.analytics as FakeAnalyticsService;
  FakeCrashService get crash => services.crash as FakeCrashService;
  FakeMessagingService get messaging => services.messaging as FakeMessagingService;
  FakeRemoteConfigService get config =>
      services.remoteConfig as FakeRemoteConfigService;

  GoRouter get router =>
      GoRouter.of(tester.element(find.byType(Navigator).first));

  String get path => currentPath(router);

  List<String> get eventNames => [for (final e in analytics.events) e.name];

  Future<void> settle() async {
    await tester.pumpAndSettle();
    // Tab ẩn tự tải lại khi dữ liệu đổi. Tab ẩn không xin frame nên pumpAndSettle
    // không chờ phần này.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  /// Cuộn như người dùng tới phần tử, vì ListView chỉ dựng phần gần màn hình.
  Future<void> reveal(Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.descendant(
          of: find.byType(PageList).last,
          matching: find.byType(Scrollable).first,
        ),
      );
    }
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }

  /// Repository có độ trễ giả lập. Trong testWidgets thời gian chỉ chạy khi pump,
  /// nên await trực tiếp sẽ treo mãi.
  Future<void> addMeal(
    String uid,
    String date,
    MealType type,
    String description,
  ) async {
    final future = services.meals.add(
      uid,
      date: date,
      type: type,
      description: description,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await future;
    await settle();
  }

  Future<void> setPlan(String date, PlanSlot slot, String recipeId) async {
    final future = services.plans.setSlot('demo-user', date, slot, recipeId);
    await tester.pump(const Duration(milliseconds: 300));
    await future;
    await settle();
  }

  Future<void> tapKey(String key) async {
    final finder = find.byKey(Key(key));
    await reveal(finder);
    await tester.tap(finder);
    await settle();
  }

  Future<void> tapText(String text) async {
    final finder = find.text(text);
    await reveal(finder);
    await tester.tap(finder.first);
    await settle();
  }

  Future<void> tapBack() async {
    await tester.tap(find.byTooltip('Quay lại'));
    await settle();
  }

  Future<void> enter(String key, String text) async {
    final finder = find.byKey(Key(key));
    await reveal(finder);
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }
}

/// Dựng app với dịch vụ giả lập ở kích thước màn hình Lab 2 yêu cầu.
Future<TestApp> pumpApp(
  WidgetTester tester, {
  bool signedIn = false,
  bool onboarded = false,
  Size size = const Size(360, 800),
  FakeRemoteConfigService? remoteConfig,
  Map<String, Object> prefs = const {},
  PushMessage? launchMessage,
  PushPermission? permission,
  Future<bool> Function(Uri uri)? linkOpener,
  MealPhotoService? mealPhotos,
  bool capture = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    if (onboarded) 'demo-user.goals': ['logMeals'],
    ...prefs,
  });
  final instance = await SharedPreferences.getInstance();
  final services = AppServices.fake(
    instance,
    auth: FakeAuthService(initialUser: signedIn ? demoUser : null),
    remoteConfig: remoteConfig,
    linkOpener: linkOpener,
    mealPhotos: mealPhotos,
  );
  final messaging = services.messaging as FakeMessagingService;
  messaging.launchMessage = launchMessage;
  if (permission != null) messaging.permission = permission;

  final widget = LongevityPlateApp(services: services);
  await tester.pumpWidget(capture ? RepaintBoundary(key: const Key('ui-capture'), child: widget) : widget);
  await tester.pumpAndSettle();
  return TestApp(tester, services);
}
