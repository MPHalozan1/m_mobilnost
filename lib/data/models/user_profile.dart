//**********************************************
// Rider UserProfile domain & Firestore model  *
//**********************************************

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
    this.emailVerified = true,
    this.isDemo = false,
    this.walletBalanceEur = 0.0,
    required this.createdAt,
  });

  /// Unique user account identifier (matches Firebase Auth UID).
  final String id;

  /// User email address (empty for Anonymous Demo users).
  final String email;

  /// Full display name.
  final String name;

  /// Optional date of birth used for youth, senior, and minor guardian checks.
  final DateTime? dateOfBirth;

  /// Preferred language code (`sl`, `en`, `de`, `sr`, or `sr_Latn`).
  final String preferredLocaleCode;

  /// Whether parent/guardian permission has been confirmed for minor purchases.
  final bool guardianConfirmed;

  /// Optional profile avatar URL (populated for Google Sign-In accounts).
  final String? photoUrl;

  /// Authentication source (`email`, `google`, or `anonymous`).
  final String authProvider;

  /// Whether the rider's email address has been verified via Firebase Auth.
  final bool emailVerified;

  /// True when signed in automatically via the zero-friction Demo session.
  final bool isDemo;

  /// Demo or prepaid wallet balance in EUR.
  final double walletBalanceEur;

  /// Account creation timestamp.
  final DateTime createdAt;

  /// True when this profile represents an anonymous/demo guest account.
  bool get isAnonymousDemo => isDemo || authProvider == 'anonymous';

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
    bool? emailVerified,
    bool? isDemo,
    double? walletBalanceEur,
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
      emailVerified: emailVerified ?? this.emailVerified,
      isDemo: isDemo ?? this.isDemo,
      walletBalanceEur: walletBalanceEur ?? this.walletBalanceEur,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serializes this profile into JSON for local storage (never includes passwords).
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'preferredLocaleCode': preferredLocaleCode,
        'guardianConfirmed': guardianConfirmed,
        'photoUrl': photoUrl,
        'authProvider': authProvider,
        'emailVerified': emailVerified,
        'isDemo': isDemo,
        'walletBalanceEur': walletBalanceEur,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Serializes allowed fields matching `firestore.rules` `users/{userId}` schema.
  /// Strictly excludes password hashes/secrets (handled solely by Firebase Auth).
  Map<String, dynamic> toFirestore({bool forUpdate = false}) {
    final safeLocale = const {'sl', 'en', 'de', 'sr', 'sr_Latn'}
            .contains(preferredLocaleCode)
        ? preferredLocaleCode
        : 'sl';
    final safeProvider =
        const {'email', 'google', 'anonymous'}.contains(authProvider)
            ? authProvider
            : 'email';
    final cleanEmail = email.trim().toLowerCase();
    final safeName = name.trim().isEmpty
        ? (cleanEmail.isNotEmpty ? cleanEmail.split('@').first : 'Demo Potnik')
        : (name.trim().length > 100
            ? name.trim().substring(0, 100)
            : name.trim());

    return <String, dynamic>{
      'id': id,
      'uid': id,
      'email': cleanEmail,
      'name': safeName,
      'displayName': safeName,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
      'preferredLocaleCode': safeLocale,
      'guardianConfirmed': guardianConfirmed,
      if (photoUrl != null &&
          (photoUrl!.startsWith('https://') ||
              photoUrl!.startsWith('http://')) &&
          photoUrl!.length <= 512)
        'photoUrl': photoUrl,
      'authProvider': safeProvider,
      'emailVerified': emailVerified,
      'isDemo': isDemo || safeProvider == 'anonymous',
      'walletBalanceEur': walletBalanceEur.clamp(0.0, 10000.0),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Restores a [UserProfile] from stored JSON data.
  factory UserProfile.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    DateTime? parsedDob;
    final rawDob = json['dateOfBirth'];
    if (rawDob is String && rawDob.isNotEmpty) {
      parsedDob = DateTime.tryParse(rawDob);
    } else if (rawDob != null && rawDob is! String) {
      try {
        parsedDob = (rawDob as dynamic).toDate() as DateTime?;
      } catch (_) {}
    }

    DateTime parsedCreatedAt = DateTime.now();
    final rawCreated = json['createdAt'];
    if (rawCreated is String && rawCreated.isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else if (rawCreated != null && rawCreated is! String) {
      try {
        parsedCreatedAt =
            ((rawCreated as dynamic).toDate() as DateTime?) ?? DateTime.now();
      } catch (_) {}
    }

    final provider = json['authProvider'] as String? ?? 'email';
    return UserProfile(
      id: (json['id'] ?? json['uid'] ?? '') as String,
      email: (json['email'] as String?) ?? '',
      name: (json['name'] ?? json['displayName'] ?? 'Demo Potnik') as String,
      dateOfBirth: parsedDob,
      preferredLocaleCode: json['preferredLocaleCode'] as String? ?? 'sl',
      guardianConfirmed: json['guardianConfirmed'] as bool? ?? false,
      photoUrl: json['photoUrl'] as String?,
      authProvider: provider,
      emailVerified: json['emailVerified'] as bool? ?? (provider != 'email'),
      isDemo: json['isDemo'] as bool? ?? (provider == 'anonymous'),
      walletBalanceEur:
          (json['walletBalanceEur'] as num?)?.toDouble() ?? 25.0,
      createdAt: parsedCreatedAt,
    );
  }
}
