//**********************************************
// Animated Welcome & Transit Overview Screen  *
//**********************************************

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/accessibility/a11y_settings.dart';
import '../../../core/config/download_links.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/seed/seed_stops.dart';
import '../../live_tracker/domain/fleet_statistics_provider.dart';

/// Sleek Welcome / Onboarding landing screen with live Maribor fleet metrics,
/// quick route-search preview, Google + Email sign-in, theme/accessibility toggles,
/// and a Web-only Android APK download CTA.
class WelcomeScreen extends ConsumerStatefulWidget {
  /// Creates a [WelcomeScreen].
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  String _fromStopId = 'glavna_postaja';
  String _toStopId = 'vzpenjaca';
  bool _signingIn = false;

  Future<void> _continueWithGoogle() async {
    setState(() => _signingIn = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle(
            preferredLocaleCode: ref.read(a11ySettingsProvider).localeCode,
          );
      await ref.read(a11ySettingsProvider.notifier).setOnboardingDone(true);
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(a11ySettingsProvider);
    final notifier = ref.read(a11ySettingsProvider.notifier);
    final liveBuses = ref.watch(liveBusesStreamProvider).valueOrNull ??
        ref.watch(busSimulatorProvider).snapshotAt(DateTime.now());
    final stats = computeFleetStatistics(liveBuses);
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final sortedStops = List.of(seedStops)
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CustomPaint(
                            size: const Size.square(40),
                            painter: const MarpromLogoPainter(),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'M-Mobilnost Maribor',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: isDark ? 'Svetli način' : 'Temni način',
                            icon: Icon(
                              isDark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                            ),
                            onPressed: () => notifier.setThemeMode(
                              isDark
                                  ? AppThemeChoice.light
                                  : AppThemeChoice.dark,
                            ),
                          ),
                          FilterChip(
                            avatar: const Icon(Icons.accessible_rounded, size: 16),
                            label: const Text('Voziček'),
                            selected: settings.wheelchairAccessibleOnly,
                            onSelected: notifier.setWheelchairAccessibleOnly,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Hero highlight card
                  Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          MarpromColors.marpromCharcoal,
                          MarpromColors.marpromBurgundy,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '● ${stats.activeBusCount} aktivnih avtobusov • ${stats.totalPassengers} potnikov v Mariboru',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Pametni mestni prevoz po Mariboru v živo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Prave Google Maps ceste, 3D preleti tras, pametni izračun prestopov in realne zmogljivosti avtobusov Marprom (G1–G6 & P7–P19).',
                          style: TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick route search preview
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Hitri načrtovalec poti',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _fromStopId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Vstopno postajališče',
                              prefixIcon: Icon(Icons.my_location_rounded),
                            ),
                            items: [
                              for (final s in sortedStops)
                                DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _fromStopId = v);
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _toStopId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Ciljno postajališče',
                              prefixIcon: Icon(Icons.flag_rounded),
                            ),
                            items: [
                              for (final s in sortedStops)
                                DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _toStopId = v);
                            },
                          ),
                          const SizedBox(height: 14),
                          BigButton(
                            icon: Icons.route_rounded,
                            label: 'Poišči optimalno povezavo',
                            expanded: true,
                            onPressed: () {
                              notifier.setOnboardingDone(true);
                              context.go(
                                '/plan?from=${Uri.encodeComponent(_fromStopId)}'
                                '&to=${Uri.encodeComponent(_toStopId)}',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Auth entry & Web-only APK CTA
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GoogleSignInButton(
                            label: 'Nadaljuj z Google računom',
                            loading: _signingIn,
                            onPressed: _continueWithGoogle,
                          ),
                          const SizedBox(height: 10),
                          BigButton(
                            icon: Icons.email_outlined,
                            label: 'Prijava / registracija z e-pošto',
                            variant: BigButtonVariant.outlined,
                            expanded: true,
                            onPressed: () {
                              notifier.setOnboardingDone(true);
                              context.go('/account');
                            },
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              notifier.setOnboardingDone(true);
                              context.go('/');
                            },
                            child: const Text('Nadaljuj kot gost →'),
                          ),
                          if (kIsWeb) ...[
                            const Divider(height: 24),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: MarpromColors.mobilityGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => launchUrl(
                                marpromAndroidApkUri,
                                mode: LaunchMode.externalApplication,
                              ),
                              icon: const Icon(Icons.android_rounded),
                              label: const Text(
                                'Prenesi Android aplikacijo (v2.0 APK)',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
