import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_failure.dart';
import '../meal_photo_service.dart';
import '../service_interfaces.dart';
import 'backend_api.dart';
import 'local_sync_store.dart';

class SyncEngine extends ChangeNotifier {
  SyncEngine({
    required this.store,
    required this.api,
    required this.prefs,
    required this.photos,
    required this.messaging,
  }) {
    store.addListener(_changed);
    _tokens = messaging.tokenRefresh.listen((_) {
      final uid = _uid;
      if (uid != null) unawaited(registerDevice(uid));
    });
  }
  final LocalSyncStore store;
  final BackendApi api;
  final SharedPreferences prefs;
  final MealPhotoService photos;
  final MessagingService messaging;
  String? _uid;
  bool _disposed = false;
  Future<void>? _running;
  Timer? _timer;
  late final StreamSubscription<String> _tokens;
  int _seenLocalChanges = 0;
  int _cycleFailures = 0;
  Future<void> _deviceTail = Future.value();
  String? error;
  bool busy = false;
  int pendingCount = 0;
  int conflicts = 0;
  String? get uid => _uid;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    _notify();
    if (_seenLocalChanges == store.localChanges) return;
    _seenLocalChanges = store.localChanges;
    _cycleFailures = 0;
    _timer?.cancel();
    if (_uid != null) {
      _timer = Timer(
        const Duration(milliseconds: 700),
        () => unawaited(synchronize()),
      );
    }
  }

  Future<void> activate(String uid) async {
    _uid = uid;
    error = null;
    await store.activate(uid, prefs);
    await store.recover(uid);
    await synchronize();
    if (_uid != uid) return;
    if (store.get(uid, 'profile', 'self') == null) {
      await store.write(uid, 'profile', 'self', {
        'displayName': api.auth.currentUser?.displayName ?? 'Người dùng',
        'timezone': 'Asia/Bangkok',
      });
    }
    await registerDevice(uid);
  }

  Future<void> deactivate() async {
    final uid = _uid;
    _uid = null;
    _timer?.cancel();
    error = null;
    pendingCount = 0;
    conflicts = 0;
    if (uid != null) {
      final id = await store.meta('installation:id'),
          secret = await store.meta('installation:secret'),
          generation = await store.meta('$uid:device-generation');
      if (id != null && secret != null && generation != null) {
        try {
          await api.call(
            uid,
            '/devices/unregister',
            method: 'POST',
            body: {
              'installationId': id,
              'installationSecret': secret,
              'generation': int.parse(generation),
            },
          );
        } catch (_) {
          /* No UI/private data is retained for the next session. */
        }
      }
    }
    store.deactivate();
    _notify();
  }

  Future<void> synchronize() async {
    if (_disposed || _uid == null) return;
    _timer?.cancel();
    _timer = null;
    if (_running != null) {
      await _running;
      return;
    }
    final uid = _uid!;
    busy = true;
    error = null;
    _notify();
    final work = _cycle(uid);
    _running = work;
    try {
      await work;
    } finally {
      _running = null;
      busy = false;
      if (!_disposed) _notify();
    }
  }

  bool _current(String uid) =>
      !_disposed && _uid == uid && api.auth.currentUser?.uid == uid;
  Future<void> _cycle(String uid) async {
    try {
      // Pull first: preserve local pending edits and surface genuine revision conflicts.
      await _pull(uid);
      for (var n = 0; n < 30 && _current(uid); n++) {
        final op = await store.next(uid);
        if (op == null) break;
        try {
          final response = await api.call(
            uid,
            '/sync/push',
            method: 'POST',
            body: {
              'operations': [store.operation(op)],
            },
          );
          if (!_current(uid)) return;
          final result = Map<String, dynamic>.from(
            (response['results'] as List).single as Map,
          );
          if (result['error'] != null) {
            final code = (result['error'] as Map)['code'] as String;
            await store.fail(
              uid,
              op,
              code,
              retryable: false,
              current: result['current'] is Map
                  ? Map<String, dynamic>.from(result['current'] as Map)
                  : null,
            );
          } else {
            await store.acknowledge(
              uid,
              op,
              Map<String, dynamic>.from(result['record'] as Map),
            );
          }
        } on AppFailure catch (e) {
          if (!_current(uid)) return;
          await store.fail(
            uid,
            op,
            e.code,
            retryable: e is BackendFailure && e.retryable,
          );
          error = e.code;
          if (e is BackendFailure && e.retryable) break;
        } catch (_) {
          if (!_current(uid)) return;
          await store.fail(uid, op, 'invalid_sync_response', retryable: false);
          error = 'invalid_sync_response';
        }
      }
      if (!_current(uid)) return;
      await _uploadPhotos(uid);
      if (!_current(uid)) return;
      await _pull(uid);
      _cycleFailures = 0;
    } on AppFailure catch (e) {
      if (_current(uid)) {
        error = e.code;
        _cycleFailures++;
      }
    } catch (_) {
      if (_current(uid)) {
        error = 'sync_unavailable';
        _cycleFailures++;
      }
    } finally {
      if (_current(uid)) {
        final list = await store.pending(uid);
        pendingCount =
            list.length +
            store
                .all(uid, 'meal')
                .where(
                  (row) =>
                      store.data(row)['imagePath'] != null &&
                      row['asset_id'] == null,
                )
                .length;
        conflicts = list.where((o) => o['state'] == 'conflict').length;
        if (_cycleFailures < 3 && list.any((o) => o['state'] == 'pending')) {
          _timer?.cancel();
          _timer = Timer(
            const Duration(seconds: 5),
            () => unawaited(synchronize()),
          );
        }
      }
    }
  }

  Future<void> _pull(String uid) async {
    for (var page = 0; page < 100 && _current(uid); page++) {
      final cursor = await store.cursor(uid);
      final response = await api.call(
        uid,
        '/sync/pull?cursor=$cursor&limit=20',
      );
      if (!_current(uid)) return;
      final records = [
        for (final row in response['items'] as List)
          Map<String, dynamic>.from(row as Map),
      ];
      await store.applyPull(
        uid,
        records,
        (response['nextCursor'] as num).toInt(),
      );
      if (response['hasMore'] != true) return;
    }
  }

  Future<void> _uploadPhotos(String uid) async {
    for (final row in store.all(uid, 'meal')) {
      if (!_current(uid)) return;
      final data = store.data(row);
      final path = data['imagePath'] as String?;
      if (path == null ||
          path.startsWith('cloud:') ||
          row['asset_id'] != null ||
          row['sync_status'] != 'synced') {
        continue;
      }
      final retryKey = '$uid:photo-attempts:${row['id']}';
      final attempts = int.tryParse(await store.meta(retryKey) ?? '0') ?? 0;
      if (attempts >= 3) continue;
      try {
        await store.setMeta(retryKey, '${attempts + 1}');
        final bytes = await photos.read(uid, path);
        if (bytes == null) throw const AppFailure('meal_photo_missing');
        final result = await api.upload(
          uid,
          bytes: bytes,
          kind: 'photo',
          mealId: row['id'] as String,
          mealVersion:
              (row['photo_base_version'] ?? row['server_version']) as int,
        );
        if (!_current(uid)) return;
        final asset = Map<String, dynamic>.from(result['asset'] as Map),
            meal = Map<String, dynamic>.from(result['meal'] as Map);
        await store.setAsset(
          uid,
          row['id'] as String,
          asset['id'] as String,
          (meal['version'] as num).toInt(),
        );
      } on AppFailure catch (e) {
        if (!_current(uid)) return;
        error = e.code;
        if (e.code == 'version_conflict') {
          await store.setMeta('$uid:photo-conflict:${row['id']}', '1');
          await store.setMeta(retryKey, '3');
          continue;
        }
        if (attempts < 2) {
          _timer?.cancel();
          _timer = Timer(
            Duration(seconds: 5 * (attempts + 1)),
            () => unawaited(synchronize()),
          );
        }
      }
    }
  }

  Future<void> retryAll() async {
    _cycleFailures = 0;
    final uid = _uid;
    if (uid == null) return;
    await store.retry(uid);
    for (final row in store.all(uid, 'meal')) {
      if (row['asset_id'] == null &&
          await store.meta('$uid:photo-conflict:${row['id']}') != '1') {
        await store.setMeta('$uid:photo-attempts:${row['id']}', '0');
      }
    }
    await synchronize();
  }

  Future<List<String>> photoConflicts() async {
    final uid = _uid;
    if (uid == null) return [];
    final result = <String>[];
    for (final row in store.all(uid, 'meal')) {
      if (await store.meta('$uid:photo-conflict:${row['id']}') == '1') {
        result.add(row['id'] as String);
      }
    }
    return result;
  }

  Future<void> resolvePhoto(String id, {required bool keepLocal}) async {
    final uid = _uid;
    if (uid == null) return;
    final response = await api.call(uid, '/meals/$id');
    await store.resolvePhoto(
      uid,
      id,
      Map<String, dynamic>.from(response['record'] as Map),
      keepLocal: keepLocal,
    );
    await store.setMeta('$uid:photo-conflict:$id', '0');
    await store.setMeta('$uid:photo-attempts:$id', '0');
    await synchronize();
  }

  Future<void> registerDevice(String uid) {
    final work = _deviceTail.then((_) => _registerDevice(uid));
    _deviceTail = work.catchError((_) {});
    return work;
  }

  Future<void> _registerDevice(String uid) async {
    if (!_current(uid)) return;
    try {
      if (await messaging.permissionStatus() != PushPermission.granted) return;
      final token = await messaging.token();
      if (token == null || !_current(uid)) return;
      final id = await store.meta('installation:id') ?? syncId(),
          secret =
              await store.meta('installation:secret') ??
              '${syncId()}${syncId()}';
      await store.setMeta('installation:id', id);
      await store.setMeta('installation:secret', secret);
      final generation =
          (int.tryParse(await store.meta('installation:generation') ?? '0') ??
              0) +
          1;
      await store.setMeta('installation:generation', '$generation');
      await store.setMeta('$uid:device-generation', '$generation');
      if (!_current(uid)) return;
      await api.call(
        uid,
        '/devices/register',
        method: 'POST',
        body: {
          'installationId': id,
          'installationSecret': secret,
          'token': token,
          'generation': generation,
          'platform': 'android',
          'appVersion': '1.0.0',
        },
      );
    } on AppFailure catch (e) {
      if (_current(uid)) error = e.code;
    } catch (_) {
      if (_current(uid)) error = 'device_registration_failed';
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _tokens.cancel();
    store.removeListener(_changed);
    super.dispose();
  }
}
