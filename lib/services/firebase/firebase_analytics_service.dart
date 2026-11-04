import 'package:firebase_analytics/firebase_analytics.dart';

import '../service_interfaces.dart';

class FirebaseAnalyticsService implements AnalyticsService {
  final _analytics = FirebaseAnalytics.instance;

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object> parameters = const {},
  ]) => _analytics.logEvent(name: name, parameters: parameters);

  @override
  Future<void> logScreen(String name) =>
      _analytics.logScreenView(screenName: name);

  @override
  Future<void> setUserId(String? uid) => _analytics.setUserId(id: uid);
}
