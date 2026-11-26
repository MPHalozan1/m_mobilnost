//**********************************************
// Production FirebaseAuth & Firestore Auth    *
//**********************************************

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/auth/email_validator.dart';
import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/firebase/firestore_transit_service.dart';
import '../../core/maps/google_web_views.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

//**********************************************
// FirebaseAuthRepository implementation       *
//**********************************************

// Production [AuthRepository] backed by Firebase Authentication (server-side scrypt
// password hashing — zero plaintext storage) and Cloud Firestore `users/{uid}`.
class FirebaseAuthRepository implements AuthRepository {
  // Creates a [FirebaseAuthRepository].
  FirebaseAuthRepository({
    required FirestoreTransitService firestoreService,
    Future<void> Function()? onDeleteLocalData,
    Future<void> Function(String fromUid, String toUid)? onMigrateTickets,
    FirebaseAuth? firebaseAuth,
  })  : _firestore = firestoreService,
        // ignore: prefer_initializing_formals
        _onDeleteLocalData = onDeleteLocalData,
        // ignore: prefer_initializing_formals
        _onMigrateTickets = onMigrateTickets,
        _auth = firebaseAuth ?? FirebaseAuth.instance {
    _controller = StreamController<UserProfile?>.broadcast(
      onListen: () => _controller.add(_currentUser),
    );
    _authSub = _auth.authStateChanges().listen(_handleFirebaseUser);
    if (!isFlutterTestEnvironment && _auth.currentUser == null) {
      unawaited(signInDemoAccount());
    }
  }

  final FirebaseAuth _auth;
  final FirestoreTransitService _firestore;
  final Future<void> Function()? _onDeleteLocalData;
  final Future<void> Function(String fromUid, String toUid)? _onMigrateTickets;
  late final StreamController<UserProfile?> _controller;
  late final StreamSubscription<User?> _authSub;

  UserProfile? _currentUser;
  bool _initialAutoDemoAttempted = false;

  Future<void> _handleFirebaseUser(User? fbUser) async {
    if (fbUser == null) {
      if (!_initialAutoDemoAttempted && !isFlutterTestEnvironment) {
        await signInDemoAccount();
        return;
      }
      _currentUser = null;
      _emit(null);
      return;
    }
    _initialAutoDemoAttempted = true;
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
    final isAnon = fbUser.isAnonymous || overrideProvider == 'anonymous';
    final providerId = overrideProvider ??
        (isAnon
            ? 'anonymous'
            : (fbUser.providerData.any((p) => p.providerId == 'google.com')
                ? 'google'
                : 'email'));
    final isGoogle = providerId == 'google';

    final fallbackName = isAnon
        ? 'Demo Potnik'
        : (fbUser.email?.split('@').first ?? 'Potnik');
    final profile = UserProfile(
      id: fbUser.uid,
      email: isAnon
          ? ''
          : (fbUser.email ?? existing?.email ?? '').trim().toLowerCase(),
      name: (overrideName ??
              existing?.name ??
              fbUser.displayName ??
              fallbackName)
          .trim(),
      dateOfBirth: overrideDob ?? existing?.dateOfBirth,
      preferredLocaleCode:
          overrideLocale ?? existing?.preferredLocaleCode ?? 'sl',
      guardianConfirmed:
          overrideGuardianConfirmed ?? existing?.guardianConfirmed ?? false,
      photoUrl: fbUser.photoURL ?? existing?.photoUrl,
      authProvider: providerId,
      emailVerified: isAnon ? false : (isGoogle || fbUser.emailVerified),
      isDemo: isAnon || (existing?.isDemo ?? false),
      walletBalanceEur:
          existing?.walletBalanceEur ?? (isAnon ? 25.0 : 0.0),
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
    final previousDemoUid =
        _currentUser?.isAnonymousDemo == true ? _currentUser!.id : null;
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
      if (previousDemoUid != null &&
          profile.id != previousDemoUid &&
          _onMigrateTickets != null) {
        unawaited(_onMigrateTickets(previousDemoUid, profile.id));
      }
      _currentUser = profile;
      _emit(profile);
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        e.code,
        _mapFirebaseAuthMessage(e.code, e.message),
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
    final policy = EmailValidator.evaluatePasswordPolicy(password);
    if (!policy.isCompliant) {
      throw const AuthException(
        'password-does-not-meet-requirements',
        'Geslo mora vsebovati najmanj 6 znakov, 1 veliko črko (A–Z), 1 malo črko (a–z) in 1 številko (0–9).',
      );
    }

    final previousDemoUid =
        _currentUser?.isAnonymousDemo == true ? _currentUser!.id : null;
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
      if (previousDemoUid != null &&
          profile.id != previousDemoUid &&
          _onMigrateTickets != null) {
        unawaited(_onMigrateTickets(previousDemoUid, profile.id));
      }
      _currentUser = profile;
      _emit(profile);
      return profile;
    } on FirebaseAuthException catch (e) {
      final mappedCode =
          e.code == 'email-already-in-use' ? 'email_already_exists' : e.code;
      throw AuthException(
        mappedCode,
        _mapFirebaseAuthMessage(e.code, e.message),
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
    final previousDemoUid =
        _currentUser?.isAnonymousDemo == true ? _currentUser!.id : null;
    try {
      final identity = await GoogleAuthBridge.authenticate();
      final fbUser = _auth.currentUser;
      if (fbUser != null && !fbUser.isAnonymous) {
        final profile = await _mergeAndSyncProfile(
          fbUser,
          overrideLocale: preferredLocaleCode,
          overrideProvider: 'google',
        );
        if (previousDemoUid != null &&
            profile.id != previousDemoUid &&
            _onMigrateTickets != null) {
          unawaited(_onMigrateTickets(previousDemoUid, profile.id));
        }
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
        if (previousDemoUid != null &&
            profile.id != previousDemoUid &&
            _onMigrateTickets != null) {
          unawaited(_onMigrateTickets(previousDemoUid, profile.id));
        }
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
        _mapFirebaseAuthMessage(e.code, e.message),
      );
    }
  }

  @override
  Future<UserProfile> signInDemoAccount({
    String preferredLocaleCode = 'sl',
  }) async {
    _initialAutoDemoAttempted = true;
    final existing = _currentUser;
    if (existing != null) return existing;

    final activeFb = _auth.currentUser;
    if (activeFb != null) {
      final synced = await _mergeAndSyncProfile(
        activeFb,
        overrideLocale: preferredLocaleCode,
      );
      _currentUser = synced;
      _emit(synced);
      return synced;
    }

    try {
      final cred = await _auth.signInAnonymously();
      final fbUser = cred.user;
      if (fbUser != null) {
        final profile = await _mergeAndSyncProfile(
          fbUser,
          overrideName: 'Demo Potnik',
          overrideLocale: preferredLocaleCode,
          overrideProvider: 'anonymous',
        );
        _currentUser = profile;
        _emit(profile);
        return profile;
      }
    } catch (_) {
      // Fallback safely to an offline local Demo profile when offline or if
      // Anonymous Auth is disabled in Firebase Console.
    }

    final fallbackDemo = UserProfile(
      id: 'user_demo_marprom',
      email: '',
      name: 'Demo Potnik',
      preferredLocaleCode: preferredLocaleCode,
      authProvider: 'anonymous',
      emailVerified: false,
      isDemo: true,
      walletBalanceEur: 25.0,
      createdAt: DateTime.now(),
    );
    _currentUser = fallbackDemo;
    _emit(fallbackDemo);
    return fallbackDemo;
  }

  @override
  Future<void> signOut() async {
    _initialAutoDemoAttempted = true;
    try {
      await _auth.signOut();
    } catch (_) {}
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
        _mapFirebaseAuthMessage(e.code, e.message),
      );
    }
  }

  static String _mapFirebaseAuthMessage(String code, String? fallback) {
    switch (code) {
      case 'weak-password':
      case 'password-does-not-meet-requirements':
        return 'Geslo ne ustreza varnostnim zahtevam Firebase (min. 6 znakov, velika črka A–Z, mala črka a–z in številka 0–9).';
      case 'email-already-in-use':
        return 'Ta e-poštni naslov je že registriran. Prijavite se ali ponastavite geslo.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Napačen e-poštni naslov ali geslo.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Google prijavno okno je bilo zaprto pred dokončanjem.';
      case 'network-request-failed':
        return 'Omrežna napaka pri povezavi s Firebase Auth. Preverite povezavo.';
      case 'too-many-requests':
        return 'Preveč poskusov prijave. Počakajte nekaj minut in poskusite znova.';
      default:
        return fallback ?? 'Napaka pri avtentikaciji ($code).';
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
