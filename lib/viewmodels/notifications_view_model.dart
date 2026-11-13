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
    _readInitialMessage();
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
  bool get isLocal => _s.isLocal;
  String? errorMessage;

  Future<void> _readInitialMessage() async {
    try {
      final message = await _s.messaging.initialMessage();
      if (!isDisposed && message != null) await _onOpened(message);
    } catch (error, stack) {
      await _s.crash.recordError(
        error,
        stack,
        reason: 'initial_message_failed',
      );
      if (isDisposed) return;
      errorMessage =
          'Chưa mở được thông báo. Bạn có thể xem lại trong lịch sử.';
      notifyListeners();
    }
  }

  Future<void> addLocalExample() async {
    if (!isLocal) return;
    await _onForeground(
      PushMessage(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        title: 'Thông báo mẫu trên thiết bị',
        body: 'Chạm để mở thư viện kiến thức. Đây không phải thông báo FCM.',
        route: '/library',
      ),
    );
  }

  void _onSessionChanged() {
    final uid = _session.restoring ? null : _session.uid;
    if (uid == _uid) {
      _flushPending();
      return;
    }
    _uid = uid;
    items = const [];
    notifyListeners();
    if (uid == null) return;
    reload();
    _flushPending();
  }

  void _flushPending() {
    if (_uid == null || _session.restoring || !_session.isOnboarded) return;
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
    try {
      final loaded = await _s.notifications.load(uid);
      if (uid != _uid || isDisposed) return;
      items = loaded;
      if (_s.backend != null) {
        try {
          final response = await _s.backend!.call(
            uid,
            '/notifications?limit=50',
          );
          if (uid != _uid || isDisposed) return;
          for (final row in response['items'] as List) {
            final value = Map<String, dynamic>.from(row as Map);
            if (value['status'] != 'accepted' && value['openedAt'] == null) {
              continue;
            }
            await _s.notifications.add(
              uid,
              AppNotification(
                id: value['id'] as String,
                title: value['title'] as String,
                body: value['body'] as String,
                route: value['route'] as String?,
                receivedAt: DateTime.parse(value['receivedAt'] as String),
                read: value['openedAt'] != null,
              ),
            );
            if (uid != _uid || isDisposed) return;
          }
          final merged = await _s.notifications.load(uid);
          if (uid != _uid || isDisposed) return;
          items = merged;
        } catch (_) {
          if (uid == _uid && !isDisposed) {
            errorMessage = 'Đang hiển thị lịch sử đã lưu trên thiết bị.';
          }
        }
      }
    } catch (_) {
      errorMessage =
          'Chưa tải được lịch sử thông báo. Hãy mở lại màn này để thử lại.';
    }
    notifyListeners();
    await _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    try {
      permission = await _s.messaging.permissionStatus();
    } catch (_) {
      errorMessage = 'Chưa đọc được quyền thông báo. Hãy thử lại.';
    }
    notifyListeners();
  }

  Future<void> requestPermission() async {
    errorMessage = null;
    try {
      permission = await _s.messaging.requestPermission();
      final uid = _uid;
      if (uid != null && permission == PushPermission.granted) {
        await _s.sync?.registerDevice(uid);
      }
    } catch (_) {
      errorMessage =
          'Chưa bật được thông báo. Kiểm tra cài đặt thiết bị rồi thử lại.';
    }
    notifyListeners();
  }

  /// Chỉ hỏi một lần sau onboarding, các lần sau người dùng tự bật ở màn Thông báo.
  Future<void> requestAfterOnboarding() async {
    await _refreshPermission();
    if (!isLocal && permission == PushPermission.notDetermined) {
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
    if (message.targetUid != null && message.targetUid != uid) return;
    if (uid == null) {
      if (_s.isFake) await NotificationRepository.enqueueFromBackground(item);
      return;
    }
    await _s.notifications.add(uid, item);
    if (uid != _uid || isDisposed) return;
    await reload();
    onForegroundShown?.call(item);
  }

  Future<void> _onOpened(PushMessage message) async {
    final uid = _uid;
    if (uid != null && message.targetUid != null && message.targetUid != uid) {
      return;
    }
    if (uid == null || !_session.isOnboarded) {
      // Người dùng phải đăng nhập trước, đăng nhập xong mới đưa tới đích.
      _pendingOpen = message;
      return;
    }
    await _s.notifications.add(uid, _toItem(message));
    if (uid != _uid || isDisposed) return;
    await open(message.id, source: 'system');
  }

  /// Đánh dấu đã đọc rồi đi tới màn trong thông báo.
  Future<void> open(String id, {required String source}) async {
    final uid = _uid;
    if (uid == null) return;
    await _s.notifications.markRead(uid, id);
    if (_s.backend != null) {
      try {
        await _s.backend!.call(
          uid,
          '/notifications/${Uri.encodeComponent(id)}/open',
          method: 'POST',
          body: {},
        );
      } catch (_) {
        errorMessage =
            'Đã mở trên thiết bị. Chưa cập nhật trạng thái lên máy chủ.';
      }
    }
    await reload();
    if (uid != _uid || isDisposed) return;
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
