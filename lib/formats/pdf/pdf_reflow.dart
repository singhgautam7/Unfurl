import 'dart:math' as math;
import 'dart:typed_data';

import '../reading_document.dart';

/// One page's raw text as PDFium reports it, with a rectangle per character
/// in PDF units (origin bottom-left, so top > bottom).
class PdfPageInput {
  const PdfPageInput({
    required this.text,
    required this.rects,
    required this.width,
    required this.height,
    this.regions = const <double>[],
    this.tables = const <PdfTable>[],
  });

  final String text;

  /// left, top, right, bottom per character, flattened.
  final List<double> rects;
  final double width;
  final double height;

  /// Figures and tables kept as pictures (left, top, right, bottom per
  /// region, PDF units), found by [PdfReflow.findRegions]. Their text
  /// leaves the flow; image `PdfReflow.regionKey(page, i)` takes its place.
  final List<double> regions;

  /// Tables, rebuilt as rows of text by [PdfReflow.tableGrid]: their text
  /// leaves the flow and a table block takes its place.
  final List<PdfTable> tables;
}

/// A table's grid in PDF units: column edges left to right, row edges top
/// to bottom (top > bottom), outer edges included.
class PdfTable {
  const PdfTable(this.xs, this.ys);

  final List<double> xs;
  final List<double> ys;

  Rect4 get box => Rect4(xs.first, ys.first, xs.last, ys.last);
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

  /// A figure: its image key; the line has no text.
  String? region;

  /// A table: its grid; the line has no text.
  PdfTable? table;
}

/// Turns positioned PDF text into reader blocks (Phase 5 of the brief):
/// detect columns, strip running heads and feet, rejoin hyphenated breaks,
/// build paragraphs from spacing and indents, infer headings from size and
/// centring, and keep a character map back to each page. Pure Dart, so it
/// runs in an isolate.
abstract final class PdfReflow {
  static String regionKey(int page, int index) => 'p${page}r$index';

  /// Figures and tables on a page, in PDF units (l, t, r, b per region):
  ///
  /// - drawn ink that isn't text ([bgra] is the page rendered [w] x [h]):
  ///   pictures, charts, and ruled tables (their rules), grown to take in
  ///   the text inside them;
  /// - text laid out in a grid: three or more consecutive lines, each with
  ///   two or more wide gaps between words (an unruled table).
  ///
  /// ponytail: pixel heuristics, no PDF object model. Background tints that
  /// cover most of a page are ignored; a very busy page may read as one
  /// picture. PDFium's page objects would be exact if pdfrx exposes them.
  static List<double> findRegions(PdfPageInput p, Uint8List? bgra, int w, int h) {
    final List<Rect4> found = <Rect4>[];
    final double sx = p.width / math.max(1, w), sy = p.height / math.max(1, h);
    if (bgra != null && w > 0 && h > 0) {
      final int cell = math.max(4, w ~/ 90);
      final int gw = (w + cell - 1) ~/ cell, gh = (h + cell - 1) ~/ cell;
      final Uint8List ink = Uint8List(gw * gh);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final int i = (y * w + x) * 4;
          final int b = bgra[i], g = bgra[i + 1], r = bgra[i + 2];
          final int hi = math.max(r, math.max(g, b)), lo = math.min(r, math.min(g, b));
          if (hi < 230 || hi - lo > 40) ink[(y ~/ cell) * gw + x ~/ cell] = 1;
        }
      }
      // Clear text: each glyph's cells, grown by one.
      for (int i = 0; i + 3 < p.rects.length; i += 4) {
        if (i ~/ 4 < p.text.length && p.text[i ~/ 4].trim().isEmpty) continue;
        final int x0 = (p.rects[i] / sx / cell).floor() - 1, x1 = (p.rects[i + 2] / sx / cell).ceil() + 1;
        final int y0 = ((p.height - p.rects[i + 1]) / sy / cell).floor() - 1;
        final int y1 = ((p.height - p.rects[i + 3]) / sy / cell).ceil() + 1;
        for (int y = math.max(0, y0); y < math.min(gh, y1); y++) {
          for (int x = math.max(0, x0); x < math.min(gw, x1); x++) {
            ink[y * gw + x] = 0;
          }
        }
      }
      // Join nearby marks (a chart's bars and axes) by growing ink 2 cells,
      // then take connected groups.
      final Uint8List grown = Uint8List(gw * gh);
      for (int y = 0; y < gh; y++) {
        for (int x = 0; x < gw; x++) {
          if (ink[y * gw + x] == 0) continue;
          for (int dy = -2; dy <= 2; dy++) {
            for (int dx = -2; dx <= 2; dx++) {
              final int yy = y + dy, xx = x + dx;
              if (yy >= 0 && yy < gh && xx >= 0 && xx < gw) grown[yy * gw + xx] = 1;
            }
          }
        }
      }
      final Int32List stack = Int32List(gw * gh);
      for (int start = 0; start < grown.length; start++) {
        if (grown[start] != 1) continue;
        int top = 0, x0 = gw, y0 = gh, x1 = -1, y1 = -1;
        stack[top++] = start;
        grown[start] = 2;
        while (top > 0) {
          final int at = stack[--top];
          final int x = at % gw, y = at ~/ gw;
          x0 = math.min(x0, x);
          x1 = math.max(x1, x);
          y0 = math.min(y0, y);
          y1 = math.max(y1, y);
          for (final int n in <int>[at - 1, at + 1, at - gw, at + gw]) {
            if (n < 0 || n >= grown.length || (n % gw - x).abs() > 1 || grown[n] != 1) continue;
            grown[n] = 2;
            stack[top++] = n;
          }
        }
        final double bw = (x1 - x0 + 1) / gw, bh = (y1 - y0 + 1) / gh;
        // Large enough to be a picture or a table, not a rule or a bullet,
        // and not a tint behind the whole page.
        if (bw < 0.12 || bh < 0.05 || bw * bh < 0.015 || bw * bh > 0.7) continue;
        found.add(
          Rect4(
            x0 * cell * sx,
            p.height - y0 * cell * sy,
            math.min(p.width, (x1 + 1) * cell * sx),
            math.max(0, p.height - (y1 + 1) * cell * sy),
          ),
        );
      }
    }
    final int pictures = found.length;
    // Unruled tables: runs of lines with two or more wide gaps.
    final List<_Line> lines = _lines(1, p);
    int run = 0;
    for (int i = 0; i <= lines.length; i++) {
      final bool grid = i < lines.length && _gaps(p, lines[i]) >= 2;
      final bool joined =
          grid &&
          run > 0 &&
          lines[i - 1].bottom - lines[i].top < lines[i].size * 2.5 &&
          lines[i].top < lines[i - 1].top;
      if (grid && (run == 0 || joined)) {
        run++;
        continue;
      }
      if (run >= 3) {
        final List<_Line> rows = lines.sublist(i - run, i);
        final double pad = rows.first.size * 0.6;
        found.add(
          Rect4(
            rows.map((_Line l) => l.left).reduce(math.min) - pad,
            rows.first.top + pad,
            rows.map((_Line l) => l.right).reduce(math.max) + pad,
            rows.last.bottom - pad,
          ),
        );
      }
      run = grid ? 1 : 0;
    }
    // Pictures (from ink) take in short labels at their edges: axis
    // numbers and legend entries are text, so they were cleared above.
    final List<bool> picture = <bool>[for (int k = 0; k < found.length; k++) k < pictures];
    // Regions within a few points of each other are one: clearing a cell's
    // text also clears the rule beside it, so a table can arrive in pieces.
    void merge() {
      bool changed = true;
      while (changed) {
        changed = false;
        for (int a = 0; a < found.length && !changed; a++) {
          for (int b = a + 1; b < found.length; b++) {
            if (found[a].inflate(6).overlaps(found[b])) {
              found[a] = found[a].union(found[b]);
              picture[a] = picture[a] || picture[b];
              found.removeAt(b);
              picture.removeAt(b);
              changed = true;
              break;
            }
          }
        }
      }
    }

    merge();
    for (int k = 0; k < found.length; k++) {
      bool grew = true;
      while (grew) {
        grew = false;
        for (final _Line l in lines) {
          final Rect4 box = Rect4(l.left, l.top, l.right, l.bottom);
          if (found[k].contains(box)) continue;
          final bool inside = found[k].holdsMost(l.left, l.top, l.right, l.bottom);
          final bool label =
              picture[k] && l.right - l.left < p.width * 0.3 && found[k].inflate(l.size * 1.5).overlaps(box);
          if (inside || label) {
            found[k] = found[k].union(box);
            grew = true;
          }
        }
      }
    }
    merge();
    // A little air around each, inside the page.
    return <double>[
      for (final Rect4 r in found) ...<double>[
        math.max(0, r.l - 4),
        math.min(p.height, r.t + 4),
        math.min(p.width, r.r + 4),
        math.max(0, r.b - 4),
      ],
    ];
  }

  /// Symbol-font bullets (Wingdings, Symbol) arrive in the private use
  /// area, which reading fonts draw as empty boxes: they read as "•".
  static String _glyph(String ch) {
    final int c = ch.codeUnitAt(0);
    return c >= 0xE000 && c <= 0xF8FF ? '•' : ch;
  }

  static bool _bulleted(String pageText, _Line l) {
    if (l.start >= l.end) return false;
    final int c = pageText.codeUnitAt(l.start);
    return (c >= 0xE000 && c <= 0xF8FF) || '•◦▪‣*·'.contains(pageText[l.start]);
  }

  /// The region [box] (l, t, r, b) as a table, or null when it's a picture.
  ///
  /// Columns and rows come from the table's own rules where it has them
  /// (dark pixel runs across most of the region in [bgra], the page drawn
  /// [w] x [h]), else from the gaps between columns of text and from its
  /// lines. It is a table only when it is text and rules: little other ink,
  /// no colour, and text in at least a third of its cells.
  static PdfTable? tableGrid(PdfPageInput p, List<double> box, Uint8List? bgra, int w, int h) {
    final Rect4 r = Rect4(box[0], box[1], box[2], box[3]);
    final List<int> chars = <int>[
      for (int i = 0; i < p.text.length && i * 4 + 3 < p.rects.length; i++)
        if (p.text[i].trim().isNotEmpty &&
            r.holdsMost(p.rects[i * 4], p.rects[i * 4 + 1], p.rects[i * 4 + 2], p.rects[i * 4 + 3]))
          i,
    ];
    if (chars.length < 6) return null;
    final double size = _median(<double>[for (final int i in chars) p.rects[i * 4 + 1] - p.rects[i * 4 + 3]]);
    final List<double> vRules = <double>[], hRules = <double>[];
    if (bgra != null && w > 0 && h > 0) {
      final double sx = p.width / w, sy = p.height / h;
      final int x0 = (r.l / sx).floor().clamp(0, w - 1), x1 = (r.r / sx).ceil().clamp(0, w - 1);
      final int y0 = ((p.height - r.t) / sy).floor().clamp(0, h - 1),
          y1 = ((p.height - r.b) / sy).ceil().clamp(0, h - 1);
      if (x1 - x0 < 8 || y1 - y0 < 8) return null;
      bool dark(int x, int y) {
        final int i = (y * w + x) * 4;
        return (bgra[i + 2] * 54 + bgra[i + 1] * 183 + bgra[i] * 19) >> 8 < 215;
      }

      int colour = 0;
      for (int y = y0; y <= y1; y += 2) {
        for (int x = x0; x <= x1; x += 2) {
          final int i = (y * w + x) * 4;
          final int hi = math.max(bgra[i], math.max(bgra[i + 1], bgra[i + 2]));
          final int lo = math.min(bgra[i], math.min(bgra[i + 1], bgra[i + 2]));
          if (hi - lo > 40) colour++;
        }
      }
      if (colour > ((x1 - x0) * (y1 - y0) / 4) * 0.02) return null; // a chart or a photo
      List<double> runs(int from, int to, bool Function(int) hit, double Function(double) toPdf) {
        final List<double> out = <double>[];
        int? start;
        for (int k = from; k <= to + 1; k++) {
          final bool on = k <= to && hit(k);
          if (on) start ??= k;
          if (!on && start != null) {
            out.add(toPdf((start + k - 1) / 2));
            start = null;
          }
        }
        return out;
      }

      vRules.addAll(
        runs(x0, x1, (int x) {
          int n = 0;
          for (int y = y0; y <= y1; y++) {
            if (dark(x, y)) n++;
          }
          return n > (y1 - y0) * 0.8;
        }, (double x) => x * sx),
      );
      hRules.addAll(
        runs(y0, y1, (int y) {
          int n = 0;
          for (int x = x0; x <= x1; x++) {
            if (dark(x, y)) n++;
          }
          return n > (x1 - x0) * 0.8;
        }, (double y) => p.height - y * sy),
      );
      // Other ink (not text, not rules) means a picture.
      int other = 0, total = 0;
      bool nearRule(int x, int y) =>
          vRules.any((double v) => (v / sx - x).abs() < 2) ||
          hRules.any((double v) => ((p.height - v) / sy - y).abs() < 2);
      for (int y = y0; y <= y1; y += 2) {
        for (int x = x0; x <= x1; x += 2) {
          total++;
          if (!dark(x, y) || nearRule(x, y)) continue;
          final double px = x * sx, py = p.height - y * sy;
          final bool text = chars.any(
            (int i) =>
                px >= p.rects[i * 4] - 1.5 &&
                px <= p.rects[i * 4 + 2] + 1.5 &&
                py <= p.rects[i * 4 + 1] + 1.5 &&
                py >= p.rects[i * 4 + 3] - 1.5,
          );
          if (!text) other++;
        }
      }
      if (other > total * 0.03) return null;
    }
    double cy(int i) => (p.rects[i * 4 + 1] + p.rects[i * 4 + 3]) / 2;
    final double tl = chars.map((int i) => p.rects[i * 4]).reduce(math.min) - 1;
    final double tr = chars.map((int i) => p.rects[i * 4 + 2]).reduce(math.max) + 1;
    final double tt = chars.map((int i) => p.rects[i * 4 + 1]).reduce(math.max) + 1;
    final double tb = chars.map((int i) => p.rects[i * 4 + 3]).reduce(math.min) - 1;
    // Columns: the rules, else the gaps no character crosses.
    List<double> xs;
    if (vRules.length >= 2) {
      xs = vRules;
    } else {
      final List<(double, double)> spans = <(double, double)>[
        for (final int i in chars) (p.rects[i * 4], p.rects[i * 4 + 2]),
      ]..sort(((double, double) a, (double, double) b) => a.$1.compareTo(b.$1));
      xs = <double>[];
      double reach = spans.first.$2;
      for (final (double l, double rr) in spans.skip(1)) {
        if (l - reach > size * 0.9) xs.add((l + reach) / 2);
        reach = math.max(reach, rr);
      }
    }
    // Rows: the rules, else the lines of text.
    List<double> ys;
    if (hRules.length >= 2) {
      ys = hRules;
    } else {
      final List<double> centres = chars.map(cy).toList()..sort((double a, double b) => b.compareTo(a));
      ys = <double>[];
      for (int k = 1; k < centres.length; k++) {
        if (centres[k - 1] - centres[k] > size * 0.8) ys.add((centres[k - 1] + centres[k]) / 2);
      }
    }
    xs = <double>[
      if (xs.isEmpty || xs.first > tl) math.min(tl, xs.firstOrNull ?? tl),
      ...xs,
      if (xs.isEmpty || xs.last < tr) math.max(tr, xs.lastOrNull ?? tr),
    ];
    ys = <double>[
      if (ys.isEmpty || ys.first < tt) math.max(tt, ys.firstOrNull ?? tt),
      ...ys,
      if (ys.isEmpty || ys.last > tb) math.min(tb, ys.lastOrNull ?? tb),
    ];
    xs.sort();
    ys.sort((double a, double b) => b.compareTo(a));
    final PdfTable t = PdfTable(xs, ys);
    final List<List<List<int>>> cells = _cells(p, t, chars);
    final int filled = cells.fold<int>(
      0,
      (int n, List<List<int>> row) => n + row.where((List<int> c) => c.isNotEmpty).length,
    );
    final int rows = cells.where((List<List<int>> row) => row.any((List<int> c) => c.isNotEmpty)).length;
    final int cols = xs.length - 1;
    if (rows < 2 || cols < 2 || filled < 3 || filled < rows * cols / 3) return null;
    // Text that crosses a column edge: not a grid after all.
    for (final int i in chars) {
      if (xs.skip(1).take(cols - 1).any((double x) => p.rects[i * 4] < x - 0.5 && p.rects[i * 4 + 2] > x + 0.5)) {
        return null;
      }
    }
    return t;
  }

  /// Character indices of [chars] by row and column of [t].
  static List<List<List<int>>> _cells(PdfPageInput p, PdfTable t, List<int> chars) {
    final List<List<List<int>>> out = <List<List<int>>>[
      for (int r = 0; r < t.ys.length - 1; r++) <List<int>>[for (int c = 0; c < t.xs.length - 1; c++) <int>[]],
    ];
    for (final int i in chars) {
      final double x = (p.rects[i * 4] + p.rects[i * 4 + 2]) / 2, y = (p.rects[i * 4 + 1] + p.rects[i * 4 + 3]) / 2;
      int r = -1, c = -1;
      for (int k = 0; k < t.ys.length - 1; k++) {
        if (y <= t.ys[k] && y > t.ys[k + 1]) r = k;
      }
      for (int k = 0; k < t.xs.length - 1; k++) {
        if (x >= t.xs[k] && x < t.xs[k + 1]) c = k;
      }
      if (r >= 0 && c >= 0) out[r][c].add(i);
    }
    return out;
  }

  /// A table block: each cell's text in reading order, words spaced, empty
  /// rows and columns dropped, and a character map back to the page.
  static Block? _tableBlock(PdfPageInput p, int page, PdfTable t) {
    final List<int> chars = <int>[
      for (int i = 0; i < p.text.length && i * 4 + 3 < p.rects.length; i++)
        if (p.text[i].trim().isNotEmpty &&
            t.box.holdsMost(p.rects[i * 4], p.rects[i * 4 + 1], p.rects[i * 4 + 2], p.rects[i * 4 + 3]))
          i,
    ];
    final List<List<List<int>>> grid = _cells(p, t, chars);
    final List<int> keepCols = <int>[
      for (int c = 0; c < t.xs.length - 1; c++)
        if (grid.any((List<List<int>> row) => row[c].isNotEmpty)) c,
    ];
    final List<List<List<int>>> rowsIdx = <List<List<int>>>[
      for (final List<List<int>> row in grid)
        if (row.any((List<int> c) => c.isNotEmpty)) <List<int>>[for (final int c in keepCols) row[c]..sort()],
    ];
    if (rowsIdx.isEmpty) return null;
    final List<List<String>> rows = <List<String>>[];
    final List<int> map = <int>[];
    for (int r = 0; r < rowsIdx.length; r++) {
      final List<String> row = <String>[];
      for (int c = 0; c < rowsIdx[r].length; c++) {
        final StringBuffer cell = StringBuffer();
        int? last;
        for (final int i in rowsIdx[r][c]) {
          // Spaces and line breaks aren't in the cell, so anything between
          // this character and the last one on the page is a word break.
          if (last != null && i != last + 1) {
            cell.write(' ');
            map.add(-1);
          }
          cell.write(_glyph(p.text[i]));
          map.add(page * SourceRef.kPage + i);
          last = i;
        }
        row.add(cell.toString());
        if (c < rowsIdx[r].length - 1) map.add(-1); // the tab
      }
      rows.add(row);
      if (r < rowsIdx.length - 1) map.add(-1); // the newline
    }
    return Block(
      kind: BlockKind.table,
      rows: rows,
      source: SourceRef(page: page, charMap: map),
    );
  }

  /// A table that carries on from the one just before it, over a page
  /// break: same columns, nothing between them (running heads are gone).
  static bool _continues(Block prev, Block t) =>
      prev.kind == BlockKind.table &&
      prev.rows!.first.length == t.rows!.first.length &&
      t.source!.page == prev.source!.lastPage + 1;

  /// One table from both, so the second page's first row isn't drawn as a
  /// header. A header repeated at the top of the second page is dropped.
  static Block _joinTables(Block prev, Block t) {
    final List<int> map = t.source!.charMap!;
    List<List<String>> rows = t.rows!;
    int from = 0;
    if (rows.length > 1 && rows.first.join('\t') == prev.rows!.first.join('\t')) {
      // The repeated row's text and its newline.
      from = rows.first.fold<int>(0, (int n, String c) => n + c.length) + rows.first.length;
      rows = rows.sublist(1);
    }
    return Block(
      kind: BlockKind.table,
      rows: <List<String>>[...prev.rows!, ...rows],
      source: SourceRef(page: prev.source!.page, charMap: <int>[...prev.source!.charMap!, -1, ...map.sublist(from)]),
    );
  }

  /// Wide gaps between neighbouring glyphs on a line: column breaks.
  static int _gaps(PdfPageInput p, _Line l) {
    int gaps = 0;
    double? lastRight;
    for (int i = l.start; i < l.end && i * 4 + 3 < p.rects.length; i++) {
      if (p.text[i].trim().isEmpty) continue;
      final double left = p.rects[i * 4];
      if (lastRight != null && left - lastRight > l.size * 1.6) gaps++;
      lastRight = p.rects[i * 4 + 2];
    }
    return gaps;
  }

  static ReadingDocument analyse(
    List<PdfPageInput> pages, {
    required String title,
    String? author,
    Map<String, Uint8List> images = const <String, Uint8List>{},
  }) {
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
    // Tables: their text leaves the flow; a table block takes the place of
    // the first line below its top.
    for (int i = 0; i < perPage.length; i++) {
      for (final PdfTable t in pages[i].tables) {
        final Rect4 box = t.box;
        final List<_Line> inside = perPage[i]
            .where((_Line l) => l.region == null && l.table == null && box.holdsMost(l.left, l.top, l.right, l.bottom))
            .toList();
        perPage[i].removeWhere(inside.contains);
        final int at = perPage[i].indexWhere((_Line l) => l.region == null && l.table == null && l.top < box.t);
        perPage[i].insert(
          at < 0 ? perPage[i].length : at,
          _Line(i + 1, 0, 0, '', box.l, box.t, box.r, box.b, 0)..table = t,
        );
      }
    }
    // Figures: their text leaves the flow; the picture takes the
    // place of the first line below its top.
    for (int i = 0; i < perPage.length; i++) {
      final List<double> r = pages[i].regions;
      for (int k = 0; k + 3 < r.length; k += 4) {
        final String key = regionKey(i + 1, k ~/ 4);
        if (!images.containsKey(key)) continue;
        final Rect4 box = Rect4(r[k], r[k + 1], r[k + 2], r[k + 3]);
        final List<_Line> inside = perPage[i]
            .where((_Line l) => l.region == null && box.holdsMost(l.left, l.top, l.right, l.bottom))
            .toList();
        perPage[i].removeWhere(inside.contains);
        final int at = perPage[i].indexWhere((_Line l) => l.region == null && l.top < box.t);
        // Anchored at the first character in it (a label), else the line
        // after it, so positions on a picture map back to its place.
        inside.sort((_Line a, _Line b) => b.top.compareTo(a.top));
        final int anchor = inside.firstOrNull?.start ?? (at < 0 ? 0 : perPage[i][at].start);
        perPage[i].insert(
          at < 0 ? perPage[i].length : at,
          _Line(i + 1, anchor, anchor, '', box.l, box.t, box.r, box.b, 0)..region = key,
        );
        simplified = true;
      }
    }
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
    final List<_Line> textLines = all.where((_Line l) => l.region == null && l.table == null).toList();
    final double body = _median(textLines.map((_Line l) => l.size).toList());
    final List<double> gaps = <double>[];
    for (int i = 1; i < textLines.length; i++) {
      final _Line a = textLines[i - 1], b = textLines[i];
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
      if (line.table != null) {
        flush();
        final Block? t = _tableBlock(pages[line.page - 1], line.page, line.table!);
        final Block? last = blocks.lastOrNull;
        if (t != null && last != null && _continues(last, t)) {
          blocks[blocks.length - 1] = _joinTables(last, t);
        } else if (t != null) {
          blocks.add(t);
        }
        prev = null;
        continue;
      }
      if (line.region != null) {
        flush();
        blocks.add(
          Block(
            kind: BlockKind.image,
            image: line.region,
            source: SourceRef(page: line.page, start: line.start, end: line.start),
          ),
        );
        prev = null;
        continue;
      }
      final (double colLeft, double colRight) = columns.putIfAbsent((
        line.page,
        line.column,
      ), () => (_columnLeft(perPage[line.page - 1], line.column), _columnRight(perPage[line.page - 1], line.column)));
      final double colWidth = math.max(1, colRight - colLeft);
      final bool large = line.size > body * 1.25;
      final double centre = (line.left + line.right) / 2;
      final bool centred =
          (centre - (colLeft + colRight) / 2).abs() < colWidth * 0.06 && (line.right - line.left) < colWidth * 0.75;
      final bool bulleted = _bulleted(pages[line.page - 1].text, line);
      final bool headingLike =
          !bulleted &&
          (large ||
              (centred &&
                  line.text.length < 70 &&
                  !RegExp(r'[,;]$').hasMatch(line.text) &&
                  line.text.split(' ').length < 10));
      // A list item's wrapped lines hang under its text.
      final bool hanging = kind == BlockKind.listItem && !bulleted && line.left > colLeft + body * 0.7;
      final BlockKind lineKind = headingLike
          ? BlockKind.heading
          : (bulleted || hanging ? BlockKind.listItem : BlockKind.paragraph);

      bool breakBefore = prev == null;
      if (prev != null) {
        final bool samePlace = prev.page == line.page && prev.column == line.column;
        final double vgap = samePlace ? prev.bottom - line.top : 0;
        final bool bigGap = samePlace && vgap > gap * 1.8 + body * 0.35;
        // A list item's wrapped lines hang under its text, not a new paragraph.
        final bool indented =
            line.left > colLeft + body * 0.7 && !centred && !(kind == BlockKind.listItem && !bulleted);
        final bool prevShort = prev.right < colRight - body * 2.5 && RegExp(r'[.!?:"”’)]$').hasMatch(prev.text);
        final bool kindChange = lineKind != kind || (headingLike && (prev.size - line.size).abs() > body * 0.15);
        breakBefore =
            bigGap || indented || (prevShort && !hanging) || kindChange || bulleted || (headingLike && !samePlace);
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
        level = headingLike ? (line.size > body * 1.25 ? 1 : 3) : (bulleted ? 1 : 0);
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
      int from = line.start;
      if (bulleted && breakBefore) {
        // The engine draws the bullet; the text starts after it.
        from++;
        while (from < line.end && src[from].trim().isEmpty) {
          from++;
        }
      }
      for (int i = from; i < line.end; i++) {
        final String ch = src[i];
        if (ch == '\r' || ch == '\n') continue;
        text.write(_glyph(ch));
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
      resources: images,
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
    final List<double> lefts =
        lines
            .where((_Line l) => l.column == column && l.region == null && l.table == null)
            .map((_Line l) => l.left)
            .toList()
          ..sort();
    return lefts.isEmpty ? 0 : lefts[lefts.length ~/ 10];
  }

  static double _columnRight(List<_Line> lines, int column) {
    final List<double> rights =
        lines
            .where((_Line l) => l.column == column && l.region == null && l.table == null)
            .map((_Line l) => l.right)
            .toList()
          ..sort();
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

/// A rectangle in PDF units (top above bottom).
class Rect4 {
  const Rect4(this.l, this.t, this.r, this.b);

  final double l, t, r, b;

  bool overlaps(Rect4 o) => l < o.r && o.l < r && b < o.t && o.b < t;

  bool contains(Rect4 o) => o.l >= l && o.r <= r && o.t <= t && o.b >= b;

  Rect4 inflate(double d) => Rect4(l - d, t + d, r + d, b - d);

  Rect4 union(Rect4 o) => Rect4(math.min(l, o.l), math.max(t, o.t), math.max(r, o.r), math.min(b, o.b));

  /// Most of the box (l, t, r, b) lies inside this one.
  bool holdsMost(double l2, double t2, double r2, double b2) {
    final double w = math.min(r, r2) - math.max(l, l2), h = math.min(t, t2) - math.max(b, b2);
    if (w <= 0 || h <= 0) return false;
    return w * h >= 0.6 * math.max(1e-6, (r2 - l2) * (t2 - b2));
  }
}
