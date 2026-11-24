// Abstract repository contract and exception type for rider authentication and profiles.

import '../models/user_profile.dart';

/// Structured authentication error returned by [AuthRepository] operations.
class AuthException implements Exception {
  /// Creates an [AuthException] with a machine-readable [code] and [message].
  const AuthException(this.code, this.message);

  /// Error identifier (for example `invalid_credentials` or `email_already_exists`).
  final String code;

  /// Diagnostic error message.
  final String message;

  @override
  String toString() => 'AuthException($code): $message';
}

// TODO(firebase): Replace mock implementation with FirebaseAuth + Firestore profile sync.
/// Manages rider authentication, profile updates, and local data deletion.
abstract class AuthRepository {
  /// Broadcast stream emitting the current [UserProfile], or null in guest mode.
  Stream<UserProfile?> watchCurrentUser();

  /// Synchronously reads the currently signed-in [UserProfile], if any.
  UserProfile? get currentUser;

  /// Signs in an existing account using [email] and [password].
  Future<UserProfile> signIn({
    required String email,
    required String password,
  });

  /// Registers a new rider profile and signs them in.
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String name,
    DateTime? dateOfBirth,
    String preferredLocaleCode = 'sl',
    bool guardianConfirmed = false,
  });

  /// Signs in using a Google Account (Firebase OAuth when configured, or local preview Google profile).
  Future<UserProfile> signInWithGoogle({
    String? googleEmail,
    String? googleDisplayName,
    String? photoUrl,
    String preferredLocaleCode = 'sl',
  });

  /// Ends the active session and switches to guest mode.
  Future<void> signOut();

  /// Sends a password reset request for [email].
  Future<void> resetPassword(String email);

  /// Updates persisted rider profile fields.
  Future<UserProfile> updateProfile(UserProfile updated);

  /// Permanently deletes the account and clears all local Hive and preference data.
  Future<void> deleteAccount();

  /// Disposes internal stream resources.
  void dispose();
}
