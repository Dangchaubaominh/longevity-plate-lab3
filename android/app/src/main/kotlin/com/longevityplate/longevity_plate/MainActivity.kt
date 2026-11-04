package com.longevityplate.longevity_plate

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // FCM chép custom data vào Intent, còn FlutterActivity lấy extra "route" làm
    // route khởi đầu. Bỏ qua để route trong thông báo luôn đi qua resolvePushRoute.
    override fun getInitialRoute(): String? = null
}
