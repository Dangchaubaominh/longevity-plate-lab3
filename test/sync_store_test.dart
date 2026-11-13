import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:longevity_plate/services/sync/local_sync_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late LocalSyncStore store;
  late SharedPreferences prefs;
  String? uid = 'alice';
  final meal = <String, dynamic>{
    'id': 'm1',
    'date': '2026-11-13',
    'type': 'lunch',
    'description': 'Cơm rau',
    'createdAt': '2026-11-13T12:00:00.000',
  };
  Map<String, dynamic> remote(
    int version, {
    String description = 'Server',
    String? asset,
    bool deleted = false,
  }) => {
    'kind': 'meal',
    'id': 'm1',
    'version': version,
    'data': {'date': '2026-11-13', 'type': 'lunch', 'description': description},
    'createdAt': '2026-11-13T12:00:00.000Z',
    'updatedAt': '2026-11-13T12:30:00.000Z',
    'deletedAt': deleted ? '2026-11-13T12:30:00Z' : null,
    if (asset != null) 'photoAsset': {'id': asset},
  };
  setUp(() async {
    uid = 'alice';
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => LocalSyncStore.createSchema(db),
      ),
    );
    store = LocalSyncStore(db, () => uid);
    await store.activate('alice', prefs);
  });
  tearDown(() async {
    await store.close();
    store.dispose();
  });

  test('local write and durable operation commit together; unsent changes coalesce', () async {
    await store.write('alice', 'meal', 'm1', meal);
    await store.write('alice', 'meal', 'm1', {...meal, 'description': 'Mới'});
    expect(store.data(store.get('alice', 'meal', 'm1')!)['description'], 'Mới');
    expect(await store.pending('alice'), hasLength(1));
    expect(store.status('alice', 'meal', 'm1'), 'pending');
    final op = await store.next('alice');
    expect(store.operation(op!)['data'], {
      'date': '2026-11-13',
      'type': 'lunch',
      'description': 'Mới',
    });
  });
  test(
    'failed outbox insert rolls back the matching business record',
    () async {
      await store.db.execute(
        "CREATE TRIGGER fail_outbox BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT,'disk simulation'); END",
      );
      await expectLater(
        store.write('alice', 'meal', 'm1', meal),
        throwsA(isA<DatabaseException>()),
      );
      expect(await store.db.query('local_records'), isEmpty);
      expect(await store.pending('alice'), isEmpty);
    },
  );
  test(
    'frozen retry preserves op ID and payload while a later edit waits',
    () async {
      await store.write('alice', 'meal', 'm1', meal);
      final first = (await store.next('alice'))!;
      await store.write('alice', 'meal', 'm1', {
        ...meal,
        'description': 'Second edit',
      });
      expect(await store.next('alice'), isNull);
      await store.fail('alice', first, 'network', retryable: true);
      await store.db.update('outbox', {'next_at': 0});
      final retry = (await store.next('alice'))!;
      expect(store.operation(retry), store.operation(first));
      await store.acknowledge(
        'alice',
        retry,
        remote(1, description: 'Cơm rau'),
      );
      expect(
        store.data(store.get('alice', 'meal', 'm1')!)['description'],
        'Second edit',
      );
      final second = (await store.next('alice'))!;
      expect(second['base_version'], 1);
      expect(second['op_id'], isNot(first['op_id']));
    },
  );
  test('remote edits never overwrite pending local edits and conflict needs a choice', () async {
    await store.write('alice', 'meal', 'm1', meal);
    final op = (await store.next('alice'))!;
    await store.applyPull('alice', [remote(2)], 8);
    expect(
      store.data(store.get('alice', 'meal', 'm1')!)['description'],
      'Cơm rau',
    );
    expect(op['base_version'], 0);
    expect(await store.cursor('alice'), 8);
    await store.fail('alice', op, 'version_conflict', current: remote(2));
    expect(store.status('alice', 'meal', 'm1'), 'conflict');
    await store.resolve('alice', 'meal', 'm1', keepLocal: true);
    final replacement = (await store.next('alice'))!;
    expect(replacement['base_version'], 2);
    expect(replacement['op_id'], isNot(op['op_id']));
  });
  test(
    'choose server clears conflicting operation and applies tombstone',
    () async {
      await store.write('alice', 'meal', 'm1', meal);
      final op = (await store.next('alice'))!;
      await store.fail(
        'alice',
        op,
        'version_conflict',
        current: remote(2, deleted: true),
      );
      await store.resolve('alice', 'meal', 'm1', keepLocal: false);
      expect(store.get('alice', 'meal', 'm1'), isNull);
      expect(await store.pending('alice'), isEmpty);
    },
  );
  test('UID switch isolates memory, cursor, outbox and writes', () async {
    await store.write('alice', 'meal', 'm1', meal);
    await store.applyPull('alice', [], 9);
    uid = 'bob';
    await store.activate('bob', prefs);
    expect(store.all('bob', 'meal'), isEmpty);
    expect(await store.cursor('bob'), 0);
    expect(() => store.all('alice', 'meal'), throwsException);
    await expectLater(
      store.write('alice', 'meal', 'm2', meal),
      throwsException,
    );
    uid = 'alice';
    await store.activate('alice', prefs);
    expect(store.all('alice', 'meal'), hasLength(1));
    expect(await store.pending('alice'), hasLength(1));
  });
  test(
    'per-UID migration is idempotent and never deletes the old backup',
    () async {
      await prefs.setString('bob.meals', jsonEncode([meal]));
      await prefs.setStringList('bob.goals', ['logMeals']);
      await prefs.setString(
        'bob.plan',
        jsonEncode({
          '2026-11-13': {'lunch': 'rice-veg-beans'},
        }),
      );
      uid = 'bob';
      await store.activate('bob', prefs);
      expect(await store.pending('bob'), hasLength(3));
      await store.activate('bob', prefs);
      expect(await store.pending('bob'), hasLength(3));
      expect(prefs.getString('bob.meals'), isNotNull);
    },
  );
  test(
    'invalid legacy data rolls back migration without losing source data',
    () async {
      await prefs.setString(
        'bob.meals',
        jsonEncode([
          meal,
          {'id': null},
        ]),
      );
      uid = 'bob';
      await expectLater(store.activate('bob', prefs), throwsException);
      expect(
        await store.db.query(
          'local_records',
          where: 'uid=?',
          whereArgs: ['bob'],
        ),
        isEmpty,
      );
      expect(await store.meta('bob:migrated'), isNull);
      expect(prefs.getString('bob.meals'), isNotNull);
    },
  );
  test('photo base revision survives unrelated remote changes', () async {
    await store.write('alice', 'meal', 'm1', {
      ...meal,
      'imagePath': 'meal_photos/alice/saved/a.jpg',
    });
    final op = (await store.next('alice'))!;
    await store.acknowledge('alice', op, remote(1));
    await store.applyPull('alice', [remote(2)], 2);
    expect(store.get('alice', 'meal', 'm1')!['photo_base_version'], 1);
    await store.resolvePhoto(
      'alice',
      'm1',
      remote(2, asset: 'new'),
      keepLocal: false,
    );
    expect(store.data(store.get('alice', 'meal', 'm1')!)['imagePath'], isNull);
    expect(store.get('alice', 'meal', 'm1')!['asset_id'], 'new');
  });
  test('deleted remote asset clears an old local cache instead of uploading it again', () async {
    await store.applyPull('alice', [remote(1, asset: 'old')], 1);
    final row = store.get('alice', 'meal', 'm1')!;
    await store.db.update(
      'local_records',
      {
        'data_json': jsonEncode({
          ...store.data(row),
          'imagePath': 'cached-old.jpg',
        }),
      },
      where: 'uid=? AND id=?',
      whereArgs: ['alice', 'm1'],
    );
    await store.applyPull('alice', [remote(2)], 2);
    expect(store.data(store.get('alice', 'meal', 'm1')!)['imagePath'], isNull);
    expect(store.get('alice', 'meal', 'm1')!['asset_id'], isNull);
  });
  test(
    'remote attachment cannot silently replace an unsent local photo',
    () async {
      await store.write('alice', 'meal', 'm1', {
        ...meal,
        'imagePath': 'pending.jpg',
      });
      final op = (await store.next('alice'))!;
      await store.acknowledge('alice', op, remote(1));
      await store.applyPull('alice', [remote(2, asset: 'other-device')], 2);
      final row = store.get('alice', 'meal', 'm1')!;
      expect(row['asset_id'], isNull);
      expect(row['photo_base_version'], 1);
      expect(store.data(row)['imagePath'], 'pending.jpg');
    },
  );
  test(
    'local delete persists a tombstone operation; pull cannot resurrect it',
    () async {
      await store.applyPull('alice', [remote(1)], 1);
      await store.write('alice', 'meal', 'm1', meal, deleted: true);
      await store.applyPull('alice', [remote(2)], 2);
      expect(store.get('alice', 'meal', 'm1'), isNull);
      final op = (await store.next('alice'))!;
      expect(store.operation(op)['deleted'], true);
      expect(store.operation(op)['data'], isEmpty);
    },
  );
  test(
    'inflight operation survives database close and process-like restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('longevity-sync-test-');
      final path = '${dir.path}/durable.db';
      final db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => LocalSyncStore.createSchema(db),
        ),
      );
      final original = LocalSyncStore(db, () => uid);
      await original.activate('alice', prefs);
      await original.write('alice', 'meal', 'm1', meal);
      final op = (await original.next('alice'))!;
      await original.close();
      original.dispose();
      final restored = LocalSyncStore(
        await databaseFactoryFfi.openDatabase(path),
        () => uid,
      );
      await restored.activate('alice', prefs);
      await restored.recover('alice');
      final replay = (await restored.next('alice'))!;
      expect(restored.operation(replay), store.operation(op));
      await restored.close();
      restored.dispose();
      await dir.delete(recursive: true);
    },
  );
}
