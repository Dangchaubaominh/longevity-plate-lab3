import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:longevity_plate/models/models.dart';
import 'package:longevity_plate/services/repositories.dart';
import 'package:longevity_plate/app/app_services.dart';
import 'package:longevity_plate/services/fake_services.dart';
import 'package:longevity_plate/services/service_interfaces.dart';
import 'package:longevity_plate/services/sync/sync_engine.dart';
import 'package:longevity_plate/viewmodels/session_view_model.dart';
import 'package:longevity_plate/viewmodels/notifications_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'terminated push waits for account restoration before navigating',
    () async {
      SharedPreferences.setMockInitialValues({
        'demo-user.goals': ['logMeals'],
      });
      final services = AppServices.fake(
        await SharedPreferences.getInstance(),
        auth: FakeAuthService(initialUser: const AppUser(uid: 'demo-user')),
      );
      final gate = _RestoreGate();
      services.sync = gate;
      (services.messaging as FakeMessagingService).launchMessage =
          const PushMessage(
            id: 'startup',
            title: 'Tin',
            body: 'Body',
            route: '/library',
            targetUid: 'demo-user',
          );
      final session = SessionViewModel(services);
      final notifications = NotificationsViewModel(services, session);
      final routes = <String>[];
      notifications.onNavigate = routes.add;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(session.restoring, true);
      expect(routes, isEmpty);
      gate.complete.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(routes, ['/library']);
      notifications.dispose();
      session.dispose();
      gate.dispose();
    },
  );
  test(
    'push destination is retained until first onboarding completes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final services = AppServices.fake(
        await SharedPreferences.getInstance(),
        auth: FakeAuthService(initialUser: const AppUser(uid: 'demo-user')),
      );
      (services.messaging as FakeMessagingService).launchMessage =
          const PushMessage(
            id: 'first-login',
            title: 'Tin',
            body: 'Body',
            route: '/log',
            targetUid: 'demo-user',
          );
      final session = SessionViewModel(services);
      final notifications = NotificationsViewModel(services, session);
      final routes = <String>[];
      notifications.onNavigate = routes.add;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(routes, isEmpty);
      await services.goals.save('demo-user', {Goal.logMeals});
      session.refreshOnboarding();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(routes, ['/log']);
      notifications.dispose();
      session.dispose();
    },
  );
  test(
    'background queue cannot be adopted by a different signed-in owner',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = NotificationRepository(prefs);
      final item = AppNotification(
        id: 'same-id',
        title: 'Private A',
        body: 'A only',
        route: '/log',
        receivedAt: DateTime(2026, 11, 13),
      );
      await NotificationRepository.enqueueFromBackground(
        item,
        targetUid: 'alice',
      );
      expect(await repo.load('bob'), isEmpty);
      expect(await repo.load('alice'), hasLength(1));
      await NotificationRepository.enqueueFromBackground(
        item,
        targetUid: 'alice',
      );
      expect(await repo.load('alice'), hasLength(1));
      await NotificationRepository.enqueueFromBackground(item);
      expect(await repo.load('bob'), isEmpty);
    },
  );
  test(
    'server open acknowledgement merges read state without duplicate history',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = NotificationRepository(
        await SharedPreferences.getInstance(),
      );
      final item = AppNotification(
        id: 'n1',
        title: 'Test',
        body: 'Body',
        route: '/log',
        receivedAt: DateTime(2026, 11, 13),
      );
      await repo.add('alice', item);
      await repo.add('alice', item.markedRead());
      await repo.add('alice', item);
      final history = await repo.load('alice');
      expect(history, hasLength(1));
      expect(history.single.read, true);
      expect(await repo.load('bob'), isEmpty);
    },
  );
}

class _RestoreGate extends ChangeNotifier implements SyncEngine {
  final complete = Completer<void>();
  @override
  Future<void> activate(String uid) => complete.future;
  @override
  Future<void> deactivate() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
