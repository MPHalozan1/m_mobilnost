// 3-step ticket checkout screen handling validity start, minor guard, payment, and issue.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/a11y_settings.dart';
import '../../../core/accessibility/haptic_cues.dart';
import '../../../core/accessibility/semantics_helpers.dart';
import '../../../core/layout/responsive_builder.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../data/models/payment_method.dart';
import '../../../data/models/ticket.dart';
import '../../../data/models/ticket_type.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/presentation/account_screen.dart';
import '../../account/presentation/payment_methods_screen.dart';
import '../../account/presentation/widgets/payment_method_helpers.dart';
import '../../account/providers/account_providers.dart';
import '../providers/ticket_providers.dart';
import 'ticket_view_screen.dart';

/// Guided 3-step checkout flow for purchasing a [TicketType] identified by [typeId].
class TicketCheckoutScreen extends ConsumerStatefulWidget {
  /// Creates a [TicketCheckoutScreen] for ticket product [typeId].
  const TicketCheckoutScreen({
    super.key,
    required this.typeId,
  });

  /// Identifier of the [TicketType] being purchased.
  final String typeId;

  @override
  ConsumerState<TicketCheckoutScreen> createState() =>
      _TicketCheckoutScreenState();
}

class _TicketCheckoutScreenState extends ConsumerState<TicketCheckoutScreen> {
  int _step = 0;
  int _quantity = 1;
  bool _startImmediately = true;
  DateTime _chosenStartTime = DateTime.now().add(const Duration(hours: 1));
  bool _guardianConfirmed = false;
  String? _selectedPaymentMethodId;
  bool _useBuiltInNfcPay = false;
  bool _nfcTapAuthorized = false;
  bool _submitting = false;
  String? _checkoutError;
  List<Ticket>? _purchasedTickets;

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _chosenStartTime.isBefore(now) ? now : _chosenStartTime,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _chosenStartTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _chosenStartTime.hour,
        _chosenStartTime.minute,
      );
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_chosenStartTime),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _chosenStartTime = DateTime(
        _chosenStartTime.year,
        _chosenStartTime.month,
        _chosenStartTime.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _completePurchase({
    required UserProfile user,
    required TicketType type,
    required PaymentMethod method,
  }) async {
    final l10n = context.l10n;
    if (user.isUnder18 && !_guardianConfirmed) {
      setState(() => _checkoutError = l10n.ticketsMinorUnder18Notice);
      return;
    }

    setState(() {
      _submitting = true;
      _checkoutError = null;
    });

    try {
      final totalEur = type.priceEur * _quantity;
      final approved = await ref.read(paymentRepositoryProvider).simulateCharge(
            userId: user.id,
            methodId: method.id,
            amountEur: totalEur,
          );
      if (!approved) {
        if (mounted) {
          setState(() => _checkoutError = l10n.commonErrorBody);
        }
        return;
      }

      if (user.isUnder18 && _guardianConfirmed && !user.guardianConfirmed) {
        await ref
            .read(authRepositoryProvider)
            .updateProfile(user.copyWith(guardianConfirmed: true));
      }

      final issued = <Ticket>[];
      final ticketRepo = ref.read(ticketRepositoryProvider);
      final validFrom = _startImmediately ? null : _chosenStartTime;
      for (var i = 0; i < _quantity; i++) {
        issued.add(
          await ticketRepo.purchaseTicket(
            type: type,
            userId: user.id,
            validFrom: validFrom,
          ),
        );
      }

      final settings = ref.read(a11ySettingsProvider);
      unawaited(
        HapticCues.trigger(
          HapticCueType.tap,
          enabled: settings.hapticAlertsEnabled,
          soundOptional: settings.soundAlertsOptional,
        ),
      );

      if (mounted) {
        setState(() => _purchasedTickets = issued);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _checkoutError = l10n.commonErrorBody);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(a11ySettingsProvider);
    final user = ref.watch(activeUserProvider);
    final typeAsync = ref.watch(ticketTypeByIdProvider(widget.typeId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ticketsCheckoutTitle),
      ),
      body: user == null
          ? ListView(
              children: [
                ResponsiveContentContainer(
                  child: GuestAuthPromptCard(
                    onSignInPressed: () => navigateWithFallback(
                      context,
                      '/account',
                      fallbackBuilder: (_) => const AccountScreen(),
                    ),
                  ),
                ),
              ],
            )
          : typeAsync.when(
              loading: () => const LoadingStateView(),
              error: (_, _) => ErrorStateView(
                onRetry: () =>
                    ref.invalidate(ticketTypeByIdProvider(widget.typeId)),
              ),
              data: (type) {
                if (type == null) {
                  return ErrorStateView(
                    onRetry: () =>
                        ref.invalidate(ticketTypeByIdProvider(widget.typeId)),
                  );
                }

                if (_purchasedTickets != null &&
                    _purchasedTickets!.isNotEmpty) {
                  return _buildSuccessView(
                    context,
                    l10n,
                    settings.localeCode,
                    _purchasedTickets!,
                  );
                }

                return ListView(
                  children: [
                    ResponsiveContentContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CheckoutStepHeader(currentStep: _step),
                          const SizedBox(height: 16),
                          if (_step == 0)
                            _buildStepOne(context, l10n, user, type, settings)
                          else if (_step == 1)
                            _buildStepTwo(context, l10n)
                          else
                            _buildStepThree(
                              context,
                              l10n,
                              user,
                              type,
                              settings,
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

  Widget _buildStepOne(
    BuildContext context,
    AppLocalizations l10n,
    UserProfile user,
    TicketType type,
    A11ySettings settings,
  ) {
    final locale = settings.localeCode;
    final unitPrice = TimeFormatUtils.formatEur(type.priceEur, locale: locale);
    final totalPrice =
        TimeFormatUtils.formatEur(type.priceEur * _quantity, locale: locale);
    final isMinor = user.isUnder18;
    final canAdvance = !isMinor || _guardianConfirmed;
    final statusColors =
        Theme.of(context).extension<MarpromStatusColors>() ??
            MarpromStatusColors.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.localizedTitle(locale),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  type.localizedDescription(locale),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(
                      type: TransitStatusType.info,
                      label: l10n.ticketsZoneMaribor,
                    ),
                    StatusChip(
                      type: TransitStatusType.onTime,
                      label: unitPrice,
                    ),
                  ],
                ),
              ],
            ),
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
                  l10n.ticketsQuantity,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton.outlined(
                      constraints:
                          const BoxConstraints(minWidth: 56, minHeight: 56),
                      tooltip: l10n.commonRemove,
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity -= 1)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '$_quantity',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton.outlined(
                      constraints:
                          const BoxConstraints(minWidth: 56, minHeight: 56),
                      tooltip: l10n.commonAdd,
                      onPressed: _quantity < 10
                          ? () => setState(() => _quantity += 1)
                          : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${l10n.ticketsTotalPrice}: $totalPrice',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RadioGroup<bool>(
              groupValue: _startImmediately,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _startImmediately = value);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: true,
                      title: Text(l10n.ticketsStartNow),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: false,
                      title: Text(l10n.ticketsStartLater),
                    ),
                  ),
                  if (!_startImmediately) ...[
                    const SizedBox(height: 12),
                    Text(
                      TimeFormatUtils.formatDateTime24(
                        _chosenStartTime,
                        locale: locale,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        BigButton(
                          icon: Icons.calendar_today_rounded,
                          label: formatCalendarDate(
                            _chosenStartTime,
                            localeCode: locale,
                          ),
                          variant: BigButtonVariant.outlined,
                          onPressed: _pickStartDate,
                        ),
                        BigButton(
                          icon: Icons.schedule_rounded,
                          label: TimeFormatUtils.formatTime24(_chosenStartTime),
                          variant: BigButtonVariant.outlined,
                          onPressed: _pickStartTime,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (isMinor) ...[
          const SizedBox(height: 16),
          Material(
            color: statusColors.warningBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: statusColors.warningFg,
                width: statusColors.highContrastBorders ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusChip(
                    type: TransitStatusType.warning,
                    label: l10n.ticketsMinorTitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.isUnder16
                        ? l10n.ticketsMinorUnder16Warning
                        : l10n.ticketsMinorUnder18Notice,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: statusColors.warningFg,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _guardianConfirmed,
                      title: Text(
                        l10n.ticketsMinorGuardianConfirm,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: statusColors.warningFg,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      onChanged: (value) {
                        setState(() => _guardianConfirmed = value ?? false);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        BigButton(
          icon: Icons.arrow_forward_rounded,
          label: l10n.commonNext,
          expanded: true,
          onPressed: canAdvance ? () => setState(() => _step = 1) : null,
        ),
      ],
    );
  }

  Widget _buildStepTwo(BuildContext context, AppLocalizations l10n) {
    final methodsAsync = ref.watch(userPaymentMethodsProvider);

    return methodsAsync.when(
      loading: () => const LoadingStateView(),
      error: (_, _) => ErrorStateView(
        onRetry: () => ref.invalidate(userPaymentMethodsProvider),
      ),
      data: (methods) {
        final effectiveId = _resolvedMethodId(methods);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DemoPaymentBanner(),
            const SizedBox(height: 14),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _useBuiltInNfcPay
                      ? MarpromColors.marpromRed
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: _useBuiltInNfcPay ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                            Icons.contactless_rounded,
                            color: MarpromColors.marpromRed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Plačilo z vgrajenim NFC čipom telefona',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Brezstična bančna kartica / Google Pay / Apple Pay prek NFC čipa',
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _nfcTapAuthorized
                                ? MarpromColors.mobilityGreen
                                : MarpromColors.marpromRed,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            final cardOrWallet = methods.firstWhere(
                              (m) =>
                                  m.type == PaymentMethodType.card ||
                                  m.type == PaymentMethodType.googlePay ||
                                  m.type == PaymentMethodType.applePay,
                              orElse: () => methods.first,
                            );
                            setState(() {
                              _useBuiltInNfcPay = true;
                              _nfcTapAuthorized = true;
                              _selectedPaymentMethodId = cardOrWallet.id;
                            });
                          },
                          icon: Icon(
                            _nfcTapAuthorized
                                ? Icons.verified_rounded
                                : Icons.nfc_rounded,
                          ),
                          label: Text(
                            _nfcTapAuthorized
                                ? 'NFC čip potrjen za plačilo'
                                : 'Aktiviraj plačilo z NFC čipom',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (methods.isEmpty)
              EmptyStateView(
                icon: Icons.credit_card_off_outlined,
                title: l10n.commonEmpty,
              )
            else
              RadioGroup<String>(
                groupValue: effectiveId,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPaymentMethodId = value;
                      _useBuiltInNfcPay = false;
                    });
                  }
                },
                child: Column(
                  children: [
                    for (final method in methods) ...[
                      Card(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: RadioListTile<String>(
                            value: method.id,
                            secondary: Icon(iconForPaymentType(method.type)),
                            title: Text(
                              method.type == PaymentMethodType.card
                                  ? '${method.brand} •••• ${method.last4Digits ?? ''}'
                                      .trim()
                                  : (method.label.isNotEmpty
                                      ? method.label
                                      : localizedPaymentTypeLabel(
                                          l10n,
                                          method.type,
                                        )),
                            ),
                            subtitle: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    localizedPaymentTypeLabel(
                                      l10n,
                                      method.type,
                                    ),
                                  ),
                                ),
                                if (method.isDefault) ...[
                                  const SizedBox(width: 8),
                                  StatusChip(
                                    type: TransitStatusType.onTime,
                                    label: l10n.paymentsDefaultBadge,
                                    compact: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 8),
            BigButton(
              icon: Icons.credit_card_rounded,
              label: l10n.accountManagePayments,
              variant: BigButtonVariant.outlined,
              expanded: true,
              onPressed: () {
                navigateWithFallback(
                  context,
                  '/account/payments',
                  fallbackBuilder: (_) => const PaymentMethodsScreen(),
                );
              },
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                BigButton(
                  icon: Icons.arrow_back_rounded,
                  label: l10n.commonBack,
                  variant: BigButtonVariant.outlined,
                  onPressed: () => setState(() => _step = 0),
                ),
                BigButton(
                  icon: Icons.arrow_forward_rounded,
                  label: l10n.commonNext,
                  onPressed: effectiveId == null
                      ? null
                      : () {
                          setState(() {
                            _selectedPaymentMethodId = effectiveId;
                            _step = 2;
                          });
                        },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStepThree(
    BuildContext context,
    AppLocalizations l10n,
    UserProfile user,
    TicketType type,
    A11ySettings settings,
  ) {
    final methods = ref.watch(userPaymentMethodsProvider).valueOrNull ??
        const <PaymentMethod>[];
    final selectedId = _resolvedMethodId(methods);
    PaymentMethod? selectedMethod;
    for (final method in methods) {
      if (method.id == selectedId) {
        selectedMethod = method;
        break;
      }
    }

    final locale = settings.localeCode;
    final totalEur =
        TimeFormatUtils.formatEur(type.priceEur * _quantity, locale: locale);
    final validityLabel = _startImmediately
        ? l10n.ticketsStartNow
        : TimeFormatUtils.formatDateTime24(_chosenStartTime, locale: locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DemoPaymentBanner(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.localizedTitle(locale),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  '${l10n.ticketsQuantity}: $_quantity',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  validityLabel,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (selectedMethod != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.paymentsTitle}: ${selectedMethod.label}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.ticketsTotalPrice,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      totalEur,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_checkoutError != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                _checkoutError!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            BigButton(
              icon: Icons.arrow_back_rounded,
              label: l10n.commonBack,
              variant: BigButtonVariant.outlined,
              onPressed: _submitting ? null : () => setState(() => _step = 1),
            ),
            BigButton(
              icon: Icons.check_circle_outline_rounded,
              label: l10n.ticketsPayNow,
              loading: _submitting,
              onPressed: selectedMethod == null
                  ? null
                  : () => _completePurchase(
                        user: user,
                        type: type,
                        method: selectedMethod!,
                      ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessView(
    BuildContext context,
    AppLocalizations l10n,
    String localeCode,
    List<Ticket> tickets,
  ) {
    final first = tickets.first;
    final validFrom =
        TimeFormatUtils.formatDateTime24(first.validFrom, locale: localeCode);
    final validUntil =
        TimeFormatUtils.formatDateTime24(first.validUntil, locale: localeCode);

    return ListView(
      children: [
        ResponsiveContentContainer(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StatusChip(
                      type: TransitStatusType.onTime,
                      label: l10n.commonDone,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.ticketsPurchaseSuccess,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    first.localizedTitle(localeCode),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.ticketsValidFromUntil(validFrom, validUntil),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.ticketsDriverFallbackCode(first.driverFallbackCode),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  BigButton(
                    icon: Icons.qr_code_2_rounded,
                    label: l10n.ticketsViewTitle,
                    expanded: true,
                    onPressed: () {
                      navigateWithFallback(
                        context,
                        '/tickets/view/${first.id}',
                        replace: true,
                        fallbackBuilder: (_) =>
                            TicketViewScreen(ticketId: first.id),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  BigButton(
                    icon: Icons.confirmation_number_outlined,
                    label: l10n.ticketsTitle,
                    variant: BigButtonVariant.outlined,
                    expanded: true,
                    onPressed: () {
                      final router = GoRouter.maybeOf(context);
                      if (router != null) {
                        router.go('/tickets');
                      } else if (Navigator.of(context).canPop()) {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _resolvedMethodId(List<PaymentMethod> methods) {
    if (methods.isEmpty) return null;
    if (_selectedPaymentMethodId != null &&
        methods.any((m) => m.id == _selectedPaymentMethodId)) {
      return _selectedPaymentMethodId;
    }
    for (final method in methods) {
      if (method.isDefault) return method.id;
    }
    return methods.first.id;
  }
}

class _CheckoutStepHeader extends StatelessWidget {
  const _CheckoutStepHeader({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = [
      l10n.ticketsStepChoose,
      l10n.ticketsStepPayment,
      l10n.ticketsStepConfirm,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < steps.length; i++)
          Semantics(
            selected: i == currentStep,
            child: StatusChip(
              type: i == currentStep
                  ? TransitStatusType.info
                  : (i < currentStep
                      ? TransitStatusType.onTime
                      : TransitStatusType.warning),
              label: steps[i],
            ),
          ),
      ],
    );
  }
}
