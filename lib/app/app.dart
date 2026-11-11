import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/push_routes.dart';
import '../models/models.dart';
import '../viewmodels/notifications_view_model.dart';
import '../viewmodels/session_view_model.dart';
import 'app_services.dart';
import 'router.dart';
import 'theme.dart';

class LongevityPlateApp extends StatefulWidget {
  const LongevityPlateApp({super.key, required this.services});

  final AppServices services;

  @override
  State<LongevityPlateApp> createState() => _LongevityPlateAppState();
}

class _LongevityPlateAppState extends State<LongevityPlateApp>
    with WidgetsBindingObserver {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final SessionViewModel _session;
  late final NotificationsViewModel _notifications;
  late final GoRouter _router;

  String? _lastTrackedPath;

  @override
  void initState() {
    super.initState();
    _session = SessionViewModel(widget.services);
    _router = buildRouter(_session);
    _router.routerDelegate.addListener(_onRouteChanged);
    _onRouteChanged();
    _notifications = NotificationsViewModel(widget.services, _session)
      ..onNavigate = _navigate
      ..onForegroundShown = _showForeground;
    WidgetsBinding.instance.addObserver(this);
  }

  // Theo dõi màn đang mở cho Analytics và gắn vào báo cáo Crashlytics.
  void _onRouteChanged() {
    final path = currentPath(_router);
    if (path.isEmpty || path == _lastTrackedPath) return;
    _lastTrackedPath = path;
    widget.services.analytics.logScreen(path);
    widget.services.crash.setKey('route', path);
  }

  void _navigate(String route) {
    // Thông báo mở app có thể đến trước khi router dựng xong màn đầu tiên.
    if (_router.routerDelegate.currentConfiguration.isEmpty) {
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => _navigate(route))
        ..scheduleFrame();
      return;
    }
    if (route == currentPath(_router)) return;
    tabRoutes.contains(route) ? _router.go(route) : _router.push(route);
  }

  void _showForeground(AppNotification item) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(item.title),
        action: SnackBarAction(
          label: 'Xem',
          onPressed: () => _notifications.open(item.id, source: 'foreground'),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _notifications.reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.routerDelegate.removeListener(_onRouteChanged);
    _router.dispose();
    _notifications.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.services),
        ChangeNotifierProvider.value(value: _session),
        ChangeNotifierProvider.value(value: _notifications),
      ],
      child: MaterialApp.router(
        title: 'Longevity Plate',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        scaffoldMessengerKey: _messengerKey,
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router,
        builder: widget.services.isLocal
            ? (context, child) => Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: Container(
                      width: double.infinity,
                      color: AppColors.selected,
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      child: const Text(
                        'OFFLINE · Dữ liệu lưu trên điện thoại',
                        style: AppText.caption,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Expanded(child: child!),
                ],
              )
            : null,
      ),
    );
  }
}

/// Hiện khi Firebase chưa được cấu hình, thay vì màn trắng hoặc crash lúc mở app.
class FirebaseSetupErrorApp extends StatelessWidget {
  const FirebaseSetupErrorApp({
    super.key,
    required this.error,
    this.onContinueOffline,
  });

  final Object error;
  final VoidCallback? onContinueOffline;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.lg),
            children: [
              const Text('Chưa kết nối được Firebase', style: AppText.title),
              const SizedBox(height: AppSpace.sm),
              const Text(
                'Hãy chạy "flutterfire configure" theo docs/SETUP-FIREBASE.md rồi cài lại app.',
                style: AppText.body,
              ),
              const SizedBox(height: AppSpace.lg),
              SelectableText('$error', style: AppText.caption),
              if (onContinueOffline != null) ...[
                const SizedBox(height: AppSpace.lg),
                FilledButton(
                  onPressed: onContinueOffline,
                  child: const Text('Tiếp tục bằng chế độ offline'),
                ),
                const Text(
                  'Chế độ này lưu dữ liệu trên máy, không đăng nhập Google và không gửi dữ liệu lên Firebase.',
                  style: AppText.caption,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
