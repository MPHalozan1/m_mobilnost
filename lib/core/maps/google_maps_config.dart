//**********************************************
// Google Maps Platform configuration & styles *
//**********************************************

/// Holds Google Maps API keys, Vector Map ID, and Dark/Light styles.
abstract final class GoogleMapsConfig {
  static const String _defaultApiKey =
      'AIzaSyCJZoVbBxzgU4tt8Z-t4r5wxFM5eUOLdcs';

  /// Key used by Google Maps JS SDK on Web.
  static const String webApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_WEB_KEY',
    defaultValue: _defaultApiKey,
  );

  /// Key used by Google Routes API v2 (`directions/v2:computeRoutes`).
  static const String routesApiKey = String.fromEnvironment(
    'GOOGLE_ROUTES_API_KEY',
    defaultValue: _defaultApiKey,
  );

  /// Cloud Map ID enabling WebGL Vector rendering & tilted 3D buildings on Web.
  static const String vectorMapId = String.fromEnvironment(
    'GOOGLE_MAPS_MAP_ID',
    defaultValue: 'DEMO_MAP_ID',
  );

  /// Key configured for Google Maps SDK on Android (`AndroidManifest.xml`).
  static const String android3dApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_ANDROID_3D_KEY',
    defaultValue: _defaultApiKey,
  );

  /// Key configured for Google Maps SDK on iOS (`AppDelegate.swift`).
  static const String ios3dApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_IOS_3D_KEY',
    defaultValue: _defaultApiKey,
  );

  /// Endpoint for Google Routes API v2 `computeRoutes`.
  static final Uri computeRoutesEndpoint = Uri.parse(
    'https://routes.googleapis.com/directions/v2:computeRoutes',
  );

  /// Sleek dark JSON style applied to `google_maps_flutter` on Android/iOS.
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
}
