// Accessible multimodal Trip Planner screen with GPS fallback, map/list preview, and TTS.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/accessibility/favorites_provider.dart';
import 'package:m_mobilnost/core/accessibility/haptic_cues.dart';
import 'package:m_mobilnost/core/accessibility/semantics_helpers.dart';
import 'package:m_mobilnost/core/layout/breakpoints.dart';
import 'package:m_mobilnost/core/layout/responsive_builder.dart';
import 'package:m_mobilnost/core/maps/google_web_views.dart';
import 'package:m_mobilnost/core/network/google_routes_service.dart';
import 'package:m_mobilnost/core/theme/brand_tokens.dart';
import 'package:m_mobilnost/core/widgets/ui_kit.dart';
import 'package:m_mobilnost/core/utils/distance.dart';
import 'package:m_mobilnost/core/utils/time_format.dart';
import 'package:m_mobilnost/core/widgets/big_button.dart';
import 'package:m_mobilnost/core/widgets/state_views.dart';
import 'package:m_mobilnost/data/models/bus_line.dart';
import 'package:m_mobilnost/data/models/bus_stop.dart';
import 'package:m_mobilnost/data/models/trip_plan.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';

import '../domain/route_planner.dart';
import 'widgets/location_picker.dart';
import 'widgets/trip_endpoint.dart';
import 'widgets/trip_option_card.dart';
import 'widgets/trip_preview_and_steps.dart';

/// Trip Planner screen computing direct and 1-transfer Maribor bus routes.
class TripPlannerScreen extends ConsumerStatefulWidget {
  /// Creates a [TripPlannerScreen] with optional pre-populated endpoints.
  const TripPlannerScreen({
    super.key,
    this.initialFromStopId,
    this.initialToStopId,
    this.initialToName,
  });

  /// Optional origin stop ID supplied via deep link or stop screen.
  final String? initialFromStopId;

  /// Optional destination stop ID supplied via deep link or nearest-stop view.
  final String? initialToStopId;

  /// Optional destination place/stop name supplied via query parameter.
  final String? initialToName;

  @override
  ConsumerState<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends ConsumerState<TripPlannerScreen> {
  TripEndpoint? _fromEndpoint;
  TripEndpoint? _toEndpoint;
  TripTimeMode _timeMode = TripTimeMode.leaveNow;
  DateTime _targetTime = DateTime.now();
  bool _accessibleOnly = false;
  bool _fewerTransfers = false;
  double _maxWalkMeters = RoutePlanner.defaultMaxWalkMeters;

  bool _initializing = true;
  bool _searching = false;
  bool _hasSearched = false;
  bool _needsDestinationWarning = false;
  Object? _searchError;
  List<TripOption> _results = const [];
  GoogleRouteResult? _googleRouteSummary;
  int _selectedIndex = 0;

  Map<String, BusLine> _linesById = const {};
  Map<String, BusStop> _stopsById = const {};

  @override
  void initState() {
    super.initState();
    _initPlanner();
  }

  @override
  void didUpdateWidget(covariant TripPlannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFromStopId != widget.initialFromStopId ||
        oldWidget.initialToStopId != widget.initialToStopId ||
        oldWidget.initialToName != widget.initialToName) {
      _applyRouteOverrides();
    }
  }

  Future<void> _initPlanner() async {
    final lineRepo = ref.read(lineRepositoryProvider);
    final settings = ref.read(a11ySettingsProvider);
    final favorites = ref.read(favoritesProvider);

    final loaded = await Future.wait([
      lineRepo.getLines(),
      lineRepo.getStops(),
      resolveInitialOrigin(
        lineRepo: lineRepo,
        locationManualMode: settings.locationManualMode,
        manualStopId: favorites.manualStopId,
        initialFromStopId: widget.initialFromStopId,
      ),
      resolveInitialDestination(
        lineRepo: lineRepo,
        stopId: widget.initialToStopId,
        placeOrStopName: widget.initialToName,
      ),
    ]);

    if (!mounted) return;
    final lines = loaded[0] as List<BusLine>;
    final stops = loaded[1] as List<BusStop>;
    final (origin, _) = loaded[2] as (TripEndpoint, bool);
    final dest = loaded[3] as TripEndpoint?;

    setState(() {
      _linesById = {for (final l in lines) l.id: l};
      _stopsById = {for (final s in stops) s.id: s};
      _fromEndpoint = origin;
      _toEndpoint = dest;
      _initializing = false;
    });

    if (dest != null) {
      await _findRoutes();
    }
  }

  Future<void> _applyRouteOverrides() async {
    final lineRepo = ref.read(lineRepositoryProvider);
    var changed = false;

    if (widget.initialFromStopId != null &&
        widget.initialFromStopId!.isNotEmpty) {
      final stop = await lineRepo.getStopById(widget.initialFromStopId!);
      if (stop != null && mounted) {
        _fromEndpoint = TripEndpoint.stop(stop);
        changed = true;
      }
    }

    if ((widget.initialToStopId != null &&
            widget.initialToStopId!.isNotEmpty) ||
        (widget.initialToName != null && widget.initialToName!.isNotEmpty)) {
      final dest = await resolveInitialDestination(
        lineRepo: lineRepo,
        stopId: widget.initialToStopId,
        placeOrStopName: widget.initialToName,
      );
      if (dest != null && mounted) {
        _toEndpoint = dest;
        changed = true;
      }
    }

    if (changed && mounted) {
      setState(() {});
      if (_toEndpoint != null) {
        await _findRoutes();
      }
    }
  }

  Future<void> _pickOrigin() async {
    final l10n = context.l10n;
    final chosen = await showLocationSearchSheet(
      context: context,
      title: l10n.planSelectOrigin,
      allowCurrentLocation: true,
    );
    if (chosen != null && mounted) {
      setState(() {
        _fromEndpoint = chosen;
        _maxWalkMeters = RoutePlanner.defaultMaxWalkMeters;
      });
      if (_toEndpoint != null && _hasSearched) {
        await _findRoutes();
      }
    }
  }

  Future<void> _pickDestination({String initialQuery = ''}) async {
    final l10n = context.l10n;
    final chosen = await showLocationSearchSheet(
      context: context,
      title: l10n.planSelectDestination,
      allowCurrentLocation: false,
      initialQuery: initialQuery,
    );
    if (chosen != null && mounted) {
      setState(() {
        _toEndpoint = chosen;
        _needsDestinationWarning = false;
        _maxWalkMeters = RoutePlanner.defaultMaxWalkMeters;
      });
    }
  }

  void _swapEndpoints() {
    if (_fromEndpoint == null && _toEndpoint == null) return;
    final settings = ref.read(a11ySettingsProvider);
    HapticCues.trigger(
      HapticCueType.tap,
      enabled: settings.hapticAlertsEnabled,
    );
    setState(() {
      final prevFrom = _fromEndpoint;
      _fromEndpoint = _toEndpoint;
      _toEndpoint = prevFrom;
      _needsDestinationWarning = _toEndpoint == null;
    });
    if (_fromEndpoint != null && _toEndpoint != null && _hasSearched) {
      _findRoutes();
    }
  }

  Future<void> _pickTargetTime() async {
    final initial = TimeOfDay.fromDateTime(_targetTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    final now = DateTime.now();
    setState(() {
      _targetTime = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _findRoutes() async {
    final settings = ref.read(a11ySettingsProvider);
    HapticCues.trigger(
      HapticCueType.tap,
      enabled: settings.hapticAlertsEnabled,
    );

    if (_toEndpoint == null) {
      setState(() => _needsDestinationWarning = true);
      await _pickDestination();
      if (_toEndpoint == null) return;
    }
    if (_fromEndpoint == null) return;

    setState(() {
      _searching = true;
      _searchError = null;
      _needsDestinationWarning = false;
    });

    try {
      final planner = ref.read(routePlannerProvider);
      final effectiveTarget =
          _timeMode == TripTimeMode.leaveNow ? null : _targetTime;
      final googleFuture = isFlutterTestEnvironment
          ? Future.value(
              GoogleRoutesService.buildOfflineFallback(
                origin: _fromEndpoint!.position,
                destination: _toEndpoint!.position,
              ),
            )
          : ref.read(googleRoutesServiceProvider).computeRouteByCoordinates(
                origin: _fromEndpoint!.position,
                destination: _toEndpoint!.position,
              );
      final options = await planner.planTrip(
        origin: _fromEndpoint!.position,
        destination: _toEndpoint!.position,
        originLabel: _fromEndpoint!.rawName,
        destinationLabel: _toEndpoint!.rawName,
        mode: _timeMode,
        targetTime: effectiveTarget,
        accessibleOnly: _accessibleOnly,
        fewerTransfers: _fewerTransfers,
        maxWalkMeters: _maxWalkMeters,
      );
      final googleSummary = await googleFuture;
      if (!mounted) return;
      setState(() {
        _results = options;
        _googleRouteSummary = googleSummary;
        _selectedIndex = 0;
        _searching = false;
        _hasSearched = true;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _searchError = err;
        _searching = false;
        _hasSearched = true;
      });
    }
  }

  Future<void> _tryWalkFurther() async {
    setState(() {
      _maxWalkMeters = (_maxWalkMeters + 1000).clamp(1500, 3500);
    });
    await _findRoutes();
  }

  Future<void> _tryWaitNextDeparture() async {
    final planner = ref.read(routePlannerProvider);
    final base = _timeMode == TripTimeMode.leaveNow
        ? planner.currentTime()
        : _targetTime;
    setState(() {
      if (_timeMode == TripTimeMode.leaveNow) {
        _timeMode = TripTimeMode.departAt;
      }
      _targetTime = base.add(const Duration(minutes: 30));
    });
    await _findRoutes();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasParentScaffold = Scaffold.maybeOf(context) != null;

    if (_initializing) {
      final loading = const LoadingStateView();
      return hasParentScaffold
          ? loading
          : Scaffold(
              appBar: AppBar(title: Text(l10n.planTitle)),
              body: loading,
            );
    }

    final body = ResponsiveBuilder(
      builder: (context, layoutSize, _) {
        final isExpanded = layoutSize == ScreenLayoutSize.expanded ||
            LayoutBreakpoints.fromWidth(
                  MediaQuery.sizeOf(context).width,
                ) ==
                ScreenLayoutSize.expanded;
        if (isExpanded) {
          return _buildExpandedLayout(context);
        }
        return _buildStackedLayout(context, layoutSize);
      },
    );

    if (hasParentScaffold) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.planTitle)),
      body: body,
    );
  }

  Widget _buildExpandedLayout(BuildContext context) {
    final l10n = context.l10n;
    final planner = ref.watch(routePlannerProvider);
    final selectedOption =
        (_results.isNotEmpty && _selectedIndex < _results.length)
            ? _results[_selectedIndex]
            : null;
    final originDisplay = _fromEndpoint?.displayLabel(l10n) ?? l10n.planCurrentLocation;
    final destDisplay = _toEndpoint?.displayLabel(l10n) ?? l10n.planDestinationLabel;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: ListView(
              children: [
                ScreenTitle(
                  title: l10n.planTitle,
                  eyebrow: 'Marprom',
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
                ),
                _buildControlsCard(context),
                const SizedBox(height: 16),
                _buildResultsList(context, originDisplay, destDisplay),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 6,
            child: selectedOption != null
                ? ListView(
                    children: [
                      TripPreviewAndSteps(
                        option: selectedOption,
                        planner: planner,
                        linesById: _linesById,
                        stopsById: _stopsById,
                        originLabel: originDisplay,
                        destinationLabel: destDisplay,
                      ),
                    ],
                  )
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyStateView(
                        icon: Icons.alt_route_rounded,
                        title: l10n.planWhatDoINextTitle,
                        subtitle: l10n.planSelectDestination,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedLayout(BuildContext context, ScreenLayoutSize size) {
    final l10n = context.l10n;
    final planner = ref.watch(routePlannerProvider);
    final selectedOption =
        (_results.isNotEmpty && _selectedIndex < _results.length)
            ? _results[_selectedIndex]
            : null;
    final originDisplay = _fromEndpoint?.displayLabel(l10n) ?? l10n.planCurrentLocation;
    final destDisplay = _toEndpoint?.displayLabel(l10n) ?? l10n.planDestinationLabel;

    return ListView(
      children: [
        ResponsiveContentContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenTitle(
                title: l10n.planTitle,
                eyebrow: 'Marprom',
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
              ),
              _buildControlsCard(context),
              const SizedBox(height: 16),
              _buildResultsList(context, originDisplay, destDisplay),
              if (selectedOption != null) ...[
                const SizedBox(height: 16),
                TripPreviewAndSteps(
                  option: selectedOption,
                  planner: planner,
                  linesById: _linesById,
                  stopsById: _stopsById,
                  originLabel: originDisplay,
                  destinationLabel: destDisplay,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlsCard(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      LocationPickerField(
                        label: l10n.planOriginLabel,
                        placeholder: l10n.planSelectOrigin,
                        leadingIcon: _fromEndpoint?.kind == TripEndpointKind.gps
                            ? Icons.my_location_rounded
                            : Icons.trip_origin_rounded,
                        value: _fromEndpoint,
                        onTap: _pickOrigin,
                      ),
                      const SizedBox(height: 10),
                      LocationPickerField(
                        label: l10n.planDestinationLabel,
                        placeholder: l10n.planSelectDestination,
                        leadingIcon: Icons.place_rounded,
                        value: _toEndpoint,
                        onTap: () => _pickDestination(),
                        onVoiceSelected: (query) =>
                            _pickDestination(initialQuery: query),
                        onClear: _toEndpoint == null
                            ? null
                            : () => setState(() {
                                  _toEndpoint = null;
                                  _results = const [];
                                  _hasSearched = false;
                                }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: l10n.a11ySwapStations,
                  child: IconButton.filledTonal(
                    icon: const Icon(Icons.swap_vert_rounded),
                    tooltip: l10n.planSwap,
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      minHeight: 56,
                    ),
                    onPressed: _swapEndpoints,
                  ),
                ),
              ],
            ),
            if (_needsDestinationWarning) ...[
              const SizedBox(height: 8),
              Text(
                l10n.planSelectDestination,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final modeButtons = [
                  for (final mode in TripTimeMode.values)
                    _TimeModeButton(
                      label: switch (mode) {
                        TripTimeMode.leaveNow => l10n.planLeaveNow,
                        TripTimeMode.departAt => l10n.planDepartAt,
                        TripTimeMode.arriveBy => l10n.planArriveBy,
                      },
                      selected: _timeMode == mode,
                      onTap: () {
                        setState(() {
                          _timeMode = mode;
                          if (mode != TripTimeMode.leaveNow && !_hasSearched) {
                            _targetTime = DateTime.now();
                          }
                        });
                      },
                    ),
                ];
                // Equal-width segmented control at normal text sizes; wraps
                // gracefully when the rider uses very large text.
                final fitsInRow =
                    MediaQuery.textScalerOf(context).scale(1.0) <= 1.3;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: MarpromBrand.of(context).subtleFill,
                    borderRadius: BorderRadius.circular(MarpromRadii.md + 4),
                  ),
                  child: fitsInRow
                      ? Row(
                          children: [
                            for (final b in modeButtons) Expanded(child: b),
                          ],
                        )
                      : Wrap(spacing: 4, runSpacing: 4, children: modeButtons),
                );
              },
            ),
            if (_timeMode != TripTimeMode.leaveNow) const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_timeMode != TripTimeMode.leaveNow)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: OutlinedButton.icon(
                      onPressed: _pickTargetTime,
                      icon: const Icon(Icons.access_time_rounded),
                      label: Text(TimeFormatUtils.formatTime24(_targetTime)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.planAccessibleOnly,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              secondary: const Icon(Icons.accessible_rounded),
              value: _accessibleOnly,
              onChanged: (val) {
                setState(() => _accessibleOnly = val);
                if (_toEndpoint != null && _hasSearched) {
                  _findRoutes();
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.planFewerTransfers,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              secondary: const Icon(Icons.transfer_within_a_station_rounded),
              value: _fewerTransfers,
              onChanged: (val) {
                setState(() => _fewerTransfers = val);
                if (_toEndpoint != null && _hasSearched) {
                  _findRoutes();
                }
              },
            ),
            const SizedBox(height: 12),
            BigButton(
              icon: Icons.search_rounded,
              label: l10n.planFindRoutes,
              expanded: true,
              loading: _searching,
              onPressed: _findRoutes,
            ),
          ],
        ),
    );
  }

  Widget _buildResultsList(
    BuildContext context,
    String originDisplay,
    String destDisplay,
  ) {
    final l10n = context.l10n;
    if (_searching) {
      return const LoadingStateView();
    }
    if (_searchError != null) {
      return ErrorStateView(onRetry: _findRoutes);
    }
    if (!_hasSearched) {
      return const SizedBox.shrink();
    }
    if (_results.isEmpty) {
      return SurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconWell(icon: Icons.directions_bus_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.planNoResultsTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.planNoResultsBody,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  BigButton(
                    icon: Icons.directions_walk_rounded,
                    label: '${l10n.planTryWalkFurther} '
                        '(${DistanceUtils.formatMeters(_maxWalkMeters + 1000, l10n)})',
                    variant: BigButtonVariant.secondary,
                    onPressed: _tryWalkFurther,
                  ),
                  BigButton(
                    icon: Icons.schedule_rounded,
                    label: l10n.planTryWaitNext,
                    variant: BigButtonVariant.outlined,
                    onPressed: _tryWaitNextDeparture,
                  ),
                ],
              ),
            ],
          ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_googleRouteSummary != null) ...[
          Card(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.45),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.route_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Google Routes API: ${_googleRouteSummary!.formattedDistanceKm} • ${_googleRouteSummary!.formattedDurationMinutes}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < _results.length; i++) ...[
          TripOptionCard(
            option: _results[i],
            index: i,
            isSelected: i == _selectedIndex,
            onSelect: () => setState(() => _selectedIndex = i),
            linesById: _linesById,
            originLabel: originDisplay,
            destinationLabel: destDisplay,
          ),
          if (i < _results.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TimeModeButton extends StatelessWidget {
  const _TimeModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = MarpromBrand.of(context);
    final hc = isHighContrastTheme(context);
    final isDark = scheme.brightness == Brightness.dark;
    // Segmented-control look: the selected option is a raised pill.
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? (hc
                  ? scheme.primary
                  : isDark
                      ? scheme.primaryContainer
                      : scheme.surface)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(MarpromRadii.md),
          boxShadow: selected && !hc && !isDark ? brand.cardShadow : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(MarpromRadii.md),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56, minWidth: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected
                          ? (hc
                              ? scheme.onPrimary
                              : isDark
                                  ? scheme.onPrimaryContainer
                                  : scheme.primary)
                          : scheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
