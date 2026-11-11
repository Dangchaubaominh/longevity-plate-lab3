import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:longevity_plate/core/dates.dart';
import 'package:longevity_plate/models/models.dart';

import 'helpers.dart';

void main() {
  // Lỗi tràn layout làm test thất bại. Chữ FlutterTest rộng hơn Roboto nên đây là
  // phép kiểm tra chặt hơn thực tế.
  for (final size in const [Size(360, 800), Size(412, 915), Size(800, 1000)]) {
    testWidgets('mọi màn không tràn layout ở ${size.width.toInt()}dp', (tester) async {
      final app = await pumpApp(tester, size: size);
      await app.tapKey('welcome-start');
      await app.tapKey('login-google');
      await app.tapKey('goal-logMeals');
      await app.tapKey('goals-submit');

      final key = dateKey(today());
      await app.addMeal(
        'demo-user',
        key,
        MealType.breakfast,
        'Cơm gạo lứt, rau luộc, đậu hũ và thêm một vài món khác nữa',
      );
      await app.setPlan(key, PlanSlot.lunch, 'rice-veg-beans');

      await app.tapKey('tab-log');
      await app.tapKey('log-add-meal');
      await app.tapKey('meal-save');
      await app.tapBack();
      await app.tapKey('tab-plan');
      await app.tapKey('view-lunch');
      await app.tapBack();
      await app.tapKey('tab-library');
      await app.tapKey('article-read');
      await app.tapKey('article-plan');
      await app.tapBack();
      await app.tapBack();
      await app.tapKey('open-notifications');
      await app.tapBack();
      await app.tapKey('open-account');
      await app.tapKey('demo-area');

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nút và điều khiển chính cao tối thiểu 48dp', (tester) async {
    final app = await pumpApp(tester, signedIn: true, onboarded: true);
    await app.tapKey('tab-log');
    await app.tapKey('log-add-meal');

    for (final key in ['meal-save', 'meal-date', 'meal-type-lunch']) {
      final height = tester.getSize(find.byKey(Key(key))).height;
      expect(height, greaterThanOrEqualTo(48), reason: key);
    }
    expect(tester.getSize(find.byKey(const Key('meal-save'))).height, 56);
  });

  testWidgets('đạt hướng dẫn về chạm và tương phản của Flutter', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await pumpApp(tester, signedIn: true, onboarded: true);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await app.tapKey('tab-plan');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
