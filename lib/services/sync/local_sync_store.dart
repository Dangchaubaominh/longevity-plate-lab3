import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../app_failure.dart';

String syncId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

/// SQLite is authoritative when API sync is enabled. An edit and its outbox
/// operation are committed in the same transaction; SharedPreferences remains
/// an untouched legacy backup after the one-time, per-user migration.
class LocalSyncStore extends ChangeNotifier {
  LocalSyncStore(this.db, this.currentUid);
  final Database db;
  final String? Function() currentUid;
  String? _activeUid;
  final Map<String, Map<String, dynamic>> _cache = {};
  int localChanges = 0;

  static Future<LocalSyncStore> open(String? Function() currentUid) async {
    final root = await getDatabasesPath();
    final db = await openDatabase(
      '$root/longevity_sync.db',
      version: 2,
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE local_records ADD COLUMN photo_base_version INTEGER',
          );
        }
      },
      onCreate: (db, _) async {
        await createSchema(db);
      },
    );
    return LocalSyncStore(db, currentUid);
  }

  static Future<void> createSchema(Database db) async {
    await db.execute(
      'CREATE TABLE local_records(uid TEXT NOT NULL,kind TEXT NOT NULL,id TEXT NOT NULL,data_json TEXT NOT NULL,server_version INTEGER NOT NULL DEFAULT 0,local_sequence INTEGER NOT NULL DEFAULT 0,deleted INTEGER NOT NULL DEFAULT 0,asset_id TEXT,photo_base_version INTEGER,conflict_json TEXT,PRIMARY KEY(uid,kind,id))',
    );
    await db.execute(
      'CREATE TABLE outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT,uid TEXT NOT NULL,kind TEXT NOT NULL,record_id TEXT NOT NULL,op_id TEXT NOT NULL UNIQUE,payload_json TEXT NOT NULL,base_version INTEGER NOT NULL,local_sequence INTEGER NOT NULL,deleted INTEGER NOT NULL DEFAULT 0,state TEXT NOT NULL DEFAULT \'pending\',attempts INTEGER NOT NULL DEFAULT 0,frozen INTEGER NOT NULL DEFAULT 0,next_at INTEGER NOT NULL DEFAULT 0,last_error TEXT)',
    );
    await db.execute('CREATE INDEX outbox_owner ON outbox(uid,state,seq)');
    await db.execute(
      'CREATE TABLE sync_meta(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
    );
  }

  void check(String uid) {
    if (currentUid() != uid || _activeUid != uid) {
      throw const AppFailure('sync_session_changed');
    }
  }

  String _key(String kind, String id) => '$kind:$id';
  Map<String, dynamic>? get(String uid, String kind, String id) {
    check(uid);
    final row = _cache[_key(kind, id)];
    return row == null || row['deleted'] == 1
        ? null
        : Map<String, dynamic>.from(row);
  }

  List<Map<String, dynamic>> all(String uid, String kind) {
    check(uid);
    return [
      for (final row in _cache.values)
        if (row['kind'] == kind && row['deleted'] != 1)
          Map<String, dynamic>.from(row),
    ];
  }

  Map<String, dynamic> data(Map<String, dynamic> row) =>
      Map<String, dynamic>.from(jsonDecode(row['data_json'] as String) as Map);
  String status(String uid, String kind, String id) {
    check(uid);
    return _cache[_key(kind, id)]?['sync_status'] as String? ?? 'synced';
  }

  Future<void> activate(String uid, SharedPreferences prefs) async {
    if (currentUid() != uid) throw const AppFailure('sync_session_changed');
    _activeUid = uid;
    _cache.clear();
    await db.transaction((tx) async {
      final migrated = await tx.query(
        'sync_meta',
        where: 'key=?',
        whereArgs: ['$uid:migrated'],
      );
      if (migrated.isNotEmpty) return;
      final meals = prefs.getString('$uid.meals');
      if (meals != null) {
        for (final item in jsonDecode(meals) as List) {
          final value = Map<String, dynamic>.from(item as Map);
          if (value['id'] is! String ||
              value['date'] is! String ||
              value['description'] is! String ||
              value['createdAt'] is! String) {
            throw const AppFailure('invalid_legacy_data');
          }
          await _write(tx, uid, 'meal', value['id'] as String, value, false);
        }
      }
      final goals = prefs.getStringList('$uid.goals');
      if (goals != null && goals.isNotEmpty) {
        await _write(tx, uid, 'goals', 'self', {'goals': goals}, false);
      }
      final plans = prefs.getString('$uid.plan');
      if (plans != null) {
        final days = Map<String, dynamic>.from(jsonDecode(plans) as Map);
        for (final day in days.entries) {
          for (final slot in Map<String, dynamic>.from(
            day.value as Map,
          ).entries) {
            await _write(tx, uid, 'plan', '${day.key}_${slot.key}', {
              'date': day.key,
              'slot': slot.key,
              'recipeId': slot.value,
            }, false);
          }
        }
      }
      await tx.insert('sync_meta', {'key': '$uid:migrated', 'value': '1'});
    });
    check(uid);
    await _reload(uid);
  }

  void deactivate() {
    _activeUid = null;
    _cache.clear();
    notifyListeners();
  }

  Future<void> write(
    String uid,
    String kind,
    String id,
    Map<String, dynamic> value, {
    bool deleted = false,
  }) async {
    check(uid);
    await db.transaction((tx) => _write(tx, uid, kind, id, value, deleted));
    localChanges++;
    if (currentUid() == uid && _activeUid == uid) await _reload(uid);
  }

  Future<void> _write(
    Transaction tx,
    String uid,
    String kind,
    String id,
    Map<String, dynamic> value,
    bool deleted,
  ) async {
    final existing = await tx.query(
      'local_records',
      where: 'uid=? AND kind=? AND id=?',
      whereArgs: [uid, kind, id],
    );
    final row = existing.firstOrNull;
    final sequence = (row?['local_sequence'] as int? ?? 0) + 1;
    final version = row?['server_version'] as int? ?? 0;
    await tx.insert('local_records', {
      'uid': uid,
      'kind': kind,
      'id': id,
      'data_json': jsonEncode(value),
      'server_version': version,
      'local_sequence': sequence,
      'deleted': deleted ? 1 : 0,
      'asset_id': row?['asset_id'],
      'photo_base_version': row?['photo_base_version'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final coalesce = await tx.query(
      'outbox',
      where:
          "uid=? AND kind=? AND record_id=? AND frozen=0 AND state='pending'",
      whereArgs: [uid, kind, id],
      orderBy: 'seq DESC',
      limit: 1,
    );
    final payload = jsonEncode(serverData(kind, value));
    if (coalesce.isNotEmpty) {
      await tx.update(
        'outbox',
        {
          'payload_json': payload,
          'deleted': deleted ? 1 : 0,
          'local_sequence': sequence,
        },
        where: 'seq=?',
        whereArgs: [coalesce.first['seq']],
      );
    } else {
      await tx.insert('outbox', {
        'uid': uid,
        'kind': kind,
        'record_id': id,
        'op_id': syncId(),
        'payload_json': payload,
        'base_version': version,
        'local_sequence': sequence,
        'deleted': deleted ? 1 : 0,
      });
    }
  }

  static Map<String, dynamic> serverData(
    String kind,
    Map<String, dynamic> value,
  ) => switch (kind) {
    'meal' => {
      'date': value['date'],
      'type': value['type'],
      'description': value['description'],
    },
    'plan' => {
      'date': value['date'],
      'slot': value['slot'],
      'recipeId': value['recipeId'],
    },
    'goals' => {'goals': value['goals']},
    'profile' => {
      'displayName': value['displayName'],
      'timezone': value['timezone'] ?? 'Asia/Bangkok',
    },
    _ => throw const AppFailure('invalid_sync_kind'),
  };

  Future<Map<String, dynamic>?> next(String uid) async {
    check(uid);
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction((tx) async {
      final rows = await tx.query(
        'outbox',
        where: "uid=? AND state='pending' AND attempts<3 AND next_at<=? AND NOT EXISTS(SELECT 1 FROM outbox older WHERE older.uid=outbox.uid AND older.kind=outbox.kind AND older.record_id=outbox.record_id AND older.seq<outbox.seq)",
        whereArgs: [uid, now],
        orderBy: 'seq',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = Map<String, dynamic>.from(rows.first);
      await tx.update(
        'outbox',
        {
          'state': 'inflight',
          'frozen': 1,
          'attempts': (row['attempts'] as int) + 1,
        },
        where: 'seq=?',
        whereArgs: [row['seq']],
      );
      row['attempts'] = (row['attempts'] as int) + 1;
      return row;
    });
  }

  Map<String, dynamic> operation(Map<String, dynamic> row) => {
    'opId': row['op_id'],
    'kind': row['kind'],
    'id': row['record_id'],
    'baseVersion': row['base_version'],
    'deleted': row['deleted'] == 1,
    'data': row['deleted'] == 1
        ? <String, dynamic>{}
        : jsonDecode(row['payload_json'] as String),
  };
  Future<void> acknowledge(
    String uid,
    Map<String, dynamic> op,
    Map<String, dynamic> remote,
  ) async {
    check(uid);
    await db.transaction((tx) async {
      await tx.delete(
        'outbox',
        where: 'uid=? AND seq=?',
        whereArgs: [uid, op['seq']],
      );
      await tx.update(
        'local_records',
        {'server_version': remote['version']},
        where: 'uid=? AND kind=? AND id=?',
        whereArgs: [uid, op['kind'], op['record_id']],
      );
      // Only rebase queued edits that follow our own successful mutation.
      await tx.update(
        'outbox',
        {'base_version': remote['version']},
        where: 'uid=? AND kind=? AND record_id=? AND frozen=0 AND seq>?',
        whereArgs: [uid, op['kind'], op['record_id'], op['seq']],
      );
      await _remote(tx, uid, remote);
      if (op['kind'] == 'meal') {
        await tx.update(
          'local_records',
          {'photo_base_version': remote['version']},
          where: 'uid=? AND kind=? AND id=? AND asset_id IS NULL',
          whereArgs: [uid, op['kind'], op['record_id']],
        );
      }
    });
    await _reload(uid);
  }

  Future<void> fail(
    String uid,
    Map<String, dynamic> op,
    String code, {
    bool retryable = true,
    Map<String, dynamic>? current,
  }) async {
    check(uid);
    final conflict =
        code == 'version_conflict' || code == 'idempotency_conflict';
    await db.transaction((tx) async {
      await tx.update(
        'outbox',
        {
          'state': conflict
              ? 'conflict'
              : retryable && (op['attempts'] as int) < 3
              ? 'pending'
              : 'failed',
          'next_at':
              DateTime.now().millisecondsSinceEpoch +
              1000 * (1 << (op['attempts'] as int)),
          'last_error': code,
        },
        where: 'uid=? AND seq=?',
        whereArgs: [uid, op['seq']],
      );
      if (conflict) {
        await tx.update(
          'local_records',
          {'conflict_json': jsonEncode(current)},
          where: 'uid=? AND kind=? AND id=?',
          whereArgs: [uid, op['kind'], op['record_id']],
        );
      }
    });
    await _reload(uid);
  }

  Future<void> recover(String uid) async {
    check(uid);
    await db.update(
      'outbox',
      {'state': 'pending'},
      where: "uid=? AND state='inflight'",
      whereArgs: [uid],
    );
    await _reload(uid);
  }

  Future<void> retry(String uid) async {
    check(uid);
    await db.update(
      'outbox',
      {'state': 'pending', 'attempts': 0, 'next_at': 0},
      where: "uid=? AND state='failed'",
      whereArgs: [uid],
    );
    await _reload(uid);
  }

  Future<void> applyPull(
    String uid,
    List<Map<String, dynamic>> records,
    int cursor,
  ) async {
    check(uid);
    await db.transaction((tx) async {
      for (final item in records) {
        await _remote(tx, uid, item);
      }
      await tx.insert('sync_meta', {
        'key': '$uid:cursor',
        'value': '$cursor',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await _reload(uid);
  }

  Future<void> _remote(
    Transaction tx,
    String uid,
    Map<String, dynamic> remote,
  ) async {
    final kind = remote['kind'] as String, id = remote['id'] as String;
    final pending = await tx.query(
      'outbox',
      where: 'uid=? AND kind=? AND record_id=?',
      whereArgs: [uid, kind, id],
      limit: 1,
    );
    final existing = await tx.query(
      'local_records',
      where: 'uid=? AND kind=? AND id=?',
      whereArgs: [uid, kind, id],
    );
    final old = existing.firstOrNull;
    if ((old?['server_version'] as int? ?? 0) > (remote['version'] as int)) {
      return;
    }
    final asset = (remote['photoAsset'] as Map?)?['id'] as String?;
    if (pending.isNotEmpty) {
      await tx.update(
        'local_records',
        {'server_version': remote['version']},
        where: 'uid=? AND kind=? AND id=?',
        whereArgs: [uid, kind, id],
      );
      return;
    }
    final data = Map<String, dynamic>.from(remote['data'] as Map);
    final previousData = old == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(
            jsonDecode(old['data_json'] as String) as Map,
          );
    final pendingLocalPhoto =
        kind == 'meal' &&
        previousData['imagePath'] != null &&
        old?['asset_id'] == null;
    if (kind == 'meal') {
      final previous = old == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(
              jsonDecode(old['data_json'] as String) as Map,
            );
      data['id'] = id;
      data['createdAt'] =
          previous['createdAt'] ?? remote['createdAt'] ?? remote['updatedAt'];
      if (previous['imagePath'] != null &&
          (old?['asset_id'] == null || asset == old?['asset_id'])) {
        data['imagePath'] = previous['imagePath'];
      }
    }
    await tx.insert('local_records', {
      'uid': uid,
      'kind': kind,
      'id': id,
      'data_json': jsonEncode(data),
      'server_version': remote['version'],
      'local_sequence': old?['local_sequence'] ?? 0,
      'deleted': remote['deletedAt'] == null ? 0 : 1,
      'asset_id': pendingLocalPhoto ? null : asset,
      'photo_base_version': old?['photo_base_version'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> cursor(String uid) async {
    check(uid);
    final rows = await db.query(
      'sync_meta',
      where: 'key=?',
      whereArgs: ['$uid:cursor'],
    );
    return int.tryParse(rows.firstOrNull?['value'] as String? ?? '0') ?? 0;
  }

  Future<String?> meta(String key) async {
    final rows = await db.query('sync_meta', where: 'key=?', whereArgs: [key]);
    return rows.firstOrNull?['value'] as String?;
  }

  Future<void> setMeta(String key, String value) => db
      .insert('sync_meta', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<List<Map<String, dynamic>>> pending(String uid) async {
    check(uid);
    return db.query('outbox', where: 'uid=?', whereArgs: [uid], orderBy: 'seq');
  }

  Future<void> resolve(
    String uid,
    String kind,
    String id, {
    required bool keepLocal,
  }) async {
    check(uid);
    await db.transaction((tx) async {
      final rows = await tx.query(
        'local_records',
        where: 'uid=? AND kind=? AND id=?',
        whereArgs: [uid, kind, id],
      );
      if (rows.isEmpty) return;
      final row = rows.first;
      final raw = row['conflict_json'] as String?;
      if (raw == null || raw == 'null') {
        throw const AppFailure('conflict_requires_refresh');
      }
      final current = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      await tx.delete(
        'outbox',
        where: 'uid=? AND kind=? AND record_id=?',
        whereArgs: [uid, kind, id],
      );
      if (keepLocal) {
        await tx.update(
          'local_records',
          {'server_version': current['version'], 'conflict_json': null},
          where: 'uid=? AND kind=? AND id=?',
          whereArgs: [uid, kind, id],
        );
        await _write(
          tx,
          uid,
          kind,
          id,
          Map<String, dynamic>.from(
            jsonDecode(row['data_json'] as String) as Map,
          ),
          row['deleted'] == 1,
        );
      } else {
        await _remote(tx, uid, current);
      }
    });
    await _reload(uid);
  }

  Future<void> setAsset(
    String uid,
    String id,
    String assetId,
    int version,
  ) async {
    check(uid);
    await db.update(
      'local_records',
      {'asset_id': assetId, 'server_version': version},
      where: "uid=? AND kind='meal' AND id=?",
      whereArgs: [uid, id],
    );
    await _reload(uid);
  }

  Future<void> resolvePhoto(
    String uid,
    String id,
    Map<String, dynamic> remote, {
    required bool keepLocal,
  }) async {
    check(uid);
    final row = get(uid, 'meal', id);
    if (row == null) return;
    final value = data(row);
    if (!keepLocal) value.remove('imagePath');
    await db.update(
      'local_records',
      {
        'data_json': jsonEncode(value),
        'photo_base_version': remote['version'],
        'asset_id': keepLocal ? null : (remote['photoAsset'] as Map?)?['id'],
      },
      where: "uid=? AND kind='meal' AND id=?",
      whereArgs: [uid, id],
    );
    if (!keepLocal) await db.transaction((tx) => _remote(tx, uid, remote));
    await _reload(uid);
  }

  Future<void> _reload(String uid) async {
    final rows = await db.rawQuery(
      "SELECT r.*,CASE WHEN EXISTS(SELECT 1 FROM outbox o WHERE o.uid=r.uid AND o.kind=r.kind AND o.record_id=r.id AND o.state='conflict') THEN 'conflict' WHEN EXISTS(SELECT 1 FROM outbox o WHERE o.uid=r.uid AND o.kind=r.kind AND o.record_id=r.id AND o.state='failed') THEN 'failed' WHEN EXISTS(SELECT 1 FROM outbox o WHERE o.uid=r.uid AND o.kind=r.kind AND o.record_id=r.id) THEN 'pending' ELSE 'synced' END AS sync_status FROM local_records r WHERE r.uid=?",
      [uid],
    );
    if (_activeUid != uid || currentUid() != uid) return;
    _cache
      ..clear()
      ..addEntries(
        rows.map(
          (row) => MapEntry(
            _key(row['kind'] as String, row['id'] as String),
            Map<String, dynamic>.from(row),
          ),
        ),
      );
    notifyListeners();
  }

  Future<void> close() => db.close();
}
