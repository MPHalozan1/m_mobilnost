// Responsive navigation shell switching between NavigationBar and NavigationRail.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/accessibility/semantics_helpers.dart';
import '../core/layout/breakpoints.dart';
import '../core/theme/brand_tokens.dart';
import '../core/widgets/motion.dart';
import '../core/widgets/offline_banner.dart';
import '../core/widgets/simulated_data_badge.dart';
import '../features/web_portal/presentation/marprom_web_scaffold.dart';

/// Top-level adaptive scaffold hosting the 4 primary transit destinations.
class ShellScaffold extends StatelessWidget {
  /// Creates a [ShellScaffold] wrapping [navigationShell].
  const ShellScaffold({
    super.key,
    required this.navigationShell,
  });

  /// Active GoRouter stateful navigation shell.
  final StatefulNavigationShell navigationShell;

  void _onSelectBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = MarpromBrand.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final layoutSize = LayoutBreakpoints.fromWidth(width);
    final isCompact = layoutSize == ScreenLayoutSize.compact;
    final isExpanded = layoutSize == ScreenLayoutSize.expanded;

    final destinations = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, l10n.navHome),
      (Icons.map_outlined, Icons.map_rounded, l10n.navMap),
      (Icons.alt_route_outlined, Icons.alt_route_rounded, l10n.navPlan),
      (
        Icons.confirmation_number_outlined,
        Icons.confirmation_number_rounded,
        l10n.navTickets,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MarpromBrandEmblem(size: 34),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                l10n.appTitle,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          _ShellAction(
            semanticsLabel: l10n.a11yNoticesButton,
            tooltip: l10n.navNotices,
            icon: Icons.notifications_outlined,
            onPressed: () => context.push('/notices'),
          ),
          _ShellAction(
            semanticsLabel: l10n.a11yProfileButton,
            tooltip: l10n.navAccount,
            icon: Icons.person_outline_rounded,
            onPressed: () => context.push('/account'),
          ),
          _ShellAction(
            semanticsLabel: l10n.a11ySettingsButton,
            tooltip: l10n.navSettings,
            icon: Icons.settings_outlined,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Row(
        children: [
          if (!isCompact)
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onSelectBranch,
              extended: isExpanded,
              labelType: isExpanded
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: [
                for (final (icon, activeIcon, label) in destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(activeIcon),
                    label: Text(label),
                  ),
              ],
            ),
          if (!isCompact) VerticalDivider(width: 1, color: brand.hairline),
          Expanded(
            child: Column(
              children: [
                const OfflineBanner(),
                const _SourceStatusBar(),
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
      bottomNavigationBar: isCompact
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: brand.hairline)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: scheme.brightness == Brightness.dark ? 0.3 : 0.04,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _onSelectBranch,
                animationDuration: const Duration(milliseconds: 360),
                destinations: [
                  for (final (icon, activeIcon, label) in destinations)
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

class _ShellAction extends StatelessWidget {
  const _ShellAction({
    required this.semanticsLabel,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String semanticsLabel;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        onPressed: onPressed,
      ),
    );
  }
}

/// Cross-fades the tab body briefly whenever the selected branch changes.
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
    duration: const Duration(milliseconds: 240),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _BranchFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !motionDisabled(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.012),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}

class _SourceStatusBar extends StatelessWidget {
  const _SourceStatusBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SimulatedDataBadge(),
      ),
    );
  }
}
