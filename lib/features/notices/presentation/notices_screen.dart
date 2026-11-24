// Service notices, disruptions filter, smart alert toggles, and vibration alert test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/a11y_settings.dart';
import '../../../core/accessibility/haptic_cues.dart';
import '../../../core/accessibility/read_aloud.dart';
import '../../../core/accessibility/semantics_helpers.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/layout/responsive_builder.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../data/models/service_notice.dart';
import '../../../data/repositories/repository_providers.dart';
import '../domain/smart_alerts_provider.dart';

/// Filter options for [NoticesScreen].
enum NoticesFilter {
  /// Show all informational, delay, and disruption notices.
  all,

  /// Show only active delays and disruptions.
  disruptions,
}

/// Displays active Marprom transit notices, disruption filters, and smart alerts.
class NoticesScreen extends ConsumerStatefulWidget {
  /// Creates the [NoticesScreen] view.
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  NoticesFilter _filter = NoticesFilter.all;
  bool _showVisualTestBanner = false;

  Future<void> _triggerVisualAndHapticTest() async {
    final settings = ref.read(a11ySettingsProvider);
    final l10n = context.l10n;
    setState(() => _showVisualTestBanner = true);

    await HapticCues.trigger(
      HapticCueType.disruption,
      enabled: settings.hapticAlertsEnabled,
      soundOptional: settings.soundAlertsOptional,
    );

    if (settings.readAloudEnabled) {
      await ref.read(readAloudProvider).speak(
            l10n.homeActiveDisruptionAlert,
            enabled: true,
            localeCode: settings.localeCode,
          );
    }
    if (mounted) {
      announceForAccessibility(context, l10n.homeActiveDisruptionAlert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(a11ySettingsProvider);
    final smartAlerts = ref.watch(smartAlertsProvider);
    final noticesAsync = ref.watch(serviceNoticesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.noticesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: l10n.noticesMarkAllRead,
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            onPressed: () => ref.read(noticeRepositoryProvider).markAllAsRead(),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          if (_showVisualTestBanner)
            _VisualTestAlertBanner(
              onDismiss: () => setState(() => _showVisualTestBanner = false),
            ),
          Expanded(
            child: noticesAsync.when(
              loading: () => const LoadingStateView(),
              error: (_, _) => ErrorStateView(
                onRetry: () => ref.invalidate(serviceNoticesStreamProvider),
              ),
              data: (allNotices) {
                final filtered = _filter == NoticesFilter.all
                    ? allNotices
                    : allNotices
                        .where(
                          (n) =>
                              n.severity == NoticeSeverity.disruption ||
                              n.severity == NoticeSeverity.delay,
                        )
                        .toList(growable: false);

                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    ResponsiveContentContainer(
                      child: ResponsiveBuilder(
                        builder: (context, layoutSize, _) {
                          final smartCard = _SmartAlertsCard(
                            smartAlerts: smartAlerts,
                            onTestAlert: _triggerVisualAndHapticTest,
                          );

                          final noticesSection = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FilterTabs(
                                selected: _filter,
                                onChanged: (next) =>
                                    setState(() => _filter = next),
                              ),
                              const SizedBox(height: 12),
                              if (allNotices.any((n) => !n.isRead)) ...[
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(56, 56),
                                    ),
                                    icon: const Icon(Icons.done_all_rounded),
                                    label: Text(l10n.noticesMarkAllRead),
                                    onPressed: () => ref
                                        .read(noticeRepositoryProvider)
                                        .markAllAsRead(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (filtered.isEmpty)
                                EmptyStateView(
                                  icon: Icons.notifications_none_rounded,
                                  title: l10n.noticesEmpty,
                                )
                              else
                                for (final notice in filtered) ...[
                                  _NoticeCard(
                                    notice: notice,
                                    localeCode: settings.localeCode,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                            ],
                          );

                          if (layoutSize == ScreenLayoutSize.expanded) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 5, child: noticesSection),
                                const SizedBox(width: 24),
                                Expanded(flex: 4, child: smartCard),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              smartCard,
                              const SizedBox(height: 16),
                              noticesSection,
                            ],
                          );
                        },
                      ),
                    ),
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

class _VisualTestAlertBanner extends StatelessWidget {
  const _VisualTestAlertBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusColors =
        Theme.of(context).extension<MarpromStatusColors>() ??
            MarpromStatusColors.light;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: statusColors.disruptionBg,
          border: Border(
            bottom: BorderSide(color: statusColors.disruptionFg, width: 2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.notification_important_rounded,
              color: statusColors.disruptionFg,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeActiveDisruptionAlert,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: statusColors.disruptionFg,
                        ),
                  ),
                  Text(
                    l10n.noticesSmartAlertsDesc,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: statusColors.disruptionFg,
                        ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: l10n.a11yCloseButton,
              child: IconButton(
                icon: Icon(Icons.close_rounded, color: statusColors.disruptionFg),
                tooltip: l10n.commonClose,
                constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                onPressed: onDismiss,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.selected,
    required this.onChanged,
  });

  final NoticesFilter selected;
  final ValueChanged<NoticesFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _FilterChipButton(
          label: l10n.noticesAllTab,
          icon: Icons.notifications_outlined,
          isSelected: selected == NoticesFilter.all,
          onPressed: () => onChanged(NoticesFilter.all),
        ),
        _FilterChipButton(
          label: l10n.noticesDisruptionsTab,
          icon: Icons.report_problem_outlined,
          isSelected: selected == NoticesFilter.disruptions,
          onPressed: () => onChanged(NoticesFilter.disruptions),
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BigButton(
      icon: icon,
      label: label,
      variant: isSelected ? BigButtonVariant.selected : BigButtonVariant.outlined,
      onPressed: onPressed,
    );
  }
}

class _SmartAlertsCard extends ConsumerWidget {
  const _SmartAlertsCard({
    required this.smartAlerts,
    required this.onTestAlert,
  });

  final SmartAlertsState smartAlerts;
  final VoidCallback onTestAlert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(smartAlertsProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.noticesSmartAlertsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.noticesSmartAlertsDesc,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.noticesSmartBusArriving),
              value: smartAlerts.busArrivingSoon,
              onChanged: notifier.setBusArrivingSoon,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.noticesSmartLineDelayed),
              value: smartAlerts.favoriteLineDelayed,
              onChanged: notifier.setFavoriteLineDelayed,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.noticesSmartTicketExpiring),
              value: smartAlerts.ticketExpiringSoon,
              onChanged: notifier.setTicketExpiringSoon,
            ),
            const SizedBox(height: 12),
            BigButton(
              icon: Icons.vibration_rounded,
              label: l10n.noticesPreviewVibration,
              variant: BigButtonVariant.secondary,
              expanded: true,
              onPressed: onTestAlert,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends ConsumerWidget {
  const _NoticeCard({
    required this.notice,
    required this.localeCode,
  });

  final ServiceNotice notice;
  final String localeCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final chipType = switch (notice.severity) {
      NoticeSeverity.info => TransitStatusType.info,
      NoticeSeverity.delay => TransitStatusType.late,
      NoticeSeverity.disruption => TransitStatusType.disruption,
    };

    final title = notice.localizedTitle(localeCode);
    final body = notice.localizedBody(localeCode);
    final hint = notice.localizedAlternativeHint(localeCode);
    final hasAlternative = notice.severity == NoticeSeverity.disruption ||
        notice.severity == NoticeSeverity.delay;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: notice.isRead ? scheme.outlineVariant : scheme.primary,
          width: notice.isRead ? 1 : 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChip(type: chipType),
                Text(
                  TimeFormatUtils.formatDateTime24(
                    notice.publishedAt,
                    locale: localeCode,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (notice.isRead)
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (notice.affectedLineIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.noticesAffectedLines(notice.affectedLineIds.join(', ')),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
            if (hint != null && hint.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hint,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(56, 56),
                  ),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: Text(l10n.a11yReadAloudButton),
                  onPressed: () {
                    final spoken =
                        hint != null ? '$title. $body $hint' : '$title. $body';
                    ref.read(readAloudProvider).speak(
                          spoken,
                          enabled: true,
                          localeCode: localeCode,
                        );
                  },
                ),
                if (!notice.isRead)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(56, 56),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l10n.commonDone),
                    onPressed: () =>
                        ref.read(noticeRepositoryProvider).markAsRead(notice.id),
                  ),
                if (hasAlternative)
                  BigButton(
                    icon: Icons.alt_route_rounded,
                    label: l10n.noticesTriggerAlternative,
                    variant: BigButtonVariant.primary,
                    onPressed: () => context.go('/plan'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
