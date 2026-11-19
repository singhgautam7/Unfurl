import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../reading_document.dart';
import 'ooxml.dart';

/// A run with the document's own formatting, for Page view.
class DocxRun {
  const DocxRun(this.text, {this.size, this.bold = false, this.italic = false, this.underline = false, this.href});

  final String text;

  /// Points; null takes the paragraph's.
  final double? size;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? href;
}

enum DocxAlign { start, center, end, justify }

/// A paragraph's line spacing: a multiple of single (`lineRule` auto, in
/// 240ths), or a fixed or minimum height in points (`exact`, `atLeast`).
class DocxLine {
  const DocxLine({this.multiple = 1, this.points, this.atLeast = false});

  /// From `w:line` and `w:lineRule`; null when the element sets no line.
  static DocxLine? of(XmlElement? spacing) {
    final double? twips = double.tryParse(spacing?.getAttribute('w:line') ?? '');
    if (twips == null || twips <= 0) return null;
    return switch (spacing?.getAttribute('w:lineRule')) {
      'exact' => DocxLine(points: twips / 20),
      'atLeast' => DocxLine(points: twips / 20, atLeast: true),
      _ => DocxLine(multiple: twips / 240),
    };
  }

  /// Word's single line is about 1.15 of the font size (Arial's and Calibri's
  /// ascent, descent and gap).
  static const double single = 1.15;

  final double multiple;
  final double? points;
  final bool atLeast;

  /// The line height as a multiple of [fontSize] (both in points).
  double heightFor(double fontSize) {
    final double auto = single * multiple;
    final double? pt = points;
    if (pt == null || fontSize <= 0) return auto;
    return atLeast ? (pt / fontSize > single ? pt / fontSize : single) : pt / fontSize;
  }
}

/// One paragraph, table or image of the body, in order.
class DocxItem {
  DocxItem.paragraph({
    required this.runs,
    this.style,
    this.align = DocxAlign.start,
    this.size = 11,
    this.spaceBefore = 0,
    this.spaceAfter = 6,
    this.indent = 0,
    this.heading = 0,
    this.listLevel,
    this.ordinal,
    this.pageBreakBefore = false,
    this.line = const DocxLine(),
  }) : rows = null,
       image = null;

  DocxItem.table(this.rows, {this.pageBreakBefore = false})
    : line = const DocxLine(),
      runs = const <DocxRun>[],
      style = null,
      align = DocxAlign.start,
      size = 9,
      spaceBefore = 4,
      spaceAfter = 6,
      indent = 0,
      heading = 0,
      listLevel = null,
      ordinal = null,
      image = null;

  DocxItem.image(this.image)
    : line = const DocxLine(),
      runs = const <DocxRun>[],
      rows = null,
      style = null,
      align = DocxAlign.center,
      size = 11,
      spaceBefore = 4,
      spaceAfter = 6,
      indent = 0,
      heading = 0,
      listLevel = null,
      ordinal = null,
      pageBreakBefore = false;

  final List<DocxRun> runs;
  final List<List<String>>? rows;
  final String? image;
  final String? style;
  final DocxAlign align;

  /// Paragraph font size, points.
  final double size;
  final double spaceBefore;
  final double spaceAfter;
  final double indent;

  /// 0 for body text; 1 is Title or Heading 1.
  final int heading;
  final int? listLevel;
  final int? ordinal;
  final bool pageBreakBefore;

  /// Line spacing (`w:spacing w:line` / `w:lineRule`).
  final DocxLine line;

  String get text =>
      rows != null ? rows!.map((List<String> r) => r.join('\t')).join('\n') : runs.map((DocxRun r) => r.text).join();
}

/// A Word document's body, page geometry and images.
/// Page margins in points, as the document sets each side.
class EdgeInsetsPt {
  const EdgeInsetsPt(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;
}

class Docx {
  Docx._(this.items, this.images, this.title, this.author, this.pageWidth, this.pageHeight, this.margins);

  /// Page size and margins in points (`w:pgSz`, `w:pgMar`).
  final double pageWidth;
  final double pageHeight;
  final EdgeInsetsPt margins;
  final List<DocxItem> items;
  final Map<String, Uint8List> images;
  final String? title;
  final String? author;

  static Docx parse(Uint8List bytes) {
    final Archive zip = ZipDecoder().decodeBytes(bytes);
    String? text(String path) {
      final ArchiveFile? f = zip.findFile(path);
      return f == null ? null : utf8.decode(f.content, allowMalformed: true);
    }

    final XmlDocument doc = XmlDocument.parse(text('word/document.xml')!);
    final Map<String, String> rels = _rels(text('word/_rels/document.xml.rels'));
    final _Styles styles = _Styles(text('word/styles.xml'));
    final XmlDocument? core = text('docProps/core.xml') == null ? null : XmlDocument.parse(text('docProps/core.xml')!);
    String? coreField(String name) => core?.descendantElements
        .where((XmlElement e) => e.localName == name)
        .map((XmlElement e) => e.innerText.trim())
        .where((String s) => s.isNotEmpty)
        .firstOrNull;

    final Map<String, Uint8List> images = <String, Uint8List>{};
    final List<DocxItem> items = <DocxItem>[];
    final Map<String, int> counters = <String, int>{};
    final XmlElement body = doc.descendantElements.firstWhere((XmlElement e) => e.localName == 'body');

    // A section break (other than continuous) starts the next block on a new page.
    bool sectionBreak = false;
    for (final XmlElement el in body.childElements) {
      if (el.localName == 'tbl') {
        final bool breakBefore = sectionBreak;
        sectionBreak = false;
        items.add(
          DocxItem.table(pageBreakBefore: breakBefore, <List<String>>[
            for (final XmlElement tr in el.childElements.where((XmlElement e) => e.localName == 'tr'))
              <String>[
                for (final XmlElement tc in tr.childElements.where((XmlElement e) => e.localName == 'tc'))
                  tc.descendantElements.where((XmlElement e) => e.localName == 'p').map(_plain).join('\n').trim(),
              ],
          ]),
        );
        continue;
      }
      if (el.localName != 'p') continue;
      final XmlElement? ppr = ooxmlChild(el, 'pPr');
      final String? styleId = ooxmlVal(ooxmlChild(ppr, 'pStyle'));
      final _Style st = styles.of(styleId);
      final XmlElement? numPr = ooxmlChild(ppr, 'numPr');
      final int? level = numPr == null && !st.list
          ? null
          : int.tryParse(ooxmlVal(ooxmlChild(numPr, 'ilvl')) ?? '0') ?? 0;
      final String numId = ooxmlVal(ooxmlChild(numPr, 'numId')) ?? '';
      final bool ordered = numPr != null && styles.isOrdered(text('word/numbering.xml'), numId, level ?? 0);
      final int? ordinal = ordered ? (counters[numId] = (counters[numId] ?? 0) + 1) : null;

      List<DocxRun> runs = <DocxRun>[];
      // Only breaks that are on: `pageBreakBefore` read as ST_OnOff (Google
      // Docs writes `w:val="0"` on most paragraphs), else the style's.
      bool pageBreak = (ooxmlOn(ooxmlChild(ppr, 'pageBreakBefore')) ?? st.pageBreakBefore) || sectionBreak;
      final XmlElement? sect = ooxmlChild(ppr, 'sectPr');
      sectionBreak = sect != null && ooxmlVal(ooxmlChild(sect, 'type')) != 'continuous';
      // Text before and after each page break run, with whether it starts a page.
      final List<(List<DocxRun>, bool)> parts = <(List<DocxRun>, bool)>[];
      void addRun(XmlElement r, String? href) {
        final XmlElement? rpr = ooxmlChild(r, 'rPr');
        for (final XmlElement part in r.childElements) {
          switch (part.localName) {
            case 't':
              runs.add(
                DocxRun(
                  part.innerText,
                  size: _halfPoints(ooxmlChild(rpr, 'sz')),
                  bold: ooxmlOn(ooxmlChild(rpr, 'b')) ?? st.bold ?? false,
                  italic: ooxmlOn(ooxmlChild(rpr, 'i')) ?? st.italic ?? false,
                  underline: ooxmlUnderline(ooxmlChild(rpr, 'u')) ?? false,
                  href: href,
                ),
              );
            case 'tab':
              runs.add(const DocxRun('\t'));
            case 'br':
              final String? type = part.attributes
                  .where((XmlAttribute a) => a.localName == 'type')
                  .map((XmlAttribute a) => a.value)
                  .firstOrNull;
              if (type == 'page') {
                // A page break inside a paragraph: what follows starts the next page.
                if (runs.isNotEmpty) {
                  parts.add((runs, pageBreak));
                  runs = <DocxRun>[];
                }
                pageBreak = true;
              } else {
                runs.add(const DocxRun('\n'));
              }
            case 'drawing' || 'pict':
              final XmlElement? blip = part.descendantElements
                  .where((XmlElement e) => e.localName == 'blip' || e.localName == 'imagedata')
                  .firstOrNull;
              final String? rid = blip?.attributes
                  .where((XmlAttribute a) => a.localName == 'embed' || a.localName == 'id')
                  .map((XmlAttribute a) => a.value)
                  .firstOrNull;
              final String? target = rid == null ? null : rels[rid];
              if (target != null) {
                final ArchiveFile? f = zip.findFile('word/$target');
                if (f != null) {
                  images[target] = f.content;
                  items.add(DocxItem.image(target));
                }
              }
          }
        }
      }

      for (final XmlElement child in el.childElements) {
        if (child.localName == 'r') addRun(child, null);
        if (child.localName == 'hyperlink') {
          final String? rid = child.attributes
              .where((XmlAttribute a) => a.localName == 'id')
              .map((XmlAttribute a) => a.value)
              .firstOrNull;
          for (final XmlElement r in child.childElements.where((XmlElement e) => e.localName == 'r')) {
            addRun(r, rid == null ? null : rels[rid]);
          }
        }
      }
      parts.add((runs, pageBreak));
      final String jc = ooxmlVal(ooxmlChild(ppr, 'jc')) ?? st.align;
      final XmlElement? spacing = ooxmlChild(ppr, 'spacing');
      for (final (List<DocxRun> partRuns, bool breakBefore) in parts) {
        items.add(
          DocxItem.paragraph(
            runs: partRuns,
            style: styleId,
            align: switch (jc) {
              'center' => DocxAlign.center,
              'right' || 'end' => DocxAlign.end,
              'both' || 'distribute' => DocxAlign.justify,
              _ => DocxAlign.start,
            },
            size: st.size ?? styles.defaultSize,
            heading: st.heading,
            spaceBefore: _twips(spacing?.getAttribute('w:before')) ?? st.spaceBefore,
            spaceAfter: _twips(spacing?.getAttribute('w:after')) ?? st.spaceAfter,
            line: DocxLine.of(spacing) ?? st.line ?? styles.defaultLine,
            indent: _twips(ooxmlChild(ppr, 'ind')?.getAttribute('w:left')) ?? 0,
            listLevel: level,
            ordinal: ordinal,
            pageBreakBefore: breakBefore,
          ),
        );
      }
    }

    final XmlElement? sect = body.childElements.where((XmlElement e) => e.localName == 'sectPr').firstOrNull;
    final XmlElement? pgSz = ooxmlChild(sect, 'pgSz');
    final XmlElement? pgMar = ooxmlChild(sect, 'pgMar');
    double margin(String side) => _twips(pgMar?.getAttribute('w:$side'))?.abs() ?? 72;
    return Docx._(
      items,
      images,
      coreField('title'),
      coreField('creator'),
      _twips(pgSz?.getAttribute('w:w')) ?? 595,
      _twips(pgSz?.getAttribute('w:h')) ?? 842,
      EdgeInsetsPt(margin('left'), margin('top'), margin('right'), margin('bottom')),
    );
  }

  /// Reader mode: Word headings become headings, lists list items, tables
  /// tables. Each block's source is its paragraph index (1-based), which is
  /// how Page view and Reader view share a place.
  ReadingDocument toReading(String name) {
    final List<Section> sections = <Section>[];
    List<Block> current = <Block>[];
    String title = '';
    void close() {
      if (current.isNotEmpty) sections.add(Section(title: title, blocks: current));
      current = <Block>[];
    }

    for (int i = 0; i < items.length; i++) {
      final DocxItem it = items[i];
      final SourceRef src = SourceRef(page: i + 1, end: it.text.length);
      if (it.rows != null) {
        current.add(Block(kind: BlockKind.table, rows: it.rows, source: src));
      } else if (it.image != null) {
        current.add(Block(kind: BlockKind.image, image: it.image, source: src));
      } else if (it.text.trim().isEmpty) {
        continue;
      } else if (it.heading > 0) {
        // A new section (and page) at a top-level heading, once the one
        // before has body text: a title isn't left alone on its page.
        if (it.heading == 1 && current.any((Block b) => b.kind != BlockKind.heading)) close();
        if (it.heading <= 2 && (title.isEmpty || it.heading == 1)) title = it.text.trim();
        current.add(Block(kind: BlockKind.heading, level: it.heading, runs: _inlines(it), source: src));
      } else if (it.listLevel != null) {
        current.add(
          Block(
            kind: BlockKind.listItem,
            level: it.listLevel! + 1,
            ordinal: it.ordinal,
            runs: _inlines(it),
            source: src,
          ),
        );
      } else {
        final bool caption = it.runs.every((DocxRun r) => r.italic) && it.text.length < 120 && (it.size < 10.5);
        current.add(Block(kind: caption ? BlockKind.caption : BlockKind.paragraph, runs: _inlines(it), source: src));
      }
    }
    close();
    if (sections.isEmpty) {
      sections.add(
        Section(
          title: '',
          blocks: <Block>[
            Block(kind: BlockKind.paragraph, runs: const <Inline>[Inline('')]),
          ],
        ),
      );
    }
    return ReadingDocument(
      title: title.isEmpty ? (this.title ?? name) : (this.title ?? name),
      author: author,
      sections: sections,
      resources: images,
      unitLabel: 'Section',
    );
  }

  static List<Inline> _inlines(DocxItem it) => <Inline>[
    for (final DocxRun r in it.runs) Inline(r.text, bold: r.bold, italic: r.italic, href: r.href),
  ];

  static String _plain(XmlElement p) => p.descendantElements
      .where((XmlElement e) => e.localName == 't' || e.localName == 'tab')
      .map((XmlElement e) => e.localName == 'tab' ? '\t' : e.innerText)
      .join();

  static Map<String, String> _rels(String? xml) => xml == null
      ? const <String, String>{}
      : <String, String>{
          for (final XmlElement r in XmlDocument.parse(
            xml,
          ).descendantElements.where((XmlElement e) => e.localName == 'Relationship'))
            r.getAttribute('Id')!: r.getAttribute('Target')!,
        };
}

double? _halfPoints(XmlElement? e) {
  final String? v = ooxmlVal(e);
  return v == null ? null : (int.tryParse(v) ?? 22) / 2;
}

double? _twips(String? v) => v == null ? null : (int.tryParse(v) ?? 0) / 20;

class _Style {
  const _Style({
    this.size,
    this.bold,
    this.italic,
    this.heading = 0,
    this.align = 'left',
    this.spaceBefore = 0,
    this.spaceAfter = 6,
    this.list = false,
    this.pageBreakBefore = false,
    this.line,
  });

  final double? size;
  final bool? bold;
  final bool? italic;
  final int heading;
  final String align;
  final double spaceBefore;
  final double spaceAfter;
  final bool list;
  final bool pageBreakBefore;
  final DocxLine? line;
}

class _Styles {
  _Styles(String? xml) {
    if (xml == null) return;
    final XmlDocument doc = XmlDocument.parse(xml);
    final XmlElement? defaults = doc.descendantElements
        .where((XmlElement e) => e.localName == 'rPrDefault')
        .firstOrNull;
    defaultSize =
        _halfPoints(defaults?.descendantElements.where((XmlElement e) => e.localName == 'sz').firstOrNull) ?? 11;
    final XmlElement? pDefault = doc.descendantElements
        .where((XmlElement e) => e.localName == 'pPrDefault')
        .firstOrNull;
    defaultLine =
        DocxLine.of(pDefault?.descendantElements.where((XmlElement e) => e.localName == 'spacing').firstOrNull) ??
        defaultLine;
    for (final XmlElement s in doc.descendantElements.where((XmlElement e) => e.localName == 'style')) {
      final String? id = s.getAttribute('w:styleId');
      if (id == null) continue;
      _raw[id] = s;
    }
  }

  double defaultSize = 11;

  /// `w:pPrDefault`'s line spacing, else single.
  DocxLine defaultLine = const DocxLine();
  final Map<String, XmlElement> _raw = <String, XmlElement>{};
  final Map<String, _Style> _resolved = <String, _Style>{};

  _Style of(String? id) {
    if (id == null) return of('Normal');
    return _resolved[id] ??= _resolve(id, 0);
  }

  _Style _resolve(String id, int depth) {
    final XmlElement? s = _raw[id];
    if (s == null || depth > 8) return const _Style();
    final String name = (ooxmlVal(ooxmlChild(s, 'name')) ?? id).toLowerCase();
    final _Style base = ooxmlVal(ooxmlChild(s, 'basedOn')) == null
        ? const _Style()
        : _resolve(ooxmlVal(ooxmlChild(s, 'basedOn'))!, depth + 1);
    final XmlElement? rpr = ooxmlChild(s, 'rPr');
    final XmlElement? ppr = ooxmlChild(s, 'pPr');
    final RegExpMatch? h = RegExp(r'^heading (\d)').firstMatch(name);
    final XmlElement? spacing = ooxmlChild(ppr, 'spacing');
    return _Style(
      size: _halfPoints(ooxmlChild(rpr, 'sz')) ?? base.size,
      bold: ooxmlOn(ooxmlChild(rpr, 'b')) ?? base.bold,
      italic: ooxmlOn(ooxmlChild(rpr, 'i')) ?? base.italic,
      heading: name == 'title' ? 1 : (h != null ? int.parse(h[1]!) + (name == 'title' ? 0 : 0) : base.heading),
      align: ooxmlVal(ooxmlChild(ppr, 'jc')) ?? base.align,
      spaceBefore: _twips(spacing?.getAttribute('w:before')) ?? base.spaceBefore,
      spaceAfter: _twips(spacing?.getAttribute('w:after')) ?? base.spaceAfter,
      line: DocxLine.of(spacing) ?? base.line,
      list: name.contains('list') || base.list,
      pageBreakBefore: ooxmlOn(ooxmlChild(ppr, 'pageBreakBefore')) ?? base.pageBreakBefore,
    );
  }

  /// Whether a numbering instance at [level] counts (decimal, letters,
  /// roman) rather than bullets.
  bool isOrdered(String? numberingXml, String numId, int level) {
    if (numberingXml == null) return false;
    final XmlDocument doc = _numbering ??= XmlDocument.parse(numberingXml);
    final XmlElement? num = doc.descendantElements
        .where((XmlElement e) => e.localName == 'num' && e.getAttribute('w:numId') == numId)
        .firstOrNull;
    final String? abstractId = ooxmlVal(ooxmlChild(num, 'abstractNumId'));
    final XmlElement? abs = doc.descendantElements
        .where((XmlElement e) => e.localName == 'abstractNum' && e.getAttribute('w:abstractNumId') == abstractId)
        .firstOrNull;
    final XmlElement? lvl = abs?.childElements
        .where((XmlElement e) => e.localName == 'lvl' && e.getAttribute('w:ilvl') == '$level')
        .firstOrNull;
    final String fmt = ooxmlVal(ooxmlChild(lvl, 'numFmt')) ?? 'bullet';
    return fmt != 'bullet' && fmt != 'none';
  }

  XmlDocument? _numbering;
}

/// Page view: the item indices on each page. A page ends where the next item
/// would overflow [textHeight], or before an item whose break is on (a page
/// break run, `pageBreakBefore` on, a section break). A page that would hold
/// only empty paragraphs is never kept, so empty paragraphs never make a
/// blank page.
List<List<int>> docxPages(Docx d, double textHeight, double Function(DocxItem) height) {
  bool blank(List<int> page) => page.every((int i) {
    final DocxItem it = d.items[i];
    return it.rows == null && it.image == null && it.text.trim().isEmpty;
  });
  final List<List<int>> pages = <List<int>>[<int>[]];
  double y = 0;
  for (int i = 0; i < d.items.length; i++) {
    final DocxItem it = d.items[i];
    final double h = height(it);
    if ((y + h > textHeight || it.pageBreakBefore) && pages.last.isNotEmpty) {
      if (blank(pages.last)) {
        pages.last.clear();
      } else {
        pages.add(<int>[]);
      }
      y = 0;
    }
    pages.last.add(i);
    y += h;
  }
  if (pages.length > 1 && blank(pages.last)) pages.removeLast();
  return pages;
}
