// Renders the legacy launcher PNGs (Android 7.x, before adaptive icons) and
// the 512px store icon from concept 1d, the same shapes as tool/make_icon.py.
// Run: flutter test tool/make_icon_png.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const Color primary = Color(0xFFA15800), surface = Color(0xFFFEFBF9);
const Color outline = Color(0xFFDED8D1), container = Color(0xFFFFDDC0);

/// The board's 144px artboard, scaled to [size].
Future<List<int>> render(int size, {required bool shaped}) async {
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final Canvas c = Canvas(rec)..scale(size / 144);
  final RRect field = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 144, 144), const Radius.circular(34));
  if (shaped) {
    c.clipRRect(field);
  }
  c.drawRect(const Rect.fromLTWH(0, 0, 144, 144), Paint()..color = primary);
  void tilted(Offset centre, void Function() draw) {
    c
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(-6 * math.pi / 180)
      ..translate(-centre.dx, -centre.dy);
    draw();
    c.restore();
  }

  tilted(const Offset(72, 66), () {
    c.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(36, 26, 72, 80),
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
      Paint()..color = surface,
    );
    for (final (int i, double w, Color colour) in <(int, double, Color)>[
      (0, 0.62, primary),
      (1, 1.0, outline),
      (2, 0.8, outline),
    ]) {
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(49, 43 + i * 17.0, 46 * w, 8), const Radius.circular(4)),
        Paint()..color = colour,
      );
    }
  });
  tilted(const Offset(73, 110), () {
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(28, 100, 90, 20), const Radius.circular(10)),
      Paint()..color = container,
    );
  });
  final ui.Image image = await rec.endRecording().toImage(size, size);
  final List<int> png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  image.dispose();
  return png;
}

void main() {
  test('write launcher PNGs', () async {
    const String res = 'android/app/src/main/res';
    for (final (String density, int px) in <(String, int)>[
      ('mdpi', 48),
      ('hdpi', 72),
      ('xhdpi', 96),
      ('xxhdpi', 144),
      ('xxxhdpi', 192),
    ]) {
      File('$res/mipmap-$density/ic_launcher.png').writeAsBytesSync(await render(px, shaped: true));
    }
    // Play listing: square, the store applies its own mask.
    File('android/app/src/main/ic_launcher-playstore.png').writeAsBytesSync(await render(512, shaped: false));
  });
}
