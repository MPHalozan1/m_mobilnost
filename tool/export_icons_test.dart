// Regenerates every app icon from MarpromLogoPainter.
//
// Run from the project root:
//   flutter test tool/export_icons_test.dart
//
// Lives outside test/ so the normal `flutter test` run does not rewrite icons.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_mobilnost/core/widgets/brand_logo.dart';

Future<void> _png(
  String path,
  int px,
  MarpromLogoPainter painter, {
  Color? fill,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (fill != null) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()),
      Paint()..color = fill,
    );
  }
  // Monochrome stops/pin eyes are punched out with BlendMode.clear, which
  // needs its own layer.
  canvas.saveLayer(Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()), Paint());
  painter.paint(canvas, Size(px.toDouble(), px.toDouble()));
  canvas.restore();
  final image = await recorder.endRecording().toImage(px, px);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('export icons', (tester) async {
    await tester.runAsync(() async {
      const res = 'android/app/src/main/res';
      const densities = {
        'mdpi': 1.0,
        'hdpi': 1.5,
        'xhdpi': 2.0,
        'xxhdpi': 3.0,
        'xxxhdpi': 4.0,
      };

      for (final entry in densities.entries) {
        final d = entry.value;
        final dir = '$res/mipmap-${entry.key}';
        final legacy = (48 * d).round();
        final adaptive = (108 * d).round();

        // Pre-Oreo launchers: complete icon.
        await _png(
          '$dir/ic_launcher.png',
          legacy,
          const MarpromLogoPainter(markScale: 0.86),
        );
        await _png(
          '$dir/ic_launcher_round.png',
          legacy,
          const MarpromLogoPainter(
            background: LogoBackground.circle,
            markScale: 0.8,
          ),
        );

        // Adaptive icon layers (108dp, content kept inside the 66dp safe zone).
        await _png(
          '$dir/ic_launcher_background.png',
          adaptive,
          const MarpromLogoPainter(background: LogoBackground.square)
              ._backgroundOnly(),
        );
        await _png(
          '$dir/ic_launcher_foreground.png',
          adaptive,
          const MarpromLogoPainter(
            background: LogoBackground.none,
            markScale: 0.6,
          ),
        );
        await _png(
          '$dir/ic_launcher_monochrome.png',
          adaptive,
          const MarpromLogoPainter(
            background: LogoBackground.none,
            markScale: 0.6,
            monochrome: true,
          ),
        );
      }

      // Web / PWA.
      await _png(
        'web/icons/Icon-192.png',
        192,
        const MarpromLogoPainter(markScale: 0.86),
      );
      await _png(
        'web/icons/Icon-512.png',
        512,
        const MarpromLogoPainter(markScale: 0.86),
      );
      await _png(
        'web/icons/Icon-maskable-192.png',
        192,
        const MarpromLogoPainter(
          background: LogoBackground.square,
          markScale: 0.72,
        ),
      );
      await _png(
        'web/icons/Icon-maskable-512.png',
        512,
        const MarpromLogoPainter(
          background: LogoBackground.square,
          markScale: 0.72,
        ),
      );
      await _png(
        'web/favicon.png',
        32,
        const MarpromLogoPainter(markScale: 0.9),
      );

      // iOS (must be opaque, full-bleed; iOS applies its own mask).
      const ios = {
        'Icon-App-1024x1024@1x.png': 1024,
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
      };
      for (final e in ios.entries) {
        await _png(
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/${e.key}',
          e.value,
          const MarpromLogoPainter(
            background: LogoBackground.square,
            markScale: 0.8,
          ),
          fill: const Color(0xFFC8102E),
        );
      }
    });
  });
}

extension on MarpromLogoPainter {
  /// Background layer only (mark scaled to zero).
  MarpromLogoPainter _backgroundOnly() => MarpromLogoPainter(
        background: background,
        markScale: 0,
      );
}
