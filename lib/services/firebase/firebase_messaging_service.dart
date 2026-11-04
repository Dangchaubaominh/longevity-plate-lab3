import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../../models/models.dart';
import '../repositories.dart';
import '../service_interfaces.dart';

PushMessage _toPush(RemoteMessage message) => PushMessage(
  id:
      message.messageId ??
      message.sentTime?.toIso8601String() ??
      DateTime.now().microsecondsSinceEpoch.toString(),
  title: message.notification?.title ?? 'Longevity Plate',
  body: message.notification?.body ?? '',
  route: message.data['route'] as String?,
);

/// Chạy ở isolate riêng khi app ở nền hoặc đã đóng, không dùng được Provider.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final push = _toPush(message);
  await NotificationRepository.enqueueFromBackground(
    AppNotification(
      id: push.id,
      title: push.title,
      body: push.body,
      route: push.route,
      receivedAt: message.sentTime ?? DateTime.now(),
    ),
  );
}

class FirebaseMessagingService implements MessagingService {
  FirebaseMessagingService() {
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  }

  final _messaging = FirebaseMessaging.instance;

  PushPermission _map(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushPermission.granted,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };

  @override
  Stream<PushMessage> get onForeground =>
      FirebaseMessaging.onMessage.map(_toPush);

  @override
  Stream<PushMessage> get onOpened =>
      FirebaseMessaging.onMessageOpenedApp.map(_toPush);

  @override
  Future<PushMessage?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _toPush(message);
  }

  @override
  Future<PushPermission> permissionStatus() async =>
      _map((await _messaging.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async =>
      _map((await _messaging.requestPermission()).authorizationStatus);

  @override
  Future<String?> token() async {
    try {
      // API mới register()/onRegistered trả về FID. Form gửi thử trên Firebase
      // Console vẫn nhận registration token nên lab tiếp tục dùng getToken().
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('Không lấy được FCM token: $e');
      return null;
    }
  }
}
