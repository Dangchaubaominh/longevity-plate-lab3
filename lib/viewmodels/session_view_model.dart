import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app/app_services.dart';
import '../services/app_failure.dart';
import '../services/service_interfaces.dart';

class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this._s) : _user = _s.auth.currentUser {
    _sub = _s.auth.userChanges.listen(_onUser);
    _applyIdentity();
    if (_user != null && _s.sync != null) unawaited(_restore(_user!.uid));
  }

  final AppServices _s;
  late final StreamSubscription<AppUser?> _sub;
  AppUser? _user;
  bool _signingIn = false;
  bool restoring = false;
  int _generation = 0;
  String? _message;

  AppUser? get user => _user;
  String? get uid => _user?.uid;
  bool get isSignedIn => _user != null;
  bool get isSigningIn => _signingIn;
  String? get message => _message;
  bool get isOnboarded =>
      _user != null && !restoring && _s.goals.isOnboarded(_user!.uid);

  /// Tên gọi ở màn Hôm nay. Thứ tự họ tên trên tài khoản Google không cố định
  /// nên hiển thị đủ, không tách tên riêng.
  String get greetingName {
    final name = _user?.displayName?.trim();
    return name == null || name.isEmpty ? 'bạn' : name;
  }

  void _onUser(AppUser? user) {
    if (user?.uid == _user?.uid) return;
    _user = user;
    if (user != null) _message = null;
    _applyIdentity();
    if (user != null && _s.sync != null) {
      unawaited(_restore(user.uid));
    } else if (user == null) {
      _generation++;
      restoring = false;
      unawaited(_s.sync?.deactivate() ?? Future.value());
    }
    notifyListeners();
  }

  Future<void> _restore(String uid) async {
    final generation = ++_generation;
    restoring = true;
    notifyListeners();
    try {
      await _s.sync!.activate(uid);
    } catch (_) {
      if (generation == _generation) {
        _message = 'Dữ liệu trên thiết bị vẫn được giữ. Mở Đồng bộ để thử lại.';
      }
    } finally {
      if (generation == _generation) {
        restoring = false;
        notifyListeners();
      }
    }
  }

  // Chỉ gửi uid, không gửi email hay tên lên Analytics và Crashlytics.
  void _applyIdentity() {
    _s.analytics.setUserId(uid);
    _s.crash.setUserId(uid);
  }

  Future<void> signIn() async {
    if (_signingIn) return;
    _signingIn = true;
    _message = null;
    notifyListeners();
    try {
      await _s.auth.signInWithGoogle();
      await _s.analytics.logEvent(AnalyticsEvents.login, {
        'method': _s.isLocal ? 'local' : 'google',
      });
    } on SignInCancelled {
      _message = 'Bạn đã hủy đăng nhập. Bạn có thể thử lại bất kỳ lúc nào.';
    } catch (e, st) {
      _message = _describe(e);
      await _s.crash.recordError(e, st, reason: 'sign_in_failed');
    } finally {
      _signingIn = false;
      notifyListeners();
    }
  }

  String _describe(Object error) {
    final code = error is AppFailure ? error.code : '';
    if (code.contains('network')) {
      return 'Không có kết nối mạng. Hãy kiểm tra mạng rồi thử lại.';
    }
    if (code.contains('onfiguration') || code == 'google_missing_id_token') {
      return 'Đăng nhập Google chưa được cấu hình đúng cho bản cài này.';
    }
    return 'Chưa đăng nhập được. Kiểm tra kết nối rồi thử lại.';
  }

  /// ViewModel theo từng màn bị hủy cùng màn, nên đăng xuất cũng xóa trạng thái
  /// cục bộ. Dữ liệu đã lưu theo uid không bị xóa.
  Future<void> signOut() async {
    try {
      await _s.analytics.logEvent(AnalyticsEvents.logout);
      await _s.sync?.deactivate();
      await _s.auth.signOut();
    } catch (e, st) {
      _message = 'Chưa đăng xuất được. Vui lòng thử lại.';
      await _s.crash.recordError(e, st, reason: 'sign_out_failed');
      notifyListeners();
    }
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  /// Gọi sau khi lưu mục tiêu để bộ định tuyến tính lại điều hướng.
  void refreshOnboarding() => notifyListeners();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
