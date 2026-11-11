import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:longevity_plate/app/router.dart';
import 'package:longevity_plate/core/dates.dart';
import 'package:longevity_plate/models/models.dart';
import 'package:longevity_plate/services/app_failure.dart';
import 'package:longevity_plate/services/service_interfaces.dart';

import 'helpers.dart';

void main() {
  group('guardRedirect', () {
    String? guard(
      String path, {
      bool signedIn = true,
      bool onboarded = true,
      bool edit = false,
    }) => guardRedirect(
      path: path,
      isEditingGoals: edit,
      signedIn: signedIn,
      onboarded: onboarded,
    );

    test('chặn mọi route bảo vệ khi chưa đăng nhập', () {
      for (final path in [
        '/home',
        '/log',
        '/log/add',
        '/plan',
        '/plan/recipe/rice-veg-beans',
        '/library',
        '/library/who-diverse',
        '/account',
        '/notifications',
        '/goals',
      ]) {
        expect(guard(path, signedIn: false), '/login', reason: path);
      }
      expect(guard('/welcome', signedIn: false), isNull);
      expect(guard('/login', signedIn: false), isNull);
    });

    test('đã đăng nhập, chưa có mục tiêu thì buộc qua S02', () {
      expect(guard('/home', onboarded: false), '/goals');
      expect(guard('/login', onboarded: false), '/goals');
      expect(guard('/goals', onboarded: false), isNull);
      expect(guard('/welcome', onboarded: false), isNull);
    });

    test('đã onboarding thì không quay lại S01, S10, S02', () {
      expect(guard('/welcome'), '/home');
      expect(guard('/login'), '/home');
      expect(guard('/goals'), '/home');
      expect(guard('/goals', edit: true), isNull);
      expect(guard('/home'), isNull);
    });
  });

  testWidgets('F01: S01 → S10 → S02 → S03 kể cả lỗi chưa chọn mục tiêu', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    expect(find.text('Ăn uống chủ động, mỗi ngày một chút'), findsOneWidget);

    await app.tapKey('welcome-start');
    expect(app.path, '/login');

    await app.tapKey('login-google');
    expect(app.path, '/goals');

    await app.tapKey('goals-submit');
    expect(find.text('Hãy chọn ít nhất một mục tiêu.'), findsOneWidget);
    expect(app.path, '/goals');

    await app.tapKey('goal-logMeals');
    expect(find.text('Hãy chọn ít nhất một mục tiêu.'), findsNothing);
    expect(find.text('Đã chọn'), findsOneWidget);

    await app.tapKey('goals-submit');
    expect(app.path, '/home');
    expect(find.text('Chào Mai'), findsOneWidget);

    expect(app.eventNames, containsAll(['login', 'tutorial_begin', 'tutorial_complete']));
    final complete = app.analytics.events.firstWhere(
      (e) => e.name == 'tutorial_complete',
    );
    expect(complete.parameters['goal_count'], 1);
    expect(complete.parameters['duration_ms'], isA<int>());
  });

  testWidgets('S02: lưu lỗi vẫn giữ lựa chọn, thử lại thành công', (tester) async {
    final app = await pumpApp(tester, signedIn: true);
    app.services.faults.set(FaultPoint.saveGoals, true);
    await app.tapKey('welcome-start');
    await app.tapKey('goal-planMeals');
    await app.tapKey('goals-submit');

    expect(find.byKey(const Key('goal-save-error')), findsOneWidget);
    expect(find.text('Đã chọn'), findsOneWidget);
    expect(app.path, '/goals');
    expect(app.crash.errors, contains('goal_save_failed'));

    await app.tapKey('goals-submit');
    expect(app.path, '/home');
  });

  testWidgets('S02: chỉ hỏi quyền thông báo sau onboarding', (tester) async {
    final app = await pumpApp(tester, signedIn: true);
    expect(app.messaging.permission, PushPermission.notDetermined);
    await app.tapKey('welcome-start');
    await app.tapKey('goal-learn');
    await app.tapKey('goals-submit');
    expect(app.messaging.permission, PushPermission.granted);
  });

  testWidgets('hủy đăng nhập: ở lại S10, báo rõ, không ghi crash', (tester) async {
    final app = await pumpApp(tester);
    await app.tapKey('welcome-start');
    app.auth.nextSignInResult = 'cancel';
    await app.tapKey('login-google');

    expect(app.path, '/login');
    expect(find.textContaining('Bạn đã hủy đăng nhập'), findsOneWidget);
    expect(app.crash.errors, isEmpty);
    expect(app.eventNames, isNot(contains('login')));

    await app.tapKey('login-google');
    expect(app.path, '/goals');
  });

  testWidgets('mất mạng khi đăng nhập: báo lỗi mạng, ghi non-fatal', (tester) async {
    final app = await pumpApp(tester);
    await app.tapKey('welcome-start');
    app.auth.nextSignInResult = 'network-request-failed';
    await app.tapKey('login-google');

    expect(app.path, '/login');
    expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);
    expect(app.crash.errors, contains('sign_in_failed'));
  });

  testWidgets('đăng xuất về S10, xóa trạng thái, đăng nhập lại còn dữ liệu', (
    tester,
  ) async {
    final app = await pumpApp(tester, signedIn: true, onboarded: true);
    await app.addMeal('demo-user', dateKey(today()), MealType.lunch, 'Cơm rau');
    await app.tapKey('tab-log');
    expect(find.text('Cơm rau'), findsOneWidget);

    await app.tapKey('open-account');
    await app.tapKey('account-sign-out');
    expect(app.path, '/login');
    expect(find.text('Cơm rau'), findsNothing);
    expect(app.analytics.userId, isNull);
    expect(app.crash.userId, isNull);

    // Đăng nhập lại vào shell mới: state cũ đã bị hủy, dữ liệu theo uid vẫn còn.
    await app.tapKey('login-google');
    expect(app.path, '/home');
    await app.tapKey('tab-log');
    expect(find.text('Cơm rau'), findsOneWidget);
  });

  testWidgets('dữ liệu tách theo uid', (tester) async {
    final app = await pumpApp(tester, signedIn: true, onboarded: true);
    await app.addMeal(
      'nguoi-khac',
      dateKey(today()),
      MealType.lunch,
      'Món của người khác',
    );
    await app.tapKey('tab-log');
    expect(find.text('Món của người khác'), findsNothing);
    expect(find.text('Chưa có bữa ăn nào'), findsOneWidget);
  });
}
