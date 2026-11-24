// Calm personalized Home dashboard answering where am I, what is next, and what to do.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/accessibility/a11y_settings.dart';
import '../../../core/accessibility/favorites_provider.dart';
import '../../../core/accessibility/read_aloud.dart';
import '../../../core/accessibility/semantics_helpers.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/layout/responsive_builder.dart';
import '../../../core/maps/google_web_views.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/distance.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/occupancy_strip.dart';
import '../../../core/widgets/simulated_data_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../data/models/bus_position.dart';
import '../../../data/models/departure.dart';
import '../../../data/models/service_notice.dart';
import '../../../data/models/ticket.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/seed/seed_lines.dart';
import '../../../l10n/app_localizations.dart';
import '../../live_tracker/domain/fleet_statistics_provider.dart';
import '../domain/home_dashboard_provider.dart';
import 'ask_marprom_sheet.dart';

/// Primary Home screen providing calm next-bus, notice, ticket, and action cards.
class HomeScreen extends ConsumerWidget {
  /// Creates the personalized [HomeScreen] hosted inside the app shell.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(a11ySettingsProvider);
    final favorites = ref.watch(favoritesProvider);
    final dashboardAsync = ref.watch(homeDashboardProvider);
    final noticesAsync = ref.watch(serviceNoticesStreamProvider);
    final ticketsAsync = ref.watch(homeUserTicketsProvider);

    // Keep showing the previous dashboard while it reloads, so the screen
    // never flashes a spinner and replays its entrance animation.
    return dashboardAsync.when(
      skipLoadingOnReload: true,
      loading: () => const LoadingStateView(),
      error: (_, _) => ErrorStateView(
        onRetry: () => ref.invalidate(homeDashboardProvider),
      ),
      data: (dashboard) {
        final favoriteNotice = _findFavoriteNotice(
          notices: noticesAsync.valueOrNull ?? const <ServiceNotice>[],
          favorites: favorites,
        );
        final activeTicket = _findActiveTicket(
          ticketsAsync.valueOrNull ?? const <Ticket>[],
        );

        return RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(homeDashboardProvider);
            await ref.read(homeDashboardProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              ResponsiveContentContainer(
                child: ResponsiveBuilder(
                  builder: (context, layoutSize, _) {
                    var i = 0;
                    Widget enter(Widget child) =>
                        FadeSlideIn.staggered(index: i++, child: child);

                    final primaryCards = <Widget>[
                      enter(_GreetingAndLocationHeader(dashboard: dashboard)),
                      const SizedBox(height: 18),
                      if (favoriteNotice != null) ...[
                        enter(
                          _FavoriteNoticeAlertCard(
                            notice: favoriteNotice,
                            localeCode: settings.localeCode,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      enter(
                        _NextBusSummaryCard(
                          dashboard: dashboard,
                          settings: settings,
                          onRefresh: () =>
                              ref.invalidate(homeDashboardProvider),
                        ),
                      ),
                      if (activeTicket != null) ...[
                        const SizedBox(height: 14),
                        enter(
                          _ActiveTicketCard(
                            ticket: activeTicket,
                            localeCode: settings.localeCode,
                          ),
                        ),
                      ],
                    ];

                    final secondaryCards = <Widget>[
                      enter(_QuickActionsSection(l10n: l10n)),
                      const SizedBox(height: 26),
                      enter(
                        _FavoritesSection(dashboard: dashboard, l10n: l10n),
                      ),
                      const SizedBox(height: 26),
                      enter(_AskMarpromCard(dashboard: dashboard, l10n: l10n)),
                    ];

                    final isExpanded = layoutSize == ScreenLayoutSize.expanded ||
                        LayoutBreakpoints.fromWidth(
                              MediaQuery.sizeOf(context).width,
                            ) ==
                            ScreenLayoutSize.expanded;
                    if (isExpanded) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: primaryCards,
                            ),
                          ),
                          const SizedBox(width: 28),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: secondaryCards,
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...primaryCards,
                        const SizedBox(height: 26),
                        ...secondaryCards,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  ServiceNotice? _findFavoriteNotice({
    required List<ServiceNotice> notices,
    required FavoritesState favorites,
  }) {
    if (favorites.lineIds.isEmpty && favorites.stopIds.isEmpty) return null;
    final normalizedFavLineIds = {
      for (final id in favorites.lineIds) seedLinesById[id]?.id ?? id,
    };
    final now = DateTime.now();
    for (final notice in notices) {
      if (!notice.isActiveAt(now)) continue;
      final hitsLine =
          notice.affectedLineIds.any(normalizedFavLineIds.contains);
      final hitsStop =
          notice.affectedStopIds.any(favorites.stopIds.contains);
      if (hitsLine || hitsStop) return notice;
    }
    return null;
  }

  Ticket? _findActiveTicket(List<Ticket> tickets) {
    final now = DateTime.now();
    for (final ticket in tickets) {
      if (ticket.statusAt(now) == TicketStatus.active) {
        return ticket;
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------

/// Small uppercase section label with an optional trailing action.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 12),
      child: Text(
        title,
        style: theme.textTheme.titleLarge,
      ),
    );
  }
}

/// Rounded square that holds an icon on a soft tinted background.
class _IconWell extends StatelessWidget {
  const _IconWell({
    required this.icon,
    this.size = 44,
    this.tinted = true,
  });

  final IconData icon;
  final double size;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = MarpromBrand.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tinted ? scheme.primaryContainer : brand.subtleFill,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.5,
        color: tinted ? scheme.primary : scheme.onSurface,
      ),
    );
  }
}

/// White surface card with the brand's soft shadow and an ink ripple.
class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    return onTap == null ? card : PressableScale(child: card);
  }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

class _FavoriteNoticeAlertCard extends StatelessWidget {
  const _FavoriteNoticeAlertCard({
    required this.notice,
    required this.localeCode,
  });

  final ServiceNotice notice;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final statusColors = theme.extension<MarpromStatusColors>() ??
        MarpromStatusColors.light;
    final isDisruption = notice.severity == NoticeSeverity.disruption;
    final chipType = switch (notice.severity) {
      NoticeSeverity.disruption => TransitStatusType.disruption,
      NoticeSeverity.delay => TransitStatusType.late,
      NoticeSeverity.info => TransitStatusType.info,
    };
    final accent =
        isDisruption ? statusColors.disruptionFg : statusColors.warningFg;
    final bg = isDisruption ? statusColors.disruptionBg : statusColors.warningBg;

    return AccessibleSection(
      liveRegion: true,
      label: l10n.homeActiveDisruptionAlert,
      child: PressableScale(
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(MarpromRadii.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/notices'),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accent, width: 4)),
              ),
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusChip(type: chipType, compact: true),
                        const SizedBox(height: 8),
                        Text(
                          l10n.homeActiveDisruptionAlert,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notice.localizedTitle(localeCode),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GreetingAndLocationHeader extends ConsumerWidget {
  const _GreetingAndLocationHeader({required this.dashboard});

  final HomeDashboardData dashboard;

  /// Localized "Tuesday, 24 November"; empty if the locale has no date data.
  static String _todayLabel(BuildContext context) {
    try {
      return DateFormat.MMMMEEEEd(Localizations.localeOf(context).toString())
          .format(DateTime.now());
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = MarpromBrand.of(context);
    final stats = ref.watch(fleetStatisticsProvider);
    final stop = dashboard.primaryStop;
    final dist = DistanceUtils.formatMeters(
      dashboard.distanceToPrimaryStopMeters.toDouble(),
      l10n,
    );

    return AccessibleSection(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          // Fleet pulse: a quiet one-line status rather than a loud banner.
          Material(
            color: brand.subtleFill,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/live'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: MarpromStatusColors.light.onTimeFg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: MarpromStatusColors.light.onTimeFg
                                .withValues(alpha: 0.35),
                            blurRadius: 0,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Marprom Maribor • ${stats.activeBusCount} busov • ${stats.totalPassengers} potnikov (${stats.onTimePercent}% točno)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_todayLabel(context).isNotEmpty) ...[
            Text(
              _todayLabel(context).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            l10n.homeGreeting,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          PressableScale(
            child: Material(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(MarpromRadii.md),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push('/nearest-stop'),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MarpromRadii.md),
                    border: Border.all(color: brand.hairline),
                  ),
                  child: Row(
                    children: [
                      _IconWell(
                        icon: dashboard.usingManualLocation
                            ? Icons.pin_drop_outlined
                            : Icons.my_location_rounded,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${stop.name} • ${l10n.nearestStopDistance(dist)}',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextBusSummaryCard extends ConsumerWidget {
  const _NextBusSummaryCard({
    required this.dashboard,
    required this.settings,
    required this.onRefresh,
  });

  final HomeDashboardData dashboard;
  final A11ySettings settings;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = MarpromBrand.of(context);
    final dep = dashboard.nextDeparture;
    final hms = DateFormat('HH:mm:ss').format(dashboard.fetchedAt);

    if (dep == null) {
      return _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _IconWell(icon: Icons.directions_bus_outlined),
            const SizedBox(height: 12),
            Text(
              l10n.stopNoDepartures,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 14),
            BigButton(
              icon: Icons.refresh_rounded,
              label: l10n.commonRefresh,
              variant: BigButtonVariant.outlined,
              onPressed: onRefresh,
            ),
          ],
        ),
      );
    }

    final mins = dep.estimatedTime
        .difference(dashboard.fetchedAt)
        .inMinutes
        .clamp(0, 999);
    final summary = l10n.homeNextBusSummary(
      dep.directionName,
      dep.lineCode,
      mins,
      dashboard.distanceToPrimaryStopMeters,
    );

    final statusLabel = _departureStatusLabel(dep, l10n);
    final liveBuses = isFlutterTestEnvironment
        ? ref.read(busSimulatorProvider).snapshotAt(dashboard.fetchedAt)
        : (ref.watch(liveBusesStreamProvider).valueOrNull ??
            const <BusPosition>[]);
    BusPosition? matchingLiveBus;
    for (final bus in liveBuses) {
      if (bus.lineId == dep.lineId && bus.directionId == dep.directionId) {
        matchingLiveBus = bus;
        break;
      }
    }

    final isHighContrast = theme.extension<MarpromStatusColors>()
            ?.highContrastBorders ??
        false;

    final hero = Container(
      decoration: BoxDecoration(gradient: brand.heroGradient),
      child: Stack(
        children: [
          // Soft decorative glow, kept very faint so the red stays rich, not loud.
          Positioned(
            right: -60,
            top: -70,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: isHighContrast ? 0 : 0.05,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 8, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeroLineBadge(code: dep.lineCode),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.homeNextDepartures.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: brand.onHeroMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dep.directionName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: brand.onHero,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      color: brand.onHero,
                      tooltip: l10n.commonRefresh,
                      constraints:
                          const BoxConstraints(minWidth: 56, minHeight: 56),
                      onPressed: onRefresh,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Wrap (not Row) so 200% text scaling moves the time below
                // the countdown instead of overflowing.
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _AnimatedMinutes(minutes: mins, color: brand.onHero),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Text(
                            'min',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: brand.onHeroMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, right: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            TimeFormatUtils.formatTime24(dep.estimatedTime),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: brand.onHero,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            dashboard.primaryStop.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: brand.onHeroMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final details = Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(type: dep.status, label: statusLabel),
              SimulatedDataBadge(freshness: dep.freshness),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          OccupancyStrip(level: dep.occupancy),
          if (matchingLiveBus != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.directions_bus_filled_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${matchingLiveBus.vehicleId} (${matchingLiveBus.vehicleModel}) • '
                    '${matchingLiveBus.passengerCount}/${matchingLiveBus.vehicleCapacity} potnikov (${matchingLiveBus.loadPercent}%)',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (!settings.useSimulatedLive) ...[
            Text(
              l10n.freshnessLiveDisabledFallback,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
          ],
          Text(
            l10n.commonLastUpdatedAt(hms),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          BigButton(
            icon: Icons.volume_up_rounded,
            label: l10n.a11yReadAloudButton,
            variant: BigButtonVariant.outlined,
            expanded: true,
            onPressed: () {
              ref.read(readAloudProvider).speak(
                    summary,
                    enabled: true,
                    localeCode: settings.localeCode,
                  );
              announceForAccessibility(context, summary);
            },
          ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MarpromRadii.xl),
        boxShadow: brand.raisedShadow,
      ),
      child: Material(
        color: scheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarpromRadii.xl),
          side: isHighContrast
              ? BorderSide(color: scheme.outline, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () => context.push(
            '/tracker?lineId=${dep.lineId}&stopId=${dep.stopId}',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [hero, details],
          ),
        ),
      ),
    );
  }

  String _departureStatusLabel(Departure dep, AppLocalizations l10n) {
    if (dep.isCancelled) return l10n.statusCancelled;
    if (dep.delaySeconds < -60) {
      return l10n.statusEarlyByMinutes((-dep.delaySeconds / 60).round());
    }
    if (dep.delaySeconds > 120) {
      return l10n.statusLateByMinutes((dep.delaySeconds / 60).round());
    }
    return l10n.statusOnTime;
  }
}

/// White line-number tile that sits on the red hero surface.
class _HeroLineBadge extends StatelessWidget {
  const _HeroLineBadge({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: l10n.a11yLineBadge(code),
      child: Container(
        constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          code,
          style: const TextStyle(
            color: MarpromColors.marpromRed,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Large countdown number that rolls smoothly when the value changes.
class _AnimatedMinutes extends StatelessWidget {
  const _AnimatedMinutes({required this.minutes, required this.color});

  final int minutes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color,
      fontSize: 56,
      height: 1,
      fontWeight: FontWeight.w800,
      letterSpacing: -2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ExcludeSemantics(
      child: AnimatedSwitcher(
        duration: motionDisabled(context)
            ? Duration.zero
            : const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Text('$minutes', key: ValueKey(minutes), style: style),
      ),
    );
  }
}

class _ActiveTicketCard extends StatelessWidget {
  const _ActiveTicketCard({
    required this.ticket,
    required this.localeCode,
  });

  final Ticket ticket;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColors = theme.extension<MarpromStatusColors>() ??
        MarpromStatusColors.light;
    final remaining = ticket.validUntil.difference(DateTime.now());
    final remainingLabel = remaining.inHours >= 1
        ? l10n.commonHoursShort(remaining.inHours)
        : l10n.commonMinutesShort(remaining.inMinutes.clamp(1, 59));

    return _SurfaceCard(
      onTap: () => context.push('/tickets/view/${ticket.id}'),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.inverseSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.qr_code_2_rounded,
              size: 30,
              color: scheme.onInverseSurface,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColors.onTimeFg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.homeActiveTicket,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: statusColors.onTimeFg,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  ticket.localizedTitle(localeCode),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.ticketsValidUntil(TimeFormatUtils.formatTime24(ticket.validUntil))} • ${l10n.ticketsRemainingTime(remainingLabel)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.alt_route_rounded,
        label: l10n.homePlanTripAction,
        onTap: () => context.go('/plan'),
        highlighted: true,
      ),
      _QuickAction(
        icon: Icons.confirmation_number_outlined,
        label: l10n.homeBuyTicketAction,
        onTap: () => context.go('/tickets/shop'),
      ),
      _QuickAction(
        icon: Icons.my_location_rounded,
        label: l10n.homeNearestStopAction,
        onTap: () => context.push('/nearest-stop'),
      ),
      _QuickAction(
        icon: Icons.map_outlined,
        label: l10n.navMap,
        onTap: () => context.go('/map'),
      ),
      _QuickAction(
        icon: Icons.directions_bus_rounded,
        label: l10n.homeLinesAction,
        onTap: () => context.push('/lines'),
      ),
      _QuickAction(
        icon: Icons.school_outlined,
        label: l10n.homeGuideAction,
        onTap: () => context.push('/guide'),
      ),
    ];

    return AccessibleSection(
      header: true,
      label: l10n.homeQuickActions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: l10n.homeQuickActions),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 3 : 2;
              const gap = 12.0;
              final tileWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final action in actions)
                    SizedBox(
                      width: tileWidth,
                      child: _QuickActionTile(action: action),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = MarpromBrand.of(context);
    final highlighted = action.highlighted;
    final isHighContrast =
        theme.extension<MarpromStatusColors>()?.highContrastBorders ?? false;

    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: PressableScale(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MarpromRadii.lg),
            boxShadow: highlighted ? brand.raisedShadow : brand.cardShadow,
          ),
          child: Material(
            color: highlighted && !isHighContrast
                ? Colors.transparent
                : scheme.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MarpromRadii.lg),
              side: isHighContrast
                  ? BorderSide(color: scheme.outline, width: 2)
                  : BorderSide.none,
            ),
            child: Ink(
              decoration: highlighted && !isHighContrast
                  ? BoxDecoration(gradient: brand.heroGradient)
                  : null,
              child: InkWell(
                onTap: action.onTap,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 112),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (highlighted && !isHighContrast)
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          alignment: Alignment.center,
                          child: Icon(action.icon, color: Colors.white),
                        )
                      else
                        _IconWell(icon: action.icon, size: 42),
                      const SizedBox(height: 14),
                      Text(
                        action.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: highlighted && !isHighContrast
                              ? Colors.white
                              : scheme.onSurface,
                          height: 1.25,
                        ),
                      ),
                    ],
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

class _FavoritesSection extends StatelessWidget {
  const _FavoritesSection({
    required this.dashboard,
    required this.l10n,
  });

  final HomeDashboardData dashboard;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = MarpromBrand.of(context);

    return AccessibleSection(
      header: true,
      label: l10n.homeFavoriteStops,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: l10n.homeFavoriteStops),
          if (dashboard.favoriteStops.isEmpty &&
              dashboard.favoriteLines.isEmpty)
            _SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _IconWell(icon: Icons.star_outline_rounded),
                  const SizedBox(height: 12),
                  Text(
                    l10n.homeNoFavoriteStops,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      BigButton(
                        icon: Icons.directions_bus_rounded,
                        label: l10n.navLines,
                        variant: BigButtonVariant.outlined,
                        onPressed: () => context.push('/lines'),
                      ),
                      BigButton(
                        icon: Icons.map_outlined,
                        label: l10n.navMap,
                        variant: BigButtonVariant.outlined,
                        onPressed: () => context.go('/map'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else ...[
            if (dashboard.favoriteLines.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final line in dashboard.favoriteLines)
                    BigButton(
                      icon: Icons.directions_bus_rounded,
                      label: l10n.linesBadge(line.code),
                      variant: BigButtonVariant.outlined,
                      onPressed: () => context.push('/lines/${line.id}'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            for (final preview in dashboard.favoriteStops) ...[
              _SurfaceCard(
                onTap: () => context.push('/stops/${preview.stop.id}'),
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _IconWell(
                          icon: Icons.signpost_outlined,
                          size: 36,
                          tinted: false,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            preview.stop.name,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (preview.departures.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          l10n.stopNoDepartures,
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    else
                      for (final (idx, dep)
                          in preview.departures.take(3).indexed) ...[
                        if (idx > 0) Divider(color: brand.hairline),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${l10n.linesBadge(dep.lineCode)} • ${dep.directionName}',
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                    const SizedBox(height: 5),
                                    StatusChip(
                                      type: dep.status,
                                      compact: true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                TimeFormatUtils.formatTime24(
                                  dep.estimatedTime,
                                ),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _AskMarpromCard extends StatelessWidget {
  const _AskMarpromCard({
    required this.dashboard,
    required this.l10n,
  });

  final HomeDashboardData dashboard;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = MarpromBrand.of(context);
    final samples = [
      l10n.askSample1,
      l10n.askSample2,
      l10n.askSample3,
      l10n.askSample4,
    ];

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconWell(icon: Icons.auto_awesome_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.askTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.askSubtitle,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sample in samples)
                PressableScale(
                  child: Material(
                    color: brand.subtleFill,
                    borderRadius: BorderRadius.circular(MarpromRadii.md),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => showAskMarpromSheet(
                        context,
                        initialQuery: sample,
                        userPosition: dashboard.userPosition,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.north_east_rounded,
                                size: 16,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  sample,
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          BigButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: l10n.homeAskMarpromAction,
            variant: BigButtonVariant.secondary,
            expanded: true,
            onPressed: () => showAskMarpromSheet(
              context,
              userPosition: dashboard.userPosition,
            ),
          ),
        ],
      ),
    );
  }
}
