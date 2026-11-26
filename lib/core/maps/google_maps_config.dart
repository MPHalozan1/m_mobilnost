//**********************************************
// Google Maps Platform configuration          *
//**********************************************

import '../config/api_keys_config.dart';

/// Holds Google Maps API keys and Vector Map ID.
/// Google Maps always renders in crisp default Light Roadmap theme across
/// both Dark Mode and Light Mode. Never mixes `GOOGLE_MAPS_API_KEY` with `GEMINI_API_KEY`.
abstract final class GoogleMapsConfig {
  /// Key used by Google Maps JS SDK on Web.
  static String get webApiKey => ApiKeysConfig.googleMapsApiKey;

  /// Key used by Google Routes API v2 (`directions/v2:computeRoutes`).
  static String get routesApiKey => ApiKeysConfig.googleMapsApiKey;

  /// Cloud Map ID enabling WebGL Vector rendering & tilted 3D buildings on Web.
  static const String vectorMapId = String.fromEnvironment(
    'GOOGLE_MAPS_MAP_ID',
    defaultValue: 'DEMO_MAP_ID',
  );

  /// Key configured for Google Maps SDK on Android (`AndroidManifest.xml`).
  static String get android3dApiKey => ApiKeysConfig.googleMapsApiKey;

  /// Key configured for Google Maps SDK on iOS (`AppDelegate.swift`).
  static String get ios3dApiKey => ApiKeysConfig.googleMapsApiKey;

  /// Endpoint for Google Routes API v2 `computeRoutes`.
  static final Uri computeRoutesEndpoint = Uri.parse(
    'https://routes.googleapis.com/directions/v2:computeRoutes',
  );
}
