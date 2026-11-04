import 'package:flutter/foundation.dart';

import '../app/app_services.dart';
import '../models/models.dart';
import '../services/service_interfaces.dart';
import 'safe_notifier.dart';
import 'session_view_model.dart';

class GoalViewModel extends ChangeNotifier with SafeNotifier {
  GoalViewModel(this._s, this._session, this._uid, {required this.isEditing})
    : selected = _s.goals.load(_uid) {
    if (!isEditing) _s.analytics.logEvent(AnalyticsEvents.tutorialBegin);
  }

  final AppServices _s;
  final SessionViewModel _session;
  final String _uid;
  final bool isEditing;
  final _timer = Stopwatch()..start();

  final Set<Goal> selected;
  bool showRequiredError = false;
  bool saving = false;
  bool saveFailed = false;

  void toggle(Goal goal) {
    if (saving) return;
    selected.contains(goal) ? selected.remove(goal) : selected.add(goal);
    if (selected.isNotEmpty) showRequiredError = false;
    saveFailed = false;
    notifyListeners();
  }

  Future<bool> submit() async {
    if (saving) return false;
    if (selected.isEmpty) {
      showRequiredError = true;
      notifyListeners();
      return false;
    }
    saving = true;
    saveFailed = false;
    notifyListeners();
    try {
      await _s.goals.save(_uid, selected);
      // Khi đổi mục tiêu, người dùng đã onboarding nên điều hướng không đổi.
      if (!isEditing) {
        await _s.analytics.logEvent(AnalyticsEvents.tutorialComplete, {
          'goal_count': selected.length,
          'duration_ms': _timer.elapsedMilliseconds,
        });
        _session.refreshOnboarding();
      }
      return true;
    } catch (e, st) {
      saveFailed = true;
      await _s.crash.recordError(e, st, reason: 'goal_save_failed');
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
