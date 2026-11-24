// Phone built-in NFC Host Card Emulation (HCE) & contactless reader contract + platform channel implementation.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/maps/google_web_views.dart';

/// Describes device capability for phone-chip NFC contactless ticket validation.
enum NfcHardwareMode {
  /// Android phone has an active NFC chip and Host Card Emulation (HCE) enabled.
  hceReady,

  /// Phone has an NFC chip, but NFC is turned off in system settings.
  nfcDisabled,

  /// Web browser / non-Android hardware uses contactless card/QR fallback simulation.
  simulatedContactless,
}

/// Snapshot describing device NFC HCE hardware and ticket arming state.
@immutable
class NfcCardReaderStatus {
  /// Creates an [NfcCardReaderStatus] payload.
  const NfcCardReaderStatus({
    required this.isAvailable,
    required this.message,
    this.mode = NfcHardwareMode.simulatedContactless,
    this.aidHex = 'F04D415250524F4D01',
    this.isHceArmed = false,
    this.isNfcEnabled = false,
  });

  /// Whether hardware NFC HCE validation is ready on this device.
  final bool isAvailable;

  /// Human-readable status note for UI, diagnostics, and tests.
  final String message;

  /// Operating mode of the NFC contactless module.
  final NfcHardwareMode mode;

  /// ISO 7816-4 Host Card Emulation Application ID for Marprom JMPP validators.
  final String aidHex;

  /// Whether an active digital ticket payload is currently loaded in the phone's NFC HCE service.
  final bool isHceArmed;

  /// Whether the system NFC radio is currently switched on.
  final bool isNfcEnabled;
}

/// Abstract contract for contactless NFC transit ticket reading, HCE arming, and validation.
abstract class TicketCardReader {
  /// Returns true when physical NFC card / HCE emulation is supported and active.
  Future<bool> isAvailable();

  /// Returns the current NFC chip / HCE hardware status and availability note.
  Future<NfcCardReaderStatus> readCardStatus();

  /// Arms the phone's built-in NFC chip (HCE) with [payload] for [ticketId].
  Future<bool> armTicketForNfc({
    required String ticketId,
    required String payload,
  });

  /// Opens device NFC system settings when NFC radio is disabled (Android).
  Future<void> openNfcSettings();

  /// Validates/simulates tapping the phone's NFC chip at a bus validator for [ticketId].
  Future<DateTime> simulateTapValidation(String ticketId);
}

/// Stub [TicketCardReader] reporting NFC card support as coming soon (preserved for compatibility tests).
class StubTicketCardReader implements TicketCardReader {
  /// Creates a [StubTicketCardReader] with an optional deterministic [clock].
  const StubTicketCardReader({this._clock});

  /// Canonical stub availability message returned until native NFC lands.
  static const String comingSoonMessage = 'NFC card in app coming soon';

  final DateTime Function()? _clock;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<NfcCardReaderStatus> readCardStatus() async {
    return const NfcCardReaderStatus(
      isAvailable: false,
      message: comingSoonMessage,
    );
  }

  @override
  Future<bool> armTicketForNfc({
    required String ticketId,
    required String payload,
  }) async =>
      ticketId.trim().isNotEmpty && payload.trim().isNotEmpty;

  @override
  Future<void> openNfcSettings() async {}

  @override
  Future<DateTime> simulateTapValidation(String ticketId) async {
    if (ticketId.trim().isEmpty) {
      throw ArgumentError.value(ticketId, 'ticketId', 'Must not be empty.');
    }
    return (_clock ?? DateTime.now)();
  }
}

/// Platform-aware NFC HCE bridge communicating with native Android `HostApduService`
/// via `MethodChannel('si.marprom.m_mobilnost/nfc')`, with graceful fallback on Web/Desktop/tests.
class PlatformNfcTicketCardReader implements TicketCardReader {
  /// Creates a [PlatformNfcTicketCardReader].
  PlatformNfcTicketCardReader({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const MethodChannel _channel =
      MethodChannel('si.marprom.m_mobilnost/nfc');
  static const String marpromAidHex = 'F04D415250524F4D01';

  final DateTime Function() _clock;
  String? _lastArmedTicketId;

  bool get _canUseAndroidNfcChannel =>
      !kIsWeb &&
      !isFlutterTestEnvironment &&
      defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isAvailable() async {
    final status = await readCardStatus();
    return status.isAvailable;
  }

  @override
  Future<NfcCardReaderStatus> readCardStatus() async {
    if (_canUseAndroidNfcChannel) {
      try {
        final raw =
            await _channel.invokeMapMethod<String, dynamic>('getNfcStatus');
        if (raw != null) {
          final hasNfc = raw['hasNfcHardware'] as bool? ?? false;
          final isEnabled = raw['isNfcEnabled'] as bool? ?? false;
          final hasHce = raw['hasHce'] as bool? ?? false;
          final isArmed = raw['isHceArmed'] as bool? ?? false;
          final aid = raw['aidHex'] as String? ?? marpromAidHex;

          if (hasNfc && hasHce && isEnabled) {
            return NfcCardReaderStatus(
              isAvailable: true,
              mode: NfcHardwareMode.hceReady,
              aidHex: aid,
              isHceArmed: isArmed,
              isNfcEnabled: true,
              message:
                  'Vgrajeni NFC čip (HCE) pripravljen • prislonite telefon k validatorju na avtobusu.',
            );
          }
          if (hasNfc && !isEnabled) {
            return NfcCardReaderStatus(
              isAvailable: false,
              mode: NfcHardwareMode.nfcDisabled,
              aidHex: aid,
              isHceArmed: isArmed,
              isNfcEnabled: false,
              message:
                  'NFC čip je v telefonu prisoten, vendar izklopljen v nastavitvah.',
            );
          }
        }
      } catch (_) {
        // In unit/widget tests or unsupported bindings, fall through to contactless fallback.
      }
    }

    return NfcCardReaderStatus(
      isAvailable: false,
      mode: NfcHardwareMode.simulatedContactless,
      aidHex: marpromAidHex,
      isHceArmed: _lastArmedTicketId != null,
      isNfcEnabled: false,
      message: kIsWeb
          ? 'Brskalnik ne dovoljuje oddajanja HCE NFC signala — na avtobusu pokažite QR kodo ali plačajte z brezstično kartico.'
          : 'Brezstični NFC čip (AID $marpromAidHex) pripravljen v načinu predogleda.',
    );
  }

  @override
  Future<bool> armTicketForNfc({
    required String ticketId,
    required String payload,
  }) async {
    if (ticketId.trim().isEmpty || payload.trim().isEmpty) return false;
    _lastArmedTicketId = ticketId;
    if (_canUseAndroidNfcChannel) {
      try {
        final ok = await _channel.invokeMethod<bool>('armTicketHce', {
          'ticketId': ticketId,
          'payload': payload,
        });
        return ok ?? true;
      } catch (_) {
        return true;
      }
    }
    return true;
  }

  @override
  Future<void> openNfcSettings() async {
    if (_canUseAndroidNfcChannel) {
      try {
        await _channel.invokeMethod<bool>('openNfcSettings');
      } catch (_) {}
    }
  }

  @override
  Future<DateTime> simulateTapValidation(String ticketId) async {
    if (ticketId.trim().isEmpty) {
      throw ArgumentError.value(ticketId, 'ticketId', 'Must not be empty.');
    }
    await armTicketForNfc(
      ticketId: ticketId,
      payload: 'MARPROM|NFC|$ticketId',
    );
    return _clock();
  }
}

/// Provides the active [TicketCardReader] implementation across the app.
final ticketCardReaderProvider = Provider<TicketCardReader>((ref) {
  return PlatformNfcTicketCardReader();
});
