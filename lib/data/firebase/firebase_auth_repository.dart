//**********************************************
// Production FirebaseAuth & Firestore Auth    *
//**********************************************

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/auth/email_validator.dart';
import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/firebase/firestore_transit_service.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

//**********************************************
// FirebaseAuthRepository implementation       *
//**********************************************

/// Production [AuthRepository] backed by Firebase Authentication (server-side scrypt
/// password hashing — zero plaintext storage) and Cloud Firestore `users/{uid}`.
class FirebaseAuthRepository implements AuthRepository {
  /// Creates a [FirebaseAuthRepository].
  FirebaseAuthRepository({
    required FirestoreTransitService firestoreService,
    Future<void> Function()? onDeleteLocalData,
    FirebaseAuth? firebaseAuth,
  })  : _firestore = firestoreService,
        _onDeleteLocalData = onDeleteLocalData,
        _auth = firebaseAuth ?? FirebaseAuth.instance {
    _controller = StreamController<UserProfile?>.broadcast(
      onListen: () => _controller.add(_currentUser),
    );
    _authSub = _auth.authStateChanges().listen(_handleFirebaseUser);
  }

  final FirebaseAuth _auth;
  final FirestoreTransitService _firestore;
  final Future<void> Function()? _onDeleteLocalData;
  late final StreamController<UserProfile?> _controller;
  late final StreamSubscription<User?> _authSub;

  UserProfile? _currentUser;

  Future<void> _handleFirebaseUser(User? fbUser) async {
    if (fbUser == null) {
      _currentUser = null;
      _emit(null);
      return;
    }
    final synced = await _mergeAndSyncProfile(fbUser);
    _currentUser = synced;
    _emit(synced);
  }

  Future<UserProfile> _mergeAndSyncProfile(
    User fbUser, {
    DateTime? overrideDob,
    String? overrideName,
    String? overrideLocale,
    bool? overrideGuardianConfirmed,
    String? overrideProvider,
  }) async {
    final existing = await _firestore.getUserProfile(fbUser.uid);
    final providerId = overrideProvider ??
        (fbUser.providerData.any((p) => p.providerId == 'google.com')
            ? 'google'
            : 'email');
    final isGoogle = providerId == 'google';

    final profile = UserProfile(
      id: fbUser.uid,
      email: (fbUser.email ?? existing?.email ?? '').trim().toLowerCase(),
      name: (overrideName ??
              existing?.name ??
              fbUser.displayName ??
              (fbUser.email?.split('@').first ?? 'Potnik'))
          .trim(),
      dateOfBirth: overrideDob ?? existing?.dateOfBirth,
      preferredLocaleCode:
          overrideLocale ?? existing?.preferredLocaleCode ?? 'sl',
      guardianConfirmed:
          overrideGuardianConfirmed ?? existing?.guardianConfirmed ?? false,
      photoUrl: fbUser.photoURL ?? existing?.photoUrl,
      authProvider: providerId,
      emailVerified: isGoogle || fbUser.emailVerified,
      createdAt:
          existing?.createdAt ?? fbUser.metadata.creationTime ?? DateTime.now(),
    );

    await _firestore.upsertUserProfile(profile);
    return profile;
  }

  @override
  Stream<UserProfile?> watchCurrentUser() => _controller.stream;

  @override
  UserProfile? get currentUser => _currentUser;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final check = EmailValidator.validate(email);
    if (!check.isValid) {
      throw AuthException(
        check.errorCode ?? 'invalid_email',
        check.errorMessageSl ?? 'Neveljaven e-poštni naslov.',
      );
    }
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: check.normalizedEmail,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw const AuthException('auth_failed', 'Prijava ni uspela.');
      }
      final profile = await _mergeAndSyncProfile(user, overrideProvider: 'email');
      _currentUser = profile;
      _emit(profile);
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        e.code,
        e.message ?? 'Napaka pri prijavi (${e.code}).',
      );
    }
  }

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String name,
    DateTime? dateOfBirth,
    String preferredLocaleCode = 'sl',
    bool guardianConfirmed = false,
  }) async {
    final check = EmailValidator.validate(email);
    if (!check.isValid) {
      throw AuthException(
        check.errorCode ?? 'invalid_email',
        check.errorMessageSl ?? 'Neveljaven e-poštni naslov.',
      );
    }
    if (password.length < 6) {
      throw const AuthException(
        'weak_password',
        'Geslo mora vsebovati vsaj 6 znakov.',
      );
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: check.normalizedEmail,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw const AuthException('auth_failed', 'Registracija ni uspela.');
      }
      if (name.trim().isNotEmpty) {
        await user.updateDisplayName(name.trim());
      }
      if (!user.emailVerified) {
        try {
          await user.sendEmailVerification();
        } catch (_) {}
      }

      final profile = await _mergeAndSyncProfile(
        user,
        overrideDob: dateOfBirth,
        overrideName: name.trim(),
        overrideLocale: preferredLocaleCode,
        overrideGuardianConfirmed: guardianConfirmed,
        overrideProvider: 'email',
      );
      _currentUser = profile;
      _emit(profile);
      return profile;
    } on FirebaseAuthException catch (e) {
      final mappedCode =
          e.code == 'email-already-in-use' ? 'email_already_exists' : e.code;
      throw AuthException(
        mappedCode,
        e.message ?? 'Napaka pri registraciji (${e.code}).',
      );
    }
  }

  @override
  Future<UserProfile> signInWithGoogle({
    String? googleEmail,
    String? googleDisplayName,
    String? photoUrl,
    String preferredLocaleCode = 'sl',
  }) async {
    try {
      final identity = await GoogleAuthBridge.authenticate();
      final fbUser = _auth.currentUser;
      if (fbUser != null) {
        final profile = await _mergeAndSyncProfile(
          fbUser,
          overrideLocale: preferredLocaleCode,
          overrideProvider: 'google',
        );
        _currentUser = profile;
        _emit(profile);
        return profile;
      }
      if (identity != null) {
        final profile = UserProfile(
          id: identity.uid,
          email: identity.email.toLowerCase(),
          name: identity.displayName,
          preferredLocaleCode: preferredLocaleCode,
          photoUrl: identity.photoUrl ?? photoUrl,
          authProvider: 'google',
          emailVerified: true,
          createdAt: DateTime.now(),
        );
        await _firestore.upsertUserProfile(profile);
        _currentUser = profile;
        _emit(profile);
        return profile;
      }
      throw const AuthException(
        'google_signin_cancelled',
        'Google prijava je bila preklicana.',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        e.code,
        e.message ?? 'Google prijava ni uspela (${e.code}).',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await GoogleAuthBridge.signOut();
    _currentUser = null;
    _emit(null);
  }

  @override
  Future<void> resetPassword(String email) async {
    final check = EmailValidator.validate(email);
    if (!check.isValid) {
      throw AuthException(
        check.errorCode ?? 'invalid_email',
        check.errorMessageSl ?? 'Neveljaven e-poštni naslov.',
      );
    }
    try {
      await _auth.sendPasswordResetEmail(email: check.normalizedEmail);
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        e.code,
        e.message ?? 'Ponastavitev gesla ni uspela.',
      );
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  @override
  Future<UserProfile?> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      await user.reload();
      final refreshed = _auth.currentUser ?? user;
      final profile = await _mergeAndSyncProfile(refreshed);
      _currentUser = profile;
      _emit(profile);
      return profile;
    } catch (_) {
      return _currentUser;
    }
  }

  @override
  Future<UserProfile> updateProfile(UserProfile updated) async {
    await _firestore.upsertUserProfile(updated);
    if (!kIsWeb && _auth.currentUser != null) {
      try {
        await _auth.currentUser!.updateDisplayName(updated.name);
      } catch (_) {}
    }
    _currentUser = updated;
    _emit(updated);
    return updated;
  }

  @override
  Future<void> deleteAccount() async {
    final uid = _currentUser?.id ?? _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      await _firestore.deleteUserProfile(uid);
    }
    try {
      await _auth.currentUser?.delete();
    } catch (_) {
      // May require recent-login on sensitive ops; still wipe local state.
    }
    await GoogleAuthBridge.signOut();
    _currentUser = null;
    if (_onDeleteLocalData != null) {
      await _onDeleteLocalData();
    }
    _emit(null);
  }

  void _emit(UserProfile? user) {
    if (!_controller.isClosed) {
      _controller.add(user);
    }
  }

  @override
  void dispose() {
    _authSub.cancel();
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
