//**********************************************
// Hardened Offline/Test AuthRepository        *
//**********************************************

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/email_validator.dart';
import '../../core/firebase/firebase_bootstrap.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import 'local_storage_helper.dart';

// Offline/test [AuthRepository] enforcing [EmailValidator], zero plaintext
// password persistence, demo login, and full GDPR wipe on delete.
class MockAuthRepository implements AuthRepository {
  // Creates a [MockAuthRepository] with seeded `demo@marprom.si` credentials.
  MockAuthRepository({
    this._prefs,
    this._onDeleteLocalData,
    this._onMigrateTickets,
    String boxName = 'm_mobilnost_auth',
    this.requireEmailVerification = false,
  }) : _store = LocalKeyValueStore(boxName) {
    _seedDemoAccount();
    _controller = StreamController<UserProfile?>.broadcast(
      onListen: () => _controller.add(_currentUser),
    );
  }

  /// Demo account email for usability evaluation and quick testing.
  static const String demoEmail = 'demo@marprom.si';

  /// Demo account password matching [demoEmail].
  static const String demoPassword = 'demo1234';

  final SharedPreferences? _prefs;
  final Future<void> Function()? _onDeleteLocalData;
  final Future<void> Function(String fromUid, String toUid)? _onMigrateTickets;
  final LocalKeyValueStore _store;

  /// When true, newly registered email accounts start unverified until verified.
  final bool requireEmailVerification;

  late final StreamController<UserProfile?> _controller;
  final Map<String, _HashedAccount> _accounts = {};
  UserProfile? _currentUser;

  /// Computes a salted one-way digest in memory only (never stores plaintext passwords).
  static String _saltedDigest(String normalizedEmail, String password) {
    var h1 = 0x811c9dc5;
    var h2 = 0x9e3779b9;
    final input = '$normalizedEmail|marprom-m2-salt-v2|$password';
    for (var round = 0; round < 64; round++) {
      for (var i = 0; i < input.length; i++) {
        final code = input.codeUnitAt(i) ^ (round * 31 + i);
        h1 = ((h1 ^ code) * 0x01000193) & 0x7fffffff;
        h2 = ((h2 + (code << 5)) * 0x45d9f3b) & 0x7fffffff;
      }
    }
    return '${h1.toRadixString(16).padLeft(8, '0')}_${h2.toRadixString(16).padLeft(8, '0')}';
  }

  void _seedDemoAccount() {
    final normalized = demoEmail.toLowerCase();
    _accounts[normalized] = _HashedAccount(
      digest: _saltedDigest(normalized, demoPassword),
      profile: UserProfile(
        id: 'user_demo_marprom',
        email: normalized,
        name: 'Ana Kovač',
        dateOfBirth: DateTime(1995, 5, 14),
        preferredLocaleCode: 'sl',
        guardianConfirmed: false,
        authProvider: 'email',
        emailVerified: true,
        createdAt: DateTime(2025, 1, 10),
      ),
    );
  }

  /// Attempts to restore a previously persisted session from local storage.
  Future<UserProfile?> restoreSession() async {
    final raw = await _store.read('active_user');
    if (raw is Map) {
      _currentUser = UserProfile.fromJson(raw);
      _emit(_currentUser);
    }
    return _currentUser;
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
    final normalized = check.normalizedEmail;
    var account = _accounts[normalized];

    if (account == null) {
      final raw = await _store.read('acct_$normalized');
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final digest = map['passwordDigest'] as String?;
        if (digest != null && map['profile'] is Map) {
          account = _HashedAccount(
            digest: digest,
            profile: UserProfile.fromJson(map['profile'] as Map),
          );
          _accounts[normalized] = account;
        }
      }
    }

    final expectedDigest = _saltedDigest(normalized, password);
    if (account == null || account.digest != expectedDigest) {
      throw const AuthException(
        'invalid_credentials',
        'Invalid email or password.',
      );
    }

    final previousDemoUid =
        _currentUser?.isAnonymousDemo == true ? _currentUser!.id : null;
    _currentUser = account.profile;
    await _store.write('active_user', _currentUser!.toJson());
    if (previousDemoUid != null &&
        _currentUser!.id != previousDemoUid &&
        _onMigrateTickets != null) {
      unawaited(_onMigrateTickets(previousDemoUid, _currentUser!.id));
    }
    _emit(_currentUser);
    return _currentUser!;
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
    if (password.length < 4) {
      throw const AuthException(
        'invalid_input',
        'Valid email and password (min 4 characters) are required.',
      );
    }

    final normalized = check.normalizedEmail;
    if (_accounts.containsKey(normalized) ||
        await _store.read('acct_$normalized') != null) {
      throw const AuthException(
        'email_already_exists',
        'An account with this email already exists.',
      );
    }

    final now = DateTime.now();
    final digest = _saltedDigest(normalized, password);
    final profile = UserProfile(
      id: 'user_${now.microsecondsSinceEpoch}',
      email: normalized,
      name: name.trim(),
      dateOfBirth: dateOfBirth,
      preferredLocaleCode: preferredLocaleCode,
      guardianConfirmed: guardianConfirmed,
      authProvider: 'email',
      emailVerified: !requireEmailVerification,
      createdAt: now,
    );

    final previousDemoUid =
        _currentUser?.isAnonymousDemo == true ? _currentUser!.id : null;
    _accounts[normalized] = _HashedAccount(digest: digest, profile: profile);
    // Security invariant: never persist plaintext passwords.
    await _store.write('acct_$normalized', {
      'passwordDigest': digest,
      'profile': profile.toJson(),
    });
    _currentUser = profile;
    await _store.write('active_user', profile.toJson());
    if (previousDemoUid != null &&
        profile.id != previousDemoUid &&
        _onMigrateTickets != null) {
      unawaited(_onMigrateTickets(previousDemoUid, profile.id));
    }
    _emit(profile);
    return profile;
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
    final firebaseIdentity = await GoogleAuthBridge.authenticate();
    final resolvedEmail =
        (firebaseIdentity?.email ?? googleEmail ?? 'potnik.maribor@gmail.com')
            .trim()
            .toLowerCase();
    final resolvedName = firebaseIdentity?.displayName ??
        googleDisplayName ??
        'Luka Maribor (Google)';
    final resolvedId =
        firebaseIdentity?.uid ?? 'google_${resolvedEmail.hashCode.abs()}';

    final profile = UserProfile(
      id: resolvedId,
      email: resolvedEmail,
      name: resolvedName,
      preferredLocaleCode: preferredLocaleCode,
      photoUrl: firebaseIdentity?.photoUrl ?? photoUrl,
      authProvider: 'google',
      emailVerified: true,
      createdAt: DateTime.now(),
    );

    final digest = _accounts[resolvedEmail]?.digest ??
        _saltedDigest(resolvedEmail, 'oauth_google');
    _accounts[resolvedEmail] = _HashedAccount(digest: digest, profile: profile);
    await _store.write('acct_$resolvedEmail', {
      'passwordDigest': digest,
      'profile': profile.toJson(),
    });
    _currentUser = profile;
    await _store.write('active_user', profile.toJson());
    if (previousDemoUid != null &&
        profile.id != previousDemoUid &&
        _onMigrateTickets != null) {
      unawaited(_onMigrateTickets(previousDemoUid, profile.id));
    }
    _emit(profile);
    return profile;
  }

  @override
  Future<UserProfile> signInDemoAccount({
    String preferredLocaleCode = 'sl',
  }) async {
    final existing = _currentUser;
    if (existing != null) return existing;

    final demoProfile = UserProfile(
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
    _currentUser = demoProfile;
    await _store.write('active_user', demoProfile.toJson());
    _emit(demoProfile);
    return demoProfile;
  }

  @override
  Future<void> signOut() async {
    await GoogleAuthBridge.signOut();
    _currentUser = null;
    await _store.delete('active_user');
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
    final normalized = check.normalizedEmail;
    final known = _accounts.containsKey(normalized) ||
        await _store.read('acct_$normalized') != null;
    if (!known) {
      throw const AuthException(
        'user_not_found',
        'No account matches the provided email address.',
      );
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    // No-op in local test/offline repository.
  }

  @override
  Future<UserProfile?> reloadCurrentUser() async {
    final current = _currentUser;
    if (current == null) return null;
    final verified = current.copyWith(emailVerified: true);
    return updateProfile(verified);
  }

  @override
  Future<UserProfile> updateProfile(UserProfile updated) async {
    final normalized = updated.email.trim().toLowerCase();
    final digest = _accounts[normalized]?.digest ??
        _saltedDigest(normalized, demoPassword);
    _accounts[normalized] = _HashedAccount(digest: digest, profile: updated);
    await _store.write('acct_$normalized', {
      'passwordDigest': digest,
      'profile': updated.toJson(),
    });
    _currentUser = updated;
    await _store.write('active_user', updated.toJson());
    _emit(updated);
    return updated;
  }

  @override
  Future<void> deleteAccount() async {
    await GoogleAuthBridge.signOut();
    final activeEmail = _currentUser?.email.toLowerCase();
    if (activeEmail != null && activeEmail != demoEmail) {
      _accounts.remove(activeEmail);
    }
    _currentUser = null;
    await _store.clear();
    await _prefs?.clear();
    if (_onDeleteLocalData != null) {
      await _onDeleteLocalData();
    }
    _seedDemoAccount();
    _emit(null);
  }

  void _emit(UserProfile? user) {
    if (!_controller.isClosed) {
      _controller.add(user);
    }
  }

  @override
  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

class _HashedAccount {
  const _HashedAccount({
    required this.digest,
    required this.profile,
  });

  final String digest;
  final UserProfile profile;
}
