//**********************************************
// Cloud Firestore m-mobilnost-2 Service       *
//**********************************************

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/bus_line.dart';
import '../../data/models/bus_position.dart';
import '../../data/models/bus_stop.dart';
import '../../data/models/occupancy.dart';
import '../../data/models/user_profile.dart';
import '../maps/google_web_views.dart';
import 'firebase_bootstrap.dart';

//**********************************************
// Saved Route & Occupancy Report Models       *
//**********************************************

/// User-saved transit route document stored in Firestore `saved_routes`.
@immutable
class SavedRouteRecord {
  /// Creates a [SavedRouteRecord].
  const SavedRouteRecord({
    required this.id,
    required this.userId,
    required this.originName,
    required this.destinationName,
    this.originStopId,
    this.destinationStopId,
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
    this.lineIds = const [],
    this.label,
    this.isFavorite = true,
    this.accessibleOnly = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Firestore document ID.
  final String id;

  /// Owner Firebase Auth UID (`request.auth.uid`).
  final String userId;

  /// Origin stop/place display name.
  final String originName;

  /// Destination stop/place display name.
  final String destinationName;

  /// Optional origin bus stop ID.
  final String? originStopId;

  /// Optional destination bus stop ID.
  final String? destinationStopId;

  /// Optional origin latitude.
  final double? originLat;

  /// Optional origin longitude.
  final double? originLng;

  /// Optional destination latitude.
  final double? destinationLat;

  /// Optional destination longitude.
  final double? destinationLng;

  /// Line codes/IDs traversed along this saved trip.
  final List<String> lineIds;

  /// Optional custom label (`Dom → Faks`, etc.).
  final String? label;

  /// Whether marked favorite.
  final bool isFavorite;

  /// Whether saved with wheelchair accessibility enabled.
  final bool accessibleOnly;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last modification timestamp.
  final DateTime updatedAt;

  /// Serializes into a payload obeying `firestore.rules` `saved_routes/{routeId}`.
  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'originName': _clampStr(originName, 150),
        'destinationName': _clampStr(destinationName, 150),
        if (originStopId != null && originStopId!.isNotEmpty)
          'originStopId': _clampStr(originStopId!, 64),
        if (destinationStopId != null && destinationStopId!.isNotEmpty)
          'destinationStopId': _clampStr(destinationStopId!, 64),
        if (originLat != null) 'originLat': originLat,
        if (originLng != null) 'originLng': originLng,
        if (destinationLat != null) 'destinationLat': destinationLat,
        if (destinationLng != null) 'destinationLng': destinationLng,
        'lineIds': lineIds.take(20).toList(growable: false),
        if (label != null && label!.trim().isNotEmpty)
          'label': _clampStr(label!.trim(), 100),
        'isFavorite': isFavorite,
        'accessibleOnly': accessibleOnly,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Deserializes a Firestore `saved_routes` document.
  factory SavedRouteRecord.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    return SavedRouteRecord(
      id: (data['id'] as String?) ?? docId,
      userId: (data['userId'] as String?) ?? '',
      originName: (data['originName'] as String?) ?? '',
      destinationName: (data['destinationName'] as String?) ?? '',
      originStopId: data['originStopId'] as String?,
      destinationStopId: data['destinationStopId'] as String?,
      originLat: (data['originLat'] as num?)?.toDouble(),
      originLng: (data['originLng'] as num?)?.toDouble(),
      destinationLat: (data['destinationLat'] as num?)?.toDouble(),
      destinationLng: (data['destinationLng'] as num?)?.toDouble(),
      lineIds: (data['lineIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      label: data['label'] as String?,
      isFavorite: data['isFavorite'] as bool? ?? true,
      accessibleOnly: data['accessibleOnly'] as bool? ?? false,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }
}

/// Crowd occupancy report document stored in Firestore `occupancy_reports`.
@immutable
class OccupancyReportRecord {
  /// Creates an [OccupancyReportRecord].
  const OccupancyReportRecord({
    required this.id,
    required this.userId,
    required this.lineId,
    required this.reportedLoadPercent,
    this.vehicleId,
    this.directionId,
    this.stopId,
    this.occupancyLevel,
    this.comment,
    required this.createdAt,
  });

  /// Firestore document ID.
  final String id;

  /// Reporter Firebase Auth UID.
  final String userId;

  /// Reported Marprom line ID.
  final String lineId;

  /// Integer load percentage (`0..100`).
  final int reportedLoadPercent;

  /// Optional live vehicle ID.
  final String? vehicleId;

  /// Optional direction ID.
  final String? directionId;

  /// Optional boarding/current stop ID.
  final String? stopId;

  /// Discrete level string (`low`, `medium`, `high`).
  final String? occupancyLevel;

  /// Optional short rider comment (<= 280 chars).
  final String? comment;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Deserializes a Firestore `occupancy_reports` document.
  factory OccupancyReportRecord.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    return OccupancyReportRecord(
      id: docId,
      userId: (data['userId'] as String?) ?? '',
      lineId: (data['lineId'] as String?) ?? '',
      reportedLoadPercent:
          (data['reportedLoadPercent'] as num?)?.round().clamp(0, 100) ?? 50,
      vehicleId: data['vehicleId'] as String?,
      directionId: data['directionId'] as String?,
      stopId: data['stopId'] as String?,
      occupancyLevel: data['occupancyLevel'] as String?,
      comment: data['comment'] as String?,
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }
}

//**********************************************
// FirestoreTransitService implementation      *
//**********************************************

/// Connects the shared Flutter Web + Android app to Cloud Firestore (`m-mobilnost-2`,
/// `(default)` database) for `users`, `bus_lines`, `stations`, `active_buses`,
/// `saved_routes`, and `occupancy_reports`, failing safely when offline or disabled.
class FirestoreTransitService {
  /// Creates a [FirestoreTransitService].
  FirestoreTransitService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;
  bool _catalogSeededThisSession = false;

  bool get _canUseFirestore =>
      !isFlutterTestEnvironment && FirebaseBootstrap.isReady;

  FirebaseFirestore? get _db {
    if (_firestoreOverride != null) return _firestoreOverride;
    if (!_canUseFirestore) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Creates or updates `users/{uid}` in Firestore using only allowlisted keys
  /// (never storing passwords, hashes, or secrets).
  Future<void> upsertUserProfile(UserProfile profile) async {
    final db = _db;
    if (db == null) return;
    try {
      final docRef = db.collection('users').doc(profile.id);
      final snap = await docRef.get();
      if (snap.exists) {
        await docRef.update(profile.toFirestore(forUpdate: true));
      } else {
        await docRef.set(profile.toFirestore(forUpdate: false));
      }
    } catch (_) {
      // Non-fatal if Firestore API isn't enabled yet or network is offline.
    }
  }

  /// Fetches `users/{uid}` from Firestore, returning null if unavailable.
  Future<UserProfile?> getUserProfile(String uid) async {
    final db = _db;
    if (db == null || uid.isEmpty) return null;
    try {
      final snap = await db.collection('users').doc(uid).get();
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return UserProfile.fromJson({...data, 'id': data['id'] ?? snap.id});
    } catch (_) {
      return null;
    }
  }

  /// Deletes the owner's `users/{uid}` profile document on GDPR deletion.
  Future<void> deleteUserProfile(String uid) async {
    final db = _db;
    if (db == null || uid.isEmpty) return;
    try {
      await db.collection('users').doc(uid).delete();
    } catch (_) {}
  }

  /// Seeds public `bus_lines` and `stations` collections once per session
  /// when authenticated, adhering to `firestore.rules` public transit schemas.
  Future<void> seedPublicTransitCatalogIfNeeded({
    required List<BusLine> lines,
    required List<BusStop> stops,
  }) async {
    if (_catalogSeededThisSession) return;
    final db = _db;
    if (db == null) return;
    _catalogSeededThisSession = true;

    try {
      final existingLines = await db.collection('bus_lines').limit(1).get();
      if (existingLines.docs.isNotEmpty) return;

      final batch = db.batch();
      for (final line in lines) {
        batch.set(
          db.collection('bus_lines').doc(line.id),
          line.toFirestore(),
        );
      }
      for (final stop in stops) {
        batch.set(
          db.collection('stations').doc(stop.id),
          stop.toFirestore(),
        );
      }
      await batch.commit();
    } catch (_) {
      // Fails quietly when unauthenticated or Firestore API disabled.
    }
  }

  /// Syncs live bus telemetry snapshots to `active_buses/{vehicleId}`.
  Future<void> syncActiveBuses(List<BusPosition> buses) async {
    final db = _db;
    if (db == null || buses.isEmpty) return;
    try {
      final batch = db.batch();
      for (final bus in buses) {
        batch.set(
          db.collection('active_buses').doc(bus.vehicleId),
          bus.toFirestore(),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Streams saved routes owned by [userId], sorted newest first in Dart.
  Stream<List<SavedRouteRecord>> watchUserSavedRoutes(String userId) {
    final db = _db;
    if (db == null || userId.isEmpty) {
      return Stream<List<SavedRouteRecord>>.value(const []);
    }
    try {
      return db
          .collection('saved_routes')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snap) {
        final items = snap.docs
            .map((d) => SavedRouteRecord.fromFirestore(d.id, d.data()))
            .toList(growable: false);
        items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return items;
      }).handleError((_) => const <SavedRouteRecord>[]);
    } catch (_) {
      return Stream<List<SavedRouteRecord>>.value(const []);
    }
  }

  /// Saves or updates a transit route under `saved_routes/{routeId}`.
  Future<bool> saveRoute(SavedRouteRecord route) async {
    final db = _db;
    if (db == null || route.userId.isEmpty) return false;
    try {
      await db
          .collection('saved_routes')
          .doc(route.id)
          .set(route.toFirestore());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a saved route owned by the signed-in user.
  Future<bool> deleteSavedRoute(String routeId) async {
    final db = _db;
    if (db == null || routeId.isEmpty) return false;
    try {
      await db.collection('saved_routes').doc(routeId).delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Submits an immutable crowd occupancy report to `occupancy_reports`.
  Future<bool> submitOccupancyReport({
    required String userId,
    required String lineId,
    required int reportedLoadPercent,
    String? vehicleId,
    String? directionId,
    String? stopId,
    BusOccupancyLevel? occupancyLevel,
    String? comment,
  }) async {
    final db = _db;
    if (db == null || userId.isEmpty || lineId.isEmpty) return false;
    try {
      final safePercent = reportedLoadPercent.clamp(0, 100);
      final payload = <String, dynamic>{
        'userId': userId,
        'lineId': _clampStr(lineId, 64),
        'reportedLoadPercent': safePercent,
        if (vehicleId != null && vehicleId.isNotEmpty)
          'vehicleId': _clampStr(vehicleId, 64),
        if (directionId != null && directionId.isNotEmpty)
          'directionId': _clampStr(directionId, 64),
        if (stopId != null && stopId.isNotEmpty)
          'stopId': _clampStr(stopId, 64),
        if (occupancyLevel != null) 'occupancyLevel': occupancyLevel.name,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': _clampStr(comment.trim(), 280),
        'createdAt': DateTime.now().toIso8601String(),
      };
      await db.collection('occupancy_reports').add(payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Streams recent occupancy reports for [lineId], sorted newest first in Dart.
  Stream<List<OccupancyReportRecord>> watchLineOccupancyReports(String lineId) {
    final db = _db;
    if (db == null || lineId.isEmpty) {
      return Stream<List<OccupancyReportRecord>>.value(const []);
    }
    try {
      return db
          .collection('occupancy_reports')
          .where('lineId', isEqualTo: lineId)
          .snapshots()
          .map((snap) {
        final items = snap.docs
            .map((d) => OccupancyReportRecord.fromFirestore(d.id, d.data()))
            .toList(growable: false);
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return items.take(20).toList(growable: false);
      }).handleError((_) => const <OccupancyReportRecord>[]);
    } catch (_) {
      return Stream<List<OccupancyReportRecord>>.value(const []);
    }
  }
}

String _clampStr(String value, int maxLen) =>
    value.length <= maxLen ? value : value.substring(0, maxLen);

DateTime _parseTimestamp(dynamic raw) {
  if (raw is String) {
    return DateTime.tryParse(raw) ?? DateTime.now();
  }
  if (raw != null) {
    try {
      return ((raw as dynamic).toDate() as DateTime?) ?? DateTime.now();
    } catch (_) {}
  }
  return DateTime.now();
}

/// Provides the shared [FirestoreTransitService] connected to `m-mobilnost-2`.
final firestoreTransitServiceProvider = Provider<FirestoreTransitService>((ref) {
  return FirestoreTransitService();
});
