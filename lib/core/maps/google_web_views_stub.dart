// Non-web (Android, iOS, and VM test) implementation of Google Maps Directions & 3D/2D Views.

import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'google_map_models.dart';
import 'google_maps_config.dart';

/// True when executing inside `flutter test` on the Dart VM.
bool get isFlutterTestEnvironment =>
    Platform.environment.containsKey('FLUTTER_TEST');

/// Displays Google Maps Directions Embed (`<iframe>` on Web; interactive card on Mobile/Tests).
class GoogleDirectionsEmbedPlatformView extends StatelessWidget {
  /// Creates a [GoogleDirectionsEmbedPlatformView].
  const GoogleDirectionsEmbedPlatformView({
    super.key,
    required this.origin,
    required this.destination,
    this.mode = 'transit',
    this.avoidTolls = false,
    this.avoidHighways = false,
  });

  /// Origin place or address string.
  final String origin;

  /// Destination place or address string.
  final String destination;

  /// Google Maps travel mode (`transit`, `driving`, `walking`).
  final String mode;

  /// Whether `avoid=tolls` is enabled.
  final bool avoidTolls;

  /// Whether `avoid=highways` is enabled.
  final bool avoidHighways;

  @override
  Widget build(BuildContext context) {
    final embedUri = GoogleMapsConfig.buildDirectionsEmbedUri(
      origin: origin,
      destination: destination,
      mode: mode,
      avoidTolls: avoidTolls,
      avoidHighways: avoidHighways,
    );
    final mapsOpenUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': origin,
      'destination': destination,
      'travelmode': mode,
    });
    final scheme = Theme.of(context).colorScheme;

    return Container(
      key: const Key('google_directions_embed_card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_rounded, size: 42, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            'Google Maps Directions ($mode)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '$origin → $destination',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          SelectableText(
            embedUri.toString(),
            maxLines: 2,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => launchUrl(
              mapsOpenUri,
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Google Maps'),
          ),
        ],
      ),
    );
  }
}

/// Renders Google Maps 3D SDK on Android/iOS (tilted 3D buildings) or a safe stub in tests.
class GoogleMap3DPlatformView extends StatefulWidget {
  /// Creates a [GoogleMap3DPlatformView].
  const GoogleMap3DPlatformView({
    super.key,
    required this.center,
    this.tilt = 60,
    this.heading = 18,
    this.range = 1750,
    this.mobileZoom = 15.8,
    this.polylines = const [],
    this.markers = const [],
  });

  /// Map camera target coordinate.
  final LatLng center;

  /// Camera tilt angle in degrees (`0..75`).
  final double tilt;

  /// Camera bearing/heading in degrees (`0..360`).
  final double heading;

  /// Web 3D camera distance range in meters.
  final double range;

  /// Mobile zoom level (`>= 15` activates 3D buildings).
  final double mobileZoom;

  /// Polylines drawn over Maribor streets.
  final List<GoogleMap3DPolylineData> polylines;

  /// Live bus and stop markers.
  final List<GoogleMap3DMarkerData> markers;

  @override
  State<GoogleMap3DPlatformView> createState() =>
      _GoogleMap3DPlatformViewState();
}

class _CompactTransitBitmaps {
  static final Map<String, gmaps.BitmapDescriptor> _cache = {};

  static String keyFor(GoogleMap3DMarkerData m) {
    if (m.isBus) {
      final code = (m.shortLabel ?? m.label.split(' ').first).toUpperCase();
      return 'bus|$code|${m.color.toARGB32()}';
    }
    return 'stop|${m.color.toARGB32()}';
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
    if (m.isBus) {
      width = 76;
      height = 44;
      const w = 76.0;
      const h = 44.0;
      final rrect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 2, w - 4, h - 4),
        const Radius.circular(14),
      );
      canvas.drawRRect(rrect, Paint()..color = m.color);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0,
      );
      final code = (m.shortLabel ?? m.label.split(' ').first)
          .toUpperCase()
          .trim();
      final displayCode = code.length > 4 ? code.substring(0, 4) : code;
      final tp = TextPainter(
        text: TextSpan(
          text: displayCode,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((w - tp.width) / 2, (h - tp.height) / 2));
    } else {
      width = 24;
      height = 24;
      const center = Offset(12, 12);
      canvas.drawCircle(center, 9, Paint()..color = Colors.white);
      canvas.drawCircle(
        center,
        9,
        Paint()
          ..color = m.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0,
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
    result.add(
      gmaps.Polyline(
        polylineId: gmaps.PolylineId('${line.id}_casing'),
        color: Colors.white.withValues(alpha: 0.92),
        width: w + 3,
        zIndex: 1,
        points: gPoints,
      ),
    );
    result.add(
      gmaps.Polyline(
        polylineId: gmaps.PolylineId(line.id),
        color: line.color,
        width: w,
        zIndex: 2,
        points: gPoints,
      ),
    );
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
      _controller?.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: gmaps.LatLng(
              widget.center.latitude,
              widget.center.longitude,
            ),
            zoom: widget.mobileZoom,
            tilt: widget.tilt.clamp(0.0, 67.5),
            bearing: widget.heading,
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

  @override
  Widget build(BuildContext context) {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    final isMobile = !isTest && (Platform.isAndroid || Platform.isIOS);
    final scheme = Theme.of(context).colorScheme;

    if (!isMobile) {
      return Container(
        key: const Key('google_map_3d_stub_preview'),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.view_in_ar_rounded, size: 44, color: scheme.primary),
            const SizedBox(height: 10),
            Text(
              'Google Maps 3D SDK (${widget.tilt.round()}° tilt)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.center.latitude.toStringAsFixed(4)}, '
              '${widget.center.longitude.toStringAsFixed(4)} • '
              '${widget.markers.length} pins • ${widget.polylines.length} routes',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
          zIndexInt: m.isBus ? 20 : 10,
          icon: cachedIcon,
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

/// Interactive 2D Google Maps view on Android/iOS with compact custom bus badges, stop dots, and bounds fitting.
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

  /// Map camera target coordinate.
  final LatLng center;

  /// Initial zoom level when [fitBounds] is false.
  final double zoom;

  /// Google Routes polylines rendered over Maribor roads.
  final List<GoogleMap3DPolylineData> polylines;

  /// Compact bus pills and stop markers.
  final List<GoogleMap3DMarkerData> markers;

  /// Automatically frames all [polylines] and [markers] when true.
  final bool fitBounds;

  /// Cache key controlling when bounds re-fit happens.
  final String fitSignature;

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
    } else if (!widget.fitBounds &&
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
    controller.animateCamera(gmaps.CameraUpdate.newLatLngBounds(bounds, 44));
  }

  @override
  Widget build(BuildContext context) {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    final isMobile = !isTest && (Platform.isAndroid || Platform.isIOS);
    final scheme = Theme.of(context).colorScheme;

    if (!isMobile) {
      return Container(
        key: const Key('google_map_3d_stub_preview'),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_rounded, size: 44, color: scheme.primary),
            const SizedBox(height: 10),
            Text(
              'Google Maps 2D Road View',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.center.latitude.toStringAsFixed(4)}, '
              '${widget.center.longitude.toStringAsFixed(4)} • '
              '${widget.markers.length} pins • ${widget.polylines.length} routes',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
          zIndexInt: m.isBus ? 20 : 10,
          icon: cachedIcon,
        ),
      );
    }

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: gmaps.LatLng(widget.center.latitude, widget.center.longitude),
        zoom: widget.zoom,
      ),
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
