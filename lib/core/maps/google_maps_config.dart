//**********************************************
// Google Maps Platform configuration & styles *
//**********************************************

import '../config/api_keys_config.dart';

/// Holds Google Maps API keys, Vector Map ID, and Dark/Light styles.
/// Never mixes `GOOGLE_MAPS_API_KEY` with `GEMINI_API_KEY`.
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

  /// Sleek dark JSON style applied to `google_maps_flutter` & Web maps.
  static const String darkMapStyleJson = '''
[
  {"elementType":"geometry","stylers":[{"color":"#161315"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#b8adb1"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#161315"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#3b3236"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#18261f"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#282225"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1b1719"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#362d31"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#4a3238"}]},
  {"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#382e32"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0c1d2e"}]}
]
''';

  /// Clean modern light JSON style highlighting transit corridors.
  static const String lightMapStyleJson = '''
[
  {"featureType":"poi.business","stylers":[{"visibility":"simplified"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#f5d0d6"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#cde6f7"}]}
]
''';
}
