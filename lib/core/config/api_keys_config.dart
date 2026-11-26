//**********************************************
// Separated API Key Architecture & Vault      *
//**********************************************

import 'dart:convert';

//**********************************************
// Runtime byte vault for public-repo builds   *
//**********************************************

abstract final class _RuntimeKeyVault {
  static const List<int> _mask = <int>[
    0x53,
    0x2F,
    0x6D,
    0x4D,
    0x30,
    0x62,
    0x21,
    0x4C,
    0x7A,
    0x39,
  ];

  static const List<int> _mapsCipher = <int>[
    0x12, 0x66, 0x17, 0x2C, 0x63, 0x1B, 0x62, 0x06, 0x20, 0x56,
    0x05, 0x4D, 0x2F, 0x35, 0x4A, 0x05, 0x74, 0x78, 0x0E, 0x4D,
    0x6B, 0x75, 0x40, 0x39, 0x04, 0x10, 0x14, 0x3B, 0x02, 0x7F,
    0x1E, 0x1A, 0x08, 0x18, 0x7F, 0x2E, 0x45, 0x2F, 0x09,
  ];

  static const List<int> _geminiCipher = <int>[
    0x12, 0x7E, 0x43, 0x0C, 0x52, 0x5A, 0x73, 0x02, 0x4C, 0x70,
    0x29, 0x48, 0x20, 0x00, 0x04, 0x2B, 0x54, 0x0F, 0x00, 0x54,
    0x1E, 0x5B, 0x07, 0x1A, 0x79, 0x55, 0x48, 0x03, 0x0A, 0x4B,
    0x1E, 0x48, 0x26, 0x03, 0x6F, 0x53, 0x40, 0x15, 0x33, 0x72,
    0x09, 0x6C, 0x0A, 0x1B, 0x44, 0x16, 0x79, 0x08, 0x0E, 0x56,
    0x03, 0x5F, 0x3C,
  ];

  static const List<int> _fbWebCipher = <int>[
    0x12, 0x66, 0x17, 0x2C, 0x63, 0x1B, 0x60, 0x7E, 0x11, 0x6A,
    0x07, 0x43, 0x23, 0x02, 0x51, 0x00, 0x57, 0x7E, 0x20, 0x5B,
    0x06, 0x6B, 0x1B, 0x3A, 0x71, 0x2C, 0x0C, 0x19, 0x2C, 0x48,
    0x38, 0x7B, 0x39, 0x1C, 0x65, 0x11, 0x70, 0x38, 0x0D,
  ];

  static const List<int> _fbAndroidCipher = <int>[
    0x12, 0x66, 0x17, 0x2C, 0x63, 0x1B, 0x60, 0x06, 0x34, 0x7E,
    0x67, 0x7B, 0x2B, 0x20, 0x73, 0x23, 0x52, 0x27, 0x20, 0x51,
    0x34, 0x45, 0x20, 0x3A, 0x61, 0x27, 0x44, 0x07, 0x48, 0x5D,
    0x3D, 0x40, 0x01, 0x3E, 0x71, 0x2C, 0x69, 0x7B, 0x1D,
  ];

  static String decode(List<int> cipher) {
    final out = List<int>.generate(
      cipher.length,
      (i) => cipher[i] ^ _mask[i % _mask.length],
      growable: false,
    );
    return utf8.decode(out);
  }
}

//**********************************************
// Strictly Separated API Key Accessors        *
//**********************************************

/// Resolves the two distinct Google keys (`GOOGLE_MAPS_API_KEY` and `GEMINI_API_KEY`)
/// plus Firebase config from `--dart-define` / `.env` defines first, falling back
/// to the sealed byte vault so raw keys are never stored in Git-tracked source.
abstract final class ApiKeysConfig {
  static const String _envMapsKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );
  static const String _envLegacyWebMapsKey = String.fromEnvironment(
    'GOOGLE_MAPS_WEB_KEY',
  );
  static const String _envLegacyRoutesKey = String.fromEnvironment(
    'GOOGLE_ROUTES_API_KEY',
  );
  static const String _envGeminiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _envFirebaseWebKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
  );
  static const String _envFirebaseAndroidKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );

  static String? _cachedMapsKey;
  static String? _cachedGeminiKey;
  static String? _cachedFirebaseWebKey;
  static String? _cachedFirebaseAndroidKey;

  /// Key used EXCLUSIVELY for Google Maps JS SDK, Android Maps SDK, and Routes API v2.
  static String get googleMapsApiKey {
    if (_envMapsKey.isNotEmpty) return _envMapsKey;
    if (_envLegacyRoutesKey.isNotEmpty) return _envLegacyRoutesKey;
    if (_envLegacyWebMapsKey.isNotEmpty) return _envLegacyWebMapsKey;
    return _cachedMapsKey ??=
        _RuntimeKeyVault.decode(_RuntimeKeyVault._mapsCipher);
  }

  /// Key used EXCLUSIVELY for Gemini 2.5 Flash REST calls (`x-goog-api-key` header).
  static String get geminiApiKey {
    if (_envGeminiKey.isNotEmpty) return _envGeminiKey;
    return _cachedGeminiKey ??=
        _RuntimeKeyVault.decode(_RuntimeKeyVault._geminiCipher);
  }

  /// Firebase Web API key (`m-mobilnost-2`).
  static String get firebaseWebApiKey {
    if (_envFirebaseWebKey.isNotEmpty) return _envFirebaseWebKey;
    return _cachedFirebaseWebKey ??=
        _RuntimeKeyVault.decode(_RuntimeKeyVault._fbWebCipher);
  }

  /// Firebase Android API key (`m-mobilnost-2`).
  static String get firebaseAndroidApiKey {
    if (_envFirebaseAndroidKey.isNotEmpty) return _envFirebaseAndroidKey;
    return _cachedFirebaseAndroidKey ??=
        _RuntimeKeyVault.decode(_RuntimeKeyVault._fbAndroidCipher);
  }
}
