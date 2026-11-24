// Part L1: Word's on/off flags and page breaks. Synthetic documents shaped
// like a Google Docs export (pageBreakBefore, keepNext and keepLines written
// with w:val="0" on most paragraphs, empty paragraphs between sections).
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/features/reader/engine/layout.dart';
import 'package:unfurl/formats/office/docx.dart';
import 'package:unfurl/formats/office/ooxml.dart';
import 'package:unfurl/formats/reading_document.dart';
import 'package:xml/xml.dart';

import '../reader/harness.dart';

const String _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

String _p(String text, {String ppr = '', String run = ''}) =>
    '<w:p><w:pPr>$ppr</w:pPr><w:r><w:t xml:space="preserve">$text</w:t></w:r>$run</w:p>';

const String _off =
    '<w:keepNext w:val="0"/><w:keepLines w:val="0"/><w:pageBreakBefore w:val="0"/><w:widowControl w:val="1"/>';

Uint8List _docx(String body, {String styles = ''}) {
  final Archive a = Archive();
  void add(String name, String text) {
    final List<int> bytes = utf8.encode(text);
    a.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add(
    'word/document.xml',
    '<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="$_w"><w:body>$body'
        '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/>'
        '<w:pgMar w:top="936" w:bottom="936" w:left="936" w:right="936"/></w:sectPr></w:body></w:document>',
  );
  add(
    'word/styles.xml',
    '<?xml version="1.0" encoding="UTF-8"?><w:styles xmlns:w="$_w">'
        '<w:style w:type="paragraph" w:styleId="Normal"><w:name w:val="Normal"/>'
        '<w:pPr><w:pageBreakBefore w:val="0"/></w:pPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/>'
        '<w:basedOn w:val="Normal"/><w:pPr><w:pageBreakBefore w:val="0"/></w:pPr></w:style>'
        '$styles</w:styles>',
  );
  return Uint8List.fromList(ZipEncoder().encode(a));
}

/// A resume-like body: 28 of the paragraphs carry off-valued flags, 5 are empty.
String _resumeLike({bool flags = true}) {
  final StringBuffer b = StringBuffer();
  for (int section = 0; section < 5; section++) {
    b.write(_p('SECTION $section'));
    for (int i = 0; i < 6; i++) {
      b.write(_p('Bullet $section.$i ${'words ' * 20}', ppr: flags && i < 6 ? _off : ''));
    }
    b.write('<w:p><w:pPr>${flags ? _off : ''}</w:pPr></w:p>');
  }
  return b.toString();
}

/// Every item one unit high on a page of [perPage] units.
List<List<int>> _pages(Docx d, {double perPage = 1000}) => docxPages(d, perPage, (_) => 1);

int _readerPages(ReadingDocument doc) {
  final Layout l = Layout(doc: doc, style: styleOf(), pageSize: const Size(360, 600), images: ImageSizes.of(doc));
  for (int s = 0; s < doc.sections.length; s++) {
    l.ensure(s);
  }
  final int n = l.knownPages;
  l.dispose();
  return n;
}

void main() {
  test('ST_OnOff: presence is on, 0/false/off is off, absent inherits', () {
    XmlElement el(String xml) => XmlDocument.parse(xml).rootElement;
    expect(ooxmlOn(null), isNull);
    expect(ooxmlOn(el('<b/>')), isTrue);
    for (final String v in <String>['1', 'true', 'on', 'TRUE']) {
      expect(ooxmlOn(el('<b val="$v"/>')), isTrue, reason: v);
    }
    for (final String v in <String>['0', 'false', 'off']) {
      expect(ooxmlOn(el('<b val="$v"/>')), isFalse, reason: v);
    }
    expect(ooxmlUnderline(el('<u val="none"/>')), isFalse);
    expect(ooxmlUnderline(el('<u val="single"/>')), isTrue);
  });

  test('off-valued flags make no extra pages in Page view', () {
    final Docx d = Docx.parse(_docx(_resumeLike()));
    expect(d.items.where((DocxItem i) => i.pageBreakBefore), isEmpty);
    expect(_pages(d), hasLength(1));
    // Overflow still breaks: 35 items on pages of 10.
    expect(_pages(d, perPage: 10), hasLength(4));
  });

  test('off-valued flags make no extra pages or chapters in Reader mode', () {
    final ReadingDocument withFlags = Docx.parse(_docx(_resumeLike())).toReading('r');
    final ReadingDocument without = Docx.parse(_docx(_resumeLike(flags: false))).toReading('r');
    expect(withFlags.sections, hasLength(1));
    expect(withFlags.chapters, hasLength(1));
    expect(_readerPages(withFlags), _readerPages(without));
  });

  test('one real page break run gives exactly one break', () {
    final Docx d = Docx.parse(
      _docx(_p('one') + _p('two', run: '<w:r><w:br w:type="page"/></w:r><w:r><w:t>three</w:t></w:r>') + _p('four')),
    );
    final List<List<int>> pages = _pages(d);
    expect(pages, hasLength(2));
    expect(d.items[pages[1].first].text, 'three');
    expect(pages.expand((List<int> p) => p).map((int i) => d.items[i].text).join(' '), 'one two three four');
  });

  test('pageBreakBefore on (bare, 1, from the style) breaks; a line break does not', () {
    final Docx d = Docx.parse(
      _docx(
        _p('a') +
            _p('b', ppr: '<w:pageBreakBefore/>') +
            _p('c', ppr: '<w:pageBreakBefore w:val="1"/>') +
            _p('d', ppr: '<w:pStyle w:val="Chapter"/>') +
            _p('e', run: '<w:r><w:br/></w:r>'),
        styles:
            '<w:style w:type="paragraph" w:styleId="Chapter"><w:name w:val="Chapter"/>'
            '<w:pPr><w:pageBreakBefore/></w:pPr></w:style>',
      ),
    );
    expect(_pages(d), hasLength(4));
  });

  test('empty paragraphs never make a blank page', () {
    const String empty = '<w:p><w:pPr><w:pageBreakBefore/></w:pPr></w:p>';
    final Docx d = Docx.parse(_docx("${_p('a')}$empty<w:p/>${_p('b', ppr: '<w:pageBreakBefore/>')}<w:p/><w:p/>"));
    final List<List<int>> pages = _pages(d);
    expect(pages, hasLength(2));
    for (final List<int> page in pages) {
      expect(page.any((int i) => d.items[i].text.trim().isNotEmpty), isTrue);
    }
    expect(Docx.parse(_docx(_p('a') + empty + empty)).toReading('r').sections, hasLength(1));
  });

  test('a section break starts a new page; a continuous one does not', () {
    final Docx d = Docx.parse(
      _docx(_p('a', ppr: '<w:sectPr/>') + _p('b', ppr: '<w:sectPr><w:type w:val="continuous"/></w:sectPr>') + _p('c')),
    );
    expect(_pages(d).map((List<int> p) => p.length), <int>[1, 2]);
    const String table = '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl>';
    expect(_pages(Docx.parse(_docx("${_p('a', ppr: '<w:sectPr/>')}$table"))), hasLength(2));
  });

  test('line spacing comes from the paragraph, else its style, else single', () {
    final Docx d = Docx.parse(
      _docx(
        _p('single') +
            _p('one and a half', ppr: '<w:spacing w:line="360" w:lineRule="auto"/>') +
            _p('exact', ppr: '<w:spacing w:line="280" w:lineRule="exact"/>') +
            _p('styled', ppr: '<w:pStyle w:val="Loose"/>'),
        styles:
            '<w:style w:type="paragraph" w:styleId="Loose"><w:name w:val="Loose"/>'
            '<w:pPr><w:spacing w:line="480"/></w:pPr></w:style>',
      ),
    );
    expect(d.items[0].line.heightFor(11), closeTo(1.15, 1e-9));
    expect(d.items[1].line.heightFor(11), closeTo(1.725, 1e-9));
    expect(d.items[2].line.heightFor(14), closeTo(1.0, 1e-9));
    expect(d.items[3].line.heightFor(11), closeTo(2.3, 1e-9));
  });

  test('page margins are read per side', () {
    final Docx d = Docx.parse(_docx(_p('a')));
    expect(d.margins.top, 46.8);
    expect(d.margins.left, 46.8);
    expect(d.pageWidth, 612);
  });
}
