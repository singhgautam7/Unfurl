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

/// Renders pages at the size they are shown, recolours them off the UI
/// isolate, and keeps an LRU of decoded images sized from the device. A
/// render for a page that has scrolled away is cancelled.
class PageRenderer {
  PageRenderer(this.document, {int? budgetBytes}) : _budget = budgetBytes ?? 96 * 1024 * 1024;

  final PdfDocument document;
  final int _budget;
  int _bytes = 0;
  final LinkedHashMap<String, ui.Image> _cache = LinkedHashMap<String, ui.Image>();
  final Map<String, Future<ui.Image?>> _pending = <String, Future<ui.Image?>>{};
  final Map<String, PdfPageRenderCancellationToken> _tokens = <String, PdfPageRenderCancellationToken>{};
  final Map<int, Rect> _cropBoxes = <int, Rect>{};
  bool _disposed = false;

  /// Bumped when an image lands, so painters can repaint.
  final ValueNotifier<int> ready = ValueNotifier<int>(0);

  static String _key(int page, int width, PageLook look) => '$page:$width:${look.hashCode}';

  /// A cached image at exactly this width, or the best smaller one to show
  /// meanwhile.
  ui.Image? cached(int page, int width, PageLook look) {
    final ui.Image? exact = _cache.remove(_key(page, width, look));
    if (exact != null) {
      _cache[_key(page, width, look)] = exact;
      return exact;
    }
    ui.Image? best;
    for (final MapEntry<String, ui.Image> e in _cache.entries) {
      final List<String> parts = e.key.split(':');
      if (parts[0] == '$page' && parts[2] == '${look.hashCode}' && (best == null || e.value.width > best.width)) {
        best = e.value;
      }
    }
    return best;
  }

  /// Renders page [page] (1-based) at [width] device pixels across the
  /// visible (cropped) area.
  Future<ui.Image?> render(int page, int width, PageLook look) {
    final String key = _key(page, width, look);
    final ui.Image? hit = _cache[key];
    if (hit != null) return Future<ui.Image?>.value(hit);
    return _pending[key] ??= _render(page, width, look, key).whenComplete(() {
      _pending.remove(key);
      _tokens.remove(key);
    });
  }

  /// Cancels renders for pages outside [keep].
  void cancelExcept(Set<int> keep) {
    for (final MapEntry<String, PdfPageRenderCancellationToken> e in _tokens.entries.toList()) {
      if (!keep.contains(int.parse(e.key.split(':').first))) e.value.cancel();
    }
  }

  Future<ui.Image?> _render(int pageNumber, int width, PageLook look, String key) async {
    if (_disposed || pageNumber < 1 || pageNumber > document.pages.length) return null;
    final PdfPage page = document.pages[pageNumber - 1];
    final Rect crop = look.crop ?? const Rect.fromLTRB(0, 0, 1, 1);
    final double full = width / crop.width;
    final double fullH = full * page.height / page.width;
    final int x = (crop.left * full).round(), y = (crop.top * fullH).round();
    final int w = width, h = (crop.height * fullH).round();
    final PdfPageRenderCancellationToken token = page.createCancellationToken();
    _tokens[key] = token;
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
    Uint8List pixels = Uint8List.fromList(img.pixels);
    final int iw = img.width, ih = img.height;
    img.dispose();
    if (look.recolour) {
      final TransferableTypedData t = TransferableTypedData.fromList(<Uint8List>[pixels]);
      final int paper = look.paper!, ink = look.ink!;
      pixels = await _recolourOff(t, iw, ih, paper, ink);
    }
    final Completer<ui.Image> done = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, iw, ih, ui.PixelFormat.bgra8888, done.complete);
    final ui.Image image = await done.future;
    if (_disposed) {
      image.dispose();
      return null;
    }
    _cache[key] = image;
    _bytes += iw * ih * 4;
    while (_bytes > _budget && _cache.length > 2) {
      final String oldest = _cache.keys.first;
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
    // Grow photo regions by a tile so their edges are not recoloured.
    final Uint8List grown = Uint8List.fromList(photo);
    for (int ty = 0; ty < th; ty++) {
      for (int tx = 0; tx < tw; tx++) {
        if (photo[ty * tw + tx] == 0) continue;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final int y = ty + dy, x = tx + dx;
            if (y >= 0 && y < th && x >= 0 && x < tw) grown[y * tw + x] = 1;
          }
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
    for (final PdfPageRenderCancellationToken t in _tokens.values) {
      t.cancel();
    }
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
