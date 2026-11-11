import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase Web is not configured.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Firebase is not configured for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBrbXWSax0ahg5ZTXDXk5NQ8XpJxS1HXgQ',
    appId: '1:490880482076:android:2f1d73f7bcb8bc7db158d9',
    messagingSenderId: '490880482076',
    projectId: 'longevity-plate-beff9',
    storageBucket: 'longevity-plate-beff9.firebasestorage.app',
  );
}
