// Defines UserProfile with age-eligibility helpers for minor/youth/senior rules.

import 'package:flutter/foundation.dart';

/// Represents a signed-in rider profile and demographic eligibility attributes.
@immutable
class UserProfile {
  /// Creates a [UserProfile] record.
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    this.dateOfBirth,
    this.preferredLocaleCode = 'sl',
    this.guardianConfirmed = false,
    this.photoUrl,
    this.authProvider = 'email',
    required this.createdAt,
  });

  /// Unique user account identifier.
  final String id;

  /// User email address.
  final String email;

  /// Full display name.
  final String name;

  /// Optional date of birth used for youth, senior, and minor guardian checks.
  final DateTime? dateOfBirth;

  /// Preferred language code (`sl`, `en`, `de`, or `sr_Latn`).
  final String preferredLocaleCode;

  /// Whether parent/guardian permission has been confirmed for minor purchases.
  final bool guardianConfirmed;

  /// Optional profile avatar URL (populated for Google Sign-In accounts).
  final String? photoUrl;

  /// Authentication source (`email` or `google`).
  final String authProvider;

  /// Account creation timestamp.
  final DateTime createdAt;

  /// Computes exact calendar age in completed years at [referenceDate].
  int? ageAt(DateTime referenceDate) {
    final dob = dateOfBirth;
    if (dob == null) return null;
    var age = referenceDate.year - dob.year;
    final hadBirthdayThisYear = referenceDate.month > dob.month ||
        (referenceDate.month == dob.month && referenceDate.day >= dob.day);
    if (!hadBirthdayThisYear) {
      age -= 1;
    }
    return age < 0 ? 0 : age;
  }

  /// True when the rider is strictly under 16 years old today.
  bool get isUnder16 => isUnder16At(DateTime.now());

  /// True when the rider is strictly under 16 years old at [referenceDate].
  bool isUnder16At(DateTime referenceDate) {
    final age = ageAt(referenceDate);
    return age != null && age < 16;
  }

  /// True when the rider is strictly under 18 years old today.
  bool get isUnder18 => isUnder18At(DateTime.now());

  /// True when the rider is strictly under 18 years old at [referenceDate].
  bool isUnder18At(DateTime referenceDate) {
    final age = ageAt(referenceDate);
    return age != null && age < 18;
  }

  /// True when the rider qualifies for youth fares (6 to 26 years inclusive).
  bool get isYouthEligible => isYouthEligibleAt(DateTime.now());

  /// True when the rider qualifies for youth fares at [referenceDate].
  bool isYouthEligibleAt(DateTime referenceDate) {
    final age = ageAt(referenceDate);
    return age != null && age >= 6 && age <= 26;
  }

  /// True when the rider qualifies for senior fares (65 years and older).
  bool get isSeniorEligible => isSeniorEligibleAt(DateTime.now());

  /// True when the rider qualifies for senior fares at [referenceDate].
  bool isSeniorEligibleAt(DateTime referenceDate) {
    final age = ageAt(referenceDate);
    return age != null && age >= 65;
  }

  /// Returns a copy of this profile with selected fields replaced.
  UserProfile copyWith({
    String? id,
    String? email,
    String? name,
    DateTime? dateOfBirth,
    String? preferredLocaleCode,
    bool? guardianConfirmed,
    String? photoUrl,
    String? authProvider,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      preferredLocaleCode: preferredLocaleCode ?? this.preferredLocaleCode,
      guardianConfirmed: guardianConfirmed ?? this.guardianConfirmed,
      photoUrl: photoUrl ?? this.photoUrl,
      authProvider: authProvider ?? this.authProvider,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serializes this profile into JSON for local storage.
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'preferredLocaleCode': preferredLocaleCode,
        'guardianConfirmed': guardianConfirmed,
        'photoUrl': photoUrl,
        'authProvider': authProvider,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Restores a [UserProfile] from stored JSON data.
  factory UserProfile.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      dateOfBirth: json['dateOfBirth'] == null
          ? null
          : DateTime.parse(json['dateOfBirth'] as String),
      preferredLocaleCode: json['preferredLocaleCode'] as String? ?? 'sl',
      guardianConfirmed: json['guardianConfirmed'] as bool? ?? false,
      photoUrl: json['photoUrl'] as String?,
      authProvider: json['authProvider'] as String? ?? 'email',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
