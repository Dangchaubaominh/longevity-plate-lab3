import 'package:flutter/foundation.dart';

import '../app/app_services.dart';
import '../core/dates.dart';
import '../models/models.dart';
import '../services/service_interfaces.dart';
import 'safe_notifier.dart';

enum MealField { date, type, description }

class AddMealViewModel extends ChangeNotifier with SafeNotifier {
  AddMealViewModel(this._s, this._uid, {DateTime? initialDate})
    : date = dateOnly(initialDate ?? today());

  static const maxLength = 120;

  final AppServices _s;
  final String _uid;
  final _timer = Stopwatch()..start();

  DateTime date;
  MealType? type;
  String description = '';
  bool saving = false;
  bool saveFailed = false;
  Set<MealField> errors = {};

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

  void logDiscard() => _s.analytics.logEvent(AnalyticsEvents.mealDraftDiscarded);

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
    if (saving) return false;
    firstError = _validate();
    if (firstError != null) {
      notifyListeners();
      return false;
    }
    saving = true;
    saveFailed = false;
    notifyListeners();
    try {
      await _s.meals.add(
        _uid,
        date: dateKey(date),
        type: type!,
        description: description.trim(),
      );
      await _s.analytics.logEvent(AnalyticsEvents.mealSaved, {
        'meal_type': type!.name,
        'duration_ms': _timer.elapsedMilliseconds,
      });
      _dirty = false;
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
}
