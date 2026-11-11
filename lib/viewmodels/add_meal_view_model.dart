import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app/app_services.dart';
import '../core/dates.dart';
import '../models/models.dart';
import '../services/app_failure.dart';
import '../services/meal_photo_service.dart';
import '../services/service_interfaces.dart';
import 'safe_notifier.dart';

enum MealField { date, type, description }

class AddMealViewModel extends ChangeNotifier with SafeNotifier {
  AddMealViewModel(this._s, this._uid, {DateTime? initialDate})
    : date = dateOnly(initialDate ?? today()) {
    unawaited(_recoverPhoto());
  }

  static const maxLength = 120;

  final AppServices _s;
  final String _uid;
  final _timer = Stopwatch()..start();
  final _entryId =
      '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
  bool _completed = false;

  DateTime date;
  MealType? type;
  String description = '';
  bool saving = false;
  bool saveFailed = false;
  Set<MealField> errors = {};
  String? photoReference;
  String? photoMessage;
  bool photoMessageIsError = false;
  bool pickingPhoto = false;
  bool get busy => saving || pickingPhoto;
  String get uid => _uid;

  bool _dirty = false;
  bool get isDirty => _dirty;
  int get length => description.trim().length;

  void setDate(DateTime value) {
    date = dateOnly(value);
    _touch(MealField.date);
  }

  void setType(MealType value) {
    type = value;
    _touch(MealField.type);
  }

  void setDescription(String value) {
    description = value;
    _touch(MealField.description);
  }

  void _touch(MealField field) {
    _dirty = true;
    errors = {...errors}..remove(field);
    saveFailed = false;
    notifyListeners();
  }

  void logDiscard() =>
      _s.analytics.logEvent(AnalyticsEvents.mealDraftDiscarded);

  Future<void> _recoverPhoto() async {
    pickingPhoto = true;
    try {
      final recovered = await _s.photos.recover(_uid);
      if (isDisposed) {
        if (recovered != null) await _removeDraft(recovered);
        return;
      }
      if (recovered != null) {
        photoReference = recovered;
        _dirty = true;
        photoMessage = 'Đã khôi phục ảnh từ lần chọn trước. Kiểm tra lại thông tin bữa ăn trước khi lưu.';
      }
    } catch (error) {
      photoMessage = _describePhotoError(error);
      photoMessageIsError = true;
    } finally {
      pickingPhoto = false;
      notifyListeners();
    }
  }

  Future<void> pickPhoto(MealPhotoSource source) async {
    if (busy || _completed) return;
    pickingPhoto = true;
    photoMessage = null;
    photoMessageIsError = false;
    notifyListeners();
    try {
      final picked = await _s.photos.pick(_uid, source);
      if (picked == null) return; // Cancellation preserves the entire draft.
      if (isDisposed) {
        await _removeDraft(picked);
        return;
      }
      final old = photoReference;
      photoReference = picked;
      _dirty = true;
      saveFailed = false;
      if (old != null) await _removeDraft(old);
    } catch (error) {
      photoMessage = _describePhotoError(error);
      photoMessageIsError = true;
    } finally {
      pickingPhoto = false;
      notifyListeners();
    }
  }

  Future<void> removePhoto() async {
    if (busy || photoReference == null) return;
    final old = photoReference!;
    photoReference = null;
    photoMessage = null;
    _dirty = true;
    notifyListeners();
    await _removeDraft(old);
  }

  Future<void> discard() async {
    final draft = photoReference;
    photoReference = null;
    _dirty = false;
    if (draft != null) await _removeDraft(draft);
  }

  Future<void> _removeDraft(String reference) async {
    try {
      await _s.photos.remove(_uid, reference);
    } catch (_) {
      // Another session must never be allowed to access or delete this photo.
      debugPrint('Chưa dọn được ảnh nháp bữa ăn.');
    }
  }

  String _describePhotoError(Object error) {
    final code = switch (error) {
      AppFailure() => error.code,
      PlatformException() => error.code,
      _ => '',
    };
    if (code.contains('denied') || code.contains('restricted')) {
      return 'Chưa có quyền dùng camera hoặc ảnh. Kiểm tra Cài đặt ứng dụng rồi thử lại.';
    }
    return switch (code) {
      'photo_too_large' =>
        'Ảnh quá lớn để xử lý an toàn. Hãy chọn ảnh nhỏ hơn hoặc chụp lại.',
      'invalid_meal_photo' =>
        'Không đọc được ảnh này. Hãy chọn ảnh JPEG/PNG khác.',
      'photo_session_changed' =>
        'Phiên đăng nhập đã thay đổi. Hãy mở lại màn thêm bữa ăn.',
      'photo_pending_other_user' => 'Một lần chọn ảnh trước chưa hoàn tất. Hãy quay lại tài khoản đã thực hiện thao tác đó.',
      'no_available_camera' ||
      'camera_not_available' ||
      'photo_platform_unavailable' => 'Không mở được camera trên thiết bị này. Bạn có thể chọn ảnh từ thư viện.',
      _ => 'Chưa thêm được ảnh. Kiểm tra dung lượng hoặc chọn ảnh khác rồi thử lại.',
    };
  }

  MealField? _validate() {
    final trimmed = description.trim();
    errors = {
      if (date.isAfter(today())) MealField.date,
      if (type == null) MealField.type,
      if (trimmed.isEmpty || trimmed.length > maxLength) MealField.description,
    };
    if (errors.isEmpty) return null;
    return MealField.values.firstWhere(errors.contains);
  }

  /// Trả về true khi đã lưu đúng một bản ghi. Trường lỗi đầu tiên nằm ở [firstError].
  MealField? firstError;

  Future<bool> submit() async {
    if (busy || _completed) return false;
    firstError = _validate();
    if (firstError != null) {
      notifyListeners();
      return false;
    }
    saving = true;
    saveFailed = false;
    notifyListeners();
    try {
      _s.photos.checkOwner(_uid);
      await _s.meals.add(
        _uid,
        date: dateKey(date),
        type: type!,
        description: description.trim(),
        photoDraft: photoReference,
        id: _entryId,
      );
      _completed = true;
      _dirty = false;
      // A telemetry failure cannot turn a committed meal into a failed save.
      try {
        await _s.analytics.logEvent(AnalyticsEvents.mealSaved, {
          'meal_type': type!.name,
          'duration_ms': _timer.elapsedMilliseconds,
        });
      } catch (_) {
        debugPrint('Chưa gửi được sự kiện lưu bữa ăn.');
      }
      return true;
    } catch (e, st) {
      saveFailed = true;
      await _s.analytics.logEvent(AnalyticsEvents.mealSaveFailed, {
        'meal_type': type!.name,
      });
      await _s.crash.recordError(e, st, reason: 'meal_save_failed');
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    final draft = photoReference;
    if (!_completed && draft != null) unawaited(_removeDraft(draft));
    super.dispose();
  }
}
