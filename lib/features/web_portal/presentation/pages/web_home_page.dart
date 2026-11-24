// Marprom Maribor Web Portal landing & introduction page with Quick Planner & Live KPIs.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/accessibility/a11y_settings.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/bus_stop.dart';
import '../../../../data/models/service_notice.dart';
import '../../../../data/repositories/repository_providers.dart';
import '../../../../data/seed/seed_stops.dart';
import '../../../live_tracker/domain/fleet_statistics_provider.dart';
import '../marprom_web_strings.dart';

/// Marprom Web Portal Home Page (`/`) featuring company introduction,
/// embedded Quick Route Planner, live Maribor fleet KPIs, all 19 G/P lines,
/// service notices, and Mobile App download promo.
class WebHomePage extends ConsumerStatefulWidget {
  /// Creates the [WebHomePage].
  const WebHomePage({super.key});

  @override
  ConsumerState<WebHomePage> createState() => _WebHomePageState();
}

class _WebHomePageState extends ConsumerState<WebHomePage> {
  String _fromStopId = 'glavna_postaja';
  String _toStopId = 'vzpenjaca';
  int _lineGroupFilter = 0; // 0: All 19, 1: G1-G6, 2: P7-P19

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(a11ySettingsProvider);
    final stats = ref.watch(fleetStatisticsProvider);
    final noticesAsync = ref.watch(serviceNoticesStreamProvider);
    final ws = MarpromWebStrings.of(settings.localeCode);
    final notices = noticesAsync.valueOrNull ?? const <ServiceNotice>[];
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 980;
    final scheme = Theme.of(context).colorScheme;

    final filteredStats = stats.lineStats.where((item) {
      if (_lineGroupFilter == 1) return item.line.isMainTrunk;
      if (_lineGroupFilter == 2) return !item.line.isMainTrunk;
      return true;
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Marprom Editorial Hero + Quick Route Planner
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MarpromColors.marpromCharcoal,
                Color(0xFF280B14),
                MarpromColors.marpromBurgundy,
              ],
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 32 : 16,
            vertical: isWide ? 54 : 32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: isWide ? 6 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            ws.heroEyebrow,
                            style: const TextStyle(
                              color: Color(0xFFFFD6DC),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          ws.heroTitle,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isWide ? 44 : 30,
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          ws.heroSubtitle,
                          style: TextStyle(
                            color: const Color(0xFFE2E8F0),
                            fontSize: isWide ? 16 : 15,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: MarpromColors.marpromRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 16,
                                ),
                              ),
                              onPressed: () => context.go('/live'),
                              icon: const Icon(Icons.view_in_ar_rounded),
                              label: Text(
                                ws.open3DMapCta,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 16,
                                ),
                              ),
                              onPressed: () => context.go('/lines'),
                              icon: const Icon(Icons.schedule_rounded),
                              label: Text(
                                ws.navSchedules,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isWide ? 36 : 0, height: isWide ? 0 : 28),
                  Expanded(
                    flex: isWide ? 5 : 0,
                    child: _QuickPlannerHeroCard(
                      ws: ws,
                      fromStopId: _fromStopId,
                      toStopId: _toStopId,
                      onFromChanged: (val) =>
                          setState(() => _fromStopId = val),
                      onToChanged: (val) => setState(() => _toStopId = val),
                      onSwap: () => setState(() {
                        final tmp = _fromStopId;
                        _fromStopId = _toStopId;
                        _toStopId = tmp;
                      }),
                      onSubmit: () => context.go(
                        '/plan?fromStopId=${Uri.encodeComponent(_fromStopId)}'
                        '&toStopId=${Uri.encodeComponent(_toStopId)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. Live Maribor Transit KPI Strip
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 960
                      ? 4
                      : (constraints.maxWidth >= 560 ? 2 : 1);
                  final cardWidth =
                      (constraints.maxWidth - (16 * (cols - 1))) / cols;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _KpiCard(
                        width: cardWidth,
                        icon: Icons.directions_bus_rounded,
                        accent: MarpromColors.marpromRed,
                        label: ws.kpiActiveBuses,
                        value: '${stats.activeBusCount}',
                        subtitle:
                            '19 linij (G1–G6 & P7–P19) • ${TimeFormatUtils.formatTime24(stats.updatedAt)}',
                        onTap: () => context.go('/live'),
                      ),
                      _KpiCard(
                        width: cardWidth,
                        icon: Icons.groups_rounded,
                        accent: const Color(0xFF0057B8),
                        label: ws.kpiPassengersNow,
                        value: '${stats.totalPassengers}',
                        subtitle:
                            '${stats.averageLoadPercent}% zasedenosti (${stats.totalCapacity} mest)',
                        onTap: () => context.go('/live'),
                      ),
                      _KpiCard(
                        width: cardWidth,
                        icon: Icons.verified_rounded,
                        accent: MarpromColors.mobilityGreen,
                        label: ws.kpiOnTime,
                        value: '${stats.onTimePercent}%',
                        subtitle:
                            '${stats.onTimeCount + stats.earlyCount} točnih • ${stats.lateCount} z zamudo',
                        onTap: () => context.go('/live'),
                      ),
                      _KpiCard(
                        width: cardWidth,
                        icon: Icons.electric_bolt_rounded,
                        accent: const Color(0xFF6D28D9),
                        label: ws.kpiElectric,
                        value: '${stats.electricBusCount}',
                        subtitle:
                            '${stats.electricSharePercent}% aktivnega e-voznega parka',
                        onTap: () => context.go('/live'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),

        // 3. All 19 Marprom Lines Grid (G1–G6 & P7–P19)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ws.navSchedules,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Glavne linije G1–G6 ter povezovalne linije P7–P19 z živimi podatki o zasedenosti in številu potnikov',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(ws.allLines),
                            selected: _lineGroupFilter == 0,
                            onSelected: (_) =>
                                setState(() => _lineGroupFilter = 0),
                          ),
                          ChoiceChip(
                            label: Text(ws.mainLines),
                            selected: _lineGroupFilter == 1,
                            onSelected: (_) =>
                                setState(() => _lineGroupFilter = 1),
                          ),
                          ChoiceChip(
                            label: Text(ws.connectorLines),
                            selected: _lineGroupFilter == 2,
                            onSelected: (_) =>
                                setState(() => _lineGroupFilter = 2),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 1060
                          ? 3
                          : (constraints.maxWidth >= 680 ? 2 : 1);
                      final cardWidth =
                          (constraints.maxWidth - (16 * (cols - 1))) / cols;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final stat in filteredStats)
                            _WebLineCard(
                              width: cardWidth,
                              stat: stat,
                              passengersWord: ws.passengersWord,
                              onTap: () => context.go(
                                '/lines/${Uri.encodeComponent(stat.line.id)}',
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // 4. Marprom Pillars + Live Service Notices
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isWide ? 6 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zakaj potovati z Marpromom',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 14),
                        const _FeatureHighlightTile(
                          icon: Icons.electric_bolt_rounded,
                          color: Color(0xFF6D28D9),
                          title: 'Električna mobilnost v središču Maribora',
                          body:
                              'Liniji G5 (Rotovž) in G6 (Vzpenjača) ter osrednji odhodi na G1 in G2 obratujejo s sodobnimi baterijsko-električnimi avtobusi Iveco E-Way in MAN Lion\'s City 12E.',
                        ),
                        const SizedBox(height: 12),
                        const _FeatureHighlightTile(
                          icon: Icons.cable_rounded,
                          color: Color(0xFF15803D),
                          title: 'Hitra povezava do Pohorske vzpenjače',
                          body:
                              'Glavna linija G6 povezuje Glavno avtobusno in železniško postajo neposredno s spodnjo postajo Pohorske vzpenjače in kolesarskimi ter smučarskimi progami.',
                        ),
                        const SizedBox(height: 12),
                        const _FeatureHighlightTile(
                          icon: Icons.swap_horiz_rounded,
                          color: MarpromColors.marpromRed,
                          title: '75-minutno brezplačno prestopanje',
                          body:
                              'Enotna enkratna vozovnica omogoča neomejeno prestopanje med vsemi 19 linijami (G1–G6 in P7–P19) znotraj 75 minut od prve potrditve.',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isWide ? 28 : 0, height: isWide ? 0 : 28),
                  Expanded(
                    flex: isWide ? 5 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Prometna obvestila',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/notices'),
                              child: const Text('Vsa obvestila →'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (final notice in notices.take(3)) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        notice.severity ==
                                                NoticeSeverity.disruption
                                            ? Icons.warning_amber_rounded
                                            : Icons.info_outline_rounded,
                                        color: notice.severity ==
                                                NoticeSeverity.disruption
                                            ? MarpromColors.marpromRed
                                            : scheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          notice.localizedTitle(
                                            settings.localeCode,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    notice.localizedBody(settings.localeCode),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 5. Mobile App APK & iOS Promo Banner (Web-only)
        if (kIsWeb)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [
                      MarpromColors.marpromRed,
                      MarpromColors.marpromBurgundy,
                    ],
                  ),
                ),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const SizedBox(
                      width: 680,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'M Mobilnost v vašem žepu — Android APK & iOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Prenesite uradno mobilno aplikacijo M Mobilnost za Android (neposredni .apk prenos) ali iOS ter imejte QR vozovnice, 3D zemljevid Maribora in prihode avtobusov vedno pri roki.',
                            style: TextStyle(
                              color: Color(0xFFFFE4E6),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: MarpromColors.marpromRed,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                      ),
                      onPressed: () => context.go('/download'),
                      icon: const Icon(Icons.install_mobile_rounded),
                      label: Text(
                        ws.navDownload,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickPlannerHeroCard extends StatelessWidget {
  const _QuickPlannerHeroCard({
    required this.ws,
    required this.fromStopId,
    required this.toStopId,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onSwap,
    required this.onSubmit,
  });

  final MarpromWebStrings ws;
  final String fromStopId;
  final String toStopId;
  final ValueChanged<String> onFromChanged;
  final ValueChanged<String> onToChanged;
  final VoidCallback onSwap;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sortedStops = List<BusStop>.from(seedStops)
      ..sort((a, b) => a.name.compareTo(b.name));

    return Card(
      elevation: 10,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MarpromColors.marpromRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.alt_route_rounded,
                    color: MarpromColors.marpromRed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ws.quickPlannerTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Zamenjaj smer',
                  onPressed: onSwap,
                  icon: const Icon(Icons.swap_vert_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: fromStopId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: ws.fromLabel,
                prefixIcon: const Icon(Icons.my_location_rounded),
              ),
              items: [
                for (final stop in sortedStops)
                  DropdownMenuItem(
                    value: stop.id,
                    child: Text(stop.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (val) {
                if (val != null) onFromChanged(val);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: toStopId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: ws.toLabel,
                prefixIcon: const Icon(Icons.flag_rounded),
              ),
              items: [
                for (final stop in sortedStops)
                  DropdownMenuItem(
                    value: stop.id,
                    child: Text(stop.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (val) {
                if (val != null) onToChanged(val);
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: MarpromColors.marpromRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: onSubmit,
              icon: const Icon(Icons.directions_rounded),
              label: Text(
                ws.planRouteCta,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.width,
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: accent, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebLineCard extends StatelessWidget {
  const _WebLineCard({
    required this.width,
    required this.stat,
    required this.passengersWord,
    required this.onTap,
  });

  final double width;
  final FleetLineStat stat;
  final String passengersWord;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final line = stat.line;
    final scheme = Theme.of(context).colorScheme;
    final loadRatio = (stat.averageLoadPercent / 100.0).clamp(0.0, 1.0);
    final loadColor = stat.averageLoadPercent >= 75
        ? MarpromColors.marpromRed
        : (stat.averageLoadPercent >= 45
            ? const Color(0xFFD97706)
            : MarpromColors.mobilityGreen);

    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: line.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        line.code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        line.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (stat.electricBuses > 0)
                      const Tooltip(
                        message: 'Električni avtobus',
                        child: Icon(
                          Icons.electric_bolt_rounded,
                          size: 16,
                          color: Color(0xFF6D28D9),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '${stat.activeBuses} ${stat.activeBuses == 1 ? 'bus' : 'busi'} na trasi',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        stat.activeBuses > 0
                            ? '${stat.totalPassengers}/${stat.totalCapacity} $passengersWord (${stat.averageLoadPercent}%)'
                            : 'Izven konice',
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: loadColor,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: stat.activeBuses > 0 ? loadRatio : 0.08,
                    minHeight: 7,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: stat.activeBuses > 0 ? loadColor : scheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureHighlightTile extends StatelessWidget {
  const _FeatureHighlightTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
