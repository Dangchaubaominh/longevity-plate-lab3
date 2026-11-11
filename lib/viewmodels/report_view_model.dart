import 'package:flutter/foundation.dart';

import '../app/app_services.dart';
import '../core/dates.dart';
import '../services/app_failure.dart';
import '../services/service_interfaces.dart';
import 'safe_notifier.dart';

enum ReportPhase { idle, building, uploading, success, failure }

class ReportViewModel extends ChangeNotifier with SafeNotifier {
  ReportViewModel(this._s, this._uid);

  static const days = 7;

  final AppServices _s;
  final String _uid;

  ReportPhase phase = ReportPhase.idle;
  double progress = 0;
  String? url;
  String? errorMessage;
  String? notice;
  int mealCount = 0;

  bool get isBusy =>
      phase == ReportPhase.building || phase == ReportPhase.uploading;
  bool get isLocal => _s.isLocal;

  Future<void> export() async {
    if (isBusy) return;
    phase = ReportPhase.building;
    progress = 0;
    url = null;
    errorMessage = null;
    notice = null;
    notifyListeners();
    try {
      final to = today();
      final from = addDays(to, -(days - 1));
      final meals = _s.meals.inRange(_uid, from, to);
      mealCount = meals.length;
      final bytes = await _s.reports.build(meals: meals, from: from, to: to);

      phase = ReportPhase.uploading;
      notifyListeners();
      final fileName =
          'meal-report-${DateTime.now().millisecondsSinceEpoch}.pdf';
      final upload = _s.storage.upload(
        uid: _uid,
        fileName: fileName,
        bytes: bytes,
      );
      await for (final update in upload) {
        progress = update.fraction;
        url = update.downloadUrl ?? url;
        notifyListeners();
      }
      if (url == null) throw const AppFailure('missing_download_url');

      phase = ReportPhase.success;
      await _s.analytics.logEvent(AnalyticsEvents.reportExported, {
        'meal_count': mealCount,
        'size_kb': bytes.length ~/ 1024,
      });
    } catch (e, st) {
      phase = ReportPhase.failure;
      errorMessage = _describe(e);
      await _s.analytics.logEvent(AnalyticsEvents.reportExportFailed, {
        'code': e is AppFailure ? e.code : 'unknown',
      });
      await _s.crash.recordError(e, st, reason: 'report_export_failed');
    }
    notifyListeners();
  }

  String _describe(Object error) {
    final code = error is AppFailure ? error.code : '';
    if (code == 'save_cancelled') {
      return 'Bạn đã hủy lưu PDF. Bấm Thử lại để chọn nơi lưu.';
    }
    if (isLocal) {
      return 'Chưa lưu được PDF vào máy. Kiểm tra dung lượng rồi thử lại.';
    }
    if (code == 'unauthorized' || code == 'unauthenticated') {
      return 'Bạn không có quyền lưu tệp vào vị trí này. Hãy đăng nhập lại.';
    }
    if (code == 'retry-limit-exceeded' || code.contains('network')) {
      return 'Mất kết nối khi tải lên. Kiểm tra mạng rồi thử lại.';
    }
    return 'Chưa tải được báo cáo lên. Vui lòng thử lại.';
  }

  void showNotice(String message) {
    notice = message;
    notifyListeners();
  }

  Future<void> openReport() async {
    var opened = false;
    try {
      opened = await _s.openLink(Uri.parse(url!));
    } catch (e, st) {
      await _s.crash.recordError(e, st, reason: 'open_link_failed');
    }
    if (!opened) showNotice('Không mở được đường dẫn báo cáo.');
  }
}
