//**********************************************
// Contactless NFC HCE & Scannable QR Ticket   *
//**********************************************

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../../core/accessibility/a11y_settings.dart';
import '../../../../core/accessibility/semantics_helpers.dart';
import '../../../../core/maps/google_web_views.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../data/mock/mock_ticket_repository.dart';
import '../../../../data/models/ticket.dart';
import '../../../../data/models/ticket_type.dart';
import '../../../../data/repositories/repository_providers.dart';
import '../../nfc/ticket_card_reader.dart';
import '../../providers/ticket_providers.dart';

//**********************************************
// Contactless NFC + QR Ticket Hero Card       *
//**********************************************

// Front-and-center Vozovnica pass rendering:
// 1. Live NFC HCE contactless emulation card (`com.mmobilnost/nfc_hce`, AID F222222222)
//    with animated contactless waves and validator tap listener.
// 2. Crisp high-contrast scannable QR code with live validity countdown,
//    holographic anti-screenshot shimmer bar, and mobile max-brightness toggle.
class ContactlessQrTicketHero extends ConsumerStatefulWidget {
  // Creates a [ContactlessQrTicketHero].
  const ContactlessQrTicketHero({
    super.key,
    required this.ticket,
    required this.localeCode,
    required this.now,
    this.onOpenFullScreen,
  });

  // Active or selected Marprom ticket to present.
  final Ticket ticket;

  // Current UI locale (`sl`, `en`, ...).
  final String localeCode;

  // Live clock reference passed by parent timer.
  final DateTime now;

  // Optional callback opening full-screen ticket viewer.
  final VoidCallback? onOpenFullScreen;

  @override
  ConsumerState<ContactlessQrTicketHero> createState() =>
      _ContactlessQrTicketHeroState();
}

class _ContactlessQrTicketHeroState
    extends ConsumerState<ContactlessQrTicketHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  StreamSubscription<String>? _tapSub;

  NfcCardReaderStatus? _nfcStatus;
  bool _isArmed = false;
  bool _justValidatedFlash = false;
  DateTime? _lastTapTime;
  bool _brightnessBoosted = false;
  bool _busySimulating = false;
  Timer? _flashResetTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _syncTickerState();
    _initNfcAndArm();
    _subscribeValidatorTapStream();
  }

  @override
  void didUpdateWidget(covariant ContactlessQrTicketHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTickerState();
    if (oldWidget.ticket.id != widget.ticket.id ||
        oldWidget.ticket.qrPayload != widget.ticket.qrPayload) {
      unawaited(_armCurrentTicket());
    }
  }

  void _syncTickerState() {
    final reducedMotion =
        ref.read(a11ySettingsProvider).reducedMotion || isFlutterTestEnvironment;
    if (reducedMotion) {
      _pulseController.value = 0.45;
      _pulseController.stop();
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat();
    }
  }

  Future<void> _initNfcAndArm() async {
    final reader = ref.read(ticketCardReaderProvider);
    final status = await reader.readCardStatus();
    if (!mounted) return;
    setState(() => _nfcStatus = status);
    await _armCurrentTicket();
  }

  Future<void> _armCurrentTicket() async {
    final status = widget.ticket.statusAt(widget.now);
    final reader = ref.read(ticketCardReaderProvider);
    if (status != TicketStatus.active) {
      await reader.disarmTicketForNfc();
      if (mounted) setState(() => _isArmed = false);
      return;
    }
    final ok = await reader.armTicketForNfc(
      ticketId: widget.ticket.id,
      payload: widget.ticket.qrPayload,
    );
    if (mounted) setState(() => _isArmed = ok);
  }

  void _subscribeValidatorTapStream() {
    final reader = ref.read(ticketCardReaderProvider);
    _tapSub = reader.validatorTapStream.listen((tappedTicketId) {
      if (!mounted) return;
      if (tappedTicketId == widget.ticket.id) {
        unawaited(_handleValidatorTapFeedback(triggerRepoValidate: true));
      }
    });
  }

  Future<void> _handleValidatorTapFeedback({
    bool triggerRepoValidate = false,
  }) async {
    HapticFeedback.heavyImpact();
    _flashResetTimer?.cancel();
    if (mounted) {
      setState(() {
        _justValidatedFlash = true;
        _lastTapTime = DateTime.now();
      });
    }
    if (triggerRepoValidate) {
      try {
        await ref.read(ticketRepositoryProvider).validateTicket(widget.ticket.id);
      } catch (_) {}
    }
    if (!isFlutterTestEnvironment) {
      _flashResetTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _justValidatedFlash = false);
      });
    }
  }

  Future<void> _simulateValidatorTap() async {
    if (_busySimulating) return;
    setState(() => _busySimulating = true);
    try {
      final reader = ref.read(ticketCardReaderProvider);
      await reader.armTicketForNfc(
        ticketId: widget.ticket.id,
        payload: widget.ticket.qrPayload,
      );
      await reader.simulateTapValidation(widget.ticket.id);
    } finally {
      if (mounted) setState(() => _busySimulating = false);
    }
  }

  Future<void> _toggleMaxBrightness() async {
    if (kIsWeb || isFlutterTestEnvironment) return;
    try {
      if (_brightnessBoosted) {
        await ScreenBrightness().resetApplicationScreenBrightness();
      } else {
        await ScreenBrightness().setApplicationScreenBrightness(1.0);
      }
      if (mounted) setState(() => _brightnessBoosted = !_brightnessBoosted);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tapSub?.cancel();
    _flashResetTimer?.cancel();
    _pulseController.dispose();
    if (_brightnessBoosted && !kIsWeb && !isFlutterTestEnvironment) {
      unawaited(ScreenBrightness().resetApplicationScreenBrightness());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isSl = widget.localeCode == 'sl';
    final status = widget.ticket.statusAt(widget.now);
    final isActive = status == TicketStatus.active;
    final remaining = widget.ticket.validUntil.difference(widget.now);
    final fromStr = TimeFormatUtils.formatDateTime24(
      widget.ticket.validFrom,
      locale: widget.localeCode,
    );
    final untilStr = TimeFormatUtils.formatDateTime24(
      widget.ticket.validUntil,
      locale: widget.localeCode,
    );
    final qrVerified =
        MockTicketRepository.verifySignedQrPayload(widget.ticket.qrPayload);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Contactless NFC HCE Pass Hero Card
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _justValidatedFlash
                  ? const [Color(0xFF0E7C47), Color(0xFF15803D)]
                  : isActive
                      ? const [
                          MarpromColors.marpromCharcoal,
                          MarpromColors.marpromBurgundy,
                          Color(0xFFA01734),
                        ]
                      : [
                          theme.colorScheme.surfaceContainerHighest,
                          theme.colorScheme.surfaceContainerHigh,
                        ],
            ),
            boxShadow: [
              BoxShadow(
                color: (_justValidatedFlash
                        ? const Color(0xFF16A34A)
                        : MarpromColors.marpromBurgundy)
                    .withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top identity + Status badge
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.contactless_rounded,
                            size: 16,
                            color: isActive
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'NFC HCE • ${_nfcStatus?.aidHex ?? PlatformNfcTicketCardReader.marpromAidHex}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isActive
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_justValidatedFlash)
                      const StatusChip(
                        type: TransitStatusType.onTime,
                        label: 'Potrjeno ✓',
                        compact: true,
                      )
                    else
                      StatusChip(
                        type: isActive
                            ? TransitStatusType.onTime
                            : TransitStatusType.warning,
                        label: isActive ? l10n.ticketsActiveTab : status.name,
                        compact: true,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Pulsing NFC contactless symbol isolated in RepaintBoundary
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final v = _pulseController.value;
                          final ring1 = 0.28 + (1.0 - v) * 0.45;
                          final ring2 = 0.16 + ((1.0 - ((v + 0.5) % 1.0)) * 0.32);
                          return SizedBox(
                            width: 64,
                            height: 64,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (isActive)
                                  Container(
                                    width: 44 + (v * 20),
                                    height: 44 + (v * 20),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: ring1.clamp(0.0, 1.0)),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                if (isActive)
                                  Container(
                                    width: 36 + (((v + 0.5) % 1.0) * 24),
                                    height: 36 + (((v + 0.5) % 1.0) * 24),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: ring2.clamp(0.0, 1.0)),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _justValidatedFlash
                                        ? Icons.verified_rounded
                                        : Icons.nfc_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.ticket.localizedTitle(widget.localeCode),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isActive
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _justValidatedFlash
                                ? (isSl
                                    ? 'Vozovnica potrjena na validatorju!'
                                    : 'Ticket validated at bus terminal!')
                                : (isSl
                                    ? 'Prisloni telefon k validatorju na avtobusu'
                                    : 'Hold phone near the bus validator'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isActive
                                  ? Colors.white.withValues(alpha: 0.92)
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: _justValidatedFlash
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Live countdown + holographic shimmer strip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isActive
                              ? l10n.ticketsRemainingTime(
                                  formatTicketCountdown(remaining),
                                )
                              : l10n.ticketsValidFromUntil(fromStr, untilStr),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      if (widget.ticket.validatedAt != null || _lastTapTime != null)
                        Text(
                          TimeFormatUtils.formatTime24(
                            _lastTapTime ?? widget.ticket.validatedAt!,
                          ),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF86EFAC),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Animated holographic anti-screenshot bar (RepaintBoundary isolated)
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      final alignX = -1.0 + (_pulseController.value * 2.0);
                      return Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            begin: Alignment(alignX - 0.6, 0),
                            end: Alignment(alignX + 0.6, 0),
                            colors: const [
                              Color(0xFF38BDF8),
                              Color(0xFFA7F3D0),
                              Color(0xFFFDE047),
                              Color(0xFFF472B6),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Platform NFC readiness banner & Simulate Tap CTA
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (isActive)
                      FilledButton.icon(
                        onPressed:
                            _busySimulating ? null : _simulateValidatorTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: MarpromColors.marpromBurgundy,
                          minimumSize: const Size(0, 44),
                        ),
                        icon: const Icon(Icons.tap_and_play_rounded, size: 18),
                        label: Text(
                          isSl
                              ? 'Simuliraj potrditev'
                              : 'Simulate Validator Tap',
                        ),
                      ),
                    if (_nfcStatus?.mode == NfcHardwareMode.nfcDisabled)
                      OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(ticketCardReaderProvider).openNfcSettings(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          minimumSize: const Size(0, 44),
                        ),
                        icon: const Icon(Icons.settings_rounded, size: 18),
                        label: Text(isSl ? 'Vklopi NFC' : 'Enable NFC'),
                      ),
                  ],
                ),
                if (kIsWeb ||
                    (_nfcStatus != null &&
                        _nfcStatus!.mode != NfcHardwareMode.hceReady)) ...[
                  const SizedBox(height: 8),
                  Text(
                    kIsWeb
                        ? (isSl
                            ? 'Opomba: Spletni brskalnik ne oddaja strojnega NFC HCE signala — na avtobusu pokažite QR kodo spodaj.'
                            : 'Web browsers cannot transmit HCE NFC signals — scan the QR code below on the bus.')
                        : (_nfcStatus?.message ?? ''),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ] else if (_isArmed) ...[
                  const SizedBox(height: 8),
                  Text(
                    isSl
                        ? 'NFC HCE čip aktiven • prislonite zadnjo stran telefona k čitalcu.'
                        : 'NFC HCE active • tap back of phone to reader.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFBBF7D0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Crisp High-Contrast QR Code Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isSl ? 'Digitalna QR vozovnica' : 'Scannable QR Pass',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (qrVerified)
                      Tooltip(
                        message: 'Signed Marprom Ticket',
                        child: Icon(
                          Icons.verified_user_rounded,
                          size: 18,
                          color: Colors.green.shade500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12, width: 1.5),
                    ),
                    child: QrImageView(
                      data: widget.ticket.qrPayload,
                      size: 188,
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
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      l10n.ticketsDriverFallbackCode(
                        widget.ticket.driverFallbackCode,
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      l10n.ticketsValidFromUntil(fromStr, untilStr),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!kIsWeb)
                      OutlinedButton.icon(
                        onPressed: _toggleMaxBrightness,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        icon: Icon(
                          _brightnessBoosted
                              ? Icons.brightness_high_rounded
                              : Icons.brightness_6_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _brightnessBoosted
                              ? l10n.ticketsBrightnessBoosted
                              : (isSl ? 'Maks. svetlost' : 'Max Brightness'),
                        ),
                      ),
                    if (widget.onOpenFullScreen != null)
                      FilledButton.tonalIcon(
                        onPressed: widget.onOpenFullScreen,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        icon: const Icon(Icons.fullscreen_rounded, size: 18),
                        label: Text(l10n.ticketsViewTitle),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

//**********************************************
// 1-Tap Demo Ticket Quick-Issue Card          *
//**********************************************

// Instant 1-tap ticket issuer allowing Demo & signed-in passengers to mint
// active Single 75m, Day 24h, or Monthly / Student tickets with zero checkout walls.
class QuickDemoTicketShopSection extends ConsumerStatefulWidget {
  // Creates a [QuickDemoTicketShopSection].
  const QuickDemoTicketShopSection({
    super.key,
    required this.types,
    required this.localeCode,
    this.onTicketIssued,
  });

  // Catalog ticket types.
  final List<TicketType> types;

  // Active locale (`sl`, `en`, ...).
  final String localeCode;

  // Optional callback invoked with the newly activated ticket ID.
  final ValueChanged<String>? onTicketIssued;

  @override
  ConsumerState<QuickDemoTicketShopSection> createState() =>
      _QuickDemoTicketShopSectionState();
}

class _QuickDemoTicketShopSectionState
    extends ConsumerState<QuickDemoTicketShopSection> {
  String? _issuingTypeId;

  Future<void> _issueInstantTicket(TicketType type) async {
    if (_issuingTypeId != null) return;
    setState(() => _issuingTypeId = type.id);
    final isSl = widget.localeCode == 'sl';
    try {
      final authRepo = ref.read(authRepositoryProvider);
      var user = authRepo.currentUser;
      user ??= await authRepo.signInDemoAccount(
        preferredLocaleCode: widget.localeCode,
      );

      final issued = await ref.read(ticketRepositoryProvider).purchaseTicket(
            type: type,
            userId: user.id,
          );
      await ref.read(ticketCardReaderProvider).armTicketForNfc(
            ticketId: issued.id,
            payload: issued.qrPayload,
          );

      if (!mounted) return;
      widget.onTicketIssued?.call(issued.id);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              isSl
                  ? 'Aktivirano: ${type.localizedTitle(widget.localeCode)}'
                  : 'Activated: ${type.localizedTitle(widget.localeCode)}',
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Napaka: $e')),
      );
    } finally {
      if (mounted) setState(() => _issuingTypeId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSl = widget.localeCode == 'sl';
    const preferredOrder = ['single', 'day_24h', 'student_monthly', 'monthly'];
    final quickTypes = <TicketType>[];
    for (final id in preferredOrder) {
      final match = widget.types.where((t) => t.id == id);
      if (match.isNotEmpty) quickTypes.add(match.first);
    }
    if (quickTypes.isEmpty) {
      quickTypes.addAll(widget.types.take(3));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flash_on_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isSl
                        ? 'Hitra 1-klik aktivacija (Demo)'
                        : 'Instant 1-Tap Pass Activation (Demo)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < quickTypes.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _issuingTypeId != null
                        ? null
                        : () => _issueInstantTicket(quickTypes[i]),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_issuingTypeId == quickTypes[i].id)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(
                            Icons.confirmation_number_outlined,
                            size: 18,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            quickTypes[i].localizedTitle(widget.localeCode),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          TimeFormatUtils.formatEur(
                            quickTypes[i].priceEur,
                            locale: widget.localeCode,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
