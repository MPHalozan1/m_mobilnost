// Accessible Settings screen with language, theme, a11y, data, and usability console.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/a11y_settings.dart';
import '../../../core/accessibility/favorites_provider.dart';
import '../../../core/accessibility/semantics_helpers.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/layout/responsive_builder.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/bus_stop.dart';
import '../../../data/repositories/repository_providers.dart';
import '../domain/usability_tracker.dart';

final _settingsStopsProvider = FutureProvider<List<BusStop>>((ref) {
  return ref.watch(lineRepositoryProvider).getStops();
});

/// Comprehensive accessible Settings screen for M Mobilnost 2.0.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates the [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const List<int> _seedChoices = [7, 42, 101, 2026];
  String _selectedScenarioId = 'next_bus';
  String? _exportedText;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(usabilityTrackerProvider).isRunning) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _copyAndShowExport(String output) async {
    setState(() => _exportedText = output);
    try {
      await Clipboard.setData(ClipboardData(text: output));
    } catch (_) {
      // Ignore unavailable clipboard channels in headless tests.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(a11ySettingsProvider);
    final settingsNotifier = ref.read(a11ySettingsProvider.notifier);
    final favorites = ref.watch(favoritesProvider);
    final favoritesNotifier = ref.read(favoritesProvider.notifier);
    final simulatedOffline = ref.watch(simulatedOfflineProvider);
    final stopsAsync = ref.watch(_settingsStopsProvider);

    final languageSection = _SectionCard(
      title: l10n.settingsSectionLanguage,
      child: _LanguageSelector(
        selectedCode: settings.localeCode,
        onSelected: settingsNotifier.setLocaleCode,
      ),
    );

    final appearanceSection = _SectionCard(
      title: l10n.settingsSectionAppearance,
      child: _ThemeSelector(
        selected: settings.themeMode,
        onSelected: settingsNotifier.setThemeMode,
      ),
    );

    final accessibilitySection = _SectionCard(
      title: l10n.settingsSectionAccessibility,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsExtraLargeText),
            subtitle: Text(l10n.settingsExtraLargeTextDesc),
            value: settings.extraLargeText,
            onChanged: settingsNotifier.setExtraLargeText,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsReducedMotion),
            subtitle: Text(l10n.settingsReducedMotionDesc),
            value: settings.reducedMotion,
            onChanged: settingsNotifier.setReducedMotion,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsReadAloud),
            subtitle: Text(l10n.settingsReadAloudDesc),
            value: settings.readAloudEnabled,
            onChanged: settingsNotifier.setReadAloudEnabled,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsVoiceInput),
            subtitle: Text(l10n.settingsVoiceInputDesc),
            value: settings.voiceInputEnabled,
            onChanged: settingsNotifier.setVoiceInputEnabled,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsHapticAlerts),
            subtitle: Text(l10n.settingsHapticAlertsDesc),
            value: settings.hapticAlertsEnabled,
            onChanged: settingsNotifier.setHapticAlertsEnabled,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsSoundAlerts),
            subtitle: Text(l10n.settingsSoundAlertsDesc),
            value: settings.soundAlertsOptional,
            onChanged: settingsNotifier.setSoundAlertsOptional,
          ),
        ],
      ),
    );

    final dataSection = _SectionCard(
      title: l10n.settingsSectionData,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsShowDataSource),
            subtitle: Text(l10n.settingsShowDataSourceDesc),
            value: settings.showDataSource,
            onChanged: settingsNotifier.setShowDataSource,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsUseSimulatedLive),
            subtitle: Text(l10n.settingsUseSimulatedLiveDesc),
            value: settings.useSimulatedLive,
            onChanged: settingsNotifier.setUseSimulatedLive,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.settingsSimulationSeed,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final seed in _seedChoices)
                BigButton(
                  icon: settings.simulationSeed == seed
                      ? Icons.check_rounded
                      : Icons.casino_outlined,
                  label: '$seed',
                  variant: settings.simulationSeed == seed
                      ? BigButtonVariant.selected
                      : BigButtonVariant.outlined,
                  onPressed: () => settingsNotifier.setSimulationSeed(seed),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsLocationManual),
            subtitle: Text(l10n.settingsLocationManualDesc),
            value: settings.locationManualMode,
            onChanged: settingsNotifier.setLocationManualMode,
          ),
          if (stopsAsync.valueOrNull != null &&
              stopsAsync.valueOrNull!.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(favorites.manualStopId),
              isExpanded: true,
              initialValue: stopsAsync.valueOrNull!.any(
                (s) => s.id == favorites.manualStopId,
              )
                  ? favorites.manualStopId
                  : stopsAsync.valueOrNull!.first.id,
              decoration: InputDecoration(
                labelText: l10n.mapSelectManualStop,
              ),
              items: [
                for (final stop in stopsAsync.valueOrNull!)
                  DropdownMenuItem<String>(
                    value: stop.id,
                    child: Text(stop.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (stopId) {
                if (stopId != null) {
                  favoritesNotifier.setManualStop(stopId);
                }
              },
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.badgeOfflineTitle),
            subtitle: Text(l10n.badgeOfflineBody),
            value: simulatedOffline,
            onChanged: (value) =>
                ref.read(simulatedOfflineProvider.notifier).state = value,
          ),
          const SizedBox(height: 12),
          BigButton(
            icon: Icons.cleaning_services_outlined,
            label: l10n.settingsClearLocalData,
            variant: BigButtonVariant.outlined,
            expanded: true,
            onPressed: () async {
              await ref.read(timetableRepositoryProvider).clearCache();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.settingsClearLocalDataDone)),
              );
            },
          ),
        ],
      ),
    );

    final privacyAndHelpSection = _SectionCard(
      title: l10n.settingsSectionPrivacy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BigButton(
            icon: Icons.privacy_tip_outlined,
            label: l10n.accountGdprTitle,
            variant: BigButtonVariant.outlined,
            expanded: true,
            onPressed: () => context.push('/account'),
          ),
          const SizedBox(height: 10),
          BigButton(
            icon: Icons.school_outlined,
            label: l10n.settingsOpenGuide,
            variant: BigButtonVariant.outlined,
            expanded: true,
            onPressed: () => context.push('/guide'),
          ),
          const SizedBox(height: 10),
          BigButton(
            icon: Icons.restart_alt_rounded,
            label: l10n.settingsResetOnboarding,
            variant: BigButtonVariant.outlined,
            expanded: true,
            onPressed: () async {
              await settingsNotifier.setOnboardingDone(false);
              if (context.mounted) {
                context.push('/onboarding');
              }
            },
          ),
        ],
      ),
    );

    final usabilitySection = _SectionCard(
      title: l10n.settingsSectionUsability,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsUsabilityTestMode),
            subtitle: Text(l10n.settingsUsabilityTestModeDesc),
            value: settings.usabilityTestMode,
            onChanged: settingsNotifier.setUsabilityTestMode,
          ),
          if (settings.usabilityTestMode) ...[
            const SizedBox(height: 12),
            _UsabilityConsole(
              selectedScenarioId: _selectedScenarioId,
              onScenarioChanged: (id) =>
                  setState(() => _selectedScenarioId = id),
              exportedText: _exportedText,
              onExport: _copyAndShowExport,
            ),
          ],
        ],
      ),
    );

    final aboutSection = _SectionCard(
      title: l10n.settingsAboutTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appBrand,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.settingsAboutBody,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.badgeSimulatedDisclaimer,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                ResponsiveContentContainer(
                  child: ResponsiveBuilder(
                    builder: (context, layoutSize, _) {
                      final leftColumn = UsabilityTapObserver(
                        child: Column(
                          children: [
                            languageSection,
                            const SizedBox(height: 16),
                            appearanceSection,
                            const SizedBox(height: 16),
                            accessibilitySection,
                          ],
                        ),
                      );

                      final rightColumn = Column(
                        children: [
                          UsabilityTapObserver(
                            child: Column(
                              children: [
                                dataSection,
                                const SizedBox(height: 16),
                                privacyAndHelpSection,
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          usabilitySection,
                          const SizedBox(height: 16),
                          aboutSection,
                        ],
                      );

                      if (layoutSize == ScreenLayoutSize.expanded) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: leftColumn),
                            const SizedBox(width: 24),
                            Expanded(child: rightColumn),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          leftColumn,
                          const SizedBox(height: 16),
                          rightColumn,
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Grouped-list style: the section title sits above its card.
    return AccessibleSection(
      header: true,
      label: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: child,
          ),
        ],
      ),
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
    final options = <(String, Locale, String)>[
      ('sl', const Locale('sl'), l10n.languageNameSl),
      ('en', const Locale('en'), l10n.languageNameEn),
      ('de', const Locale('de'), l10n.languageNameDe),
      (
        'sr_Latn',
        const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
        l10n.languageNameSrLatn,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsLanguage,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (code, locale, label) in options)
              BigButton(
                icon: selectedCode == code
                    ? Icons.check_circle_rounded
                    : Icons.language_rounded,
                label: label,
                semanticLabel: '$label (${locale.toLanguageTag()})',
                variant: selectedCode == code
                    ? BigButtonVariant.selected
                    : BigButtonVariant.outlined,
                onPressed: () => onSelected(code),
              ),
          ],
        ),
      ],
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({
    required this.selected,
    required this.onSelected,
  });

  final AppThemeChoice selected;
  final ValueChanged<AppThemeChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <(AppThemeChoice, IconData, String)>[
      (AppThemeChoice.system, Icons.brightness_auto_rounded, l10n.settingsThemeSystem),
      (AppThemeChoice.light, Icons.light_mode_outlined, l10n.settingsThemeLight),
      (AppThemeChoice.dark, Icons.dark_mode_outlined, l10n.settingsThemeDark),
      (
        AppThemeChoice.highContrast,
        Icons.contrast_rounded,
        l10n.settingsThemeHighContrast,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsThemeMode,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (choice, icon, label) in options)
              BigButton(
                icon: icon,
                label: label,
                variant: selected == choice
                    ? BigButtonVariant.selected
                    : BigButtonVariant.outlined,
                onPressed: () => onSelected(choice),
              ),
          ],
        ),
      ],
    );
  }
}

class _UsabilityConsole extends ConsumerWidget {
  const _UsabilityConsole({
    required this.selectedScenarioId,
    required this.onScenarioChanged,
    required this.exportedText,
    required this.onExport,
  });

  final String selectedScenarioId;
  final ValueChanged<String> onScenarioChanged;
  final String? exportedText;
  final Future<void> Function(String output) onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tracker = ref.read(usabilityTrackerProvider.notifier);
    final state = ref.watch(usabilityTrackerProvider);
    final seconds = tracker.elapsedSeconds();
    final scheme = Theme.of(context).colorScheme;

    final scenarios = <(String, String)>[
      ('next_bus', l10n.homeNextDepartures),
      ('plan_trip', l10n.homePlanTripAction),
      ('buy_ticket', l10n.homeBuyTicketAction),
      ('check_notices', l10n.navNotices),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (id, label) in scenarios)
              BigButton(
                icon: selectedScenarioId == id
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                label: label,
                variant: selectedScenarioId == id
                    ? BigButtonVariant.secondary
                    : BigButtonVariant.outlined,
                onPressed: state.isRunning ? null : () => onScenarioChanged(id),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Semantics(
            liveRegion: true,
            child: Text(
              l10n.settingsUsabilitySummary(
                seconds,
                state.tapCount,
                state.errorCount,
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (!state.isRunning)
              BigButton(
                icon: Icons.play_arrow_rounded,
                label: l10n.settingsUsabilityStart,
                onPressed: () => tracker.startScenario(selectedScenarioId),
              )
            else ...[
              BigButton(
                icon: Icons.touch_app_outlined,
                label: '${l10n.commonAdd} (+1)',
                variant: BigButtonVariant.secondary,
                onPressed: tracker.recordTap,
              ),
              BigButton(
                icon: Icons.error_outline_rounded,
                label: l10n.settingsUsabilityRecordError,
                variant: BigButtonVariant.outlined,
                onPressed: tracker.recordError,
              ),
              BigButton(
                icon: Icons.stop_rounded,
                label: l10n.settingsUsabilityFinish,
                onPressed: tracker.finishScenario,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            BigButton(
              icon: Icons.table_chart_outlined,
              label: l10n.settingsUsabilityExportCsv,
              variant: BigButtonVariant.outlined,
              onPressed: () => onExport(tracker.exportCsv()),
            ),
            BigButton(
              icon: Icons.data_object_rounded,
              label: l10n.settingsUsabilityExportJson,
              variant: BigButtonVariant.outlined,
              onPressed: () => onExport(tracker.exportJson()),
            ),
          ],
        ),
        if (exportedText != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: SelectableText(
              exportedText!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        ],
      ],
    );
  }
}
