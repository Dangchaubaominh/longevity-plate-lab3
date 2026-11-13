import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_failure.dart';
import 'meal_photo_service.dart';

abstract interface class MealPhotoPicker {
  Future<XFile?> pick(MealPhotoSource source);
  Future<XFile?> recover();
}

class NativeMealPhotoPicker implements MealPhotoPicker {
  NativeMealPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<XFile?> pick(MealPhotoSource source) => _picker.pickImage(
    source: source == MealPhotoSource.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 82,
    requestFullMetadata: false,
  );

  @override
  Future<XFile?> recover() async {
    final lost = await _picker.retrieveLostData();
    if (lost.exception != null) throw lost.exception!;
    return lost.files?.firstOrNull;
  }
}

/// Camera/gallery photos stay in the Android app sandbox. Nothing is uploaded.
class DeviceMealPhotoService implements MealPhotoService {
  DeviceMealPhotoService({
    required this.prefs,
    required this.currentUid,
    MealPhotoPicker? picker,
    Future<Directory> Function()? documentsDirectory,
  }) : _picker = picker ?? NativeMealPhotoPicker(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  final SharedPreferences prefs;
  final String? Function() currentUid;
  final MealPhotoPicker _picker;
  final Future<Directory> Function() _documentsDirectory;
  static const _pendingOwner = 'meal_photo.pending_owner';
  static const maxInputBytes = 20 * 1024 * 1024;
  static const maxStoredBytes = 5 * 1024 * 1024;
  bool _picking = false;

  static String ownerKey(String uid) =>
      base64Url.encode(utf8.encode(uid)).replaceAll('=', '');

  @override
  void checkOwner(String uid) {
    if (uid.isEmpty || currentUid() != uid) {
      throw const AppFailure('photo_session_changed');
    }
  }

  String _nonce() =>
      '${DateTime.now().microsecondsSinceEpoch}_${math.Random.secure().nextInt(1 << 32)}';

  Future<File> _file(String uid, String reference) async {
    checkOwner(uid);
    final prefix = 'meal_photos/${ownerKey(uid)}/';
    if (!reference.startsWith(prefix) ||
        !RegExp(r'^(draft|saved)/[a-zA-Z0-9_-]+\.jpg$')
            .hasMatch(reference.substring(prefix.length))) {
      throw const AppFailure('invalid_photo_reference');
    }
    final root = await _documentsDirectory();
    checkOwner(uid);
    return File('${root.path}/$reference');
  }

  @override
  Future<String?> pick(String uid, MealPhotoSource source) async {
    checkOwner(uid);
    if (kIsWeb) throw const AppFailure('photo_platform_unavailable');
    if (_picking) throw const AppFailure('photo_picker_busy');
    final pending = prefs.getString(_pendingOwner);
    if (pending != null && pending != ownerKey(uid)) {
      throw const AppFailure('photo_pending_other_user');
    }
    _picking = true;
    try {
      if (!await prefs.setString(_pendingOwner, ownerKey(uid))) {
        throw const AppFailure('photo_write_failed');
      }
      final image = await _picker.pick(source);
      checkOwner(uid);
      if (image == null) return null;
      return await _prepare(uid, image);
    } finally {
      _picking = false;
      if (prefs.getString(_pendingOwner) == ownerKey(uid)) {
        await prefs.remove(_pendingOwner);
      }
    }
  }

  @override
  Future<String?> recover(String uid) async {
    checkOwner(uid);
    // Do not consume another account's Android lost-result cache.
    if (prefs.getString(_pendingOwner) != ownerKey(uid)) return null;
    try {
      final image = await _picker.recover();
      checkOwner(uid);
      return image == null ? null : await _prepare(uid, image);
    } finally {
      if (prefs.getString(_pendingOwner) == ownerKey(uid)) {
        await prefs.remove(_pendingOwner);
      }
    }
  }

  Future<String> _prepare(String uid, XFile image) async {
    final length = await image.length();
    if (length <= 0 || length > maxInputBytes) {
      throw const AppFailure('photo_too_large');
    }
    final bytes = await image.readAsBytes();
    checkOwner(uid);
    final jpeg = await normalizePhoto(bytes);
    checkOwner(uid);
    final reference = 'meal_photos/${ownerKey(uid)}/draft/${_nonce()}.jpg';
    final file = await _file(uid, reference);
    await file.parent.create(recursive: true);
    // Remove abandoned drafts after a day, never committed meal photos.
    await for (final entry in file.parent.list()) {
      if (entry is File && entry.path.endsWith('.jpg')) {
        final stat = await entry.stat();
        if (DateTime.now().difference(stat.modified) >
            const Duration(days: 1)) {
          await entry.delete();
        }
      }
    }
    checkOwner(uid);
    await file.writeAsBytes(jpeg, flush: true);
    try {
      checkOwner(uid);
    } catch (_) {
      await file.delete();
      rethrow;
    }
    return reference;
  }

  /// Decode to a bounded frame before passing pixels to the JPEG worker isolate.
  /// The native picker also subsamples large originals before returning them.
  static Future<Uint8List> normalizePhoto(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxInputBytes) {
      throw const AppFailure('photo_too_large');
    }
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? frame;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width;
      final h = descriptor.height;
      if (w <= 0 || h <= 0 || w > 12000 || h > 12000 || w * h > 40000000) {
        throw const AppFailure('photo_too_large');
      }
      final scale = math.min(1.0, 1600 / math.max(w, h));
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (w * scale).round()),
        targetHeight: math.max(1, (h * scale).round()),
      );
      frame = (await codec.getNextFrame()).image;
      final rgba = await frame.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) throw const AppFailure('invalid_meal_photo');
      final jpeg = await compute(_encodeJpeg, (
        rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
        frame.width,
        frame.height,
      ));
      if (jpeg.length > maxStoredBytes) {
        throw const AppFailure('photo_too_large');
      }
      return jpeg;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure('invalid_meal_photo');
    } finally {
      frame?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  @override
  Future<String> persist(
    String uid,
    String draftReference,
    String mealId,
  ) async {
    checkOwner(uid);
    final prefix = 'meal_photos/${ownerKey(uid)}/draft/';
    if (!draftReference.startsWith(prefix) ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(mealId)) {
      throw const AppFailure('invalid_photo_reference');
    }
    final draft = await _file(uid, draftReference);
    if (!await draft.exists()) throw const AppFailure('meal_photo_missing');
    final reference =
        'meal_photos/${ownerKey(uid)}/saved/${mealId}_${_nonce()}.jpg';
    final target = await _file(uid, reference);
    await target.parent.create(recursive: true);
    checkOwner(uid);
    await draft.copy(target.path);
    try {
      checkOwner(uid);
    } catch (_) {
      await target.delete();
      rethrow;
    }
    return reference;
  }

  @override
  Future<Uint8List?> read(String uid, String reference) async {
    final file = await _file(uid, reference);
    if (!await file.exists()) return null;
    if (await file.length() > maxStoredBytes) return null;
    final bytes = await file.readAsBytes();
    checkOwner(uid);
    return bytes;
  }

  Future<String> cacheCloud(String uid, Uint8List bytes, String assetId) async {
    checkOwner(uid);
    final draft = await _prepare(uid, XFile.fromData(bytes, name: 'cloud.jpg'));
    try {
      return await persist(uid, draft, 'cloud_$assetId');
    } finally {
      await remove(uid, draft);
    }
  }

  @override
  Future<void> remove(String uid, String reference) async {
    final file = await _file(uid, reference);
    if (await file.exists()) {
      checkOwner(uid);
      await file.delete();
    }
  }
}

Uint8List _encodeJpeg((Uint8List, int, int) data) {
  final rgba = img.Image.fromBytes(
    width: data.$2,
    height: data.$3,
    bytes: data.$1.buffer,
    bytesOffset: data.$1.offsetInBytes,
    numChannels: 4,
  );
  final background = img.Image(width: data.$2, height: data.$3, numChannels: 3);
  img.fill(background, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(background, rgba);
  return img.encodeJpg(background, quality: 82);
}
