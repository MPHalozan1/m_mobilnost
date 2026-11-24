// Unit and widget tests for RoutePlanner, TripPlannerScreen, and NearestStopScreen.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/app/app.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/network/connectivity_provider.dart';
import 'package:m_mobilnost/core/network/data_freshness.dart';
import 'package:m_mobilnost/core/network/map_tile_provider.dart';
import 'package:m_mobilnost/core/widgets/big_button.dart';
import 'package:m_mobilnost/core/widgets/occupancy_strip.dart';
import 'package:m_mobilnost/data/mock/mock_line_repository.dart';
import 'package:m_mobilnost/data/mock/mock_timetable_repository.dart';
import 'package:m_mobilnost/data/models/bus_line.dart';
import 'package:m_mobilnost/data/models/bus_stop.dart';
import 'package:m_mobilnost/data/models/departure.dart';
import 'package:m_mobilnost/data/models/place.dart';
import 'package:m_mobilnost/data/models/trip_plan.dart';
import 'package:m_mobilnost/data/repositories/line_repository.dart';
import 'package:m_mobilnost/data/repositories/timetable_repository.dart';
import 'package:m_mobilnost/data/seed/seed_places.dart';
import 'package:m_mobilnost/data/seed/seed_stops.dart';
import 'package:m_mobilnost/data/seed/seed_timetables.dart';
import 'package:m_mobilnost/features/nearest_stop/presentation/nearest_stop_screen.dart';
import 'package:m_mobilnost/features/trip_planner/domain/route_planner.dart';
import 'package:m_mobilnost/features/trip_planner/presentation/trip_planner_screen.dart';
import 'package:m_mobilnost/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryTestTileProvider extends TileProvider {
  static final Uint8List _transparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_transparentPng);
  }
}

/// Deterministic stub line repository for controlled tight-transfer and
/// earliest-arrival-vs-distance tests.
class _StubLineRepository implements LineRepository {
  _StubLineRepository({
    required this.stops,
    required this.lines,
  });

  final List<BusStop> stops;
  final List<BusLine> lines;
  final List<Place> places = const [];

  @override
  Future<List<BusLine>> getLines() async => lines;

  @override
  Future<BusLine?> getLineById(String lineId) async =>
      lines.where((l) => l.id == lineId).firstOrNull;

  @override
  Future<List<BusStop>> getStops() async => stops;

  @override
  Future<BusStop?> getStopById(String stopId) async =>
      stops.where((s) => s.id == stopId).firstOrNull;

  @override
  Future<List<BusStop>> searchStops(String query) async => stops;

  @override
  Future<List<BusStop>> getNearbyStops(
    LatLng position, {
    double maxDistanceMeters = 1500,
    int limit = 10,
  }) async =>
      stops.take(limit).toList();

  @override
  Future<List<Place>> getPlaces() async => places;

  @override
  Future<List<Place>> searchPlaces(String query) async => places;
}

/// Stub timetable allowing explicit control of simulated delays and headways.
class _StubTimetableRepository implements TimetableRepository {
  _StubTimetableRepository(this.departuresBuilder);

  final List<Departure> Function({
    required String lineId,
    required String directionId,
    required String stopId,
    required DateTime at,
    required bool useSimulatedLive,
  }) departuresBuilder;

  @override
  Future<void> clearCache() async {}

  @override
  Future<List<Departure>> getDeparturesForLine(
    String lineId,
    String directionId, {
    required DateTime at,
    DayScheduleType? scheduleType,
    String? stopId,
    bool? useSimulatedLive,
    bool isOffline = false,
  }) async {
    return departuresBuilder(
      lineId: lineId,
      directionId: directionId,
      stopId: stopId ?? '',
      at: at,
      useSimulatedLive: (useSimulatedLive ?? true) && !isOffline,
    );
  }

  @override
  Future<List<Departure>> getDeparturesForStop(
    String stopId, {
    required DateTime at,
    int limit = 20,
    bool? useSimulatedLive,
    bool isOffline = false,
  }) async =>
      const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoutePlanner domain (Maribor seed network)', () {
    late MockLineRepository lineRepo;
    late MockTimetableRepository timetableRepo;
    late RoutePlanner planner;
    final morning = DateTime(2026, 11, 23, 8, 5); // Monday morning peak.

    setUp(() {
      lineRepo = const MockLineRepository();
      timetableRepo = MockTimetableRepository();
      planner = RoutePlanner(
        lineRepository: lineRepo,
        timetableRepository: timetableRepo,
        clock: () => morning,
      );
    });

    test('plans direct trips with walk/bus legs and structured instructions', () async {
      final options = await planner.planTrip(
        origin: seedStopsById['glavni_trg']!.position,
        destination: seedStopsById['ukc_maribor']!.position,
        originLabel: 'Glavni trg',
        destinationLabel: 'UKC Maribor',
        mode: TripTimeMode.departAt,
        targetTime: morning,
      );

      expect(options, isNotEmpty);
      expect(options.length, lessThanOrEqualTo(3));

      final first = options.first;
      expect(first.transferCount, 0);
      expect(first.hasTightTransfer, isFalse);
      expect(first.legs.any((l) => l.type == TripLegType.bus), isTrue);
      expect(first.departureTime.isBefore(morning), isFalse);

      final steps = planner.buildInstructions(
        first,
        destinationLabel: 'UKC Maribor',
      );
      expect(steps.any((s) => s.type == TripStepType.boardBus), isTrue);
      expect(steps.any((s) => s.type == TripStepType.rideStops), isTrue);
      expect(steps.any((s) => s.type == TripStepType.getOff), isTrue);
      expect(steps.last.type, TripStepType.arrived);
    });

    test('plans 1-transfer trips through Maribor hubs and honors fewerTransfers', () async {
      final options = await planner.planTrip(
        origin: seedStopsById['pekre']!.position,
        destination: seedStopsById['pobrezje']!.position,
        mode: TripTimeMode.leaveNow,
        targetTime: morning,
        fewerTransfers: true,
      );

      expect(options, isNotEmpty);
      expect(options.length, lessThanOrEqualTo(3));
      expect(options.every((o) => o.transferCount == 1), isTrue);

      final first = options.first;
      final busLegs =
          first.legs.where((l) => l.type == TripLegType.bus).toList();
      expect(busLegs.length, 2);
      expect(busLegs.first.toStopId, isNotNull);

      final steps = planner.buildInstructions(first);
      expect(steps.any((s) => s.type == TripStepType.transferAt), isTrue);
    });

    test('supports departAt and arriveBy timing constraints accurately', () async {
      final departAtTime = DateTime(2026, 11, 23, 14, 15);
      final departOptions = await planner.planTrip(
        origin: seedStopsById['univerza']!.position,
        destination: seedStopsById['tabor']!.position,
        mode: TripTimeMode.departAt,
        targetTime: departAtTime,
      );
      expect(departOptions, isNotEmpty);
      for (final opt in departOptions) {
        expect(opt.departureTime.isBefore(departAtTime), isFalse);
      }

      final arriveDeadline = DateTime(2026, 11, 23, 9, 0);
      final arriveOptions = await planner.planTrip(
        origin: seedStopsById['pekre']!.position,
        destination: seedStopsById['pobrezje']!.position,
        mode: TripTimeMode.arriveBy,
        targetTime: arriveDeadline,
      );
      expect(arriveOptions, isNotEmpty);
      for (final opt in arriveOptions) {
        expect(
          opt.arrivalTime.isAfter(arriveDeadline),
          isFalse,
          reason: 'Arrival ${opt.arrivalTime} exceeded deadline $arriveDeadline',
        );
      }
      // Ranked by latest viable departure first in arriveBy mode.
      for (var i = 0; i < arriveOptions.length - 1; i++) {
        expect(
          arriveOptions[i].departureTime
              .isBefore(arriveOptions[i + 1].departureTime),
          isFalse,
        );
      }
    });

    test('filters out non-step-free stops and non-low-floor lines when accessibleOnly is true', () async {
      // Turnerjeva -> Pekre has direct Line P18 (isLowFloorDefault: false).
      final standard = await planner.planTrip(
        origin: seedStopsById['turnerjeva']!.position,
        destination: seedStopsById['pekre']!.position,
        mode: TripTimeMode.departAt,
        targetTime: DateTime(2026, 11, 23, 8, 15),
        accessibleOnly: false,
        fewerTransfers: true,
        maxWalkMeters: 350,
        maxResults: 6,
      );
      expect(
        standard.any(
          (opt) => opt.legs.any((l) => l.lineId == 'P18'),
        ),
        isTrue,
      );

      final accessible = await planner.planTrip(
        origin: seedStopsById['turnerjeva']!.position,
        destination: seedStopsById['pekre']!.position,
        mode: TripTimeMode.departAt,
        targetTime: DateTime(2026, 11, 23, 8, 15),
        accessibleOnly: true,
        fewerTransfers: true,
        maxWalkMeters: 350,
        maxResults: 6,
      );
      expect(accessible, isNotEmpty);
      for (final opt in accessible) {
        expect(opt.isAccessible, isTrue);
        expect(opt.legs.any((l) => l.lineId == 'P18'), isFalse);
      }
    });

    test('respects maxWalkMeters and returns empty when stops are outside radius', () async {
      // Rospoh is not step-free; nearest step-free stop (Kamnica) is ~1.3 km away.
      final tooClose = await planner.planTrip(
        origin: seedStopsById['rospoh']!.position,
        destination: seedStopsById['glavni_trg']!.position,
        mode: TripTimeMode.departAt,
        targetTime: morning,
        accessibleOnly: true,
        maxWalkMeters: 850,
      );
      expect(tooClose, isEmpty);

      // Expanding walk radius reaches Kamnica and succeeds.
      final widerWalk = await planner.planTrip(
        origin: seedStopsById['rospoh']!.position,
        destination: seedStopsById['glavni_trg']!.position,
        mode: TripTimeMode.departAt,
        targetTime: morning,
        accessibleOnly: true,
        maxWalkMeters: 1800,
      );
      expect(widerWalk, isNotEmpty);
      expect(widerWalk.first.isAccessible, isTrue);
    });

    test('falls back to static cached timetable when useSimulatedLive is false', () async {
      final staticOptions = await planner.planTrip(
        origin: seedStopsById['glavni_trg']!.position,
        destination: seedStopsById['ukc_maribor']!.position,
        mode: TripTimeMode.departAt,
        targetTime: morning,
        useSimulatedLive: false,
      );
      expect(staticOptions, isNotEmpty);
      expect(staticOptions.first.freshness.kind, DataSourceKind.cached);
      for (final leg in staticOptions.first.legs) {
        expect(leg.delaySeconds, 0);
      }
    });
  });

  group('RoutePlanner deterministic tight-transfer & nearest-stop ranking', () {
    test('flags tight transfer <= 4 min under simulated delay and offers safer alternative', () async {
      const stopO = BusStop(
        id: 'stop_o',
        name: 'Origin Stop',
        position: LatLng(46.5500, 15.6300),
        lineIds: ['A'],
        isStepFree: true,
      );
      const stopH = BusStop(
        id: 'stop_h',
        name: 'Hub Stop',
        position: LatLng(46.5550, 15.6450),
        lineIds: ['A', 'B'],
        isStepFree: true,
      );
      const stopD = BusStop(
        id: 'stop_d',
        name: 'Dest Stop',
        position: LatLng(46.5600, 15.6600),
        lineIds: ['B'],
        isStepFree: true,
      );

      final lineA = BusLine(
        id: 'A',
        code: 'A',
        name: 'Line A',
        color: const Color(0xFF004B87),
        directions: const [
          LineDirection(
            id: 'A_out',
            name: 'Origin - Hub',
            terminalStopId: 'stop_h',
            stopIds: ['stop_o', 'stop_h'],
            polyline: [
              LatLng(46.5500, 15.6300),
              LatLng(46.5550, 15.6450),
            ],
          ),
        ],
      );
      final lineB = BusLine(
        id: 'B',
        code: 'B',
        name: 'Line B',
        color: const Color(0xFF0B6E4F),
        directions: const [
          LineDirection(
            id: 'B_out',
            name: 'Hub - Dest',
            terminalStopId: 'stop_d',
            stopIds: ['stop_h', 'stop_d'],
            polyline: [
              LatLng(46.5550, 15.6450),
              LatLng(46.5600, 15.6600),
            ],
          ),
        ],
      );

      final base = DateTime(2026, 11, 23, 8, 0);
      final timetable = _StubTimetableRepository(({
        required lineId,
        required directionId,
        required stopId,
        required at,
        required useSimulatedLive,
      }) {
        final freshness = DataFreshness(
          kind: useSimulatedLive
              ? DataSourceKind.simulated
              : DataSourceKind.cached,
          updatedAt: base,
        );
        if (lineId == 'A') {
          // Scheduled: 08:00 -> 08:10. Under simulated live: +4 min delay at hub (arrives 08:14).
          final sched = stopId == 'stop_o'
              ? base
              : base.add(const Duration(minutes: 10));
          final delay = (useSimulatedLive && stopId == 'stop_h') ? 240 : 0;
          return [
            Departure(
              id: 'tripA1_${stopId}_${stopId == 'stop_o' ? 0 : 1}',
              lineId: 'A',
              lineCode: 'A',
              directionId: 'A_out',
              directionName: 'Origin - Hub',
              stopId: stopId,
              scheduledTime: sched,
              delaySeconds: delay,
              occupancy: BusOccupancyLevel.low,
              freshness: freshness,
            ),
          ];
        }
        // Line B departures at 08:16 (2 min buffer when A delayed, 6 min if on time)
        // and safer departure at 08:28 (14 min buffer).
        final b1Sched = stopId == 'stop_h'
            ? base.add(const Duration(minutes: 16))
            : base.add(const Duration(minutes: 26));
        final b2Sched = stopId == 'stop_h'
            ? base.add(const Duration(minutes: 28))
            : base.add(const Duration(minutes: 38));
        final idx = stopId == 'stop_h' ? 0 : 1;
        return [
          Departure(
            id: 'tripB1_${stopId}_$idx',
            lineId: 'B',
            lineCode: 'B',
            directionId: 'B_out',
            directionName: 'Hub - Dest',
            stopId: stopId,
            scheduledTime: b1Sched,
            delaySeconds: 0,
            occupancy: BusOccupancyLevel.medium,
            freshness: freshness,
          ),
          Departure(
            id: 'tripB2_${stopId}_$idx',
            lineId: 'B',
            lineCode: 'B',
            directionId: 'B_out',
            directionName: 'Hub - Dest',
            stopId: stopId,
            scheduledTime: b2Sched,
            delaySeconds: 0,
            occupancy: BusOccupancyLevel.low,
            freshness: freshness,
          ),
        ];
      });

      final planner = RoutePlanner(
        lineRepository: _StubLineRepository(
          stops: const [stopO, stopH, stopD],
          lines: [lineA, lineB],
        ),
        timetableRepository: timetable,
        clock: () => base,
      );

      // With simulated delay (+4 min -> 2 min transfer buffer), tight warning + safer option appear.
      final liveResults = await planner.planTrip(
        origin: stopO.position,
        destination: stopD.position,
        mode: TripTimeMode.departAt,
        targetTime: base,
        useSimulatedLive: true,
      );

      expect(liveResults.length, 2);
      expect(liveResults.first.hasTightTransfer, isTrue);
      expect(liveResults.first.tightTransferMinutes, 2);
      expect(liveResults[1].hasTightTransfer, isFalse);

      final tightSteps = planner.buildInstructions(liveResults.first);
      expect(
        tightSteps.any(
          (s) => s.type == TripStepType.transferAt && s.isTightTransfer,
        ),
        isTrue,
      );

      // Without simulated delay, scheduled buffer is 6 min -> NOT tight.
      final staticResults = await planner.planTrip(
        origin: stopO.position,
        destination: stopD.position,
        mode: TripTimeMode.departAt,
        targetTime: base,
        useSimulatedLive: false,
      );
      expect(staticResults, isNotEmpty);
      expect(staticResults.first.hasTightTransfer, isFalse);
      expect(staticResults.first.freshness.kind, DataSourceKind.cached);
    });

    test('findNearestStopsToDestination sorts by total arrival time rather than walking distance', () async {
      // User stands 90m from closeStop and 360m from fastStop.
      const userPos = LatLng(46.5550, 15.6450);
      const closeStop = BusStop(
        id: 'close_stop',
        name: 'Close Slow Stop',
        position: LatLng(46.5558, 15.6450), // ~89m north
        lineIds: ['S'],
        isStepFree: true,
      );
      const fastStop = BusStop(
        id: 'fast_stop',
        name: 'Further Fast Stop',
        position: LatLng(46.5518, 15.6450), // ~355m south
        lineIds: ['F'],
        isStepFree: true,
      );
      const destStop = BusStop(
        id: 'dest_stop',
        name: 'Destination Stop',
        position: LatLng(46.5650, 15.6600),
        lineIds: ['S', 'F'],
        isStepFree: true,
      );

      final slowLine = BusLine(
        id: 'S',
        code: 'S',
        name: 'Slow Line',
        color: const Color(0xFFB45309),
        directions: const [
          LineDirection(
            id: 'S_out',
            name: 'Close - Dest',
            terminalStopId: 'dest_stop',
            stopIds: ['close_stop', 'dest_stop'],
            polyline: [
              LatLng(46.5558, 15.6450),
              LatLng(46.5650, 15.6600),
            ],
          ),
        ],
      );
      final fastLine = BusLine(
        id: 'F',
        code: 'F',
        name: 'Fast Line',
        color: const Color(0xFF004B87),
        directions: const [
          LineDirection(
            id: 'F_out',
            name: 'Fast - Dest',
            terminalStopId: 'dest_stop',
            stopIds: ['fast_stop', 'dest_stop'],
            polyline: [
              LatLng(46.5518, 15.6450),
              LatLng(46.5650, 15.6600),
            ],
          ),
        ],
      );

      final base = DateTime(2026, 11, 23, 9, 0);
      final timetable = _StubTimetableRepository(({
        required lineId,
        required directionId,
        required stopId,
        required at,
        required useSimulatedLive,
      }) {
        final freshness = DataFreshness(
          kind: DataSourceKind.simulated,
          updatedAt: base,
        );
        if (lineId == 'S') {
          // Slow line departs in 30 min (09:30 -> arrives 09:45).
          final dep = stopId == 'close_stop'
              ? base.add(const Duration(minutes: 30))
              : base.add(const Duration(minutes: 45));
          return [
            Departure(
              id: 's1_${stopId}_${stopId == 'close_stop' ? 0 : 1}',
              lineId: 'S',
              lineCode: 'S',
              directionId: 'S_out',
              directionName: 'Close - Dest',
              stopId: stopId,
              scheduledTime: dep,
              delaySeconds: 0,
              occupancy: BusOccupancyLevel.low,
              freshness: freshness,
            ),
          ];
        }
        // Fast line departs in 7 min (09:07 -> arrives 09:17).
        final dep = stopId == 'fast_stop'
            ? base.add(const Duration(minutes: 7))
            : base.add(const Duration(minutes: 17));
        return [
          Departure(
            id: 'f1_${stopId}_${stopId == 'fast_stop' ? 0 : 1}',
            lineId: 'F',
            lineCode: 'F',
            directionId: 'F_out',
            directionName: 'Fast - Dest',
            stopId: stopId,
            scheduledTime: dep,
            delaySeconds: 0,
            occupancy: BusOccupancyLevel.low,
            freshness: freshness,
          ),
        ];
      });

      final planner = RoutePlanner(
        lineRepository: _StubLineRepository(
          stops: const [closeStop, fastStop, destStop],
          lines: [slowLine, fastLine],
        ),
        timetableRepository: timetable,
        clock: () => base,
      );

      final ranked = await planner.findNearestStopsToDestination(
        origin: userPos,
        destination: destStop.position,
        at: base,
        maxWalkMeters: 1000,
      );

      expect(ranked.length, 2);
      expect(ranked.first.stop.id, 'fast_stop');
      expect(ranked.last.stop.id, 'close_stop');
      expect(
        ranked.first.walkMeters,
        greaterThan(ranked.last.walkMeters),
      );
      expect(
        ranked.first.estimatedArrivalTime
            .isBefore(ranked.last.estimatedArrivalTime),
        isTrue,
      );
    });
  });

  group('TripPlannerScreen & NearestStopScreen widgets', () {
    testWidgets('TripPlannerScreen swaps, searches, toggles map/list, and handles empty fallback',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isOfflineProvider.overrideWithValue(false),
          mapTileProviderProvider.overrideWithValue(_MemoryTestTileProvider()),
          routePlannerProvider.overrideWithValue(
            RoutePlanner(
              lineRepository: const MockLineRepository(),
              timetableRepository: MockTimetableRepository(),
              clock: () => DateTime(2026, 11, 23, 8, 5),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(a11ySettingsProvider.notifier).setLocaleCode('en');

      // Test at expanded width (>1024px) for 2-pane split and 200% text scale.
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: MMobilnostApp.appSupportedLocales,
            locale: const Locale('en'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0),
              ),
              child: child!,
            ),
            home: const TripPlannerScreen(
              initialFromStopId: 'glavni_trg',
              initialToStopId: 'ukc_maribor',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify swap button >= 56dp and prefilled stops + auto-searched results.
      final swapBtn = find.byIcon(Icons.swap_vert_rounded);
      final swapBox = tester.getSize(
        find.ancestor(of: swapBtn, matching: find.byType(IconButton)),
      );
      expect(swapBox.width, greaterThanOrEqualTo(56));
      expect(swapBox.height, greaterThanOrEqualTo(56));

      expect(find.text('What do I do next?'), findsOneWidget);
      expect(find.text('Read aloud'), findsOneWidget);

      // Toggle Map preview -> List view cleanly.
      final listBtn = find.widgetWithText(BigButton, 'List');
      expect(listBtn, findsOneWidget);
      await tester.tap(listBtn);
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsNothing);

      // Swap endpoints and verify destination updated.
      await tester.tap(swapBtn);
      await tester.pumpAndSettle();
      expect(find.text('UKC Maribor'), findsWidgets);

      // Verify compact width (390px) at 200% text scale + empty state fallback.
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: MMobilnostApp.appSupportedLocales,
            locale: const Locale('en'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0),
              ),
              child: child!,
            ),
            home: const TripPlannerScreen(
              key: ValueKey('rospoh_empty_test'),
              initialFromStopId: 'rospoh',
              initialToStopId: 'glavni_trg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle accessibleOnly on -> Rospoh is non-step-free -> empty state renders.
      final accessibleSwitch = find.text('Step-free accessible routes only');
      await tester.ensureVisible(accessibleSwitch);
      await tester.pumpAndSettle();
      await tester.tap(accessibleSwitch);
      await tester.pumpAndSettle();
      expect(find.text('No route found'), findsOneWidget);
      expect(find.textContaining('Search with longer walk'), findsOneWidget);
      expect(find.text('Check later departures'), findsOneWidget);

      // Tapping "Search with longer walk" expands walk radius to Kamnica and finds routes.
      final longerWalkBtn = find.textContaining('Search with longer walk');
      await tester.ensureVisible(longerWalkBtn);
      await tester.pumpAndSettle();
      await tester.tap(longerWalkBtn);
      await tester.pumpAndSettle();
      expect(find.text('No route found'), findsNothing);
      expect(find.text('What do I do next?'), findsOneWidget);
    });

    testWidgets('NearestStopScreen renders earliest-arrival results and actions',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isOfflineProvider.overrideWithValue(false),
          routePlannerProvider.overrideWithValue(
            RoutePlanner(
              lineRepository: const MockLineRepository(),
              timetableRepository: MockTimetableRepository(),
              clock: () => DateTime(2026, 11, 23, 8, 5),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(a11ySettingsProvider.notifier).setLocaleCode('en');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: MMobilnostApp.appSupportedLocales,
            locale: const Locale('en'),
            home: NearestStopScreen(
              initialToName: seedPlaces[3].name, // UKC Maribor
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Find the nearest stop with a bus to your destination'),
        findsOneWidget,
      );
      expect(find.text('Sorted by earliest arrival time'), findsOneWidget);
      expect(find.textContaining('Arrives '), findsWidgets);
      expect(find.text('Plan trip'), findsWidgets);
      expect(find.text('View stop departures'), findsWidgets);

      // All BigButtons are >= 56dp tall.
      for (final element in find.byType(BigButton).evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.height, greaterThanOrEqualTo(56));
      }
    });
  });
}
