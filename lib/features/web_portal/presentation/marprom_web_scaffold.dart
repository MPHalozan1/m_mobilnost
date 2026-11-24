// Responsive Marprom (Skupina JHMB Maribor) Web Portal navigation shell & footer.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/a11y_settings.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../account/providers/account_providers.dart';
import '../../live_tracker/domain/fleet_statistics_provider.dart';
import 'marprom_web_strings.dart';

/// Top-level corporate web shell rendering the JHMB utility strip, sticky Marprom
/// navbar (`SL | EN | DE | SR` switcher + theme toggle), page body, and footer.
class MarpromWebScaffold extends ConsumerWidget {
  /// Creates a [MarpromWebScaffold] wrapping [child] at [currentPath].
  const MarpromWebScaffold({
    super.key,
    required this.currentPath,
    required this.child,
  });

  /// Active GoRouter path used to highlight the matching navigation link.
  final String currentPath;

  /// Active page body rendered between navbar and corporate footer.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(a11ySettingsProvider);
    final stats = ref.watch(fleetStatisticsProvider);
    final ws = MarpromWebStrings.of(settings.localeCode);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1040;
    final scheme = Theme.of(context).colorScheme;

    final navItems = <({String path, String label, IconData icon})>[
      (path: '/', label: ws.navHome, icon: Icons.home_rounded),
      (path: '/lines', label: ws.navSchedules, icon: Icons.schedule_rounded),
      (path: '/plan', label: ws.navPlanner, icon: Icons.alt_route_rounded),
      (path: '/live', label: ws.navLiveStats, icon: Icons.insights_rounded),
      (
        path: '/tickets',
        label: ws.navTickets,
        icon: Icons.confirmation_number_rounded,
      ),
    ];

    return Scaffold(
      drawer: isWide
          ? null
          : _MobileWebDrawer(
              currentPath: currentPath,
              navItems: navItems,
              ws: ws,
            ),
      body: CustomScrollView(
        slivers: [
          // 1. Top Skupina JHMB corporate & language bar
          SliverToBoxAdapter(
            child: _CorporateUtilityBar(
              ws: ws,
              stats: stats,
              settings: settings,
            ),
          ),
          // 2. Sticky Marprom Main Navbar
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: !isWide,
            toolbarHeight: 74,
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
            surfaceTintColor: Colors.transparent,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            titleSpacing: isWide ? 32 : 8,
            title: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => context.go('/'),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const MarpromBrandEmblem(size: 40),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'MARPROM',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                        color: MarpromColors.marpromRed,
                                      ),
                                ),
                                Text(
                                  'M Mobilnost • Maribor',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isWide) ...[
                      const SizedBox(width: 24),
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final item in navItems)
                              _NavbarLink(
                                label: item.label,
                                selected: _isPathSelected(
                                  currentPath,
                                  item.path,
                                ),
                                onTap: () => context.go(item.path),
                              ),
                          ],
                        ),
                      ),
                      if (kIsWeb) ...[
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: MarpromColors.marpromRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => context.go('/download'),
                          icon: const Icon(Icons.download_for_offline_rounded),
                          label: Text(
                            ws.navDownload,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ] else if (kIsWeb) ...[
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: MarpromColors.marpromRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () => context.go('/download'),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('APK / iOS'),
                      ),
                    ] else
                      const Spacer(),
                  ],
                ),
              ),
            ),
          ),
          // 3. Offline alert if disconnected
          const SliverToBoxAdapter(child: OfflineBanner()),
          // 4. Page content
          SliverToBoxAdapter(
            child: child,
          ),
          // 5. Corporate Footer
          SliverToBoxAdapter(
            child: _MarpromWebFooter(ws: ws),
          ),
        ],
      ),
    );
  }

  bool _isPathSelected(String current, String target) {
    if (target == '/') return current == '/';
    return current == target || current.startsWith('$target/');
  }
}

/// Official stylized Marprom `M` emblem badge used across Web & Mobile headers.
class MarpromBrandEmblem extends StatelessWidget {
  /// Creates a [MarpromBrandEmblem].
  const MarpromBrandEmblem({super.key, this.size = 38});

  /// Square dimension of the emblem.
  final double size;

  @override
  Widget build(BuildContext context) {
    // Same mark as the launcher icon: a route "M" ending in a destination pin.
    return Semantics(
      image: true,
      label: 'M Mobilnost',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.27),
          boxShadow: [
            BoxShadow(
              color: MarpromColors.marpromRed.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: MarpromLogo(size: size),
      ),
    );
  }
}

class _CorporateUtilityBar extends ConsumerWidget {
  const _CorporateUtilityBar({
    required this.ws,
    required this.stats,
    required this.settings,
  });

  final MarpromWebStrings ws;
  final FleetStatistics stats;
  final A11ySettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(a11ySettingsProvider.notifier);
    final activeUser = ref.watch(activeUserProvider);

    return Container(
      color: MarpromColors.marpromCharcoal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_bus_filled_rounded,
                    color: Color(0xFFFF8A9B),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      ws.corporateStrip,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${stats.activeBusCount} busov • ${stats.totalPassengers} ${ws.passengersWord}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Instant SL | EN | DE | SR switcher
                  for (final entry in const [
                    ('sl', 'SL'),
                    ('en', 'EN'),
                    ('de', 'DE'),
                    ('sr_Latn', 'SR'),
                  ])
                    InkWell(
                      onTap: () => notifier.setLocaleCode(entry.$1),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: settings.localeCode == entry.$1
                              ? MarpromColors.marpromRed
                              : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.$2,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: settings.localeCode == entry.$1
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  // Theme cycle (Light -> Dark -> High Contrast)
                  InkWell(
                    onTap: () {
                      final next = switch (settings.themeMode) {
                        AppThemeChoice.system ||
                        AppThemeChoice.light =>
                          AppThemeChoice.dark,
                        AppThemeChoice.dark => AppThemeChoice.highContrast,
                        AppThemeChoice.highContrast => AppThemeChoice.light,
                      };
                      notifier.setThemeMode(next);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        settings.themeMode == AppThemeChoice.dark
                            ? Icons.dark_mode_rounded
                            : settings.themeMode == AppThemeChoice.highContrast
                                ? Icons.contrast_rounded
                                : Icons.light_mode_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                  if (activeUser == null)
                    GoogleSignInButton(
                      compact: true,
                      label: settings.localeCode == 'sl'
                          ? 'Google prijava'
                          : 'Google Sign-In',
                      onPressed: () {
                        ref.read(authRepositoryProvider).signInWithGoogle(
                              preferredLocaleCode: settings.localeCode,
                            );
                      },
                    )
                  else
                    InkWell(
                      onTap: () => context.go('/account'),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF475569)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.account_circle_rounded,
                              color: Color(0xFF38BDF8),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              activeUser.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavbarLink extends StatelessWidget {
  const _NavbarLink({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? MarpromColors.marpromRed.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? MarpromColors.marpromRed : scheme.onSurface,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MobileWebDrawer extends StatelessWidget {
  const _MobileWebDrawer({
    required this.currentPath,
    required this.navItems,
    required this.ws,
  });

  final String currentPath;
  final List<({String path, String label, IconData icon})> navItems;
  final MarpromWebStrings ws;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const MarpromBrandEmblem(size: 42),
                const SizedBox(width: 12),
                Text(
                  'MARPROM',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: MarpromColors.marpromRed,
                      ),
                ),
              ],
            ),
            const Divider(height: 28),
            for (final item in navItems)
              ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                selected: currentPath == item.path,
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(item.path);
                },
              ),
            const Divider(height: 24),
            if (kIsWeb)
              ListTile(
                leading: const Icon(Icons.download_for_offline_rounded),
                title: Text(ws.navDownload),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/download');
                },
              ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Obvestila v prometu'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/notices');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MarpromWebFooter extends StatelessWidget {
  const _MarpromWebFooter({required this.ws});

  final MarpromWebStrings ws;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 48),
      color: MarpromColors.marpromCharcoal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 40,
                runSpacing: 28,
                children: [
                  SizedBox(
                    width: 340,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const MarpromBrandEmblem(size: 38),
                            const SizedBox(width: 12),
                            const Text(
                              'MARPROM • Skupina JHMB',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Javno podjetje za mestni potniški promet, Pohorsko vzpenjačo ter upravljanje osrednje Avtobusne postaje Maribor.',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            height: 1.5,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _FooterColumn(
                    title: 'Mestne linije',
                    links: [
                      ('Glavne linije G1–G6', '/lines'),
                      ('Povezovalne P7–P19', '/lines'),
                      ('3D Zemljevid & Statistika', '/live'),
                      ('Načrtovalec poti', '/plan'),
                    ],
                  ),
                  _FooterColumn(
                    title: 'Potniki & Aplikacija',
                    links: [
                      ('Vozovnice & cenik', '/tickets'),
                      if (kIsWeb) ('Prenesi Android APK', '/download'),
                      if (kIsWeb) ('Namesti za iOS', '/download'),
                      ('Prometna obvestila', '/notices'),
                    ],
                  ),
                  const SizedBox(
                    width: 260,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Avtobusna postaja Maribor',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Mlinska ulica 1, 2000 Maribor\nBlagajna: Pon–Pet 05:30–20:30\nSobota: 07:00–15:00\nInfo center: +386 (0)2 235 01 10',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            height: 1.6,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF1E293B), height: 40),
              const Text(
                '© 2026 Javno podjetje Marprom d.o.o. • M Mobilnost 2.0 • Google Maps 3D & Routes API v2',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  final List<(String, String)> links;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          for (final (label, path) in links)
            InkWell(
              onTap: () => context.go(path),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
