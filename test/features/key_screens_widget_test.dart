// Responsive web breakpoint tests (Compact 390, Medium 768, Expanded 1280), touch targets, map list parity, simulated badge, and reduced motion.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/app/app.dart';
import 'package:m_mobilnost/app/router.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/maps/google_map_3d_widget.dart';
import 'package:m_mobilnost/core/network/connectivity_provider.dart';
import 'package:m_mobilnost/core/widgets/big_button.dart';
import 'package:m_mobilnost/core/widgets/occupancy_strip.dart';
import 'package:m_mobilnost/core/widgets/simulated_data_badge.dart';
import 'package:m_mobilnost/data/mock/mock_auth_repository.dart';
import 'package:m_mobilnost/data/mock/mock_line_repository.dart';
import 'package:m_mobilnost/data/mock/mock_notice_repository.dart';
import 'package:m_mobilnost/data/mock/mock_ticket_repository.dart';
import 'package:m_mobilnost/data/mock/mock_timetable_repository.dart';
import 'package:m_mobilnost/data/models/bus_position.dart';
import 'package:m_mobilnost/data/repositories/repository_providers.dart';
import 'package:m_mobilnost/data/seed/seed_tickets.dart';
import 'package:m_mobilnost/features/map/data/location_service.dart';
import 'package:m_mobilnost/features/trip_planner/domain/route_planner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _buildAppContainer({
  bool useSimulatedLive = true,
  bool reducedMotion = false,
  bool signInDemoUser = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'a11y_onboarding_done': true,
    'a11y_locale_code': 'en',
    'a11y_location_manual': true,
    'a11y_use_simulated_live': useSimulatedLive,
    'a11y_reduced_motion': reducedMotion,
    'a11y_haptic_alerts': false,
  });
  final prefs = await SharedPreferences.getInstance();

  final suffix = DateTime.now().microsecondsSinceEpoch;
  final ticketRepo = MockTicketRepository(boxName: 'key_tkt_$suffix');
  final noticeRepo = MockNoticeRepository(boxName: 'key_ntc_$suffix');
  final now = DateTime(2026, 11, 23, 8, 5);
  final sampleBus = BusPosition(
    vehicleId: 'MB-G6-KEY',
    lineId: 'G6',
    lineCode: 'G6',
    directionId: 'G6_out',
    directionName: 'Vzpenjača – AP Maribor – Melje',
    position: const LatLng(46.5457, 15.6448),
    progress: 0.45,
    speedKmh: 24.0,
    nextStopId: 'tabor',
    nextStopName: 'Tabor',
    remainingStopsCount: 5,
    etaToNextStopSeconds: 120,
    delaySeconds: 0,
    occupancy: BusOccupancyLevel.medium,
    updatedAt: now,
  );

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      isOfflineProvider.overrideWithValue(false),
      ticketRepositoryProvider.overrideWithValue(ticketRepo),
      noticeRepositoryProvider.overrideWithValue(noticeRepo),
      locationServiceProvider.overrideWithValue(
        LocationService(gpsProbe: () async => null),
      ),
      liveBusesStreamProvider.overrideWith(
        (ref) => Stream.value([sampleBus]),
      ),
      routePlannerProvider.overrideWithValue(
        RoutePlanner(
          lineRepository: const MockLineRepository(),
          timetableRepository: MockTimetableRepository(),
          clock: () => now,
        ),
      ),
    ],
  );

  if (signInDemoUser) {
    final user = await container.read(authRepositoryProvider).signIn(
          email: MockAuthRepository.demoEmail,
          password: MockAuthRepository.demoPassword,
        );
    await ticketRepo.purchaseTicket(
      type: seedTicketTypes.first,
      userId: user.id,
    );
  }

  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 9: Responsive Web Breakpoints & Key Screen Parity', () {
    testWidgets(
        'Compact (390x844), Medium (768x1024), and Expanded (1280x900) switch NavigationBar and NavigationRail',
        (tester) async {
      final container = await _buildAppContainer(signInDemoUser: true);
      addTearDown(container.dispose);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.devicePixelRatio = 1.0;

      // 1. Compact (< 600px): bottom NavigationBar, no NavigationRail.
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MMobilnostApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(tester.takeException(), isNull);

      // Verify >= 56x56 dp touch targets on BigButtons on HomeScreen.
      final bigButtons = find.byType(BigButton);
      expect(bigButtons, findsWidgets);
      for (final element in bigButtons.evaluate()) {
        final box = element.renderObject as RenderBox;
        expect(box.size.width, greaterThanOrEqualTo(56));
        expect(box.size.height, greaterThanOrEqualTo(56));
      }

      // 2. Medium (600..1024px): compact NavigationRail (extended == false).
      tester.view.physicalSize = const Size(768, 1024);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      final mediumRail =
          tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(mediumRail.extended, isFalse);
      expect(tester.takeException(), isNull);

      // 3. Expanded (> 1024px): extended NavigationRail (extended == true) + 2-pane splits.
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      final expandedRail =
          tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(expandedRail.extended, isTrue);

      // Navigate to Tickets on Expanded (1280x900) and verify 2-pane detail shows QrImageView inline.
      final router = container.read(routerProvider);
      router.go('/tickets');
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Map List-View toggle parity works on MapScreen and TripPlannerScreen',
        (tester) async {
      final container = await _buildAppContainer();
      addTearDown(container.dispose);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MMobilnostApp(),
        ),
      );
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);

      // Navigate to /map -> verify GoogleMap3DWidget is visible, then toggle List view.
      router.go('/map');
      await tester.pumpAndSettle();
      expect(find.byType(GoogleMap3DWidget), findsOneWidget);

      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      expect(find.byType(GoogleMap3DWidget), findsNothing);

      // Navigate to /plan with endpoints -> verify GoogleMap3DWidget preview toggles to List view.
      router.go('/plan?fromStopId=glavni_trg&toStopId=ukc_maribor');
      await tester.pumpAndSettle();
      expect(find.byType(GoogleMap3DWidget), findsOneWidget);

      final listBtn = find.widgetWithText(BigButton, 'List');
      await tester.ensureVisible(listBtn);
      await tester.pumpAndSettle();
      await tester.tap(listBtn);
      await tester.pumpAndSettle();
      expect(find.byType(GoogleMap3DWidget), findsNothing);
    });

    testWidgets(
        'SimulatedDataBadge displays cached fallback when useSimulatedLive is false and Reduced Motion disables animations',
        (tester) async {
      final container = await _buildAppContainer(
        useSimulatedLive: false,
        reducedMotion: true,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MMobilnostApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimulatedDataBadge), findsWidgets);
      expect(
        find.text('Live data not available, showing timetable'),
        findsWidgets,
      );

      final scaffoldCtx = tester.element(find.byType(Scaffold).first);
      expect(MediaQuery.disableAnimationsOf(scaffoldCtx), isTrue);
    });
  });
}
