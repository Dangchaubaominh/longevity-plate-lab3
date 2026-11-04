import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:longevity_plate/app/app_services.dart';
import 'package:longevity_plate/core/dates.dart';
import 'package:longevity_plate/core/push_routes.dart';
import 'package:longevity_plate/models/models.dart';
import 'package:longevity_plate/services/app_failure.dart';
import 'package:longevity_plate/services/fake_services.dart';
import 'package:longevity_plate/services/report_builder.dart';
import 'package:longevity_plate/services/repositories.dart';
import 'package:longevity_plate/services/service_interfaces.dart';
import 'package:longevity_plate/viewmodels/report_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Remote Config', () {
    testWidgets('max_knowledge_results giới hạn S08, đổi là cập nhật ngay', (
      tester,
    ) async {
      final config = FakeRemoteConfigService();
      final app = await pumpApp(
        tester,
        signedIn: true,
        onboarded: true,
        remoteConfig: config,
        size: const Size(412, 1600),
      );
      await app.tapKey('tab-library');
      expect(find.text('Chuẩn bị bữa ăn cho ngày bận rộn'), findsOneWidget);

      config.publish(maxResults: 1);
      await app.settle();
      expect(find.text('Bữa ăn đa dạng bắt đầu từ đâu?'), findsOneWidget);
      expect(find.text('Chuẩn bị bữa ăn cho ngày bận rộn'), findsNothing);
    });

    testWidgets('giá trị không hợp lệ không làm thư viện trống', (tester) async {
      final app = await pumpApp(
        tester,
        signedIn: true,
        onboarded: true,
        remoteConfig: FakeRemoteConfigService(maxResults: 0),
        size: const Size(412, 1600),
      );
      await app.tapKey('tab-library');
      expect(find.text('Bữa ăn đa dạng bắt đầu từ đâu?'), findsOneWidget);
      expect(find.text('Chuẩn bị bữa ăn cho ngày bận rộn'), findsOneWidget);
    });

    testWidgets('suggested_recipes_enabled ẩn hiện Món gợi ý ở S06', (tester) async {
      final config = FakeRemoteConfigService();
      final app = await pumpApp(
        tester,
        signedIn: true,
        onboarded: true,
        remoteConfig: config,
      );
      await app.tapKey('tab-plan');
      await app.reveal(find.byKey(const Key('plan-suggestion')));
      expect(find.text('Món gợi ý'), findsOneWidget);

      config.publish(recipesEnabled: false);
      await app.settle();
      expect(find.text('Món gợi ý'), findsNothing);
      expect(find.byKey(const Key('plan-suggestion')), findsNothing);
    });

    test('mặc định trong app đúng như tài liệu', () {
      expect(RemoteConfigKeys.defaults, {
        'max_knowledge_results': 3,
        'suggested_recipes_enabled': true,
      });
    });
  });

  group('Cloud Messaging', () {
    const message = PushMessage(
      id: 'm1',
      title: 'Đến giờ ghi nhận bữa trưa',
      body: 'Ghi lại món bạn vừa ăn.',
      route: '/log',
    );

    test('chỉ đi tới route trong danh sách cho phép', () {
      expect(resolvePushRoute('/plan'), '/plan');
      expect(resolvePushRoute('/library/who-diverse'), '/library/who-diverse');
      expect(
        resolvePushRoute('/plan/recipe/toast-egg'),
        '/plan/recipe/toast-egg',
      );
      for (final bad in [
        null,
        '',
        '/account',
        '/login',
        '/library/khong-ton-tai',
        '/library/harvard-plate',
        'https://evil.example/',
        '/log/add',
      ]) {
        expect(resolvePushRoute(bad), notificationsRoute, reason: '$bad');
      }
    });

    testWidgets('foreground: lưu lịch sử, hiện SnackBar, Xem điều hướng', (
      tester,
    ) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      app.messaging.emitForeground(message);
      await app.settle();

      expect(find.text(message.title), findsOneWidget);
      expect(find.text('Xem'), findsOneWidget);
      expect(find.byTooltip('Thông báo, 1 chưa đọc'), findsOneWidget);

      await app.tapText('Xem');
      expect(app.path, '/log');
      expect(app.eventNames, contains('notification_opened'));
      expect(find.byTooltip('Thông báo'), findsOneWidget);
    });

    testWidgets('background: chạm thông báo mở đúng màn và có trong lịch sử', (
      tester,
    ) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      app.messaging.emitOpened(
        const PushMessage(
          id: 'm2',
          title: 'Bài mới',
          body: '',
          route: '/library/who-diverse',
        ),
      );
      await app.settle();
      expect(app.path, '/library/who-diverse');

      await app.tapBack();
      await app.tapKey('open-notifications');
      expect(find.text('Bài mới'), findsOneWidget);
      expect(find.text('Mới'), findsNothing);
    });

    testWidgets('terminated: tin mở app được xử lý sau khi đã đăng nhập', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        signedIn: true,
        onboarded: true,
        launchMessage: message,
      );
      await app.settle();
      expect(app.path, '/log');
    });

    testWidgets('terminated: mở màn chi tiết, Back về được màn chính', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        signedIn: true,
        onboarded: true,
        launchMessage: const PushMessage(
          id: 'm4',
          title: 'Bài mới',
          body: '',
          route: '/library/who-diverse',
        ),
      );
      await app.settle();
      expect(app.path, '/library/who-diverse');
      expect(find.text('Xem nguồn WHO'), findsOneWidget);

      await app.tapBack();
      expect(app.path, '/home');
      expect(find.text('Chào Trần Thị Mai'), findsOneWidget);
    });

    testWidgets('chưa đăng nhập: giữ tin, đăng nhập xong mới đi tới', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        launchMessage: message,
        prefs: const {
          'demo-user.goals': ['logMeals'],
        },
      );
      await app.settle();
      expect(app.path, '/welcome');
      await app.tapKey('welcome-start');
      await app.tapKey('login-google');
      await app.settle();
      expect(app.path, '/log');
    });

    testWidgets('route lạ trong thông báo đưa về S12', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      app.messaging.emitOpened(
        const PushMessage(id: 'm3', title: 'Lạ', body: '', route: '/account'),
      );
      await app.settle();
      expect(app.path, '/notifications');
    });

    testWidgets('tin từ handler nền được gộp vào lịch sử, không trùng', (
      tester,
    ) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      final item = AppNotification(
        id: 'bg1',
        title: 'Tin nền',
        body: 'Nhận khi app ở nền',
        route: null,
        receivedAt: DateTime(2026, 11, 4, 8),
      );
      await NotificationRepository.enqueueFromBackground(item);
      await NotificationRepository.enqueueFromBackground(item);

      await app.tapKey('open-notifications');
      expect(find.text('Tin nền'), findsOneWidget);
      expect(await app.services.notifications.load('demo-user'), hasLength(1));
    });

    testWidgets('từ chối quyền: S12 có hướng dẫn, app vẫn dùng được', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        signedIn: true,
        onboarded: true,
        permission: PushPermission.denied,
      );
      app.messaging.grantOnRequest = PushPermission.denied;
      await app.tapKey('open-notifications');
      expect(find.text('Thông báo đang tắt'), findsOneWidget);
      expect(find.text('Chưa có thông báo nào'), findsOneWidget);

      await app.tapKey('notification-request');
      expect(find.text('Thông báo đang tắt'), findsOneWidget);

      app.messaging.grantOnRequest = PushPermission.granted;
      await app.tapKey('notification-request');
      expect(find.text('Thông báo đang tắt'), findsNothing);
    });
  });

  group('Cloud Storage và báo cáo PDF', () {
    late AppServices services;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      services = AppServices.fake(await SharedPreferences.getInstance());
    });

    test('tải lên đúng thư mục theo uid, có tiến độ và URL', () async {
      final vm = ReportViewModel(services, 'demo-user');
      final progress = <double>[];
      vm.addListener(() => progress.add(vm.progress));

      await vm.export();

      expect(vm.phase, ReportPhase.success);
      expect(vm.url, isNotNull);
      expect(progress, containsAllInOrder([0.25, 0.5, 0.75, 1.0]));
      final storage = services.storage as FakeReportStorageService;
      expect(storage.lastPath, startsWith('reports/demo-user/meal-report-'));
      expect(storage.lastPath, endsWith('.pdf'));
    });

    test('tải lên lỗi báo rõ, ghi non-fatal, thử lại được', () async {
      services.faults.set(FaultPoint.uploadReport, true);
      final vm = ReportViewModel(services, 'demo-user');

      await vm.export();

      expect(vm.phase, ReportPhase.failure);
      expect(vm.errorMessage, isNotEmpty);
      final crash = services.crash as FakeCrashService;
      expect(crash.errors, contains('report_export_failed'));
      final analytics = services.analytics as FakeAnalyticsService;
      expect(analytics.events.map((e) => e.name), contains('report_export_failed'));

      await vm.export();
      expect(vm.phase, ReportPhase.success);
    });

    test('PDF hợp lệ, chỉ gồm 7 ngày gần nhất', () async {
      final now = today();
      for (final (offset, text) in [(0, 'Cơm gạo lứt'), (-6, 'Phở bò'), (-7, 'Quá hạn')]) {
        await services.meals.add(
          'demo-user',
          date: dateKey(addDays(now, offset)),
          type: MealType.lunch,
          description: text,
        );
      }
      final meals = services.meals.inRange('demo-user', addDays(now, -6), now);
      expect(meals.map((m) => m.description), ['Phở bò', 'Cơm gạo lứt']);

      final bytes = await ReportBuilder().build(
        meals: meals,
        from: addDays(now, -6),
        to: now,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

      // Để lại tệp cho bước kiểm tra chữ tiếng Việt bằng pdftotext.
      final output = Platform.environment['REPORT_TEST_OUTPUT'];
      if (output != null) File(output).writeAsBytesSync(bytes);
    });

    testWidgets('bottom sheet ở S04 xuất báo cáo và hiện kết quả', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      await app.tapKey('tab-log');
      await app.tapKey('log-export');
      expect(find.text('Xuất báo cáo PDF'), findsWidgets);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('report-start')));
        // Nạp font từ bundle và tạo PDF cần thời gian thật.
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          if (find.byKey(const Key('report-success')).evaluate().isNotEmpty) {
            break;
          }
        }
      });
      await app.settle();
      expect(find.byKey(const Key('report-success')), findsOneWidget);
    });
  });

  group('Khu vực trình diễn', () {
    testWidgets('bật lỗi giả lập một lần, thử quyền đọc UID khác', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      await app.tapKey('open-account');
      await app.tapKey('demo-area');

      await app.tapKey('fault-loadLog');
      expect(app.services.faults.isArmed(FaultPoint.loadLog), isTrue);

      await app.tapKey('storage-probe');
      expect(
        find.text('Bị từ chối đúng như mong đợi (unauthorized).'),
        findsOneWidget,
      );

      await app.tapKey('crash-non-fatal');
      expect(app.crash.errors, contains('demo_non_fatal'));
      expect(find.textContaining('max_knowledge_results = 3'), findsOneWidget);
    });

    testWidgets('crash thử nghiệm phải xác nhận trước', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      await app.tapKey('open-account');
      await app.tapKey('demo-area');
      await app.tapKey('crash-test');
      expect(find.text('Gây crash thử nghiệm?'), findsOneWidget);

      await app.tapText('Hủy');
      expect(tester.takeException(), isNull);
    });

    testWidgets('đổi mục tiêu từ S11 rồi quay lại', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      await app.tapKey('open-account');
      await app.tapKey('account-edit-goals');
      expect(app.path, '/goals');
      await app.tapKey('goal-learn');
      await app.tapKey('goals-submit');
      expect(app.path, '/account');
      expect(find.text('• ${Goal.learn.label}'), findsOneWidget);
    });
  });
}
