// Initializes Firebase, Hive, SharedPreferences, and Riverpod ProviderScope for M Mobilnost 2.0.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/accessibility/a11y_settings.dart';
import 'core/firebase/firebase_bootstrap.dart';

/// Application entry point initializing Firebase, local storage, and [MMobilnostApp].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseBootstrap.tryInitialize();

  try {
    await Hive.initFlutter();
  } catch (_) {
    // Allow app startup even if local Hive storage initialization fails.
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MMobilnostApp(),
    ),
  );
}
