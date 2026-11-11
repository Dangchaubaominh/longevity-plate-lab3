import 'dart:typed_data';

enum MealPhotoSource { camera, gallery }

/// References are relative to the app's documents directory, never picker paths.
abstract interface class MealPhotoService {
  void checkOwner(String uid);
  Future<String?> pick(String uid, MealPhotoSource source);
  Future<String?> recover(String uid);
  Future<String> persist(String uid, String draftReference, String mealId);
  Future<Uint8List?> read(String uid, String reference);
  Future<void> remove(String uid, String reference);
}
