//**********************************************
// Live GPS (Web + Android) & Nearest Stops    *
//**********************************************

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/accessibility/favorites_provider.dart';
import 'package:m_mobilnost/core/maps/google_web_views.dart';
import 'package:m_mobilnost/core/utils/distance.dart';
import 'package:m_mobilnost/core/utils/geo.dart';
import 'package:m_mobilnost/data/models/bus_stop.dart';
import 'package:m_mobilnost/features/lines/data/transit_providers.dart';

/// Describes how the user's current Maribor reference position was obtained.
enum LocationAccessKind {
  /// Live GPS coordinates obtained with user permission (Web HTTPS & Android).
  gps,

  /// User explicitly enabled manual stop mode in settings.
  manualMode,

  /// GPS permission denied, disabled, or unavailable.
  unavailableOrDenied,
}

/// Nearby Marprom stop enriched with walking distance and estimated walk minutes.
@immutable
class NearbyStopSummary {
  /// Creates a [NearbyStopSummary].
  const NearbyStopSummary({
    required this.stop,
    required this.distanceMeters,
    required this.walkMinutes,
  });

  /// Bus stop metadata including serving Marprom line IDs.
  final BusStop stop;

  /// Distance in meters from the user's current/reference position.
  final double distanceMeters;

  /// Estimated walking minutes to reach [stop].
  final int walkMinutes;
}

/// Resolved location state combining GPS coordinates or manual stop fallback.
@immutable
class UserLocationState {
  /// Creates a [UserLocationState] with a non-null [effectivePosition].
  const UserLocationState({
    required this.kind,
    required this.effectivePosition,
    this.manualStop,
    this.nearestStops = const [],
    this.lastUpdatedAt,
  });

  /// Resolution source (GPS, manual mode, or denied/unavailable fallback).
  final LocationAccessKind kind;

  /// Geographic coordinate used to sort nearby stops and center maps.
  final LatLng effectivePosition;

  /// Active manual fallback stop when not using live GPS.
  final BusStop? manualStop;

  /// Auto-computed nearest Marprom stops around [effectivePosition].
  final List<NearbyStopSummary> nearestStops;

  /// Timestamp of last location resolution.
  final DateTime? lastUpdatedAt;

  /// Whether a live GPS fix is currently active.
  bool get isGps => kind == LocationAccessKind.gps;

  /// Whether manual stop fallback guidance should be shown.
  bool get showManualFallbackCard => kind != LocationAccessKind.gps;
}

/// Safe wrapper around `geolocator` supporting both Web HTTPS Geolocation
/// and Android GPS without crashing or hanging in widget tests.
class LocationService {
  /// Creates a [LocationService] with an optional test [gpsProbe] override.
  const LocationService({
    this.gpsProbe,
  });

  /// Optional test hook overriding native/web GPS probing.
  final Future<LatLng?> Function()? gpsProbe;

  /// Attempts to read the device position safely on Web & Android.
  Future<LatLng?> tryGetCurrentPosition({bool requestPermission = true}) async {
    if (gpsProbe != null) {
      try {
        return await gpsProbe!();
      } catch (_) {
        return null;
      }
    }
    if (isFlutterTestEnvironment) {
      return null;
    }
    try {
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 7),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Opens continuous GPS tracking stream on Web & Android (empty in unit tests).
  Stream<LatLng> watchPositionStream() {
    if (isFlutterTestEnvironment || gpsProbe != null) {
      return const Stream<LatLng>.empty();
    }
    try {
      return Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 15,
        ),
      ).map((p) => LatLng(p.latitude, p.longitude)).handleError((_) {});
    } catch (_) {
      return const Stream<LatLng>.empty();
    }
  }

  /// Computes nearest Marprom stops around [position], optionally filtered to
  /// step-free stops only.
  static List<NearbyStopSummary> computeNearestStops(
    LatLng position,
    List<BusStop> stops, {
    bool accessibleOnly = false,
    int limit = 5,
  }) {
    final items = <NearbyStopSummary>[];
    for (final stop in stops) {
      if (accessibleOnly && !stop.isStepFree) continue;
      final d = GeoUtils.haversineMeters(position, stop.position);
      items.add(
        NearbyStopSummary(
          stop: stop,
          distanceMeters: d,
          walkMinutes: DistanceUtils.estimateWalkMinutes(d),
        ),
      );
    }
    items.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return items.take(limit).toList(growable: false);
  }
}

/// Exposes [LocationService] for safe injection and test overrides.
final locationServiceProvider = Provider<LocationService>((ref) {
  return const LocationService();
});

/// Isolates live GPS coordinate updates into a lightweight [ValueNotifier]
/// so moving coordinates update the map GPS dot without rebuilding screens.
final liveGpsPositionNotifierProvider =
    Provider<ValueNotifier<LatLng?>>((ref) {
  final notifier = ValueNotifier<LatLng?>(null);
  final service = ref.watch(locationServiceProvider);
  StreamSubscription<LatLng>? sub;

  Future<void> initGps() async {
    final pos = await service.tryGetCurrentPosition(requestPermission: true);
    if (pos != null) {
      notifier.value = pos;
    }
    sub = service.watchPositionStream().listen((pos) {
      notifier.value = pos;
    });
  }

  if (!isFlutterTestEnvironment) {
    initGps();
  }

  ref.onDispose(() {
    sub?.cancel();
    notifier.dispose();
  });
  return notifier;
});

/// Resolves the active [UserLocationState] combining GPS, nearest stops,
/// and manual stop fallback.
final userLocationProvider = FutureProvider<UserLocationState>((ref) async {
  final settings = ref.watch(a11ySettingsProvider);
  final favorites = ref.watch(favoritesProvider);
  final stops = await ref.watch(allStopsProvider.future);

  BusStop? manualStop;
  final manualId =
      favorites.manualStopId ?? FavoritesState.defaultManualStopId;
  for (final stop in stops) {
    if (stop.id == manualId) {
      manualStop = stop;
      break;
    }
  }
  manualStop ??= stops.isNotEmpty ? stops.first : null;
  final fallbackPos = manualStop?.position ?? GeoUtils.mariborCenter;

  if (settings.locationManualMode) {
    return UserLocationState(
      kind: LocationAccessKind.manualMode,
      effectivePosition: fallbackPos,
      manualStop: manualStop,
      nearestStops: LocationService.computeNearestStops(
        fallbackPos,
        stops,
        accessibleOnly: settings.wheelchairAccessibleOnly,
      ),
      lastUpdatedAt: DateTime.now(),
    );
  }

  final gpsPos =
      await ref.watch(locationServiceProvider).tryGetCurrentPosition();
  if (gpsPos != null) {
    ref.read(liveGpsPositionNotifierProvider).value = gpsPos;
    return UserLocationState(
      kind: LocationAccessKind.gps,
      effectivePosition: gpsPos,
      manualStop: manualStop,
      nearestStops: LocationService.computeNearestStops(
        gpsPos,
        stops,
        accessibleOnly: settings.wheelchairAccessibleOnly,
      ),
      lastUpdatedAt: DateTime.now(),
    );
  }

  return UserLocationState(
    kind: LocationAccessKind.unavailableOrDenied,
    effectivePosition: fallbackPos,
    manualStop: manualStop,
    nearestStops: LocationService.computeNearestStops(
      fallbackPos,
      stops,
      accessibleOnly: settings.wheelchairAccessibleOnly,
    ),
    lastUpdatedAt: DateTime.now(),
  );
});
