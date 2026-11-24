//**********************************************
// BusStop domain model with Firestore sync    *
//**********************************************

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Represents a physical Marprom bus stop in Maribor with accessibility metadata.
@immutable
class BusStop {
  /// Creates a [BusStop] record with coordinates, served lines, and amenities.
  const BusStop({
    required this.id,
    required this.name,
    required this.position,
    required this.lineIds,
    this.directionLabels = const {},
    this.platform,
    this.hasShelter = false,
    this.hasBench = false,
    this.hasTactile = false,
    this.isStepFree = false,
    this.hasDigitalDisplay = false,
  });

  /// Unique stop identifier used across lines, timetables, and routing.
  final String id;

  /// Human-readable stop name shown in UI and announcements.
  final String name;

  /// Geographic coordinates of the stop.
  final LatLng position;

  /// IDs of bus lines serving this stop.
  final List<String> lineIds;

  /// Maps a line or direction key to its destination label at this stop.
  final Map<String, String> directionLabels;

  /// Optional bay or platform code (for example `A`, `1`, or `Peron 2`).
  final String? platform;

  /// Whether the stop has a weather shelter.
  final bool hasShelter;

  /// Whether seating is available at the stop.
  final bool hasBench;

  /// Whether tactile paving for blind or low-vision riders is installed.
  final bool hasTactile;

  /// Whether boarding platforms allow step-free wheelchair/stroller access.
  final bool isStepFree;

  /// Whether a live digital arrival display exists at the stop.
  final bool hasDigitalDisplay;

  /// Returns a copy of this stop with selected fields replaced.
  BusStop copyWith({
    String? id,
    String? name,
    LatLng? position,
    List<String>? lineIds,
    Map<String, String>? directionLabels,
    String? platform,
    bool? hasShelter,
    bool? hasBench,
    bool? hasTactile,
    bool? isStepFree,
    bool? hasDigitalDisplay,
  }) {
    return BusStop(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      lineIds: lineIds ?? this.lineIds,
      directionLabels: directionLabels ?? this.directionLabels,
      platform: platform ?? this.platform,
      hasShelter: hasShelter ?? this.hasShelter,
      hasBench: hasBench ?? this.hasBench,
      hasTactile: hasTactile ?? this.hasTactile,
      isStepFree: isStepFree ?? this.isStepFree,
      hasDigitalDisplay: hasDigitalDisplay ?? this.hasDigitalDisplay,
    );
  }

  /// Serializes this stop for the Cloud Firestore `stations` collection.
  Map<String, dynamic> toFirestore() => {
        'id': id,
        'name': name,
        'lat': position.latitude,
        'lng': position.longitude,
        'lineIds': lineIds,
        'directionLabels': directionLabels,
        'platform': platform,
        'hasShelter': hasShelter,
        'hasBench': hasBench,
        'hasTactile': hasTactile,
        'isStepFree': isStepFree,
        'hasDigitalDisplay': hasDigitalDisplay,
      };

  /// Reconstructs a [BusStop] from a Firestore `stations` document map.
  factory BusStop.fromFirestore(Map<String, dynamic> data, String docId) {
    final lat = (data['lat'] as num?)?.toDouble() ?? 46.5547;
    final lng = (data['lng'] as num?)?.toDouble() ?? 15.6459;
    final rawLines = (data['lineIds'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);
    final rawDirs = (data['directionLabels'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ) ??
        const <String, String>{};
    return BusStop(
      id: data['id'] as String? ?? docId,
      name: data['name'] as String? ?? docId,
      position: LatLng(lat, lng),
      lineIds: rawLines,
      directionLabels: rawDirs,
      platform: data['platform'] as String?,
      hasShelter: data['hasShelter'] as bool? ?? false,
      hasBench: data['hasBench'] as bool? ?? false,
      hasTactile: data['hasTactile'] as bool? ?? false,
      isStepFree: data['isStepFree'] as bool? ?? false,
      hasDigitalDisplay: data['hasDigitalDisplay'] as bool? ?? false,
    );
  }
}
