import 'package:flutter/foundation.dart';

import '../app/app_services.dart';
import '../core/dates.dart';
import '../core/load_state.dart';
import '../models/models.dart';
import '../services/app_failure.dart';
import '../services/service_interfaces.dart';
import 'safe_notifier.dart';

class MealLogViewModel extends ChangeNotifier with SafeNotifier {
  MealLogViewModel(this._s, this._uid) {
    _s.meals.addListener(load);
    load();
  }

  final AppServices _s;
  final String _uid;
  int _loadId = 0;

  DateTime date = today();
  LoadState state = LoadState.loading;
  List<MealEntry> meals = const [];
  bool showSaved = false;

  bool get canGoNext => date.isBefore(today());
  bool get isToday => isSameDay(date, today());

  String get dayLabel {
    if (isToday) return 'Hôm nay';
    if (isSameDay(date, addDays(today(), -1))) return 'Hôm qua';
    return 'Ngày đã chọn';
  }

  void previousDay() => _setDate(addDays(date, -1));

  void nextDay() {
    if (canGoNext) _setDate(addDays(date, 1));
  }

  void _setDate(DateTime value) {
    date = value;
    showSaved = false;
    load();
  }

  void logAddStart() => _s.analytics.logEvent(AnalyticsEvents.mealAddStart);

  void markSaved() {
    showSaved = true;
    notifyListeners();
  }

  Future<void> load() async {
    // Chuyển ngày nhanh: chỉ nhận kết quả của lần tải mới nhất.
    final id = ++_loadId;
    state = LoadState.loading;
    notifyListeners();
    try {
      final loaded = await _s.meals.forDate(
        _uid,
        dateKey(date),
        fault: FaultPoint.loadLog,
      );
      if (id != _loadId) return;
      meals = loaded;
      state = loaded.isEmpty ? LoadState.empty : LoadState.ready;
    } catch (e, st) {
      if (id != _loadId) return;
      state = LoadState.error;
      await _s.crash.recordError(e, st, reason: 'meal_log_load_failed');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _s.meals.removeListener(load);
    super.dispose();
  }
}
