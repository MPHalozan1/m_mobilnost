// Full-screen QR ticket viewer with safe brightness boost, live clock, TTS, and NFC stub.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../core/accessibility/a11y_settings.dart';
import '../../../core/accessibility/haptic_cues.dart';
import '../../../core/accessibility/read_aloud.dart';
import '../../../core/accessibility/semantics_helpers.dart';
import '../../../core/layout/responsive_builder.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/big_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../data/models/ticket.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../nfc/ticket_card_reader.dart';
import '../providers/ticket_providers.dart';

/// Displays an active or scheduled ticket with large QR, live clock, TTS, and NFC stub.
class TicketViewScreen extends ConsumerStatefulWidget {
  /// Creates a [TicketViewScreen] displaying the ticket with [ticketId].
  const TicketViewScreen({
    super.key,
    required this.ticketId,
  });

  /// Identifier of the [Ticket] to display.
  final String ticketId;

  @override
  ConsumerState<TicketViewScreen> createState() => _TicketViewScreenState();
}

class _TicketViewScreenState extends ConsumerState<TicketViewScreen> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  bool _pulseOn = true;
  bool _brightnessBoosted = false;
  bool _validatingNfc = false;
  DateTime? _nfcValidatedAt;
  NfcCardReaderStatus? _nfcStatus;
  bool _nfcHceArmed = false;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        _pulseOn = !_pulseOn;
      });
    });
    unawaited(_boostBrightness());
    unawaited(_initNfcStatus());
  }

  Future<void> _initNfcStatus() async {
    final reader = ref.read(ticketCardReaderProvider);
    final status = await reader.readCardStatus();
    Ticket? ticket = ref.read(ticketByIdProvider(widget.ticketId)).valueOrNull;
    if (ticket == null) {
      try {
        final tickets = await ref.read(userTicketsProvider.future);
        for (final candidate in tickets) {
          if (candidate.id == widget.ticketId) {
            ticket = candidate;
            break;
          }
        }
      } catch (_) {
        ticket = null;
      }
    }
    var armed = status.isHceArmed;
    if (ticket != null) {
      armed = await reader.armTicketForNfc(
        ticketId: ticket.id,
        payload: ticket.qrPayload,
      );
    }
    if (!mounted) return;
    setState(() {
      _nfcStatus = status;
      _nfcHceArmed = armed;
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    unawaited(_restoreBrightness());
    super.dispose();
  }

  Future<void> _boostBrightness() async {
    if (kIsWeb) return;
    try {
      await ScreenBrightness().setApplicationScreenBrightness(1.0);
      if (mounted) {
        setState(() => _brightnessBoosted = true);
      }
    } catch (_) {
      // Safely ignore missing brightness platform channels in tests and desktops.
    }
  }

  Future<void> _restoreBrightness() async {
    if (kIsWeb) return;
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (_) {
      // Safely ignore missing brightness platform channels in tests and desktops.
    }
  }

  Future<void> _readTicketAloud(
    BuildContext context,
    Ticket ticket,
    String localeCode,
  ) async {
    final l10n = context.l10n;
    final fromStr =
        TimeFormatUtils.formatDateTime24(ticket.validFrom, locale: localeCode);
    final untilStr =
        TimeFormatUtils.formatDateTime24(ticket.validUntil, locale: localeCode);
    final summary = '${ticket.localizedTitle(localeCode)}. '
        '${l10n.ticketsValidFromUntil(fromStr, untilStr)}. '
        '${l10n.ticketsDriverFallbackCode(ticket.driverFallbackCode)}.';

    unawaited(announceForAccessibility(context, summary));
    unawaited(
      ref.read(readAloudProvider).speak(
            summary,
            enabled: true,
            localeCode: localeCode,
          ),
    );
  }

  Future<void> _simulateNfcValidation(Ticket ticket) async {
    final l10n = context.l10n;
    final settings = ref.read(a11ySettingsProvider);
    setState(() => _validatingNfc = true);
    try {
      final reader = ref.read(ticketCardReaderProvider);
      final status = await reader.readCardStatus();
      await reader.armTicketForNfc(
        ticketId: ticket.id,
        payload: ticket.qrPayload,
      );
      final validatedTime = await reader.simulateTapValidation(ticket.id);
      await ref.read(ticketRepositoryProvider).validateTicket(ticket.id);
      unawaited(
        HapticCues.trigger(
          HapticCueType.tap,
          enabled: settings.hapticAlertsEnabled,
          soundOptional: settings.soundAlertsOptional,
        ),
      );
      if (!mounted) return;
      setState(() {
        _nfcValidatedAt = validatedTime;
        _nfcStatus = status;
        _nfcHceArmed = true;
      });
      unawaited(announceForAccessibility(context, l10n.ticketsNfcValidated));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.ticketsNfcValidated)),
        );
      }
    } finally {
      if (mounted) setState(() => _validatingNfc = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(a11ySettingsProvider);
    final ticketAsync = ref.watch(ticketByIdProvider(widget.ticketId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ticketsViewTitle),
      ),
      body: ticketAsync.when(
        loading: () => const LoadingStateView(),
        error: (_, _) => ErrorStateView(
          onRetry: () => ref.invalidate(userTicketsProvider),
        ),
        data: (ticket) {
          if (ticket == null) {
            return EmptyStateView(
              icon: Icons.confirmation_number_outlined,
              title: l10n.commonEmpty,
            );
          }

          return _buildTicketContent(context, l10n, ticket, settings);
        },
      ),
    );
  }

  Widget _buildTicketContent(
    BuildContext context,
    AppLocalizations l10n,
    Ticket ticket,
    A11ySettings settings,
  ) {
    final locale = settings.localeCode;
    final status = ticket.statusAt(_now);
    final scheme = Theme.of(context).colorScheme;
    final statusColors =
        Theme.of(context).extension<MarpromStatusColors>() ??
            MarpromStatusColors.light;

    final (chipType, chipLabel) = switch (status) {
      TicketStatus.active => (TransitStatusType.onTime, l10n.ticketsActiveTab),
      TicketStatus.upcoming => (
          TransitStatusType.info,
          l10n.ticketsTabUpcoming,
        ),
      TicketStatus.expired => (
          TransitStatusType.warning,
          l10n.ticketsTabExpired,
        ),
    };

    final validFromStr =
        TimeFormatUtils.formatDateTime24(ticket.validFrom, locale: locale);
    final validUntilStr =
        TimeFormatUtils.formatDateTime24(ticket.validUntil, locale: locale);
    final liveSecondsClock = DateFormat('HH:mm:ss').format(_now);
    final validatedTime = _nfcValidatedAt ?? ticket.validatedAt;

    final remainingDuration = switch (status) {
      TicketStatus.active => ticket.validUntil.difference(_now),
      TicketStatus.upcoming => ticket.validFrom.difference(_now),
      TicketStatus.expired => Duration.zero,
    };

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
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusChip(type: chipType, label: chipLabel),
                          StatusChip(
                            type: TransitStatusType.info,
                            label: l10n.ticketsZoneMaribor,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        ticket.localizedTitle(locale),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        TimeFormatUtils.formatEur(
                          ticket.priceEur,
                          locale: locale,
                        ),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: scheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // High-contrast crisp white QR container so scanners read reliably even in dark/AAA themes.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Semantics(
                        image: true,
                        label: l10n.a11yQrCode,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.black,
                              width: statusColors.highContrastBorders ? 3 : 1.5,
                            ),
                          ),
                          child: QrImageView(
                            data: ticket.qrPayload,
                            size: 240,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
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
                      const SizedBox(height: 14),
                      Text(
                        l10n.ticketsQrHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (_brightnessBoosted) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.ticketsBrightnessBoosted,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          if (settings.reducedMotion)
                            Icon(
                              Icons.verified_user_rounded,
                              color: scheme.primary,
                              size: 26,
                            )
                          else
                            AnimatedOpacity(
                              opacity: _pulseOn ? 1.0 : 0.4,
                              duration: const Duration(milliseconds: 350),
                              child: Icon(
                                Icons.verified_user_rounded,
                                color: scheme.primary,
                                size: 26,
                              ),
                            ),
                          Text(
                            liveSecondsClock,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.ticketsLiveClockNote,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Divider(height: 22),
                      Text(
                        l10n.ticketsValidFromUntil(validFromStr, validUntilStr),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (status != TicketStatus.expired) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.ticketsRemainingTime(
                            formatTicketCountdown(remainingDuration),
                          ),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: scheme.primary,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          l10n.ticketsDriverFallbackCode(
                            ticket.driverFallbackCode,
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              BigButton(
                icon: Icons.volume_up_rounded,
                label: l10n.a11yReadAloudButton,
                variant: BigButtonVariant.secondary,
                expanded: true,
                onPressed: () => _readTicketAloud(context, ticket, locale),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: _nfcHceArmed
                        ? MarpromColors.marpromRed
                        : scheme.outlineVariant,
                    width: _nfcHceArmed ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: MarpromColors.marpromRed
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.contactless_rounded,
                                  color: MarpromColors.marpromRed,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  l10n.ticketsNfcStubTitle,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          StatusChip(
                            type: (_nfcStatus?.isAvailable ?? false)
                                ? TransitStatusType.onTime
                                : TransitStatusType.info,
                            label: (_nfcStatus?.isAvailable ?? false)
                                ? 'NFC HCE aktiven'
                                : l10n.ticketsNfcComingSoon,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Metallic contactless phone-chip pass banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              MarpromColors.marpromCharcoal,
                              MarpromColors.marpromBurgundy,
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAB308),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.sim_card_outlined,
                                color: Color(0xFF422006),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Marprom NFC SmartPass (${_nfcStatus?.aidHex ?? PlatformNfcTicketCardReader.marpromAidHex})${_nfcHceArmed ? ' • NFC pripravljen' : ''}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _nfcStatus?.message ?? l10n.ticketsNfcStubBody,
                                    style: const TextStyle(
                                      color: Color(0xFFCBD5E1),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.ticketsNfcStubBody,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (validatedTime != null) ...[
                        const SizedBox(height: 10),
                        StatusChip(
                          type: TransitStatusType.onTime,
                          label: '${l10n.ticketsNfcValidated} '
                              '(${TimeFormatUtils.formatTime24(validatedTime)})',
                        ),
                      ],
                      if (_nfcStatus?.mode == NfcHardwareMode.nfcDisabled) ...[
                        const SizedBox(height: 10),
                        BigButton(
                          icon: Icons.settings_rounded,
                          label: 'Vklopi NFC v nastavitvah telefona',
                          variant: BigButtonVariant.secondary,
                          expanded: true,
                          onPressed: () =>
                              ref.read(ticketCardReaderProvider).openNfcSettings(),
                        ),
                      ],
                      const SizedBox(height: 14),
                      BigButton(
                        icon: Icons.nfc_rounded,
                        label: l10n.ticketsNfcTapToSimulate,
                        variant: BigButtonVariant.outlined,
                        expanded: true,
                        loading: _validatingNfc,
                        onPressed: () => _simulateNfcValidation(ticket),
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
