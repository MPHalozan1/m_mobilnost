//**********************************************
// FirebaseOptions for m-mobilnost-2 (Web/App) *
//**********************************************

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Provides live Firebase credentials for project `m-mobilnost-2` across Web
/// and Android, with optional `--dart-define` overrides.
abstract final class FirebaseEnvOptions {
  /// Firebase project ID (`m-mobilnost-2`).
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'm-mobilnost-2',
  );

  /// Firebase Web API key (`m-mobilnost-2`).
  static const String webApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyA2kSTlNOabv2ZbUDvwAN-UVqkTTQUsQtw',
  );

  /// Firebase Web App ID (`m-mobilnost-2`).
  static const String webAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:500961598933:web:3eecf85537ca71a220315c',
  );

  /// Firebase Android API key (`m-mobilnost-2`).
  static const String androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
    defaultValue: 'AIzaSyAJNG4TFmCAskZhgjMwQEeK2dnolsANH7g',
  );

  /// Firebase Android App ID (`m-mobilnost-2`).
  static const String androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '1:500961598933:android:5ed776e20ed8866820315c',
  );

  /// Firebase Cloud Messaging sender ID (`500961598933`).
  static const String messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '500961598933',
  );

  /// Firebase Auth domain (`m-mobilnost-2.firebaseapp.com`).
  static const String authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'm-mobilnost-2.firebaseapp.com',
  );

  /// Firebase Storage bucket (`m-mobilnost-2.firebasestorage.app`).
  static const String storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'm-mobilnost-2.firebasestorage.app',
  );

  /// Measurement ID for Web Analytics.
  static const String measurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
    defaultValue: 'G-LTQ47XTBC9',
  );

  /// True when Firebase project credentials are available.
  static bool get isConfigured =>
      projectId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      (kIsWeb
          ? webApiKey.isNotEmpty && webAppId.isNotEmpty
          : androidApiKey.isNotEmpty && androidAppId.isNotEmpty);

  /// Returns platform [FirebaseOptions] for `m-mobilnost-2`.
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: webApiKey,
        appId: webAppId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
        measurementId: measurementId,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const FirebaseOptions(
          apiKey: androidApiKey,
          appId: androidAppId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: storageBucket,
          iosBundleId: 'si.marprom.mMobilnost',
        );
      default:
        return const FirebaseOptions(
          apiKey: androidApiKey,
          appId: androidAppId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: storageBucket,
        );
    }
  }
}
