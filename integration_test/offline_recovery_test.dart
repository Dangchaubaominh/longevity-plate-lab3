// Physical Android SQLite + actual Firebase/D1/Cloudinary. The offline boundary
// is an injected HTTP failure so wireless ADB stays connected. Closing/reopening
// SQLite proves disk recovery; this does not claim an Android process-kill test.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:longevity_plate/app/app.dart';
import 'package:longevity_plate/main.dart' as app;
import 'package:longevity_plate/services/device_meal_photo_service.dart';
import 'package:longevity_plate/services/firebase/firebase_messaging_service.dart';
import 'package:longevity_plate/services/meal_photo_service.dart';
import 'package:longevity_plate/services/service_interfaces.dart';
import 'package:longevity_plate/services/sync/backend_api.dart';
import 'package:longevity_plate/services/sync/local_sync_store.dart';
import 'package:longevity_plate/services/sync/sync_engine.dart';

class _OfflineClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw http.ClientException('Controlled offline acceptance boundary');
}

class _FixturePicker implements MealPhotoPicker {
  _FixturePicker(this.bytes);
  final Uint8List bytes;
  @override
  Future<XFile?> pick(MealPhotoSource source) async =>
      XFile.fromData(bytes, name: 'acceptance.jpg', mimeType: 'image/jpeg');
  @override
  Future<XFile?> recover() async => null;
}

// This separate acceptance DB must not register a duplicate installation token.
class _NoDeviceRegistration extends FirebaseMessagingService {
  @override
  Future<PushPermission> permissionStatus() async => PushPermission.denied;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native durable outbox, retry and real second-client conflict', (
    tester,
  ) async {
    const base = String.fromEnvironment('API_BASE_URL');
    expect(base, isNotEmpty);
    await app.main();
    await tester.pumpAndSettle();
    final s = tester
        .widget<LongevityPlateApp>(find.byType(LongevityPlateApp))
        .services;
    final uid = s.auth.currentUser?.uid;
    expect(uid, isNotNull, reason: 'Sign in on the physical device first.');
    final owner = uid!;
    final api = s.backend!;
    final id = 'acceptance_offline_${syncId()}';
    final path = '${await getDatabasesPath()}/$id.db';
    Future<LocalSyncStore> open() async => LocalSyncStore(
      await openDatabase(
        path,
        version: 1,
        onCreate: (db, _) => LocalSyncStore.createSchema(db),
      ),
      () => s.auth.currentUser?.uid,
    );
    var store = await open();
    await store.setMeta('$owner:migrated', '1');
    final input = await rootBundle.load('assets/images/bowl.png');
    final bytes = await DeviceMealPhotoService.normalizePhoto(
      input.buffer.asUint8List(),
    );
    final photos = DeviceMealPhotoService(
      prefs: s.prefs,
      currentUid: () => s.auth.currentUser?.uid,
      picker: _FixturePicker(bytes),
    );
    final draft = await photos.pick(owner, MealPhotoSource.gallery);
    final photo = await photos.persist(owner, draft!, id);
    SyncEngine makeEngine(BackendApi backend) => SyncEngine(
      store: store,
      api: backend,
      prefs: s.prefs,
      photos: photos,
      messaging: _NoDeviceRegistration(),
    );
    var engine = makeEngine(
      BackendApi(baseUrl: base, auth: s.auth, client: _OfflineClient()),
    );
    var remoteCreated = false;
    try {
      await engine.activate(owner);
      await store.write(owner, 'meal', id, {
        'id': id,
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'type': 'lunch',
        'description': 'Controlled offline acceptance',
        'createdAt': DateTime.now().toIso8601String(),
        'imagePath': photo,
      });
      await engine.synchronize();
      expect(engine.error, 'network-request-failed');
      final pending = await store.pending(owner);
      expect(pending.where((o) => o['record_id'] == id), hasLength(1));
      final opId = pending.singleWhere((o) => o['record_id'] == id)['op_id'];
      expect(await photos.read(owner, photo), isNotEmpty);
      await expectLater(
        api.call(owner, '/meals/$id'),
        throwsA(isA<BackendFailure>().having((e) => e.status, 'status', 404)),
      );
      engine.dispose();
      await store.close();
      store = await open();
      await store.activate(owner, s.prefs);
      expect(
        (await store.pending(owner))
            .singleWhere((o) => o['record_id'] == id)['op_id'],
        opId,
      );
      expect(store.get(owner, 'meal', id), isNotNull);
      engine = makeEngine(api);
      await engine.activate(owner);
      await engine.retryAll();
      remoteCreated = true;
      final uploaded = (await api.call(owner, '/meals/$id'))['record'] as Map;
      final version = uploaded['version'];
      final asset = (uploaded['photoAsset'] as Map)['id'];
      expect(asset, isA<String>());
      expect(await api.image(owner, asset as String), isNotEmpty);
      await engine.retryAll();
      final repeat = (await api.call(owner, '/meals/$id'))['record'] as Map;
      expect(repeat['version'], version, reason: 'Retry must not duplicate.');
      expect((repeat['photoAsset'] as Map)['id'], asset);

      // Two real clients contend on the same revision: local pending edit and
      // a direct second-client API update. No mock server response is used.
      engine.dispose();
      engine = makeEngine(api);
      await store.write(owner, 'meal', id, {
        ...store.data(store.get(owner, 'meal', id)!),
        'description': 'Acceptance local pending',
      });
      await api.call(
        owner,
        '/meals/$id',
        method: 'PUT',
        body: {
          'opId': syncId(),
          'baseVersion': version,
          'data': {
            ...(uploaded['data'] as Map).cast<String, dynamic>(),
            'description': 'Acceptance second client',
          },
        },
      );
      await engine.activate(owner);
      expect(store.get(owner, 'meal', id)!['sync_status'], 'conflict');
      await store.resolve(owner, 'meal', id, keepLocal: false);
      await engine.retryAll();
      expect(
        store.data(store.get(owner, 'meal', id)!)['description'],
        'Acceptance second client',
      );
    } finally {
      engine.dispose();
      if (remoteCreated) {
        final latest = (await api.call(owner, '/meals/$id'))['record'] as Map;
        await api.call(
          owner,
          '/meals/$id',
          method: 'DELETE',
          body: {
            'opId': syncId(),
            'baseVersion': latest['version'],
            'data': {},
          },
        );
      }
      await photos.remove(owner, photo);
      await store.close();
      await deleteDatabase(path);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
