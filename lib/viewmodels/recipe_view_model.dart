import 'package:flutter/foundation.dart';

import '../app/app_services.dart';
import '../core/dates.dart';
import '../core/load_state.dart';
import '../models/models.dart';
import '../services/service_interfaces.dart';
import 'planner_view_model.dart';
import 'safe_notifier.dart';

class RecipeViewModel extends ChangeNotifier with SafeNotifier {
  RecipeViewModel(
    this._s,
    this._uid,
    this.recipeId, {
    DateTime? initialDate,
    PlanSlot? initialSlot,
    this.articleStartedAt,
  }) : date = dateOnly(initialDate ?? today()),
       slot = initialSlot ?? PlanSlot.dinner {
    load();
  }

  final AppServices _s;
  final String _uid;
  final String recipeId;

  /// Mốc rời S09 khi đi theo luồng F03, dùng để đo SC03.
  final int? articleStartedAt;
  final _timer = Stopwatch()..start();

  LoadState state = LoadState.loading;
  Recipe? recipe;
  DateTime date;
  PlanSlot slot;
  bool saving = false;
  bool saveFailed = false;

  void setDate(DateTime value) {
    if (saving) return;
    date = dateOnly(value);
    saveFailed = false;
    notifyListeners();
  }

  void setSlot(PlanSlot value) {
    if (saving) return;
    slot = value;
    saveFailed = false;
    notifyListeners();
  }

  Future<void> load() async {
    state = LoadState.loading;
    notifyListeners();
    try {
      recipe = await _s.content.recipe(recipeId);
      state = LoadState.ready;
      await _s.analytics.logEvent(AnalyticsEvents.recipeView, {
        'item_id': recipeId,
      });
    } catch (e, st) {
      state = LoadState.error;
      await _s.crash.recordError(e, st, reason: 'recipe_load_failed');
    }
    notifyListeners();
  }

  /// Slot đã có món khác thì View phải hỏi trước khi thay.
  bool get needsReplaceConfirm {
    final existing = _s.plans.recipeAt(_uid, dateKey(date), slot);
    return existing != null && existing != recipeId;
  }

  Future<PlanSaveResult?> save() async {
    if (saving) return null;
    // Giữ nguyên ngày, bữa đang chọn để lưu đúng slot dù có điều gì đổi giữa chừng.
    final snapshotDate = date;
    final snapshotSlot = slot;
    final replaced = needsReplaceConfirm;
    saving = true;
    saveFailed = false;
    notifyListeners();
    try {
      await _s.plans.setSlot(
        _uid,
        dateKey(snapshotDate),
        snapshotSlot,
        recipeId,
      );
      final startedAt = articleStartedAt;
      await _s.analytics.logEvent(AnalyticsEvents.planSlotSaved, {
        'meal': snapshotSlot.name,
        'action': replaced ? 'replace' : 'add',
        'source': startedAt != null ? 'article' : 'planner',
        'duration_ms': startedAt != null
            ? DateTime.now().millisecondsSinceEpoch - startedAt
            : _timer.elapsedMilliseconds,
      });
      return PlanSaveResult(snapshotDate, snapshotSlot, replaced: replaced);
    } catch (e, st) {
      saveFailed = true;
      await _s.analytics.logEvent(AnalyticsEvents.planSaveFailed, {
        'meal': snapshotSlot.name,
      });
      await _s.crash.recordError(e, st, reason: 'plan_save_failed');
      return null;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
