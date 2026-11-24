//**********************************************
// Unified 2D/3D Google Maps & Flyover Widget  *
//**********************************************

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../accessibility/a11y_settings.dart';
import '../utils/geo.dart';
import 'google_map_models.dart';
import 'google_web_views.dart';

//**********************************************
// GoogleMap3DWidget with 3D route flyover     *
//**********************************************

/// Displays Google Maps 2D and tilted 3D Vector Maps (`tilt: 60°`, dynamic bearing,
/// 3D buildings) with interactive play/pause, camera angle, and route scrubbing controls.
class GoogleMap3DWidget extends ConsumerStatefulWidget {
  /// Creates a [GoogleMap3DWidget].
  const GoogleMap3DWidget({
    super.key,
    this.initialCenter = GeoUtils.mariborCenter,
    this.initialZoom = 13.6,
    this.polylines3D = const [],
    this.markers3D = const [],
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

  /// Polylines rendered in Google 2D & 3D modes.
  final List<GoogleMap3DPolylineData> polylines3D;

  /// Markers rendered in Google 2D & 3D modes.
  final List<GoogleMap3DMarkerData> markers3D;

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
  ConsumerState<GoogleMap3DWidget> createState() => _GoogleMap3DWidgetState();
}

class _GoogleMap3DWidgetState extends ConsumerState<GoogleMap3DWidget>
    with SingleTickerProviderStateMixin {
  late bool _use3D;
  late GoogleMap3DCameraPreset _activePreset;
  late final AnimationController _flyController;

  double _scrubProgress = 0.0;
  double _tiltDegrees = 60.0;
  double _headingOffset = 0.0;
  double _playbackSpeed = 1.0;
  bool _followRouteCamera = false;

  @override
  void initState() {
    super.initState();
    _use3D = widget.initialUse3D;
    _activePreset = GoogleMap3DCameraPreset(
      id: 'initial',
      label: 'Glavni trg & Center',
      center: widget.initialCenter,
    );
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..addListener(() {
        if (!mounted) return;
        setState(() {
          _scrubProgress = _flyController.value;
          _followRouteCamera = true;
        });
      });
  }

  @override
  void dispose() {
    _flyController.dispose();
    super.dispose();
  }

  List<LatLng> _combinedFlyoverPolyline() {
    final pts = <LatLng>[];
    for (final line in widget.polylines3D) {
      if (line.points.length >= 2) {
        pts.addAll(line.points);
      }
    }
    return pts;
  }

  void _togglePlayPause() {
    final pts = _combinedFlyoverPolyline();
    if (pts.length < 2) return;
    if (_flyController.isAnimating) {
      _flyController.stop();
      setState(() {});
    } else {
      if (_scrubProgress >= 0.99) {
        _scrubProgress = 0.0;
      }
      _flyController.duration = Duration(
        milliseconds: (26000 / _playbackSpeed).round(),
      );
      _flyController.repeat(min: 0.0, max: 1.0);
      setState(() {
        _followRouteCamera = true;
      });
    }
  }

  void _onScrubChanged(double value) {
    _flyController.stop();
    _flyController.value = value;
    setState(() {
      _scrubProgress = value;
      _followRouteCamera = true;
    });
  }

  void _cycleSpeed() {
    setState(() {
      _playbackSpeed = _playbackSpeed == 1.0
          ? 2.0
          : (_playbackSpeed == 2.0 ? 4.0 : 1.0);
    });
    if (_flyController.isAnimating) {
      final pos = _flyController.value;
      _flyController.duration = Duration(
        milliseconds: (26000 / _playbackSpeed).round(),
      );
      _flyController.forward(from: pos);
      _flyController.repeat();
    }
  }

  void _selectPreset(GoogleMap3DCameraPreset preset) {
    _flyController.stop();
    setState(() {
      _activePreset = preset;
      _followRouteCamera = false;
      _tiltDegrees = preset.tilt;
      _headingOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mapStyle = ref.watch(
      a11ySettingsProvider.select((s) => s.mapStylePreset),
    );
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final showLiveCounter = widget.showStatusPill &&
        viewportWidth >= 520 &&
        (widget.activeBusCount != null || widget.totalPassengers != null);
    final flyoverPts = _combinedFlyoverPolyline();
    final canFlyover = flyoverPts.length >= 2;
    final showCameraPresets =
        widget.showPresets && (_use3D || viewportWidth >= 800) && !_use3D;

    LatLng effectiveCenter3D = _activePreset.center;
    double effectiveHeading3D = (_activePreset.heading + _headingOffset) % 360;
    final markersWithFlyover = List<GoogleMap3DMarkerData>.from(widget.markers3D);

    if (_use3D && canFlyover && _followRouteCamera) {
      final pos = GeoUtils.interpolatePolyline(flyoverPts, _scrubProgress);
      final lookAhead = GeoUtils.interpolatePolyline(
        flyoverPts,
        (_scrubProgress + 0.03).clamp(0.0, 1.0),
      );
      final segmentBearing = GeoUtils.bearingDegrees(pos, lookAhead);
      effectiveCenter3D = pos;
      effectiveHeading3D = (segmentBearing + _headingOffset) % 360;
      markersWithFlyover.add(
        GoogleMap3DMarkerData(
          id: 'flyover_3d_bus_chase',
          position: pos,
          shortLabel: '3D',
          label: '3D trasa (${(_scrubProgress * 100).round()}%)',
          isBus: true,
          color: const Color(0xFFC8102E),
        ),
      );
    } else if (_use3D && canFlyover && _activePreset.id == 'initial') {
      effectiveCenter3D = flyoverPts[flyoverPts.length ~/ 2];
    }

    return Stack(
      children: [
        Positioned.fill(
          child: _use3D
              ? GoogleMap3DPlatformView(
                  center: effectiveCenter3D,
                  tilt: _tiltDegrees,
                  heading: effectiveHeading3D,
                  mobileZoom: _followRouteCamera ? 16.5 : _activePreset.mobileZoom,
                  polylines: widget.polylines3D,
                  markers: markersWithFlyover,
                  camera3DActive: _followRouteCamera || _flyController.isAnimating,
                  stylePreset: mapStyle,
                  fitBounds: false,
                  fitSignature: widget.fitSignature,
                )
              : GoogleRoadMapPlatformView(
                  center: _activePreset.center,
                  zoom: widget.initialZoom,
                  polylines: widget.polylines3D,
                  markers: widget.markers3D,
                  fitBounds: widget.fitBounds && _activePreset.id == 'initial',
                  fitSignature: widget.fitSignature,
                  stylePreset: mapStyle,
                ),
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
                          onTap: () {
                            _flyController.stop();
                            setState(() {
                              _use3D = false;
                              _followRouteCamera = false;
                            });
                          },
                        ),
                        const SizedBox(width: 2),
                        _ModePill(
                          selected: _use3D,
                          icon: Icons.view_in_ar_rounded,
                          label: '3D trasa',
                          onTap: () {
                            setState(() {
                              _use3D = true;
                              if (canFlyover) {
                                _followRouteCamera = true;
                              }
                            });
                          },
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
                    if (widget.onRecenter2D != null && !_use3D) ...[
                      Material(
                        color: scheme.surface.withValues(alpha: 0.95),
                        elevation: 3,
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          tooltip: widget.recenterLabel ?? 'Center',
                          icon: Icon(
                            Icons.my_location_rounded,
                            color: scheme.primary,
                          ),
                          onPressed: widget.onRecenter2D,
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
        // Bottom 3D Route Flyover Player & Camera Controls
        if (_use3D)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Material(
              color: scheme.surface.withValues(alpha: 0.94),
              elevation: 5,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (canFlyover)
                      Row(
                        children: [
                          IconButton(
                            key: const Key('route_3d_play_pause_btn'),
                            tooltip: _flyController.isAnimating
                                ? 'Premor 3D trase'
                                : 'Predvajaj 3D traso',
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              _flyController.isAnimating
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_filled_rounded,
                              color: scheme.primary,
                              size: 32,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                          Expanded(
                            child: Slider(
                              key: const Key('route_3d_scrubber_slider'),
                              value: _scrubProgress.clamp(0.0, 1.0),
                              onChanged: _onScrubChanged,
                            ),
                          ),
                          Text(
                            '${(_scrubProgress * 100).round()}%',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _CameraChip(
                            icon: Icons.threesixty_rounded,
                            label: 'Nagib ${_tiltDegrees.round()}°',
                            selected: _tiltDegrees >= 55,
                            onTap: () => setState(() {
                              _tiltDegrees = _tiltDegrees >= 58 ? 42.0 : 60.0;
                            }),
                          ),
                          const SizedBox(width: 6),
                          _CameraChip(
                            icon: Icons.rotate_left_rounded,
                            label: '-45°',
                            onTap: () => setState(() {
                              _headingOffset = (_headingOffset - 45) % 360;
                            }),
                          ),
                          const SizedBox(width: 6),
                          _CameraChip(
                            icon: Icons.rotate_right_rounded,
                            label: '+45°',
                            onTap: () => setState(() {
                              _headingOffset = (_headingOffset + 45) % 360;
                            }),
                          ),
                          if (canFlyover) ...[
                            const SizedBox(width: 6),
                            _CameraChip(
                              icon: Icons.speed_rounded,
                              label: '${_playbackSpeed.round()}×',
                              selected: _playbackSpeed > 1.0,
                              onTap: _cycleSpeed,
                            ),
                          ],
                          if (widget.showPresets) ...[
                            const SizedBox(width: 8),
                            for (final preset in maribor3DCameraPresets) ...[
                              _CameraChip(
                                icon: Icons.explore_rounded,
                                label: preset.label,
                                selected: !_followRouteCamera &&
                                    _activePreset.id == preset.id,
                                onTap: () => _selectPreset(preset),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (showCameraPresets)
          Positioned(
            left: 10,
            right: 10,
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

class _CameraChip extends StatelessWidget {
  const _CameraChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(
        icon,
        size: 15,
        color: selected ? scheme.onPrimary : scheme.primary,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: selected ? scheme.onPrimary : scheme.onSurface,
        ),
      ),
      backgroundColor: selected
          ? scheme.primary
          : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      side: BorderSide(color: scheme.outlineVariant),
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }
}
