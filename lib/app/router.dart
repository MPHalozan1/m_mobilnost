// Defines go_router navigation routes for both the Marprom Web Portal and Mobile App.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/accessibility/a11y_settings.dart';
import '../features/account/presentation/account_screen.dart';
import '../features/account/presentation/payment_methods_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/lines/presentation/line_detail_screen.dart';
import '../features/lines/presentation/lines_screen.dart';
import '../features/live_tracker/presentation/live_tracker_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/nearest_stop/presentation/nearest_stop_screen.dart';
import '../features/notices/presentation/notices_screen.dart';
import '../features/onboarding/presentation/new_rider_guide_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/tickets/presentation/ticket_checkout_screen.dart';
import '../features/tickets/presentation/ticket_shop_screen.dart';
import '../features/tickets/presentation/ticket_view_screen.dart';
import '../features/tickets/presentation/tickets_wallet_screen.dart';
import '../features/timetable/presentation/stop_detail_screen.dart';
import '../features/trip_planner/presentation/trip_planner_screen.dart';
import '../features/web_portal/presentation/marprom_web_scaffold.dart';
import '../features/web_portal/presentation/pages/web_download_page.dart';
import '../features/web_portal/presentation/pages/web_home_page.dart';
import '../features/web_portal/presentation/pages/web_live_stats_page.dart';
import '../features/web_portal/presentation/pages/web_route_planner_page.dart';
import '../features/web_portal/presentation/pages/web_schedules_page.dart';
import '../features/web_portal/presentation/pages/web_tickets_page.dart';
import 'shell_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class _OnboardingRefreshNotifier extends ChangeNotifier {
  void trigger() => notifyListeners();
}

/// When built with --dart-define=FORCE_MOBILE_UI=true, web builds render the
/// mobile app shell instead of the web portal (used for UI previews).
const bool _forceMobileUi = bool.fromEnvironment('FORCE_MOBILE_UI');

/// Whether the web portal routes should be used.
const bool _useWebPortal = kIsWeb && !_forceMobileUi;

/// Provides the single [GoRouter] instance wired to all app & web portal routes.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _OnboardingRefreshNotifier();
  ref.listen<bool>(
    a11ySettingsProvider.select((s) => s.onboardingDone),
    (_, _) => refreshNotifier.trigger(),
  );

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      if (_useWebPortal) return null;
      final onboardingDone = ref.read(a11ySettingsProvider).onboardingDone;
      if (!onboardingDone && state.uri.path == '/') {
        return '/onboarding';
      }
      return null;
    },
    routes: _useWebPortal ? _buildWebRoutes() : _buildMobileRoutes(),
  );

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });

  return router;
});

List<RouteBase> _buildWebRoutes() {
  return [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: const MarpromWebScaffold(
          currentPath: '/',
          child: WebHomePage(),
        ),
      ),
    ),
    GoRoute(
      path: '/lines',
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: const MarpromWebScaffold(
          currentPath: '/lines',
          child: WebSchedulesPage(),
        ),
      ),
      routes: [
        GoRoute(
          path: ':lineId',
          pageBuilder: (context, state) => _adaptivePage(
            context: context,
            state: state,
            child: MarpromWebScaffold(
              currentPath: '/lines',
              child: WebSchedulesPage(
                initialLineId: state.pathParameters['lineId'],
              ),
            ),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/plan',
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: MarpromWebScaffold(
          currentPath: '/plan',
          child: WebRoutePlannerPage(
            initialFromStopId: state.uri.queryParameters['fromStopId'],
            initialToStopId: state.uri.queryParameters['toStopId'],
            initialToName: state.uri.queryParameters['toName'],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/live',
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: MarpromWebScaffold(
          currentPath: '/live',
          child: WebLiveStatsPage(
            initialLineId: state.uri.queryParameters['lineId'],
            initialVehicleId: state.uri.queryParameters['vehicleId'],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/map',
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: MarpromWebScaffold(
          currentPath: '/live',
          child: WebLiveStatsPage(
            initialLineId: state.uri.queryParameters['lineId'],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/tracker',
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: MarpromWebScaffold(
          currentPath: '/live',
          child: WebLiveStatsPage(
            initialLineId: state.uri.queryParameters['lineId'],
            initialVehicleId: state.uri.queryParameters['vehicleId'],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/tickets',
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: const MarpromWebScaffold(
          currentPath: '/tickets',
          child: WebTicketsPage(),
        ),
      ),
      routes: [
        GoRoute(
          path: 'shop',
          pageBuilder: (context, state) => _adaptivePage(
            context: context,
            state: state,
            child: const TicketShopScreen(),
          ),
        ),
        GoRoute(
          path: 'checkout/:typeId',
          pageBuilder: (context, state) => _adaptivePage(
            context: context,
            state: state,
            child: TicketCheckoutScreen(
              typeId: state.pathParameters['typeId'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: 'view/:ticketId',
          pageBuilder: (context, state) => _adaptivePage(
            context: context,
            state: state,
            child: TicketViewScreen(
              ticketId: state.pathParameters['ticketId'] ?? '',
            ),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/download',
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: const MarpromWebScaffold(
          currentPath: '/download',
          child: WebDownloadPage(),
        ),
      ),
    ),
    ..._sharedUtilityRoutes(),
  ];
}

List<RouteBase> _buildMobileRoutes() {
  return [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ShellScaffold(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => _adaptivePage(
                context: context,
                state: state,
                child: const HomeScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/map',
              pageBuilder: (context, state) => _adaptivePage(
                context: context,
                state: state,
                child: MapScreen(
                  initialLineId: state.uri.queryParameters['lineId'],
                  initialStopId: state.uri.queryParameters['stopId'],
                ),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/plan',
              pageBuilder: (context, state) => _adaptivePage(
                context: context,
                state: state,
                child: TripPlannerScreen(
                  initialFromStopId: state.uri.queryParameters['fromStopId'],
                  initialToStopId: state.uri.queryParameters['toStopId'],
                  initialToName: state.uri.queryParameters['toName'],
                ),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tickets',
              pageBuilder: (context, state) => _adaptivePage(
                context: context,
                state: state,
                child: const TicketsWalletScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'shop',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => _adaptivePage(
                    context: context,
                    state: state,
                    child: const TicketShopScreen(),
                  ),
                ),
                GoRoute(
                  path: 'checkout/:typeId',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => _adaptivePage(
                    context: context,
                    state: state,
                    child: TicketCheckoutScreen(
                      typeId: state.pathParameters['typeId'] ?? '',
                    ),
                  ),
                ),
                GoRoute(
                  path: 'view/:ticketId',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => _adaptivePage(
                    context: context,
                    state: state,
                    child: TicketViewScreen(
                      ticketId: state.pathParameters['ticketId'] ?? '',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/lines',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: const LinesScreen(),
      ),
      routes: [
        GoRoute(
          path: ':lineId',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _adaptivePage(
            context: context,
            state: state,
            child: LineDetailScreen(
              lineId: state.pathParameters['lineId'] ?? '',
            ),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/live',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: LiveTrackerScreen(
          initialLineId: state.uri.queryParameters['lineId'],
          initialVehicleId: state.uri.queryParameters['vehicleId'],
          initialStopId: state.uri.queryParameters['stopId'],
        ),
      ),
    ),
    GoRoute(
      path: '/tracker',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: LiveTrackerScreen(
          initialLineId: state.uri.queryParameters['lineId'],
          initialVehicleId: state.uri.queryParameters['vehicleId'],
          initialStopId: state.uri.queryParameters['stopId'],
        ),
      ),
    ),
    GoRoute(
      path: '/download',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: const Scaffold(
          body: SingleChildScrollView(child: WebDownloadPage()),
        ),
      ),
    ),
    ..._sharedUtilityRoutes(),
  ];
}

List<RouteBase> _sharedUtilityRoutes() {
  return [
    GoRoute(
      path: '/stops/:stopId',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: StopDetailScreen(
          stopId: state.pathParameters['stopId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: '/nearest-stop',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: NearestStopScreen(
          initialToStopId: state.uri.queryParameters['toStopId'],
          initialToName: state.uri.queryParameters['toName'],
        ),
      ),
    ),
    GoRoute(
      path: '/account',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: const AccountScreen(),
      ),
      routes: [
        GoRoute(
          path: 'payments',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => _adaptivePage(
            context: context,
            state: state,
            child: const PaymentMethodsScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/notices',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: const NoticesScreen(),
      ),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: const SettingsScreen(),
      ),
    ),
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: const OnboardingScreen(),
      ),
    ),
    GoRoute(
      path: '/login',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: const AccountScreen(),
      ),
    ),
    GoRoute(
      path: '/guide',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _adaptivePage(
        context: context,
        state: state,
        child: const NewRiderGuideScreen(),
      ),
    ),
  ];
}

Page<void> _adaptivePage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  final reducedMotion = ProviderScope.containerOf(context, listen: false)
      .read(a11ySettingsProvider)
      .reducedMotion;
  if (reducedMotion) {
    return NoTransitionPage<void>(key: state.pageKey, child: child);
  }
  return MaterialPage<void>(key: state.pageKey, child: child);
}
