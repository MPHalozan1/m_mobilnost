// Mock AuthRepository with seeded demo user, minor/profile support, and full wipe.

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import 'local_storage_helper.dart';

/// Mock [AuthRepository] supporting demo login, registration, and GDPR deletion.
class MockAuthRepository implements AuthRepository {
  /// Creates a [MockAuthRepository] with seeded `demo@marprom.test` credentials.
  MockAuthRepository({
    this._prefs,
    this._onDeleteLocalData,
    String boxName = 'm_mobilnost_auth',
  }) : _store = LocalKeyValueStore(boxName) {
    _seedDemoAccount();
    _controller = StreamController<UserProfile?>.broadcast(
      onListen: () => _controller.add(_currentUser),
    );
  }

  /// Demo account email for usability evaluation and quick testing.
  static const String demoEmail = 'demo@marprom.test';

  /// Demo account password matching [demoEmail].
  static const String demoPassword = 'demo1234';

  final SharedPreferences? _prefs;
  final Future<void> Function()? _onDeleteLocalData;
  final LocalKeyValueStore _store;
  late final StreamController<UserProfile?> _controller;

  final Map<String, _StoredAccount> _accounts = {};
  UserProfile? _currentUser;

  void _seedDemoAccount() {
    final normalized = demoEmail.toLowerCase();
    _accounts[normalized] = _StoredAccount(
      password: demoPassword,
      profile: UserProfile(
        id: 'user_demo_marprom',
        email: normalized,
        name: 'Ana Kovač',
        dateOfBirth: DateTime(1995, 5, 14),
        preferredLocaleCode: 'sl',
        guardianConfirmed: false,
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
    final normalized = email.trim().toLowerCase();
    var account = _accounts[normalized];

    if (account == null) {
      final raw = await _store.read('acct_$normalized');
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        account = _StoredAccount(
          password: map['password'] as String,
          profile: UserProfile.fromJson(map['profile'] as Map),
        );
        _accounts[normalized] = account;
      }
    }

    if (account == null || account.password != password) {
      throw const AuthException(
        'invalid_credentials',
        'Invalid email or password.',
      );
    }

    _currentUser = account.profile;
    await _store.write('active_user', _currentUser!.toJson());
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
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@') || password.length < 4) {
      throw const AuthException(
        'invalid_input',
        'Valid email and password (min 4 characters) are required.',
      );
    }
    if (_accounts.containsKey(normalized) ||
        await _store.read('acct_$normalized') != null) {
      throw const AuthException(
        'email_already_exists',
        'An account with this email already exists.',
      );
    }

    final now = DateTime.now();
    final profile = UserProfile(
      id: 'user_${now.microsecondsSinceEpoch}',
      email: normalized,
      name: name.trim(),
      dateOfBirth: dateOfBirth,
      preferredLocaleCode: preferredLocaleCode,
      guardianConfirmed: guardianConfirmed,
      createdAt: now,
    );
    final record = _StoredAccount(password: password, profile: profile);
    _accounts[normalized] = record;
    await _store.write('acct_$normalized', {
      'password': password,
      'profile': profile.toJson(),
    });
    _currentUser = profile;
    await _store.write('active_user', profile.toJson());
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
    final firebaseIdentity = await GoogleAuthBridge.authenticate();
    final resolvedEmail =
        (firebaseIdentity?.email ?? googleEmail ?? 'potnik.maribor@gmail.com')
            .trim()
            .toLowerCase();
    final resolvedName = firebaseIdentity?.displayName ??
        googleDisplayName ??
        'Luka Maribor (Google)';
    final resolvedId = firebaseIdentity?.uid ??
        'google_${resolvedEmail.hashCode.abs()}';

    final profile = UserProfile(
      id: resolvedId,
      email: resolvedEmail,
      name: resolvedName,
      preferredLocaleCode: preferredLocaleCode,
      photoUrl: firebaseIdentity?.photoUrl ?? photoUrl,
      authProvider: 'google',
      createdAt: DateTime.now(),
    );

    _accounts[resolvedEmail] = _StoredAccount(
      password: demoPassword,
      profile: profile,
    );
    await _store.write('acct_$resolvedEmail', {
      'password': demoPassword,
      'profile': profile.toJson(),
    });
    _currentUser = profile;
    await _store.write('active_user', profile.toJson());
    _emit(profile);
    return profile;
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
    final normalized = email.trim().toLowerCase();
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
  Future<UserProfile> updateProfile(UserProfile updated) async {
    final normalized = updated.email.trim().toLowerCase();
    final existing = _accounts[normalized];
    final password = existing?.password ?? demoPassword;
    _accounts[normalized] =
        _StoredAccount(password: password, profile: updated);
    await _store.write('acct_$normalized', {
      'password': password,
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

class _StoredAccount {
  const _StoredAccount({
    required this.password,
    required this.profile,
  });

  final String password;
  final UserProfile profile;
}
