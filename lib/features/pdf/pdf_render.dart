import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:pdfrx/pdfrx.dart';

/// How a page is drawn: the reading theme's paper and ink (null keeps the
/// original), and an optional crop box.
@immutable
class PageLook {
  const PageLook({this.paper, this.ink, this.crop});

  /// ARGB. Both null: original colours.
  final int? paper;
  final int? ink;

  /// Fraction of the page to show: left, top, right, bottom in 0..1 (top
  /// down).
  final Rect? crop;

  bool get recolour => paper != null && ink != null;

  @override
  bool operator ==(Object other) => other is PageLook && other.paper == paper && other.ink == ink && other.crop == crop;

  @override
  int get hashCode => Object.hash(paper, ink, crop);
}

/// Render priorities, lowest first: what is on screen comes before what is
/// near it, and a quick low-resolution preview before the sharp page.
abstract final class RenderPriority {
  static const int visiblePreview = 0;
  static const int visible = 1;
  static const int nearPreview = 2;
  static const int near = 3;
}

typedef _Key = (int page, int width, PageLook look);

/// A render waiting for, or holding, PDFium.
class _Job {
  _Job(this.key, this.priority, this.seq);

  final _Key key;
  int priority;
  final int seq;
  bool started = false;
  PdfPageRenderCancellationToken? token;
  final Completer<ui.Image?> done = Completer<ui.Image?>();
}

/// Renders pages at the size they are shown, recolours them off the UI
/// isolate, and keeps an LRU of decoded images sized from the device.
///
/// PDFium renders one page at a time, so renders queue here by priority (what
/// is on screen first) with two in flight: one rendering while the last is
/// handed to the engine. A queued render for a page that has scrolled away is
/// dropped and a running one cancelled.
class PageRenderer {
  PageRenderer(this.document, {int? budgetBytes}) : _budget = budgetBytes ?? 96 * 1024 * 1024;

  final PdfDocument document;
  final int _budget;
  int _bytes = 0;
  final LinkedHashMap<_Key, ui.Image> _cache = LinkedHashMap<_Key, ui.Image>();
  final Map<_Key, _Job> _jobs = <_Key, _Job>{};
  final List<_Job> _queue = <_Job>[];
  final Map<int, Rect> _cropBoxes = <int, Rect>{};
  static const int _inFlight = 2;
  int _running = 0;
  int _seq = 0;
  bool _disposed = false;

  /// Bumped when an image lands, so painters can repaint.
  final ValueNotifier<int> ready = ValueNotifier<int>(0);

  /// A cached image at exactly this width, or the widest other one to show
  /// meanwhile.
  ui.Image? cached(int page, int width, PageLook look) {
    final _Key key = (page, width, look);
    final ui.Image? exact = _cache.remove(key);
    if (exact != null) {
      _cache[key] = exact;
      return exact;
    }
    ui.Image? best;
    for (final MapEntry<_Key, ui.Image> e in _cache.entries) {
      if (e.key.$1 == page && e.key.$3 == look && (best == null || e.value.width > best.width)) best = e.value;
    }
    return best;
  }

  /// Renders page [page] (1-based) at [width] device pixels across the
  /// visible (cropped) area. A render already queued keeps its place, moved
  /// up if this asks for it sooner.
  Future<ui.Image?> render(int page, int width, PageLook look, {int priority = RenderPriority.visible}) {
    final _Key key = (page, width, look);
    final ui.Image? hit = _cache[key];
    if (hit != null) return Future<ui.Image?>.value(hit);
    final _Job? queued = _jobs[key];
    if (queued != null) {
      if (!queued.started && priority < queued.priority) queued.priority = priority;
      return queued.done.future;
    }
    if (_disposed) return Future<ui.Image?>.value();
    final _Job job = _Job(key, priority, _seq++);
    _jobs[key] = job;
    _queue.add(job);
    _pump();
    return job.done.future;
  }

  void _pump() {
    while (!_disposed && _running < _inFlight && _queue.isNotEmpty) {
      _Job next = _queue.first;
      for (final _Job j in _queue) {
        if (j.priority < next.priority || (j.priority == next.priority && j.seq < next.seq)) next = j;
      }
      _queue.remove(next);
      next.started = true;
      _running++;
      unawaited(_run(next));
    }
  }

  Future<void> _run(_Job job) async {
    ui.Image? image;
    try {
      image = await _render(job);
    } catch (_) {
      // A page PDFium can't draw, or memory for its pixels: it stays blank.
      image = null;
    }
    _running--;
    _jobs.remove(job.key);
    if (!job.done.isCompleted) job.done.complete(image);
    _pump();
  }

  /// Drops queued renders for pages outside [keep] and cancels running ones.
  void cancelExcept(Set<int> keep) {
    for (final _Job j in _queue.where((_Job j) => !keep.contains(j.key.$1)).toList()) {
      _queue.remove(j);
      _jobs.remove(j.key);
      j.done.complete(null);
    }
    for (final _Job j in _jobs.values) {
      if (j.started && !keep.contains(j.key.$1)) j.token?.cancel();
    }
  }

  Future<ui.Image?> _render(_Job job) async {
    final (int pageNumber, int width, PageLook look) = job.key;
    if (_disposed || pageNumber < 1 || pageNumber > document.pages.length) return null;
    final PdfPage page = document.pages[pageNumber - 1];
    final Rect crop = look.crop ?? const Rect.fromLTRB(0, 0, 1, 1);
    final double full = width / crop.width;
    final double fullH = full * page.height / page.width;
    final int x = (crop.left * full).round(), y = (crop.top * fullH).round();
    final int w = width, h = math.max(1, (crop.height * fullH).round());
    final PdfPageRenderCancellationToken token = page.createCancellationToken();
    job.token = token;
    final PdfImage? img = await page.render(
      x: x,
      y: y,
      width: w,
      height: h,
      fullWidth: full,
      fullHeight: fullH,
      backgroundColor: 0xFFFFFFFF,
      cancellationToken: token,
    );
    if (img == null || _disposed) {
      img?.dispose();
      return null;
    }
    final ui.Image image;
    if (look.recolour) {
      final Uint8List copy = Uint8List.fromList(img.pixels);
      final int iw = img.width, ih = img.height;
      img.dispose();
      final TransferableTypedData t = TransferableTypedData.fromList(<Uint8List>[copy]);
      final Uint8List pixels = await _recolourOff(t, iw, ih, look.paper!, look.ink!);
      final Completer<ui.Image> done = Completer<ui.Image>();
      ui.decodeImageFromPixels(pixels, iw, ih, ui.PixelFormat.bgra8888, done.complete);
      image = await done.future;
    } else {
      // Straight from PDFium's buffer to the engine: no copy on this isolate.
      try {
        image = await img.createImage();
      } finally {
        img.dispose();
      }
    }
    if (_disposed) {
      image.dispose();
      return null;
    }
    _cache[job.key] = image;
    _bytes += image.width * image.height * 4;
    while (_bytes > _budget && _cache.length > 2) {
      final _Key oldest = _cache.keys.first;
      final ui.Image gone = _cache.remove(oldest)!;
      _bytes -= gone.width * gone.height * 4;
      gone.dispose();
    }
    ready.value++;
    return image;
  }

  /// Recolour mode: page white maps to paper, near-black glyphs to ink,
  /// everything between along a luminance ramp. Photographs are found as
  /// 16px tiles with many mid-tones or real colour and left untouched.
  static Uint8List recolour(Uint8List px, int w, int h, int paper, int ink) {
    const int tile = 16;
    final int tw = (w + tile - 1) ~/ tile, th = (h + tile - 1) ~/ tile;
    final Uint8List photo = Uint8List(tw * th);
    for (int ty = 0; ty < th; ty++) {
      for (int tx = 0; tx < tw; tx++) {
        int mid = 0, colour = 0, n = 0;
        for (int y = ty * tile; y < math.min(h, ty * tile + tile); y += 2) {
          for (int x = tx * tile; x < math.min(w, tx * tile + tile); x += 2) {
            final int i = (y * w + x) * 4;
            final int b = px[i], g = px[i + 1], r = px[i + 2];
            final int l = (r * 54 + g * 183 + b * 19) >> 8;
            if (l > 40 && l < 215) mid++;
            if (math.max(r, math.max(g, b)) - math.min(r, math.min(g, b)) > 40) colour++;
            n++;
          }
        }
        if (n > 0 && (mid > n * 0.45 || colour > n * 0.3)) photo[ty * tw + tx] = 1;
      }
    }
    // A picture is kept whole: each group of photo tiles keeps its whole
    // bounding box (and a tile around it) in its own colours, so a chart's
    // white ground or a photo's flat sky isn't inverted in patches. Groups
    // under three tiles, or no taller than two (a line of small anti-aliased
    // text, as a scan drawn at phone size makes), are text that happened to
    // look busy.
    final Uint8List grown = Uint8List(tw * th);
    final Int32List stack = Int32List(tw * th);
    final List<List<int>> boxes = <List<int>>[];
    for (int start = 0; start < photo.length; start++) {
      if (photo[start] != 1) continue;
      int top = 0, count = 0, x0 = tw, y0 = th, x1 = -1, y1 = -1;
      stack[top++] = start;
      photo[start] = 2;
      while (top > 0) {
        final int at = stack[--top];
        final int x = at % tw, y = at ~/ tw;
        count++;
        x0 = math.min(x0, x);
        x1 = math.max(x1, x);
        y0 = math.min(y0, y);
        y1 = math.max(y1, y);
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final int nx = x + dx, ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= tw || ny >= th || photo[ny * tw + nx] != 1) continue;
            photo[ny * tw + nx] = 2;
            stack[top++] = ny * tw + nx;
          }
        }
      }
      if (count < 3 || y1 - y0 < 2) continue;
      boxes.add(<int>[x0 - 1, y0 - 1, x1 + 1, y1 + 1]);
    }
    // Boxes that touch are one picture (a chart's bars, apart).
    bool merged = true;
    while (merged) {
      merged = false;
      for (int a = 0; a < boxes.length && !merged; a++) {
        for (int b = a + 1; b < boxes.length; b++) {
          final List<int> p = boxes[a], q = boxes[b];
          if (p[0] <= q[2] + 1 && q[0] <= p[2] + 1 && p[1] <= q[3] + 1 && q[1] <= p[3] + 1) {
            boxes[a] = <int>[math.min(p[0], q[0]), math.min(p[1], q[1]), math.max(p[2], q[2]), math.max(p[3], q[3])];
            boxes.removeAt(b);
            merged = true;
            break;
          }
        }
      }
    }
    for (final List<int> b in boxes) {
      for (int y = math.max(0, b[1]); y <= math.min(th - 1, b[3]); y++) {
        for (int x = math.max(0, b[0]); x <= math.min(tw - 1, b[2]); x++) {
          grown[y * tw + x] = 1;
        }
      }
    }
    final int pr = (paper >> 16) & 0xFF, pg = (paper >> 8) & 0xFF, pb = paper & 0xFF;
    final int ir = (ink >> 16) & 0xFF, ig = (ink >> 8) & 0xFF, ib = ink & 0xFF;
    final Uint8List lr = Uint8List(256), lg = Uint8List(256), lb = Uint8List(256);
    for (int l = 0; l < 256; l++) {
      lr[l] = ir + ((pr - ir) * l) ~/ 255;
      lg[l] = ig + ((pg - ig) * l) ~/ 255;
      lb[l] = ib + ((pb - ib) * l) ~/ 255;
    }
    for (int y = 0; y < h; y++) {
      final int row = (y ~/ tile) * tw;
      for (int x = 0; x < w; x++) {
        if (grown[row + x ~/ tile] == 1) continue;
        final int i = (y * w + x) * 4;
        final int l = (px[i + 2] * 54 + px[i + 1] * 183 + px[i] * 19) >> 8;
        px[i] = lb[l];
        px[i + 1] = lg[l];
        px[i + 2] = lr[l];
      }
    }
    return px;
  }

  /// The page's content box (0..1, top down), from a small render: the
  /// margins auto-crop removes. Computed once per page in an isolate.
  Future<Rect> contentBox(int pageNumber) async {
    final Rect? known = _cropBoxes[pageNumber];
    if (known != null) return known;
    final PdfPage page = document.pages[pageNumber - 1];
    const int w = 240;
    final int h = (w * page.height / page.width).round();
    final PdfImage? img = await page.render(
      fullWidth: w.toDouble(),
      fullHeight: h.toDouble(),
      backgroundColor: 0xFFFFFFFF,
    );
    if (img == null) return const Rect.fromLTRB(0, 0, 1, 1);
    final Uint8List px = Uint8List.fromList(img.pixels);
    final int iw = img.width, ih = img.height;
    img.dispose();
    final Rect box = await _boundsOff(px, iw, ih);
    return _cropBoxes[pageNumber] = box;
  }

  static Rect _bounds(Uint8List px, int w, int h) {
    int minX = w, minY = h, maxX = -1, maxY = -1;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int i = (y * w + x) * 4;
        if (px[i] < 235 || px[i + 1] < 235 || px[i + 2] < 235) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return const Rect.fromLTRB(0, 0, 1, 1);
    const double pad = 6;
    return Rect.fromLTRB(
      math.max(0, (minX - pad) / w),
      math.max(0, (minY - pad) / h),
      math.min(1, (maxX + pad) / w),
      math.min(1, (maxY + pad) / h),
    );
  }

  void dispose() {
    _disposed = true;
    for (final _Job j in _jobs.values) {
      j.token?.cancel();
      if (!j.done.isCompleted) j.done.complete(null);
    }
    _jobs.clear();
    _queue.clear();
    for (final ui.Image i in _cache.values) {
      i.dispose();
    }
    _cache.clear();
    ready.dispose();
  }
}

// Top-level, so the isolate's closures carry only pixels, never the renderer.
Future<Uint8List> _recolourOff(TransferableTypedData t, int w, int h, int paper, int ink) =>
    Isolate.run(() => PageRenderer.recolour(t.materialize().asUint8List(), w, h, paper, ink));
Future<Rect> _boundsOff(Uint8List px, int w, int h) => Isolate.run(() => PageRenderer._bounds(px, w, h));
