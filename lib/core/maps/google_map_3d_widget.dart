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

/// Displays Google Maps 2D and tilted 3D Vector Maps (`tilt: 60°`, `zoom: 17.2`,
/// smoothed bearing interpolation along Google Routes road polylines, 3D buildings)
/// with isolated `ValueNotifier` playback controls and zero overflow.
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
    this.forceCenter = false,
    this.onFullScreenToggle,
    this.isFullScreen = false,
    this.activeBusCount,
    this.totalPassengers,
    this.onRecenter2D,
    this.recenterLabel,
    this.onMarkerTap,
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

  /// Forces camera center update when true.
  final bool forceCenter;

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

  /// Invoked when a map marker (bus or stop) is tapped.
  final ValueChanged<String>? onMarkerTap;

  @override
  ConsumerState<GoogleMap3DWidget> createState() => _GoogleMap3DWidgetState();
}

class _GoogleMap3DWidgetState extends ConsumerState<GoogleMap3DWidget>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<bool> _use3D;
  late final ValueNotifier<double> _scrubProgress;
  late final ValueNotifier<bool> _followRouteCamera;
  late final ValueNotifier<double> _playbackSpeed;
  late final ValueNotifier<double> _tiltDegrees;
  late final ValueNotifier<double> _headingOffset;
  late final ValueNotifier<GoogleMap3DCameraPreset> _activePreset;
  late final AnimationController _flyController;

  double _smoothedBearing = 18.0;

  @override
  void initState() {
    super.initState();
    _use3D = ValueNotifier<bool>(widget.initialUse3D);
    _scrubProgress = ValueNotifier<double>(0.0);
    _followRouteCamera = ValueNotifier<bool>(widget.initialUse3D);
    _playbackSpeed = ValueNotifier<double>(1.0);
    _tiltDegrees = ValueNotifier<double>(60.0);
    _headingOffset = ValueNotifier<double>(0.0);
    _activePreset = ValueNotifier<GoogleMap3DCameraPreset>(
      GoogleMap3DCameraPreset(
        id: 'initial',
        label: 'Glavni trg & Center',
        center: widget.initialCenter,
      ),
    );
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..addListener(() {
        if (!mounted) return;
        _scrubProgress.value = _flyController.value;
        if (!_followRouteCamera.value) _followRouteCamera.value = true;
      });
  }

  @override
  void didUpdateWidget(covariant GoogleMap3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialUse3D != widget.initialUse3D) {
      _use3D.value = widget.initialUse3D;
      _followRouteCamera.value = widget.initialUse3D;
    }
    if (oldWidget.initialCenter != widget.initialCenter &&
        _activePreset.value.id == 'initial') {
      _activePreset.value = GoogleMap3DCameraPreset(
        id: 'initial',
        label: 'Center',
        center: widget.initialCenter,
      );
    }
  }

  @override
  void dispose() {
    _flyController.dispose();
    _use3D.dispose();
    _scrubProgress.dispose();
    _followRouteCamera.dispose();
    _playbackSpeed.dispose();
    _tiltDegrees.dispose();
    _headingOffset.dispose();
    _activePreset.dispose();
    super.dispose();
  }

  List<LatLng> _combinedFlyoverPolyline() {
    final pts = <LatLng>[];
    for (final line in widget.polylines3D) {
      if (line.points.length >= 2) {
        if (pts.isNotEmpty && pts.last == line.points.first) {
          pts.addAll(line.points.skip(1));
        } else {
          pts.addAll(line.points);
        }
      }
    }
    return pts;
  }

  double _shortestAngleLerp(double current, double target, double alpha) {
    final diff = ((target - current + 540.0) % 360.0) - 180.0;
    return (current + diff * alpha + 360.0) % 360.0;
  }

  void _togglePlayPause() {
    final pts = _combinedFlyoverPolyline();
    if (pts.length < 2) return;
    if (_flyController.isAnimating) {
      _flyController.stop();
      setState(() {});
    } else {
      if (_scrubProgress.value >= 0.99) {
        _scrubProgress.value = 0.0;
      }
      _flyController.duration = Duration(
        milliseconds: (26000 / _playbackSpeed.value).round(),
      );
      _flyController.repeat(min: 0.0, max: 1.0);
      _followRouteCamera.value = true;
      setState(() {});
    }
  }

  void _onScrubChanged(double value) {
    _flyController.stop();
    _flyController.value = value;
    _scrubProgress.value = value;
    _followRouteCamera.value = true;
  }

  void _cycleSpeed() {
    final next = _playbackSpeed.value == 1.0
        ? 2.0
        : (_playbackSpeed.value == 2.0 ? 4.0 : 1.0);
    _playbackSpeed.value = next;
    if (_flyController.isAnimating) {
      final pos = _flyController.value;
      _flyController.duration = Duration(
        milliseconds: (26000 / next).round(),
      );
      _flyController.forward(from: pos);
      _flyController.repeat();
    }
  }

  void _selectPreset(GoogleMap3DCameraPreset preset) {
    _flyController.stop();
    _activePreset.value = preset;
    _followRouteCamera.value = false;
    _tiltDegrees.value = preset.tilt;
    _headingOffset.value = 0.0;
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

    return Stack(
      children: [
        // Isolated map surface rebuilding smoothly on 3D camera/scrub ticks
        Positioned.fill(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              _use3D,
              _scrubProgress,
              _followRouteCamera,
              _tiltDegrees,
              _headingOffset,
              _activePreset,
            ]),
            builder: (_, _) {
              final use3d = _use3D.value;
              final preset = _activePreset.value;
              final follow = _followRouteCamera.value;
              final scrub = _scrubProgress.value;
              final tilt = _tiltDegrees.value;
              final hOff = _headingOffset.value;

              var effectiveCenter3D = preset.center;
              var effectiveHeading3D = (preset.heading + hOff) % 360;
              final markersWithFlyover =
                  List<GoogleMap3DMarkerData>.from(widget.markers3D);

              if (use3d && canFlyover && follow) {
                final pos = GeoUtils.interpolatePolyline(flyoverPts, scrub);
                final lookAhead = GeoUtils.interpolatePolyline(
                  flyoverPts,
                  (scrub + 0.025).clamp(0.0, 1.0),
                );
                final rawBearing = GeoUtils.bearingDegrees(pos, lookAhead);
                _smoothedBearing = _shortestAngleLerp(
                  _smoothedBearing,
                  rawBearing,
                  0.35,
                );
                effectiveCenter3D = pos;
                effectiveHeading3D = (_smoothedBearing + hOff) % 360;
                markersWithFlyover.add(
                  GoogleMap3DMarkerData(
                    id: 'flyover_3d_bus_chase',
                    position: pos,
                    shortLabel: 'BUS',
                    label: '3D trasa (${(scrub * 100).round()}%)',
                    isBus: true,
                    headingDegrees: _smoothedBearing,
                    color: const Color(0xFFC8102E),
                  ),
                );
              } else if (use3d && canFlyover && preset.id == 'initial') {
                effectiveCenter3D = flyoverPts[flyoverPts.length ~/ 2];
              }

              return use3d
                  ? GoogleMap3DPlatformView(
                      center: effectiveCenter3D,
                      tilt: tilt,
                      heading: effectiveHeading3D,
                      mobileZoom: follow ? 17.2 : preset.mobileZoom,
                      polylines: widget.polylines3D,
                      markers: markersWithFlyover,
                      camera3DActive: follow || _flyController.isAnimating,
                      stylePreset: mapStyle,
                      fitBounds: widget.fitBounds &&
                          preset.id == 'initial' &&
                          !(follow || _flyController.isAnimating),
                      fitSignature: '3d|${widget.fitSignature}',
                      forceCenter: widget.forceCenter,
                      onMarkerTap: widget.onMarkerTap,
                    )
                  : GoogleRoadMapPlatformView(
                      center: preset.center,
                      zoom: widget.initialZoom,
                      polylines: widget.polylines3D,
                      markers: widget.markers3D,
                      fitBounds: widget.fitBounds && preset.id == 'initial',
                      fitSignature: widget.fitSignature,
                      forceCenter: widget.forceCenter,
                      stylePreset: mapStyle,
                      onMarkerTap: widget.onMarkerTap,
                    );
            },
          ),
        ),
        // Compact top bar: 2D/3D toggle + live pill + recenter + fullscreen
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: SafeArea(
            bottom: false,
            child: ValueListenableBuilder<bool>(
              valueListenable: _use3D,
              builder: (_, is3d, _) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Material(
                      color: scheme.surface.withValues(alpha: 0.94),
                      elevation: 3,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Wrap(
                          spacing: 2,
                          runSpacing: 2,
                          children: [
                            _ModePill(
                              selected: !is3d,
                              icon: Icons.map_outlined,
                              label: '2D',
                              onTap: () {
                                _flyController.stop();
                                _use3D.value = false;
                                _followRouteCamera.value = false;
                              },
                            ),
                            _ModePill(
                              selected: is3d,
                              icon: Icons.view_in_ar_rounded,
                              label: '3D trasa',
                              onTap: () {
                                _use3D.value = true;
                                if (canFlyover) {
                                  _followRouteCamera.value = true;
                                }
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
                            color: const Color(0xFF0F172A)
                                .withValues(alpha: 0.90),
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
                                        '${widget.activeBusCount} busov',
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
                        if (widget.onRecenter2D != null && !is3d) ...[
                          Material(
                            color: scheme.surface.withValues(alpha: 0.95),
                            elevation: 3,
                            borderRadius: BorderRadius.circular(12),
                            child: IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              tooltip: widget.recenterLabel ?? 'Center on Me',
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
                                minWidth: 48,
                                minHeight: 48,
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
                );
              },
            ),
          ),
        ),
        // Bottom 3D Route Flyover Player & Camera Controls (strictly isolated)
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: ValueListenableBuilder<bool>(
            valueListenable: _use3D,
            builder: (_, is3d, _) {
              if (!is3d) return const SizedBox.shrink();
              return SafeArea(
                top: false,
                child: Material(
                  color: scheme.surface.withValues(alpha: 0.95),
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
                          ValueListenableBuilder<double>(
                            valueListenable: _scrubProgress,
                            builder: (_, scrub, _) {
                              return Row(
                                children: [
                                  IconButton(
                                    key: const Key('route_3d_play_pause_btn'),
                                    tooltip: _flyController.isAnimating
                                        ? 'Premor 3D trase'
                                        : 'Predvajaj 3D traso',
                                    constraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
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
                                      value: scrub.clamp(0.0, 1.0),
                                      onChanged: _onScrubChanged,
                                    ),
                                  ),
                                  Text(
                                    '${(scrub * 100).round()}%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ],
                              );
                            },
                          ),
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            _playbackSpeed,
                            _followRouteCamera,
                            _tiltDegrees,
                            _activePreset,
                          ]),
                          builder: (_, _) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  if (canFlyover) ...[
                                    _CameraChip(
                                      icon: Icons.speed_rounded,
                                      label: '${_playbackSpeed.value.round()}×',
                                      selected: _playbackSpeed.value > 1.0,
                                      onTap: _cycleSpeed,
                                    ),
                                    const SizedBox(width: 6),
                                    _CameraChip(
                                      icon: _followRouteCamera.value
                                          ? Icons.videocam_rounded
                                          : Icons.videocam_off_outlined,
                                      label: 'Sledi kameri',
                                      selected: _followRouteCamera.value,
                                      onTap: () => _followRouteCamera.value =
                                          !_followRouteCamera.value,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  _CameraChip(
                                    icon: Icons.threesixty_rounded,
                                    label: 'Nagib ${_tiltDegrees.value.round()}°',
                                    selected: _tiltDegrees.value >= 55,
                                    onTap: () => _tiltDegrees.value =
                                        _tiltDegrees.value >= 58 ? 42.0 : 60.0,
                                  ),
                                  if (widget.showPresets) ...[
                                    const SizedBox(width: 8),
                                    for (final preset in maribor3DCameraPresets) ...[
                                      _CameraChip(
                                        icon: Icons.explore_rounded,
                                        label: preset.label,
                                        selected: !_followRouteCamera.value &&
                                            _activePreset.value.id == preset.id,
                                        onTap: () => _selectPreset(preset),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
