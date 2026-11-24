// Builds lib/data/seed/seed_road_geometry.dart from bus route responses.
//
// Pipeline (re-runnable end to end):
//   1. flutter test tool/dump_stop_pairs_test.dart      -> build/stop_pairs.json
//   2. powershell -File tool/fetch_bus_routes.ps1       -> $OSRM_DIR/<from>__<to>.json
//      (routes each line direction as one bus trip with Valhalla costing=bus,
//      split per stop pair, stored in OSRM response shape)
//   3. flutter test tool/build_road_geometry_test.dart   -> seed_road_geometry.dart
//
// Environment variables (all optional):
//   OSRM_DIR     directory with the per-pair route responses
//   REPORT_PATH  where the quality report is written
//
// Each segment follows the routed road geometry between the two stops (with
// PIN_TO_STOPS=1 it is also forced to start/end exactly at the stop
// coordinates). It is simplified with Douglas-Peucker (~2 m) and
// stored as a Google encoded polyline (precision 1e5). Pairs without a usable
// OSRM response are omitted (the app then draws a straight line).

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

const _defaultOsrmDir =
    'build/route_responses';
const _defaultReportPath =
    'build/route_report.txt';
const _pairsPath = 'build/stop_pairs.json';
const _outPath = 'lib/data/seed/seed_road_geometry.dart';

const double _simplifyToleranceM = 2.0;
const double _endSpikeM = 25.0;
const double _flagRatio = 1.8;
const double _flagRatioMinLengthM = 400.0;
const double _flagSnapM = 40.0;
const double _uTurnDegrees = 150.0;
const double _uTurnWindowM = 60.0;

class _P {
  const _P(this.lat, this.lng);
  final double lat;
  final double lng;
}

const double _earthR = 6371008.8;

double _rad(double d) => d * math.pi / 180.0;

/// Haversine distance in metres.
double _dist(_P a, _P b) {
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthR * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Local equirectangular projection (metres) around a reference latitude.
class _Proj {
  _Proj(double refLat) : _k = math.cos(_rad(refLat));
  final double _k;
  List<double> xy(_P p) => [_rad(p.lng) * _earthR * _k, _rad(p.lat) * _earthR];
}

double _len(List<_P> pts) {
  var s = 0.0;
  for (var i = 1; i < pts.length; i++) {
    s += _dist(pts[i - 1], pts[i]);
  }
  return s;
}

/// Index of the first point after [i] that is at least [minM] from pts[i].
int? _aheadIndex(List<_P> pts, int i, int step, {double minM = 5}) {
  for (var j = i + step; j >= 0 && j < pts.length; j += step) {
    if (_dist(pts[i], pts[j]) >= minM) return j;
  }
  return null;
}

/// Drops leading OSRM points lying "behind" [stop] (within 25 m), i.e. where
/// going stop -> p0 -> onward would be a back-and-forth spike.
List<_P> _trimStart(_P stop, List<_P> osrm, _Proj proj) {
  final pts = List<_P>.of(osrm);
  while (pts.length >= 2) {
    final p0 = pts.first;
    final d = _dist(stop, p0);
    if (d >= _endSpikeM) break;
    if (d < 0.05) {
      pts.removeAt(0); // duplicate of the stop itself
      continue;
    }
    final j = _aheadIndex(pts, 0, 1);
    if (j == null) break;
    final s = proj.xy(stop), a = proj.xy(p0), b = proj.xy(pts[j]);
    final dot = (a[0] - s[0]) * (b[0] - a[0]) + (a[1] - s[1]) * (b[1] - a[1]);
    if (dot < 0) {
      pts.removeAt(0);
    } else {
      break;
    }
  }
  return pts;
}

List<_P> _trimEnd(_P stop, List<_P> osrm, _Proj proj) =>
    _trimStart(stop, osrm.reversed.toList(), proj).reversed.toList();

List<_P> _douglasPeucker(List<_P> pts, double tol, _Proj proj) {
  if (pts.length <= 2) return pts;
  final xy = pts.map(proj.xy).toList();
  final keep = List<bool>.filled(pts.length, false);
  keep[0] = true;
  keep[pts.length - 1] = true;
  final stack = <List<int>>[
    [0, pts.length - 1]
  ];
  while (stack.isNotEmpty) {
    final r = stack.removeLast();
    final s = r[0], e = r[1];
    if (e <= s + 1) continue;
    var maxD = -1.0;
    var idx = -1;
    for (var i = s + 1; i < e; i++) {
      final d = _segDist(xy[i], xy[s], xy[e]);
      if (d > maxD) {
        maxD = d;
        idx = i;
      }
    }
    if (maxD > tol) {
      keep[idx] = true;
      stack.add([s, idx]);
      stack.add([idx, e]);
    }
  }
  return [for (var i = 0; i < pts.length; i++) if (keep[i]) pts[i]];
}

double _segDist(List<double> p, List<double> a, List<double> b) {
  final dx = b[0] - a[0], dy = b[1] - a[1];
  final l2 = dx * dx + dy * dy;
  var t = l2 == 0 ? 0.0 : ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2;
  t = t.clamp(0.0, 1.0);
  final x = a[0] + t * dx - p[0], y = a[1] + t * dy - p[1];
  return math.sqrt(x * x + y * y);
}

String _encode(List<_P> pts) {
  final sb = StringBuffer();
  var pLat = 0, pLng = 0;
  void enc(int v) {
    var x = v < 0 ? ~(v << 1) : (v << 1);
    while (x >= 0x20) {
      sb.writeCharCode((0x20 | (x & 0x1f)) + 63);
      x >>= 5;
    }
    sb.writeCharCode(x + 63);
  }

  for (final p in pts) {
    final lat = (p.lat * 1e5).round(), lng = (p.lng * 1e5).round();
    enc(lat - pLat);
    enc(lng - pLng);
    pLat = lat;
    pLng = lng;
  }
  return sb.toString();
}

/// Heading reversals > 150 deg between segments that are within 60 m of each
/// other along the track and spatially close (excludes ordinary roundabouts).
String? _detectUTurn(List<_P> pts, _Proj proj) {
  final xy = pts.map(proj.xy).toList();
  final segs = <List<double>>[]; // [heading, cumStart, cumEnd, midX, midY]
  var cum = 0.0;
  for (var i = 1; i < xy.length; i++) {
    final dx = xy[i][0] - xy[i - 1][0], dy = xy[i][1] - xy[i - 1][1];
    final l = math.sqrt(dx * dx + dy * dy);
    if (l >= 1.0) {
      segs.add([
        math.atan2(dy, dx),
        cum,
        cum + l,
        (xy[i][0] + xy[i - 1][0]) / 2,
        (xy[i][1] + xy[i - 1][1]) / 2,
      ]);
    }
    cum += l;
  }
  for (var i = 0; i < segs.length; i++) {
    for (var j = i + 1; j < segs.length; j++) {
      if (segs[j][1] - segs[i][2] > _uTurnWindowM) break;
      var diff = (segs[j][0] - segs[i][0]).abs() * 180 / math.pi;
      if (diff > 180) diff = 360 - diff;
      if (diff <= _uTurnDegrees) continue;
      final mx = segs[j][3] - segs[i][3], my = segs[j][4] - segs[i][4];
      if (math.sqrt(mx * mx + my * my) <= 20) {
        return 'UTURN@${segs[i][2].round()}m';
      }
    }
  }
  return null;
}

bool _segmentsIntersect(List<double> a, List<double> b, List<double> c, List<double> d) {
  double cross(List<double> o, List<double> p, List<double> q) =>
      (p[0] - o[0]) * (q[1] - o[1]) - (p[1] - o[1]) * (q[0] - o[0]);
  final d1 = cross(c, d, a), d2 = cross(c, d, b);
  final d3 = cross(a, b, c), d4 = cross(a, b, d);
  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

bool _selfCrosses(List<_P> pts, _Proj proj) {
  final xy = pts.map(proj.xy).toList();
  for (var i = 0; i < xy.length - 1; i++) {
    for (var j = i + 2; j < xy.length - 1; j++) {
      if (_segmentsIntersect(xy[i], xy[i + 1], xy[j], xy[j + 1])) return true;
    }
  }
  return false;
}

class _Row {
  _Row(this.key, this.road, this.straight, this.snapA, this.snapB, this.flags, this.points,
      this.status);
  final String key;
  final double road, straight, snapA, snapB;
  final List<String> flags;
  final int points;
  final String status;
}

void main() {
  test('build road geometry', () {
    final osrmDir = Platform.environment['OSRM_DIR'] ?? _defaultOsrmDir;
    final reportPath = Platform.environment['REPORT_PATH'] ?? _defaultReportPath;
    final data = jsonDecode(File(_pairsPath).readAsStringSync()) as Map<String, dynamic>;
    final pairs = (data['pairs'] as List).cast<Map<String, dynamic>>();

    final out = <String, String>{};
    final rows = <_Row>[];
    var missing = 0, failed = 0;

    for (final pair in pairs) {
      final from = pair['from'] as String, to = pair['to'] as String;
      final key = '$from>$to';
      final a = _P((pair['fromLat'] as num).toDouble(), (pair['fromLng'] as num).toDouble());
      final b = _P((pair['toLat'] as num).toDouble(), (pair['toLng'] as num).toDouble());
      final straight = _dist(a, b);
      final f = File('$osrmDir${Platform.pathSeparator}${from}__$to.json');
      if (!f.existsSync()) {
        missing++;
        rows.add(_Row(key, 0, straight, 0, 0, ['MISSING'], 0, 'missing'));
        continue;
      }
      Map<String, dynamic> js;
      try {
        js = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {
        failed++;
        rows.add(_Row(key, 0, straight, 0, 0, ['FAILED(json)'], 0, 'failed'));
        continue;
      }
      final routes = js['routes'] as List?;
      if (js['code'] != 'Ok' || routes == null || routes.isEmpty) {
        failed++;
        rows.add(_Row(key, 0, straight, 0, 0, ['FAILED(${js['code']})'], 0, 'failed'));
        continue;
      }
      final coords = ((routes.first as Map)['geometry']['coordinates'] as List)
          .map((c) => _P((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      final wps = (js['waypoints'] as List?) ?? const [];
      double snap(int i) =>
          i < wps.length ? ((wps[i] as Map)['distance'] as num? ?? 0).toDouble() : 0;
      final snapA = snap(0), snapB = snap(wps.length - 1);

      final proj = _Proj((a.lat + b.lat) / 2);
      // PIN_TO_STOPS=1 forces the segment to start/end exactly at the stop
      // coordinates (good when stops sit on the road). Default: keep the pure
      // road path, so stops placed off the road do not create spikes.
      final pin = Platform.environment['PIN_TO_STOPS'] == '1';
      final List<_P> full;
      if (pin) {
        var mid = _trimStart(a, coords, proj);
        mid = _trimEnd(b, mid, proj);
        full = <_P>[a, ...mid, b];
      } else {
        full = coords.length >= 2 ? coords : <_P>[a, b];
      }
      final simplified = _douglasPeucker(full, _simplifyToleranceM, proj);
      final road = _len(full);

      final flags = <String>[];
      final ratio = straight > 0 ? road / straight : 0.0;
      if (ratio > _flagRatio && road > _flagRatioMinLengthM) {
        flags.add('RATIO');
      }
      if (snapA > _flagSnapM || snapB > _flagSnapM) flags.add('SNAP');
      final ut = _detectUTurn(full, proj);
      if (ut != null) flags.add(ut);
      if (_selfCrosses(simplified, proj)) flags.add('CROSS');

      out[key] = _encode(simplified);
      rows.add(_Row(key, road, straight, snapA, snapB, flags, simplified.length, 'ok'));
    }

    // ---- write Dart file ----
    final keys = out.keys.toList()..sort();
    final sb = StringBuffer()
      ..writeln('// GENERATED FILE - do not edit by hand.')
      ..writeln('// Generated by tool/build_road_geometry_test.dart '
          '(flutter test tool/build_road_geometry_test.dart).')
      ..writeln('// Road-following geometry between consecutive stops.')
      ..writeln('// Map data © OpenStreetMap contributors (ODbL), routed with Valhalla (bus).')
      ..writeln('//')
      ..writeln("// Key: '<fromStopId>><toStopId>' (directional). Value: Google encoded "
          'polyline')
      ..writeln('// (precision 1e5) that starts at the from-stop and ends at the to-stop.')
      ..writeln('// Pairs missing here fall back to a straight line in the app.')
      ..writeln()
      ..writeln('/// Encoded road geometry per directional stop pair.')
      ..writeln('const Map<String, String> seedRoadSegmentsEncoded = <String, String>{');
    for (final k in keys) {
      final v = out[k]!;
      // Encoded polylines only use chars 63..126, so a raw string is always safe.
      expect(v.contains("'"), isFalse);
      sb.writeln("  r'$k':");
      sb.writeln("      r'$v',");
    }
    sb.writeln('};');
    File(_outPath).writeAsStringSync(sb.toString());

    // ---- write report ----
    rows.sort((x, y) {
      final fx = x.flags.isEmpty ? 1 : 0, fy = y.flags.isEmpty ? 1 : 0;
      if (fx != fy) return fx - fy;
      return x.key.compareTo(y.key);
    });
    final rep = StringBuffer()
      ..writeln('Road geometry report  (generated ${keys.length}, missing $missing, '
          'failed $failed, total ${pairs.length})')
      ..writeln('${'pair'.padRight(52)} ${'road_m'.padLeft(7)} ${'line_m'.padLeft(7)} '
          '${'ratio'.padLeft(5)} ${'snapA'.padLeft(6)} ${'snapB'.padLeft(6)} '
          '${'pts'.padLeft(4)}  FLAG');
    for (final r in rows) {
      final ratio = r.straight > 0 && r.road > 0 ? r.road / r.straight : 0.0;
      rep.writeln('${r.key.padRight(52)} ${r.road.toStringAsFixed(0).padLeft(7)} '
          '${r.straight.toStringAsFixed(0).padLeft(7)} '
          '${ratio.toStringAsFixed(2).padLeft(5)} '
          '${r.snapA.toStringAsFixed(1).padLeft(6)} '
          '${r.snapB.toStringAsFixed(1).padLeft(6)} '
          '${r.points.toString().padLeft(4)}  ${r.flags.join(',')}');
    }
    File(reportPath).writeAsStringSync(rep.toString());

    // ignore: avoid_print
    print('generated ${keys.length}, missing $missing, failed $failed; '
        '${File(_outPath).lengthSync()} bytes -> $_outPath; report -> $reportPath');
  });
}
