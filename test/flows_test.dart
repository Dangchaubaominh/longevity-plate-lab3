import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:longevity_plate/core/dates.dart';
import 'package:longevity_plate/models/models.dart';
import 'package:longevity_plate/services/app_failure.dart';

import 'helpers.dart';

const _pii = ['mai@example.com', 'Trần Thị Mai', 'Bữa của tôi'];

void main() {
  group('F02 Ghi nhận bữa ăn', () {
    testWidgets('kiểm tra hợp lệ rồi lưu đúng một bản ghi về S04', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      await app.tapKey('home-log-meal');
      expect(app.path, '/log');
      expect(find.text('Chưa có bữa ăn nào'), findsOneWidget);

      await app.tapKey('log-add-meal');
      expect(app.path, '/log/add');

      await app.tapKey('meal-save');
      expect(find.text('Hãy chọn loại bữa.'), findsOneWidget);
      expect(find.text('Hãy nhập món ăn trước khi lưu.'), findsOneWidget);

      await app.tapKey('meal-type-lunch');
      await app.enter('meal-description', '   ');
      await app.tapKey('meal-save');
      expect(find.text('Hãy nhập món ăn trước khi lưu.'), findsOneWidget);

      await app.enter('meal-description', '  Bữa của tôi  ');
      expect(find.text('11/120'), findsOneWidget);
      await app.tapKey('meal-save');

      expect(app.path, '/log');
      expect(find.text('Đã lưu bữa ăn'), findsOneWidget);
      expect(find.text('Bữa của tôi'), findsOneWidget);
      expect(find.text('Hôm nay đã ghi 1 bữa'), findsOneWidget);
      final saved = app.services.meals.inRange('demo-user', today(), today());
      expect(saved, hasLength(1));
      expect(saved.single.description, 'Bữa của tôi');

      final event = app.analytics.events.firstWhere((e) => e.name == 'meal_saved');
      expect(event.parameters['meal_type'], 'lunch');
    });

    testWidgets('lưu lỗi giữ nội dung, thử lại chỉ tạo một bản ghi', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      await app.tapKey('tab-log');
      await app.tapKey('log-add-meal');
      await app.tapKey('meal-type-dinner');
      await app.enter('meal-description', 'Canh rau');

      app.services.faults.set(FaultPoint.saveMeal, true);
      await app.tapKey('meal-save');

      expect(app.path, '/log/add');
      expect(find.text('Chưa lưu được bữa ăn.'), findsOneWidget);
      expect(find.text('Canh rau'), findsOneWidget);
      expect(app.eventNames, contains('meal_save_failed'));
      expect(app.crash.errors, contains('meal_save_failed'));
      expect(app.services.meals.inRange('demo-user', today(), today()), isEmpty);

      await app.tapKey('meal-retry');
      expect(app.path, '/log');
      expect(app.services.meals.inRange('demo-user', today(), today()), hasLength(1));
    });

    testWidgets('Back khi có nội dung hỏi xác nhận, Tiếp tục nhập giữ nội dung', (
      tester,
    ) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      await app.tapKey('tab-log');
      await app.tapKey('log-add-meal');

      await app.tapBack();
      expect(app.path, '/log');

      await app.tapKey('log-add-meal');
      await app.enter('meal-description', 'Nháp');
      await app.tapBack();
      expect(find.text('Bỏ nội dung chưa lưu?'), findsOneWidget);

      await app.tapText('Tiếp tục nhập');
      expect(app.path, '/log/add');
      expect(find.text('Nháp'), findsOneWidget);

      await app.tapBack();
      await app.tapKey('discard-confirm');
      expect(app.path, '/log');
      expect(app.eventNames, contains('meal_draft_discarded'));
      expect(app.services.meals.inRange('demo-user', today(), today()), isEmpty);
    });

    testWidgets('không cho chuyển tới ngày tương lai ở S04', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      await app.tapKey('tab-log');
      final next = tester.widget<IconButton>(find.byKey(const Key('log-next-day')));
      expect(next.onPressed, isNull);

      await app.tapKey('log-prev-day');
      expect(find.text('Hôm qua'), findsOneWidget);
      await app.tapKey('log-next-day');
      expect(find.text(formatLong(today())), findsOneWidget);
    });

    testWidgets('lỗi tải S04 có Thử lại', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      app.services.faults.set(FaultPoint.loadLog, true);
      await app.tapKey('tab-log');
      expect(find.text('Chưa tải được nhật ký.'), findsOneWidget);
      await app.tapText('Thử lại');
      expect(find.text('Chưa có bữa ăn nào'), findsOneWidget);
    });
  });

  group('F03 Từ kiến thức đến kế hoạch', () {
    testWidgets('S08 → S09 → S06 → S07 → S06 đúng ngày và slot', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      await app.tapKey('tab-library');
      await app.tapKey('article-read');
      expect(app.path, '/library/who-diverse');
      expect(find.text('Xem nguồn WHO'), findsOneWidget);

      await app.tapKey('article-plan');
      expect(app.path, '/article-plan');
      expect(find.byTooltip('Quay lại'), findsOneWidget);

      await app.tapKey('choose-breakfast');
      await app.tapKey('pick-toast-egg');
      expect(app.path, '/plan/recipe/toast-egg');
      await app.tapKey('recipe-add');

      expect(app.path, '/article-plan');
      expect(find.text('Đã thêm món vào kế hoạch.'), findsOneWidget);
      expect(find.text('Bánh mì và trứng'), findsWidgets);
      expect(
        app.services.plans.recipeAt(
          'demo-user',
          dateKey(today()),
          PlanSlot.breakfast,
        ),
        'toast-egg',
      );
      expect(app.eventNames, contains('plan_from_article'));
      final event = app.analytics.events.firstWhere(
        (e) => e.name == 'plan_slot_saved',
      );
      expect(event.parameters['source'], 'article');
      expect(event.parameters['action'], 'add');

      await app.tapBack();
      expect(app.path, '/library/who-diverse');
    });

    testWidgets('thay món: Hủy giữ món cũ, Thay thế đổi đúng slot', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      final key = dateKey(today());
      await app.setPlan(key, PlanSlot.lunch, 'toast-egg');
      await app.setPlan(key, PlanSlot.dinner, 'toast-egg');
      await app.tapKey('tab-plan');

      await app.tapKey('plan-open-suggestion');
      await app.tapKey('recipe-slot-lunch');
      await app.tapKey('recipe-add');
      expect(find.text('Thay thế món hiện tại?'), findsOneWidget);
      expect(find.textContaining('bữa Trưa'), findsOneWidget);

      await app.tapKey('replace-cancel');
      expect(app.path, '/plan/recipe/rice-veg-beans');
      expect(app.services.plans.recipeAt('demo-user', key, PlanSlot.lunch), 'toast-egg');

      await app.tapKey('recipe-add');
      await app.tapKey('replace-confirm');
      expect(app.path, '/plan');
      expect(find.text('Đã thay thế món trong kế hoạch.'), findsOneWidget);
      expect(
        app.services.plans.recipeAt('demo-user', key, PlanSlot.lunch),
        'rice-veg-beans',
      );
      expect(app.services.plans.recipeAt('demo-user', key, PlanSlot.dinner), 'toast-egg');
    });

    testWidgets('lưu kế hoạch lỗi giữ lựa chọn, thử lại thành công', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      await app.tapKey('tab-plan');
      await app.tapKey('plan-open-suggestion');
      await app.tapKey('recipe-slot-breakfast');

      app.services.faults.set(FaultPoint.savePlan, true);
      await app.tapKey('recipe-add');
      expect(find.byKey(const Key('plan-save-error')), findsOneWidget);
      expect(app.eventNames, contains('plan_save_failed'));

      await app.tapKey('plan-retry');
      expect(app.path, '/plan');
      expect(
        app.services.plans.recipeAt('demo-user', dateKey(today()), PlanSlot.breakfast),
        'rice-veg-beans',
      );
    });

    testWidgets('chuyển tuần giữ đúng khoảng ngày', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      await app.tapKey('tab-plan');
      final monday = startOfWeek(today());
      await app.tapKey('plan-next-week');
      final expected =
          '${formatDayMonth(addDays(monday, 7))} – ${formatDate(addDays(monday, 13))}';
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('lỗi tải S06, S07, S08, S09 đều có Thử lại', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);

      app.services.faults.set(FaultPoint.loadPlan, true);
      await app.tapKey('tab-plan');
      expect(find.text('Chưa tải được kế hoạch.'), findsOneWidget);
      await app.tapText('Thử lại');
      expect(find.text('Chưa tải được kế hoạch.'), findsNothing);

      app.services.faults.set(FaultPoint.loadDetail, true);
      await app.tapKey('plan-open-suggestion');
      expect(find.text('Chưa tải được công thức.'), findsOneWidget);
      await app.tapBack();
      expect(app.path, '/plan');

      app.services.faults.set(FaultPoint.loadLibrary, true);
      await app.tapKey('tab-library');
      expect(find.text('Chưa tải được thư viện.'), findsOneWidget);
      await app.tapText('Thử lại');

      app.services.faults.set(FaultPoint.loadDetail, true);
      await app.tapKey('article-read');
      expect(find.text('Chưa tải được bài viết.'), findsOneWidget);
      await app.tapText('Thử lại');
      expect(find.text('Xem nguồn WHO'), findsOneWidget);
    });

    testWidgets('tìm kiếm không dấu, rỗng thì có Xóa tìm kiếm', (tester) async {
      final app = await pumpApp(tester, signedIn: true, onboarded: true);
      await app.tapKey('tab-library');

      await app.enter('library-search', 'dia an can bang');
      expect(find.text('Gợi ý xây dựng đĩa ăn cân bằng'), findsOneWidget);
      expect(find.text('Bữa ăn đa dạng bắt đầu từ đâu?'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      final search = app.analytics.events.firstWhere(
        (e) => e.name == 'article_search',
      );
      expect(search.parameters.keys, ['result_count']);

      await app.enter('library-search', 'không có bài này');
      expect(find.text('Không tìm thấy bài viết phù hợp'), findsOneWidget);
      await app.tapText('Xóa tìm kiếm');
      expect(find.text('Bữa ăn đa dạng bắt đầu từ đâu?'), findsOneWidget);
    });

    testWidgets('link ngoài lỗi thì báo, không crash', (tester) async {
      final opened = <Uri>[];
      final app = await pumpApp(
        tester,
        signedIn: true,
        onboarded: true,
        linkOpener: (uri) async {
          opened.add(uri);
          return false;
        },
      );
      await app.tapKey('tab-library');
      await app.tapKey('article-harvard-plate');
      expect(opened.single.host, 'nutritionsource.hsph.harvard.edu');
      expect(find.textContaining('Không mở được đường dẫn'), findsOneWidget);
    });
  });

  testWidgets('Analytics không gửi email, tên hay nội dung món', (tester) async {
    final app = await pumpApp(tester, signedIn: true, onboarded: true);
    await app.tapKey('tab-log');
    await app.tapKey('log-add-meal');
    await app.tapKey('meal-type-lunch');
    await app.enter('meal-description', 'Bữa của tôi');
    await app.tapKey('meal-save');

    expect(app.analytics.userId, 'demo-user');
    expect(app.crash.userId, 'demo-user');
    final sent = app.analytics.events
        .expand((e) => [e.name, ...e.parameters.values.map((v) => '$v')])
        .join('|');
    for (final value in _pii) {
      expect(sent, isNot(contains(value)));
    }
    expect(app.crash.keys['route'], isNotNull);
    expect(app.analytics.screens, contains('/log/add'));
  });
}
