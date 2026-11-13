import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:longevity_plate/models/models.dart';
import 'package:longevity_plate/services/app_failure.dart';
import 'package:longevity_plate/services/fake_services.dart';
import 'package:longevity_plate/services/fake_meal_photo_service.dart';
import 'package:longevity_plate/services/repositories.dart';
import 'package:longevity_plate/services/service_interfaces.dart';
import 'package:longevity_plate/services/sync/backend_api.dart';
import 'package:longevity_plate/services/sync/local_sync_store.dart';
import 'package:longevity_plate/services/sync/sync_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late FakeAuthService auth;
  late LocalSyncStore store;
  late SyncEngine engine;
  late SharedPreferences prefs;
  late Map<String, Map<String, dynamic>> records;
  late Map<String, Map<String, dynamic>> operations;
  var offline = false;
  var pulls = 0;
  var loseResponse = false;
  var concurrentRegistrations = 0, maxConcurrentRegistrations = 0;
  late List<int> deviceGenerations;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    auth = FakeAuthService(
      initialUser: const AppUser(uid: 'demo-user', displayName: 'Mai'),
    );
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => LocalSyncStore.createSchema(db),
      ),
    );
    store = LocalSyncStore(db, () => auth.currentUser?.uid);
    records = {};
    operations = {};
    offline = false;
    pulls = 0;
    loseResponse = false;
    deviceGenerations = [];
    concurrentRegistrations = 0;
    maxConcurrentRegistrations = 0;
    final api = BackendApi(
      baseUrl: 'https://test.backend',
      auth: auth,
      client: MockClient((r) async {
        if (offline) throw http.ClientException('offline');
        if (r.url.path.endsWith('/devices/register')) {
          final body = jsonDecode(r.body) as Map;
          deviceGenerations.add(body['generation'] as int);
          concurrentRegistrations++;
          if (concurrentRegistrations > maxConcurrentRegistrations) {
            maxConcurrentRegistrations = concurrentRegistrations;
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
          concurrentRegistrations--;
          return http.Response('{"registered":true}', 200);
        }
        if (r.url.path.endsWith('/sync/pull')) {
          pulls++;
          return http.Response(
            jsonEncode({
              'items': records.values.toList(),
              'nextCursor': records.length,
              'hasMore': false,
            }),
            200,
          );
        }
        if (r.url.path.endsWith('/sync/push')) {
          final op = Map<String, dynamic>.from(
            (jsonDecode(r.body)['operations'] as List).single as Map,
          );
          final key = '${op['kind']}:${op['id']}';
          final existing = records[key];
          if (operations[op['opId']] == null) {
            if ((existing?['version'] ?? 0) != op['baseVersion']) {
              return http.Response(
                jsonEncode({
                  'results': [
                    {
                      'opId': op['opId'],
                      'error': {'code': 'version_conflict'},
                      'current': existing,
                    },
                  ],
                }),
                200,
              );
            }
            final record = <String, dynamic>{
              'id': op['id'],
              'kind': op['kind'],
              'version': (existing?['version'] as int? ?? 0) + 1,
              'data': op['data'],
              'createdAt': '2026-11-13T12:00:00Z',
              'updatedAt': '2026-11-13T12:00:00Z',
              'deletedAt': op['deleted'] == true
                  ? '2026-11-13T12:00:00Z'
                  : null,
            };
            records[key] = record;
            operations[op['opId'] as String] = record;
          }
          if (loseResponse) {
            loseResponse = false;
            throw http.ClientException('response lost after commit');
          }
          return http.Response(
            jsonEncode({
              'results': [
                {'opId': op['opId'], 'record': operations[op['opId']]},
              ],
            }),
            200,
          );
        }
        return http.Response(
          '{"error":{"code":"provider_not_configured"}}',
          503,
        );
      }),
    );
    engine = SyncEngine(
      store: store,
      api: api,
      prefs: prefs,
      photos: FakeMealPhotoService(currentUid: () => auth.currentUser?.uid),
      messaging: FakeMessagingService(),
    );
    await engine.activate('demo-user');
    await engine.retryAll();
  });
  tearDown(() async {
    engine.dispose();
    await store.close();
    store.dispose();
  });
  test(
    'repository commits offline first, then engine uploads one stable mutation',
    () async {
      offline = true;
      final meals = MealRepository(prefs, FaultInjector(), sync: store);
      final saved = await meals.add(
        'demo-user',
        id: 'offline-meal',
        date: '2026-11-13',
        type: MealType.lunch,
        description: 'Rau',
      );
      await engine.synchronize();
      expect(saved.id, 'offline-meal');
      expect(await store.pending('demo-user'), hasLength(1));
      offline = false;
      await engine.retryAll();
      expect(await store.pending('demo-user'), isEmpty);
      expect(records['meal:offline-meal']!['version'], 1);
      meals.dispose();
    },
  );
  test('lost response is replayed with the same operation and never duplicates a meal', () async {
    await store.write('demo-user', 'meal', 'm1', {
      'id': 'm1',
      'date': '2026-11-13',
      'type': 'lunch',
      'description': 'Rau',
      'createdAt': '2026-11-13T12:00:00Z',
    });
    loseResponse = true;
    await engine.synchronize();
    expect(await store.pending('demo-user'), hasLength(1));
    await store.db.update('outbox', {'next_at': 0});
    await engine.synchronize();
    expect(await store.pending('demo-user'), isEmpty);
    expect(records['meal:m1']!['version'], 1);
    expect(records.keys.where((k) => k.startsWith('meal:')), hasLength(1));
  });
  test('goal and weekly plan repositories restore from the same authoritative cache', () async {
    final goals = GoalRepository(prefs, FaultInjector(), sync: store),
        plans = PlanRepository(prefs, FaultInjector(), sync: store);
    await goals.save('demo-user', {Goal.learn});
    await plans.setSlot(
      'demo-user',
      '2026-11-13',
      PlanSlot.lunch,
      'rice-veg-beans',
    );
    expect(goals.isOnboarded('demo-user'), true);
    expect(goals.load('demo-user'), {Goal.learn});
    expect(
      plans.recipeAt('demo-user', '2026-11-13', PlanSlot.lunch),
      'rice-veg-beans',
    );
    await engine.synchronize();
    expect(records['goals:self'], isNotNull);
    expect(records['plan:2026-11-13_lunch'], isNotNull);
    plans.dispose();
  });
  test(
    'missing photo retries are bounded and never remove the saved meal',
    () async {
      await store.write('demo-user', 'meal', 'missing-photo', {
        'id': 'missing-photo',
        'date': '2026-11-13',
        'type': 'lunch',
        'description': 'Rau',
        'createdAt': '2026-11-13T12:00:00Z',
        'imagePath': 'meal_photos/ZGVtby11c2Vy/saved/missing.jpg',
      });
      for (var n = 0; n < 4; n++) {
        await engine.synchronize();
      }
      expect(await store.meta('demo-user:photo-attempts:missing-photo'), '3');
      expect(store.get('demo-user', 'meal', 'missing-photo'), isNotNull);
      expect(records['meal:missing-photo'], isNotNull);
      expect(engine.pendingCount, 1);
    },
  );
  test('concurrent token refresh registrations serialize and use increasing generations', () async {
    (engine.messaging as FakeMessagingService).permission =
        PushPermission.granted;
    await Future.wait([
      engine.registerDevice('demo-user'),
      engine.registerDevice('demo-user'),
    ]);
    expect(deviceGenerations, [1, 2]);
    expect(maxConcurrentRegistrations, 1);
  });
  test(
    'pull and acknowledgements do not trigger an endless synchronization loop',
    () async {
      await engine.synchronize();
      final count = pulls;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(pulls, count);
    },
  );
  test('logout clears account memory and rejects late reads; durable old data stays isolated', () async {
    await engine.deactivate();
    await auth.signOut();
    expect(engine.uid, isNull);
    expect(() => store.all('demo-user', 'meal'), throwsException);
    expect(await store.db.query('local_records'), isNotEmpty);
  });
}
