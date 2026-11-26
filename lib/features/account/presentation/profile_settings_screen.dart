//**********************************************
// Unified Profile & Settings Screen           *
//**********************************************

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/accessibility/a11y_settings.dart';
import '../../../core/accessibility/favorites_provider.dart';
import '../../../core/accessibility/semantics_helpers.dart';
import '../../../core/auth/email_validator.dart';
import '../../../core/config/download_links.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../data/models/bus_stop.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/seed/seed_places.dart';
import '../../../l10n/app_localizations.dart';
import '../../lines/data/transit_providers.dart';
import '../../trip_planner/presentation/widgets/smart_station_autocomplete.dart';
import '../../trip_planner/presentation/widgets/trip_endpoint.dart';

//**********************************************
// ProfileSettingsScreen widget                *
//**********************************************

// Clean, card-grouped Profile, Auth & Preferences screen replacing separate
// Account and Settings views on both Web and Mobile.
class ProfileSettingsScreen extends ConsumerStatefulWidget {
  // Creates a [ProfileSettingsScreen].
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _busy = false;
  String? _statusMessage;
  bool _statusIsError = false;
  String? _typoSuggestion;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInGoogle(String localeCode) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithGoogle(preferredLocaleCode: localeCode);
      if (!mounted) return;
      setState(() {
        _statusIsError = false;
        _statusMessage = localeCode == 'sl'
            ? 'Prijava z Google računom uspešna.'
            : 'Signed in with Google successfully.';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusIsError = true;
        _statusMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusIsError = true;
        _statusMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmailAuth(String localeCode) async {
    final isSl = localeCode == 'sl';
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      if (_isSignUp) {
        await repo.signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          name: _nameCtrl.text.trim().isEmpty
              ? _emailCtrl.text.trim().split('@').first
              : _nameCtrl.text.trim(),
          preferredLocaleCode: localeCode,
        );
        if (!mounted) return;
        setState(() {
          _statusIsError = false;
          _statusMessage = isSl
              ? 'Račun ustvarjen! Preverite e-pošto za potrditev.'
              : 'Account created! Check your inbox for verification.';
        });
      } else {
        await repo.signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        if (!mounted) return;
        setState(() {
          _statusIsError = false;
          _statusMessage =
              isSl ? 'Uspešno ste prijavljeni.' : 'Signed in successfully.';
        });
      }
      _passwordCtrl.clear();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusIsError = true;
        _statusMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusIsError = true;
        _statusMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendVerification(String localeCode) async {
    final isSl = localeCode == 'sl';
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _statusIsError = false;
        _statusMessage = isSl
            ? 'Potrditvena e-pošta ponovno poslana.'
            : 'Verification email re-sent.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusIsError = true;
        _statusMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshVerification(String localeCode) async {
    final isSl = localeCode == 'sl';
    setState(() => _busy = true);
    try {
      final refreshed = await ref.read(authRepositoryProvider).reloadCurrentUser();
      if (!mounted) return;
      setState(() {
        _statusIsError = false;
        _statusMessage = (refreshed?.emailVerified ?? false)
            ? (isSl ? 'E-pošta je potrjena ✓' : 'Email verified ✓')
            : (isSl
                ? 'E-pošta še ni potrjena.'
                : 'Email still pending verification.');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOutBackToDemo(String localeCode) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signOut();
      await repo.signInDemoAccount(preferredLocaleCode: localeCode);
      if (!mounted) return;
      setState(() {
        _statusIsError = false;
        _statusMessage = localeCode == 'sl'
            ? 'Preklopljeno v Demo način.'
            : 'Signed out — Demo mode active.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(a11ySettingsProvider);
    final settingsNotifier = ref.read(a11ySettingsProvider.notifier);
    final favorites = ref.watch(favoritesProvider);
    final stops = ref.watch(allStopsProvider).valueOrNull ?? const <BusStop>[];
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isSl = settings.localeCode == 'sl';

    BusStop? homeStop;
    final homeId = favorites.manualStopId ?? FavoritesState.defaultManualStopId;
    for (final s in stops) {
      if (s.id == homeId) {
        homeStop = s;
        break;
      }
    }

    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSl ? 'Profil in nastavitve' : 'Profile & Settings'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 24 : 16,
                12,
                isWide ? 24 : 16,
                32,
              ),
              children: [
                // 1. Account / Auth Card
                _buildAccountSection(
                  context,
                  theme: theme,
                  l10n: l10n,
                  user: user,
                  isSl: isSl,
                  localeCode: settings.localeCode,
                ),
                const SizedBox(height: 16),

                // 2. Accessibility & Wheelchair Mobility Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.accessible_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isSl
                                    ? 'Dostopnost in gibalna oviranost'
                                    : 'Accessibility & Mobility',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: settings.wheelchairAccessibleOnly,
                          onChanged: (v) => unawaited(
                            settingsNotifier.setWheelchairAccessibleOnly(v),
                          ),
                          title: Text(
                            isSl
                                ? 'Samo prilagojeno za invalidske vozičke'
                                : 'Wheelchair Accessible Buses Only',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            isSl
                                ? 'Globalno filtrira iskalnik poti, AI, Vse avtobuse in vozne rede.'
                                : 'Filters routes, AI search, live tracker, and timetables globally.',
                          ),
                        ),
                        const Divider(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: settings.extraLargeText,
                          onChanged: (v) =>
                              unawaited(settingsNotifier.setExtraLargeText(v)),
                          title: Text(l10n.settingsExtraLargeText),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value:
                              settings.themeMode == AppThemeChoice.highContrast,
                          onChanged: (high) => unawaited(
                            settingsNotifier.setThemeMode(
                              high
                                  ? AppThemeChoice.highContrast
                                  : AppThemeChoice.dark,
                            ),
                          ),
                          title: Text(
                            isSl
                                ? 'Visok kontrast (WCAG AAA)'
                                : 'High Contrast Mode (WCAG AAA)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Appearance & Language Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.palette_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isSl
                                    ? 'Videz in jezik aplikacije'
                                    : 'Appearance & Language',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isSl
                              ? 'Tema aplikacije (Google Zemljevid ostaja vedno svetel)'
                              : 'App Theme (Google Maps always stays crisp light)',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<AppThemeChoice>(
                          segments: [
                            ButtonSegment(
                              value: AppThemeChoice.dark,
                              icon: const Icon(Icons.dark_mode_outlined),
                              label: Text(isSl ? 'Temna' : 'Dark'),
                            ),
                            ButtonSegment(
                              value: AppThemeChoice.light,
                              icon: const Icon(Icons.light_mode_outlined),
                              label: Text(isSl ? 'Svetla' : 'Light'),
                            ),
                            ButtonSegment(
                              value: AppThemeChoice.system,
                              icon: const Icon(Icons.brightness_auto_outlined),
                              label: Text(isSl ? 'Sistem' : 'System'),
                            ),
                          ],
                          selected: {
                            settings.themeMode == AppThemeChoice.highContrast
                                ? AppThemeChoice.dark
                                : settings.themeMode,
                          },
                          onSelectionChanged: (sel) {
                            if (sel.isNotEmpty) {
                              unawaited(settingsNotifier.setThemeMode(sel.first));
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isSl ? 'Jezik vmesnika' : 'App Language',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in const [
                              ('sl', 'Slovenščina'),
                              ('en', 'English'),
                              ('de', 'Deutsch'),
                              ('sr_Latn', 'Srpski'),
                            ])
                              ChoiceChip(
                                selected: settings.localeCode == entry.$1,
                                label: Text(entry.$2),
                                onSelected: (_) => unawaited(
                                  settingsNotifier.setLocaleCode(entry.$1),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Home Station Searchable Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.home_work_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isSl
                                    ? 'Domače / privzeto postajališče'
                                    : 'Home / Default Bus Stop',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SmartStationAutocompleteField(
                          label: isSl ? 'Izberi domačo postajo' : 'Home Stop',
                          hint: isSl
                              ? 'Išči postajo (npr. glav → Glavni trg)...'
                              : 'Search Maribor bus stop...',
                          icon: Icons.location_city_rounded,
                          value: homeStop != null
                              ? TripEndpoint.stop(homeStop)
                              : null,
                          stops: stops,
                          places: seedPlaces,
                          userPosition: GeoUtils.mariborCenter,
                          accessibleOnly: settings.wheelchairAccessibleOnly,
                          localeCode: settings.localeCode,
                          onSelected: (endpoint) {
                            final chosen = endpoint.stop;
                            if (chosen != null) {
                              unawaited(
                                ref
                                    .read(favoritesProvider.notifier)
                                    .setManualStop(chosen.id),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // 5. Web-Only Android APK Card
                if (kIsWeb) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.35,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            child: const Icon(Icons.android_rounded),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSl
                                      ? 'M-Mobilnost za Android'
                                      : 'M-Mobilnost Android App',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isSl
                                      ? 'Namesti mobilno aplikacijo z NFC HCE brezstično vozovnico.'
                                      : 'Install native Android APK with built-in NFC HCE validation.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: () => unawaited(
                              launchUrl(
                                marpromAndroidApkUri,
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: Text(isSl ? 'Prenesi APK' : 'Download APK'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openForgotPasswordDialog(String localeCode) async {
    final isSl = localeCode == 'sl';
    final resetCtrl = TextEditingController(text: _emailCtrl.text.trim());
    String? dialogError;
    var sending = false;

    final sentEmail = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                isSl ? 'Ponastavitev gesla' : 'Reset Password',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isSl
                        ? 'Vnesite svoj e-poštni naslov za prejem povezave za ponastavitev gesla (novo geslo mora vsebovati min. 6 znakov, A–Z, a–z in 0–9).'
                        : 'Enter your email address to receive a password reset link (new password requires 6+ chars, A–Z, a–z, and 0–9).',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: resetCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: isSl ? 'E-pošta' : 'Email',
                      hintText: 'ime@gmail.com',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      dialogError!,
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: sending ? null : () => Navigator.of(ctx).pop(),
                  child: Text(isSl ? 'Prekliči' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final email = resetCtrl.text.trim();
                          final check = EmailValidator.validate(email);
                          if (!check.isValid) {
                            setDialogState(() {
                              dialogError = check.localizedError(localeCode) ??
                                  (isSl
                                      ? 'Neveljaven e-poštni naslov.'
                                      : 'Invalid email address.');
                            });
                            return;
                          }
                          setDialogState(() {
                            sending = true;
                            dialogError = null;
                          });
                          try {
                            await ref
                                .read(authRepositoryProvider)
                                .resetPassword(check.normalizedEmail);
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop(check.normalizedEmail);
                            }
                          } on AuthException catch (e) {
                            setDialogState(() {
                              sending = false;
                              dialogError = e.message;
                            });
                          } catch (e) {
                            setDialogState(() {
                              sending = false;
                              dialogError = e.toString();
                            });
                          }
                        },
                  child: sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isSl ? 'Pošlji' : 'Send Email'),
                ),
              ],
            );
          },
        );
      },
    );

    resetCtrl.dispose();
    if (sentEmail != null && mounted) {
      setState(() {
        _statusIsError = false;
        _statusMessage = isSl
            ? 'Povezava za ponastavitev gesla je bila poslana na $sentEmail.'
            : 'Password reset email sent to $sentEmail.';
      });
    }
  }

  Future<void> _openSupportDialog(String localeCode) async {
    final isSl = localeCode == 'sl';
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.support_agent_rounded),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSl ? 'Pomoč in podpora Marprom' : 'Marprom Help & Support',
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined),
                title: const Text('info@marprom.si'),
                subtitle: Text(isSl ? 'Podpora po e-pošti' : 'Email support'),
                onTap: () => unawaited(
                  launchUrl(Uri.parse('mailto:info@marprom.si')),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: const Text('+386 2 80 50 910'),
                subtitle: Text(
                  isSl ? 'Prometni center Marprom' : 'Marprom Transit Center',
                ),
                onTap: () => unawaited(
                  launchUrl(Uri.parse('tel:+38628050910')),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language_rounded),
                title: const Text('marprom.si/kontakt'),
                subtitle: Text(
                  isSl ? 'Uradna spletna podpora' : 'Official web contact',
                ),
                onTap: () => unawaited(
                  launchUrl(
                    Uri.parse('https://www.marprom.si/kontakt/'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton.tonal(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(isSl ? 'Zapri' : 'Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountSection(
    BuildContext context, {
    required ThemeData theme,
    required AppLocalizations l10n,
    required UserProfile? user,
    required bool isSl,
    required String localeCode,
  }) {
    final isDemo = user == null || user.isAnonymousDemo;
    final policy = EmailValidator.evaluatePasswordPolicy(_passwordCtrl.text);
    final strength = EmailValidator.evaluatePasswordStrength(_passwordCtrl.text);
    final canSubmitAuth = !_busy && (!_isSignUp || policy.isCompliant);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isDemo) ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primary,
                    foregroundImage: (user.photoUrl?.isNotEmpty ?? false)
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : 'M',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (user.email.isNotEmpty)
                          Text(
                            user.email,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  StatusChip(
                    type: user.emailVerified
                        ? TransitStatusType.onTime
                        : TransitStatusType.warning,
                    label: user.authProvider == 'google'
                        ? 'Google'
                        : (user.emailVerified
                            ? (isSl ? 'Potrjen' : 'Verified')
                            : (isSl ? 'Nepotrjen' : 'Unverified')),
                    compact: true,
                  ),
                ],
              ),
              if (!user.emailVerified && user.authProvider == 'email') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSl
                            ? 'Potrdite e-pošto za trajno sinhronizacijo vozovnic.'
                            : 'Verify your email address to sync tickets permanently.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _resendVerification(localeCode),
                            icon: const Icon(Icons.mark_email_read_outlined,
                                size: 16),
                            label: Text(
                              isSl ? 'Ponovno pošlji' : 'Resend Email',
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _busy
                                ? null
                                : () => _refreshVerification(localeCode),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(
                              isSl ? 'Osveži status' : 'Refresh Status',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _signOutBackToDemo(localeCode),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(l10n.accountSignOut),
                  ),
                ],
              ),
            ] else ...[
              // Demo Mode banner + upgrade Auth Form
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSl
                                ? 'Demo način — Prijavite se za trajno shranjevanje vozovnic'
                                : 'Demo Mode — Sign in to save tickets permanently',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isSl
                                ? 'Demo dobroimetje: ${TimeFormatUtils.formatEur(user?.walletBalanceEur ?? 25.0, locale: localeCode)}'
                                : 'Demo balance: ${TimeFormatUtils.formatEur(user?.walletBalanceEur ?? 25.0, locale: localeCode)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _signInGoogle(localeCode),
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                  label: Text(
                    isSl ? 'Nadaljuj z Google računom' : 'Continue with Google',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.accountSignIn),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.accountSignUp),
                  ),
                ],
                selected: {_isSignUp},
                onSelectionChanged: (s) {
                  if (s.isNotEmpty) {
                    setState(() {
                      _isSignUp = s.first;
                      _statusMessage = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.accountNameLabel,
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onChanged: (v) {
                        final res = EmailValidator.validate(v);
                        setState(() => _typoSuggestion = res.suggestedEmail);
                      },
                      validator: (v) {
                        final res = EmailValidator.validate(v ?? '');
                        if (res.isValid) return null;
                        return isSl
                            ? (res.errorMessageSl ?? 'Neveljavna e-pošta.')
                            : (res.errorMessageEn ?? 'Invalid email address.');
                      },
                      decoration: InputDecoration(
                        labelText: l10n.accountEmailLabel,
                        hintText: 'ime@gmail.com / student.um.si',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_typoSuggestion != null) ...[
                      const SizedBox(height: 6),
                      ActionChip(
                        avatar: const Icon(Icons.auto_fix_high_rounded, size: 16),
                        label: Text('Ste mislili $_typoSuggestion?'),
                        onPressed: () {
                          _emailCtrl.text = _typoSuggestion!;
                          setState(() => _typoSuggestion = null);
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final pwd = v ?? '';
                        if (!_isSignUp) {
                          if (pwd.length < 6) {
                            return isSl
                                ? 'Geslo mora imeti vsaj 6 znakov.'
                                : 'Password must be at least 6 characters.';
                          }
                          return null;
                        }
                        if (!EmailValidator.evaluatePasswordPolicy(pwd).isCompliant) {
                          return isSl
                              ? 'Izpolnite vsa 4 pravila za geslo spodaj.'
                              : 'Please satisfy all 4 password requirements below.';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: l10n.accountPasswordLabel,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: isSl ? 'Pokaži/skrij geslo' : 'Toggle password',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 10),
                      _PasswordPolicyChecklist(
                        policy: policy,
                        isSl: isSl,
                        strength: strength,
                      ),
                    ] else ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => _openForgotPasswordDialog(localeCode),
                          child: Text(
                            isSl ? 'Pozabljeno geslo?' : 'Forgot Password?',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: canSubmitAuth
                            ? () => _submitEmailAuth(localeCode)
                            : null,
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isSignUp
                                    ? l10n.accountSignUp
                                    : l10n.accountSignIn,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _statusIsError
                      ? theme.colorScheme.error
                      : Colors.green.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openSupportDialog(localeCode),
                icon: const Icon(Icons.help_outline_rounded, size: 18),
                label: Text(
                  isSl ? 'Pomoč in podpora Marprom' : 'Help & Support',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordPolicyChecklist extends StatelessWidget {
  const _PasswordPolicyChecklist({
    required this.policy,
    required this.isSl,
    required this.strength,
  });

  final PasswordPolicyCheck policy;
  final bool isSl;
  final PasswordStrengthResult strength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: policy.isCompliant
              ? Colors.green.withValues(alpha: 0.55)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: (strength.score / 4.0).clamp(0.05, 1.0),
            color: policy.isCompliant
                ? Colors.green
                : (strength.score >= 2
                    ? Colors.amber
                    : theme.colorScheme.error),
          ),
          const SizedBox(height: 8),
          _PolicyRuleRow(
            satisfied: policy.hasMinLength,
            label: isSl ? 'Vsaj 6 znakov' : 'At least 6 characters',
          ),
          _PolicyRuleRow(
            satisfied: policy.hasUppercase,
            label: isSl ? '1 velika črka (A–Z)' : '1 uppercase letter (A–Z)',
          ),
          _PolicyRuleRow(
            satisfied: policy.hasLowercase,
            label: isSl ? '1 mala črka (a–z)' : '1 lowercase letter (a–z)',
          ),
          _PolicyRuleRow(
            satisfied: policy.hasNumber,
            label: isSl ? '1 številka (0–9)' : '1 number (0–9)',
          ),
        ],
      ),
    );
  }
}

class _PolicyRuleRow extends StatelessWidget {
  const _PolicyRuleRow({
    required this.satisfied,
    required this.label,
  });

  final bool satisfied;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = satisfied ? Colors.green.shade600 : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              satisfied
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              key: ValueKey<bool>(satisfied),
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: satisfied ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
