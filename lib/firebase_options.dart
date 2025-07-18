// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
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
        return windows;
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
    apiKey: 'AIzaSyDoFbvPf-vbI8IOyV7_58PtUGnkHHgxUCE',
    appId: '1:765090949581:web:69b0698f051ecac7223c84',
    messagingSenderId: '765090949581',
    projectId: 'guideme-eb7a2',
    authDomain: 'guideme-eb7a2.firebaseapp.com',
    storageBucket: 'guideme-eb7a2.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCpi-faxN1hToeQC9OvF81vkgsjxEtu9wI',
    appId: '1:765090949581:android:f6d7546687dc6b69223c84',
    messagingSenderId: '765090949581',
    projectId: 'guideme-eb7a2',
    storageBucket: 'guideme-eb7a2.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAF3ZY259D6gi0f_jrmAH3agK47bT2mZAI',
    appId: '1:765090949581:ios:47a946aec1944339223c84',
    messagingSenderId: '765090949581',
    projectId: 'guideme-eb7a2',
    storageBucket: 'guideme-eb7a2.firebasestorage.app',
    iosBundleId: 'com.example.guideme',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAF3ZY259D6gi0f_jrmAH3agK47bT2mZAI',
    appId: '1:765090949581:ios:47a946aec1944339223c84',
    messagingSenderId: '765090949581',
    projectId: 'guideme-eb7a2',
    storageBucket: 'guideme-eb7a2.firebasestorage.app',
    iosBundleId: 'com.example.guideme',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDoFbvPf-vbI8IOyV7_58PtUGnkHHgxUCE',
    appId: '1:765090949581:web:61c48df3fa979e47223c84',
    messagingSenderId: '765090949581',
    projectId: 'guideme-eb7a2',
    authDomain: 'guideme-eb7a2.firebaseapp.com',
    storageBucket: 'guideme-eb7a2.firebasestorage.app',
  );
}
