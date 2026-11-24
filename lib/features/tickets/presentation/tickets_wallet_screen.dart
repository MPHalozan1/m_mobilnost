// Offline-capable ticket wallet with Active/Upcoming/Expired tabs and 2-pane expanded layout.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/accessibility/a11y_settings.dart';
import '../../../core/accessibility/semantics_helpers.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/layout/responsive_builder.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../data/models/ticket.dart';
import '../../../data/models/ticket_type.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/presentation/account_screen.dart';
import '../../account/presentation/widgets/payment_method_helpers.dart';
import '../../account/providers/account_providers.dart';
import '../providers/ticket_providers.dart';
import 'ticket_checkout_screen.dart';
import 'ticket_shop_screen.dart';
import 'ticket_view_screen.dart';

/// Displays offline-stored rider tickets across Active, Upcoming, and Expired tabs.
class TicketsWalletScreen extends ConsumerStatefulWidget {
  /// Creates a [TicketsWalletScreen].
  const TicketsWalletScreen({super.key});

  @override
  ConsumerState<TicketsWalletScreen> createState() =>
      _TicketsWalletScreenState();
}

class _TicketsWalletScreenState extends ConsumerState<TicketsWalletScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  String? _selectedTicketId;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _openShop(BuildContext context) {
    navigateWithFallback(
      context,
      '/tickets/shop',
      fallbackBuilder: (_) => const TicketShopScreen(),
    );
  }

  void _openTicketView(BuildContext context, String ticketId) {
    navigateWithFallback(
      context,
      '/tickets/view/$ticketId',
      fallbackBuilder: (_) => TicketViewScreen(ticketId: ticketId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(a11ySettingsProvider);
    final user = ref.watch(activeUserProvider);
    final ticketsAsync = ref.watch(userTicketsProvider);
    final typesAsync = ref.watch(ticketTypesProvider);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveBuilder(
          builder: (context, layoutSize, constraints) {
            final isExpanded = layoutSize == ScreenLayoutSize.expanded ||
                LayoutBreakpoints.fromWidth(
                      MediaQuery.sizeOf(context).width,
                    ) ==
                    ScreenLayoutSize.expanded;

            final header = ScreenTitle(
              title: l10n.ticketsTitle,
              eyebrow: l10n.ticketsZoneMaribor,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              trailing: BigButton(
                icon: Icons.add_rounded,
                label: l10n.ticketsBuyButton,
                onPressed: () => _openShop(context),
              ),
            );

            final allTickets = ticketsAsync.valueOrNull ?? const <Ticket>[];
            final partitioned = partitionTicketsByStatus(
              allTickets,
              referenceTime: _now,
            );
            final selectedTicket = _resolveSelectedTicket(allTickets);

            final walletColumn = DefaultTabController(
              length: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  if (user == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: GuestAuthPromptCard(
                        onSignInPressed: () => navigateWithFallback(
                          context,
                          '/account',
                          fallbackBuilder: (_) => const AccountScreen(),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: MarpromBrand.of(context).subtleFill,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: TabBar(
                        isScrollable:
                            MediaQuery.textScalerOf(context).scale(1.0) > 1.35,
                        tabs: [
                          Tab(height: 56, text: l10n.ticketsActiveTab),
                          Tab(height: 56, text: l10n.ticketsTabUpcoming),
                          Tab(height: 56, text: l10n.ticketsTabExpired),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ticketsAsync.when(
                      loading: () => const LoadingStateView(),
                      error: (_, _) => ErrorStateView(
                        onRetry: () => ref.invalidate(userTicketsProvider),
                      ),
                      data: (_) {
                        return TabBarView(
                          children: [
                            _TicketTabList(
                              tickets: partitioned.active,
                              emptyText: l10n.ticketsNoActiveTickets,
                              localeCode: settings.localeCode,
                              now: _now,
                              selectedTicketId:
                                  isExpanded ? selectedTicket?.id : null,
                              onBuyTicket: () => _openShop(context),
                              onSelectTicket: (ticket) {
                                if (isExpanded) {
                                  setState(
                                    () => _selectedTicketId = ticket.id,
                                  );
                                } else {
                                  _openTicketView(context, ticket.id);
                                }
                              },
                            ),
                            _TicketTabList(
                              tickets: partitioned.upcoming,
                              emptyText: l10n.ticketsNoUpcomingTickets,
                              localeCode: settings.localeCode,
                              now: _now,
                              selectedTicketId:
                                  isExpanded ? selectedTicket?.id : null,
                              onBuyTicket: () => _openShop(context),
                              onSelectTicket: (ticket) {
                                if (isExpanded) {
                                  setState(
                                    () => _selectedTicketId = ticket.id,
                                  );
                                } else {
                                  _openTicketView(context, ticket.id);
                                }
                              },
                            ),
                            _TicketTabList(
                              tickets: partitioned.expired,
                              emptyText: l10n.ticketsNoExpiredTickets,
                              localeCode: settings.localeCode,
                              now: _now,
                              selectedTicketId:
                                  isExpanded ? selectedTicket?.id : null,
                              onBuyTicket: () => _openShop(context),
                              onSelectTicket: (ticket) {
                                if (isExpanded) {
                                  setState(
                                    () => _selectedTicketId = ticket.id,
                                  );
                                } else {
                                  _openTicketView(context, ticket.id);
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );

            if (!isExpanded) {
              return walletColumn;
            }

            return Row(
              children: [
                Expanded(flex: 5, child: walletColumn),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 6,
                  child: _ExpandedDetailPane(
                    selectedTicket: selectedTicket,
                    localeCode: settings.localeCode,
                    now: _now,
                    isSignedIn: user != null,
                    typesAsync: typesAsync,
                    onOpenFullTicket: (id) => _openTicketView(context, id),
                    onOpenShop: () => _openShop(context),
                    onQuickBuy: (typeId) {
                      if (user == null) {
                        navigateWithFallback(
                          context,
                          '/account',
                          fallbackBuilder: (_) => const AccountScreen(),
                        );
                      } else {
                        navigateWithFallback(
                          context,
                          '/tickets/checkout/$typeId',
                          fallbackBuilder: (_) =>
                              TicketCheckoutScreen(typeId: typeId),
                        );
                      }
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Ticket? _resolveSelectedTicket(List<Ticket> allTickets) {
    if (allTickets.isEmpty) return null;
    if (_selectedTicketId != null) {
      for (final ticket in allTickets) {
        if (ticket.id == _selectedTicketId) return ticket;
      }
    }
    final active = partitionTicketsByStatus(allTickets, referenceTime: _now);
    if (active.active.isNotEmpty) return active.active.first;
    return allTickets.first;
  }
}

class _TicketTabList extends StatelessWidget {
  const _TicketTabList({
    required this.tickets,
    required this.emptyText,
    required this.localeCode,
    required this.now,
    required this.selectedTicketId,
    required this.onBuyTicket,
    required this.onSelectTicket,
  });

  final List<Ticket> tickets;
  final String emptyText;
  final String localeCode;
  final DateTime now;
  final String? selectedTicketId;
  final VoidCallback onBuyTicket;
  final ValueChanged<Ticket> onSelectTicket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (tickets.isEmpty) {
      return EmptyStateView(
        icon: Icons.confirmation_number_outlined,
        title: emptyText,
        actionLabel: l10n.ticketsBuyButton,
        onAction: onBuyTicket,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: tickets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final ticket = tickets[index];
        return FadeSlideIn.staggered(
          index: index,
          child: _WalletTicketCard(
            ticket: ticket,
            localeCode: localeCode,
            now: now,
            selected: selectedTicketId == ticket.id,
            onTap: () => onSelectTicket(ticket),
          ),
        );
      },
    );
  }
}

class _WalletTicketCard extends StatelessWidget {
  const _WalletTicketCard({
    required this.ticket,
    required this.localeCode,
    required this.now,
    required this.selected,
    required this.onTap,
  });

  final Ticket ticket;
  final String localeCode;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final status = ticket.statusAt(now);
    final (chipType, chipLabel) = _statusChipFor(l10n, status);
    final fromStr =
        TimeFormatUtils.formatDateTime24(ticket.validFrom, locale: localeCode);
    final untilStr =
        TimeFormatUtils.formatDateTime24(ticket.validUntil, locale: localeCode);
    final tone = switch (status) {
      TicketStatus.active => TicketPassTone.active,
      TicketStatus.upcoming => TicketPassTone.upcoming,
      TicketStatus.expired => TicketPassTone.expired,
    };

    return TicketPass(
      tone: tone,
      selected: selected,
      onTap: onTap,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MARPROM',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticket.localizedTitle(localeCode),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  size: 32,
                  color: Color(0xFF1C1719),
                ),
              ),
            ],
          ),
          if (status == TicketStatus.active) ...[
            const SizedBox(height: 14),
            Text(
              l10n.ticketsRemainingTime(
                formatTicketCountdown(ticket.validUntil.difference(now)),
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
      stub: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(type: chipType, label: chipLabel, compact: true),
              Text(
                l10n.ticketsDriverFallbackCode(ticket.driverFallbackCode),
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.ticketsValidFromUntil(fromStr, untilStr),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ExpandedDetailPane extends StatelessWidget {
  const _ExpandedDetailPane({
    required this.selectedTicket,
    required this.localeCode,
    required this.now,
    required this.isSignedIn,
    required this.typesAsync,
    required this.onOpenFullTicket,
    required this.onOpenShop,
    required this.onQuickBuy,
  });

  final Ticket? selectedTicket;
  final String localeCode;
  final DateTime now;
  final bool isSignedIn;
  final AsyncValue<List<TicketType>> typesAsync;
  final ValueChanged<String> onOpenFullTicket;
  final VoidCallback onOpenShop;
  final ValueChanged<String> onQuickBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (selectedTicket != null) {
      final ticket = selectedTicket!;
      final status = ticket.statusAt(now);
      final (chipType, chipLabel) = _statusChipFor(l10n, status);
      final fromStr =
          TimeFormatUtils.formatDateTime24(ticket.validFrom, locale: localeCode);
      final untilStr = TimeFormatUtils.formatDateTime24(
        ticket.validUntil,
        locale: localeCode,
      );

      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text(
                        ticket.localizedTitle(localeCode),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      StatusChip(type: chipType, label: chipLabel),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black26),
                      ),
                      child: QrImageView(
                        data: ticket.qrPayload,
                        size: 180,
                        backgroundColor: Colors.white,
                        semanticsLabel: l10n.a11yQrCode,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.ticketsValidFromUntil(fromStr, untilStr),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.ticketsDriverFallbackCode(ticket.driverFallbackCode),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 18),
                  BigButton(
                    icon: Icons.qr_code_2_rounded,
                    label: l10n.ticketsViewTitle,
                    expanded: true,
                    onPressed: () => onOpenFullTicket(ticket.id),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Text(
              l10n.ticketsShopTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            BigButton(
              icon: Icons.storefront_outlined,
              label: l10n.commonShowMore,
              variant: BigButtonVariant.outlined,
              onPressed: onOpenShop,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const DemoPaymentBanner(),
        const SizedBox(height: 16),
        typesAsync.when(
          loading: () => const LoadingStateView(),
          error: (_, _) => ErrorStateView(onRetry: onOpenShop),
          data: (types) => Column(
            children: [
              for (final type in types.take(4)) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                type.localizedTitle(localeCode),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              TimeFormatUtils.formatEur(
                                type.priceEur,
                                locale: localeCode,
                              ),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          type.localizedDescription(localeCode),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        BigButton(
                          icon: Icons.shopping_cart_checkout_rounded,
                          label: isSignedIn
                              ? l10n.ticketsBuyButton
                              : l10n.accountSignIn,
                          expanded: true,
                          onPressed: () => onQuickBuy(type.id),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

(TransitStatusType, String) _statusChipFor(
  AppLocalizations l10n,
  TicketStatus status,
) {
  switch (status) {
    case TicketStatus.active:
      return (TransitStatusType.onTime, l10n.ticketsActiveTab);
    case TicketStatus.upcoming:
      return (TransitStatusType.info, l10n.ticketsTabUpcoming);
    case TicketStatus.expired:
      return (TransitStatusType.warning, l10n.ticketsTabExpired);
  }
}
