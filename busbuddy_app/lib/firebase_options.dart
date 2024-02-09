// File generated by FlutterFire CLI.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBY19tyzW1E6RQoK1sHQPFZwwhyGNuo_F4',
    appId: '1:567556902142:web:9fb82c727fde598b2369af',
    messagingSenderId: '567556902142',
    projectId: 'busbuddy-user-end',
    authDomain: 'busbuddy-user-end.firebaseapp.com',
    storageBucket: 'busbuddy-user-end.appspot.com',
    measurementId: 'G-WYJF5B03HE',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCC_6xihngZ8_-VqnxYRcV4dFBK3Ov8sCU',
    appId: '1:567556902142:android:5452623e8ac399e32369af',
    messagingSenderId: '567556902142',
    projectId: 'busbuddy-user-end',
    storageBucket: 'busbuddy-user-end.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBhssBQmS29nFmpmTvqzFj_Kg2FdYLcEMI',
    appId: '1:567556902142:ios:fdac2defbb182a022369af',
    messagingSenderId: '567556902142',
    projectId: 'busbuddy-user-end',
    storageBucket: 'busbuddy-user-end.appspot.com',
    iosBundleId: 'com.example.busbuddyApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBhssBQmS29nFmpmTvqzFj_Kg2FdYLcEMI',
    appId: '1:567556902142:ios:f751a7cd9ce5abca2369af',
    messagingSenderId: '567556902142',
    projectId: 'busbuddy-user-end',
    storageBucket: 'busbuddy-user-end.appspot.com',
    iosBundleId: 'com.example.busbuddyApp.RunnerTests',
  );
}