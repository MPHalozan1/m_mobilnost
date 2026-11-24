// Safe Firebase bootstrap, Google Account Sign-In bridge (Web popup + Mobile 7.x), and Google G button.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../maps/google_web_views.dart';
import 'firebase_options.dart';

/// Holds authenticated identity fields returned by Google / Firebase Auth.
@immutable
class GoogleIdentityResult {
  /// Creates a [GoogleIdentityResult].
  const GoogleIdentityResult({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  /// Firebase or provider user ID.
  final String uid;

  /// Verified Google email address.
  final String email;

  /// Google display name.
  final String displayName;

  /// Optional avatar photo URL.
  final String? photoUrl;
}

/// Initializes Firebase when configured via build defines, while allowing
/// local offline/mock execution cleanly before Firebase project provisioning.
abstract final class FirebaseBootstrap {
  static bool _isReady = false;

  /// True when a Firebase App instance is initialized and live auth is active.
  static bool get isReady => _isReady && Firebase.apps.isNotEmpty;

  /// Attempts to initialize Firebase safely at app startup.
  static Future<bool> tryInitialize() async {
    if (isFlutterTestEnvironment) {
      _isReady = false;
      return false;
    }

    try {
      if (Firebase.apps.isNotEmpty) {
        _isReady = true;
        return true;
      }

      if (FirebaseEnvOptions.isConfigured) {
        await Firebase.initializeApp(
          options: FirebaseEnvOptions.currentPlatform,
        );
        _isReady = true;
        return true;
      }

      // On Android/iOS with google-services.json / GoogleService-Info.plist bundled,
      // parameterless initializeApp() picks up native resources automatically.
      if (!kIsWeb) {
        await Firebase.initializeApp();
        _isReady = Firebase.apps.isNotEmpty;
        return _isReady;
      }
    } catch (_) {
      _isReady = false;
    }
    return false;
  }
}

/// Executes Google Account authentication using `FirebaseAuth.signInWithPopup`
/// on Web (avoiding `google_sign_in` Web client-id hangs) and `GoogleSignIn.instance.authenticate()`
/// on Android/iOS when Firebase is configured.
abstract final class GoogleAuthBridge {
  static bool _mobileGoogleSignInInitialized = false;

  /// Signs in via Google OAuth when Firebase is configured, or returns `null` when
  /// running in local/preview mode so `AuthRepository` falls back to preview Google sign-in.
  static Future<GoogleIdentityResult?> authenticate() async {
    if (!FirebaseBootstrap.isReady) {
      return null;
    }

    final auth = FirebaseAuth.instance;
    if (kIsWeb) {
      final credential = await auth.signInWithPopup(GoogleAuthProvider());
      final user = credential.user;
      if (user == null || user.email == null) return null;
      return GoogleIdentityResult(
        uid: user.uid,
        email: user.email!,
        displayName: user.displayName ?? 'Marprom Google Uporabnik',
        photoUrl: user.photoURL,
      );
    }

    if (!_mobileGoogleSignInInitialized) {
      await GoogleSignIn.instance.initialize();
      _mobileGoogleSignInInitialized = true;
    }
    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCred = await auth.signInWithCredential(credential);
    final user = userCred.user;
    if (user == null) return null;
    return GoogleIdentityResult(
      uid: user.uid,
      email: user.email ?? googleUser.email,
      displayName: user.displayName ?? googleUser.displayName ?? 'Marprom Rider',
      photoUrl: user.photoURL ?? googleUser.photoUrl,
    );
  }

  /// Signs out from FirebaseAuth (and native GoogleSignIn on mobile only; skipped on Web).
  static Future<void> signOut() async {
    if (!FirebaseBootstrap.isReady) return;
    try {
      if (!kIsWeb && _mobileGoogleSignInInitialized) {
        await GoogleSignIn.instance.signOut();
      }
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Ignore sign-out errors during cleanup/deleteAccount.
    }
  }
}

/// Official styled "Continue with Google" button featuring a multi-color vector G emblem.
class GoogleSignInButton extends StatelessWidget {
  /// Creates a [GoogleSignInButton].
  const GoogleSignInButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.compact = false,
  });

  /// Button text label.
  final String label;

  /// Callback when tapped.
  final VoidCallback? onPressed;

  /// Shows loading indicator instead of icon while signing in.
  final bool loading;

  /// Compact mode for top web header navigation bar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        minimumSize: Size(compact ? 44 : double.infinity, compact ? 40 : 54),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18,
          vertical: compact ? 8 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 10 : 14),
        ),
      ),
      onPressed: loading ? null : onPressed,
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const _GoogleGEmblem(size: 18),
          SizedBox(width: compact ? 8 : 12),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: compact ? 12.5 : 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleGEmblem extends StatelessWidget {
  const _GoogleGEmblem({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GoogleGPainter(),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.20;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Red top arc
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.55, 1.85, false, paint);
    // Yellow left arc
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.35, 1.38, false, paint);
    // Green bottom arc
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.72, 1.63, false, paint);
    // Blue right arc
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.08, 0.85, false, paint);

    // Blue horizontal crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.50,
        size.height * 0.41,
        size.width * 0.45,
        stroke,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
