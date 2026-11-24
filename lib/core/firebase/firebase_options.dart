// Environment-driven FirebaseOptions prepared for multi-platform FlutterFire builds.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Reads Firebase Web/Android/iOS credentials supplied via `--dart-define`
/// (or empty defaults when running in local offline/mock preview mode).
abstract final class FirebaseEnvOptions {
  /// Firebase project ID (`--dart-define=FIREBASE_PROJECT_ID=...`).
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'marprom-m-mobilnost',
  );

  /// Firebase Web/Client API key (`--dart-define=FIREBASE_API_KEY=...`).
  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');

  /// Firebase App ID (`--dart-define=FIREBASE_APP_ID=...`).
  static const String appId = String.fromEnvironment('FIREBASE_APP_ID');

  /// Firebase Cloud Messaging sender ID (`--dart-define=FIREBASE_MESSAGING_SENDER_ID=...`).
  static const String messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');

  /// Firebase Auth domain (`--dart-define=FIREBASE_AUTH_DOMAIN=...`).
  static const String authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'marprom-m-mobilnost.firebaseapp.com',
  );

  /// Firebase Storage bucket (`--dart-define=FIREBASE_STORAGE_BUCKET=...`).
  static const String storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'marprom-m-mobilnost.firebasestorage.app',
  );

  /// True once real Firebase project credentials are supplied for build/deploy.
  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  /// Returns platform [FirebaseOptions] constructed from build-time environment defines.
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: storageBucket,
          iosBundleId: 'si.marprom.mMobilnost',
        );
      default:
        return const FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: storageBucket,
        );
    }
  }
}
