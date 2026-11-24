// Marprom Mestni promet & Elektronske vozovnice Portal page (`/tickets`) with category filters,
// phone NFC / contactless bank-card pay highlights, 17-digit CUID smartcard top-up, and active QR wallet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/accessibility/a11y_settings.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/ticket.dart';
import '../../../../data/models/ticket_type.dart';
import '../../../../data/seed/seed_tickets.dart';
import '../../../account/providers/account_providers.dart';
import '../../../tickets/providers/ticket_providers.dart';

/// Marprom Web Tickets & Fares Page (`/tickets`) presenting official Mestni promet fares (June 2026),
/// Elektronske vozovnice / CUID card top-up, phone NFC chip validation, and QR ticket wallet access.
class WebTicketsPage extends ConsumerStatefulWidget {
  /// Creates the [WebTicketsPage].
  const WebTicketsPage({super.key});

  @override
  ConsumerState<WebTicketsPage> createState() => _WebTicketsPageState();
}

class _WebTicketsPageState extends ConsumerState<WebTicketsPage> {
  TicketFareGroup? _selectedGroup;
  final TextEditingController _cuidController = TextEditingController();
  String? _cuidStatusMessage;

  @override
  void dispose() {
    _cuidController.dispose();
    super.dispose();
  }

  void _validateCuid() {
    final digits = _cuidController.text.replaceAll(RegExp(r'\D'), '');
    setState(() {
      if (digits.length == 17) {
        _cuidStatusMessage =
            'Kartica Marprom / IJPP ($digits) prepoznana — izberite vozovnico ali paket 10 voženj spodaj.';
      } else {
        _cuidStatusMessage =
            'Vnesite vseh 17 števk CUID številke na hrbtni strani kartice Marprom ali IJPP (trenutno: ${digits.length}/17).';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = ref.watch(a11ySettingsProvider).localeCode;
    final user = ref.watch(activeUserProvider);
    final tickets = ref.watch(userTicketsProvider).valueOrNull ?? const <Ticket>[];
    final activeTickets = partitionTicketsByStatus(tickets).active;
    final scheme = Theme.of(context).colorScheme;

    final filteredTickets = _selectedGroup == null
        ? seedTicketTypes
        : seedTicketTypes
            .where((t) => t.fareGroup == _selectedGroup)
            .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Marprom Crimson Hero Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MarpromColors.marpromCharcoal,
                      MarpromColors.marpromBurgundy,
                      MarpromColors.marpromRed,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'URADNI CENIK JMPP MARPROM • ELEKTRONSKE VOZOVNICE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Vozovnice in cenik mestnega prometa Marprom',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Brezgotovinsko poslovanje: plačilo z vgrajenim NFC čipom telefona, brezstično bančno kartico (Visa / Mastercard / Apple Pay / Google Pay / VALU) ter takojšnja NFC HCE + QR vozovnica s 75-minutnim brezplačnim prestopanjem.',
                                style: TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontSize: 14.5,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: MarpromColors.marpromRed,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              onPressed: () =>
                                  context.go('/tickets/checkout/single'),
                              icon: const Icon(Icons.nfc_rounded),
                              label: const Text(
                                'Kupi enkratno (1,50 €)',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white54),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                              ),
                              onPressed: () => context.go('/tickets/shop'),
                              icon: const Icon(Icons.shopping_bag_rounded),
                              label: const Text('Odpri spletno trgovino'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: const [
                        _TicketFeaturePill(
                          icon: Icons.contactless_rounded,
                          text: 'Vgrajeni NFC čip telefona (HCE)',
                        ),
                        _TicketFeaturePill(
                          icon: Icons.qr_code_2_rounded,
                          text: 'Digitalna QR vozovnica + zaščita s časovnikom',
                        ),
                        _TicketFeaturePill(
                          icon: Icons.transfer_within_a_station_rounded,
                          text: '75 min brezplačnega prestopanja (G1–G6 & P7–P19)',
                        ),
                        _TicketFeaturePill(
                          icon: Icons.no_accounts_outlined,
                          text: 'Brez gotovine pri vozniku (kartice / telefon)',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Active Wallet Quick-Pass + 17-digit CUID Elektronska kartica Top-Up Strip
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSplit = constraints.maxWidth >= 920;
                  final activePassCard = Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: MarpromColors.marpromRed
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.qr_code_scanner_rounded,
                                  color: MarpromColors.marpromRed,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activeTickets.isNotEmpty
                                          ? 'Aktivna NFC / QR vozovnica (${activeTickets.length})'
                                          : 'Vaša NFC & QR denarnica vozovnic',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      user == null
                                          ? 'Prijavite se z Google računom za takojšnji nakup in shranitev vozovnice.'
                                          : 'Prijavljeni kot ${user.name} (${user.email})',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (activeTickets.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: MarpromColors.mobilityGreen
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: MarpromColors.mobilityGreen
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: MarpromColors.mobilityGreen,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${activeTickets.first.localizedTitle(localeCode)} • Koda: ${activeTickets.first.driverFallbackCode}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () => context.go(
                                      '/tickets/view/${activeTickets.first.id}',
                                    ),
                                    child: const Text('Prikaži NFC / QR'),
                                  ),
                                ],
                              ),
                            ),
                          ] else
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: MarpromColors.marpromRed,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () =>
                                      context.go('/tickets/checkout/single'),
                                  icon: const Icon(Icons.credit_card_rounded),
                                  label: const Text('Kupi 75-min vozovnico'),
                                ),
                                if (user == null)
                                  OutlinedButton.icon(
                                    onPressed: () => context.go('/account'),
                                    icon: const Icon(Icons.login_rounded),
                                    label: const Text('Prijava / Google račun'),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );

                  final cuidTopUpCard = Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0057B8)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.nfc_rounded,
                                  color: Color(0xFF0057B8),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Polnitev kartice Marprom / IJPP (CUID)',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      'Vnesite 17-mestno številko kartice (cena kartice 3,00 €, aktivacija na busu do 1 ure).',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _cuidController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: '17-mestni CUID (npr. 12345678901234567)',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed: _validateCuid,
                                child: const Text('Preveri CUID'),
                              ),
                            ],
                          ),
                          if (_cuidStatusMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _cuidStatusMessage!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );

                  if (isSplit) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: activePassCard),
                        const SizedBox(width: 16),
                        Expanded(child: cuidTopUpCard),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      activePassCard,
                      const SizedBox(height: 16),
                      cuidTopUpCard,
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Official Marprom Category Tabs
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('Vse vozovnice (${seedTicketTypes.length})'),
                    selected: _selectedGroup == null,
                    selectedColor:
                        MarpromColors.marpromRed.withValues(alpha: 0.16),
                    onSelected: (_) => setState(() => _selectedGroup = null),
                  ),
                  ChoiceChip(
                    label: const Text('Enkratne & 10 voženj'),
                    selected: _selectedGroup == TicketFareGroup.singleAndCoupon,
                    selectedColor:
                        MarpromColors.marpromRed.withValues(alpha: 0.16),
                    onSelected: (_) => setState(
                      () => _selectedGroup = TicketFareGroup.singleAndCoupon,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Dnevne & večdnevne'),
                    selected:
                        _selectedGroup == TicketFareGroup.dailyAndMultiDay,
                    selectedColor:
                        MarpromColors.marpromRed.withValues(alpha: 0.16),
                    onSelected: (_) => setState(
                      () => _selectedGroup = TicketFareGroup.dailyAndMultiDay,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Mesečne, šolske, IJPP & letne'),
                    selected:
                        _selectedGroup == TicketFareGroup.monthlyAndAnnual,
                    selectedColor:
                        MarpromColors.marpromRed.withValues(alpha: 0.16),
                    onSelected: (_) => setState(
                      () => _selectedGroup = TicketFareGroup.monthlyAndAnnual,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('P+R Parkiraj & presedi'),
                    selected: _selectedGroup == TicketFareGroup.parkAndRide,
                    selectedColor:
                        MarpromColors.marpromRed.withValues(alpha: 0.16),
                    onSelected: (_) => setState(
                      () => _selectedGroup = TicketFareGroup.parkAndRide,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Fare Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 980
                      ? 3
                      : (constraints.maxWidth >= 600 ? 2 : 1);
                  final cardWidth =
                      (constraints.maxWidth - (16 * (cols - 1))) / cols;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final ticket in filteredTickets)
                        SizedBox(
                          width: cardWidth,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 5,
                                  color: _accentForGroup(ticket.fareGroup),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              ticket.localizedTitle(localeCode),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: MarpromColors.marpromRed
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              TimeFormatUtils.formatEur(
                                                ticket.priceEur,
                                                locale: localeCode,
                                              ),
                                              style: const TextStyle(
                                                color: MarpromColors.marpromRed,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        ticket.localizedDescription(localeCode),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              height: 1.45,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          Chip(
                                            visualDensity:
                                                VisualDensity.compact,
                                            avatar: const Icon(
                                              Icons.nfc_rounded,
                                              size: 14,
                                            ),
                                            label: const Text(
                                              'NFC + QR',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ),
                                          if (ticket.ridesCount > 1)
                                            Chip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              label: Text(
                                                '${ticket.ridesCount} voženj',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                MarpromColors.marpromRed,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () => context.go(
                                            '/tickets/checkout/${Uri.encodeComponent(ticket.id)}',
                                          ),
                                          icon: const Icon(
                                            Icons.contactless_rounded,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Kupi NFC / QR vozovnico',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
      ),
    );
  }

  Color _accentForGroup(TicketFareGroup group) {
    return switch (group) {
      TicketFareGroup.singleAndCoupon => MarpromColors.marpromRed,
      TicketFareGroup.dailyAndMultiDay => const Color(0xFF0057B8),
      TicketFareGroup.monthlyAndAnnual => MarpromColors.mobilityGreen,
      TicketFareGroup.parkAndRide => const Color(0xFFD97706),
    };
  }
}

class _TicketFeaturePill extends StatelessWidget {
  const _TicketFeaturePill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
