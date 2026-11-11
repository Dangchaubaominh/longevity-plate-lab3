import 'package:flutter/foundation.dart';

/// Tác vụ bất đồng bộ có thể xong sau khi rời màn, lúc đó bỏ qua thông báo.
mixin SafeNotifier on ChangeNotifier {
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
