// Dedicated Mobile App Download Page serving real Android APK + iOS install & mockup.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/accessibility/a11y_settings.dart';
import '../../../../core/config/download_links.dart';
import '../../../../core/theme/colors.dart';
import '../marprom_web_strings.dart';

/// Marprom Web Download Page (`/download`) providing direct Android `.apk` download
/// from GitHub Releases on Web, scannable QR codes, and iOS PWA guidance.
class WebDownloadPage extends ConsumerWidget {
  /// Creates the [WebDownloadPage].
  const WebDownloadPage({super.key, this.forceWebPreview = false});

  /// Allows widget tests running on VM (`!kIsWeb`) to preview the Web download layout.
  final bool forceWebPreview;

  Uri _apkUri() => marpromAndroidApkUri;

  Uri _webAppUri() => Uri.base.resolve('');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kIsWeb && !forceWebPreview) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 48,
                  color: MarpromColors.mobilityGreen,
                ),
                const SizedBox(height: 12),
                Text(
                  'Uporabljate mobilno aplikacijo M Mobilnost',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    final settings = ref.watch(a11ySettingsProvider);
    final ws = MarpromWebStrings.of(settings.localeCode);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 980;
    final scheme = Theme.of(context).colorScheme;
    final apkUrl = _apkUri();
    final iosWebUrl = _webAppUri();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero banner
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MarpromColors.marpromCharcoal,
                MarpromColors.marpromBurgundy,
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.center,
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
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'ANDROID .APK & iOS • GOOGLE MAPS 3D SDK',
                            style: TextStyle(
                              color: Color(0xFFFFD6DC),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          ws.downloadTitle,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isWide ? 40 : 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Vseh 19 mariborskih linij (G1–G6 in P7–P19), Google Maps 3D sledenje avtobusov, natančno število potnikov na krovu, načrtovalec poti in digitalne QR vozovnice v eni aplikaciji.',
                          style: TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 16,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: MarpromColors.marpromRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 18,
                                ),
                              ),
                              onPressed: () => launchUrl(
                                apkUrl,
                                mode: LaunchMode.externalApplication,
                              ),
                              icon: const Icon(Icons.android_rounded),
                              label: Text(
                                ws.downloadAndroidCta,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
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
                                  horizontal: 24,
                                  vertical: 18,
                                ),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Za iOS uporabite Safari → Deli → Dodaj na začetni zaslon ali TestFlight povezavo spodaj.',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.apple_rounded),
                              label: const Text(
                                'Namesti za iOS (iPhone / iPad)',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isWide ? 40 : 0, height: isWide ? 0 : 28),
                  const _PhoneAppMockupPreview(),
                ],
              ),
            ),
          ),
        ),

        // Android APK & iOS Download Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Android APK Card
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: MarpromColors.mobilityGreen
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.android_rounded,
                                    color: MarpromColors.mobilityGreen,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Android — Neposredni prenos APK',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        'Različica 2.0.0+1 • Android 8.0+ • Google Maps 3D SDK',
                                        style: TextStyle(fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                  child: QrImageView(
                                    data: apkUrl.toString(),
                                    size: 112,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '1. Skenirajte QR kodo s telefonom Android ali kliknite gumb spodaj.\n'
                                        '2. Prenesite datoteko m-mobilnost.apk.\n'
                                        '3. Odprite preneseno datoteko in potrdite namestitev.',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          height: 1.55,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: MarpromColors.mobilityGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                onPressed: () => launchUrl(
                                  apkUrl,
                                  mode: LaunchMode.externalApplication,
                                ),
                                icon: const Icon(Icons.download_rounded),
                                label: const Text(
                                  'Prenesi m-mobilnost.apk',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: isWide ? 24 : 0, height: isWide ? 0 : 24),

                  // iOS Card
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: MarpromColors.marpromCharcoal
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.apple_rounded,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'iOS (iPhone & iPad) — App & PWA',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        'iOS 15.0+ • Safari Web App & iOS Maps 3D projekt',
                                        style: TextStyle(fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                  child: QrImageView(
                                    data: iosWebUrl.toString(),
                                    size: 112,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '1. Odprite ta portal v brskalniku Safari na iPhonu.\n'
                                        '2. Tapnite ikono Deli (kvadrat s puščico navzgor).\n'
                                        '3. Izberite »Dodaj na začetni zaslon« za celozaslonsko aplikacijo M Mobilnost.',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          height: 1.55,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                onPressed: () => launchUrl(
                                  iosWebUrl,
                                  mode: LaunchMode.platformDefault,
                                ),
                                icon: const Icon(Icons.qr_code_scanner_rounded),
                                label: const Text(
                                  'Odpri iOS spletno aplikacijo / TestFlight',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneAppMockupPreview extends StatelessWidget {
  const _PhoneAppMockupPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFF334155), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MarpromColors.marpromRed,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'M',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'M Mobilnost',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.qr_code_2_rounded,
                  size: 18,
                  color: MarpromColors.marpromRed,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MarpromColors.marpromRed,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Glavni trg • Naslednji avtobus',
                    style: TextStyle(
                      color: Color(0xFFFFD6DC),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Linija G6 • čez 3 min',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '41 / 85 potnikov (48%) • Točen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.view_in_ar_rounded,
                    color: MarpromColors.mobilityGreen,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Google Maps 3D sledenje v živo',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
