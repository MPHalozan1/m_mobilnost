//**********************************************
// Animated Welcome & Transit Overview Screen  *
//**********************************************

import 'dart:async';

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
import '../../live_tracker/domain/fleet_statistics_provider.dart';

//**********************************************
// WelcomeScreen Hero Landing Page             *
//**********************************************

// Sleek Welcome landing page with 1-click entry straight into the live Map
// in Demo Mode (zero forced login wall), optional Google Sign-In, theme &
// accessibility toggles, and Web-only Android APK download CTA.
class WelcomeScreen extends ConsumerStatefulWidget {
  // Creates a [WelcomeScreen].
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _signingIn = false;

  Future<void> _enterMapDemo() async {
    await ref.read(a11ySettingsProvider.notifier).setOnboardingDone(true);
    final authRepo = ref.read(authRepositoryProvider);
    if (authRepo.currentUser == null) {
      unawaited(authRepo.signInDemoAccount(
        preferredLocaleCode: ref.read(a11ySettingsProvider).localeCode,
      ));
    }
    if (mounted) context.go('/');
  }

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
    final isSl = settings.localeCode == 'sl';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CustomPaint(
                              size: const Size.square(40),
                              painter: const MarpromLogoPainter(),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'M-Mobilnost Maribor',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: isDark
                                ? (isSl ? 'Svetli način' : 'Light Mode')
                                : (isSl ? 'Temni način' : 'Dark Mode'),
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
                            label: Text(isSl ? 'Voziček' : 'Wheelchair'),
                            selected: settings.wheelchairAccessibleOnly,
                            onSelected: notifier.setWheelchairAccessibleOnly,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Sleek Marprom Hero Card with immediate Start CTA
                  Container(
                    padding: const EdgeInsets.all(28),
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
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
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
                            isSl
                                ? '● ${stats.activeBusCount} aktivnih avtobusov • ${stats.totalPassengers} potnikov v Mariboru'
                                : '● ${stats.activeBusCount} active buses • ${stats.totalPassengers} riders in Maribor',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isSl
                              ? 'Pametni mestni prevoz po Mariboru v živo'
                              : 'Smart Real-Time Maribor City Transit',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isSl
                              ? 'Prave Google Maps ceste, Gemini AI iskalnik poti, brezstična NFC + QR vozovnica in pregled zasedenosti vseh linij (G1–G6 & P7–P19).'
                              : 'Live Google Maps road routing, Gemini AI transit planner, contactless NFC + QR Vozovnica, and live bus occupancy across G1–G6 & P7–P19.',
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: _enterMapDemo,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: MarpromColors.marpromBurgundy,
                                minimumSize: const Size(0, 52),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                              ),
                              icon: const Icon(Icons.explore_rounded),
                              label: Text(
                                isSl
                                    ? 'Začni / Odpri zemljevid'
                                    : 'Start / Open Map',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                unawaited(notifier.setOnboardingDone(true));
                                context.go('/buses');
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white54),
                                minimumSize: const Size(0, 52),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                              ),
                              icon: const Icon(Icons.directions_bus_rounded),
                              label: Text(
                                isSl ? 'Vsi avtobusi' : 'All Buses',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Optional Sign-In & Web-Only Android APK Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isSl
                                ? 'Takojšnji Demo način ali prijava'
                                : 'Instant Demo Mode or Sign In',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isSl
                                ? 'Aplikacija je pripravljena brez prijave. Po želji se povežite z Google računom ali e-pošto za trajno shranjevanje vozovnic.'
                                : 'Explore everything immediately in Demo mode, or sign in with Google or Email to sync your tickets.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),
                          GoogleSignInButton(
                            label: isSl
                                ? 'Nadaljuj z Google računom'
                                : 'Continue with Google',
                            loading: _signingIn,
                            onPressed: _continueWithGoogle,
                          ),
                          const SizedBox(height: 10),
                          BigButton(
                            icon: Icons.person_outline_rounded,
                            label: isSl
                                ? 'Profil, nastavitve in prijava z e-pošto'
                                : 'Profile, Settings & Email Sign In',
                            variant: BigButtonVariant.outlined,
                            expanded: true,
                            onPressed: () {
                              unawaited(notifier.setOnboardingDone(true));
                              context.go('/profile');
                            },
                          ),
                          if (kIsWeb) ...[
                            const Divider(height: 24),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: MarpromColors.mobilityGreen,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 50),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => launchUrl(
                                marpromAndroidApkUri,
                                mode: LaunchMode.externalApplication,
                              ),
                              icon: const Icon(Icons.android_rounded),
                              label: Text(
                                isSl
                                    ? 'Prenesi Android aplikacijo (v2.0 APK)'
                                    : 'Download Android App (v2.0 APK)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
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
