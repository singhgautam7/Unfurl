import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/formats/epub/epub.dart';
import 'package:unfurl/formats/format_registry.dart';
import 'package:unfurl/formats/office/docx.dart';
import 'package:unfurl/formats/office/pptx.dart';
import 'package:unfurl/formats/office/sheets.dart';
import 'package:unfurl/formats/reading_document.dart';
import 'package:unfurl/formats/text/text_formats.dart';

Uint8List fixture(String name) => File('test/fixtures/$name').readAsBytesSync();

void main() {
  test('EPUB: metadata, cover, spine, nav and an internal link', () {
    final Epub epub = Epub.open(fixture('pride-and-prejudice.epub'));
    final BookMeta meta = epub.meta();
    expect(meta.title, 'Pride and Prejudice');
    expect(meta.author, 'Jane Austen');
    expect(meta.cover, isNotNull);
    final ReadingDocument doc = epub.document();
    expect(doc.sections, hasLength(3));
    expect(doc.toc.map((TocEntry t) => t.title), <String>['Chapter 1', 'Chapter 2', 'Chapter 3']);
    expect(doc.sections.first.blocks.first.kind, BlockKind.heading);
    expect(doc.plainText, contains('It is a truth universally acknowledged'));
    expect(doc.sections.first.blocks.any((Block b) => b.kind == BlockKind.image), isTrue);
    expect(doc.resources, isNotEmpty);
    final Inline link = doc.sections[1].blocks.expand((Block b) => b.runs).firstWhere((Inline r) => r.href != null);
    expect(doc.anchors[link.href], (0, 0));
    expect(doc.sections[1].blocks.any((Block b) => b.kind == BlockKind.quote), isTrue);
  });

  test('DOCX: headings, emphasis, a table, a list, page geometry', () {
    final Docx docx = Docx.parse(fixture('Thesis draft v4.docx'));
    expect(docx.title, 'Thesis draft v4');
    expect(docx.items.where((DocxItem i) => i.rows != null), hasLength(1));
    expect(docx.items.firstWhere((DocxItem i) => i.text == '2. Related work').heading, 1);
    expect(docx.items.expand((DocxItem i) => i.runs).any((DocxRun r) => r.bold && r.text == 'paged'), isTrue);
    expect(docx.pageWidth, greaterThan(500));
    final ReadingDocument doc = docx.toReading('Thesis draft v4.docx');
    expect(doc.sections.length, greaterThan(2));
    expect(doc.plainText, contains('Reading on small screens'));
    expect(doc.sections.expand((Section s) => s.blocks).where((Block b) => b.kind == BlockKind.listItem), hasLength(3));
  });

  test('PPTX: slides, titles, bullets, a picture, notes, outline', () {
    final Pptx pptx = Pptx.parse(fixture('Q3 review.pptx'));
    expect(pptx.slides, hasLength(5));
    expect(pptx.slides[2].title, 'Reader retention, Q3');
    expect(pptx.slides[2].shapes.any((SlideShape s) => s.image != null), isTrue);
    expect(pptx.slides[2].notes, 'Chart is 30-day retention by month.');
    expect(pptx.aspect, closeTo(16 / 9, 0.01));
    final ReadingDocument outline = pptx.toReading('Q3 review.pptx');
    expect(outline.sections, hasLength(5));
    expect(outline.sections[2].blocks[1].text, 'Reader retention, Q3');
  });

  test('Spreadsheets: XLSX with comments and formulas, XLS, ODS, CSV', () {
    final List<SheetData> xlsx = Sheets.parse(fixture('Household budget.xlsx'), 'xlsx');
    expect(xlsx.map((SheetData s) => s.name), <String>['2026', 'Savings', 'Notes']);
    expect(xlsx.first.cell(0, 3), 'Utilities');
    expect(xlsx.first.cell(1, 1), '1,240.00');
    expect(xlsx.first.comments[(6, 3)], contains('Boiler'));
    expect(xlsx[1].rows.length, 399);

    final List<SheetData> xls = Sheets.parse(fixture('Budget 2025.xls'), 'xls');
    expect(xls.single.name, '2025');
    expect(xls.single.cell(0, 2), 'Groceries');
    expect(xls.single.cell(2, 2), '398.75');

    final List<SheetData> ods = Sheets.parse(fixture('reading-plan.ods'), 'ods');
    expect(ods.single.cell(2, 1), 'Emma');

    final List<SheetData> csv = Sheets.parse(fixture('survey-results.csv'), 'csv');
    expect(csv.single.rows, hasLength(201));
    expect(csv.single.cell(1, 4), 'likes the sepia page, reads, mostly');
    expect(Sheets.column(27), 'AB');
  });

  test('Markdown and text', () {
    final ReadingDocument md = TextFormats.markdown(fixture('Reading list.md'), 'Reading list.md');
    expect(md.title, 'Reading list');
    final List<Block> blocks = md.sections.single.blocks;
    expect(blocks.where((Block b) => b.checked == true), hasLength(1));
    expect(blocks.where((Block b) => b.kind == BlockKind.code), hasLength(1));
    expect(blocks.where((Block b) => b.kind == BlockKind.quote), hasLength(1));
    expect(blocks.where((Block b) => b.kind == BlockKind.table), hasLength(1));
    expect(md.toc.map((TocEntry t) => t.title), containsAll(<String>['Novels', 'Notes']));

    final ReadingDocument list = TextFormats.plain(fixture('packing-list.txt'), 'packing-list.txt');
    expect(list.sections.single.blocks.first.text, 'Packing, Lisbon');
    expect(list.mono, isFalse);
    final ReadingDocument code = TextFormats.plain(fixture('config-sample.txt'), 'config-sample.txt');
    expect(code.mono, isTrue);
    // Mono changes the font only: one paragraph, line breaks and indents kept, no code boxes.
    final List<Block> lines = code.sections.single.blocks;
    expect(lines, hasLength(1));
    expect(lines.single.kind, BlockKind.paragraph);
    expect(lines.single.text, contains('\n    return'));
  });

  test('format registry capability lookup', () {
    expect(Formats.of('a.PDF')!.hasModeToggle, isTrue);
    expect(Formats.of('a.epub')!.hasModeToggle, isFalse);
    expect(Formats.of('a.xlsx')!.readerMode, isFalse);
    expect(Formats.of('a.pptx')!.hasModeToggle, isFalse, reason: 'slides only');
    expect(Formats.of('a.md')!.view, ViewKind.reader);
    expect(Formats.of('a.rar'), isNull);
    expect(Formats.of('noext', 'application/pdf'), Formats.pdf);
    expect(Formats.labelOf('dataset.zip'), 'ZIP');
  });
}
