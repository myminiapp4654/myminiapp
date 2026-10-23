import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      if (web.appId.isEmpty || web.apiKey.isEmpty) {
        throw UnsupportedError(
            "Veb sozlamasi to'ldirilmagan: lib/firebase_options.dart dagi "
            "'web' bo'limiga Firebase Console'dan apiKey va appId ni qo'ying");
      }
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Bu platforma qo\'llanilmaydi');
    }
  }

  // Firebase Console -> Project settings -> Your apps -> Web app (</>)
  // qo'shing va u bergan apiKey, appId, measurementId ni shu yerga yozing.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '1095410537471',
    projectId: 'online-game-9f0e5',
    authDomain: 'online-game-9f0e5.firebaseapp.com',
    storageBucket: 'online-game-9f0e5.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA5xnK9V3KKUd_FzYpa3k0QGB_ftaQuoUM',
    appId: '1:1095410537471:android:4bec00a3633e40a7958dca',
    messagingSenderId: '1095410537471',
    projectId: 'online-game-9f0e5',
    storageBucket: 'online-game-9f0e5.firebasestorage.app',
  );
}
