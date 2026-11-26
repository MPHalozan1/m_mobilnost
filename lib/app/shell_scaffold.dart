//**********************************************
// Unified 4-Tab Responsive Navigation Shell   *
//**********************************************

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/a11y_settings.dart';
import '../core/accessibility/semantics_helpers.dart';
import '../core/config/download_links.dart';
import '../core/layout/breakpoints.dart';
import '../core/maps/google_web_views.dart';
import '../core/theme/colors.dart';
import '../core/widgets/brand_logo.dart';
import '../core/widgets/offline_banner.dart';
import '../core/widgets/simulated_data_badge.dart';

//**********************************************
// ShellScaffold (Web NavigationRail + Mobile) *
//**********************************************

// Unified 4-destination navigation shell shared across Web and Android:
// 0: Go / Map (`/`)
// 1: All Buses (`/buses`)
// 2: Vozovnica (`/tickets`)
// 3: Profile & Settings (`/profile`)
class ShellScaffold extends ConsumerWidget {
  // Creates a [ShellScaffold] wrapping [navigationShell].
  const ShellScaffold({
    super.key,
    required this.navigationShell,
  });

  // Active GoRouter stateful navigation shell.
  final StatefulNavigationShell navigationShell;

  void _onSelectBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(a11ySettingsProvider);
    final settingsNotifier = ref.read(a11ySettingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final isSl = settings.localeCode == 'sl';

    final viewportWidth = MediaQuery.sizeOf(context).width;
    final useRail = !LayoutBreakpoints.isCompact(viewportWidth);
    final extendRail = LayoutBreakpoints.isExpanded(viewportWidth);

    final destinations = <(IconData, IconData, String, String)>[
      (
        Icons.explore_outlined,
        Icons.explore_rounded,
        isSl ? 'Zemljevid' : 'Go / Map',
        isSl ? 'Odpri interaktivni zemljevid in AI iskalnik' : 'Go / Map tab',
      ),
      (
        Icons.directions_bus_outlined,
        Icons.directions_bus_rounded,
        isSl ? 'Avtobusi' : 'All Buses',
        isSl ? 'Pregled vseh Marprom avtobusov v živo' : 'All Buses tab',
      ),
      (
        Icons.confirmation_number_outlined,
        Icons.confirmation_number_rounded,
        l10n.navTickets,
        l10n.navTickets,
      ),
      (
        Icons.person_outline_rounded,
        Icons.person_rounded,
        isSl ? 'Profil' : 'Profile',
        isSl ? 'Profil, prijava in nastavitve' : 'Profile & Settings tab',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: useRail ? 58 : 54,
        titleSpacing: 12,
        title: Semantics(
          button: true,
          label: 'M-Mobilnost Marprom',
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.push('/welcome'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: const Size.square(28),
                    painter: const MarpromLogoPainter(),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'M-Mobilnost',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (useRail)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilterChip(
                selected: settings.wheelchairAccessibleOnly,
                avatar: const Icon(Icons.accessible_rounded, size: 17),
                label: Text(isSl ? 'Samo za invalide' : 'Wheelchair'),
                onSelected: (v) =>
                    unawaited(settingsNotifier.setWheelchairAccessibleOnly(v)),
              ),
            )
          else
            IconButton(
              tooltip: isSl ? 'Samo za invalide' : 'Wheelchair Only',
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              onPressed: () => unawaited(
                settingsNotifier.setWheelchairAccessibleOnly(
                  !settings.wheelchairAccessibleOnly,
                ),
              ),
              icon: Icon(
                Icons.accessible_rounded,
                color: settings.wheelchairAccessibleOnly
                    ? MarpromColors.transitBlue
                    : null,
              ),
            ),
          IconButton(
            tooltip: l10n.navLines,
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            onPressed: () => context.push('/lines'),
            icon: const Icon(Icons.route_outlined),
          ),
          IconButton(
            tooltip: l10n.noticesTitle,
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            onPressed: () => context.push('/notices'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          if (useRail)
            IconButton(
              tooltip: isDark
                  ? (isSl ? 'Svetli način' : 'Light mode')
                  : (isSl ? 'Temni način' : 'Dark mode'),
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              onPressed: () => unawaited(
                settingsNotifier.setThemeMode(
                  isDark ? AppThemeChoice.light : AppThemeChoice.dark,
                ),
              ),
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              ),
            ),
          if (kIsWeb && useRail)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 12),
              child: FilledButton.tonalIcon(
                onPressed: () => unawaited(
                  launchUrl(
                    marpromAndroidApkUri,
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                icon: const Icon(Icons.android_rounded, size: 18),
                label: Text(isSl ? 'Android APK' : 'Get APK'),
              ),
            ),
        ],
      ),
      body: Row(
        children: [
          if (useRail) ...[
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onSelectBranch,
              extended: extendRail,
              minWidth: 80,
              minExtendedWidth: 210,
              labelType: extendRail
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: [
                for (final (_, activeIcon, label, semantics) in destinations)
                  NavigationRailDestination(
                    icon: Semantics(
                      label: semantics,
                      child: Icon(activeIcon),
                    ),
                    selectedIcon: Icon(activeIcon),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: Column(
              children: [
                if (settings.showDataSource) const _SourceStatusBar(),
                Expanded(
                  child: _BranchFade(
                    index: navigationShell.currentIndex,
                    child: navigationShell,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !useRail
          ? Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _onSelectBranch,
                height: 70,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  for (final (icon, activeIcon, label, _) in destinations)
                    NavigationDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(activeIcon),
                      label: label,
                    ),
                ],
              ),
            )
          : null,
    );
  }
}

class _BranchFade extends StatefulWidget {
  const _BranchFade({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_BranchFade> createState() => _BranchFadeState();
}

class _BranchFadeState extends State<_BranchFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _BranchFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !isFlutterTestEnvironment) {
      _controller.forward(from: 0.65);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced =
        MediaQuery.disableAnimationsOf(context) || isFlutterTestEnvironment;
    if (reduced) return widget.child;
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      child: widget.child,
    );
  }
}

class _SourceStatusBar extends StatelessWidget {
  const _SourceStatusBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OfflineBanner(),
          SizedBox(height: 4),
          SimulatedDataBadge(),
        ],
      ),
    );
  }
}
