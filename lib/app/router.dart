//**********************************************
// Unified Web & Mobile GoRouter Navigation    *
//**********************************************

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/presentation/payment_methods_screen.dart';
import '../features/account/presentation/profile_settings_screen.dart';
import '../features/lines/presentation/line_detail_screen.dart';
import '../features/lines/presentation/lines_screen.dart';
import '../features/live_tracker/presentation/live_tracker_screen.dart';
import '../features/map/presentation/go_map_screen.dart';
import '../features/nearest_stop/presentation/nearest_stop_screen.dart';
import '../features/notices/presentation/notices_screen.dart';
import '../features/onboarding/presentation/new_rider_guide_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/onboarding/presentation/welcome_screen.dart';
import '../features/tickets/presentation/ticket_checkout_screen.dart';
import '../features/tickets/presentation/ticket_shop_screen.dart';
import '../features/tickets/presentation/ticket_view_screen.dart';
import '../features/tickets/presentation/tickets_wallet_screen.dart';
import '../features/timetable/presentation/stop_detail_screen.dart';
import '../features/web_portal/presentation/pages/web_download_page.dart';
import 'shell_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

// Unified GoRouter connecting Web and Android to the exact same 4-tab shell:
// Branch 0: `/` (`GoMapScreen`)
// Branch 1: `/buses` (`LiveTrackerScreen`)
// Branch 2: `/tickets` (`TicketsWalletScreen`)
// Branch 3: `/profile` (`ProfileSettingsScreen`)
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: Go / Map (AI Search, Smart Autocomplete, Nearest Stops & Google Maps)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) {
                  final fromId = state.uri.queryParameters['fromStopId'] ??
                      state.uri.queryParameters['from'];
                  final toId = state.uri.queryParameters['toStopId'] ??
                      state.uri.queryParameters['to'];
                  return GoMapScreen(
                    initialOriginStopId: fromId,
                    initialDestinationStopId: toId,
                  );
                },
              ),
            ],
          ),

          // Tab 2: All Buses (Interactive fleet map, rotated icons, cutaway, 3D route)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/buses',
                builder: (context, state) => LiveTrackerScreen(
                  initialLineId: state.uri.queryParameters['lineId'],
                ),
              ),
            ],
          ),

          // Tab 3: Vozovnica (NFC HCE card + QR + 1-Tap Demo Shop + nested flows)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tickets',
                builder: (context, state) => const TicketsWalletScreen(),
                routes: [
                  GoRoute(
                    path: 'shop',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const TicketShopScreen(),
                  ),
                  GoRoute(
                    path: 'checkout/:typeId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final typeId = state.pathParameters['typeId']!;
                      return TicketCheckoutScreen(typeId: typeId);
                    },
                  ),
                  GoRoute(
                    path: 'view/:ticketId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final ticketId = state.pathParameters['ticketId']!;
                      return TicketViewScreen(ticketId: ticketId);
                    },
                  ),
                  GoRoute(
                    path: ':ticketId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final ticketId = state.pathParameters['ticketId']!;
                      return TicketViewScreen(ticketId: ticketId);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Tab 4: Profile & Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileSettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'payments',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const PaymentMethodsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Schedules & Line Details (accessible from All Buses, Nearest Stops, and top bar)
      GoRoute(
        path: '/lines',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LinesScreen(),
        routes: [
          GoRoute(
            path: ':lineId',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => LineDetailScreen(
              lineId: state.pathParameters['lineId']!,
            ),
          ),
        ],
      ),

      GoRoute(
        path: '/stops/:stopId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => StopDetailScreen(
          stopId: state.pathParameters['stopId']!,
        ),
      ),

      GoRoute(
        path: '/notices',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NoticesScreen(),
      ),

      GoRoute(
        path: '/welcome',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WelcomeScreen(),
      ),

      // Legacy path aliases preserved for backwards compatibility & deep links
      GoRoute(
        path: '/plan',
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) {
          final query = state.uri.query;
          return query.isEmpty ? '/' : '/?$query';
        },
      ),
      GoRoute(
        path: '/map',
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) => '/',
      ),
      GoRoute(
        path: '/live',
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) => '/buses',
      ),
      GoRoute(
        path: '/tracker',
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) {
          final lineId = state.uri.queryParameters['lineId'];
          return lineId == null || lineId.isEmpty
              ? '/buses'
              : '/buses?lineId=${Uri.encodeComponent(lineId)}';
        },
      ),
      GoRoute(
        path: '/account',
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) => '/profile',
        routes: [
          GoRoute(
            path: 'payments',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const PaymentMethodsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) => '/profile',
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) => '/profile',
      ),
      GoRoute(
        path: '/nearest-stop',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NearestStopScreen(),
      ),
      GoRoute(
        path: '/download',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WebDownloadPage(),
      ),
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/guide',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NewRiderGuideScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
