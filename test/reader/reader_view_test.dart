import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/core/theme/reading_theme.dart';
import 'package:unfurl/features/reader/engine/layout.dart';
import 'package:unfurl/features/reader/engine/reader_style.dart';
import 'package:unfurl/features/reader/engine/reader_view.dart';
import 'package:unfurl/features/reader/reading_prefs.dart';
import 'package:unfurl/formats/reading_document.dart';

/// Global index of the last character on screen.
int lastIndex(ReaderController c) => c.doc.sections[c.lastVisible.$1].blocks[c.lastVisible.$2].start + c.lastVisible.$3;

ReaderController book() => ReaderController(
  ReadingDocument(
    title: 't',
    sections: <Section>[
      Section(
        title: '',
        blocks: <Block>[
          for (int i = 0; i < 60; i++)
            Block(
              kind: BlockKind.paragraph,
              runs: <Inline>[Inline('Paragraph $i. ${'The quick brown fox jumps over the lazy dog. ' * 6}')],
            ),
        ],
      ),
    ],
  ),
);

Widget view(ReaderController c, {ReaderLayout layout = ReaderLayout.paged}) => MaterialApp(
  home: ReaderView(
    controller: c,
    style: ReaderStyle.of(
      const ReadingPrefs(pageTurn: PageTurn.none),
      ReadingTheme.of(ThemeFamily.saffron, ReadingThemeId.light),
      book: true,
    ),
    layoutMode: layout,
    pageTurn: PageTurn.none,
    onCentreTap: () {},
    onLink: (_) {},
    onMarkTap: (_, _) {},
    onSelection: (_) {},
    onFontStep: (_) {},
  ),
);

void main() {
  testWidgets('turning the window there and back returns to the same page', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.reset);
    final ReaderController c = book();
    await tester.pumpWidget(view(c));
    await tester.pumpAndSettle();
    for (int i = 0; i < 4; i++) {
      c.turn(1);
      await tester.pumpAndSettle();
    }
    final int place = c.globalIndex;
    for (int round = 0; round < 3; round++) {
      tester.view.physicalSize = const Size(860, 400);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(400, 860);
      await tester.pumpAndSettle();
    }
    expect(c.globalIndex, place);
    // A turn after that moves on from the page shown, as usual.
    c.turn(1);
    await tester.pumpAndSettle();
    expect(c.globalIndex, greaterThan(place));
  });

  testWidgets('switching Paged and Scroll keeps the passage', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.reset);
    final ReaderController c = book();
    await tester.pumpWidget(view(c));
    await tester.pumpAndSettle();
    for (int i = 0; i < 6; i++) {
      c.turn(1);
      await tester.pumpAndSettle();
    }
    final (int, int, int) place = c.position;
    await tester.pumpWidget(view(c, layout: ReaderLayout.scroll));
    await tester.pumpAndSettle();
    expect(c.position.$2, inInclusiveRange(place.$2 - 1, place.$2), reason: 'scroll opens on the paragraph read');
    await tester.drag(find.byType(ReaderView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    final (int, int, int) scrolled = c.position;
    expect(scrolled.$2, greaterThan(place.$2));
    await tester.pumpWidget(view(c));
    await tester.pumpAndSettle();
    final int at = c.doc.sections[0].blocks[scrolled.$2].start;
    expect(at, inInclusiveRange(c.globalIndex, lastIndex(c)), reason: 'paged opens on the page holding it');
  });

  test('scroll layout: a paragraph laid out alone still indents after a paragraph', () {
    Block para(String t) => Block(kind: BlockKind.paragraph, runs: <Inline>[Inline(t)]);
    double firstX(Block? before) {
      final Layout l = Layout(
        doc: ReadingDocument(
          title: 't',
          sections: <Section>[
            Section(title: '', blocks: <Block>[para('However little known the feelings.')]),
          ],
        ),
        style: ReaderStyle.of(
          const ReadingPrefs(),
          ReadingTheme.of(ThemeFamily.saffron, ReadingThemeId.light),
          book: true,
        ),
        pageSize: const Size(360, 100000),
        images: ImageSizes(),
        before: before,
      );
      l.ensure(0);
      final double x = l.sections[0]!.first.fragments.first.boxes(0, 1).first.left;
      l.dispose();
      return x;
    }

    expect(firstX(null), 0);
    expect(firstX(para('It is a truth universally acknowledged.')), greaterThan(10));
  });
}
