// Accessible first-run onboarding configuring language, a11y, location, and GDPR consent.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/a11y_settings.dart';
import '../../../core/accessibility/read_aloud.dart';
import '../../../core/accessibility/semantics_helpers.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/layout/responsive_builder.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/brand_logo.dart';

/// First-run onboarding screen covering language, accessibility, location, and GDPR.
class OnboardingScreen extends ConsumerWidget {
  /// Creates the [OnboardingScreen] flow.
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(a11ySettingsProvider);
    final notifier = ref.read(a11ySettingsProvider.notifier);

    final languages = <(String, String)>[
      ('sl', l10n.languageNameSl),
      ('en', l10n.languageNameEn),
      ('de', l10n.languageNameDe),
      ('sr_Latn', l10n.languageNameSrLatn),
    ];

    final languageSection = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AccessibleSection(
          header: true,
          label: l10n.onboardingChooseLanguage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.onboardingChooseLanguage,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (code, label) in languages)
                    BigButton(
                      icon: settings.localeCode == code
                          ? Icons.check_circle_rounded
                          : Icons.language_rounded,
                      label: label,
                      variant: settings.localeCode == code
                          ? BigButtonVariant.selected
                          : BigButtonVariant.outlined,
                      onPressed: () => notifier.setLocaleCode(code),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final a11ySection = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AccessibleSection(
          header: true,
          label: l10n.onboardingAccessibilityTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.onboardingAccessibilityTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.onboardingAccessibilitySubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.settingsExtraLargeText),
                subtitle: Text(l10n.settingsExtraLargeTextDesc),
                value: settings.extraLargeText,
                onChanged: notifier.setExtraLargeText,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.settingsThemeHighContrast),
                value: settings.isHighContrast,
                onChanged: (enabled) => notifier.setThemeMode(
                  enabled ? AppThemeChoice.highContrast : AppThemeChoice.system,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.settingsReadAloud),
                subtitle: Text(l10n.settingsReadAloudDesc),
                value: settings.readAloudEnabled,
                onChanged: notifier.setReadAloudEnabled,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.settingsHapticAlerts),
                subtitle: Text(l10n.settingsHapticAlertsDesc),
                value: settings.hapticAlertsEnabled,
                onChanged: notifier.setHapticAlertsEnabled,
              ),
            ],
          ),
        ),
      ),
    );

    final locationGdprSection = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AccessibleSection(
          header: true,
          label: l10n.onboardingLocationTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.onboardingLocationTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.onboardingLocationSubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  BigButton(
                    icon: Icons.my_location_rounded,
                    label: l10n.onboardingUseGps,
                    variant: !settings.locationManualMode
                        ? BigButtonVariant.selected
                        : BigButtonVariant.outlined,
                    onPressed: () => notifier.setLocationManualMode(false),
                  ),
                  BigButton(
                    icon: Icons.pin_drop_outlined,
                    label: l10n.onboardingUseManualLocation,
                    variant: settings.locationManualMode
                        ? BigButtonVariant.selected
                        : BigButtonVariant.outlined,
                    onPressed: () => notifier.setLocationManualMode(true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.onboardingConsentLocation),
                value: !settings.locationManualMode,
                onChanged: (checked) =>
                    notifier.setLocationManualMode(!(checked ?? false)),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.onboardingConsentNotifications),
                value: settings.notificationsConsent,
                onChanged: (checked) =>
                    notifier.setNotificationsConsent(checked ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.onboardingConsentAnalytics),
                value: settings.analyticsConsent,
                onChanged: (checked) =>
                    notifier.setAnalyticsConsent(checked ?? false),
              ),
            ],
          ),
        ),
      ),
    );

    final finishSection = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.onboardingAccountOptionalNote,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BigButton(
              icon: Icons.directions_bus_rounded,
              label: l10n.onboardingStartRiding,
              expanded: true,
              onPressed: () async {
                await notifier.setOnboardingDone(true);
                if (context.mounted) {
                  context.go('/');
                }
              },
            ),
            const SizedBox(height: 10),
            BigButton(
              icon: Icons.school_outlined,
              label: l10n.onboardingOpenGuide,
              variant: BigButtonVariant.outlined,
              expanded: true,
              onPressed: () => context.push('/guide'),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingWelcomeTitle),
        actions: [
          Semantics(
            button: true,
            label: l10n.a11yReadAloudButton,
            child: IconButton(
              icon: const Icon(Icons.volume_up_rounded),
              tooltip: l10n.a11yReadAloudButton,
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              onPressed: () {
                final text =
                    '${l10n.onboardingWelcomeTitle}. ${l10n.onboardingWelcomeSubtitle}';
                ref.read(readAloudProvider).speak(
                      text,
                      enabled: true,
                      localeCode: settings.localeCode,
                    );
              },
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ResponsiveContentContainer(
            child: ResponsiveBuilder(
              builder: (context, layoutSize, _) {
                final header = Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFEA2846),
                        Color(0xFFC8102E),
                        Color(0xFF6E0A19),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The white route mark sits directly on the red hero.
                      const ExcludeSemantics(
                        child: MarpromLogo(
                          size: 104,
                          background: LogoBackground.none,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.onboardingWelcomeTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.onboardingWelcomeSubtitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                    ],
                  ),
                );

                if (layoutSize == ScreenLayoutSize.expanded) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                languageSection,
                                const SizedBox(height: 16),
                                a11ySection,
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              children: [
                                locationGdprSection,
                                const SizedBox(height: 16),
                                finishSection,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: 16),
                    languageSection,
                    const SizedBox(height: 16),
                    a11ySection,
                    const SizedBox(height: 16),
                    locationGdprSection,
                    const SizedBox(height: 16),
                    finishSection,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
