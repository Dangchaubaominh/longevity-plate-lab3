import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app/app_services.dart';
import '../core/push_routes.dart';
import '../models/models.dart';
import '../services/repositories.dart';
import '../services/service_interfaces.dart';
import 'safe_notifier.dart';
import 'session_view_model.dart';

class NotificationsViewModel extends ChangeNotifier with SafeNotifier {
  NotificationsViewModel(this._s, this._session) {
    _session.addListener(_onSessionChanged);
    _subs = [
      _s.messaging.onForeground.listen(_onForeground),
      _s.messaging.onOpened.listen(_onOpened),
    ];
    _onSessionChanged();
    _refreshPermission();
    _s.messaging.initialMessage().then(
      (message) {
        if (message != null) _onOpened(message);
      },
      // Lỗi ở đây không làm app dừng, nên ghi non-fatal thay vì để thành crash.
      onError: (Object e, StackTrace st) {
        _s.crash.recordError(e, st, reason: 'initial_message_failed');
      },
    );
  }

  final AppServices _s;
  final SessionViewModel _session;
  late final List<StreamSubscription<PushMessage>> _subs;
  String? _uid;
  PushMessage? _pendingOpen;

  List<AppNotification> items = const [];
  PushPermission permission = PushPermission.notDetermined;

  /// App gán hai callback này để hiện SnackBar và điều hướng.
  void Function(AppNotification item)? onForegroundShown;
  void Function(String route)? onNavigate;

  int get unreadCount => items.where((n) => !n.read).length;
  bool get permissionDenied => permission == PushPermission.denied;
  bool get permissionMissing => permission != PushPermission.granted;

  void _onSessionChanged() {
    final uid = _session.uid;
    if (uid == _uid) return;
    _uid = uid;
    items = const [];
    notifyListeners();
    if (uid == null) return;
    reload();
    final pending = _pendingOpen;
    if (pending != null) {
      _pendingOpen = null;
      _onOpened(pending);
    }
  }

  /// Gọi khi mở app và khi quay lại từ nền, để nhận các tin handler nền đã ghi.
  Future<void> reload() async {
    final uid = _uid;
    if (uid == null) return;
    final loaded = await _s.notifications.load(uid);
    if (uid != _uid) return;
    items = loaded;
    notifyListeners();
    await _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    permission = await _s.messaging.permissionStatus();
    notifyListeners();
  }

  Future<void> requestPermission() async {
    permission = await _s.messaging.requestPermission();
    notifyListeners();
  }

  /// Chỉ hỏi một lần sau onboarding, các lần sau người dùng tự bật ở màn Thông báo.
  Future<void> requestAfterOnboarding() async {
    if (await _s.messaging.permissionStatus() == PushPermission.notDetermined) {
      await requestPermission();
    }
  }

  AppNotification _toItem(PushMessage message) => AppNotification(
    id: message.id,
    title: message.title,
    body: message.body,
    route: message.route,
    receivedAt: DateTime.now(),
  );

  Future<void> _onForeground(PushMessage message) async {
    final item = _toItem(message);
    final uid = _uid;
    if (uid == null) {
      await NotificationRepository.enqueueFromBackground(item);
      return;
    }
    await _s.notifications.add(uid, item);
    await reload();
    onForegroundShown?.call(item);
  }

  Future<void> _onOpened(PushMessage message) async {
    final uid = _uid;
    if (uid == null) {
      // Người dùng phải đăng nhập trước, đăng nhập xong mới đưa tới đích.
      _pendingOpen = message;
      return;
    }
    await _s.notifications.add(uid, _toItem(message));
    await open(message.id, source: 'system');
  }

  /// Đánh dấu đã đọc rồi đi tới màn trong thông báo.
  Future<void> open(String id, {required String source}) async {
    final uid = _uid;
    if (uid == null) return;
    await _s.notifications.markRead(uid, id);
    await reload();
    final item = items.where((n) => n.id == id).firstOrNull;
    final route = resolvePushRoute(item?.route);
    await _s.analytics.logEvent(AnalyticsEvents.notificationOpened, {
      'source': source,
      'target': route,
    });
    onNavigate?.call(route);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}
