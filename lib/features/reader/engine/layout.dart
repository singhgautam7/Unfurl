import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../formats/reading_document.dart';
import 'reader_style.dart';

/// A laid-out piece of one block on one page: a run of its text (between
/// [start] and [end]), an image, a rule, or some rows of a table. Text
/// fragments keep their [TextPainter] and a map from block offsets to the
/// painter's own offsets (indent and soft hyphens shift them), so selection,
/// highlights and hit tests are exact.
class Fragment {
  Fragment({
    required this.section,
    required this.blockIndex,
    required this.block,
    required this.start,
    required this.end,
    required this.rect,
    this.painter,
    this.map,
    this.rowStart = 0,
    this.rowEnd = 0,
    this.columnWidths,
    this.rowHeights,
    this.bulletPainter,
    this.hyphens = const <Offset>[],
    this.hyphenPainter,
  });

  final int section;
  final int blockIndex;
  final Block block;

  /// Block text range on this fragment.
  final int start;
  final int end;

  /// Where it sits on the page (content coordinates).
  final Rect rect;
  final TextPainter? painter;

  /// Block offset minus [start], to painter offset.
  final List<int>? map;

  /// Table rows on this fragment.
  final int rowStart;
  final int rowEnd;
  final List<double>? columnWidths;
  final List<double>? rowHeights;

  /// A list item's bullet or number.
  final TextPainter? bulletPainter;

  /// Where a line ends at a soft hyphen, the hyphen to draw (the painter
  /// breaks there but draws nothing), in fragment coordinates at the
  /// baseline. It hangs into the margin, as in hand-set books.
  final List<Offset> hyphens;
  final TextPainter? hyphenPainter;

  void paintText(Canvas canvas) {
    painter?.paint(canvas, rect.topLeft);
    final TextPainter? h = hyphenPainter;
    if (h == null) return;
    final double ascent = h.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    for (final Offset o in hyphens) {
      h.paint(canvas, rect.topLeft + Offset(o.dx, o.dy - ascent));
    }
  }

  bool get isText => painter != null;

  int _toPainter(int offset) {
    final List<int> m = map!;
    return m[(offset - start).clamp(0, m.length - 1)];
  }

  int _fromPainter(int p) {
    final List<int> m = map!;
    int lo = 0, hi = m.length - 1;
    while (lo < hi) {
      final int mid = (lo + hi + 1) >> 1;
      if (m[mid] <= p) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return start + lo;
  }

  /// Rectangles covering block offsets [a, b) on this fragment, in page
  /// coordinates.
  List<Rect> boxes(int a, int b) {
    if (!isText) {
      return a <= start && b >= end && end > start ? <Rect>[rect] : const <Rect>[];
    }
    final int s = math.max(a, start), e = math.min(b, end);
    if (s >= e) return const <Rect>[];
    return <Rect>[
      for (final TextBox box in painter!.getBoxesForSelection(
        TextSelection(baseOffset: _toPainter(s), extentOffset: _toPainter(e)),
      ))
        box.toRect().shift(rect.topLeft),
    ];
  }

  /// The block offset under a page point, or null outside this fragment.
  int? offsetAt(Offset page, {bool clamp = false}) {
    if (!isText) return null;
    if (!clamp && !rect.inflate(4).contains(page)) return null;
    final Offset local = page - rect.topLeft;
    final TextPosition p = painter!.getPositionForOffset(
      Offset(local.dx.clamp(0, rect.width), local.dy.clamp(0, rect.height)),
    );
    return _fromPainter(p.offset).clamp(start, end);
  }

  /// The link under a page point.
  String? linkAt(Offset page) {
    final int? o = offsetAt(page);
    if (o == null) return null;
    int at = 0;
    for (final Inline r in block.runs) {
      if (o >= at && o < at + r.text.length) return r.href;
      at += r.text.length;
    }
    return null;
  }

  /// Top of the line holding block offset [offset], page coordinates.
  double lineTopOf(int offset) {
    if (!isText) return rect.top;
    final List<Rect> b = boxes(offset, math.min(offset + 1, end));
    return b.isEmpty ? rect.top : b.first.top;
  }

  void dispose() {
    painter?.dispose();
    bulletPainter?.dispose();
    hyphenPainter?.dispose();
  }
}

/// One page: its fragments, top to bottom.
class ReaderPage {
  ReaderPage(this.fragments);

  final List<Fragment> fragments;

  Fragment? get firstText => fragments.where((Fragment f) => f.isText).firstOrNull;

  /// The page's first position (section, block, offset).
  (int, int, int) get first =>
      fragments.isEmpty ? (0, 0, 0) : (fragments.first.section, fragments.first.blockIndex, fragments.first.start);

  (int, int, int) get last =>
      fragments.isEmpty ? (0, 0, 0) : (fragments.last.section, fragments.last.blockIndex, fragments.last.end);

  /// Whether the page shows (section, block, offset).
  bool contains(int s, int b, int o) {
    for (final Fragment f in fragments) {
      if (f.section == s &&
          f.blockIndex == b &&
          o >= f.start &&
          (o < f.end || (o == f.end && f.end == f.block.text.length))) {
        return true;
      }
    }
    return false;
  }

  /// Every rect covering the global range [from, to) given as positions.
  List<Rect> boxes(ReadingDocument doc, (int, int, int) from, (int, int, int) to) {
    final int a = doc.sections[from.$1].blocks[from.$2].start + from.$3;
    final int b = doc.sections[to.$1].blocks[to.$2].start + to.$3;
    final List<Rect> out = <Rect>[];
    for (final Fragment f in fragments) {
      final int base = f.block.start;
      if (base + f.end < a || base + f.start > b) continue;
      out.addAll(f.boxes((a - base).clamp(0, f.block.text.length), (b - base).clamp(0, f.block.text.length)));
    }
    return out;
  }

  void dispose() {
    for (final Fragment f in fragments) {
      f.dispose();
    }
  }
}

/// Image sizes, read from the encoded header without a full decode.
class ImageSizes {
  final Map<String, Size> _sizes = <String, Size>{};

  Size? operator [](String key) => _sizes[key];

  Future<void> load(Map<String, Uint8List> resources, Iterable<String> keys) async {
    for (final String k in keys) {
      if (_sizes.containsKey(k) || resources[k] == null) continue;
      try {
        final ui.ImmutableBuffer buf = await ui.ImmutableBuffer.fromUint8List(resources[k]!);
        final ui.ImageDescriptor d = await ui.ImageDescriptor.encoded(buf);
        _sizes[k] = Size(d.width.toDouble(), d.height.toDouble());
        d.dispose();
        buf.dispose();
      } catch (_) {
        _sizes[k] = Size.zero;
      }
    }
  }
}

/// Lays sections out into pages of a given size and style.
class Layout {
  Layout({required this.doc, required this.style, required this.pageSize, required this.images});

  final ReadingDocument doc;
  final ReaderStyle style;

  /// The text area of one page (or column).
  final Size pageSize;
  final ImageSizes images;

  /// Pages per section; null until laid out.
  late final List<List<ReaderPage>?> sections = List<List<ReaderPage>?>.filled(doc.sections.length, null);

  bool get complete => !sections.contains(null);

  int get knownPages => sections.fold<int>(0, (int n, List<ReaderPage>? s) => n + (s?.length ?? 0));

  /// Global page index of a section's first page (counting laid-out
  /// sections only).
  int firstPageOf(int section) {
    int n = 0;
    for (int i = 0; i < section; i++) {
      n += sections[i]?.length ?? 0;
    }
    return n;
  }

  (int, int) sectionPageOf(int global) {
    int n = global;
    for (int s = 0; s < sections.length; s++) {
      final int len = sections[s]?.length ?? 0;
      if (n < len) return (s, n);
      n -= len;
    }
    final int last = sections.lastIndexWhere((List<ReaderPage>? p) => p != null && p.isNotEmpty);
    return (math.max(0, last), math.max(0, (sections.elementAtOrNull(last)?.length ?? 1) - 1));
  }

  ReaderPage? page(int global) {
    final (int s, int p) = sectionPageOf(global);
    return sections[s]?.elementAtOrNull(p);
  }

  /// The global page holding a position, laying its section out first.
  int pageOf(int section, int block, int offset) {
    ensure(section);
    final List<ReaderPage> pages = sections[section]!;
    for (int i = 0; i < pages.length; i++) {
      if (pages[i].contains(section, block, offset)) return firstPageOf(section) + i;
      final (int ls, int lb, int lo) = pages[i].last;
      if (ls == section && (lb > block || (lb == block && lo > offset))) return firstPageOf(section) + i;
    }
    return firstPageOf(section) + math.max(0, pages.length - 1);
  }

  void ensure(int section) {
    sections[section] ??= _paginate(section);
  }

  /// Lays out the next section not yet done; false when all are.
  bool layoutNext(int around) {
    for (int d = 0; d < sections.length; d++) {
      for (final int s in <int>[around + d, around - d]) {
        if (s >= 0 && s < sections.length && sections[s] == null) {
          sections[s] = _paginate(s);
          return true;
        }
      }
    }
    return false;
  }

  void dispose() {
    for (final List<ReaderPage>? pages in sections) {
      for (final ReaderPage p in pages ?? const <ReaderPage>[]) {
        p.dispose();
      }
    }
  }

  // ------------------------------------------------------------ pagination

  List<ReaderPage> _paginate(int s) {
    final List<Block> blocks = doc.sections[s].blocks;
    final double w = pageSize.width, h = pageSize.height;
    final List<ReaderPage> pages = <ReaderPage>[];
    List<Fragment> cur = <Fragment>[];
    double y = 0;

    void newPage() {
      if (cur.isNotEmpty) pages.add(ReaderPage(cur));
      cur = <Fragment>[];
      y = 0;
    }

    for (int i = 0; i < blocks.length; i++) {
      final Block b = blocks[i];
      final Block? prev = i > 0 ? blocks[i - 1] : null;
      double gap() => cur.isEmpty ? 0 : style.spaceBefore(b, prev);
      switch (b.kind) {
        case BlockKind.image:
          final Size? natural = images[b.image ?? ''];
          if (natural == null || natural.isEmpty) continue;
          final double scale = math.min(1, math.min(w / natural.width, h * 0.8 / natural.height));
          final Size size = Size(natural.width * scale * math.min(1, 1.6), natural.height * scale);
          final Size fit = Size(math.min(w, size.width), size.height);
          if (y + gap() + fit.height > h && cur.isNotEmpty) newPage();
          y += gap();
          cur.add(
            Fragment(
              section: s,
              blockIndex: i,
              block: b,
              start: 0,
              end: b.text.length,
              rect: Rect.fromLTWH((w - fit.width) / 2, y, fit.width, fit.height),
            ),
          );
          y += fit.height;
        case BlockKind.rule:
          final double rh = style.size * 1.2;
          if (y + gap() + rh > h && cur.isNotEmpty) newPage();
          y += gap();
          cur.add(Fragment(section: s, blockIndex: i, block: b, start: 0, end: 0, rect: Rect.fromLTWH(0, y, w, rh)));
          y += rh;
        case BlockKind.table:
          _table(s, i, b, gap(), () => y, (double v) => y = v, cur, newPage, w, h);
        default:
          int from = 0;
          bool first = true;
          while (true) {
            final double g = first ? gap() : 0;
            final double inset = style.insetFor(b);
            final Fragment probe = _text(
              s,
              i,
              b,
              from,
              b.text.length,
              Offset(inset, 0),
              w - inset,
              first ? style.indentFor(b, prev) : 0,
              bullet: first,
            );
            final TextPainter tp = probe.painter!;
            final double ph = tp.height + (b.kind == BlockKind.code ? 20 : 0);
            if (y + g + ph <= h + 0.5) {
              cur.add(_place(probe, y + g + (b.kind == BlockKind.code ? 10 : 0)));
              y += g + ph;
              break;
            }
            // Split at a line: never a heading, keep two lines together.
            final List<ui.LineMetrics> lines = tp.computeLineMetrics();
            final double avail = h - y - g;
            int fit = 0;
            double used = 0;
            for (final ui.LineMetrics l in lines) {
              if (used + l.height > avail) break;
              used += l.height;
              fit++;
            }
            if (b.kind == BlockKind.heading ||
                b.kind == BlockKind.code ||
                fit < 2 ||
                lines.length - fit < 2 && lines.length > 2) {
              if (lines.length - fit < 2 && fit >= 2 && lines.length > 3) {
                fit = lines.length - 2;
              } else if (cur.isNotEmpty) {
                probe.dispose();
                newPage();
                continue;
              } else if (fit == 0) {
                fit = math.max(1, lines.length - 1);
              }
            }
            if (fit >= lines.length) {
              cur.add(_place(probe, y + g));
              y += g + ph;
              break;
            }
            final ui.LineMetrics next = lines[fit];
            final TextPosition pos = tp.getPositionForOffset(Offset(1, next.baseline - next.ascent / 2));
            final int split = probe._fromPainter(tp.getLineBoundary(pos).start).clamp(from + 1, b.text.length);
            probe.dispose();
            final Fragment part = _text(
              s,
              i,
              b,
              from,
              split,
              Offset(inset, 0),
              w - inset,
              first ? style.indentFor(b, prev) : 0,
              bullet: first,
            );
            cur.add(_place(part, y + g));
            newPage();
            from = split;
            first = false;
            while (from < b.text.length && b.text[from] == ' ') {
              from++;
            }
            if (from >= b.text.length) break;
          }
      }
      if (y >= h - 0.5) newPage();
    }
    newPage();
    if (pages.isEmpty) pages.add(ReaderPage(<Fragment>[]));
    return pages;
  }

  Fragment _place(Fragment f, double y) => Fragment(
    section: f.section,
    blockIndex: f.blockIndex,
    block: f.block,
    start: f.start,
    end: f.end,
    rect: f.rect.shift(Offset(0, y)),
    painter: f.painter,
    map: f.map,
    bulletPainter: f.bulletPainter,
    hyphens: f.hyphens,
    hyphenPainter: f.hyphenPainter,
  );

  void _table(
    int s,
    int i,
    Block b,
    double gap,
    double Function() getY,
    void Function(double) setY,
    List<Fragment> cur,
    VoidCallback newPage,
    double w,
    double h,
  ) {
    final List<List<String>> rows = b.rows!;
    final int cols = rows.fold<int>(0, (int m, List<String> r) => math.max(m, r.length));
    if (cols == 0) return;
    final List<int> weight = List<int>.filled(cols, 1);
    for (final List<String> r in rows) {
      for (int c = 0; c < r.length; c++) {
        weight[c] = math.max(weight[c], math.min(30, r[c].length));
      }
    }
    final int total = weight.fold<int>(0, (int a, int x) => a + x);
    final List<double> widths = <double>[for (final int x in weight) w * x / total];
    final TextStyle st = style.styleFor(b);
    final List<double> heights = <double>[
      for (int r = 0; r < rows.length; r++)
        rows[r].asMap().entries.fold<double>(style.size * 0.9, (double m, MapEntry<int, String> e) {
          final TextPainter tp = TextPainter(
            text: TextSpan(
              text: e.value,
              style: r == 0 ? st.copyWith(fontWeight: FontWeight.w600) : st,
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: math.max(1, widths[e.key] - 8));
          final double hh = tp.height + 10;
          tp.dispose();
          return math.max(m, hh);
        }),
    ];
    int r0 = 0;
    double y = getY();
    while (r0 < rows.length) {
      final double g = cur.isEmpty ? 0 : gap;
      double used = 0;
      int r1 = r0;
      while (r1 < rows.length && y + g + used + heights[r1] <= h) {
        used += heights[r1];
        r1++;
      }
      if (r1 == r0) {
        if (cur.isNotEmpty) {
          newPage();
          y = 0;
          continue;
        }
        used = heights[r0];
        r1 = r0 + 1;
      }
      cur.add(
        Fragment(
          section: s,
          blockIndex: i,
          block: b,
          start: 0,
          end: b.text.length,
          rect: Rect.fromLTWH(0, y + g, w, used),
          rowStart: r0,
          rowEnd: r1,
          columnWidths: widths,
          rowHeights: heights.sublist(r0, r1),
        ),
      );
      y += g + used;
      r0 = r1;
      if (r0 < rows.length) {
        newPage();
        y = 0;
      }
    }
    setY(y);
  }

  /// A text fragment of [b] from [from] to [to], laid out at [width].
  Fragment _text(
    int s,
    int i,
    Block b,
    int from,
    int to,
    Offset origin,
    double width,
    double indent, {
    required bool bullet,
  }) {
    final TextStyle base = style.styleFor(b);
    final List<InlineSpan> spans = <InlineSpan>[];
    final List<int> map = List<int>.filled(to - from + 1, 0);
    int render = 0;
    if (indent > 0) {
      // An empty placeholder as wide as the indent: one offset, like a
      // character, and counted when lines are broken.
      spans.add(const WidgetSpan(child: SizedBox.shrink()));
      render = 1;
    }
    int at = 0;
    for (final Inline run in b.runs) {
      final int rs = at, re = at + run.text.length;
      at = re;
      final int s0 = math.max(rs, from), e0 = math.min(re, to);
      if (s0 >= e0) continue;
      final String slice = run.text.substring(s0 - rs, e0 - rs);
      final bool hyph = style.hyphenate && b.kind == BlockKind.paragraph && !run.mono;
      final (String text, List<int> m) = hyph
          ? Hyphenator.apply(slice)
          : (slice, List<int>.generate(slice.length + 1, (int k) => k));
      for (int k = 0; k < slice.length; k++) {
        map[s0 - from + k] = render + m[k];
      }
      spans.add(TextSpan(text: text, style: _runStyle(base, run)));
      render += text.length;
      map[e0 - from] = render;
    }
    for (int k = 1; k < map.length; k++) {
      if (map[k] < map[k - 1]) map[k] = map[k - 1];
    }
    final bool strut = b.kind == BlockKind.paragraph || b.kind == BlockKind.quote || b.kind == BlockKind.listItem;
    final TextPainter tp = TextPainter(
      text: TextSpan(children: spans, style: base),
      textAlign: style.alignFor(b),
      textDirection: TextDirection.ltr,
      strutStyle: strut ? StrutStyle.fromTextStyle(base, forceStrutHeight: true) : null,
    );
    if (indent > 0) {
      tp.setPlaceholderDimensions(<PlaceholderDimensions>[
        PlaceholderDimensions(size: Size(indent, 0), alignment: PlaceholderAlignment.bottom),
      ]);
    }
    tp.layout(maxWidth: math.max(1, width));
    final List<Offset> hyphens = <Offset>[];
    final String plain = tp.plainText;
    if (plain.contains('\u00AD')) {
      for (final ui.LineMetrics l in tp.computeLineMetrics()) {
        final TextRange r = tp.getLineBoundary(
          tp.getPositionForOffset(Offset(l.left + l.width / 2, l.baseline - l.ascent / 2)),
        );
        if (r.end < 2 || r.end > plain.length || plain.codeUnitAt(r.end - 1) != 0xAD) continue;
        final List<TextBox> last = tp.getBoxesForSelection(
          TextSelection(baseOffset: r.end - 2, extentOffset: r.end - 1),
        );
        if (last.isNotEmpty) hyphens.add(Offset(last.last.right, l.baseline));
      }
    }
    TextPainter? bulletPainter;
    if (bullet && b.kind == BlockKind.listItem && b.checked == null) {
      bulletPainter = TextPainter(
        text: TextSpan(
          text: b.ordinal != null ? '${b.ordinal}.' : '•',
          style: base.copyWith(color: style.theme.inkMuted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    return Fragment(
      section: s,
      blockIndex: i,
      block: b,
      start: from,
      end: to,
      rect: Rect.fromLTWH(origin.dx, origin.dy, width, tp.height),
      painter: tp,
      map: map,
      bulletPainter: bulletPainter,
      hyphens: hyphens,
      hyphenPainter: hyphens.isEmpty
          ? null
          : (TextPainter(
              text: TextSpan(text: '-', style: base),
              textDirection: TextDirection.ltr,
            )..layout()),
    );
  }

  TextStyle _runStyle(TextStyle base, Inline r) {
    TextStyle t = base;
    if (r.bold) {
      t = t.copyWith(fontWeight: FontWeight.w700, fontVariations: const <FontVariation>[FontVariation('wght', 700)]);
    }
    if (r.italic) t = t.copyWith(fontStyle: FontStyle.italic);
    if (r.mono) t = t.copyWith(fontFamily: 'monospace', fontSize: (base.fontSize ?? 16) * 0.88);
    if (r.small) t = t.copyWith(fontSize: (base.fontSize ?? 16) * 0.72);
    if (r.href != null) {
      t = t.copyWith(
        color: style.theme.accentText,
        decoration: TextDecoration.underline,
        decorationColor: style.theme.accentText,
      );
    }
    return t;
  }
}
