import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:longevity_plate/app/app.dart';
import 'package:longevity_plate/app/app_services.dart';
import 'package:longevity_plate/services/app_failure.dart';
import 'package:longevity_plate/services/local_services.dart';
import 'package:longevity_plate/services/resilient_telemetry.dart';
import 'package:longevity_plate/services/service_interfaces.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingAnalytics implements AnalyticsService {
  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object> parameters = const {},
  ]) async => throw StateError('offline');
  @override
  Future<void> logScreen(String name) async => throw StateError('offline');
  @override
  Future<void> setUserId(String? uid) async => throw StateError('offline');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'hồ sơ local giữ phiên sau mở lại và logout không xóa dữ liệu bữa',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final auth = LocalAuthService(prefs);
      expect(auth.currentUser, isNull);
      await auth.signInWithGoogle();
      await prefs.setString('local-user.meals', '[]');
      expect(LocalAuthService(prefs).currentUser?.uid, 'local-user');
      await auth.signOut();
      expect(LocalAuthService(prefs).currentUser, isNull);
      expect(prefs.getString('local-user.meals'), '[]');
    },
  );

  test('PDF chuyển đúng bytes qua Android và trả URI thật', () async {
    final binding = TestDefaultBinaryMessengerBinding.instance;
    MethodCall? saved;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      DeviceReportStorageService.channel,
      (call) async {
        saved = call;
        return 'content://documents/report.pdf';
      },
    );
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
        DeviceReportStorageService.channel,
        null,
      ),
    );
    final storage = DeviceReportStorageService(FaultInjector());
    final bytes = Uint8List.fromList([37, 80, 68, 70]);
    final updates = await storage
        .upload(uid: 'local-user', fileName: 'report.pdf', bytes: bytes)
        .toList();
    expect(saved?.method, 'savePdf');
    expect(saved?.arguments['bytes'], bytes);
    expect(saved?.arguments['name'], 'report.pdf');
    expect(updates.last.downloadUrl, 'content://documents/report.pdf');
    expect(updates.last.fraction, 1);
  });

  test('hủy picker không báo upload thành công', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      DeviceReportStorageService.channel,
      (_) async => throw PlatformException(code: 'save_cancelled'),
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        DeviceReportStorageService.channel,
        null,
      ),
    );
    final storage = DeviceReportStorageService(FaultInjector());
    await expectLater(
      storage.upload(
        uid: 'local-user',
        fileName: 'test.pdf',
        bytes: Uint8List(1),
      ),
      emitsInOrder([
        isA<UploadProgress>(),
        emitsError(
          isA<AppFailure>().having((e) => e.code, 'code', 'save_cancelled'),
        ),
      ]),
    );
  });

  test('lỗi Analytics không lan sang nghiệp vụ', () async {
    final analytics = ResilientAnalyticsService(_FailingAnalytics());
    await analytics.logEvent('meal_saved');
    await analytics.logScreen('/home');
    await analytics.setUserId(null);
  });

  testWidgets('APK offline: onboarding, thêm bữa và thông báo mẫu điều hướng', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    final services = AppServices.local(prefs);
    await tester.pumpWidget(LongevityPlateApp(services: services));
    await tester.pumpAndSettle();
    Future<void> tap(String key) async {
      final finder = find.byKey(Key(key));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('OFFLINE'), findsOneWidget);
    await tap('welcome-start');
    expect(find.text('Tiếp tục offline'), findsOneWidget);
    expect(find.text('Tiếp tục với Google'), findsNothing);
    await tap('login-google');
    await tap('goal-logMeals');
    await tap('goals-submit');
    expect(find.text('Chào Bạn'), findsOneWidget);
    await tap('tab-log');
    await tap('log-add-meal');
    // Không nhập dữ liệu: vẫn phải kiểm tra hợp lệ trên bản offline.
    await tap('meal-save');
    expect(find.text('Hãy chọn loại bữa.'), findsOneWidget);
    await tap('meal-type-lunch');
    final description = find.byKey(const Key('meal-description'));
    await tester.ensureVisible(description);
    await tester.enterText(description, 'Bữa kiểm tra offline');
    await tap('meal-save');
    await tester.pumpAndSettle();
    expect(find.text('Bữa kiểm tra offline'), findsOneWidget);
    expect(
      prefs.getString('local-user.meals'),
      contains('Bữa kiểm tra offline'),
    );
    await tap('open-notifications');
    await tap('local-notification');
    expect(find.text('Thông báo mẫu trên thiết bị'), findsWidgets);
    // Đóng SnackBar trước khi chạm đúng thẻ lịch sử.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thông báo mẫu trên thiết bị').first);
    await tester.pumpAndSettle();
    expect(find.text('Kiến thức'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
