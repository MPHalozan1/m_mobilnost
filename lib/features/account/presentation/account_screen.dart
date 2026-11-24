// Account screen supporting guest sign-in/up, demo quick-fill, minor checks, profile edit, and GDPR wipe.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/a11y_settings.dart';
import '../../../core/accessibility/haptic_cues.dart';
import '../../../core/accessibility/semantics_helpers.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/layout/responsive_builder.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../data/mock/mock_auth_repository.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/account_providers.dart';
import 'payment_methods_screen.dart';
import 'widgets/payment_method_helpers.dart';

/// Account management screen for guest authentication and signed-in profile controls.
class AccountScreen extends ConsumerStatefulWidget {
  /// Creates an [AccountScreen].
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();

  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();

  final _signUpNameController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _guardianEmailController = TextEditingController();

  final _profileNameController = TextEditingController();

  bool _isSignUpMode = false;
  bool _obscureSignInPassword = true;
  bool _obscureSignUpPassword = true;
  bool _submitting = false;
  String? _authError;

  DateTime? _signUpDob;
  String _signUpLocaleCode = 'sl';
  bool _signUpGuardianConfirmed = false;
  bool _signUpShowGuardianError = false;

  String? _syncedProfileId;
  DateTime? _profileDob;
  String _profileLocaleCode = 'sl';
  bool _profileGuardianConfirmed = false;
  bool _profileShowGuardianError = false;

  @override
  void initState() {
    super.initState();
    _signUpLocaleCode = ref.read(a11ySettingsProvider).localeCode;
  }

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _guardianEmailController.dispose();
    _profileNameController.dispose();
    super.dispose();
  }

  void _syncProfileControllers(UserProfile user) {
    if (_syncedProfileId == user.id) return;
    _syncedProfileId = user.id;
    _profileNameController.text = user.name;
    _profileDob = user.dateOfBirth;
    _profileLocaleCode = user.preferredLocaleCode;
    _profileGuardianConfirmed = user.guardianConfirmed;
    _profileShowGuardianError = false;
  }

  Future<void> _fillDemoCredentials() async {
    final settings = ref.read(a11ySettingsProvider);
    unawaited(
      HapticCues.trigger(
        HapticCueType.tap,
        enabled: settings.hapticAlertsEnabled,
        soundOptional: settings.soundAlertsOptional,
      ),
    );
    setState(() {
      _isSignUpMode = false;
      _authError = null;
      _signInEmailController.text = MockAuthRepository.demoEmail;
      _signInPasswordController.text = MockAuthRepository.demoPassword;
    });
  }

  Future<void> _handleSignIn() async {
    if (!(_signInFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _authError = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _signInEmailController.text.trim(),
            password: _signInPasswordController.text,
          );
      final settings = ref.read(a11ySettingsProvider);
      unawaited(
        HapticCues.trigger(
          HapticCueType.tap,
          enabled: settings.hapticAlertsEnabled,
        ),
      );
      if (mounted) {
        _syncedProfileId = null;
      }
    } on AuthException {
      if (mounted) {
        setState(() => _authError = context.l10n.commonErrorBody);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _authError = context.l10n.commonErrorBody);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _submitting = true;
      _authError = null;
    });
    try {
      final settings = ref.read(a11ySettingsProvider);
      await ref.read(authRepositoryProvider).signInWithGoogle(
            preferredLocaleCode: settings.localeCode,
          );
      unawaited(
        HapticCues.trigger(
          HapticCueType.tap,
          enabled: settings.hapticAlertsEnabled,
        ),
      );
      if (mounted) {
        _syncedProfileId = null;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _authError = context.l10n.commonErrorBody);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleSignUp() async {
    final l10n = context.l10n;
    final formValid = _signUpFormKey.currentState?.validate() ?? false;
    final needsGuardian =
        requiresGuardianConsent(_signUpDob, forPurchase: false);
    if (needsGuardian && !_signUpGuardianConfirmed) {
      setState(() {
        _signUpShowGuardianError = true;
        _authError = l10n.ticketsMinorUnder16Warning;
      });
      return;
    }
    if (!formValid) return;

    setState(() {
      _submitting = true;
      _authError = null;
      _signUpShowGuardianError = false;
    });
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _signUpEmailController.text.trim(),
            password: _signUpPasswordController.text,
            name: _signUpNameController.text.trim(),
            dateOfBirth: _signUpDob,
            preferredLocaleCode: _signUpLocaleCode,
            guardianConfirmed: _signUpGuardianConfirmed,
          );
      await ref
          .read(a11ySettingsProvider.notifier)
          .setLocaleCode(_signUpLocaleCode);
      if (mounted) {
        _syncedProfileId = null;
      }
    } on AuthException {
      if (mounted) {
        setState(() => _authError = l10n.commonErrorBody);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _authError = l10n.commonErrorBody);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showResetPasswordDialog() async {
    final l10n = context.l10n;
    final resetController =
        TextEditingController(text: _signInEmailController.text.trim());
    final formKey = GlobalKey<FormState>();

    final confirmedEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.accountPasswordReset),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: resetController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.accountEmailLabel,
                ),
                validator: (value) {
                  if (value == null || !value.contains('@')) {
                    return l10n.commonErrorBody;
                  }
                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(resetController.text.trim());
                }
              },
              child: Text(l10n.commonConfirm),
            ),
          ],
        );
      },
    );
    resetController.dispose();

    if (confirmedEmail == null || !mounted) return;
    try {
      await ref.read(authRepositoryProvider).resetPassword(confirmedEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accountResetSent(confirmedEmail))),
      );
    } on AuthException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.commonErrorBody)),
      );
    }
  }

  Future<DateTime?> _pickDateOfBirth(DateTime? current) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1910),
      lastDate: now,
    );
  }

  Future<void> _handleSaveProfile(UserProfile user) async {
    final l10n = context.l10n;
    if (!(_profileFormKey.currentState?.validate() ?? false)) return;
    final needsGuardian =
        requiresGuardianConsent(_profileDob, forPurchase: false);
    if (needsGuardian && !_profileGuardianConfirmed) {
      setState(() => _profileShowGuardianError = true);
      return;
    }

    setState(() {
      _submitting = true;
      _profileShowGuardianError = false;
    });
    try {
      final updated = user.copyWith(
        name: _profileNameController.text.trim(),
        dateOfBirth: _profileDob,
        preferredLocaleCode: _profileLocaleCode,
        guardianConfirmed: _profileGuardianConfirmed,
      );
      await ref.read(authRepositoryProvider).updateProfile(updated);
      await ref
          .read(a11ySettingsProvider.notifier)
          .setLocaleCode(_profileLocaleCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commonDone)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleDeleteAccount() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10n.accountDeleteConfirmTitle),
          content: SingleChildScrollView(
            child: Text(l10n.accountDeleteConfirmBody),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      _syncedProfileId = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commonDone)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = ref.watch(activeUserProvider);
    final settings = ref.watch(a11ySettingsProvider);
    if (user != null) {
      _syncProfileControllers(user);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountTitle),
      ),
      body: user == null
          ? _buildGuestView(context, l10n, settings)
          : _buildSignedInView(context, l10n, user, settings),
    );
  }

  Widget _buildGuestView(
    BuildContext context,
    AppLocalizations l10n,
    A11ySettings settings,
  ) {
    return ListView(
      children: [
        ResponsiveContentContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7F1020), Color(0xFFE13A4A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_bus_filled_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.accountTitle,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.ticketsAuthRequiredBody,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusChip(
                        type: TransitStatusType.info,
                        label: l10n.accountGuestMode,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.ticketsAuthRequiredBody,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  BigButton(
                    icon: Icons.login_rounded,
                    label: l10n.accountSignIn,
                    variant: _isSignUpMode
                        ? BigButtonVariant.outlined
                        : BigButtonVariant.selected,
                    onPressed: () {
                      setState(() {
                        _isSignUpMode = false;
                        _authError = null;
                      });
                    },
                  ),
                  BigButton(
                    icon: Icons.person_add_alt_1_rounded,
                    label: l10n.accountSignUp,
                    variant: _isSignUpMode
                        ? BigButtonVariant.selected
                        : BigButtonVariant.outlined,
                    onPressed: () {
                      setState(() {
                        _isSignUpMode = true;
                        _authError = null;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_authError != null) ...[
                _ErrorBanner(message: _authError!),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        settings.localeCode == 'sl'
                            ? 'Hitra prijava z Google računom'
                            : 'Quick Google Account Sign-In',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        FirebaseBootstrap.isReady
                            ? 'Firebase Auth Google OAuth aktiven.'
                            : 'Takojšnja prijava z Google profilom za vozovnice NFC/QR in Firebase sinhronizacijo.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      GoogleSignInButton(
                        label: settings.localeCode == 'sl'
                            ? 'Prijava z Google računom'
                            : 'Continue with Google',
                        loading: _submitting,
                        onPressed: _handleGoogleSignIn,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!_isSignUpMode)
                _buildSignInCard(context, l10n)
              else
                _buildSignUpCard(context, l10n, settings),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignInCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _signInFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.accountSignIn,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _signInEmailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: l10n.accountEmailLabel,
                  hintText: MockAuthRepository.demoEmail,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || !v.trim().contains('@')) {
                    return l10n.commonErrorBody;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _signInPasswordController,
                obscureText: _obscureSignInPassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: l10n.accountPasswordLabel,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    constraints:
                        const BoxConstraints(minWidth: 56, minHeight: 56),
                    tooltip: l10n.accountPasswordLabel,
                    icon: Icon(
                      _obscureSignInPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(
                        () => _obscureSignInPassword = !_obscureSignInPassword,
                      );
                    },
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length < 4) {
                    return l10n.commonErrorBody;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              BigButton(
                icon: Icons.login_rounded,
                label: l10n.accountSignIn,
                expanded: true,
                loading: _submitting,
                onPressed: _handleSignIn,
              ),
              const SizedBox(height: 12),
              BigButton(
                icon: Icons.bolt_rounded,
                label: l10n.accountDemoAccountHint,
                variant: BigButtonVariant.secondary,
                expanded: true,
                onPressed: _fillDemoCredentials,
              ),
              const SizedBox(height: 12),
              BigButton(
                icon: Icons.lock_reset_rounded,
                label: l10n.accountPasswordReset,
                variant: BigButtonVariant.outlined,
                expanded: true,
                onPressed: _showResetPasswordDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpCard(
    BuildContext context,
    AppLocalizations l10n,
    A11ySettings settings,
  ) {
    final age = calculateAgeYears(_signUpDob);
    final isUnder16 = age != null && age < 16;
    final isUnder18 = age != null && age < 18;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _signUpFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.accountSignUp,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _signUpNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.accountNameLabel,
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l10n.commonErrorBody;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _signUpEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.accountEmailLabel,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || !v.trim().contains('@')) {
                    return l10n.commonErrorBody;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _signUpPasswordController,
                obscureText: _obscureSignUpPassword,
                decoration: InputDecoration(
                  labelText: l10n.accountPasswordLabel,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    constraints:
                        const BoxConstraints(minWidth: 56, minHeight: 56),
                    tooltip: l10n.accountPasswordLabel,
                    icon: Icon(
                      _obscureSignUpPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(
                        () => _obscureSignUpPassword = !_obscureSignUpPassword,
                      );
                    },
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length < 4) {
                    return l10n.commonErrorBody;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              BigButton(
                icon: Icons.cake_outlined,
                label: _signUpDob == null
                    ? l10n.accountDobLabel
                    : '${l10n.accountDobLabel}: '
                        '${formatCalendarDate(_signUpDob!, localeCode: settings.localeCode)}',
                variant: BigButtonVariant.outlined,
                expanded: true,
                onPressed: () async {
                  final picked = await _pickDateOfBirth(_signUpDob);
                  if (picked != null && mounted) {
                    setState(() {
                      _signUpDob = picked;
                      _signUpShowGuardianError = false;
                      _authError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n.settingsLanguage,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _LanguageSelector(
                selectedCode: _signUpLocaleCode,
                onSelected: (code) {
                  setState(() => _signUpLocaleCode = code);
                  ref.read(a11ySettingsProvider.notifier).setLocaleCode(code);
                },
              ),
              if (isUnder18) ...[
                const SizedBox(height: 16),
                _MinorProtectionCard(
                  isUnder16: isUnder16,
                  guardianConfirmed: _signUpGuardianConfirmed,
                  requireConfirmation: isUnder16,
                  showValidationError: _signUpShowGuardianError,
                  guardianEmailController: _guardianEmailController,
                  onConfirmedChanged: (value) {
                    setState(() {
                      _signUpGuardianConfirmed = value;
                      if (value) {
                        _signUpShowGuardianError = false;
                        _authError = null;
                      }
                    });
                  },
                ),
              ],
              const SizedBox(height: 18),
              BigButton(
                icon: Icons.person_add_alt_1_rounded,
                label: l10n.accountSignUp,
                expanded: true,
                loading: _submitting,
                onPressed: _handleSignUp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignedInView(
    BuildContext context,
    AppLocalizations l10n,
    UserProfile user,
    A11ySettings settings,
  ) {
    final profileAge = calculateAgeYears(_profileDob);
    final profileUnder16 = profileAge != null && profileAge < 16;
    final profileUnder18 = profileAge != null && profileAge < 18;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      children: [
        ResponsiveContentContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: scheme.primaryContainer,
                            child: Icon(
                              Icons.person_rounded,
                              size: 28,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  user.email,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (user.authProvider == 'google' ||
                          user.isYouthEligible ||
                          user.isSeniorEligible ||
                          user.isUnder18) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (user.authProvider == 'google')
                              const StatusChip(
                                type: TransitStatusType.onTime,
                                label: 'Google Account',
                              ),
                            if (user.isYouthEligible)
                              StatusChip(
                                type: TransitStatusType.info,
                                label: l10n.accountYouthEligible,
                              ),
                            if (user.isSeniorEligible)
                              StatusChip(
                                type: TransitStatusType.onTime,
                                label: l10n.accountSeniorEligible,
                              ),
                            if (user.isUnder18)
                              StatusChip(
                                type: TransitStatusType.warning,
                                label: l10n.ticketsMinorTitle,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _profileFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.accountTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _profileNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: l10n.accountNameLabel,
                            prefixIcon:
                                const Icon(Icons.badge_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return l10n.commonErrorBody;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        BigButton(
                          icon: Icons.cake_outlined,
                          label: _profileDob == null
                              ? l10n.accountDobLabel
                              : '${l10n.accountDobLabel}: '
                                  '${formatCalendarDate(_profileDob!, localeCode: settings.localeCode)}',
                          variant: BigButtonVariant.outlined,
                          expanded: true,
                          onPressed: () async {
                            final picked = await _pickDateOfBirth(_profileDob);
                            if (picked != null && mounted) {
                              setState(() {
                                _profileDob = picked;
                                _profileShowGuardianError = false;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.settingsLanguage,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _LanguageSelector(
                          selectedCode: _profileLocaleCode,
                          onSelected: (code) {
                            setState(() => _profileLocaleCode = code);
                            ref
                                .read(a11ySettingsProvider.notifier)
                                .setLocaleCode(code);
                          },
                        ),
                        if (profileUnder18) ...[
                          const SizedBox(height: 16),
                          _MinorProtectionCard(
                            isUnder16: profileUnder16,
                            guardianConfirmed: _profileGuardianConfirmed,
                            requireConfirmation: profileUnder16,
                            showValidationError: _profileShowGuardianError,
                            onConfirmedChanged: (value) {
                              setState(() {
                                _profileGuardianConfirmed = value;
                                if (value) _profileShowGuardianError = false;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        BigButton(
                          icon: Icons.save_outlined,
                          label: l10n.accountSaveProfile,
                          expanded: true,
                          loading: _submitting,
                          onPressed: () => _handleSaveProfile(user),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              BigButton(
                icon: Icons.credit_card_rounded,
                label: l10n.accountManagePayments,
                variant: BigButtonVariant.secondary,
                expanded: true,
                onPressed: () => navigateWithFallback(
                  context,
                  '/account/payments',
                  fallbackBuilder: (_) => const PaymentMethodsScreen(),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.accountGdprTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.accountGdprDescription,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.accountGdprAnalytics),
                          value: settings.analyticsConsent,
                          onChanged: (value) => ref
                              .read(a11ySettingsProvider.notifier)
                              .setAnalyticsConsent(value),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.accountGdprNotifications),
                          value: settings.notificationsConsent,
                          onChanged: (value) => ref
                              .read(a11ySettingsProvider.notifier)
                              .setNotificationsConsent(value),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              BigButton(
                icon: Icons.logout_rounded,
                label: l10n.accountSignOut,
                variant: BigButtonVariant.outlined,
                expanded: true,
                onPressed: _submitting
                    ? null
                    : () async {
                        await ref.read(authRepositoryProvider).signOut();
                        _syncedProfileId = null;
                      },
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: l10n.accountDeleteAccount,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  onPressed: _submitting ? null : _handleDeleteAccount,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delete_forever_outlined, size: 22),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          l10n.accountDeleteAccount,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.selectedCode,
    required this.onSelected,
  });

  final String selectedCode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <(String, String)>[
      ('sl', l10n.languageNameSl),
      ('en', l10n.languageNameEn),
      ('de', l10n.languageNameDe),
      ('sr_Latn', l10n.languageNameSrLatn),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (code, label) in options)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: ChoiceChip(
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(label),
              ),
              selected: selectedCode == code,
              onSelected: (_) => onSelected(code),
            ),
          ),
      ],
    );
  }
}

class _MinorProtectionCard extends StatelessWidget {
  const _MinorProtectionCard({
    required this.isUnder16,
    required this.guardianConfirmed,
    required this.requireConfirmation,
    required this.showValidationError,
    required this.onConfirmedChanged,
    this.guardianEmailController,
  });

  final bool isUnder16;
  final bool guardianConfirmed;
  final bool requireConfirmation;
  final bool showValidationError;
  final ValueChanged<bool> onConfirmedChanged;
  final TextEditingController? guardianEmailController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusColors =
        Theme.of(context).extension<MarpromStatusColors>() ??
            MarpromStatusColors.light;

    return Material(
      color: statusColors.warningBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: statusColors.warningFg,
          width: statusColors.highContrastBorders ? 2.0 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusChip(
              type: TransitStatusType.warning,
              label: l10n.ticketsMinorTitle,
            ),
            const SizedBox(height: 8),
            Text(
              isUnder16
                  ? l10n.ticketsMinorUnder16Warning
                  : l10n.ticketsMinorUnder18Notice,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: statusColors.warningFg,
                  ),
            ),
            if (guardianEmailController != null && isUnder16) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: guardianEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.ticketsMinorGuardianEmail,
                  prefixIcon: const Icon(Icons.family_restroom_rounded),
                ),
              ),
            ],
            if (requireConfirmation) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: guardianConfirmed,
                  title: Text(
                    l10n.ticketsMinorGuardianConfirm,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: statusColors.warningFg,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  onChanged: (value) => onConfirmedChanged(value ?? false),
                ),
              ),
              if (showValidationError)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.ticketsMinorUnder16Warning,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.error),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
