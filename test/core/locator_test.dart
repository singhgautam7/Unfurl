import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/files.dart';
import 'package:unfurl/core/locator.dart';
import 'package:unfurl/formats/reading_document.dart';
import 'package:unfurl/formats/text/text_formats.dart';

ReadingDocument doc(String text) => TextFormats.plain(Uint8List.fromList(utf8.encode(text)), 'notes.txt');

void main() {
  const String text =
      'It is a truth universally acknowledged.\n\nHowever little known the feelings of such a man may be.\n\n'
      'My dear Mr. Bennet, have you heard that Netherfield Park is let at last?';

  test('a locator survives JSON and resolves to its own place', () {
    final ReadingDocument d = doc(text);
    final (int s, int b, int o) = d.positionOfIndex(d.plainText.indexOf('Netherfield'));
    final Locator l = Locator.fromJson(Locator.inDocument(d, s, b, o, length: 11).toJson());
    expect(l.exact, 'Netherfield');
    expect(l.resolveIn(d), (s, b, o));
  });

  test('when the text moves, the quote finds the place again', () {
    final ReadingDocument before = doc(text);
    final (int s, int b, int o) = before.positionOfIndex(before.plainText.indexOf('Netherfield'));
    final Locator l = Locator.inDocument(before, s, b, o, length: 11);
    // A paragraph added above shifts every block and offset.
    final ReadingDocument after = doc('A new preface paragraph.\n\n$text');
    final (int s2, int b2, int o2) = l.resolveIn(after);
    final Block block = after.sections[s2].blocks[b2];
    expect(block.text.substring(o2, o2 + 11), 'Netherfield');
  });

  test('a PDF page locator re-anchors when the page text is re-extracted', () {
    const String page = 'alpha beta gamma delta epsilon';
    final Locator l = Locator.inPage(3, page, page.indexOf('gamma'), length: 5);
    expect(l.resolveInPages(<String>['', '', page]), (3, page.indexOf('gamma')));
    // Extraction joins lines differently; the quote still lands.
    const String again = 'alpha  beta\ngamma delta epsilon';
    expect(l.resolveInPages(<String>['', '', again]), (3, again.indexOf('gamma')));
  });

  test('the fingerprint reads size, head and tail, and nothing else', () {
    final Uint8List a = Uint8List.fromList(List<int>.generate(200000, (int i) => i % 251));
    final Uint8List b = Uint8List.fromList(a)..[100000] = 7; // a change in the middle
    final Uint8List c = Uint8List.fromList(a)..[10] = 7; // a change in the head
    String fp(Uint8List x) =>
        Files.fingerprintOf(x.length, (int at, int n) => x.sublist(at, (at + n).clamp(0, x.length)));
    expect(fp(a), fp(Uint8List.fromList(a)));
    expect(fp(b), fp(a), reason: 'the middle is not hashed, by design');
    expect(fp(c), isNot(fp(a)));
  });

  test('a page position maps to the nearest block before it, pictures included', () {
    // Page 2's text: a paragraph at 0..40, a table picture anchored at 50,
    // a paragraph at 120.
    final ReadingDocument d = ReadingDocument(
      title: 't',
      sections: <Section>[
        Section(
          title: '',
          blocks: <Block>[
            Block(
              kind: BlockKind.paragraph,
              runs: const <Inline>[Inline('first')],
              source: SourceRef(page: 2, charMap: <int>[for (int i = 0; i < 5; i++) 2 * SourceRef.kPage + i]),
            ),
            Block(kind: BlockKind.image, image: 'p2r0', source: const SourceRef(page: 2, start: 50, end: 50)),
            Block(
              kind: BlockKind.paragraph,
              runs: const <Inline>[Inline('after')],
              source: SourceRef(page: 2, charMap: <int>[for (int i = 120; i < 125; i++) 2 * SourceRef.kPage + i]),
            ),
          ],
        ),
      ],
    );
    expect(const Locator(page: 2, pageStart: 70).resolveIn(d), (0, 1, 0), reason: 'a cell of the table');
    expect(const Locator(page: 2, pageStart: 122).resolveIn(d), (0, 2, 2));
    expect(const Locator(page: 2, pageStart: 3).resolveIn(d), (0, 0, 3));
  });
}
