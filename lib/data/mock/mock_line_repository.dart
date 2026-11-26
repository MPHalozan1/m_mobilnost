// Mock LineRepository backed by fictional Maribor seed lines, stops, and places.

import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/utils/geo.dart';

import '../models/bus_line.dart';
import '../models/bus_stop.dart';
import '../models/place.dart';
import '../repositories/line_repository.dart';
import '../seed/seed_lines.dart';
import '../seed/seed_places.dart';
import '../seed/seed_stops.dart';

/// In-memory mock [LineRepository] serving seeded Maribor transit topology.
class MockLineRepository implements LineRepository {
  /// Creates a [MockLineRepository] serving the seeded Maribor network.
  const MockLineRepository();

  @override
  Future<List<BusLine>> getLines() async => List<BusLine>.unmodifiable(seedLines);

  @override
  Future<BusLine?> getLineById(String lineId) async => seedLinesById[lineId];

  @override
  Future<List<BusStop>> getStops() async => List<BusStop>.unmodifiable(seedStops);

  @override
  Future<BusStop?> getStopById(String stopId) async => seedStopsById[stopId];

  @override
  Future<List<BusStop>> searchStops(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return getStops();
    return seedStops.where((stop) {
      if (stop.name.toLowerCase().contains(trimmed)) return true;
      return stop.lineIds.any((code) => code.toLowerCase() == trimmed);
    }).toList(growable: false);
  }

  @override
  Future<List<BusStop>> getNearbyStops(
    LatLng position, {
    double maxDistanceMeters = 1500,
    int limit = 10,
  }) async {
    final scored = <(BusStop, double)>[];
    for (final stop in seedStops) {
      final meters = GeoUtils.haversineMeters(position, stop.position);
      if (meters <= maxDistanceMeters) {
        scored.add((stop, meters));
      }
    }
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    return scored.take(limit).map((e) => e.$1).toList(growable: false);
  }

  @override
  Future<List<Place>> getPlaces() async =>
      List<Place>.unmodifiable(allSearchablePlaces);

  @override
  Future<List<Place>> searchPlaces(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return getPlaces();
    return allSearchablePlaces.where((place) {
      return place.name.toLowerCase().contains(trimmed) ||
          place.address.toLowerCase().contains(trimmed) ||
          place.category.toLowerCase().contains(trimmed) ||
          place.aliases.any((a) => a.toLowerCase().contains(trimmed));
    }).toList(growable: false);
  }
}
