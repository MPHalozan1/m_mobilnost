// Unit tests for polyline decoding and LineDirection road-segment geometry.

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/network/route_geometry_service.dart';
import 'package:m_mobilnost/core/utils/geo.dart';
import 'package:m_mobilnost/core/utils/polyline_codec.dart';
import 'package:m_mobilnost/data/models/bus_line.dart';
import 'package:m_mobilnost/data/models/trip_plan.dart';
import 'package:m_mobilnost/data/seed/seed_lines.dart';
import 'package:m_mobilnost/data/seed/seed_road_geometry.dart';
import 'package:m_mobilnost/data/seed/seed_stops.dart';
import 'package:m_mobilnost/data/simulation/bus_simulator.dart';

void main() {
  group('decodePolyline', () {
    test('decodes the reference Google polyline', () {
      final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points, hasLength(3));
      expect(points[0].latitude, closeTo(38.5, 1e-9));
      expect(points[0].longitude, closeTo(-120.2, 1e-9));
      expect(points[2].latitude, closeTo(43.252, 1e-9));
      expect(points[2].longitude, closeTo(-126.453, 1e-9));
      expect(decodePolyline(''), isEmpty);
    });
  });

  group('LineDirection road geometry', () {
    const a = LatLng(46.55, 15.60);
    const b = LatLng(46.56, 15.62);
    const c = LatLng(46.57, 15.63);
    const d = LatLng(46.58, 15.65);
    const direction = LineDirection(
      id: 't_out',
      name: 'A - D',
      terminalStopId: 'd',
      stopIds: ['a', 'b', 'c', 'd'],
      polyline: [a, b, c, d],
      roadSegments: [
        [a, LatLng(46.552, 15.615), b],
        [], // Missing geometry -> straight fallback.
        [c, LatLng(46.575, 15.635), LatLng(46.578, 15.645), d],
      ],
    );

    test('segments fall back to straight lines when geometry is missing', () {
      expect(direction.segmentCount, 3);
      expect(direction.segment(1), [b, c]);
      expect(direction.segment(3), isEmpty);
      const bare = LineDirection(
        id: 'bare',
        name: 'bare',
        terminalStopId: 'b',
        stopIds: ['a', 'b'],
        polyline: [a, b],
      );
      expect(bare.routePolyline, [a, b]);
      expect(bare.roadPolyline, isNull);
    });

    test('roadPathBetween joins segments without duplicate joints', () {
      final path = direction.roadPathBetween(0, 3);
      expect(path.first, a);
      expect(path.last, d);
      expect(path, hasLength(3 + 1 + 3));
      for (var i = 0; i < path.length - 1; i++) {
        expect(path[i], isNot(path[i + 1]));
      }
      expect(direction.routePolyline, path);
      expect(LineDirection.joinSegments(direction.roadSegments).length, 3 + 4);

      expect(direction.roadPathBetween(1, 2), [b, c]);
      expect(direction.roadPathBetween(2, 2), [c]);
      expect(direction.roadPathBetween(-5, 1).first, a);
      expect(direction.roadPathBetween(2, 99).last, d);
    });

    test('seeded directions expose continuous road segments near their stops',
        () {
      var bundled = 0;
      for (final line in seedLines) {
        for (final dir in line.directions) {
          expect(dir.roadSegments, hasLength(dir.stopIds.length - 1));
          for (var i = 0; i < dir.segmentCount; i++) {
            final segment = dir.segment(i);
            expect(segment.length, greaterThanOrEqualTo(2));
            final key = '${dir.stopIds[i]}>${dir.stopIds[i + 1]}';
            if (!seedRoadSegmentsEncoded.containsKey(key)) {
              // Missing pair -> straight stop-to-stop fallback.
              expect(segment, [dir.polyline[i], dir.polyline[i + 1]]);
              continue;
            }
            bundled++;
            // Pure road geometry: ends sit on the road next to the stops.
            // Europark's map coordinate lies inside the mall, so routing uses
            // the real OSM stop (tool/fetch_bus_routes.ps1 override): allow
            // more distance from the marker there.
            double limitFor(String stopId) => stopId == 'europark' ? 250 : 150;
            expect(
              GeoUtils.haversineMeters(segment.first, dir.polyline[i]),
              lessThan(limitFor(dir.stopIds[i])),
              reason: '$key start',
            );
            expect(
              GeoUtils.haversineMeters(segment.last, dir.polyline[i + 1]),
              lessThan(limitFor(dir.stopIds[i + 1])),
              reason: '$key end',
            );
            if (i + 1 < dir.segmentCount) {
              final nextKey = '${dir.stopIds[i + 1]}>${dir.stopIds[i + 2]}';
              if (seedRoadSegmentsEncoded.containsKey(nextKey)) {
                // Consecutive segments must meet on the road.
                expect(
                  GeoUtils.haversineMeters(
                    segment.last,
                    dir.segment(i + 1).first,
                  ),
                  lessThan(30),
                  reason: '$key -> $nextKey joint',
                );
              }
            }
          }
          expect(dir.roadPolyline, isNotNull);
          expect(dir.roadPolyline, dir.routePolyline);
          expect(dir.routePolyline, dir.roadPathBetween(0, dir.segmentCount));
          expect(seedStopsById[dir.terminalStopId], isNotNull);
        }
      }
      if (seedRoadSegmentsEncoded.isNotEmpty) {
        expect(bundled, greaterThan(0));
      }
    });
  });

  group('Planner legs and simulator use bus road geometry', () {
    final line = seedLines.first;
    final dir = line.directions.first;

    test('roadPathForBusLeg follows the line between its stops', () {
      final leg = TripLeg(
        type: TripLegType.bus,
        fromName: 'A',
        toName: 'B',
        fromStopId: dir.stopIds[1],
        toStopId: dir.stopIds[3],
        startTime: DateTime(2026, 11, 23, 8),
        endTime: DateTime(2026, 11, 23, 8, 10),
        durationMinutes: 10,
        distanceMeters: 1000,
        lineId: line.id,
        lineCode: line.code,
        polyline: [dir.polyline[1], dir.polyline[3]],
      );
      expect(roadPathForBusLeg(leg), dir.roadPathBetween(1, 3));

      final walk = TripLeg(
        type: TripLegType.walk,
        fromName: 'A',
        toName: 'B',
        startTime: DateTime(2026, 11, 23, 8),
        endTime: DateTime(2026, 11, 23, 8, 5),
        durationMinutes: 5,
        distanceMeters: 300,
        polyline: const [LatLng(46.55, 15.6), LatLng(46.56, 15.61)],
      );
      expect(roadPathForBusLeg(walk), same(walk.polyline));
    });

    test('simulated buses stay on the road segment of their current stop pair',
        () {
      final sim = BusSimulator(seed: 42, useSimulatedLive: true);
      addTearDown(sim.dispose);
      final buses = sim.snapshotAt(DateTime(2026, 11, 23, 8, 10));
      expect(buses, isNotEmpty);
      for (final bus in buses.take(60)) {
        final d = seedLinesById[bus.lineId]!.directionById(bus.directionId)!;
        final nextIdx = d.stopIds.indexOf(bus.nextStopId);
        final segment = d.segment(nextIdx > 0 ? nextIdx - 1 : 0);
        final nearest = segment
            .map((p) => GeoUtils.haversineMeters(p, bus.position))
            .reduce((x, y) => x < y ? x : y);
        final span = GeoUtils.polylineLengthMeters(segment);
        expect(nearest, lessThanOrEqualTo(span + 1), reason: bus.vehicleId);
        expect(bus.progress, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
