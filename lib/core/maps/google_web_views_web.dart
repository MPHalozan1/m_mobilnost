//**********************************************
// Web Google Maps JS Vector View via ui_web   *
//**********************************************

import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:web/web.dart' as web;

import 'google_map_models.dart';
import 'google_maps_config.dart';

@JS('__marpromSyncGoogleMap')
external void _marpromSyncGoogleMap(web.Element hostEl, JSString payloadJson);

/// Always false on Flutter Web.
bool get isFlutterTestEnvironment => false;

//**********************************************
// Unified Web Vector 2D & 3D Google Map View  *
//**********************************************

/// Renders an official Google Maps JS Vector Map (`mapId`) supporting both 2D
/// (`tilt: 0`) and smooth tilted 3D buildings + animated route flyover (`tilt: 60°`).
class GoogleMap3DPlatformView extends StatefulWidget {
  /// Creates a [GoogleMap3DPlatformView].
  const GoogleMap3DPlatformView({
    super.key,
    required this.center,
    this.tilt = 60,
    this.heading = 18,
    this.range = 1750,
    this.mobileZoom = 16.2,
    this.polylines = const [],
    this.markers = const [],
    this.camera3DActive = false,
    this.stylePreset = GoogleMapStylePreset.dark,
    this.fitBounds = false,
    this.fitSignature = '',
  });

  /// Camera center in Maribor.
  final LatLng center;

  /// Tilt angle in degrees (`0..65`).
  final double tilt;

  /// Heading/bearing in degrees (`0..360`).
  final double heading;

  /// Unused legacy range kept for parity.
  final double range;

  /// Vector zoom level (`>= 15.2` displays 3D buildings).
  final double mobileZoom;

  /// Polylines rendered over Maribor roads.
  final List<GoogleMap3DPolylineData> polylines;

  /// Pins for live buses, stops, and transfers.
  final List<GoogleMap3DMarkerData> markers;

  /// True while actively animating/scrubbing along a 3D route.
  final bool camera3DActive;

  /// Visual style preset (`dark`, `light`, `satellite`).
  final GoogleMapStylePreset stylePreset;

  /// Fits bounds when true and [camera3DActive] is false.
  final bool fitBounds;

  /// Signature controlling camera re-fit.
  final String fitSignature;

  @override
  State<GoogleMap3DPlatformView> createState() =>
      _GoogleMap3DPlatformViewState();
}

class _GoogleMap3DPlatformViewState extends State<GoogleMap3DPlatformView> {
  static int _counter = 0;
  late String _viewType;
  web.HTMLDivElement? _hostElement;

  @override
  void initState() {
    super.initState();
    _viewType = 'marprom-gmap-vector-3d-${++_counter}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final host = web.document.createElement('div') as web.HTMLDivElement;
      host.style.width = '100%';
      host.style.height = '100%';
      host.style.position = 'relative';
      host.style.backgroundColor = '#161315';
      _hostElement = host;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync();
      });
      return host;
    });
  }

  @override
  void didUpdateWidget(covariant GoogleMap3DPlatformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final host = _hostElement;
    if (host == null) return;
    _syncHostWithGoogleJs(
      host: host,
      center: widget.center,
      zoom: widget.mobileZoom,
      tilt: widget.tilt,
      heading: widget.heading,
      polylines: widget.polylines,
      markers: widget.markers,
      fitBounds: widget.fitBounds && !widget.camera3DActive,
      fitSignature: widget.fitSignature,
      camera3DActive: widget.camera3DActive,
      stylePreset: widget.stylePreset,
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

/// Interactive 2D Google Maps JS Vector View with ResizeObserver bounds fitting.
class GoogleRoadMapPlatformView extends StatefulWidget {
  /// Creates a [GoogleRoadMapPlatformView].
  const GoogleRoadMapPlatformView({
    super.key,
    required this.center,
    this.zoom = 13.6,
    this.polylines = const [],
    this.markers = const [],
    this.fitBounds = false,
    this.fitSignature = '',
    this.stylePreset = GoogleMapStylePreset.dark,
  });

  /// Map center coordinate.
  final LatLng center;

  /// Initial camera zoom level.
  final double zoom;

  /// Road polylines to render on top of Google Maps roads.
  final List<GoogleMap3DPolylineData> polylines;

  /// Compact bus badges and stop dots.
  final List<GoogleMap3DMarkerData> markers;

  /// Whether camera should auto-fit all polylines/markers when [fitSignature] changes.
  final bool fitBounds;

  /// Cache key controlling when [fitBounds] runs again.
  final String fitSignature;

  /// Visual style preset (`dark`, `light`, `satellite`).
  final GoogleMapStylePreset stylePreset;

  @override
  State<GoogleRoadMapPlatformView> createState() =>
      _GoogleRoadMapPlatformViewState();
}

class _GoogleRoadMapPlatformViewState extends State<GoogleRoadMapPlatformView> {
  static int _counter = 0;
  late String _viewType;
  web.HTMLDivElement? _hostElement;

  @override
  void initState() {
    super.initState();
    _viewType = 'marprom-google-roadmap-${++_counter}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final host = web.document.createElement('div') as web.HTMLDivElement;
      host.style.width = '100%';
      host.style.height = '100%';
      host.style.position = 'relative';
      host.style.backgroundColor = '#161315';
      _hostElement = host;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncMap();
      });
      return host;
    });
  }

  @override
  void didUpdateWidget(covariant GoogleRoadMapPlatformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMap();
  }

  void _syncMap() {
    final host = _hostElement;
    if (host == null) return;
    _syncHostWithGoogleJs(
      host: host,
      center: widget.center,
      zoom: widget.zoom,
      tilt: 0,
      heading: 0,
      polylines: widget.polylines,
      markers: widget.markers,
      fitBounds: widget.fitBounds,
      fitSignature: widget.fitSignature,
      camera3DActive: false,
      stylePreset: widget.stylePreset,
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

void _syncHostWithGoogleJs({
  required web.HTMLDivElement host,
  required LatLng center,
  required double zoom,
  required double tilt,
  required double heading,
  required List<GoogleMap3DPolylineData> polylines,
  required List<GoogleMap3DMarkerData> markers,
  required bool fitBounds,
  required String fitSignature,
  required bool camera3DActive,
  required GoogleMapStylePreset stylePreset,
}) {
  String toHex(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  final mapTypeId = switch (stylePreset) {
    GoogleMapStylePreset.satellite => 'hybrid',
    GoogleMapStylePreset.dark || GoogleMapStylePreset.light => 'roadmap',
  };

  final payload = <String, dynamic>{
    'mapId': GoogleMapsConfig.vectorMapId,
    'mapTypeId': mapTypeId,
    'center': {'lat': center.latitude, 'lng': center.longitude},
    'zoom': zoom,
    'tilt': tilt.clamp(0.0, 65.0),
    'heading': heading,
    'fitBounds': fitBounds,
    'fitSignature': fitSignature,
    if (camera3DActive)
      'camera3D': {
        'active': true,
        'lat': center.latitude,
        'lng': center.longitude,
        'zoom': zoom,
        'tilt': tilt.clamp(0.0, 65.0),
        'heading': heading,
      },
    'polylines': [
      for (final line in polylines)
        if (line.points.length >= 2)
          {
            'id': line.id,
            'color': toHex(line.color),
            'strokeWidth': line.strokeWidth,
            'isDashed': line.isDashed,
            'points': [
              for (final pt in line.points)
                {'lat': pt.latitude, 'lng': pt.longitude},
            ],
          },
    ],
    'markers': [
      for (final mk in markers.take(80))
        {
          'id': mk.id,
          'lat': mk.position.latitude,
          'lng': mk.position.longitude,
          'label': mk.label,
          'shortLabel': mk.shortLabel,
          'isBus': mk.isBus,
          'isAccessible': mk.isWheelchairAccessible,
          'color': toHex(mk.color),
        },
    ],
  };

  try {
    _marpromSyncGoogleMap(host, jsonEncode(payload).toJS);
  } catch (_) {}
}
