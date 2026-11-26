// Riverpod providers binding mock data repositories and fleet simulators.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/firebase/firebase_bootstrap.dart';
import 'package:m_mobilnost/core/firebase/firestore_transit_service.dart';
import 'package:m_mobilnost/core/maps/google_web_views.dart';
import 'package:m_mobilnost/core/network/connectivity_provider.dart';

import '../firebase/firebase_auth_repository.dart';
import '../mock/mock_auth_repository.dart';
import '../mock/mock_line_repository.dart';
import '../mock/mock_live_bus_repository.dart';
import '../mock/mock_notice_repository.dart';
import '../mock/mock_payment_repository.dart';
import '../mock/mock_ticket_repository.dart';
import '../mock/mock_timetable_repository.dart';
import '../mock/mock_trip_repository.dart';
import '../models/bus_position.dart';
import '../models/service_notice.dart';
import '../models/user_profile.dart';
import '../simulation/bus_simulator.dart';
import '../simulation/delay_model.dart';
import '../simulation/notice_generator.dart';
import '../simulation/occupancy_model.dart';
import 'auth_repository.dart';
import 'line_repository.dart';
import 'live_bus_repository.dart';
import 'notice_repository.dart';
import 'payment_repository.dart';
import 'ticket_repository.dart';
import 'timetable_repository.dart';
import 'trip_repository.dart';

// TODO(firebase): Swap Mock* providers below with Firebase implementations in one place.

/// Provides the seeded deterministic [DelayModel].
final delayModelProvider = Provider<DelayModel>((ref) {
  final seed = ref.watch(a11ySettingsProvider.select((s) => s.simulationSeed));
  return DelayModel(seed: seed);
});

/// Provides the seeded deterministic [OccupancyModel].
final occupancyModelProvider = Provider<OccupancyModel>((ref) {
  final seed = ref.watch(a11ySettingsProvider.select((s) => s.simulationSeed));
  return OccupancyModel(seed: seed);
});

/// Provides the singleton [BusSimulator] kept in sync with [a11ySettingsProvider].
final busSimulatorProvider = Provider<BusSimulator>((ref) {
  final initial = ref.read(a11ySettingsProvider);
  final simulator = BusSimulator(
    seed: initial.simulationSeed,
    useSimulatedLive: initial.useSimulatedLive,
  );
  ref.listen<A11ySettings>(a11ySettingsProvider, (_, next) {
    simulator.updateConfig(
      seed: next.simulationSeed,
      useSimulatedLive: next.useSimulatedLive,
    );
  });
  ref.onDispose(simulator.dispose);
  return simulator;
});

/// Provides the [NoticeGenerator] driven by the configured simulation seed.
final noticeGeneratorProvider = Provider<NoticeGenerator>((ref) {
  final seed = ref.watch(a11ySettingsProvider.select((s) => s.simulationSeed));
  return NoticeGenerator(seed: seed);
});

/// Provides the active [LineRepository] implementation.
final lineRepositoryProvider = Provider<LineRepository>((ref) {
  return const MockLineRepository();
});

/// Provides the active [TimetableRepository] implementation.
final timetableRepositoryProvider = Provider<TimetableRepository>((ref) {
  final delayModel = ref.watch(delayModelProvider);
  final occupancyModel = ref.watch(occupancyModelProvider);
  return MockTimetableRepository(
    delayModel: delayModel,
    occupancyModel: occupancyModel,
    isSimulatedLiveEnabled: () => ref.read(a11ySettingsProvider).useSimulatedLive,
    isOfflineCheck: () => ref.read(isOfflineProvider),
  );
});

/// Provides the active [LiveBusRepository] implementation.
final liveBusRepositoryProvider = Provider<LiveBusRepository>((ref) {
  final simulator = ref.watch(busSimulatorProvider);
  final occupancyModel = ref.watch(occupancyModelProvider);
  final repo = MockLiveBusRepository(
    simulator: simulator,
    occupancyModel: occupancyModel,
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Provides the active [TripRepository] implementation.
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return MockTripRepository(
    lineRepository: ref.watch(lineRepositoryProvider),
    timetableRepository: ref.watch(timetableRepositoryProvider),
    isSimulatedLiveEnabled: () => ref.read(a11ySettingsProvider).useSimulatedLive,
    isOfflineCheck: () => ref.read(isOfflineProvider),
  );
});

//**********************************************
// Ticket, Payment, Notice & Auth Providers    *
//**********************************************

Future<void> _restoreOrStartDemoSession(
  MockAuthRepository authRepo,
  MockTicketRepository ticketRepo,
) async {
  try {
    final restored = await authRepo.restoreSession();
    final active = restored ?? await authRepo.signInDemoAccount();
    if (active.isAnonymousDemo) {
      await ticketRepo.ensureDemoTicketSeeded(active.id);
    }
  } catch (_) {}
}

// Provides the active [TicketRepository] implementation.
final ticketRepositoryProvider = Provider<TicketRepository>((ref) {
  final firestoreService = ref.watch(firestoreTransitServiceProvider);
  final repo = MockTicketRepository(firestoreService: firestoreService);
  ref.onDispose(repo.dispose);
  return repo;
});

// Provides the active [PaymentRepository] implementation.
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return MockPaymentRepository();
});

// Provides the active [NoticeRepository] implementation.
final noticeRepositoryProvider = Provider<NoticeRepository>((ref) {
  final repo = MockNoticeRepository(
    generator: ref.watch(noticeGeneratorProvider),
    isSimulatedLiveEnabled: () => ref.read(a11ySettingsProvider).useSimulatedLive,
  );
  ref.listen<int>(
    a11ySettingsProvider.select((s) => s.simulationSeed),
    (_, next) => repo.updateSeed(next),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

// Provides the active [AuthRepository] backed by Firebase Auth + Firestore (`m-mobilnost-2`)
// when configured, falling back safely to [MockAuthRepository] offline or in widget tests.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final tickets = ref.watch(ticketRepositoryProvider);
  final timetables = ref.watch(timetableRepositoryProvider);
  final payments = ref.watch(paymentRepositoryProvider);
  final firestoreService = ref.watch(firestoreTransitServiceProvider);

  Future<void> clearLocal() async {
    await tickets.clearAllTickets();
    await timetables.clearCache();
    await payments.clearAll();
    await ref.read(a11ySettingsProvider.notifier).resetAll();
  }

  Future<void> migrateDemoTickets(String fromUid, String toUid) async {
    if (tickets is MockTicketRepository) {
      await tickets.migrateTickets(fromUid, toUid);
    }
  }

  if (FirebaseBootstrap.isReady && !isFlutterTestEnvironment) {
    final repo = FirebaseAuthRepository(
      firestoreService: firestoreService,
      onDeleteLocalData: clearLocal,
      onMigrateTickets: migrateDemoTickets,
    );
    if (tickets is MockTicketRepository) {
      final sub = repo.watchCurrentUser().listen((user) {
        if (user != null && user.isAnonymousDemo) {
          unawaited(tickets.ensureDemoTicketSeeded(user.id));
        }
      });
      ref.onDispose(sub.cancel);
    }
    ref.onDispose(repo.dispose);
    return repo;
  }

  final repo = MockAuthRepository(
    prefs: prefs,
    onDeleteLocalData: clearLocal,
    onMigrateTickets: migrateDemoTickets,
  );
  if (!isFlutterTestEnvironment && tickets is MockTicketRepository) {
    unawaited(_restoreOrStartDemoSession(repo, tickets));
  }
  ref.onDispose(repo.dispose);
  return repo;
});

/// Reactive stream of the currently signed-in [UserProfile] (or null for guest).
final currentUserProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(authRepositoryProvider).watchCurrentUser();
});

/// Reactive stream of active simulated/live [BusPosition] snapshots.
final liveBusesStreamProvider = StreamProvider<List<BusPosition>>((ref) {
  return ref.watch(liveBusRepositoryProvider).watchLiveBuses();
});

/// Reactive stream of active [ServiceNotice] items.
final serviceNoticesStreamProvider = StreamProvider<List<ServiceNotice>>((ref) {
  return ref.watch(noticeRepositoryProvider).watchNotices();
});
