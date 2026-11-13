import 'package:flutter_test/flutter_test.dart';
import 'package:longevity_plate/core/dates.dart';
import 'package:longevity_plate/models/models.dart';

import 'helpers.dart';

/// Nút xóa bữa ở S04 (hộp thoại xác nhận, gọi MealRepository.delete có sẵn).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hỏi xác nhận, Hủy thì giữ, Xóa thì mất khỏi S04', (
    tester,
  ) async {
    final app = await pumpApp(tester, signedIn: true, onboarded: true);
    await app.addMeal('demo-user', dateKey(today()), MealType.lunch, 'Cơm rau');
    await app.tapKey('tab-log');
    final id = app.services.meals
        .inRange('demo-user', today(), today())
        .single
        .id;

    await app.tapKey('meal-delete-$id');
    expect(find.text('Xóa bữa ăn này?'), findsOneWidget);
    await app.tapKey('meal-delete-cancel');
    expect(find.text('Cơm rau'), findsOneWidget);

    await app.tapKey('meal-delete-$id');
    await app.tapKey('meal-delete-confirm');
    expect(find.text('Cơm rau'), findsNothing);
    expect(find.text('Đã xóa bữa ăn'), findsOneWidget);
    expect(
      app.services.meals.inRange('demo-user', today(), today()),
      isEmpty,
    );
  });
}
