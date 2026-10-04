import 'dart:ui';

/// The launcher icon (v2 · V2-ICON, concept C "Bookmarked U", the owner's
/// pick over the board's A), from `specs/design/unfurl-icon-v2.js`. Authored
/// on a 512 square, which is the 72dp adaptive viewport. Its ochre is the
/// icon's own and separate from the Saffron accent. `tool/make_icon.dart`
/// writes every Android asset from this.
abstract final class LauncherIcon {
  static const Color background = Color(0xFFF8E5C7);
  static const Color deep = Color(0xFF663D12);
  static const Color mid = Color(0xFFB2782C);

  /// Round-capped strokes, 52 on 512; the ribbon's outline is 10.
  static const double stroke = 52;
  static const double ribbonStroke = 10;

  /// The themed (monochrome) icon draws the mid stroke at this alpha.
  static const double monoMidAlpha = 0.62;

  /// In paint order: the mid stroke over the deep one, then the bookmark.
  static const List<GlyphLayer> layers = <GlyphLayer>[
    GlyphLayer(deep, 'M179 136 V300 A60 60 0 0 0 239 360'),
    GlyphLayer(mid, 'M239 360 A60 60 0 0 0 299 300 V136'),
    GlyphLayer(deep, 'M330 140 H352 V206 L341 194 L330 206 Z', filled: true),
  ];

  /// Draws the glyph (no background) into a 512 square scaled to [size].
  /// [mono] paints every layer in that colour, the mid stroke at
  /// [monoMidAlpha].
  static void paint(Canvas canvas, double size, {Color? mono}) {
    canvas
      ..save()
      ..scale(size / 512);
    for (final GlyphLayer l in layers) {
      final Color colour = mono == null
          ? l.colour
          : (l.colour == mid ? mono.withValues(alpha: mono.a * monoMidAlpha) : mono);
      final Paint p = Paint()
        ..color = colour
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.filled ? ribbonStroke : stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final Path path = l.path;
      if (l.filled) canvas.drawPath(path, Paint()..color = colour);
      canvas.drawPath(path, p);
    }
    canvas.restore();
  }
}

class GlyphLayer {
  const GlyphLayer(this.colour, this.d, {this.filled = false});

  final Color colour;

  /// SVG path data, using only M, H, V, L, A and Z (absolute).
  final String d;
  final bool filled;

  Path get path {
    final Path p = Path();
    final List<String> t = d
        .replaceAllMapped(RegExp('([A-Za-z])'), (Match m) => ' ${m[1]} ')
        .trim()
        .split(RegExp(r'\s+'));
    double x = 0, y = 0;
    int i = 0;
    double n() => double.parse(t[i++]);
    while (i < t.length) {
      switch (t[i++]) {
        case 'M':
          p.moveTo(x = n(), y = n());
        case 'L':
          p.lineTo(x = n(), y = n());
        case 'H':
          p.lineTo(x = n(), y);
        case 'V':
          p.lineTo(x, y = n());
        case 'A':
          final double rx = n(), ry = n(), rotation = n(), large = n(), sweep = n();
          p.arcToPoint(
            Offset(x = n(), y = n()),
            radius: Radius.elliptical(rx, ry),
            rotation: rotation,
            largeArc: large == 1,
            clockwise: sweep == 1,
          );
        case 'Z':
          p.close();
      }
    }
    return p;
  }
}
