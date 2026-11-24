// Official Marprom 7-day timetable generator synchronized with vozniredi.marprom.si.
// Encodes exact Pon-Pet, Sobota, and Nedelja/Prazniki operating spans and non-operating Sunday lines (G5, P9, P13, P14, P17, P19).

import 'package:m_mobilnost/core/utils/geo.dart';

import '../models/bus_line.dart';
import 'seed_lines.dart';
import 'seed_stops.dart';

/// Operating calendar regimes used by the Marprom timetable engine.
enum DayScheduleType {
  /// Monday through Friday schedule (`Delavnik Pon–Pet`).
  weekday,

  /// Saturday schedule (`Sobota`).
  saturday,

  /// Sunday and Slovenian public holiday service (`Nedelja in prazniki`).
  sundayHoliday,
}

/// Summary of a line's service window on a given day.
class LineOperatingSummary {
  /// Creates a [LineOperatingSummary].
  const LineOperatingSummary({
    required this.operates,
    required this.tripCount,
    this.firstDeparture,
    this.lastDeparture,
  });

  /// False when this line does not run at all on the requested day (e.g. G5/P9/P13/P14/P17/P19 on Sunday).
  final bool operates;

  /// Number of scheduled terminal departures in this direction.
  final int tripCount;

  /// Formatted first departure (`HH:mm`), if [operates] is true.
  final String? firstDeparture;

  /// Formatted last departure (`HH:mm`), if [operates] is true.
  final String? lastDeparture;
}

/// Represents one complete scheduled bus run along a [LineDirection].
class ScheduledTrip {
  /// Creates a [ScheduledTrip] with per-stop scheduled departure timestamps.
  const ScheduledTrip({
    required this.tripId,
    required this.lineId,
    required this.lineCode,
    required this.directionId,
    required this.directionName,
    required this.stopIds,
    required this.stopTimes,
  });

  /// Deterministic trip identifier (`lineId_dirId_YYYYMMDD_HHMM`).
  final String tripId;

  /// Associated line ID.
  final String lineId;

  /// Short line code.
  final String lineCode;

  /// Direction ID on the line.
  final String directionId;

  /// Human-readable direction title.
  final String directionName;

  /// Ordered stops served by this trip.
  final List<String> stopIds;

  /// Scheduled departure timestamps aligned index-for-index with [stopIds].
  final List<DateTime> stopTimes;

  /// Terminal departure time at the first stop.
  DateTime get startTime => stopTimes.first;

  /// Terminal arrival time at the final stop.
  DateTime get endTime => stopTimes.last;
}

/// Represents a single scheduled stop event extracted from a [ScheduledTrip].
class ScheduledStopEvent {
  /// Creates a [ScheduledStopEvent] for a stop index along a trip.
  const ScheduledStopEvent({
    required this.trip,
    required this.stopId,
    required this.stopIndex,
    required this.scheduledTime,
  });

  /// Parent trip run.
  final ScheduledTrip trip;

  /// Stop ID for this departure.
  final String stopId;

  /// Zero-based index of [stopId] within [ScheduledTrip.stopIds].
  final int stopIndex;

  /// Scheduled departure timestamp at [stopId].
  final DateTime scheduledTime;
}

int _m(int hour, int minute) => hour * 60 + minute;

List<int> _times(List<(int, int)> pairs) =>
    [for (final (h, m) in pairs) h * 60 + m];

class _DayDirectionRule {
  const _DayDirectionRule.window({
    required this.firstMinute,
    required this.lastMinute,
    required this.peakMinutes,
    required this.offPeakMinutes,
    int? eveningMinutes,
    this.eveningStartMinute = 20 * 60,
  })  : operates = true,
        explicitMinutes = null,
        eveningMinutes = eveningMinutes ?? offPeakMinutes;

  const _DayDirectionRule.exact(this.explicitMinutes)
      : operates = true,
        firstMinute = 0,
        lastMinute = 0,
        peakMinutes = 0,
        offPeakMinutes = 0,
        eveningMinutes = 0,
        eveningStartMinute = 20 * 60;

  const _DayDirectionRule.noService()
      : operates = false,
        explicitMinutes = null,
        firstMinute = 0,
        lastMinute = 0,
        peakMinutes = 0,
        offPeakMinutes = 0,
        eveningMinutes = 0,
        eveningStartMinute = 20 * 60;

  final bool operates;
  final List<int>? explicitMinutes;
  final int firstMinute;
  final int lastMinute;
  final int peakMinutes;
  final int offPeakMinutes;
  final int eveningMinutes;
  final int eveningStartMinute;

  List<int> resolveMinutes() {
    if (!operates) return const [];
    if (explicitMinutes != null) return explicitMinutes!;
    final list = <int>[];
    var cursor = firstMinute;
    while (cursor <= lastMinute) {
      list.add(cursor);
      final isMorningPeak = cursor >= 6 * 60 && cursor <= 8 * 60 + 30;
      final isAfternoonPeak = cursor >= 12 * 60 + 45 && cursor <= 16 * 60 + 15;
      final isEvening = cursor >= eveningStartMinute;
      final step = isEvening
          ? eveningMinutes
          : ((isMorningPeak || isAfternoonPeak) ? peakMinutes : offPeakMinutes);
      cursor += step;
    }
    if (list.isNotEmpty && list.last < lastMinute - 10) {
      list.add(lastMinute);
    }
    return list;
  }
}

class _OfficialLineSchedule {
  const _OfficialLineSchedule({
    required this.weekdayOut,
    required this.weekdayIn,
    required this.saturdayOut,
    required this.saturdayIn,
    required this.sundayOut,
    required this.sundayIn,
  });

  final _DayDirectionRule weekdayOut;
  final _DayDirectionRule weekdayIn;
  final _DayDirectionRule saturdayOut;
  final _DayDirectionRule saturdayIn;
  final _DayDirectionRule sundayOut;
  final _DayDirectionRule sundayIn;

  _DayDirectionRule ruleFor(DayScheduleType type, {required bool isInbound}) {
    return switch (type) {
      DayScheduleType.weekday => isInbound ? weekdayIn : weekdayOut,
      DayScheduleType.saturday => isInbound ? saturdayIn : saturdayOut,
      DayScheduleType.sundayHoliday => isInbound ? sundayIn : sundayOut,
    };
  }
}

/// Verified Marprom day-by-day rules extracted from `vozniredi.marprom.si`.
final Map<String, _OfficialLineSchedule> _officialSchedules = {
  // G1 Tezno
  'G1': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 0),
      lastMinute: _m(23, 0),
      peakMinutes: 15,
      offPeakMinutes: 20,
      eveningMinutes: 25,
      eveningStartMinute: _m(21, 0),
    ),
    weekdayIn: _DayDirectionRule.window(
      firstMinute: _m(4, 35),
      lastMinute: _m(22, 30),
      peakMinutes: 15,
      offPeakMinutes: 20,
      eveningMinutes: 30,
      eveningStartMinute: _m(21, 0),
    ),
    saturdayOut: _DayDirectionRule.window(
      firstMinute: _m(6, 5),
      lastMinute: _m(23, 0),
      peakMinutes: 30,
      offPeakMinutes: 60,
      eveningMinutes: 60,
    ),
    saturdayIn: _DayDirectionRule.window(
      firstMinute: _m(5, 30),
      lastMinute: _m(22, 30),
      peakMinutes: 30,
      offPeakMinutes: 60,
      eveningMinutes: 60,
    ),
    sundayOut: _DayDirectionRule.window(
      firstMinute: _m(6, 5),
      lastMinute: _m(22, 5),
      peakMinutes: 60,
      offPeakMinutes: 60,
    ),
    sundayIn: _DayDirectionRule.window(
      firstMinute: _m(6, 30),
      lastMinute: _m(21, 30),
      peakMinutes: 60,
      offPeakMinutes: 60,
    ),
  ),

  // G2 Nova vas
  'G2': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 0),
      lastMinute: _m(22, 10),
      peakMinutes: 15,
      offPeakMinutes: 20,
      eveningMinutes: 30,
      eveningStartMinute: _m(20, 40),
    ),
    weekdayIn: _DayDirectionRule.window(
      firstMinute: _m(5, 10),
      lastMinute: _m(22, 10),
      peakMinutes: 15,
      offPeakMinutes: 20,
      eveningMinutes: 30,
      eveningStartMinute: _m(20, 40),
    ),
    saturdayOut: _DayDirectionRule.window(
      firstMinute: _m(6, 10),
      lastMinute: _m(22, 10),
      peakMinutes: 30,
      offPeakMinutes: 45,
      eveningMinutes: 60,
    ),
    saturdayIn: _DayDirectionRule.window(
      firstMinute: _m(5, 35),
      lastMinute: _m(22, 25),
      peakMinutes: 30,
      offPeakMinutes: 45,
      eveningMinutes: 60,
    ),
    sundayOut: _DayDirectionRule.window(
      firstMinute: _m(6, 10),
      lastMinute: _m(21, 10),
      peakMinutes: 60,
      offPeakMinutes: 60,
    ),
    sundayIn: _DayDirectionRule.window(
      firstMinute: _m(5, 35),
      lastMinute: _m(21, 35),
      peakMinutes: 60,
      offPeakMinutes: 60,
    ),
  ),

  // G3 Mestna krožna linija
  'G3': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 0),
      lastMinute: _m(22, 0),
      peakMinutes: 25,
      offPeakMinutes: 30,
      eveningMinutes: 30,
    ),
    weekdayIn: _DayDirectionRule.window(
      firstMinute: _m(4, 41),
      lastMinute: _m(22, 16),
      peakMinutes: 25,
      offPeakMinutes: 30,
      eveningMinutes: 30,
    ),
    saturdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 30),
      lastMinute: _m(22, 0),
      peakMinutes: 30,
      offPeakMinutes: 40,
      eveningMinutes: 60,
      eveningStartMinute: _m(15, 0),
    ),
    saturdayIn: _DayDirectionRule.window(
      firstMinute: _m(6, 11),
      lastMinute: _m(22, 11),
      peakMinutes: 30,
      offPeakMinutes: 40,
      eveningMinutes: 60,
      eveningStartMinute: _m(15, 0),
    ),
    sundayOut: _DayDirectionRule.window(
      firstMinute: _m(6, 0),
      lastMinute: _m(21, 0),
      peakMinutes: 60,
      offPeakMinutes: 60,
    ),
    sundayIn: _DayDirectionRule.window(
      firstMinute: _m(6, 11),
      lastMinute: _m(21, 11),
      peakMinutes: 60,
      offPeakMinutes: 60,
    ),
  ),

  // G4 Studenci–Limbuš
  'G4': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 0),
      lastMinute: _m(22, 20),
      peakMinutes: 20,
      offPeakMinutes: 30,
      eveningMinutes: 30,
    ),
    weekdayIn: _DayDirectionRule.window(
      firstMinute: _m(5, 0),
      lastMinute: _m(22, 20),
      peakMinutes: 25,
      offPeakMinutes: 30,
      eveningMinutes: 30,
    ),
    saturdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 30),
      lastMinute: _m(21, 30),
      peakMinutes: 35,
      offPeakMinutes: 40,
      eveningMinutes: 45,
    ),
    saturdayIn: _DayDirectionRule.window(
      firstMinute: _m(6, 0),
      lastMinute: _m(21, 20),
      peakMinutes: 35,
      offPeakMinutes: 40,
      eveningMinutes: 45,
    ),
    sundayOut: _DayDirectionRule.exact(
      _times([
        (6, 0), (7, 0), (8, 0), (9, 45), (11, 30), (13, 0),
        (14, 0), (15, 0), (17, 0), (19, 0), (21, 0),
      ]),
    ),
    sundayIn: _DayDirectionRule.exact(
      _times([
        (6, 25), (7, 25), (8, 30), (10, 15), (12, 0), (13, 30),
        (14, 30), (15, 30), (17, 30), (19, 30), (21, 30),
      ]),
    ),
  ),

  // G5 Rotovž — DOES NOT OPERATE ON SUNDAYS & HOLIDAYS
  'G5': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 5),
      lastMinute: _m(21, 45),
      peakMinutes: 25,
      offPeakMinutes: 30,
      eveningMinutes: 40,
    ),
    weekdayIn: _DayDirectionRule.window(
      firstMinute: _m(5, 5),
      lastMinute: _m(22, 10),
      peakMinutes: 25,
      offPeakMinutes: 30,
      eveningMinutes: 40,
    ),
    saturdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 15),
      lastMinute: _m(21, 55),
      peakMinutes: 40,
      offPeakMinutes: 90,
      eveningMinutes: 90,
    ),
    saturdayIn: _DayDirectionRule.window(
      firstMinute: _m(5, 40),
      lastMinute: _m(22, 10),
      peakMinutes: 40,
      offPeakMinutes: 90,
      eveningMinutes: 90,
    ),
    sundayOut: const _DayDirectionRule.noService(),
    sundayIn: const _DayDirectionRule.noService(),
  ),

  // G6 Vzpenjača
  'G6': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.window(
      firstMinute: _m(4, 50),
      lastMinute: _m(23, 0),
      peakMinutes: 12,
      offPeakMinutes: 20,
      eveningMinutes: 30,
      eveningStartMinute: _m(21, 0),
    ),
    weekdayIn: _DayDirectionRule.window(
      firstMinute: _m(4, 50),
      lastMinute: _m(23, 30),
      peakMinutes: 12,
      offPeakMinutes: 20,
      eveningMinutes: 30,
      eveningStartMinute: _m(21, 0),
    ),
    saturdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 40),
      lastMinute: _m(22, 50),
      peakMinutes: 30,
      offPeakMinutes: 30,
      eveningMinutes: 30,
    ),
    saturdayIn: _DayDirectionRule.window(
      firstMinute: _m(5, 40),
      lastMinute: _m(22, 50),
      peakMinutes: 30,
      offPeakMinutes: 30,
      eveningMinutes: 30,
    ),
    sundayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 40),
      lastMinute: _m(22, 10),
      peakMinutes: 30,
      offPeakMinutes: 60,
      eveningMinutes: 60,
    ),
    sundayIn: _DayDirectionRule.window(
      firstMinute: _m(5, 40),
      lastMinute: _m(21, 40),
      peakMinutes: 30,
      offPeakMinutes: 60,
      eveningMinutes: 60,
    ),
  ),

  // P7 Kamnica
  'P7': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.exact(
      _times([
        (5, 50), (6, 30), (7, 10), (7, 50), (8, 30), (9, 10), (9, 50),
        (10, 50), (11, 50), (12, 30), (13, 10), (13, 50), (14, 30), (15, 10),
        (15, 50), (16, 40), (17, 30), (18, 30), (19, 30), (20, 30), (21, 10),
        (22, 15),
      ]),
    ),
    weekdayIn: _DayDirectionRule.exact(
      _times([
        (5, 6), (6, 20), (7, 0), (7, 40), (8, 25), (9, 5), (9, 45),
        (10, 25), (11, 20), (12, 25), (13, 5), (13, 45), (14, 21), (15, 5),
        (15, 45), (16, 25), (17, 15), (18, 0), (19, 5), (20, 0), (21, 5),
        (21, 30),
      ]),
    ),
    saturdayOut: _DayDirectionRule.exact(
      _times([
        (5, 50), (6, 50), (7, 50), (9, 50), (11, 50), (12, 50),
        (13, 50), (14, 50), (15, 50), (17, 20), (18, 50), (20, 20),
      ]),
    ),
    saturdayIn: _DayDirectionRule.exact(
      _times([
        (6, 20), (7, 20), (8, 20), (10, 20), (12, 20), (13, 20),
        (14, 20), (15, 20), (16, 20), (17, 50), (19, 10), (21, 0),
      ]),
    ),
    sundayOut: _DayDirectionRule.exact(
      _times([
        (5, 50), (6, 50), (7, 50), (9, 50), (11, 50), (12, 50),
        (13, 50), (14, 50), (15, 50), (17, 20), (18, 50), (20, 20),
      ]),
    ),
    sundayIn: _DayDirectionRule.exact(
      _times([
        (6, 20), (7, 20), (8, 20), (10, 20), (12, 20), (13, 20),
        (14, 20), (15, 20), (16, 20), (17, 50), (19, 10), (21, 0),
      ]),
    ),
  ),

  // P8 Limbuš–Pekre
  'P8': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.exact(
      _times([
        (5, 30), (6, 15), (6, 50), (7, 30), (8, 10), (9, 10), (10, 25),
        (11, 35), (12, 25), (13, 15), (14, 0), (14, 40), (15, 15), (16, 0),
        (16, 45), (17, 45), (19, 0), (20, 15), (21, 35),
      ]),
    ),
    weekdayIn: _DayDirectionRule.exact(
      _times([
        (5, 25), (6, 0), (6, 45), (7, 25), (8, 5), (8, 45), (9, 45),
        (11, 0), (12, 10), (13, 10), (14, 0), (14, 30), (15, 15), (15, 55),
        (16, 35), (17, 20), (18, 20), (19, 35), (20, 50), (22, 0),
      ]),
    ),
    saturdayOut: _DayDirectionRule.exact(
      _times([
        (5, 50), (6, 50), (7, 50), (8, 50), (9, 50), (10, 50), (11, 50),
        (12, 50), (13, 50), (14, 50), (15, 50), (17, 20), (18, 20), (19, 20),
        (20, 20),
      ]),
    ),
    saturdayIn: _DayDirectionRule.exact(
      _times([
        (6, 20), (7, 20), (8, 20), (9, 20), (10, 20), (11, 20), (12, 20),
        (13, 20), (14, 20), (15, 20), (16, 20), (17, 50), (18, 50), (19, 50),
        (20, 50),
      ]),
    ),
    sundayOut: _DayDirectionRule.exact(
      _times([
        (6, 10), (7, 10), (8, 10), (10, 10), (12, 10), (13, 50),
        (14, 50), (15, 50), (17, 20), (18, 20), (19, 20), (20, 20),
      ]),
    ),
    sundayIn: _DayDirectionRule.exact(
      _times([
        (6, 35), (7, 35), (8, 35), (10, 40), (12, 40), (14, 20),
        (15, 20), (16, 20), (17, 50), (18, 50), (19, 50), (20, 50),
      ]),
    ),
  ),

  // P9 Zrkovci — Saturday finishes early (15:10), Sunday NO SERVICE
  'P9': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.exact(
      _times([
        (5, 25), (6, 25), (7, 30), (8, 35), (10, 10), (11, 55), (13, 25),
        (14, 30), (15, 35), (16, 40), (18, 10), (19, 40), (21, 20), (22, 20),
      ]),
    ),
    weekdayIn: _DayDirectionRule.exact(
      _times([
        (5, 2), (5, 55), (6, 55), (8, 0), (9, 12), (11, 0), (12, 47),
        (13, 55), (15, 0), (16, 5), (17, 17), (18, 47), (20, 17), (21, 55),
      ]),
    ),
    saturdayOut: _DayDirectionRule.exact(
      _times([
        (6, 10), (7, 10), (8, 10), (9, 40), (11, 10), (12, 10), (13, 10),
        (14, 10), (15, 10),
      ]),
    ),
    saturdayIn: _DayDirectionRule.exact(
      _times([
        (5, 40), (6, 47), (7, 40), (8, 47), (10, 17), (11, 40), (12, 47),
        (13, 40), (14, 47),
      ]),
    ),
    sundayOut: const _DayDirectionRule.noService(),
    sundayIn: const _DayDirectionRule.noService(),
  ),

  // P10 Malečnik
  'P10': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.exact(
      _times([
        (5, 20), (6, 35), (8, 0), (9, 10), (10, 30), (12, 0), (13, 20),
        (14, 40), (16, 15), (17, 30), (18, 55), (20, 20), (22, 0),
      ]),
    ),
    weekdayIn: _DayDirectionRule.exact(
      _times([
        (4, 45), (6, 5), (7, 15), (8, 40), (9, 50), (11, 15), (12, 45),
        (14, 10), (15, 30), (17, 0), (18, 20), (19, 45), (21, 5),
      ]),
    ),
    saturdayOut: _DayDirectionRule.exact(
      _times([
        (6, 45), (8, 35), (10, 45), (12, 20), (14, 25), (15, 45),
        (19, 30), (21, 15),
      ]),
    ),
    saturdayIn: _DayDirectionRule.exact(
      _times([
        (6, 0), (7, 15), (9, 15), (11, 30), (13, 5), (15, 5), (20, 10),
      ]),
    ),
    sundayOut: _DayDirectionRule.exact(
      _times([
        (8, 30), (10, 0), (11, 10), (12, 20), (14, 0), (15, 0), (16, 0),
        (17, 0), (18, 0), (19, 0), (20, 0),
      ]),
    ),
    sundayIn: _DayDirectionRule.exact(
      _times([
        (9, 10), (10, 40), (11, 50), (13, 5), (14, 35), (15, 35), (16, 35),
        (17, 35), (18, 35), (19, 35), (20, 35),
      ]),
    ),
  ),

  // P11 Razvanje
  'P11': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 15),
      lastMinute: _m(22, 15),
      peakMinutes: 40,
      offPeakMinutes: 50,
      eveningMinutes: 60,
    ),
    weekdayIn: _DayDirectionRule.window(
      firstMinute: _m(4, 45),
      lastMinute: _m(21, 50),
      peakMinutes: 40,
      offPeakMinutes: 50,
      eveningMinutes: 60,
    ),
    saturdayOut: _DayDirectionRule.window(
      firstMinute: _m(6, 15),
      lastMinute: _m(21, 15),
      peakMinutes: 60,
      offPeakMinutes: 75,
    ),
    saturdayIn: _DayDirectionRule.window(
      firstMinute: _m(5, 45),
      lastMinute: _m(21, 45),
      peakMinutes: 60,
      offPeakMinutes: 75,
    ),
    sundayOut: _DayDirectionRule.exact(
      _times([
        (6, 15), (8, 15), (10, 15), (12, 15), (14, 15), (16, 15),
        (18, 15), (20, 15),
      ]),
    ),
    sundayIn: _DayDirectionRule.exact(
      _times([
        (6, 45), (8, 47), (10, 47), (12, 47), (14, 47), (16, 45),
        (18, 47), (20, 45),
      ]),
    ),
  ),

  // P12 Dobrava–Supernova
  'P12': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.window(
      firstMinute: _m(4, 50),
      lastMinute: _m(22, 5),
      peakMinutes: 50,
      offPeakMinutes: 60,
      eveningMinutes: 65,
    ),
    weekdayIn: _DayDirectionRule.window(
      firstMinute: _m(4, 50),
      lastMinute: _m(21, 50),
      peakMinutes: 50,
      offPeakMinutes: 60,
      eveningMinutes: 60,
    ),
    saturdayOut: _DayDirectionRule.exact(
      _times([
        (6, 5), (7, 5), (8, 5), (9, 15), (10, 5), (11, 15), (12, 5),
        (13, 5), (14, 5), (15, 5), (16, 5), (18, 5), (20, 5),
      ]),
    ),
    saturdayIn: _DayDirectionRule.exact(
      _times([
        (7, 0), (8, 0), (9, 0), (10, 0), (11, 0), (12, 0), (13, 0),
        (14, 0), (15, 0), (17, 0), (19, 0), (21, 0),
      ]),
    ),
    sundayOut: _DayDirectionRule.exact(
      _times([(6, 5), (8, 5), (10, 5), (12, 5), (14, 5), (16, 5), (18, 5), (20, 5)]),
    ),
    sundayIn: _DayDirectionRule.exact(
      _times([(7, 0), (9, 0), (11, 0), (13, 0), (15, 0), (17, 0), (19, 0), (21, 0)]),
    ),
  ),

  // P13 Stražun–PC Tezno — Saturday finishes 14:25, Sunday NO SERVICE
  'P13': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.exact(
      _times([
        (5, 25), (6, 5), (6, 45), (7, 25), (8, 5), (8, 45), (9, 45),
        (10, 45), (11, 45), (12, 25), (13, 5), (13, 45), (14, 25), (15, 5),
        (15, 45), (16, 45), (17, 45), (18, 45), (19, 45), (20, 45), (21, 45),
      ]),
    ),
    weekdayIn: _DayDirectionRule.exact(
      _times([
        (4, 55), (5, 55), (7, 15), (7, 55), (8, 35), (10, 15), (12, 15),
        (12, 55), (14, 15), (15, 35), (16, 15), (17, 15), (19, 15), (21, 15),
        (22, 15),
      ]),
    ),
    saturdayOut: _DayDirectionRule.exact(
      _times([(6, 25), (7, 25), (8, 25), (9, 55), (11, 25), (12, 25), (13, 25), (14, 25)]),
    ),
    saturdayIn: _DayDirectionRule.exact(
      _times([(5, 50), (6, 50), (7, 50), (8, 50), (10, 20), (11, 50), (12, 50), (13, 50)]),
    ),
    sundayOut: const _DayDirectionRule.noService(),
    sundayIn: const _DayDirectionRule.noService(),
  ),

  // P14 Ledina — Sunday NO SERVICE
  'P14': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.exact(
      _times([
        (5, 50), (6, 50), (7, 50), (8, 50), (10, 20), (11, 50), (12, 50),
        (13, 50), (14, 50), (15, 50), (17, 20), (18, 50), (19, 50), (20, 50),
        (21, 50),
      ]),
    ),
    weekdayIn: _DayDirectionRule.exact(
      _times([
        (5, 20), (6, 20), (7, 20), (8, 20), (9, 50), (11, 20), (12, 20),
        (13, 20), (14, 20), (15, 20), (16, 50), (18, 20), (19, 20), (20, 20),
        (21, 20),
      ]),
    ),
    saturdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 50),
      lastMinute: _m(20, 30),
      peakMinutes: 80,
      offPeakMinutes: 80,
    ),
    saturdayIn: _DayDirectionRule.window(
      firstMinute: _m(6, 35),
      lastMinute: _m(19, 55),
      peakMinutes: 80,
      offPeakMinutes: 80,
    ),
    sundayOut: const _DayDirectionRule.noService(),
    sundayIn: const _DayDirectionRule.noService(),
  ),

  // P15 Bresternica
  'P15': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 20),
      lastMinute: _m(22, 20),
      peakMinutes: 35,
      offPeakMinutes: 40,
      eveningMinutes: 40,
    ),
    weekdayIn: _DayDirectionRule.window(
      firstMinute: _m(4, 55),
      lastMinute: _m(21, 50),
      peakMinutes: 35,
      offPeakMinutes: 40,
      eveningMinutes: 40,
    ),
    saturdayOut: _DayDirectionRule.window(
      firstMinute: _m(6, 25),
      lastMinute: _m(20, 25),
      peakMinutes: 90,
      offPeakMinutes: 90,
    ),
    saturdayIn: _DayDirectionRule.window(
      firstMinute: _m(6, 0),
      lastMinute: _m(21, 15),
      peakMinutes: 90,
      offPeakMinutes: 90,
    ),
    sundayOut: _DayDirectionRule.exact(
      _times([
        (6, 25), (7, 55), (9, 25), (11, 25), (12, 55), (14, 25),
        (16, 25), (18, 25), (20, 25),
      ]),
    ),
    sundayIn: _DayDirectionRule.exact(
      _times([
        (6, 0), (7, 15), (8, 45), (10, 15), (12, 15), (13, 45),
        (15, 15), (17, 15), (19, 15),
      ]),
    ),
  ),

  // P16 Brezje
  'P16': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 45),
      lastMinute: _m(22, 20),
      peakMinutes: 35,
      offPeakMinutes: 45,
      eveningMinutes: 50,
    ),
    weekdayIn: _DayDirectionRule.window(
      firstMinute: _m(5, 15),
      lastMinute: _m(21, 50),
      peakMinutes: 35,
      offPeakMinutes: 45,
      eveningMinutes: 50,
    ),
    saturdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 45),
      lastMinute: _m(21, 45),
      peakMinutes: 60,
      offPeakMinutes: 60,
    ),
    saturdayIn: _DayDirectionRule.window(
      firstMinute: _m(5, 20),
      lastMinute: _m(21, 15),
      peakMinutes: 60,
      offPeakMinutes: 60,
    ),
    sundayOut: _DayDirectionRule.window(
      firstMinute: _m(6, 45),
      lastMinute: _m(20, 45),
      peakMinutes: 60,
      offPeakMinutes: 60,
    ),
    sundayIn: _DayDirectionRule.window(
      firstMinute: _m(6, 15),
      lastMinute: _m(20, 15),
      peakMinutes: 60,
      offPeakMinutes: 60,
    ),
  ),

  // P17 Košaki — Sunday NO SERVICE
  'P17': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.exact(
      _times([
        (5, 0), (6, 0), (6, 30), (7, 0), (7, 30), (8, 0), (8, 30), (9, 0),
        (9, 30), (10, 0), (10, 30), (11, 0), (11, 30), (12, 0), (12, 30),
        (13, 0), (13, 30), (14, 0), (14, 30), (15, 0), (16, 0), (17, 30),
        (19, 0), (20, 30),
      ]),
    ),
    weekdayIn: _DayDirectionRule.exact(
      _times([
        (5, 30), (6, 0), (6, 30), (7, 0), (7, 30), (8, 0), (8, 30), (9, 0),
        (9, 30), (10, 0), (10, 30), (11, 0), (11, 30), (12, 0), (12, 30),
        (13, 0), (13, 30), (14, 0), (14, 30), (15, 0), (15, 30), (16, 30),
        (18, 0), (19, 30), (21, 0),
      ]),
    ),
    saturdayOut: _DayDirectionRule.exact(
      _times([
        (6, 0), (7, 0), (8, 0), (9, 0), (10, 30), (12, 0), (13, 0),
        (14, 0), (15, 0), (16, 0), (17, 30), (19, 0), (20, 30),
      ]),
    ),
    saturdayIn: _DayDirectionRule.exact(
      _times([
        (6, 30), (7, 30), (8, 30), (10, 0), (11, 0), (12, 30), (13, 30),
        (14, 30), (15, 30), (17, 0), (18, 0), (19, 30), (21, 10),
      ]),
    ),
    sundayOut: const _DayDirectionRule.noService(),
    sundayIn: const _DayDirectionRule.noService(),
  ),

  // P18 Pekre
  'P18': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 35),
      lastMinute: _m(22, 10),
      peakMinutes: 25,
      offPeakMinutes: 35,
      eveningMinutes: 35,
    ),
    weekdayIn: _DayDirectionRule.window(
      firstMinute: _m(5, 0),
      lastMinute: _m(21, 35),
      peakMinutes: 25,
      offPeakMinutes: 35,
      eveningMinutes: 35,
    ),
    saturdayOut: _DayDirectionRule.window(
      firstMinute: _m(6, 10),
      lastMinute: _m(21, 10),
      peakMinutes: 60,
      offPeakMinutes: 90,
      eveningMinutes: 90,
      eveningStartMinute: _m(15, 10),
    ),
    saturdayIn: _DayDirectionRule.window(
      firstMinute: _m(6, 30),
      lastMinute: _m(20, 30),
      peakMinutes: 60,
      offPeakMinutes: 90,
      eveningMinutes: 90,
      eveningStartMinute: _m(14, 30),
    ),
    sundayOut: _DayDirectionRule.exact(
      _times([
        (6, 10), (7, 10), (8, 10), (9, 10), (10, 10), (11, 10), (12, 10),
        (13, 10), (14, 10), (16, 10), (18, 10), (20, 10),
      ]),
    ),
    sundayIn: _DayDirectionRule.exact(
      _times([
        (6, 30), (7, 30), (8, 30), (9, 30), (10, 30), (11, 30), (12, 30),
        (13, 30), (14, 30), (15, 30), (17, 30), (19, 30), (21, 0),
      ]),
    ),
  ),

  // P19 Dom pod gorco — Sunday NO SERVICE
  'P19': _OfficialLineSchedule(
    weekdayOut: _DayDirectionRule.window(
      firstMinute: _m(5, 55),
      lastMinute: _m(21, 40),
      peakMinutes: 75,
      offPeakMinutes: 75,
      eveningMinutes: 90,
      eveningStartMinute: _m(17, 10),
    ),
    weekdayIn: _DayDirectionRule.window(
      firstMinute: _m(5, 20),
      lastMinute: _m(22, 10),
      peakMinutes: 75,
      offPeakMinutes: 75,
      eveningMinutes: 90,
      eveningStartMinute: _m(17, 40),
    ),
    saturdayOut: _DayDirectionRule.exact(
      _times([
        (5, 50), (7, 10), (8, 30), (10, 0), (11, 30), (12, 50),
        (14, 10), (15, 30), (17, 30), (19, 30),
      ]),
    ),
    saturdayIn: _DayDirectionRule.exact(
      _times([
        (6, 20), (7, 40), (9, 0), (10, 30), (12, 0), (13, 20),
        (14, 40), (16, 0), (18, 0), (20, 0),
      ]),
    ),
    sundayOut: const _DayDirectionRule.noService(),
    sundayIn: const _DayDirectionRule.noService(),
  ),
};

/// Determines the [DayScheduleType] for [date] including fixed Slovenian holidays.
DayScheduleType scheduleTypeForDate(DateTime date) {
  const fixedHolidays = {
    (1, 1), (1, 2), (2, 8), (4, 27), (5, 1), (5, 2),
    (6, 25), (8, 15), (10, 31), (11, 1), (12, 25), (12, 26),
  };
  if (fixedHolidays.contains((date.month, date.day)) ||
      date.weekday == DateTime.sunday) {
    return DayScheduleType.sundayHoliday;
  }
  if (date.weekday == DateTime.saturday) {
    return DayScheduleType.saturday;
  }
  return DayScheduleType.weekday;
}

/// Returns whether [lineId] operates on [type] (`G5, P9, P13, P14, P17, P19` do not run on Sundays/Holidays).
bool doesLineOperateOn(String lineId, DayScheduleType type) {
  final line = seedLinesById[lineId];
  final canonicalId = line?.id ?? lineId;
  final spec = _officialSchedules[canonicalId];
  if (spec == null) return true;
  return spec.ruleFor(type, isInbound: false).operates;
}

/// Returns a [LineOperatingSummary] with first/last departure times for [line] on [date].
LineOperatingSummary describeLineSchedule({
  required BusLine line,
  int directionIndex = 0,
  required DateTime date,
  DayScheduleType? scheduleType,
}) {
  final dir = line.directions[directionIndex.clamp(0, line.directions.length - 1)];
  final trips = generateTripsForDirection(
    line: line,
    direction: dir,
    date: date,
    scheduleType: scheduleType,
  );
  if (trips.isEmpty) {
    return const LineOperatingSummary(operates: false, tripCount: 0);
  }
  String fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  return LineOperatingSummary(
    operates: true,
    tripCount: trips.length,
    firstDeparture: fmt(trips.first.startTime),
    lastDeparture: fmt(trips.last.startTime),
  );
}

/// Returns a human-readable service window label (e.g. `"05:00 – 23:00 (59 odhodov)"` or `"Ne obratuje"`).
String formatLineOperatingHours(
  String lineId, {
  int directionIndex = 0,
  required DayScheduleType type,
}) {
  final line = seedLinesById[lineId];
  if (line == null) return '—';
  final weekdayAnchor = switch (type) {
    DayScheduleType.weekday => DateTime.monday,
    DayScheduleType.saturday => DateTime.saturday,
    DayScheduleType.sundayHoliday => DateTime.sunday,
  };
  final summary = describeLineSchedule(
    line: line,
    directionIndex: directionIndex,
    date: sampleDateForWeekday(weekdayAnchor),
    scheduleType: type,
  );
  if (!summary.operates) {
    return 'Ne obratuje';
  }
  return '${summary.firstDeparture} – ${summary.lastDeparture} (${summary.tripCount})';
}

/// Returns a concrete non-holiday reference date matching [weekday] (`1..7`)
/// relative to [anchor] so schedules can be viewed for every day of the week.
DateTime sampleDateForWeekday(int weekday, {DateTime? anchor}) {
  final base = anchor ?? DateTime(2026, 11, 23); // Non-holiday Monday
  final clamped = weekday.clamp(DateTime.monday, DateTime.sunday);
  final monday = base.subtract(Duration(days: base.weekday - DateTime.monday));
  return DateTime(monday.year, monday.month, monday.day)
      .add(Duration(days: clamped - DateTime.monday));
}

/// Computes cumulative travel durations in seconds from the first stop of [direction].
List<int> computeStopOffsetsSeconds(LineDirection direction) {
  final offsets = <int>[0];
  var cumulative = 0;
  // Assume ~24 km/h average urban bus speed (6.67 m/s) plus 25s stop dwell.
  const metersPerSecond = 6.67;
  const dwellSeconds = 25;
  for (var i = 0; i < direction.stopIds.length - 1; i++) {
    final fromPos = seedStopsById[direction.stopIds[i]]?.position;
    final toPos = seedStopsById[direction.stopIds[i + 1]]?.position;
    final meters = (fromPos != null && toPos != null)
        ? GeoUtils.haversineMeters(fromPos, toPos)
        : 550.0;
    final segmentSeconds = (meters / metersPerSecond).round() + dwellSeconds;
    cumulative += segmentSeconds < 60 ? 60 : segmentSeconds;
    offsets.add(cumulative);
  }
  return offsets;
}

/// Generates all official scheduled trips for [line] and [direction] on [date].
List<ScheduledTrip> generateTripsForDirection({
  required BusLine line,
  required LineDirection direction,
  required DateTime date,
  DayScheduleType? scheduleType,
}) {
  final type = scheduleType ?? scheduleTypeForDate(date);
  final spec = _officialSchedules[line.id];
  final isInbound = direction.id.endsWith('_in');
  final rule = spec?.ruleFor(type, isInbound: isInbound) ??
      _DayDirectionRule.window(
        firstMinute: _m(5, isInbound ? 15 : 0),
        lastMinute: _m(22, 0),
        peakMinutes: 25,
        offPeakMinutes: 40,
      );

  if (!rule.operates) {
    return const <ScheduledTrip>[];
  }

  final departureMinutes = rule.resolveMinutes();
  if (departureMinutes.isEmpty) {
    return const <ScheduledTrip>[];
  }

  final offsets = computeStopOffsetsSeconds(direction);
  final dayStart = DateTime(date.year, date.month, date.day);
  final dateTag =
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  final trips = <ScheduledTrip>[];
  for (final minuteOfDay in departureMinutes) {
    final departure = dayStart.add(Duration(minutes: minuteOfDay));
    final hhmm =
        '${departure.hour.toString().padLeft(2, '0')}${departure.minute.toString().padLeft(2, '0')}';
    trips.add(
      ScheduledTrip(
        tripId: '${direction.id}_${dateTag}_$hhmm',
        lineId: line.id,
        lineCode: line.code,
        directionId: direction.id,
        directionName: direction.name,
        stopIds: direction.stopIds,
        stopTimes: [
          for (final offset in offsets)
            departure.add(Duration(seconds: offset)),
        ],
      ),
    );
  }
  return trips;
}

/// Returns all scheduled departures at [stopId] on [date], sorted chronologically.
List<ScheduledStopEvent> generateStopScheduleForDate({
  required String stopId,
  required DateTime date,
  DayScheduleType? scheduleType,
}) {
  final type = scheduleType ?? scheduleTypeForDate(date);
  final events = <ScheduledStopEvent>[];
  for (final line in seedLines) {
    for (final direction in line.directions) {
      final stopIdx = direction.stopIds.indexOf(stopId);
      if (stopIdx == -1) continue;
      final trips = generateTripsForDirection(
        line: line,
        direction: direction,
        date: date,
        scheduleType: type,
      );
      for (final trip in trips) {
        events.add(
          ScheduledStopEvent(
            trip: trip,
            stopId: stopId,
            stopIndex: stopIdx,
            scheduledTime: trip.stopTimes[stopIdx],
          ),
        );
      }
    }
  }
  events.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  return events;
}
