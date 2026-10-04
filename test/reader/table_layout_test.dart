import 'package:flutter/material.dart' hide TableCell;
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/core/theme/reading_theme.dart';
import 'package:unfurl/features/reader/engine/layout.dart';
import 'package:unfurl/features/reader/engine/reader_style.dart';
import 'package:unfurl/features/reader/reading_prefs.dart';
import 'package:unfurl/formats/reading_document.dart';

List<ReaderPage> pagesOf(List<List<String>> rows, double width, {double height = 800}) {
  final ReadingDocument doc = ReadingDocument(
    title: 't',
    sections: <Section>[
      Section(
        title: '',
        blocks: <Block>[Block(kind: BlockKind.table, rows: rows)],
      ),
    ],
  );
  final Layout l = Layout(
    doc: doc,
    style: ReaderStyle.of(const ReadingPrefs(), ReadingTheme.of(ThemeFamily.saffron, ReadingThemeId.light), book: true),
    pageSize: Size(width, height),
    images: ImageSizes(),
  );
  l.ensure(0);
  return l.sections[0]!;
}

Fragment tableOn(List<List<String>> rows, double width) => pagesOf(rows, width).first.fragments.single;

void main() {
  test('a table that fits keeps to the page and breaks no word', () {
    final Fragment f = tableOn(<List<String>>[
      <String>['Name', 'Qty'],
      <String>['Apples', '3'],
    ], 320);
    expect(f.rect.width, 320);
    expect(f.scroll, isNull);
    for (final TableCell c in f.cells!) {
      expect(c.painter.computeLineMetrics().length, 1, reason: '"${c.painter.plainText}" on one line');
    }
  });

  test('a table wider than the page scrolls sideways, and hit tests follow the scroll', () {
    const String word = 'Internationalisation';
    final Fragment f = tableOn(<List<String>>[
      <String>[for (int i = 0; i < 6; i++) '$word$i'],
      <String>[for (int i = 0; i < 6; i++) 'cell$i'],
    ], 320);
    expect(f.rect.width, greaterThan(320));
    expect(f.scroll, isNotNull);
    final TableCell last = f.cells!.lastWhere((TableCell c) => c.painter.plainText == 'cell5');
    final Offset onLast = f.rect.topLeft + last.rect.center;
    expect(onLast.dx, greaterThan(320), reason: 'off the page until scrolled');
    f.scroll!.value = f.rect.width - 320;
    final int? at = f.offsetAt(onLast - Offset(f.scroll!.value, 0));
    expect(at, inInclusiveRange(last.start, last.end));
    expect(f.boxes(last.start, last.end).single.left, lessThan(320));
  });

  test('a table longer than a page carries on over the next pages, never on top of itself', () {
    final List<ReaderPage> pages = pagesOf(
      <List<String>>[
        for (int i = 0; i < 60; i++) <String>['Row $i', 'value'],
      ],
      320,
      height: 300,
    );
    expect(pages.length, greaterThan(2));
    for (final ReaderPage p in pages) {
      expect(p.fragments.length, 1, reason: 'one run of rows per page');
    }
    expect(
      pages.map((ReaderPage p) => p.fragments.single.rowStart),
      orderedEquals(<int>[...pages.map((ReaderPage p) => p.fragments.single.rowStart)]..sort()),
    );
    expect(pages.last.fragments.single.rowEnd, 60);
  });

  test('a table header never sits alone at the foot of a page', () {
    // A paragraph fills most of a short page; the table's header fits under
    // it but its first row doesn't.
    final ReadingDocument doc = ReadingDocument(
      title: 't',
      sections: <Section>[
        Section(
          title: '',
          blocks: <Block>[
            Block(kind: BlockKind.paragraph, runs: <Inline>[Inline('word ' * 60)]),
            Block(
              kind: BlockKind.table,
              rows: <List<String>>[
                <String>['Book', 'Pages'],
                for (int i = 0; i < 6; i++) <String>['Title $i', '$i'],
              ],
            ),
          ],
        ),
      ],
    );
    for (double h = 200; h < 600; h += 7) {
      final Layout l = Layout(
        doc: doc,
        style: ReaderStyle.of(
          const ReadingPrefs(),
          ReadingTheme.of(ThemeFamily.saffron, ReadingThemeId.light),
          book: true,
        ),
        pageSize: Size(320, h),
        images: ImageSizes(),
      );
      l.ensure(0);
      for (final ReaderPage p in l.sections[0]!) {
        for (final Fragment f in p.fragments.where((Fragment f) => f.block.kind == BlockKind.table)) {
          expect(f.rowEnd - f.rowStart > 1 || f.rowStart > 0, isTrue, reason: 'header alone at height $h');
        }
      }
    }
  });
}
