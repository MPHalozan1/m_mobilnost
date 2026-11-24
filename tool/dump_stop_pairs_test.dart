// Dumps every consecutive stop pair used by the seeded lines (both directions)
// so road geometry can be generated for it.
//
//   flutter test tool/dump_stop_pairs_test.dart
// writes build/stop_pairs.json

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:m_mobilnost/data/seed/seed_lines.dart';
import 'package:m_mobilnost/data/seed/seed_stops.dart';

void main() {
  test('dump stop pairs', () {
    final pairs = <String, Map<String, Object>>{};
    for (final line in seedLines) {
      for (final dir in line.directions) {
        for (var i = 0; i < dir.stopIds.length - 1; i++) {
          final a = seedStopsById[dir.stopIds[i]]!;
          final b = seedStopsById[dir.stopIds[i + 1]]!;
          pairs.putIfAbsent('${a.id}>${b.id}', () => {
                'from': a.id,
                'to': b.id,
                'fromName': a.name,
                'toName': b.name,
                'fromLat': a.position.latitude,
                'fromLng': a.position.longitude,
                'toLat': b.position.latitude,
                'toLng': b.position.longitude,
                'lines': <String>[],
              });
          (pairs['${a.id}>${b.id}']!['lines']! as List<String>).add(dir.id);
        }
      }
    }
    final stops = [
      for (final s in seedStops)
        {
          'id': s.id,
          'name': s.name,
          'lat': s.position.latitude,
          'lng': s.position.longitude,
        },
    ];
    File('build/stop_pairs.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent(' ')
            .convert({'pairs': pairs.values.toList(), 'stops': stops}),
      );
  });
}
