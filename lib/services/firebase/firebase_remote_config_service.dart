import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../service_interfaces.dart';

class FirebaseRemoteConfigService extends RemoteConfigService {
  final _config = FirebaseRemoteConfig.instance;
  StreamSubscription<RemoteConfigUpdate>? _updates;
  String _status = 'Đang dùng giá trị mặc định trong app.';

  @override
  int get maxKnowledgeResults =>
      _config.getInt(RemoteConfigKeys.maxKnowledgeResults);

  @override
  bool get suggestedRecipesEnabled =>
      _config.getBool(RemoteConfigKeys.suggestedRecipesEnabled);

  @override
  String get status => _status;

  @override
  Future<void> init() async {
    await _config.setDefaults(RemoteConfigKeys.defaults);
    await _config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // Bản debug tải ngay để demo. Bản phát hành dùng lại bộ đệm trong 1 giờ.
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(hours: 1),
      ),
    );
    // Không chờ mạng lúc mở app: mặc định đã sẵn sàng, tải xong sẽ tự cập nhật.
    unawaited(refresh());
    // Lắng nghe thay đổi từ Console. Mất mạng thì app vẫn chạy bằng giá trị đang có.
    _updates = _config.onConfigUpdated.listen((_) async {
      await _config.activate();
      _status = 'Đã nhận cấu hình mới từ Firebase.';
      notifyListeners();
    }, onError: (Object e) => debugPrint('Remote Config realtime: $e'));
  }

  @override
  Future<void> refresh() async {
    try {
      await _config.fetchAndActivate();
      _status = 'Đã tải cấu hình lúc ${_config.lastFetchTime}.';
    } catch (e) {
      debugPrint('Remote Config fetch: $e');
      _status = 'Chưa tải được. App đang dùng giá trị đã lưu hoặc mặc định.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _updates?.cancel();
    super.dispose();
  }
}
