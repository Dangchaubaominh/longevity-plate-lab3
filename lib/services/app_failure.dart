import 'package:flutter/foundation.dart';

class AppFailure implements Exception {
  const AppFailure(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => 'AppFailure($code)';
}

/// Các điểm có thể giả lập lỗi từ Khu vực trình diễn, để trình diễn và kiểm thử
/// nhánh lỗi của F01–F03 khi dữ liệu local hiếm khi lỗi thật.
enum FaultPoint {
  loadHome('Lỗi tải màn Hôm nay (S03)'),
  loadLog('Lỗi tải Nhật ký (S04)'),
  loadPlan('Lỗi tải Kế hoạch (S06)'),
  loadLibrary('Lỗi tải Thư viện (S08)'),
  loadDetail('Lỗi tải chi tiết món/bài (S07, S09)'),
  saveGoals('Lỗi lưu mục tiêu (S02)'),
  saveMeal('Lỗi lưu bữa ăn (S05)'),
  savePlan('Lỗi lưu kế hoạch (S07)'),
  uploadReport('Lỗi tải báo cáo lên (S04)');

  const FaultPoint(this.label);
  final String label;
}

/// Lỗi chỉ xảy ra một lần rồi tự tắt, nên "Thử lại" sẽ thành công.
class FaultInjector extends ChangeNotifier {
  final _armed = <FaultPoint>{};

  bool isArmed(FaultPoint point) => _armed.contains(point);

  void set(FaultPoint point, bool armed) {
    armed ? _armed.add(point) : _armed.remove(point);
    notifyListeners();
  }

  void check(FaultPoint point) {
    if (_armed.remove(point)) {
      notifyListeners();
      throw AppFailure('simulated_${point.name}');
    }
  }
}
