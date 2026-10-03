import 'dart:math' as math;

import '../reading_document.dart';

/// One page's raw text as PDFium reports it, with a rectangle per character
/// in PDF units (origin bottom-left, so top > bottom).
class PdfPageInput {
  const PdfPageInput({required this.text, required this.rects, required this.width, required this.height});

  final String text;

  /// left, top, right, bottom per character, flattened.
  final List<double> rects;
  final double width;
  final double height;
}

class _Line {
  _Line(this.page, this.start, this.end, this.text, this.left, this.top, this.right, this.bottom, this.size);

  final int page;

  /// Character range in the page text.
  final int start;
  final int end;
  final String text;
  final double left, top, right, bottom;

  /// Median glyph height: the font size, near enough.
  final double size;
  int column = 0;
}

/// Turns positioned PDF text into reader blocks (Phase 5 of the brief):
/// detect columns, strip running heads and feet, rejoin hyphenated breaks,
/// build paragraphs from spacing and indents, infer headings from size and
/// centring, and keep a character map back to each page. Pure Dart, so it
/// runs in an isolate.
abstract final class PdfReflow {
  static ReadingDocument analyse(List<PdfPageInput> pages, {required String title, String? author}) {
    final List<List<_Line>> perPage = <List<_Line>>[for (int i = 0; i < pages.length; i++) _lines(i + 1, pages[i])];
    final int textChars = perPage.fold<int>(
      0,
      (int n, List<_Line> l) => n + l.fold<int>(0, (int m, _Line x) => m + x.text.length),
    );
    if (textChars < 20 * math.max(1, pages.length ~/ 2)) {
      return ReadingDocument(
        title: title,
        author: author,
        scanned: true,
        sections: <Section>[
          Section(
            title: '',
            blocks: <Block>[
              Block(kind: BlockKind.paragraph, runs: const <Inline>[Inline('')]),
            ],
          ),
        ],
      );
    }
    _stripRunningLines(perPage, pages);
    bool simplified = false;
    for (int i = 0; i < perPage.length; i++) {
      if (_orderColumns(perPage[i], pages[i])) simplified = true;
      if (_looksTabular(perPage[i])) simplified = true;
    }
    final List<_Line> all = <_Line>[for (final List<_Line> l in perPage) ...l];
    if (all.isEmpty) {
      return ReadingDocument(
        title: title,
        author: author,
        scanned: true,
        sections: <Section>[
          Section(
            title: '',
            blocks: <Block>[
              Block(kind: BlockKind.paragraph, runs: const <Inline>[Inline('')]),
            ],
          ),
        ],
      );
    }
    final double body = _median(all.map((_Line l) => l.size).toList());
    final List<double> gaps = <double>[];
    for (int i = 1; i < all.length; i++) {
      final _Line a = all[i - 1], b = all[i];
      if (a.page == b.page && a.column == b.column && (a.size - body).abs() < body * 0.2) gaps.add(a.bottom - b.top);
    }
    final double gap = gaps.isEmpty
        ? body * 0.4
        : _median(gaps.where((double g) => g > -body).toList()..add(body * 0.3));

    final List<Block> blocks = <Block>[];
    final StringBuffer text = StringBuffer();
    final List<int> map = <int>[];
    BlockKind kind = BlockKind.paragraph;
    int level = 0;
    int firstPage = 1;
    _Line? prev;

    void flush() {
      final String t = text.toString().trim();
      if (t.isNotEmpty) {
        final int lead = text.toString().indexOf(t);
        blocks.add(
          Block(
            kind: kind,
            level: level,
            runs: <Inline>[Inline(t)],
            source: SourceRef(page: firstPage, charMap: map.sublist(lead, lead + t.length)),
          ),
        );
      }
      text.clear();
      map.clear();
      kind = BlockKind.paragraph;
      level = 0;
    }

    final Map<(int, int), (double, double)> columns = <(int, int), (double, double)>{};
    for (final _Line line in all) {
      final (double colLeft, double colRight) = columns.putIfAbsent((
        line.page,
        line.column,
      ), () => (_columnLeft(perPage[line.page - 1], line.column), _columnRight(perPage[line.page - 1], line.column)));
      final double colWidth = math.max(1, colRight - colLeft);
      final bool large = line.size > body * 1.25;
      final double centre = (line.left + line.right) / 2;
      final bool centred =
          (centre - (colLeft + colRight) / 2).abs() < colWidth * 0.06 && (line.right - line.left) < colWidth * 0.75;
      final bool headingLike =
          large ||
          (centred &&
              line.text.length < 70 &&
              !RegExp(r'[,;]$').hasMatch(line.text) &&
              line.text.split(' ').length < 10);
      final BlockKind lineKind = headingLike ? BlockKind.heading : BlockKind.paragraph;

      bool breakBefore = prev == null;
      if (prev != null) {
        final bool samePlace = prev.page == line.page && prev.column == line.column;
        final double vgap = samePlace ? prev.bottom - line.top : 0;
        final bool bigGap = samePlace && vgap > gap * 1.8 + body * 0.35;
        final bool indented = line.left > colLeft + body * 0.7 && !centred;
        final bool prevShort = prev.right < colRight - body * 2.5 && RegExp(r'[.!?:"”’)]$').hasMatch(prev.text);
        final bool kindChange = lineKind != kind || (headingLike && (prev.size - line.size).abs() > body * 0.15);
        breakBefore = bigGap || indented || prevShort || kindChange || (headingLike && !samePlace);
        // A paragraph runs on across a page or column break unless the next
        // line is indented or the previous one ended a sentence.
        if (!samePlace &&
            !indented &&
            !headingLike &&
            kind == BlockKind.paragraph &&
            !RegExp(r'[.!?:"”’]$').hasMatch(prev.text)) {
          breakBefore = false;
        }
      }
      if (breakBefore) {
        flush();
        kind = lineKind;
        level = headingLike ? (line.size > body * 1.25 ? 1 : 3) : 0;
        firstPage = line.page;
      } else if (text.isNotEmpty) {
        final String sofar = text.toString();
        if (sofar.endsWith('-') &&
            line.text.isNotEmpty &&
            RegExp(r'^[a-z]').hasMatch(line.text) &&
            sofar.length > 1 &&
            RegExp(r'[a-zA-Z]$').hasMatch(sofar.substring(0, sofar.length - 1))) {
          // Rejoin a word hyphenated across the break.
          final String trimmed = sofar.substring(0, sofar.length - 1);
          text
            ..clear()
            ..write(trimmed);
          map.removeLast();
        } else {
          text.write(' ');
          map.add(-1);
        }
      }
      final String src = pages[line.page - 1].text;
      for (int i = line.start; i < line.end; i++) {
        final String ch = src[i];
        if (ch == '\r' || ch == '\n') continue;
        text.write(ch);
        map.add(line.page * SourceRef.kPage + i);
      }
      prev = line;
    }
    flush();

    // Consecutive large headings ("CHAPTER III." "STRUGGLE FOR EXISTENCE.")
    // are one heading.
    final List<Block> merged = <Block>[];
    for (final Block b in blocks) {
      if (merged.isNotEmpty &&
          b.kind == BlockKind.heading &&
          merged.last.kind == BlockKind.heading &&
          merged.last.level == b.level &&
          b.level == 1) {
        final Block a = merged.removeLast();
        final List<int> m = <int>[...?a.source?.charMap, -1, ...?b.source?.charMap];
        merged.add(
          Block(
            kind: BlockKind.heading,
            level: 1,
            runs: <Inline>[Inline('${a.text} ${b.text}')],
            source: SourceRef(page: a.source!.page, charMap: m),
          ),
        );
      } else {
        merged.add(b);
      }
    }

    final List<Section> sections = <Section>[];
    List<Block> current = <Block>[];
    String sectionTitle = '';
    for (final Block b in merged) {
      if (b.kind == BlockKind.heading && b.level == 1 && current.isNotEmpty) {
        sections.add(Section(title: sectionTitle, blocks: current));
        current = <Block>[];
      }
      if (b.kind == BlockKind.heading && b.level == 1) sectionTitle = _titleCase(b.text);
      current.add(b);
    }
    if (current.isNotEmpty) sections.add(Section(title: sectionTitle, blocks: current));
    final List<TocEntry> toc = <TocEntry>[
      for (int s = 0; s < sections.length; s++)
        for (int b = 0; b < sections[s].blocks.length; b++)
          if (sections[s].blocks[b].kind == BlockKind.heading)
            TocEntry(
              title: _titleCase(sections[s].blocks[b].text),
              section: s,
              block: b,
              level: sections[s].blocks[b].level == 1 ? 0 : 1,
            ),
    ];
    return ReadingDocument(
      title: title,
      author: author,
      sections: sections,
      toc: toc,
      simplified: simplified,
      unitLabel: 'Chapter',
    );
  }

  static List<_Line> _lines(int page, PdfPageInput p) {
    final List<_Line> out = <_Line>[];
    int start = 0;
    void emit(int end) {
      double l = double.infinity, t = -double.infinity, r = -double.infinity, b = double.infinity;
      final List<double> heights = <double>[];
      for (int i = start; i < end; i++) {
        if (i * 4 + 3 >= p.rects.length) break;
        final double cl = p.rects[i * 4], ct = p.rects[i * 4 + 1], cr = p.rects[i * 4 + 2], cb = p.rects[i * 4 + 3];
        if (cr - cl <= 0 || ct - cb <= 0 || p.text[i].trim().isEmpty) continue;
        l = math.min(l, cl);
        r = math.max(r, cr);
        t = math.max(t, ct);
        b = math.min(b, cb);
        heights.add(ct - cb);
      }
      int s = start, e = end;
      while (s < e && p.text[s].trim().isEmpty) {
        s++;
      }
      while (e > s && p.text[e - 1].trim().isEmpty) {
        e--;
      }
      if (heights.isNotEmpty && e > s) out.add(_Line(page, s, e, p.text.substring(s, e), l, t, r, b, _median(heights)));
    }

    for (int i = 0; i < p.text.length; i++) {
      if (p.text[i] == '\n') {
        emit(i);
        start = i + 1;
      }
    }
    emit(p.text.length);
    return out;
  }

  /// Lines repeated in the top or bottom tenth on many pages (running heads,
  /// feet) and bare page numbers there are dropped.
  static void _stripRunningLines(List<List<_Line>> perPage, List<PdfPageInput> pages) {
    String key(_Line l) => l.text.toLowerCase().replaceAll(RegExp(r'\d+'), '#').replaceAll(RegExp(r'\s+'), ' ').trim();
    bool inBand(_Line l) {
      final double h = pages[l.page - 1].height;
      return l.bottom > h * 0.9 || l.top < h * 0.1;
    }

    final Map<String, int> counts = <String, int>{};
    for (final List<_Line> lines in perPage) {
      for (final String k in lines.where(inBand).map(key).toSet()) {
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
    final int threshold = math.max(2, (perPage.length * 0.4).ceil());
    for (final List<_Line> lines in perPage) {
      lines.removeWhere(
        (_Line l) =>
            inBand(l) &&
            ((counts[key(l)] ?? 0) >= threshold ||
                RegExp(r'^[\divxlc]+$', caseSensitive: false).hasMatch(l.text.trim())),
      );
    }
  }

  /// Two columns: order the left column top to bottom, then the right.
  static bool _orderColumns(List<_Line> lines, PdfPageInput p) {
    if (lines.length < 8) return false;
    final double mid = p.width / 2;
    final List<_Line> right = lines
        .where((_Line l) => l.left > mid - p.width * 0.02 && l.right - l.left < p.width * 0.55)
        .toList();
    final List<_Line> left = lines.where((_Line l) => l.right < mid + p.width * 0.02).toList();
    if (right.length < lines.length * 0.25 || left.length < lines.length * 0.25) return false;
    for (final _Line l in right) {
      l.column = 1;
    }
    lines.sort((_Line a, _Line b) => a.column != b.column ? a.column - b.column : b.top.compareTo(a.top));
    return true;
  }

  /// Several lines with wide internal gaps: a table the reflow linearised.
  static bool _looksTabular(List<_Line> lines) =>
      lines.where((_Line l) => RegExp(r'\S {3,}\S').hasMatch(l.text) || '\t'.allMatches(l.text).length >= 2).length >=
      3;

  static double _columnLeft(List<_Line> lines, int column) {
    final List<double> lefts = lines.where((_Line l) => l.column == column).map((_Line l) => l.left).toList()..sort();
    return lefts.isEmpty ? 0 : lefts[lefts.length ~/ 10];
  }

  static double _columnRight(List<_Line> lines, int column) {
    final List<double> rights = lines.where((_Line l) => l.column == column).map((_Line l) => l.right).toList()..sort();
    return rights.isEmpty ? 0 : rights[rights.length * 9 ~/ 10];
  }

  static double _median(List<double> v) {
    if (v.isEmpty) return 0;
    final List<double> s = List<double>.of(v)..sort();
    return s[s.length ~/ 2];
  }

  /// "CHAPTER III. STRUGGLE FOR EXISTENCE." reads "Chapter III. Struggle for existence." in a table of contents.
  static String _titleCase(String s) {
    if (s.toUpperCase() != s) return s;
    final String lower = s.toLowerCase();
    return lower
        .replaceAllMapped(RegExp(r'(^|[.:]\s+)([a-z])'), (Match m) => '${m[1]}${m[2]!.toUpperCase()}')
        .replaceAllMapped(RegExp(r'\b(i{1,3}|iv|v|vi{0,3}|ix|x{1,3}|xi{0,3})\b'), (Match m) => m[0]!.toUpperCase());
  }
}
