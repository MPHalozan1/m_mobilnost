// Defines the Place model for searchable Maribor points of interest and addresses.

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Searchable Maribor destination or point of interest linked to nearby stops.
@immutable
class Place {
  /// Creates a [Place] record for trip planner and destination search.
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.position,
    required this.nearestStopIds,
    this.aliases = const [],
    this.brandGroup,
  });

  /// Unique place identifier.
  final String id;

  /// Public name of the landmark, institution, or address.
  final String name;

  /// Category key (for example `hospital`, `university`, `shopping`, `transit`).
  final String category;

  /// Street address in Maribor.
  final String address;

  /// Geographic coordinate of the destination.
  final LatLng position;

  /// Nearest Marprom stop IDs serving this destination.
  final List<String> nearestStopIds;

  /// Colloquial/Slovene/abbreviation aliases for smarter local & AI matching
  /// (e.g. `['mc', 'mek', 'mekdonalds', 'mcdonalds']`).
  final List<String> aliases;

  /// Shared chain/brand group identifier when multiple branches exist in Maribor
  /// (e.g. `'mcdonalds'`, `'hofer'`, `'lidl'`, `'spar'`).
  final String? brandGroup;
}
