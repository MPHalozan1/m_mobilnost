// Shared data models for 3D Google Maps markers, polylines, and Maribor camera presets.

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Marker descriptor passed to both Web `<gmp-map-3d>` and Mobile 3D `GoogleMap`.
@immutable
class GoogleMap3DMarkerData {
  /// Creates a [GoogleMap3DMarkerData].
  const GoogleMap3DMarkerData({
    required this.id,
    required this.position,
    required this.label,
    this.shortLabel,
    this.isBus = false,
    this.color = const Color(0xFFC8102E),
  });

  /// Unique marker ID.
  final String id;

  /// Geographic coordinate in Maribor.
  final LatLng position;

  /// Accessible tooltip/title displayed on the 3D pin.
  final String label;

  /// Optional compact line code rendered inside bus pills (e.g. `G1`, `P12`).
  final String? shortLabel;

  /// True for live buses; false for stops or landmarks.
  final bool isBus;

  /// Accent color for mobile markers and badges.
  final Color color;
}

/// Polyline descriptor rendered over Maribor roads in 3D/2D maps.
@immutable
class GoogleMap3DPolylineData {
  /// Creates a [GoogleMap3DPolylineData].
  const GoogleMap3DPolylineData({
    required this.id,
    required this.points,
    required this.color,
    this.strokeWidth = 6.0,
  });

  /// Unique line/route ID.
  final String id;

  /// Ordered geographic coordinates along the route.
  final List<LatLng> points;

  /// Stroke color matching the Marprom line badge.
  final Color color;

  /// Stroke width in logical pixels.
  final double strokeWidth;
}

/// Named 3D camera viewpoint across key Maribor transit hubs.
@immutable
class GoogleMap3DCameraPreset {
  /// Creates a [GoogleMap3DCameraPreset].
  const GoogleMap3DCameraPreset({
    required this.id,
    required this.label,
    required this.center,
    this.tilt = 62,
    this.heading = 18,
    this.range = 1750,
    this.mobileZoom = 15.8,
  });

  /// Preset ID.
  final String id;

  /// Display name shown on preset chips.
  final String label;

  /// Target WGS84 center.
  final LatLng center;

  /// Camera tilt angle in degrees.
  final double tilt;

  /// Camera compass bearing in degrees.
  final double heading;

  /// Web 3D camera range in meters.
  final double range;

  /// Mobile GoogleMap zoom level.
  final double mobileZoom;
}

/// Curated Maribor 3D transit camera presets.
const List<GoogleMap3DCameraPreset> maribor3DCameraPresets = [
  GoogleMap3DCameraPreset(
    id: 'center',
    label: 'Glavni trg & Stari most',
    center: LatLng(46.5576, 15.6455),
    tilt: 62,
    heading: 18,
    range: 1700,
    mobileZoom: 16.0,
  ),
  GoogleMap3DCameraPreset(
    id: 'ap_maribor',
    label: 'AP & ŽP Maribor',
    center: LatLng(46.5594, 15.6561),
    tilt: 60,
    heading: 315,
    range: 1550,
    mobileZoom: 16.2,
  ),
  GoogleMap3DCameraPreset(
    id: 'ukc_tabor',
    label: 'UKC & Tabor',
    center: LatLng(46.5495, 15.6465),
    tilt: 58,
    heading: 42,
    range: 1900,
    mobileZoom: 15.5,
  ),
  GoogleMap3DCameraPreset(
    id: 'vzpenjaca',
    label: 'Pohorska vzpenjača',
    center: LatLng(46.5343, 15.6042),
    tilt: 66,
    heading: 215,
    range: 2100,
    mobileZoom: 15.4,
  ),
];
