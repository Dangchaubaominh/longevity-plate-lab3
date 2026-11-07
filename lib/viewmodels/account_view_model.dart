import 'package:flutter/foundation.dart';

import '../app/app_services.dart';
import '../models/models.dart';
import '../services/app_failure.dart';
import 'safe_notifier.dart';

class AccountViewModel extends ChangeNotifier with SafeNotifier {
  AccountViewModel(this._s, this._uid) {
    _s.remoteConfig.addListener(notifyListeners);
    _s.faults.addListener(notifyListeners);
    _loadToken();
  }

  final AppServices _s;
  final String _uid;

  String? token;
  String? probeResult;
  bool probing = false;
  bool refreshingConfig = false;
  String? nonFatalMessage;

  Set<Goal> get goals => _s.goals.load(_uid);
  bool get isFake => _s.isFake;

  void reloadGoals() => notifyListeners();

  int get maxKnowledgeResults => _s.remoteConfig.maxKnowledgeResults;
  bool get suggestedRecipesEnabled => _s.remoteConfig.suggestedRecipesEnabled;
  String get configStatus => _s.remoteConfig.status;

  bool isArmed(FaultPoint point) => _s.faults.isArmed(point);
  void setFault(FaultPoint point, bool armed) => _s.faults.set(point, armed);

  Future<void> _loadToken() async {
    token = await _s.messaging.token();
    notifyListeners();
  }

  Future<void> refreshConfig() async {
    refreshingConfig = true;
    notifyListeners();
    await _s.remoteConfig.refresh();
    refreshingConfig = false;
    notifyListeners();
  }

  /// Kết quả mong đợi là bị từ chối, nghĩa là server báo cáo đang kiểm tra quyền.
  Future<void> probeForeignReport() async {
    probing = true;
    probeResult = null;
    notifyListeners();
    final code = await _s.storage.probeForeignReport();
    probeResult = code == 'allowed'
        ? 'CẢNH BÁO: server cấp link báo cáo của UID khác. Hãy kiểm tra lại server báo cáo.'
        : code == 'unauthorized'
        ? 'Bị từ chối đúng như mong đợi (unauthorized).'
        : 'Kết quả khác: $code. Kiểm tra mạng và server báo cáo.';
    probing = false;
    notifyListeners();
  }

  Future<void> sendNonFatal() async {
    await _s.crash.recordError(
      const AppFailure('demo_non_fatal'),
      StackTrace.current,
      reason: 'demo_non_fatal',
    );
    nonFatalMessage = 'Đã ghi lỗi non-fatal. Crashlytics có thể mất vài phút để hiển thị.';
    notifyListeners();
  }

  void testCrash() => _s.crash.testCrash();

  @override
  void dispose() {
    _s.remoteConfig.removeListener(notifyListeners);
    _s.faults.removeListener(notifyListeners);
    super.dispose();
  }
}
