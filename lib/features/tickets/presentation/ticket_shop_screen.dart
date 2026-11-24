// Ticket shop screen allowing guest browsing, fare category filtering, and NFC/QR checkout.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/a11y_settings.dart';
import '../../../core/accessibility/semantics_helpers.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/layout/responsive_builder.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/ticket_type.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/presentation/account_screen.dart';
import '../../account/presentation/widgets/payment_method_helpers.dart';
import '../../account/providers/account_providers.dart';
import '../providers/ticket_providers.dart';
import 'ticket_checkout_screen.dart';

/// Displays all official Marprom EUR ticket types with category filters and NFC/QR checkout.
class TicketShopScreen extends ConsumerStatefulWidget {
  /// Creates a [TicketShopScreen].
  const TicketShopScreen({super.key});

  @override
  ConsumerState<TicketShopScreen> createState() => _TicketShopScreenState();
}

class _TicketShopScreenState extends ConsumerState<TicketShopScreen> {
  TicketFareGroup? _selectedGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(a11ySettingsProvider);
    final typesAsync = ref.watch(ticketTypesProvider);
    final user = ref.watch(activeUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ticketsShopTitle),
      ),
      body: typesAsync.when(
        loading: () => const LoadingStateView(),
        error: (_, _) => ErrorStateView(
          onRetry: () => ref.invalidate(ticketTypesProvider),
        ),
        data: (types) {
          if (types.isEmpty) {
            return EmptyStateView(
              icon: Icons.confirmation_number_outlined,
              title: l10n.commonEmpty,
            );
          }

          final filtered = _selectedGroup == null
              ? types
              : types
                  .where((t) => t.fareGroup == _selectedGroup)
                  .toList(growable: false);

          return ListView(
            children: [
              ResponsiveContentContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [
                            MarpromColors.marpromCharcoal,
                            MarpromColors.marpromBurgundy,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Row(
                            children: [
                              Icon(Icons.nfc_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Marprom NFC & QR vozovnice (od 1. 6. 2026)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Na avtobusih Marprom plačujete brez gotovine: z bančno kartico ali telefonom (NFC HCE) ter QR kodo. Enkratna vožnja vključuje 75 min brezplačnega prestopanja.',
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const DemoPaymentBanner(),
                    if (user != null &&
                        (user.isYouthEligible || user.isSeniorEligible)) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
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
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text(l10n.commonAll),
                            selected: _selectedGroup == null,
                            onSelected: (_) =>
                                setState(() => _selectedGroup = null),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Enkratne & 10x'),
                            selected: _selectedGroup ==
                                TicketFareGroup.singleAndCoupon,
                            onSelected: (_) => setState(
                              () => _selectedGroup =
                                  TicketFareGroup.singleAndCoupon,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Dnevne & večdnevne'),
                            selected: _selectedGroup ==
                                TicketFareGroup.dailyAndMultiDay,
                            onSelected: (_) => setState(
                              () => _selectedGroup =
                                  TicketFareGroup.dailyAndMultiDay,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Mesečne / IJPP / Letne'),
                            selected: _selectedGroup ==
                                TicketFareGroup.monthlyAndAnnual,
                            onSelected: (_) => setState(
                              () => _selectedGroup =
                                  TicketFareGroup.monthlyAndAnnual,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('P+R'),
                            selected:
                                _selectedGroup == TicketFareGroup.parkAndRide,
                            onSelected: (_) => setState(
                              () =>
                                  _selectedGroup = TicketFareGroup.parkAndRide,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ResponsiveBuilder(
                      builder: (context, layoutSize, constraints) {
                        final columns =
                            layoutSize == ScreenLayoutSize.expanded ? 2 : 1;
                        if (columns == 1) {
                          return Column(
                            children: [
                              for (final type in filtered) ...[
                                _TicketTypeCard(
                                  type: type,
                                  localeCode: settings.localeCode,
                                  onBuy: () => _handleBuyPressed(
                                    context,
                                    ref,
                                    type.id,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          );
                        }

                        final cardWidth = (constraints.maxWidth - 16) / 2;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final type in filtered)
                              SizedBox(
                                width: cardWidth,
                                child: _TicketTypeCard(
                                  type: type,
                                  localeCode: settings.localeCode,
                                  onBuy: () => _handleBuyPressed(
                                    context,
                                    ref,
                                    type.id,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleBuyPressed(
    BuildContext context,
    WidgetRef ref,
    String typeId,
  ) async {
    final user = ref.read(activeUserProvider);
    if (user == null) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final l10n = dialogContext.l10n;
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: GuestAuthPromptCard(
                  secondaryLabel: l10n.commonClose,
                  onSecondaryPressed: () => Navigator.of(dialogContext).pop(),
                  onSignInPressed: () {
                    Navigator.of(dialogContext).pop();
                    navigateWithFallback(
                      context,
                      '/account',
                      fallbackBuilder: (_) => const AccountScreen(),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
      return;
    }

    navigateWithFallback(
      context,
      '/tickets/checkout/$typeId',
      fallbackBuilder: (_) => TicketCheckoutScreen(typeId: typeId),
    );
  }
}

class _TicketTypeCard extends StatelessWidget {
  const _TicketTypeCard({
    required this.type,
    required this.localeCode,
    required this.onBuy,
  });

  final TicketType type;
  final String localeCode;
  final VoidCallback onBuy;

  String? _durationChipLabel(AppLocalizations l10n) {
    if (type.durationMinutes < 180) {
      return l10n.commonMinutesShort(type.durationMinutes);
    }
    if (type.durationMinutes == 1440) {
      return l10n.commonHoursShort(24);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final priceText =
        TimeFormatUtils.formatEur(type.priceEur, locale: localeCode);
    final durationChip = _durationChipLabel(l10n);

    return SurfaceCard(
      onTap: onBuy,
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drop the decorative icon at very large text sizes so the
                // title and price keep their room.
                if (MediaQuery.textScalerOf(context).scale(1.0) <= 1.5) ...[
                  const IconWell(
                    icon: Icons.confirmation_number_outlined,
                    size: 46,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    type.localizedTitle(localeCode),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  priceText,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: scheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              type.localizedDescription(localeCode),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(
                  type: TransitStatusType.info,
                  label: l10n.ticketsZoneMaribor,
                  compact: true,
                ),
                if (durationChip != null)
                  StatusChip(
                    type: TransitStatusType.onTime,
                    label: durationChip,
                    compact: true,
                  ),
                if (type.isYouthOnly)
                  StatusChip(
                    type: TransitStatusType.info,
                    label: l10n.accountYouthEligible,
                    compact: true,
                  ),
                if (type.isSeniorOnly)
                  StatusChip(
                    type: TransitStatusType.onTime,
                    label: l10n.accountSeniorEligible,
                    compact: true,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            BigButton(
              icon: Icons.shopping_cart_checkout_rounded,
              label: l10n.ticketsBuyButton,
              variant: BigButtonVariant.secondary,
              expanded: true,
              onPressed: onBuy,
            ),
          ],
        ),
    );
  }
}
