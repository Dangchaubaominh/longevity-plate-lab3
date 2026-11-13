import 'package:flutter/foundation.dart';

import '../app/app_services.dart';
import '../core/dates.dart';
import '../core/load_state.dart';
import '../core/text.dart';
import '../models/models.dart';
import '../services/app_failure.dart';
import 'safe_notifier.dart';

class HomeViewModel extends ChangeNotifier with SafeNotifier {
  HomeViewModel(this._s, this._uid) {
    _s.meals.addListener(load);
    _s.plans.addListener(load);
    load();
  }

  final AppServices _s;
  final String _uid;
  // Tab Hôm nay được giữ trong IndexedStack, nên phải tính lại khi app mở qua đêm.
  DateTime get date => today();

  LoadState state = LoadState.loading;
  List<MealEntry> meals = const [];
  Map<PlanSlot, String> plan = const {};

  int get mealCount => meals.length;

  String get mealSummary {
    if (meals.isEmpty) {
      return 'Ghi nhận bữa ăn để theo dõi nhịp điệu trong ngày.';
    }
    final types = <String>{for (final m in meals) m.type.label.toLowerCase()};
    return 'Bạn đã ghi nhận ${joinVietnamese(types.toList())}.';
  }

  /// Món sắp tới trong kế hoạch hôm nay, chưa có thì gợi ý một món minh họa.
  bool get isSuggestion => plan.isEmpty;

  PlanSlot get featuredSlot {
    if (plan.isEmpty) return PlanSlot.dinner;
    final hour = DateTime.now().hour;
    final slots = plan.keys.toList()..sort((a, b) => a.hour.compareTo(b.hour));
    return slots.firstWhere((s) => s.hour >= hour, orElse: () => slots.last);
  }

  Recipe get featuredRecipe {
    final id = plan[featuredSlot];
    return (id == null ? null : _s.content.recipeById(id)) ??
        _s.content.recipes.first;
  }

  Article get featuredArticle =>
      _s.content.articleById('busy-prep') ?? _s.content.allArticles.first;

  Future<void> load() async {
    state = LoadState.loading;
    notifyListeners();
    try {
      final key = dateKey(date);
      final loaded = await _s.meals.forDate(
        _uid,
        key,
        fault: FaultPoint.loadHome,
      );
      plan = await _s.plans.forDate(_uid, key);
      meals = loaded;
      state = LoadState.ready;
    } catch (e, st) {
      state = LoadState.error;
      await _s.crash.recordError(e, st, reason: 'home_load_failed');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _s.meals.removeListener(load);
    _s.plans.removeListener(load);
    super.dispose();
  }
}
