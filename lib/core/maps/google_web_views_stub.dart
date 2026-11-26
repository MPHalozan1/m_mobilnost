//**********************************************
// Android/iOS Google Maps SDK & Test Stub     *
//**********************************************

import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' hide Path;

import 'google_map_models.dart';

/// True when executing inside `flutter test` on the Dart VM.
bool get isFlutterTestEnvironment =>
    Platform.environment.containsKey('FLUTTER_TEST');

//**********************************************
// Compact transit marker bitmap generator     *
//**********************************************

class _CompactTransitBitmaps {
  static final Map<String, gmaps.BitmapDescriptor> _cache = {};

  static String keyFor(GoogleMap3DMarkerData m) {
    if (m.isUserLocation) return 'user_gps';
    if (m.isBus) {
      final code = (m.shortLabel ?? m.label.split(' ').first).toUpperCase();
      final ring = (m.statusColor ?? Colors.white).toARGB32();
      return 'bus|$code|${m.color.toARGB32()}|$ring|${m.isWheelchairAccessible}|${m.isSelected}';
    }
    return 'stop|${m.color.toARGB32()}|${m.isSelected}';
  }

  static gmaps.BitmapDescriptor? cached(GoogleMap3DMarkerData m) =>
      _cache[keyFor(m)];

  static Future<gmaps.BitmapDescriptor> resolve(GoogleMap3DMarkerData m) async {
    final key = keyFor(m);
    final existing = _cache[key];
    if (existing != null) return existing;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    late int width;
    late int height;
    if (m.isUserLocation) {
      width = 48;
      height = 48;
      const center = Offset(24, 24);
      canvas.drawCircle(
        center,
        22,
        Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.25),
      );
      canvas.drawCircle(center, 13, Paint()..color = Colors.white);
      canvas.drawCircle(center, 9.5, Paint()..color = const Color(0xFF0284C7));
    } else if (m.isBus) {
      width = 96;
      height = 60;
      const w = 96.0;
      const h = 60.0;
      // Directional chevron arrow at top center (rotates with Marker.rotation)
      final arrow = Path()
        ..moveTo(w / 2, 2)
        ..lineTo(w / 2 + 9, 14)
        ..lineTo(w / 2 - 9, 14)
        ..close();
      canvas.drawPath(arrow, Paint()..color = m.color);
      canvas.drawPath(
        arrow,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      final rrect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 15, w - 8, h - 18),
        const Radius.circular(14),
      );
      canvas.drawRRect(rrect, Paint()..color = m.color);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = m.statusColor ?? Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = m.isSelected ? 5.5 : 4.0,
      );
      final code = (m.shortLabel ?? m.label.split(' ').first)
          .toUpperCase()
          .trim();
      final displayCode = code.length > 4 ? code.substring(0, 4) : code;
      final tp = TextPainter(
        text: TextSpan(
          text: m.isWheelchairAccessible ? '$displayCode ♿' : displayCode,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((w - tp.width) / 2, 15 + (h - 18 - tp.height) / 2));
    } else {
      width = m.isSelected ? 32 : 24;
      height = m.isSelected ? 32 : 24;
      final c = Offset(width / 2, height / 2);
      final r = m.isSelected ? 12.0 : 9.0;
      canvas.drawCircle(c, r, Paint()..color = Colors.white);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = m.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = m.isSelected ? 5.0 : 4.0,
      );
    }

    final image = await recorder.endRecording().toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final descriptor = gmaps.BitmapDescriptor.bytes(
      bytes,
      imagePixelRatio: 2.0,
    );
    _cache[key] = descriptor;
    return descriptor;
  }
}

Set<gmaps.Polyline> _buildMobilePolylines(
  List<GoogleMap3DPolylineData> polylines,
) {
  final result = <gmaps.Polyline>{};
  for (final line in polylines) {
    if (line.points.length < 2) continue;
    final gPoints = [
      for (final p in line.points) gmaps.LatLng(p.latitude, p.longitude),
    ];
    final w = line.strokeWidth.round().clamp(3, 10);
    if (line.isDashed) {
      result.add(
        gmaps.Polyline(
          polylineId: gmaps.PolylineId(line.id),
          color: const Color(0xFF3B82F6),
          width: kIsWeb ? 4 : 5,
          zIndex: 4,
          geodesic: false,
          patterns: kIsWeb
              ? const <gmaps.PatternItem>[]
              : <gmaps.PatternItem>[
                  gmaps.PatternItem.dash(14),
                  gmaps.PatternItem.gap(10),
                ],
          points: gPoints,
        ),
      );
    } else {
      result.add(
        gmaps.Polyline(
          polylineId: gmaps.PolylineId('${line.id}_casing'),
          color: Colors.white.withValues(alpha: 0.94),
          width: w + 3,
          zIndex: 1,
          geodesic: false,
          jointType: gmaps.JointType.round,
          startCap: gmaps.Cap.roundCap,
          endCap: gmaps.Cap.roundCap,
          points: gPoints,
        ),
      );
      result.add(
        gmaps.Polyline(
          polylineId: gmaps.PolylineId(line.id),
          color: line.color,
          width: w,
          zIndex: 2,
          geodesic: false,
          jointType: gmaps.JointType.round,
          startCap: gmaps.Cap.roundCap,
          endCap: gmaps.Cap.roundCap,
          points: gPoints,
        ),
      );
    }
  }
  return result;
}

gmaps.LatLngBounds? _computeMobileBounds(
  List<GoogleMap3DPolylineData> polylines,
  List<GoogleMap3DMarkerData> markers,
) {
  double? minLat, maxLat, minLng, maxLng;
  void include(LatLng p) {
    minLat = minLat == null ? p.latitude : math.min(minLat!, p.latitude);
    maxLat = maxLat == null ? p.latitude : math.max(maxLat!, p.latitude);
    minLng = minLng == null ? p.longitude : math.min(minLng!, p.longitude);
    maxLng = maxLng == null ? p.longitude : math.max(maxLng!, p.longitude);
  }

  for (final line in polylines) {
    for (final p in line.points) {
      include(p);
    }
  }
  for (final m in markers) {
    include(m.position);
  }
  if (minLat == null ||
      maxLat == null ||
      minLng == null ||
      maxLng == null ||
      (maxLat! - minLat!).abs() < 1e-4 && (maxLng! - minLng!).abs() < 1e-4) {
    return null;
  }
  return gmaps.LatLngBounds(
    southwest: gmaps.LatLng(minLat!, minLng!),
    northeast: gmaps.LatLng(maxLat!, maxLng!),
  );
}

//**********************************************
// Mobile 3D Tilted GoogleMap View             *
//**********************************************

/// Renders Google Maps 3D SDK on Android/iOS (tilted 3D buildings + smooth flyover)
/// or a lightweight test preview inside Dart VM widget tests.
class GoogleMap3DPlatformView extends StatefulWidget {
  /// Creates a [GoogleMap3DPlatformView].
  const GoogleMap3DPlatformView({
    super.key,
    required this.center,
    this.tilt = 60,
    this.heading = 18,
    this.range = 1750,
    this.mobileZoom = 17.2,
    this.polylines = const [],
    this.markers = const [],
    this.camera3DActive = false,
    this.stylePreset = GoogleMapStylePreset.light,
    this.fitBounds = false,
    this.fitSignature = '',
    this.forceCenter = false,
    this.onMarkerTap,
  });

  /// Map camera target coordinate.
  final LatLng center;

  /// Camera tilt angle in degrees (`0..67.5`).
  final double tilt;

  /// Camera bearing/heading in degrees (`0..360`).
  final double heading;

  /// Unused on Mobile; kept for cross-platform parity.
  final double range;

  /// Mobile zoom level (`>= 15` activates 3D buildings).
  final double mobileZoom;

  /// Polylines drawn over Maribor streets.
  final List<GoogleMap3DPolylineData> polylines;

  /// Live bus, stop, and user GPS markers.
  final List<GoogleMap3DMarkerData> markers;

  /// True while actively playing/scrubbing a 3D route flyover.
  final bool camera3DActive;

  /// Map style (`dark`, `light`, `satellite`).
  final GoogleMapStylePreset stylePreset;

  /// Auto-fits route bounds when not flying over.
  final bool fitBounds;

  /// Signature guarding camera re-fits.
  final String fitSignature;

  /// Forces camera center jump when true.
  final bool forceCenter;

  /// Invoked when the user taps a bus/stop marker.
  final ValueChanged<String>? onMarkerTap;

  @override
  State<GoogleMap3DPlatformView> createState() =>
      _GoogleMap3DPlatformViewState();
}

class _GoogleMap3DPlatformViewState extends State<GoogleMap3DPlatformView> {
  gmaps.GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    _warmupIcons();
  }

  @override
  void didUpdateWidget(covariant GoogleMap3DPlatformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markers != widget.markers) {
      _warmupIcons();
    }
    if (oldWidget.center != widget.center ||
        oldWidget.tilt != widget.tilt ||
        oldWidget.heading != widget.heading ||
        oldWidget.mobileZoom != widget.mobileZoom) {
      final update = gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: gmaps.LatLng(
            widget.center.latitude,
            widget.center.longitude,
          ),
          zoom: widget.mobileZoom,
          tilt: widget.tilt.clamp(0.0, 67.5),
          bearing: widget.heading,
        ),
      );
      if (widget.camera3DActive) {
        _controller?.moveCamera(update);
      } else {
        _controller?.animateCamera(update);
      }
    }
  }

  Future<void> _warmupIcons() async {
    var updated = false;
    for (final m in widget.markers) {
      if (_CompactTransitBitmaps.cached(m) == null) {
        await _CompactTransitBitmaps.resolve(m);
        updated = true;
      }
    }
    if (updated && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    final isMobile = !isTest && (Platform.isAndroid || Platform.isIOS);
    final scheme = Theme.of(context).colorScheme;

    if (!isMobile) {
      return _GoogleMapTestPreview(
        key: const Key('google_map_3d_stub_preview'),
        title: 'Google Maps 3D SDK (${widget.tilt.round()}° tilt)',
        center: widget.center,
        markerCount: widget.markers.length,
        polylineCount: widget.polylines.length,
        scheme: scheme,
      );
    }

    final gPolylines = _buildMobilePolylines(widget.polylines);
    final gMarkers = <gmaps.Marker>{};
    for (final m in widget.markers) {
      final cachedIcon = _CompactTransitBitmaps.cached(m);
      if (cachedIcon == null) continue;
      gMarkers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId(m.id),
          position: gmaps.LatLng(m.position.latitude, m.position.longitude),
          infoWindow: gmaps.InfoWindow(title: m.label),
          anchor: const Offset(0.5, 0.5),
          rotation: m.isBus ? (m.headingDegrees % 360) : 0.0,
          flat: m.isBus,
          zIndexInt: m.isUserLocation ? 40 : (m.isBus ? 25 : 10),
          icon: cachedIcon,
          onTap: widget.onMarkerTap != null ? () => widget.onMarkerTap!(m.id) : null,
        ),
      );
    }

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: gmaps.LatLng(widget.center.latitude, widget.center.longitude),
        zoom: widget.mobileZoom,
        tilt: widget.tilt.clamp(0.0, 67.5),
        bearing: widget.heading,
      ),
      // Google Maps ALWAYS stays in default crisp Light Roadmap theme
      mapType: gmaps.MapType.normal,
      buildingsEnabled: true,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      polylines: gPolylines,
      markers: gMarkers,
      onMapCreated: (controller) => _controller = controller,
    );
  }
}

//**********************************************
// Mobile 2D GoogleMap Road View               *
//**********************************************

/// Interactive 2D Google Maps view on Android/iOS with bus badges, stop dots, and bounds fitting.
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
    this.forceCenter = false,
    this.stylePreset = GoogleMapStylePreset.light,
    this.onMarkerTap,
  });

  /// Map camera target coordinate.
  final LatLng center;

  /// Initial zoom level when [fitBounds] is false.
  final double zoom;

  /// Google Routes polylines rendered over Maribor roads.
  final List<GoogleMap3DPolylineData> polylines;

  /// Compact bus pills, stop markers, and user GPS marker.
  final List<GoogleMap3DMarkerData> markers;

  /// Automatically frames all [polylines] and [markers] when true.
  final bool fitBounds;

  /// Cache key controlling when bounds re-fit happens.
  final String fitSignature;

  /// Forces camera center jump when true.
  final bool forceCenter;

  /// Map style (`dark`, `light`, `satellite`).
  final GoogleMapStylePreset stylePreset;

  /// Invoked when the user taps a marker.
  final ValueChanged<String>? onMarkerTap;

  @override
  State<GoogleRoadMapPlatformView> createState() =>
      _GoogleRoadMapPlatformViewState();
}

class _GoogleRoadMapPlatformViewState extends State<GoogleRoadMapPlatformView> {
  gmaps.GoogleMapController? _controller;
  String _lastFitSig = '';

  @override
  void initState() {
    super.initState();
    _warmupIcons();
  }

  @override
  void didUpdateWidget(covariant GoogleRoadMapPlatformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markers != widget.markers) {
      _warmupIcons();
    }
    if (widget.fitBounds && _lastFitSig != widget.fitSignature) {
      _fitIfReady();
    } else if ((widget.forceCenter || !widget.fitBounds) &&
        (oldWidget.center != widget.center || oldWidget.zoom != widget.zoom)) {
      _controller?.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: gmaps.LatLng(
              widget.center.latitude,
              widget.center.longitude,
            ),
            zoom: widget.zoom,
          ),
        ),
      );
    }
  }

  Future<void> _warmupIcons() async {
    var updated = false;
    for (final m in widget.markers) {
      if (_CompactTransitBitmaps.cached(m) == null) {
        await _CompactTransitBitmaps.resolve(m);
        updated = true;
      }
    }
    if (updated && mounted) setState(() {});
  }

  void _fitIfReady() {
    final controller = _controller;
    if (controller == null || !widget.fitBounds) return;
    final bounds = _computeMobileBounds(widget.polylines, widget.markers);
    if (bounds == null) return;
    _lastFitSig = widget.fitSignature;
    controller.animateCamera(gmaps.CameraUpdate.newLatLngBounds(bounds, 48));
  }

  @override
  Widget build(BuildContext context) {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    final isMobile = !isTest && (Platform.isAndroid || Platform.isIOS);
    final scheme = Theme.of(context).colorScheme;

    if (!isMobile) {
      return _GoogleMapTestPreview(
        key: const Key('google_map_3d_stub_preview'),
        title: 'Google Maps 2D Road View',
        center: widget.center,
        markerCount: widget.markers.length,
        polylineCount: widget.polylines.length,
        scheme: scheme,
      );
    }

    final gPolylines = _buildMobilePolylines(widget.polylines);
    final gMarkers = <gmaps.Marker>{};
    for (final m in widget.markers) {
      final cachedIcon = _CompactTransitBitmaps.cached(m);
      if (cachedIcon == null) continue;
      gMarkers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId(m.id),
          position: gmaps.LatLng(m.position.latitude, m.position.longitude),
          infoWindow: gmaps.InfoWindow(title: m.label),
          anchor: const Offset(0.5, 0.5),
          rotation: m.isBus ? (m.headingDegrees % 360) : 0.0,
          flat: m.isBus,
          zIndexInt: m.isUserLocation ? 40 : (m.isBus ? 25 : 10),
          icon: cachedIcon,
          onTap: widget.onMarkerTap != null ? () => widget.onMarkerTap!(m.id) : null,
        ),
      );
    }

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: gmaps.LatLng(widget.center.latitude, widget.center.longitude),
        zoom: widget.zoom,
      ),
      // Google Maps ALWAYS stays in default crisp Light Roadmap theme
      mapType: gmaps.MapType.normal,
      buildingsEnabled: true,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      polylines: gPolylines,
      markers: gMarkers,
      onMapCreated: (controller) {
        _controller = controller;
        _fitIfReady();
      },
    );
  }
}

class _GoogleMapTestPreview extends StatelessWidget {
  const _GoogleMapTestPreview({
    super.key,
    required this.title,
    required this.center,
    required this.markerCount,
    required this.polylineCount,
    required this.scheme,
  });

  final String title;
  final LatLng center;
  final int markerCount;
  final int polylineCount;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_rounded, size: 36, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${center.latitude.toStringAsFixed(4)}, '
              '${center.longitude.toStringAsFixed(4)} • '
              '$markerCount pins • $polylineCount routes',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
