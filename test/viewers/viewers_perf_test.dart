// App polish 2, viewers: DOCX pagination in slices, a windowed sheet grid, plain empty strings in Insights,
// thumbnails that press.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/motion/pressable.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/features/comics/comic_pages.dart';
import 'package:unfurl/features/comics/comic_views.dart';
import 'package:unfurl/features/office/sheet_screen.dart';
import 'package:unfurl/formats/comics/comic_archive.dart';
import 'package:unfurl/formats/office/docx.dart';
import 'package:unfurl/formats/office/sheets.dart';

import '../ui/insights_test.dart' as ins;

const String _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

Docx _bigDocx(int paragraphs) {
  final StringBuffer body = StringBuffer();
  for (int i = 0; i < paragraphs; i++) {
    // Every 97th empty, every 211th a hard page break, lengths vary so pages differ.
    final String text = i % 97 == 0 ? '' : 'Paragraph $i ${'lorem ipsum ' * (3 + i % 23)}';
    final String ppr = i % 211 == 0 && i > 0 ? '<w:pageBreakBefore/>' : '';
    body.write('<w:p><w:pPr>$ppr</w:pPr><w:r><w:t xml:space="preserve">$text</w:t></w:r></w:p>');
  }
  final Archive a = Archive();
  final List<int> doc = utf8.encode(
    '<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="$_w"><w:body>$body'
    '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:bottom="1440" w:left="1440" w:right="1440"/>'
    '</w:sectPr></w:body></w:document>',
  );
  a.addFile(ArchiveFile('word/document.xml', doc.length, doc));
  return Docx.parse(Uint8List.fromList(ZipEncoder().encode(a)));
}

class _FakeArchive implements ComicArchive {
  _FakeArchive(this.pages);

  @override
  final List<String> pages;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePages extends ComicPages {
  _FakePages() : super(_FakeArchive(<String>[for (int i = 0; i < 20; i++) '$i.jpg']), 'fp');

  @override
  Future<File?> thumb(int i) => SynchronousFuture<File?>(null);

  @override
  File? thumbNow(int i) => null;
}

void main() {
  test('DOCX: a slice lays out far fewer paragraphs than all, and the result equals a full docxPages run', () {
    final Docx d = _bigDocx(1500);
    int measured = 0;
    // A deterministic height standing in for TextPainter, so the check is about the slicing.
    double height(DocxItem it) {
      measured++;
      return 14.0 * (1 + it.text.length / 80).ceil() + it.spaceAfter;
    }

    final DocxPaginator p = DocxPaginator(d, 600, height);
    p.run(Duration.zero);
    expect(p.done, isFalse);
    expect(p.laid, lessThan(100));
    expect(measured, p.laid);
    int slices = 1;
    while (!p.run(Duration.zero)) {
      slices++;
    }
    expect(slices, greaterThan(10));
    expect(measured, 1500);
    expect(p.done, isTrue);
    expect(p.pages, docxPages(d, 600, height));
  });

  testWidgets('sheet: 6,000 x 20 lays out only the cells on screen, before and after a scroll', (WidgetTester t) async {
    final SheetData sheet = SheetData('Big', <List<String>>[
      for (int r = 0; r < 6000; r++) <String>[for (int c = 0; c < 20; c++) 'r$r c$c'],
    ]);
    final GlobalKey<SheetGridState> key = GlobalKey<SheetGridState>();
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
        home: Scaffold(
          body: SheetGrid(key: key, sheet: sheet, selected: null, hits: const <(int, int)>{}, onSelect: (_, _) {}),
        ),
      ),
    );
    final int first = key.currentState!.laidOutCells;
    expect(first, greaterThan(0));
    expect(first, lessThan(2000));
    for (int i = 0; i < 6; i++) {
      await t.drag(find.byType(SheetGrid), const Offset(-120, -700));
      await t.pump();
    }
    await t.pump(const Duration(seconds: 5));
    expect(key.currentState!.laidOutCells, lessThan(2000));
    expect(key.currentState!.laidOutCells, greaterThan(0));
  });

  testWidgets('comics: scrubber thumbnails press', (WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
        home: Scaffold(
          body: ComicScrubber(pages: _FakePages(), page: 3, rtl: false, onJump: (_) {}),
        ),
      ),
    );
    expect(find.byType(Pressable), findsWidgets);
    expect(find.descendant(of: find.byType(Pressable), matching: find.text('4')), findsOneWidget);
  });

  testWidgets('Insights: empty tiles say "None yet", never an em dash, at text scale 2', (WidgetTester t) async {
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final void Function(FlutterErrorDetails)? old = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails d) => debugPrint(d.toString());
    addTearDown(() => FlutterError.onError = old);
    await ins.pumpInsights(
      t,
      seed: (db) async {
        await ins.day(db, DateTime(2026, 10, 2), 18);
        await ins.day(db, ins.today, 19);
      },
    );
    expect(find.text('None yet'), findsWidgets);
    expect(find.textContaining('—'), findsNothing);
    final Object? ex = t.takeException();
    if (ex != null) debugPrint((ex as FlutterError).toStringDeep());
    expect(ex, isNull);
  });
}
