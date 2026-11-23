import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../formats/reading_document.dart';
import 'reader_style.dart';

/// One table cell on a fragment: its text laid out at the column width, where
/// it sits (fragment coordinates), and where its text starts in the block.
class TableCell {
  TableCell({required this.painter, required this.rect, required this.start, required this.length});

  final TextPainter painter;

  /// The text's own box inside the fragment (padding excluded).
  final Rect rect;
  final int start;
  final int length;

  int get end => start + length;
}

/// A fragment's laid-out text: the painter, the map from block offsets to its
/// own (indent and soft hyphens shift them), the bullet and the hyphens.
class FragmentText {
  FragmentText({required this.painter, required this.map, this.bullet, this.hyphens = const <Offset>[], this.hyphen});

  final TextPainter painter;
  final List<int> map;
  final TextPainter? bullet;
  final List<Offset> hyphens;
  final TextPainter? hyphen;

  void dispose() {
    painter.dispose();
    bullet?.dispose();
    hyphen?.dispose();
  }
}

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
    this._text,
    this.lay,
    this.rowStart = 0,
    this.rowEnd = 0,
    this.columnWidths,
    this.rowHeights,
    this.cells,
    this.scroll,
  });

  final int section;
  final int blockIndex;
  final Block block;

  /// Block text range on this fragment.
  final int start;
  final int end;

  /// Where it sits on the page (content coordinates).
  final Rect rect;

  /// Lays the text out again (see [release]); null when there is no text.
  /// Laying out the same text at the same width gives the same lines.
  final FragmentText Function(Fragment f)? lay;

  /// Null while released. A book keeps where its pages break, not every
  /// painter: 200,000 words of them took 450 MB.
  FragmentText? _text;

  FragmentText? get _laid => _text ??= lay?.call(this);

  TextPainter? get painter => _laid?.painter;

  /// Block offset minus [start], to painter offset.
  List<int>? get map => _laid?.map;

  /// Drops the laid-out text until it is asked for again.
  void release() {
    if (lay == null) return;
    _text?.dispose();
    _text = null;
  }

  /// Table rows on this fragment.
  final int rowStart;
  final int rowEnd;
  final List<double>? columnWidths;
  final List<double>? rowHeights;

  /// A list item's bullet or number.
  TextPainter? get bulletPainter => _laid?.bullet;

  /// Where a line ends at a soft hyphen, the hyphen to draw (the painter
  /// breaks there but draws nothing), in fragment coordinates at the
  /// baseline. It hangs into the margin, as in hand-set books.
  List<Offset> get hyphens => _laid?.hyphens ?? const <Offset>[];
  TextPainter? get hyphenPainter => _laid?.hyphen;

  /// A table's cells on this fragment: real text, so selection, highlights
  /// and read aloud reach it like any paragraph.
  final List<TableCell>? cells;

  /// A table wider than the page scrolls sideways; this is how far. Page
  /// coordinates ([boxes], [offsetAt]) are as the table is scrolled now.
  final ValueNotifier<double>? scroll;

  Offset get _scrolled => Offset(scroll?.value ?? 0, 0);

  void paintText(Canvas canvas) {
    painter?.paint(canvas, rect.topLeft);
    for (final TableCell c in cells ?? const <TableCell>[]) {
      c.painter.paint(canvas, rect.topLeft + c.rect.topLeft);
    }
    final TextPainter? h = hyphenPainter;
    if (h == null) return;
    final double ascent = h.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    for (final Offset o in hyphens) {
      h.paint(canvas, rect.topLeft + Offset(o.dx, o.dy - ascent));
    }
  }

  bool get isText => lay != null || cells != null;

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
    if (cells != null) {
      return <Rect>[
        for (final TableCell c in cells!)
          if (c.start < e && c.end > s)
            for (final TextBox box in c.painter.getBoxesForSelection(
              TextSelection(baseOffset: math.max(s, c.start) - c.start, extentOffset: math.min(e, c.end) - c.start),
            ))
              box.toRect().shift(rect.topLeft + c.rect.topLeft - _scrolled),
      ];
    }
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
    final Offset local = page - rect.topLeft + _scrolled;
    if (cells != null) {
      if (cells!.isEmpty) return start;
      // The cell under the point, else the nearest.
      TableCell best = cells!.first;
      double bestD = double.infinity;
      for (final TableCell c in cells!) {
        final Rect r = c.rect.inflate(4);
        final double dx = local.dx < r.left ? r.left - local.dx : (local.dx > r.right ? local.dx - r.right : 0);
        final double dy = local.dy < r.top ? r.top - local.dy : (local.dy > r.bottom ? local.dy - r.bottom : 0);
        final double d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          best = c;
        }
      }
      final TextPosition p = best.painter.getPositionForOffset(local - best.rect.topLeft);
      return (best.start + p.offset).clamp(best.start, best.end);
    }
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
    _text?.dispose();
    _text = null;
    for (final TableCell c in cells ?? const <TableCell>[]) {
      c.painter.dispose();
    }
    scroll?.dispose();
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

  void release() {
    for (final Fragment f in fragments) {
      f.release();
    }
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

  static final Expando<ImageSizes> _shared = Expando<ImageSizes>('ImageSizes');

  /// The sizes of one document's images, shared by every view of it: they are
  /// read once, however often Reader mode is shown.
  static ImageSizes of(ReadingDocument doc) => _shared[doc] ??= ImageSizes();

  Size? operator [](String key) => _sizes[key];

  /// Reads the sizes of [keys] that can be had from their headers, at once.
  /// True when every image is now known (nothing is left for [load]).
  bool loadKnown(Map<String, Uint8List> resources, Iterable<String> keys) {
    bool all = true;
    for (final String k in keys) {
      if (_sizes.containsKey(k)) continue;
      final Uint8List? bytes = resources[k];
      if (bytes == null) continue;
      final Size? s = sniff(bytes);
      if (s == null) {
        all = false;
      } else {
        _sizes[k] = s;
      }
    }
    return all;
  }

  /// Reads the sizes of [keys] from their headers, asking the engine only for
  /// what a header can't tell.
  Future<void> load(Map<String, Uint8List> resources, Iterable<String> keys) async {
    for (final String k in keys) {
      if (_sizes.containsKey(k) || resources[k] == null) continue;
      final Size? quick = sniff(resources[k]!);
      if (quick != null) {
        _sizes[k] = quick;
        continue;
      }
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

  /// The pixel size from an image's header (PNG, GIF, JPEG, WebP, BMP), or
  /// null when the bytes are another format or cut short. Never throws.
  static Size? sniff(Uint8List b) {
    final int n = b.length;
    int u16be(int i) => (b[i] << 8) | b[i + 1];
    int u16le(int i) => b[i] | (b[i + 1] << 8);
    int u32be(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
    int i32le(int i) => (b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24)).toSigned(32);
    bool tag(int at, String t) {
      if (at + t.length > n) return false;
      for (int k = 0; k < t.length; k++) {
        if (b[at + k] != t.codeUnitAt(k)) return false;
      }
      return true;
    }

    Size? size(int w, int h) => w > 0 && h > 0 ? Size(w.toDouble(), h.toDouble()) : null;

    // PNG: signature, then IHDR with width and height.
    if (n >= 24 && b[0] == 0x89 && tag(1, 'PNG') && b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A) {
      return size(u32be(16), u32be(20));
    }
    // GIF: little-endian logical screen size.
    if (n >= 10 && (tag(0, 'GIF87a') || tag(0, 'GIF89a'))) return size(u16le(6), u16le(8));
    // JPEG: walk the markers to the first start-of-frame.
    if (n >= 4 && b[0] == 0xFF && b[1] == 0xD8) {
      int i = 2;
      while (i + 3 < n) {
        if (b[i] != 0xFF) {
          i++;
          continue;
        }
        final int m = b[i + 1];
        if (m == 0xFF) {
          i++;
          continue;
        }
        // Markers without a length.
        if (m == 0x00 || m == 0x01 || (m >= 0xD0 && m <= 0xD9)) {
          i += 2;
          continue;
        }
        if (m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC) {
          if (i + 9 > n) return null;
          return size(u16be(i + 7), u16be(i + 5));
        }
        i += 2 + u16be(i + 2);
      }
      return null;
    }
    // WebP: RIFF container with a lossy, lossless or extended chunk.
    if (n >= 16 && tag(0, 'RIFF') && tag(8, 'WEBP')) {
      if (tag(12, 'VP8 ') && n >= 30) return size(u16le(26) & 0x3FFF, u16le(28) & 0x3FFF);
      if (tag(12, 'VP8L') && n >= 25 && b[20] == 0x2F) {
        final int bits = b[21] | (b[22] << 8) | (b[23] << 16) | (b[24] << 24);
        return size((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1);
      }
      if (tag(12, 'VP8X') && n >= 30) {
        final int w = (b[24] | (b[25] << 8) | (b[26] << 16)) + 1;
        final int h = (b[27] | (b[28] << 8) | (b[29] << 16)) + 1;
        return size(w, h);
      }
      return null;
    }
    // BMP: signed 32-bit width and height (a negative height is top-down).
    if (n >= 26 && tag(0, 'BM')) return size(i32le(18).abs(), i32le(22).abs());
    return null;
  }
}

/// Keeps one laid-out [Layout] alive while Reader mode is hidden, so showing it
/// again doesn't paginate the book again. The screen that owns the document
/// creates it and disposes it when it closes.
class ReaderLayoutCache {
  Layout? _layout;
  int _columns = 1;

  /// The parked layout if it was made for this document, style, page size and
  /// column count (it is handed over and no longer cached); a parked layout
  /// that doesn't match is disposed.
  Layout? take({
    required ReadingDocument doc,
    required ReaderStyle style,
    required Size pageSize,
    required int columns,
  }) {
    final Layout? l = _layout;
    if (l == null) return null;
    _layout = null;
    if (identical(l.doc, doc) && l.style == style && l.pageSize == pageSize && _columns == columns) return l;
    l.dispose();
    return null;
  }

  /// Keeps [layout]; disposes any other layout parked before it.
  void park(Layout layout, {required int columns}) {
    if (!identical(_layout, layout)) _layout?.dispose();
    _layout = layout;
    _columns = columns;
  }

  void dispose() {
    _layout?.dispose();
    _layout = null;
  }

  @visibleForTesting
  Layout? get parked => _layout;
}

/// Lays sections out into pages of a given size and style.
class Layout {
  Layout({required this.doc, required this.style, required this.pageSize, required this.images, this.before});

  final ReadingDocument doc;
  final ReaderStyle style;

  /// The text area of one page (or column).
  final Size pageSize;
  final ImageSizes images;

  /// The block before the first one, when one block is laid out alone (the
  /// scroll layout): book paragraphs indent after a paragraph.
  final Block? before;

  /// Pages per section; null until its layout has begun. A section being laid
  /// out has the pages finished so far (see [_paginate]); [isDone] says which.
  late final List<List<ReaderPage>?> sections = List<List<ReaderPage>?>.filled(doc.sections.length, null);

  late final List<bool> _done = List<bool>.filled(doc.sections.length, false);

  /// Sections part way through, each a paused [_paginate].
  final Map<int, Iterator<void>> _running = <int, Iterator<void>>{};

  /// Blocks laid out so far, over all sections (progress, tests).
  int blocksLaid = 0;

  bool get complete => !_done.contains(false);

  bool isDone(int section) => _done[section];

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

  /// Whether the pages laid out so far reach past (or hold) a position, so
  /// [pageOf] needs no more layout. Pages end only where pagination has
  /// passed, and a page is finished once the next begins, so the last page's
  /// end decides it.
  bool covers(int section, int block, int offset) {
    if (_done[section]) return true;
    final List<ReaderPage>? pages = sections[section];
    if (pages == null || pages.isEmpty) return false;
    final (int ls, int lb, int lo) = pages.last.last;
    return ls == section && (lb > block || (lb == block && lo > offset));
  }

  /// The global page holding a position. Lays the section out as far as the
  /// position needs (not past it) before answering, all at once.
  int pageOf(int section, int block, int offset) {
    _advance(section, () => covers(section, block, offset));
    final List<ReaderPage> pages = sections[section]!;
    for (int i = 0; i < pages.length; i++) {
      if (pages[i].contains(section, block, offset)) return firstPageOf(section) + i;
      final (int ls, int lb, int lo) = pages[i].last;
      if (ls == section && (lb > block || (lb == block && lo > offset))) return firstPageOf(section) + i;
    }
    return firstPageOf(section) + math.max(0, pages.length - 1);
  }

  /// Lays a whole section out, all at once.
  void ensure(int section) => _advance(section, () => false);

  /// Lays out toward a position for at most [budget]; true once it is covered.
  bool advanceTo(int section, int block, int offset, Duration budget) {
    final Stopwatch sw = Stopwatch()..start();
    _advance(section, () => covers(section, block, offset) || sw.elapsed >= budget);
    return covers(section, block, offset);
  }

  /// Lays out on from the page at [global] until [count] pages after it are
  /// known or the book ends, so a turn always has a page to turn to, however
  /// little of the rest is laid out.
  void ahead(int global, int count) {
    final int need = global + count + 1;
    for (int s = sectionPageOf(global).$1; s < sections.length; s++) {
      final int first = firstPageOf(s);
      _advance(s, () => first + sections[s]!.length >= need);
      if (first + sections[s]!.length >= need) return;
    }
  }

  /// Lays out more, nearest [around] first, for at most [budget]; false when
  /// every section is done. Pagination resumes where it paused, so page
  /// boundaries are those of one uninterrupted layout.
  bool step(int around, Duration budget) {
    final Stopwatch sw = Stopwatch()..start();
    while (sw.elapsed < budget) {
      final int? s = _nextUndone(around);
      if (s == null) return false;
      _advance(s, () => sw.elapsed >= budget);
    }
    return _nextUndone(around) != null;
  }

  /// Lays out the next section not yet done, whole; false when all are.
  bool layoutNext(int around) {
    final int? s = _nextUndone(around);
    if (s == null) return false;
    ensure(s);
    return true;
  }

  int? _nextUndone(int around) {
    for (int d = 0; d < sections.length; d++) {
      // Back first: [ahead] already keeps the pages to come.
      for (final int s in <int>[around - d, around + d]) {
        if (s >= 0 && s < sections.length && !_done[s]) return s;
      }
    }
    return null;
  }

  /// Runs [section]'s pagination, a block at a time, until [stop] says so or
  /// the section is done.
  void _advance(int section, bool Function() stop) {
    if (_done[section]) return;
    final List<ReaderPage> pages = sections[section] ??= <ReaderPage>[];
    final Iterator<void> it = _running[section] ??= _paginate(section, pages).iterator;
    while (!stop()) {
      if (!it.moveNext()) {
        _done[section] = true;
        _running.remove(section);
        return;
      }
    }
  }

  /// The page a paused section is still filling.
  final Map<int, List<Fragment>> _unfinished = <int, List<Fragment>>{};

  void dispose() {
    for (final List<Fragment> f in _unfinished.values) {
      ReaderPage(f).dispose();
    }
    _unfinished.clear();
    for (final List<ReaderPage>? pages in sections) {
      for (final ReaderPage p in pages ?? const <ReaderPage>[]) {
        p.dispose();
      }
    }
  }

  // ------------------------------------------------------------ pagination

  /// Paginates section [s] into [pages], pausing after each block (and each
  /// page of a block too long for one). It is one uninterrupted layout run in
  /// pieces: nothing a page holds depends on when the pieces ran, so the page
  /// boundaries equal those of a single synchronous pass. Pages up to the
  /// last one are final as they are added. A section cannot be paginated from
  /// its middle (where a page starts depends on every page before it), so a
  /// far position is reached by running on from the start in slices.
  Iterable<void> _paginate(int s, List<ReaderPage> pages) sync* {
    final List<Block> blocks = doc.sections[s].blocks;
    final double w = pageSize.width, h = pageSize.height;
    List<Fragment> cur = _unfinished[s] = <Fragment>[];
    double y = 0;

    void newPage() {
      // Where it breaks is kept; its text is laid out again when it is shown.
      if (cur.isNotEmpty) pages.add(ReaderPage(cur)..release());
      cur = _unfinished[s] = <Fragment>[];
      y = 0;
    }

    final Set<(int, int)> chapterStarts = doc.chapterBlocks;
    for (int i = 0; i < blocks.length; i++) {
      final Block b = blocks[i];
      final Block? prev = i > 0 ? blocks[i - 1] : before;
      double gap() => cur.isEmpty ? 0 : style.spaceBefore(b, prev);
      // A chapter that starts inside a section (a TOC entry mid file, a
      // heading chapter in Markdown) starts on a new page.
      // (A page holding only headings so far, a book title, keeps them.)
      if (chapterStarts.contains((s, i)) && cur.any((Fragment f) => f.block.kind != BlockKind.heading)) newPage();
      // Text with nothing to show never opens a page: no blank last page,
      // no empty lines at a page's top.
      final bool blank =
          b.kind != BlockKind.image && b.kind != BlockKind.rule && b.kind != BlockKind.table && b.text.trim().isEmpty;
      if (blank && cur.isEmpty) continue;
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
          _table(s, i, b, gap(), () => y, (double v) => y = v, () => cur, newPage, w, h);
        default:
          int from = 0;
          bool first = true;
          int most = _probeChars;
          while (true) {
            final double g = first ? gap() : 0;
            final double inset = style.insetFor(b);
            final int to = b.kind == BlockKind.code ? b.text.length : _wordEnd(b.text, from + most);
            final Fragment probe = _text(
              s,
              i,
              b,
              from,
              to,
              Offset(inset, 0),
              w - inset,
              first ? style.indentFor(b, prev) : 0,
              bullet: first,
            );
            final TextPainter tp = probe.painter!;
            final double ph = tp.height + (b.kind == BlockKind.code ? 20 : 0);
            // A heading keeps with the next block: it moves to the next page
            // unless two of that block's lines fit under it.
            final Block? following = i + 1 < blocks.length ? blocks[i + 1] : null;
            final bool lonely =
                _headingLike(b, following) &&
                first &&
                cur.isNotEmpty &&
                following != null &&
                following.kind != BlockKind.heading &&
                !chapterStarts.contains((s, i + 1)) &&
                y + g + ph + style.spaceBefore(following, b) + 2 * style.size * style.lineHeight > h + 0.5;
            if (lonely) {
              probe.dispose();
              newPage();
              continue;
            }
            if (to < b.text.length && y + g + ph <= h + 0.5) {
              // More fits than was tried (very short lines): try more.
              probe.dispose();
              most *= 2;
              continue;
            }
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
                // Whitespace that doesn't fit is dropped, not carried onto a page of its own.
                if (blank) break;
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
            yield null;
          }
      }
      if (y >= h - 0.5) newPage();
      blocksLaid++;
      yield null;
    }
    newPage();
    if (pages.isEmpty) pages.add(ReaderPage(<Fragment>[]));
  }

  /// Characters that are sure to overflow a page, with lines to spare for the
  /// widow rule. A long paragraph is tried no further than this: lines break
  /// greedily, so those on the page come out as they would from the whole
  /// text, and laying all of it out again for every page is quadratic (a PDF
  /// that reflows into one paragraph per chapter froze for seconds).
  late final int _probeChars =
      ((pageSize.height / (style.size * style.lineHeight) + 8) * math.max(8, pageSize.width / (style.size * 0.2)))
          .ceil();

  /// The end of the word at [at], or the end of the text.
  static int _wordEnd(String text, int at) {
    if (at >= text.length) return text.length;
    while (at < text.length && text.codeUnitAt(at) != 0x20 && text.codeUnitAt(at) != 0x0A) {
      at++;
    }
    return at;
  }

  /// A heading, or a line that labels what follows the way Word and Google
  /// Docs files without heading styles do: short and all in bold, or short,
  /// starting in bold and introducing a list. It keeps with the next block.
  static bool _headingLike(Block b, Block? following) {
    if (b.kind == BlockKind.heading) return true;
    if (b.kind != BlockKind.paragraph || b.text.trim().isEmpty || b.text.length > 100) return false;
    final Iterable<Inline> runs = b.runs.where((Inline r) => r.text.trim().isNotEmpty);
    if (runs.isEmpty || !runs.first.bold) return false;
    return (b.text.length <= 80 && runs.every((Inline r) => r.bold)) || following?.kind == BlockKind.listItem;
  }

  Fragment _place(Fragment f, double y) => Fragment(
    section: f.section,
    blockIndex: f.blockIndex,
    block: f.block,
    start: f.start,
    end: f.end,
    rect: f.rect.shift(Offset(0, y)),
    text: f._text,
    lay: f.lay,
    cells: f.cells,
    scroll: f.scroll,
  );

  /// Rows of a table, split across pages at row boundaries. Every cell is
  /// laid out once, as text, with the column widths shared by all rows.
  void _table(
    int s,
    int i,
    Block b,
    double gap,
    double Function() getY,
    void Function(double) setY,
    // A getter: newPage() starts a new list, and later rows belong on it.
    List<Fragment> Function() cur,
    VoidCallback newPage,
    double w,
    double h,
  ) {
    final List<List<String>> rows = b.rows!;
    final int cols = rows.fold<int>(0, (int m, List<String> r) => math.max(m, r.length));
    if (cols == 0) return;
    // Width by content, but never so narrow a number column crowds its
    // neighbour.
    final List<int> weight = List<int>.filled(cols, 4);
    for (final List<String> r in rows) {
      for (int c = 0; c < r.length; c++) {
        weight[c] = math.max(weight[c], math.min(30, r[c].length));
      }
    }
    final int total = weight.fold<int>(0, (int a, int x) => a + x);
    final TextStyle st = style.styleFor(b);
    final TextStyle head = st.copyWith(
      fontWeight: FontWeight.w600,
      fontVariations: const <FontVariation>[FontVariation('wght', 600)],
    );
    const double padX = 4, padY = 5;
    // Where each cell's text starts in the block (cells joined by tabs,
    // rows by newlines, as Block.text has them).
    final List<List<int>> starts = <List<int>>[];
    int at = 0;
    for (final List<String> r in rows) {
      final List<int> row = <int>[];
      for (int c = 0; c < r.length; c++) {
        row.add(at);
        at += r[c].length + (c < r.length - 1 ? 1 : 0);
      }
      starts.add(row);
      at += 1;
    }
    final List<List<TextPainter>> painters = <List<TextPainter>>[
      for (int r = 0; r < rows.length; r++)
        <TextPainter>[
          for (int c = 0; c < rows[r].length; c++)
            TextPainter(
              text: TextSpan(text: rows[r][c], style: r == 0 ? head : st),
              textDirection: TextDirection.ltr,
            )..layout(),
        ],
    ];
    // No column breaks inside a word: each is at least its longest word,
    // and what is left of the page is shared by content. If the words alone
    // are wider than the page, the table scrolls sideways.
    final List<double> need = List<double>.filled(cols, 0), natural = List<double>.filled(cols, 0);
    for (final List<TextPainter> row in painters) {
      for (int c = 0; c < row.length; c++) {
        need[c] = math.max(need[c], row[c].minIntrinsicWidth.ceilToDouble() + padX * 2);
        natural[c] = math.max(natural[c], row[c].maxIntrinsicWidth.ceilToDouble() + padX * 2);
      }
    }
    final double spare = w - need.fold<double>(0, (double a, double x) => a + x);
    // Once it scrolls anyway, a column takes its one-line width, up to half
    // the page, so rows don't wrap for nothing.
    final List<double> widths = <double>[
      for (int c = 0; c < cols; c++)
        spare >= 0 ? need[c] + spare * weight[c] / total : math.max(need[c], math.min(natural[c], w / 2)),
    ];
    final double tableW = widths.fold<double>(0, (double a, double x) => a + x);
    for (final List<TextPainter> row in painters) {
      for (int c = 0; c < row.length; c++) {
        row[c].layout(maxWidth: math.max(1, widths[c] - padX * 2));
      }
    }
    final List<double> heights = <double>[
      for (final List<TextPainter> row in painters)
        row.fold<double>(style.size * 0.9, (double m, TextPainter tp) => math.max(m, tp.height + padY * 2)),
    ];
    int r0 = 0;
    double y = getY();
    while (r0 < rows.length) {
      final double g = cur().isEmpty ? 0 : gap;
      double used = 0;
      int r1 = r0;
      while (r1 < rows.length && y + g + used + heights[r1] <= h) {
        used += heights[r1];
        r1++;
      }
      // A header row alone at the foot of a page goes over with its rows.
      if (r0 == 0 && r1 == 1 && rows.length > 1 && cur().isNotEmpty) r1 = r0;
      if (r1 == r0) {
        if (cur().isNotEmpty) {
          newPage();
          y = 0;
          continue;
        }
        used = heights[r0];
        r1 = r0 + 1;
      }
      final List<TableCell> cells = <TableCell>[];
      double cy = 0;
      for (int r = r0; r < r1; r++) {
        double cx = 0;
        for (int c = 0; c < rows[r].length; c++) {
          final TextPainter tp = painters[r][c];
          cells.add(
            TableCell(
              painter: tp,
              rect: Rect.fromLTWH(cx + padX, cy + padY, tp.width, tp.height),
              start: starts[r][c],
              length: rows[r][c].length,
            ),
          );
          cx += widths[c];
        }
        cy += heights[r];
      }
      final int from = starts[r0].firstOrNull ?? 0;
      final int to = r1 < rows.length ? (starts[r1].firstOrNull ?? b.text.length) - 1 : b.text.length;
      cur().add(
        Fragment(
          section: s,
          blockIndex: i,
          block: b,
          start: from,
          end: math.max(from, to),
          rect: Rect.fromLTWH(0, y + g, math.max(w, tableW), used),
          rowStart: r0,
          rowEnd: r1,
          columnWidths: widths,
          rowHeights: heights.sublist(r0, r1),
          cells: cells,
          scroll: tableW > w + 0.5 ? ValueNotifier<double>(0) : null,
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
    final FragmentText t = _layText(b, from, to, width, indent, bullet: bullet);
    return Fragment(
      section: s,
      blockIndex: i,
      block: b,
      start: from,
      end: to,
      rect: Rect.fromLTWH(origin.dx, origin.dy, width, t.painter.height),
      text: t,
      lay: (Fragment f) {
        _live.add(f);
        while (_live.length > maxLive) {
          _live.removeFirst().release();
        }
        return _layText(b, from, to, width, indent, bullet: bullet);
      },
    );
  }

  /// Fragments laid out again to be shown, oldest first. Far more than the
  /// pages on screen and their neighbours hold (three spreads of one-line
  /// paragraphs are about 250), so nothing on screen is laid out twice.
  final Queue<Fragment> _live = Queue<Fragment>();

  @visibleForTesting
  static const int maxLive = 600;

  FragmentText _layText(Block b, int from, int to, double width, double indent, {required bool bullet}) {
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
    return FragmentText(
      painter: tp,
      map: map,
      bullet: bulletPainter,
      hyphens: hyphens,
      hyphen: hyphens.isEmpty
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
