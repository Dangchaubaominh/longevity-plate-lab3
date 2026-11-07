import 'package:flutter/foundation.dart';

import '../app/app_services.dart';
import '../core/dates.dart';
import '../core/load_state.dart';
import '../models/models.dart';
import '../services/app_failure.dart';
import 'safe_notifier.dart';

class PlanSaveResult {
  const PlanSaveResult(this.date, this.slot, {required this.replaced});

  final DateTime date;
  final PlanSlot slot;
  final bool replaced;
}

class PlannerViewModel extends ChangeNotifier with SafeNotifier {
  PlannerViewModel(this._s, this._uid) {
    _s.plans.addListener(load);
    _s.remoteConfig.addListener(notifyListeners);
    load();
  }

  final AppServices _s;
  final String _uid;
  int _loadId = 0;

  DateTime selectedDate = today();
  LoadState state = LoadState.loading;
  Map<PlanSlot, String> slots = const {};
  String? banner;

  DateTime get weekStart => startOfWeek(selectedDate);
  DateTime get weekEnd => addDays(weekStart, 6);
  List<DateTime> get days => [for (var i = 0; i < 7; i++) addDays(weekStart, i)];

  bool get showSuggestions => _s.remoteConfig.suggestedRecipesEnabled;
  List<Recipe> get recipes => _s.content.recipes;
  Recipe get suggestedRecipe => _s.content.recipes.first;

  Recipe? recipeFor(PlanSlot slot) {
    final id = slots[slot];
    return id == null ? null : _s.content.recipeById(id);
  }

  /// Slot trống đầu tiên dùng nút chính, các slot trống còn lại dùng nút viền.
  PlanSlot? get firstEmptySlot =>
      PlanSlot.values.where((s) => !slots.containsKey(s)).firstOrNull;

  void selectDay(DateTime day) {
    selectedDate = day;
    banner = null;
    load();
  }

  void previousWeek() => selectDay(addDays(selectedDate, -7));
  void nextWeek() => selectDay(addDays(selectedDate, 7));

  void applySaveResult(PlanSaveResult result) {
    selectedDate = result.date;
    banner = result.replaced
        ? 'Đã thay thế món trong kế hoạch.'
        : 'Đã thêm món vào kế hoạch.';
    load();
  }

  Future<void> load() async {
    final id = ++_loadId;
    state = LoadState.loading;
    notifyListeners();
    try {
      final loaded = await _s.plans.forDate(
        _uid,
        dateKey(selectedDate),
        fault: FaultPoint.loadPlan,
      );
      if (id != _loadId) return;
      slots = loaded;
      state = LoadState.ready;
    } catch (e, st) {
      if (id != _loadId) return;
      state = LoadState.error;
      await _s.crash.recordError(e, st, reason: 'plan_load_failed');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _s.plans.removeListener(load);
    _s.remoteConfig.removeListener(notifyListeners);
    super.dispose();
  }
}
