import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/features/pdf/pdf_render.dart';

/// A BGRA page of [w] x [h], white, with [paint] applied.
Uint8List page(int w, int h, void Function(Uint8List px, int x, int y) paint) {
  final Uint8List px = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 255);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      paint(px, x, y);
    }
  }
  return px;
}

void grey(Uint8List px, int i, int v) => px
  ..[i] = v
  ..[i + 1] = v
  ..[i + 2] = v;

void main() {
  const int w = 320, h = 320, paper = 0xFF1E2731, ink = 0xFFD7DFE5;
  int at(int x, int y) => (y * w + x) * 4;

  test('a line of small grey text is recoloured, not kept as a photo', () {
    // A 12px band of mid-grey "anti-aliased text" across the page.
    final Uint8List px = page(w, h, (Uint8List p, int x, int y) {
      if (y >= 100 && y < 112 && x >= 20 && x < 300) grey(p, at(x, y), 128);
    });
    final Uint8List out = PageRenderer.recolour(px, w, h, paper, ink);
    expect(out[at(150, 106) + 2], isNot(128), reason: 'the text band takes the reading colours');
    expect(out[at(5, 5) + 2], (paper >> 16) & 0xFF, reason: 'white paper becomes the theme paper');
  });

  test('a picture keeps its own colours', () {
    // A 120px block of colour, as a photo would be.
    final Uint8List px = page(w, h, (Uint8List p, int x, int y) {
      if (y >= 100 && y < 220 && x >= 100 && x < 220) {
        p[at(x, y)] = 40; // b
        p[at(x, y) + 1] = 160; // g
        p[at(x, y) + 2] = 200; // r
      }
    });
    final Uint8List out = PageRenderer.recolour(px, w, h, paper, ink);
    expect(<int>[out[at(160, 160)], out[at(160, 160) + 1], out[at(160, 160) + 2]], <int>[40, 160, 200]);
  });
}
