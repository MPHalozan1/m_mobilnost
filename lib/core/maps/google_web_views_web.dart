// Web implementation rendering <iframe class="map-top"> and <gmp-map-3d> via dart:ui_web.

import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:web/web.dart' as web;

import 'google_map_models.dart';
import 'google_maps_config.dart';

@JS('__marpromBindPolyline')
external void _marpromBindPolyline(
  web.Element element,
  JSString coordsJson,
  JSString strokeColor,
  JSNumber strokeWidth,
);

@JS('__marpromSyncRoadMap')
external void _marpromSyncRoadMap(web.Element hostEl, JSString payloadJson);

/// Always false on Flutter Web.
bool get isFlutterTestEnvironment => false;

/// Displays an interactive Google Maps Directions Embed `<iframe>` on Flutter Web.
class GoogleDirectionsEmbedPlatformView extends StatefulWidget {
  /// Creates a [GoogleDirectionsEmbedPlatformView].
  const GoogleDirectionsEmbedPlatformView({
    super.key,
    required this.origin,
    required this.destination,
    this.mode = 'transit',
    this.avoidTolls = false,
    this.avoidHighways = false,
  });

  /// Origin address or place string.
  final String origin;

  /// Destination address or place string.
  final String destination;

  /// Google Maps mode (`transit`, `driving`, `walking`).
  final String mode;

  /// Whether `avoid=tolls` is passed.
  final bool avoidTolls;

  /// Whether `avoid=highways` is passed.
  final bool avoidHighways;

  @override
  State<GoogleDirectionsEmbedPlatformView> createState() =>
      _GoogleDirectionsEmbedPlatformViewState();
}

class _GoogleDirectionsEmbedPlatformViewState
    extends State<GoogleDirectionsEmbedPlatformView> {
  static int _counter = 0;
  late String _viewType;
  late Uri _uri;

  @override
  void initState() {
    super.initState();
    _registerIframe();
  }

  @override
  void didUpdateWidget(covariant GoogleDirectionsEmbedPlatformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.origin != widget.origin ||
        oldWidget.destination != widget.destination ||
        oldWidget.mode != widget.mode ||
        oldWidget.avoidTolls != widget.avoidTolls ||
        oldWidget.avoidHighways != widget.avoidHighways) {
      _registerIframe();
    }
  }

  void _registerIframe() {
    _uri = GoogleMapsConfig.buildDirectionsEmbedUri(
      origin: widget.origin,
      destination: widget.destination,
      mode: widget.mode,
      avoidTolls: widget.avoidTolls,
      avoidHighways: widget.avoidHighways,
    );
    _viewType = 'marprom-directions-iframe-${++_counter}';
    final src = _uri.toString();

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe =
          web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.className = 'map-top';
      iframe.style.border = '0';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.loading = 'lazy';
      iframe.referrerPolicy = 'strict-origin-when-cross-origin';
      iframe.allowFullscreen = true;
      iframe.src = src;
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: ValueKey(_viewType),
      viewType: _viewType,
    );
  }
}

/// Displays Photorealistic Google Maps 3D (`<gmp-map-3d>`) with 3D bus markers and routes.
class GoogleMap3DPlatformView extends StatefulWidget {
  /// Creates a [GoogleMap3DPlatformView].
  const GoogleMap3DPlatformView({
    super.key,
    required this.center,
    this.tilt = 62,
    this.heading = 18,
    this.range = 1750,
    this.mobileZoom = 15.8,
    this.polylines = const [],
    this.markers = const [],
  });

  /// Camera center in Maribor.
  final LatLng center;

  /// Tilt angle in degrees.
  final double tilt;

  /// Heading/bearing in degrees.
  final double heading;

  /// Camera distance range in meters.
  final double range;

  /// Unused on Web; kept for cross-platform API parity.
  final double mobileZoom;

  /// 3D polylines rendered over Maribor roads.
  final List<GoogleMap3DPolylineData> polylines;

  /// 3D pins for live buses and stops.
  final List<GoogleMap3DMarkerData> markers;

  @override
  State<GoogleMap3DPlatformView> createState() =>
      _GoogleMap3DPlatformViewState();
}

class _GoogleMap3DPlatformViewState extends State<GoogleMap3DPlatformView> {
  static int _counter = 0;
  late String _viewType;
  web.Element? _map3dElement;
  final List<web.Element> _polylineElements = [];
  final List<web.Element> _markerElements = [];
  String _lastPolylineSig = '';

  @override
  void initState() {
    super.initState();
    _viewType = 'marprom-gmp-map3d-${++_counter}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final host = web.document.createElement('div') as web.HTMLDivElement;
      host.style.width = '100%';
      host.style.height = '100%';
      host.style.position = 'relative';
      host.style.backgroundColor = '#0F172A';

      final mapEl = web.document.createElement('gmp-map-3d');
      mapEl.setAttribute('mode', 'HYBRID');
      _map3dElement = mapEl;
      _applyCamera();
      _syncPolylines(force: true);
      _syncMarkers();
      host.appendChild(mapEl);
      return host;
    });
  }

  @override
  void didUpdateWidget(covariant GoogleMap3DPlatformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.center != widget.center ||
        oldWidget.tilt != widget.tilt ||
        oldWidget.heading != widget.heading ||
        oldWidget.range != widget.range) {
      _applyCamera();
    }
    _syncPolylines();
    if (oldWidget.markers != widget.markers) {
      _syncMarkers();
    }
  }

  void _applyCamera() {
    final mapEl = _map3dElement;
    if (mapEl == null) return;
    mapEl.setAttribute(
      'center',
      '${widget.center.latitude},${widget.center.longitude},110',
    );
    mapEl.setAttribute('tilt', '${widget.tilt.round()}');
    mapEl.setAttribute('heading', '${widget.heading.round()}');
    mapEl.setAttribute('range', '${widget.range.round()}');
  }

  String _computePolylineSignature() {
    final buf = StringBuffer();
    for (final line in widget.polylines) {
      buf.write(
        '${line.id}:${line.points.length}:${line.color.toARGB32()}:${line.strokeWidth.round()}:',
      );
      if (line.points.isNotEmpty) {
        buf.write(
          '${line.points.first.latitude.toStringAsFixed(4)},${line.points.last.longitude.toStringAsFixed(4)};',
        );
      }
    }
    return buf.toString();
  }

  void _syncPolylines({bool force = false}) {
    final mapEl = _map3dElement;
    if (mapEl == null) return;

    final sig = _computePolylineSignature();
    if (!force && sig == _lastPolylineSig) return;
    _lastPolylineSig = sig;

    for (final el in _polylineElements) {
      el.remove();
    }
    _polylineElements.clear();

    for (final line in widget.polylines) {
      if (line.points.length < 2) continue;
      final cssColor = _toCssHex(line.color);
      final polyEl = web.document.createElement('gmp-polyline-3d');
      polyEl.setAttribute('stroke-color', cssColor);
      polyEl.setAttribute('stroke-width', '${line.strokeWidth.round()}');
      polyEl.setAttribute('outer-color', '#FFFFFF');
      polyEl.setAttribute('outer-width', '2');
      polyEl.setAttribute('altitude-mode', 'CLAMP_TO_GROUND');
      mapEl.appendChild(polyEl);
      _polylineElements.add(polyEl);

      final coordsJson = jsonEncode([
        for (final pt in line.points)
          {
            'lat': pt.latitude,
            'lng': pt.longitude,
            'altitude': 4,
          },
      ]);
      try {
        _marpromBindPolyline(
          polyEl,
          coordsJson.toJS,
          cssColor.toJS,
          line.strokeWidth.toJS,
        );
      } catch (_) {}
    }
  }

  void _syncMarkers() {
    final mapEl = _map3dElement;
    if (mapEl == null) return;

    for (final el in _markerElements) {
      el.remove();
    }
    _markerElements.clear();

    for (final marker in widget.markers.take(45)) {
      final markerEl = web.document.createElement('gmp-marker-3d');
      markerEl.setAttribute(
        'position',
        '${marker.position.latitude},${marker.position.longitude},${marker.isBus ? 28 : 12}',
      );
      markerEl.setAttribute('altitude-mode', 'RELATIVE_TO_GROUND');
      markerEl.setAttribute('title', marker.label);
      markerEl.setAttribute('draws-when-occluded', 'true');
      mapEl.appendChild(markerEl);
      _markerElements.add(markerEl);
    }
  }

  String _toCssHex(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

/// Interactive 2D Google Maps JavaScript View displaying crisp road polylines and compact bus badges on Web.
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
      host.style.backgroundColor = '#E2E8F0';
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

    String toHex(Color color) {
      final rgb = color.toARGB32() & 0x00FFFFFF;
      return '#${rgb.toRadixString(16).padLeft(6, '0')}';
    }

    final payload = <String, dynamic>{
      'center': {'lat': widget.center.latitude, 'lng': widget.center.longitude},
      'zoom': widget.zoom,
      'fitBounds': widget.fitBounds,
      'fitSignature': widget.fitSignature,
      'polylines': [
        for (final line in widget.polylines)
          if (line.points.length >= 2)
            {
              'id': line.id,
              'color': toHex(line.color),
              'strokeWidth': line.strokeWidth,
              'points': [
                for (final pt in line.points)
                  {'lat': pt.latitude, 'lng': pt.longitude},
              ],
            },
      ],
      'markers': [
        for (final mk in widget.markers.take(65))
          {
            'id': mk.id,
            'lat': mk.position.latitude,
            'lng': mk.position.longitude,
            'label': mk.label,
            'shortLabel': mk.shortLabel,
            'isBus': mk.isBus,
            'color': toHex(mk.color),
          },
      ],
    };
    try {
      _marpromSyncRoadMap(host, jsonEncode(payload).toJS);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
