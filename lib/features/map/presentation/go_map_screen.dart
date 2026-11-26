//**********************************************
// Unified Go / Map Screen (Web & Mobile)      *
//**********************************************

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/accessibility/a11y_settings.dart';
import '../../../core/accessibility/semantics_helpers.dart';
import '../../../core/maps/google_map_3d_widget.dart';
import '../../../core/maps/google_map_models.dart';
import '../../../core/network/gemini_transit_service.dart';
import '../../../core/network/marprom_route_fusion.dart';
import '../../../core/utils/distance.dart';
import '../../../core/utils/geo.dart';
import '../../../data/models/bus_line.dart';
import '../../../data/models/bus_stop.dart';
import '../../../data/models/trip_plan.dart';
import '../../../data/seed/seed_places.dart';
import '../../lines/data/transit_providers.dart';
import '../../trip_planner/domain/route_planner.dart';
import '../../trip_planner/presentation/widgets/ai_transit_search_pill.dart';
import '../../trip_planner/presentation/widgets/smart_station_autocomplete.dart';
import '../../trip_planner/presentation/widgets/trip_endpoint.dart';
import '../../trip_planner/presentation/widgets/trip_option_card.dart';
import '../data/location_service.dart';

//**********************************************
// GoMapScreen Interactive Maps + AI Planner   *
//**********************************************

// Unified primary Go / Map screen combining live Google Maps (2D & 3D),
// pulsing user GPS location, Gemini AI Voice + Text transit search,
// diacritic-insensitive Smart Station Autocomplete, Nearest Stops, and
// Google Routes API v2 + Marprom fleet-enriched route results.
class GoMapScreen extends ConsumerStatefulWidget {
  // Creates a [GoMapScreen].
  const GoMapScreen({
    super.key,
    this.initialOriginStopId,
    this.initialDestinationStopId,
  });

  // Optional prefilled origin stop ID (e.g. from `/plan?from=...`).
  final String? initialOriginStopId;

  // Optional prefilled destination stop ID (e.g. from `/plan?to=...`).
  final String? initialDestinationStopId;

  @override
  ConsumerState<GoMapScreen> createState() => _GoMapScreenState();
}

class _GoMapScreenState extends ConsumerState<GoMapScreen> {
  TripEndpoint? _origin;
  TripEndpoint? _destination;
  List<TripOption> _options = const [];
  TripOption? _selectedOption;

  bool _manualMode = false;
  bool _loading = false;
  bool _use3DView = false;
  bool _desktopPanelOpen = true;
  bool _appliedInitialDeepLink = false;
  bool _isLateNightBanner = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyInitialStopsAndGpsOrigin();
    });
  }

  Future<void> _applyInitialStopsAndGpsOrigin() async {
    if (_appliedInitialDeepLink) return;
    _appliedInitialDeepLink = true;

    final stops = await ref.read(allStopsProvider.future);
    final stopsById = {for (final s in stops) s.id: s};
    final locState = ref.read(userLocationProvider).valueOrNull;

    TripEndpoint? nextOrigin;
    if (widget.initialOriginStopId != null &&
        stopsById.containsKey(widget.initialOriginStopId)) {
      nextOrigin = TripEndpoint.stop(stopsById[widget.initialOriginStopId]!);
    } else if (locState != null) {
      nextOrigin = locState.isGps
          ? TripEndpoint.gps(locState.effectivePosition)
          : (locState.manualStop != null
              ? TripEndpoint.stop(locState.manualStop!)
              : TripEndpoint.gps(GeoUtils.mariborCenter));
    } else {
      nextOrigin = const TripEndpoint.gps(GeoUtils.mariborCenter);
    }

    TripEndpoint? nextDest;
    if (widget.initialDestinationStopId != null &&
        stopsById.containsKey(widget.initialDestinationStopId)) {
      nextDest = TripEndpoint.stop(stopsById[widget.initialDestinationStopId]!);
      _manualMode = true;
    }

    if (!mounted) return;
    setState(() {
      _origin = nextOrigin;
      _destination = nextDest;
    });

    if (nextDest != null) {
      unawaited(_runRoutePlan());
    }
  }

  bool _isLateNightHour(DateTime dt) {
    final mins = dt.hour * 60 + dt.minute;
    return mins >= (23 * 60 + 15) || mins < (5 * 60);
  }

  Future<void> _runRoutePlan({
    TripTimeMode mode = TripTimeMode.leaveNow,
    DateTime? targetTime,
  }) async {
    final origin = _origin;
    final dest = _destination;
    if (origin == null || dest == null) return;

    final l10n = context.l10n;
    final settings = ref.read(a11ySettingsProvider);
    final isSl = settings.localeCode == 'sl';

    setState(() {
      _loading = true;
      _errorMessage = null;
      _isLateNightBanner = false;
    });

    try {
      final planner = ref.read(routePlannerProvider);
      final results = await planner.planTrip(
        origin: origin.position,
        destination: dest.position,
        originLabel: origin.displayLabel(l10n),
        destinationLabel: dest.displayLabel(l10n),
        mode: mode,
        targetTime: targetTime,
        accessibleOnly: settings.wheelchairAccessibleOnly,
        localeCode: settings.localeCode,
      );

      if (!mounted) return;
      final checkTime = targetTime ?? DateTime.now();
      final isLateNight = results.isEmpty && _isLateNightHour(checkTime);
      setState(() {
        _options = results;
        _selectedOption = results.isNotEmpty ? results.first : null;
        _desktopPanelOpen = true;
        _isLateNightBanner = isLateNight;
        if (isLateNight) {
          _errorMessage = isSl
              ? 'Nočna prekinitev (23:15–05:00): Marprom mestni avtobusi trenutno ne obratujejo.'
              : 'Night service pause (23:15–05:00): Marprom city buses are currently not running.';
        } else if (results.isEmpty) {
          _errorMessage = isSl
              ? 'Za izbrano relacijo trenutno ni najdenih povezav.'
              : 'No bus connections found for this route right now.';
        }
      });
    } on RoutesApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _options = const [];
        _selectedOption = null;
        _errorMessage = e.localizedMessage(settings.localeCode);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _options = const [];
        _selectedOption = null;
        _errorMessage = isSl
            ? 'Napaka pri izračunu poti: $e'
            : 'Failed to plan route: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _checkTomorrowMorning0600() {
    final now = DateTime.now();
    final nextDay = now.hour >= 6 ? now.add(const Duration(days: 1)) : now;
    final morning = DateTime(nextDay.year, nextDay.month, nextDay.day, 6, 0);
    unawaited(_runRoutePlan(
      mode: TripTimeMode.departAt,
      targetTime: morning,
    ));
  }

  void _handleAiResult(AiTransitSearchResult outcome) {
    final resolved = outcome.resolvedTrip;
    final isSl = ref.read(a11ySettingsProvider).localeCode == 'sl';
    if (resolved.wheelchairOnly &&
        !ref.read(a11ySettingsProvider).wheelchairAccessibleOnly) {
      unawaited(
        ref.read(a11ySettingsProvider.notifier).setWheelchairAccessibleOnly(true),
      );
    }

    setState(() {
      _origin = TripEndpoint(
        kind: TripEndpointKind.gps,
        position: resolved.originPosition,
      );
      _destination = TripEndpoint(
        kind: TripEndpointKind.place,
        position: resolved.destinationPosition,
      );
      _options = outcome.routes;
      _selectedOption = outcome.routes.isNotEmpty ? outcome.routes.first : null;
      _desktopPanelOpen = true;
      _isLateNightBanner =
          outcome.routes.isEmpty && _isLateNightHour(DateTime.now());
      _errorMessage = outcome.errorMessage ??
          (_isLateNightBanner
              ? (isSl
                  ? 'Nočna prekinitev (23:15–05:00): avtobusi ne vozijo.'
                  : 'Night service pause (23:15–05:00).')
              : null);
    });
  }

  Future<void> _routeToStop(BusStop stop, UserLocationState? loc) async {
    final currentPos = ref.read(liveGpsPositionNotifierProvider).value ??
        loc?.effectivePosition ??
        GeoUtils.mariborCenter;
    setState(() {
      _origin ??= TripEndpoint.gps(currentPos);
      _destination = TripEndpoint.stop(stop);
      _manualMode = true;
    });
    await _runRoutePlan();
  }

  void _swapEndpoints() {
    if (_origin == null && _destination == null) return;
    setState(() {
      final prevOrigin = _origin;
      _origin = _destination;
      _destination = prevOrigin;
    });
    if (_origin != null && _destination != null) {
      unawaited(_runRoutePlan());
    }
  }

  (List<GoogleMap3DPolylineData>, List<GoogleMap3DMarkerData>) _buildMapOverlay({
    required ThemeData theme,
    required Map<String, BusLine> linesById,
    required List<BusStop> stops,
    required LatLng userPos,
    required List<NearbyStopSummary> nearestStops,
  }) {
    final polylines = <GoogleMap3DPolylineData>[];
    final markers = <GoogleMap3DMarkerData>[
      GoogleMap3DMarkerData(
        id: 'user_live_gps',
        position: userPos,
        label: 'Moja lokacija',
        isUserLocation: true,
        color: const Color(0xFF2563EB),
      ),
    ];

    final option = _selectedOption;
    if (option != null) {
      for (var i = 0; i < option.legs.length; i++) {
        final leg = option.legs[i];
        if (leg.polyline.length >= 2) {
          final isWalk = leg.type == TripLegType.walk;
          final lineMeta = linesById[leg.lineId];
          final busColor = lineMeta?.color ?? theme.colorScheme.primary;
          polylines.add(
            GoogleMap3DPolylineData(
              id: 'go_leg_${option.id}_$i',
              points: leg.polyline,
              color: isWalk ? const Color(0xFF38BDF8) : busColor,
              strokeWidth: isWalk ? 4.5 : 6.5,
              isDashed: isWalk,
            ),
          );
        }
        if (leg.polyline.isNotEmpty && leg.type == TripLegType.bus) {
          final lineMeta = linesById[leg.lineId];
          final code = lineMeta?.code ?? leg.lineCode;
          final busColor = lineMeta?.color ?? theme.colorScheme.primary;
          markers.add(
            GoogleMap3DMarkerData(
              id: 'leg_board_${option.id}_$i',
              position: leg.polyline.first,
              shortLabel: code,
              isBus: code != null,
              isSelected: true,
              isWheelchairAccessible:
                  leg.isAccessible && (lineMeta?.isWheelchairAccessible ?? true),
              label: '${code ?? ''} • ${leg.fromName}',
              color: busColor,
            ),
          );
          markers.add(
            GoogleMap3DMarkerData(
              id: 'leg_alight_${option.id}_$i',
              position: leg.polyline.last,
              label: leg.toName,
              color: busColor,
            ),
          );
        }
      }
      if (option.legs.isNotEmpty && option.legs.last.polyline.isNotEmpty) {
        markers.add(
          GoogleMap3DMarkerData(
            id: 'dest_${option.id}',
            position: option.legs.last.polyline.last,
            label: _destination?.rawName ?? option.legs.last.toName,
            color: const Color(0xFF16A34A),
          ),
        );
      }
    } else {
      final highlightIds = <String>{
        for (final ns in nearestStops.take(5)) ns.stop.id,
      };
      for (final ns in nearestStops.take(6)) {
        markers.add(
          GoogleMap3DMarkerData(
            id: 'stop_${ns.stop.id}',
            position: ns.stop.position,
            label: '${ns.stop.name} (${ns.walkMinutes} min)',
            isWheelchairAccessible: ns.stop.isStepFree,
            isSelected: highlightIds.contains(ns.stop.id),
            color: theme.colorScheme.primary,
          ),
        );
      }
      for (final stop in stops.take(18)) {
        if (highlightIds.contains(stop.id)) continue;
        markers.add(
          GoogleMap3DMarkerData(
            id: 'stop_${stop.id}',
            position: stop.position,
            label: stop.name,
            isWheelchairAccessible: stop.isStepFree,
            color: theme.colorScheme.primary.withValues(alpha: 0.72),
          ),
        );
      }
    }

    return (polylines, markers);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(a11ySettingsProvider);
    final isSl = settings.localeCode == 'sl';

    final linesAsync = ref.watch(allLinesProvider);
    final stopsAsync = ref.watch(allStopsProvider);
    final locationAsync = ref.watch(userLocationProvider);
    final gpsNotifier = ref.watch(liveGpsPositionNotifierProvider);

    final lines = linesAsync.valueOrNull ?? const <BusLine>[];
    final linesById = {for (final l in lines) l.id: l};
    final stops = stopsAsync.valueOrNull ?? const <BusStop>[];
    final stopsById = {for (final s in stops) s.id: s};
    final locState = locationAsync.valueOrNull;

    final isWideDesktop = MediaQuery.sizeOf(context).width >= 900;

    return ValueListenableBuilder<LatLng?>(
      valueListenable: gpsNotifier,
      builder: (context, liveGps, _) {
        final effectivePos =
            liveGps ?? locState?.effectivePosition ?? GeoUtils.mariborCenter;
        final nearestStops = locState?.nearestStops ??
            LocationService.computeNearestStops(
              effectivePos,
              stops,
              accessibleOnly: settings.wheelchairAccessibleOnly,
            );

        final (polylines, markers) = _buildMapOverlay(
          theme: theme,
          linesById: linesById,
          stops: stops,
          userPos: effectivePos,
          nearestStops: nearestStops,
        );

        final fitSig = _selectedOption != null
            ? 'route_${_selectedOption!.id}_$_use3DView'
            : 'idle_${effectivePos.latitude.toStringAsFixed(3)}';

        final mapLayer = GoogleMap3DWidget(
          initialCenter: effectivePos,
          initialZoom: _selectedOption != null ? 14.2 : 14.8,
          polylines3D: polylines,
          markers3D: markers,
          initialUse3D: _use3DView,
          showStatusPill: false,
          fitBounds: _selectedOption != null,
          fitSignature: fitSig,
          onMarkerTap: (markerId) {
            if (markerId.startsWith('stop_')) {
              final stopId = markerId.substring('stop_'.length);
              final stop = stopsById[stopId];
              if (stop != null) {
                unawaited(_routeToStop(stop, locState));
              }
            }
          },
          onRecenter2D: () async {
            final fresh = await ref
                .read(locationServiceProvider)
                .tryGetCurrentPosition(requestPermission: true);
            if (fresh != null) {
              gpsNotifier.value = fresh;
              ref.invalidate(userLocationProvider);
            }
          },
          recenterLabel: isSl ? 'Moja lokacija' : 'My Location',
        );

        final controlsColumn = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AiTransitSearchPill(
              userLatLng: effectivePos,
              isManualMode: _manualMode,
              onToggleManualMode: () =>
                  setState(() => _manualMode = !_manualMode),
              onLoadingChanged: (busy) {
                if (mounted) setState(() => _loading = busy);
              },
              onError: (msg) {
                if (mounted) setState(() => _errorMessage = msg);
              },
              onResult: _handleAiResult,
            ),
            if (_manualMode) ...[
              const SizedBox(height: 8),
              _GlassOverlayCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SmartStationPairSelector(
                      stops: stops,
                      places: seedPlaces,
                      origin: _origin,
                      destination: _destination,
                      userPosition: effectivePos,
                      accessibleOnly: settings.wheelchairAccessibleOnly,
                      localeCode: settings.localeCode,
                      linesById: linesById,
                      onOriginChanged: (ep) {
                        setState(() => _origin = ep);
                        if (_destination != null) unawaited(_runRoutePlan());
                      },
                      onDestinationChanged: (ep) {
                        setState(() => _destination = ep);
                        if (_origin != null) unawaited(_runRoutePlan());
                      },
                      onSwap: _swapEndpoints,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed:
                            (_origin != null && _destination != null && !_loading)
                                ? () => unawaited(_runRoutePlan())
                                : null,
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.directions_bus_rounded),
                        label: Text(
                          isSl ? 'Poišči avtobus' : 'Find Bus Route',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    selected: settings.wheelchairAccessibleOnly,
                    avatar: const Icon(Icons.accessible_rounded, size: 18),
                    label: Text(
                      isSl ? 'Samo za invalide' : 'Wheelchair Only',
                    ),
                    onSelected: (val) async {
                      await ref
                          .read(a11ySettingsProvider.notifier)
                          .setWheelchairAccessibleOnly(val);
                      if (_origin != null && _destination != null) {
                        unawaited(_runRoutePlan());
                      }
                    },
                  ),
                  if (_selectedOption != null) ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _use3DView,
                      avatar: const Icon(Icons.threed_rotation_rounded, size: 18),
                      label: Text(isSl ? '3D pogled' : '3D Route'),
                      onSelected: (v) => setState(() => _use3DView = v),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.clear_rounded, size: 16),
                      label: Text(isSl ? 'Počisti pot' : 'Clear'),
                      onPressed: () {
                        setState(() {
                          _options = const [];
                          _selectedOption = null;
                          _errorMessage = null;
                          _isLateNightBanner = false;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Material(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_isLateNightBanner) ...[
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: _checkTomorrowMorning0600,
                          icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                          label: Text(
                            isSl
                                ? 'Preveri jutranji odhod ob 06:00'
                                : 'Check morning departures at 06:00',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        );

        final resultsListContent = _ResultsBody(
          isSl: isSl,
          loading: _loading,
          options: _options,
          selectedOption: _selectedOption,
          nearestStops: nearestStops,
          linesById: linesById,
          originLabel: _origin?.displayLabel(l10n) ?? (isSl ? 'Odhod' : 'Origin'),
          destinationLabel:
              _destination?.displayLabel(l10n) ?? (isSl ? 'Cilj' : 'Destination'),
          gpsActive: locState?.isGps ?? false,
          onSelectOption: (opt) => setState(() => _selectedOption = opt),
          onToggle3D: () => setState(() => _use3DView = true),
          onRouteToStop: (stop) => unawaited(_routeToStop(stop, locState)),
          onOpenStopDepartures: (stopId) => context.push('/stops/$stopId'),
        );

        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned.fill(child: mapLayer),
              if (isWideDesktop) ...[
                // Wide Web layout: left collapsible frosted search & results panel
                Positioned(
                  top: 14,
                  left: 14,
                  bottom: 14,
                  child: SafeArea(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_desktopPanelOpen)
                          SizedBox(
                            width: 400,
                            child: _GlassOverlayCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  controlsColumn,
                                  const Divider(height: 18),
                                  Expanded(child: resultsListContent),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        FloatingActionButton.small(
                          heroTag: 'toggle_go_panel',
                          tooltip: _desktopPanelOpen
                              ? (isSl ? 'Skrij stransko vrstico' : 'Collapse panel')
                              : (isSl ? 'Prikaži iskanje' : 'Expand search'),
                          onPressed: () => setState(
                            () => _desktopPanelOpen = !_desktopPanelOpen,
                          ),
                          child: Icon(
                            _desktopPanelOpen
                                ? Icons.chevron_left_rounded
                                : Icons.search_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Mobile layout: floating top search + thumb-friendly DraggableScrollableSheet
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    bottom: false,
                    child: controlsColumn,
                  ),
                ),
                DraggableScrollableSheet(
                  initialChildSize: _options.isNotEmpty ? 0.36 : 0.28,
                  minChildSize: 0.14,
                  maxChildSize: 0.84,
                  builder: (context, scrollController) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.96),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 18,
                            offset: Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _ResultsBody(
                                isSl: isSl,
                                loading: _loading,
                                options: _options,
                                selectedOption: _selectedOption,
                                nearestStops: nearestStops,
                                linesById: linesById,
                                originLabel: _origin?.displayLabel(l10n) ??
                                    (isSl ? 'Odhod' : 'Origin'),
                                destinationLabel:
                                    _destination?.displayLabel(l10n) ??
                                        (isSl ? 'Cilj' : 'Destination'),
                                gpsActive: locState?.isGps ?? false,
                                scrollController: scrollController,
                                onSelectOption: (opt) =>
                                    setState(() => _selectedOption = opt),
                                onToggle3D: () =>
                                    setState(() => _use3DView = true),
                                onRouteToStop: (stop) =>
                                    unawaited(_routeToStop(stop, locState)),
                                onOpenStopDepartures: (stopId) =>
                                    context.push('/stops/$stopId'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _GlassOverlayCard extends StatelessWidget {
  const _GlassOverlayCard({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.isSl,
    required this.loading,
    required this.options,
    required this.selectedOption,
    required this.nearestStops,
    required this.linesById,
    required this.originLabel,
    required this.destinationLabel,
    required this.gpsActive,
    required this.onSelectOption,
    required this.onToggle3D,
    required this.onRouteToStop,
    required this.onOpenStopDepartures,
    this.scrollController,
  });

  final bool isSl;
  final bool loading;
  final List<TripOption> options;
  final TripOption? selectedOption;
  final List<NearbyStopSummary> nearestStops;
  final Map<String, BusLine> linesById;
  final String originLabel;
  final String destinationLabel;
  final bool gpsActive;
  final ValueChanged<TripOption> onSelectOption;
  final VoidCallback onToggle3D;
  final ValueChanged<BusStop> onRouteToStop;
  final ValueChanged<String> onOpenStopDepartures;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (loading) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
          Text(
            isSl
                ? 'Računam realne Marprom poti prek Google Routes...'
                : 'Computing live Marprom routes via Google Routes...',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }

    if (options.isNotEmpty) {
      return ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final opt = options[index];
          return TripOptionCard(
            option: opt,
            index: index,
            isSelected: selectedOption?.id == opt.id,
            onSelect: () => onSelectOption(opt),
            linesById: linesById,
            originLabel: originLabel,
            destinationLabel: destinationLabel,
            onOpen3DRoute: () {
              onSelectOption(opt);
              onToggle3D();
            },
          );
        },
      );
    }

    // Idle view: Nearest Stops around user's GPS / reference position
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        Row(
          children: [
            Icon(
              gpsActive ? Icons.gps_fixed_rounded : Icons.near_me_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isSl ? 'Najbližja postajališča' : 'Nearest Stops Around You',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final ns in nearestStops.take(6)) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.directions_bus_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              title: Text(
                ns.stop.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${DistanceUtils.formatMeters(ns.distanceMeters, l10n)} • ~${ns.walkMinutes} min • ${ns.stop.lineIds.take(4).join(', ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: isSl ? 'Odhodi' : 'Departures',
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    onPressed: () => onOpenStopDepartures(ns.stop.id),
                    icon: const Icon(Icons.schedule_rounded),
                  ),
                  FilledButton.tonal(
                    onPressed: () => onRouteToStop(ns.stop),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(isSl ? 'Pot' : 'Go'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
