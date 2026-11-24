// Unified 3D Google Maps + 2D Interactive Transit Map widget with Maribor camera presets.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../features/map/presentation/widgets/maribor_transit_map.dart';
import '../utils/geo.dart';
import 'google_map_models.dart';
import 'google_web_views.dart';

/// Displays Google Maps 3D (`<gmp-map-3d>` on Web / 3D tilted `GoogleMap` on Mobile)
/// with an instant switcher to the 2D interactive Maribor transit map and camera presets.
class GoogleMap3DWidget extends StatefulWidget {
  /// Creates a [GoogleMap3DWidget].
  const GoogleMap3DWidget({
    super.key,
    this.initialCenter = GeoUtils.mariborCenter,
    this.initialZoom = 13.5,
    this.mapController,
    this.polylines3D = const [],
    this.markers3D = const [],
    this.polylines2D = const [],
    this.markers2D = const [],
    this.initialUse3D = false,
    this.showPresets = false,
    this.showStatusPill = true,
    this.fitBounds = false,
    this.fitSignature = '',
    this.onFullScreenToggle,
    this.isFullScreen = false,
    this.activeBusCount,
    this.totalPassengers,
    this.onRecenter2D,
    this.recenterLabel,
  });

  /// Initial map center.
  final LatLng initialCenter;

  /// Initial 2D zoom.
  final double initialZoom;

  /// Optional controller for 2D mode.
  final MapController? mapController;

  /// Polylines rendered in Google 2D & 3D modes.
  final List<GoogleMap3DPolylineData> polylines3D;

  /// Markers rendered in Google 2D & 3D modes.
  final List<GoogleMap3DMarkerData> markers3D;

  /// Polylines rendered in `flutter_map` VM-test fallback mode.
  final List<Polyline> polylines2D;

  /// Markers rendered in `flutter_map` VM-test fallback mode.
  final List<Marker> markers2D;

  /// Whether 3D Google Maps mode starts selected (defaults to 2D Google Road View).
  final bool initialUse3D;

  /// Whether to show Maribor 3D camera preset chips.
  final bool showPresets;

  /// Whether to render the live bus/passenger count pill on wider viewports.
  final bool showStatusPill;

  /// Auto-fits camera bounds to active polylines/markers when [fitSignature] changes.
  final bool fitBounds;

  /// Signature key guarding camera bounds re-fits.
  final String fitSignature;

  /// Optional callback enabling a compact top-right full-screen map toggle button.
  final VoidCallback? onFullScreenToggle;

  /// True when already displayed inside full-screen mode.
  final bool isFullScreen;

  /// Optional live bus count badge shown in the top corner.
  final int? activeBusCount;

  /// Optional total rider count badge shown in the top corner.
  final int? totalPassengers;

  /// Optional callback for 2D recenter button.
  final VoidCallback? onRecenter2D;

  /// Label for 2D recenter button.
  final String? recenterLabel;

  @override
  State<GoogleMap3DWidget> createState() => _GoogleMap3DWidgetState();
}

class _GoogleMap3DWidgetState extends State<GoogleMap3DWidget> {
  late bool _use3D;
  late GoogleMap3DCameraPreset _activePreset;

  @override
  void initState() {
    super.initState();
    _use3D = widget.initialUse3D;
    _activePreset = GoogleMap3DCameraPreset(
      id: 'initial',
      label: 'Glavni trg & Center',
      center: widget.initialCenter,
    );
  }

  void _selectPreset(GoogleMap3DCameraPreset preset) {
    setState(() {
      _activePreset = preset;
    });
    if (!_use3D && widget.mapController != null) {
      try {
        widget.mapController!.move(preset.center, 14.4);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final showLiveCounter = widget.showStatusPill &&
        viewportWidth >= 520 &&
        (widget.activeBusCount != null || widget.totalPassengers != null);
    final showCameraPresets =
        widget.showPresets && (_use3D || viewportWidth >= 800);

    return Stack(
      children: [
        Positioned.fill(
          child: _use3D
              ? GoogleMap3DPlatformView(
                  center: _activePreset.center,
                  tilt: _activePreset.tilt,
                  heading: _activePreset.heading,
                  range: _activePreset.range,
                  mobileZoom: _activePreset.mobileZoom,
                  polylines: widget.polylines3D,
                  markers: widget.markers3D,
                )
              : (isFlutterTestEnvironment
                  ? MariborTransitMap(
                      mapController: widget.mapController,
                      initialCenter: _activePreset.center,
                      initialZoom: widget.initialZoom,
                      polylines: widget.polylines2D,
                      markers: widget.markers2D,
                      onRecenter: widget.onRecenter2D,
                      recenterLabel: widget.recenterLabel,
                    )
                  : GoogleRoadMapPlatformView(
                      center: _activePreset.center,
                      zoom: widget.initialZoom,
                      polylines: widget.polylines3D,
                      markers: widget.markers3D,
                      fitBounds: widget.fitBounds && _activePreset.id == 'initial',
                      fitSignature: widget.fitSignature,
                    )),
        ),
        // Compact top bar: 2D/3D switcher left + optional live pill & full-screen toggle right
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Material(
                  color: scheme.surface.withValues(alpha: 0.94),
                  elevation: 3,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ModePill(
                          selected: !_use3D,
                          icon: Icons.map_outlined,
                          label: '2D',
                          onTap: () => setState(() => _use3D = false),
                        ),
                        const SizedBox(width: 2),
                        _ModePill(
                          selected: _use3D,
                          icon: Icons.view_in_ar_rounded,
                          label: '3D',
                          onTap: () => setState(() => _use3D = true),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showLiveCounter) ...[
                      Material(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.90),
                        elevation: 3,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                [
                                  if (widget.activeBusCount != null)
                                    '${widget.activeBusCount} busov v živo',
                                  if (widget.totalPassengers != null)
                                    '${widget.totalPassengers} potnikov',
                                ].join(' • '),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.onFullScreenToggle != null)
                      Material(
                        color: scheme.surface.withValues(alpha: 0.95),
                        elevation: 3,
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          key: Key(
                            widget.isFullScreen
                                ? 'exit_fullscreen_map_btn'
                                : 'toggle_fullscreen_map_btn',
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: widget.isFullScreen
                              ? 'Zapri celozaslonski zemljevid'
                              : 'Celozaslonski zemljevid',
                          icon: Icon(
                            widget.isFullScreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                            color: scheme.onSurface,
                          ),
                          onPressed: widget.onFullScreenToggle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Bottom Maribor 3D camera presets
        if (showCameraPresets)
          Positioned(
            left: 10,
            right: _use3D ? 10 : 120,
            bottom: 10,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final preset in maribor3DCameraPresets) ...[
                    ActionChip(
                      avatar: Icon(
                        Icons.explore_rounded,
                        size: 16,
                        color: _activePreset.id == preset.id
                            ? scheme.onPrimary
                            : scheme.primary,
                      ),
                      label: Text(
                        preset.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _activePreset.id == preset.id
                              ? scheme.onPrimary
                              : scheme.onSurface,
                        ),
                      ),
                      backgroundColor: _activePreset.id == preset.id
                          ? scheme.primary
                          : scheme.surface.withValues(alpha: 0.94),
                      side: BorderSide(color: scheme.outlineVariant),
                      onPressed: () => _selectPreset(preset),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
