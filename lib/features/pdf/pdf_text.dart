import 'dart:math' as math;
import 'dart:ui';

import 'package:pdfrx/pdfrx.dart';

/// One page's text with a rectangle per character, as fractions of the page
/// (0..1, top down), loaded on demand and cached. Selection, highlights,
/// search and the reflow all read from here.
class PageText {
  PageText(this.text, this.rects);

  static Future<PageText> load(PdfPage page) async {
    final PdfPageRawText? raw = await page.loadText();
    if (raw == null) return PageText('', const <Rect>[]);
    final double w = page.width, h = page.height;
    return PageText(raw.fullText, <Rect>[
      for (final PdfRect r in raw.charRects) Rect.fromLTRB(r.left / w, 1 - r.top / h, r.right / w, 1 - r.bottom / h),
    ]);
  }

  final String text;
  final List<Rect> rects;

  bool get isEmpty => text.trim().isEmpty;

  /// The character index nearest to a page point (0..1), on the same line.
  int? indexAt(Offset p) {
    int? best;
    double bestD = double.infinity;
    for (int i = 0; i < rects.length && i < text.length; i++) {
      final Rect r = rects[i];
      if (r.isEmpty || text[i].trim().isEmpty) continue;
      if (r.inflate(0.004).contains(p)) return i;
      final double dy = p.dy < r.top ? r.top - p.dy : (p.dy > r.bottom ? p.dy - r.bottom : 0);
      final double dx = p.dx < r.left ? r.left - p.dx : (p.dx > r.right ? p.dx - r.right : 0);
      final double d = dy * 4 + dx;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return bestD < 0.06 ? best : null;
  }

  /// The word around [i].
  (int, int) wordAt(int i) {
    final RegExp w = RegExp(r"[\p{L}\p{N}’'-]", unicode: true);
    int a = i, b = i;
    while (a > 0 && w.hasMatch(text[a - 1])) {
      a--;
    }
    while (b < text.length && w.hasMatch(text[b])) {
      b++;
    }
    return (a, math.max(b, a + 1));
  }

  /// Line rectangles covering [a, b), merged per line.
  List<Rect> boxes(int a, int b) {
    final List<Rect> out = <Rect>[];
    Rect? line;
    for (int i = math.max(0, a); i < math.min(b, rects.length); i++) {
      final Rect r = rects[i];
      if (r.isEmpty) continue;
      if (line != null && (r.center.dy - line.center.dy).abs() < line.height * 0.6 && r.left >= line.left - 0.01) {
        line = line.expandToInclude(r);
      } else {
        if (line != null) out.add(line);
        line = r;
      }
    }
    if (line != null) out.add(line);
    return out;
  }

  /// The first character whose line sits at or below [y] (0..1): the anchor
  /// for "where I am" on a page scrolled part-way.
  int firstAtOrBelow(double y) {
    for (int i = 0; i < rects.length && i < text.length; i++) {
      if (!rects[i].isEmpty && text[i].trim().isNotEmpty && rects[i].top >= y - 0.002) return i;
    }
    return 0;
  }
}
