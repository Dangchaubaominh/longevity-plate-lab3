// Real-device/staging test. Requires the tester to sign in with Google.
// No fake services, bypass tokens, or production credentials are supplied here.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:longevity_plate/main.dart' as app;
import 'package:longevity_plate/app/app.dart';
import 'package:longevity_plate/core/dates.dart';
import 'package:longevity_plate/models/models.dart';
import 'package:longevity_plate/services/device_meal_photo_service.dart';
import 'package:longevity_plate/services/sync/local_sync_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real Firebase → D1 meal → Cloudinary photo → owner read → tombstone',
    (tester) async {
      const api = String.fromEnvironment('API_BASE_URL');
      expect(
        api,
        isNotEmpty,
        reason: 'Pass the staging Worker URL through API_BASE_URL.',
      );
      await app.main();
      await tester.pumpAndSettle();
      final services = tester
          .widget<LongevityPlateApp>(find.byType(LongevityPlateApp))
          .services;
      expect(services.isFake, false);
      expect(services.backend, isNotNull);
      // Sign in on the real device while this bounded wait runs.
      final until = DateTime.now().add(const Duration(minutes: 2));
      while (services.auth.currentUser == null &&
          DateTime.now().isBefore(until)) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      final uid = services.auth.currentUser?.uid;
      expect(
        uid,
        isNotNull,
        reason: 'Google sign-in is required on the device.',
      );
      await services.sync!.activate(uid!);
      final id = 'acceptance_${syncId()}';
      try {
        await services.meals.add(
          uid,
          id: id,
          date: dateKey(today()),
          type: MealType.lunch,
          description: 'Nghiệm thu staging tự động',
        );
        await services.sync!.retryAll();
        final meal = await services.backend!.call(uid, '/meals/$id');
        final version = ((meal['record'] as Map)['version'] as num).toInt();
        final input = await rootBundle.load('assets/images/bowl.png');
        final jpeg = await DeviceMealPhotoService.normalizePhoto(
          input.buffer.asUint8List(),
        );
        final result = await services.backend!.upload(
          uid,
          bytes: jpeg,
          kind: 'photo',
          mealId: id,
          mealVersion: version,
        );
        final asset = (result['asset'] as Map)['id'] as String;
        expect(await services.backend!.image(uid, asset), isNotEmpty);
        final me = await services.backend!.call(uid, '/me');
        expect(me['uid'], uid);
      } finally {
        await services.sync!.synchronize();
        await services.meals.delete(uid, id);
        await services.sync!.retryAll();
      }
      expect(find.byType(MaterialApp), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
