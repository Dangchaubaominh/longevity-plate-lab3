import 'dart:async';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../device_meal_photo_service.dart';
import '../meal_photo_service.dart';
import '../service_interfaces.dart';
import 'backend_api.dart';

class ConnectedMealPhotos implements MealPhotoService {
  ConnectedMealPhotos(this.local, this.api, this.prefs);
  final DeviceMealPhotoService local;
  final BackendApi api;
  final SharedPreferences prefs;
  @override
  void checkOwner(String uid) => local.checkOwner(uid);
  @override
  Future<String?> pick(String uid, MealPhotoSource source) =>
      local.pick(uid, source);
  @override
  Future<String?> recover(String uid) => local.recover(uid);
  @override
  Future<String> persist(String uid, String draftReference, String mealId) =>
      local.persist(uid, draftReference, mealId);
  @override
  Future<void> remove(String uid, String reference) async {
    checkOwner(uid);
    if (!reference.startsWith('cloud:')) await local.remove(uid, reference);
  }

  @override
  Future<Uint8List?> read(String uid, String reference) async {
    checkOwner(uid);
    if (!reference.startsWith('cloud:')) return local.read(uid, reference);
    final id = reference.substring(6), key = '$uid:photo-cache:$reference';
    final cached = prefs.getString(key);
    if (cached != null) {
      final bytes = await local.read(uid, cached);
      if (bytes != null) return bytes;
    }
    final bytes = await api.image(uid, id);
    checkOwner(uid);
    final saved = await local.cacheCloud(uid, bytes, id);
    checkOwner(uid);
    await prefs.setString(key, saved);
    return bytes;
  }
}

class ConnectedReportStorage implements ReportStorageService {
  ConnectedReportStorage(this.api);
  final BackendApi api;
  @override
  Stream<UploadProgress> upload({
    required String uid,
    required String fileName,
    required Uint8List bytes,
  }) {
    final stream = StreamController<UploadProgress>();
    unawaited(() async {
      try {
        final result = await api.upload(
          uid,
          bytes: bytes,
          kind: 'pdf',
          onProgress: (v) {
            if (v < 1) stream.add(UploadProgress(v));
          },
        );
        final asset = result['asset'] as Map;
        final link = await api.call(
          uid,
          '/media/${asset['id']}/url',
          method: 'POST',
          body: {},
        );
        stream.add(UploadProgress(1, downloadUrl: link['url'] as String));
      } catch (e, st) {
        stream.addError(e, st);
      } finally {
        await stream.close();
      }
    }());
    return stream.stream;
  }

  @override
  Future<String> probeForeignReport() async {
    final uid = api.auth.currentUser?.uid;
    if (uid == null) return 'unauthenticated';
    try {
      await api.call(
        uid,
        '/media/not-owned-asset/url',
        method: 'POST',
        body: {},
      );
      return 'unexpected_access';
    } on BackendFailure catch (e) {
      return e.status == 404 ? 'unauthorized' : e.code;
    }
  }
}
