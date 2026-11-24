//**********************************************
// Shared Google Maps markers, lines & presets *
//**********************************************

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Supported Google Maps visual styles selectable in user preferences.
enum GoogleMapStylePreset {
  /// Sleek dark vector/styled map (default).
  dark,

  /// Clean light road map.
  light,

  /// Hybrid satellite + road labels.
  satellite,
}

/// Marker descriptor passed to Google Maps (Web Vector JS & Android SDK).
@immutable
class GoogleMap3DMarkerData {
  /// Creates a [GoogleMap3DMarkerData].
  const GoogleMap3DMarkerData({
    required this.id,
    required this.position,
    required this.label,
    this.shortLabel,
    this.isBus = false,
    this.isWheelchairAccessible = true,
    this.headingDegrees = 0.0,
    this.color = const Color(0xFFC8102E),
    this.occupancyPercent,
    this.occupancyColor,
  });

  /// Unique marker ID.
  final String id;

  /// Geographic coordinate in Maribor.
  final LatLng position;

  /// Accessible tooltip/title displayed on the pin.
  final String label;

  /// Optional compact line code rendered inside bus pills (e.g. `G1`, `P12`).
  final String? shortLabel;

  /// True for live buses; false for stops or transfer landmarks.
  final bool isBus;

  /// True when the bus or stop is wheelchair accessible.
  final bool isWheelchairAccessible;

  /// Compass heading in degrees (`0..360`) for directional indicators.
  final double headingDegrees;

  /// Accent color for markers and badges.
  final Color color;

  /// Optional bus load (`0..100`) drawn as a small fill bar under bus pills.
  final int? occupancyPercent;

  /// Semantic occupancy color for the fill bar (used with [occupancyPercent]).
  final Color? occupancyColor;
}

/// Polyline descriptor rendered over Maribor streets in 2D and 3D modes.
@immutable
class GoogleMap3DPolylineData {
  /// Creates a [GoogleMap3DPolylineData].
  const GoogleMap3DPolylineData({
    required this.id,
    required this.points,
    required this.color,
    this.strokeWidth = 6.0,
    this.isDashed = false,
  });

  /// Unique line/route ID.
  final String id;

  /// Ordered geographic coordinates along the route.
  final List<LatLng> points;

  /// Stroke color matching the Marprom line badge or walking accent.
  final Color color;

  /// Stroke width in logical pixels.
  final double strokeWidth;

  /// True for pedestrian transfer segments rendered as dashed lines.
  final bool isDashed;
}

/// Named 3D camera viewpoint across key Maribor transit hubs.
@immutable
class GoogleMap3DCameraPreset {
  /// Creates a [GoogleMap3DCameraPreset].
  const GoogleMap3DCameraPreset({
    required this.id,
    required this.label,
    required this.center,
    this.tilt = 60,
    this.heading = 18,
    this.range = 1750,
    this.mobileZoom = 16.0,
  });

  /// Preset ID.
  final String id;

  /// Display name shown on preset chips.
  final String label;

  /// Target WGS84 center.
  final LatLng center;

  /// Camera tilt angle in degrees (`0..65`).
  final double tilt;

  /// Camera compass bearing in degrees (`0..360`).
  final double heading;

  /// Legacy range kept for compatibility.
  final double range;

  /// Target Google Maps zoom level (`>= 15.2` reveals 3D buildings).
  final double mobileZoom;
}

/// Curated Maribor 3D transit camera presets.
const List<GoogleMap3DCameraPreset> maribor3DCameraPresets = [
  GoogleMap3DCameraPreset(
    id: 'center',
    label: 'Glavni trg & Stari most',
    center: LatLng(46.5576, 15.6455),
    tilt: 60,
    heading: 18,
    mobileZoom: 16.2,
  ),
  GoogleMap3DCameraPreset(
    id: 'ap_maribor',
    label: 'AP & ŽP Maribor',
    center: LatLng(46.5594, 15.6561),
    tilt: 60,
    heading: 315,
    mobileZoom: 16.2,
  ),
  GoogleMap3DCameraPreset(
    id: 'ukc_tabor',
    label: 'UKC & Tabor',
    center: LatLng(46.5495, 15.6465),
    tilt: 58,
    heading: 42,
    mobileZoom: 15.8,
  ),
  GoogleMap3DCameraPreset(
    id: 'vzpenjaca',
    label: 'Pohorska vzpenjača',
    center: LatLng(46.5343, 15.6042),
    tilt: 62,
    heading: 215,
    mobileZoom: 15.8,
  ),
];
