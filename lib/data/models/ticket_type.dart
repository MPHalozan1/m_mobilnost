// Defines the TicketType catalog model with 4-language localized metadata and EUR pricing.

import 'package:flutter/foundation.dart';

/// Official Marprom Mestni promet ticket category groupings.
enum TicketFareGroup {
  /// Single 75-min and 10-ride coupon tickets (`Enkratne & kuponske`).
  singleAndCoupon,

  /// 1-day, off-peak day, 2-day, and 3-day passes (`Dnevne & večdnevne`).
  dailyAndMultiDay,

  /// Monthly, school, IJPP solo, and annual commuter passes (`Mesečne & letne`).
  monthlyAndAnnual,

  /// Combined bus + Zone A / Zone B Park & Ride passes (`Kombinirane P+R`).
  parkAndRide,
}

/// Represents a purchasable Marprom bus ticket product.
@immutable
class TicketType {
  /// Creates a [TicketType] with localized names, duration, price, and rules.
  const TicketType({
    required this.id,
    required this.code,
    required this.titles,
    required this.descriptions,
    required this.durationMinutes,
    required this.priceEur,
    this.fareGroup = TicketFareGroup.singleAndCoupon,
    this.ridesCount = 1,
    this.isYouthOnly = false,
    this.isSeniorOnly = false,
    this.zone = 'Maribor JMPP',
  });

  /// Unique product identifier.
  final String id;

  /// Short product code used in QR payloads and URLs.
  final String code;

  /// Localized product titles keyed by `sl`, `en`, `de`, `sr_Latn`.
  final Map<String, String> titles;

  /// Localized product descriptions keyed by `sl`, `en`, `de`, `sr_Latn`.
  final Map<String, String> descriptions;

  /// Validity duration in minutes from activation.
  final int durationMinutes;

  /// Ticket price in Euros (EUR).
  final double priceEur;

  /// Category tab for ticket shop filtering.
  final TicketFareGroup fareGroup;

  /// Included ride count (`1` for single/passes, `10` for coupon bundles).
  final int ridesCount;

  /// Whether the ticket is restricted to eligible youth/student riders.
  final bool isYouthOnly;

  /// Whether the ticket is restricted to senior riders (65+).
  final bool isSeniorOnly;

  /// Geographic fare zone (e.g. `Maribor JMPP`).
  final String zone;

  /// Returns the localized title for [localeCode] with `sl`/`en` fallbacks.
  String localizedTitle(String localeCode) => _pickLocalized(titles, localeCode);

  /// Returns the localized description for [localeCode] with `sl`/`en` fallbacks.
  String localizedDescription(String localeCode) =>
      _pickLocalized(descriptions, localeCode);

  static String _pickLocalized(Map<String, String> map, String localeCode) {
    final normalized = localeCode == 'sr' ? 'sr_Latn' : localeCode;
    return map[normalized] ??
        map['sl'] ??
        map['en'] ??
        (map.values.isEmpty ? '' : map.values.first);
  }
}
