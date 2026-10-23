import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web platformasi sozlanmagan');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Bu platforma qo\'llanilmaydi');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA5xnK9V3KKUd_FzYpa3k0QGB_ftaQuoUM',
    appId: '1:1095410537471:android:4bec00a3633e40a7958dca',
    messagingSenderId: '1095410537471',
    projectId: 'online-game-9f0e5',
    storageBucket: 'online-game-9f0e5.firebasestorage.app',
  );
}
