import 'dart:convert';
import 'dart:typed_data';

import 'app_failure.dart';
import 'meal_photo_service.dart';

/// In-memory photo dependency for widget tests and the explicit fake build.
class FakeMealPhotoService implements MealPhotoService {
  FakeMealPhotoService({this.currentUid});
  final String? Function()? currentUid;
  final files = <String, Uint8List>{};
  final sources = <MealPhotoSource>[];
  Uint8List? nextImage;
  AppFailure? nextError;
  String? recoveredReference;
  int _serial = 0;

  String _prefix(String uid) =>
      'meal_photos/${base64Url.encode(utf8.encode(uid)).replaceAll('=', '')}/';
  @override
  void checkOwner(String uid) {
    final readUid = currentUid;
    if (uid.isEmpty || (readUid != null && readUid() != uid)) {
      throw const AppFailure('photo_session_changed');
    }
  }

  void _validate(String uid, String reference) {
    checkOwner(uid);
    if (!reference.startsWith(_prefix(uid)) || reference.contains('..')) {
      throw const AppFailure('invalid_photo_reference');
    }
  }

  @override
  Future<String?> pick(String uid, MealPhotoSource source) async {
    checkOwner(uid);
    sources.add(source);
    final error = nextError;
    nextError = null;
    if (error != null) throw error;
    final bytes = nextImage;
    nextImage = null;
    if (bytes == null) return null;
    final ref = '${_prefix(uid)}draft/${++_serial}.jpg';
    files[ref] = bytes;
    return ref;
  }

  @override
  Future<String?> recover(String uid) async {
    checkOwner(uid);
    final ref = recoveredReference;
    recoveredReference = null;
    return ref;
  }

  @override
  Future<String> persist(
    String uid,
    String draftReference,
    String mealId,
  ) async {
    _validate(uid, draftReference);
    final bytes = files[draftReference];
    if (bytes == null) throw const AppFailure('meal_photo_missing');
    final ref = '${_prefix(uid)}saved/${mealId}_${++_serial}.jpg';
    files[ref] = bytes;
    return ref;
  }

  @override
  Future<Uint8List?> read(String uid, String reference) async {
    _validate(uid, reference);
    return files[reference];
  }

  @override
  Future<void> remove(String uid, String reference) async {
    _validate(uid, reference);
    files.remove(reference);
  }
}
