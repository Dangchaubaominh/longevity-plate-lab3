import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../service_interfaces.dart';

/// Analytics chỉ để đo, nên lỗi ở đây không được làm hỏng thao tác của người
/// dùng, ví dụ báo lưu bữa thất bại trong khi bữa đã được lưu.
class FirebaseAnalyticsService implements AnalyticsService {
  final _analytics = FirebaseAnalytics.instance;

  Future<void> _safe(String what, Future<void> Function() call) async {
    try {
      await call();
    } catch (e) {
      debugPrint('Analytics $what: $e');
    }
  }

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object> parameters = const {},
  ]) => _safe(
    name,
    () => _analytics.logEvent(name: name, parameters: parameters),
  );

  @override
  Future<void> logScreen(String name) =>
      _safe('screen', () => _analytics.logScreenView(screenName: name));

  @override
  Future<void> setUserId(String? uid) =>
      _safe('user id', () => _analytics.setUserId(id: uid));
}
