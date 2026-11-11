import 'package:flutter/foundation.dart';

import 'service_interfaces.dart';

/// Lỗi đo lường không được đổi kết quả một thao tác nghiệp vụ đã thành công.
class ResilientAnalyticsService implements AnalyticsService {
  ResilientAnalyticsService(this._delegate);
  final AnalyticsService _delegate;

  Future<void> _attempt(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      debugPrint('Analytics chưa gửi được: $error');
    }
  }

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object> parameters = const {},
  ]) => _attempt(() => _delegate.logEvent(name, parameters));

  @override
  Future<void> logScreen(String name) =>
      _attempt(() => _delegate.logScreen(name));

  @override
  Future<void> setUserId(String? uid) =>
      _attempt(() => _delegate.setUserId(uid));
}
