import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/features/pdf/pdf_text.dart';

/// Two lines of text: "Hello world" on the first, "Second line" on the
/// second, each character 0.04 wide.
PageText _page() {
  const String a = 'Hello world', b = 'Second line';
  final List<Rect> rects = <Rect>[
    for (int i = 0; i < a.length; i++) Rect.fromLTWH(0.1 + i * 0.04, 0.10, 0.04, 0.03),
    Rect.zero, // the line break PDFium inserts
    for (int i = 0; i < b.length; i++) Rect.fromLTWH(0.1 + i * 0.04, 0.20, 0.04, 0.03),
  ];
  return PageText('$a\n$b', rects);
}

void main() {
  test('nearest finds the character under a point', () {
    final PageText t = _page();
    expect(t.nearest(const Offset(0.1 + 0.04 * 2 + 0.01, 0.11)), 2); // the first l
    expect(t.nearest(const Offset(0.1 + 0.04 * 3 + 0.01, 0.21)), 12 + 3); // the o of Second
  });

  test('nearest clamps past the text: left, right, above, below, between lines', () {
    final PageText t = _page();
    expect(t.nearest(const Offset(0.0, 0.11)), 0);
    expect(t.nearest(const Offset(0.95, 0.11)), 10); // the d of world
    expect(t.nearest(const Offset(0.3, 0.0)), t.nearest(const Offset(0.3, 0.11)));
    expect(t.nearest(const Offset(0.95, 0.9)), 22); // the last e
    // Nearer the second line than the first.
    expect(t.nearest(const Offset(0.1, 0.185)), 12);
  });

  test('nearest skips spaces and empty boxes, and is -1 on a page with no text', () {
    final PageText t = _page();
    // The space between the words is a whitespace character: the nearest
    // letter wins instead.
    final int i = t.nearest(const Offset(0.1 + 0.04 * 5 + 0.02, 0.11));
    expect(i == 4 || i == 6, isTrue);
    expect(PageText('', const <Rect>[]).nearest(const Offset(0.5, 0.5)), -1);
  });

  test('a dragged selection runs from the word to the finger, either way', () {
    expect(PageText.extend((6, 11), 15), (6, 16)); // forwards
    expect(PageText.extend((6, 11), 2), (2, 11)); // backwards keeps the word
    expect(PageText.extend((6, 11), 8), (6, 11)); // inside the word
  });
}
