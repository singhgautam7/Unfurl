import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../formats/comics/comic_archive.dart';

/// A comic's pages as the viewer asks for them: encoded bytes from the
/// archive (an LRU capped in bytes; the page on screen first, ±2 prefetched,
/// prefetches dropped when the reader moves on), decoded at the size they
/// are drawn by Flutter's image cache ([providerFor]), page sizes read from
/// the image headers, and a disk cache of thumbnails for the scrubber.
class ComicPages {
  ComicPages(this.archive, this.fingerprint);

  final ComicArchive archive;
  final String fingerprint;

  static const int _bytesCap = 48 << 20;
  static const int prefetchSpan = 2;

  final LinkedHashMap<int, Uint8List> _bytes = LinkedHashMap<int, Uint8List>();
  int _bytesTotal = 0;
  final Map<int, Future<Uint8List?>> _pending = <int, Future<Uint8List?>>{};
  final Set<int> _prefetching = <int>{};

  /// Width and height of each page read so far.
  final Map<int, ui.Size> dims = <int, ui.Size>{};

  /// Bumped when a page's size becomes known (spreads re-pair, webtoon heights).
  final ValueNotifier<int> measured = ValueNotifier<int>(0);
  bool _disposed = false;

  int get count => archive.pages.length;

  Uint8List? cached(int i) {
    final Uint8List? b = _bytes.remove(i);
    if (b != null) _bytes[i] = b;
    return b;
  }

  /// The page's encoded bytes; null if it can't be read. A [prefetch] can be
  /// dropped by [around] when the reader moves away.
  Future<Uint8List?> bytes(int i, {bool prefetch = false}) {
    if (i < 0 || i >= count || _disposed) return SynchronousFuture<Uint8List?>(null);
    final Uint8List? hit = cached(i);
    if (hit != null) return SynchronousFuture<Uint8List?>(hit);
    final Future<Uint8List?>? inFlight = _pending[i];
    // A page someone is waiting for never rides on a prefetch that may be dropped.
    if (inFlight != null && (prefetch || !_prefetching.contains(i))) return inFlight;
    prefetch ? _prefetching.add(i) : _prefetching.remove(i);
    late final Future<Uint8List?> mine;
    mine = archive.page(i, cancellable: prefetch).then((Uint8List? b) {
      if (identical(_pending[i], mine)) {
        _pending.remove(i);
        _prefetching.remove(i);
      }
      if (b != null && !_disposed && !_bytes.containsKey(i)) {
        _put(i, b);
        unawaited(_measure(i, b));
      }
      return b;
    });
    return _pending[i] = mine;
  }

  void _put(int i, Uint8List b) {
    _bytes[i] = b;
    _bytesTotal += b.length;
    while (_bytesTotal > _bytesCap && _bytes.length > 1 + 2 * prefetchSpan) {
      final int oldest = _bytes.keys.first;
      _bytesTotal -= _bytes.remove(oldest)!.length;
    }
  }

  /// Reading moved to [page]: queued prefetches are dropped, then the page and
  /// its neighbours are asked for, nearest first.
  Future<void> around(int page) async {
    if (_prefetching.isNotEmpty) {
      await archive.cancelPending();
      _pending.removeWhere((int i, Future<Uint8List?> _) => _prefetching.contains(i));
      _prefetching.clear();
    }
    unawaited(bytes(page));
    for (int d = 1; d <= prefetchSpan; d++) {
      unawaited(bytes(page + d, prefetch: true));
      unawaited(bytes(page - d, prefetch: true));
    }
  }

  Future<void> _measure(int i, Uint8List b) async {
    if (dims.containsKey(i)) return;
    try {
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(b);
      final ui.ImageDescriptor d = await ui.ImageDescriptor.encoded(buffer);
      dims[i] = ui.Size(d.width.toDouble(), d.height.toDouble());
      d.dispose();
      buffer.dispose();
      if (!_disposed) measured.value++;
    } on Object {
      // Not an image Flutter decodes: drawn as a broken page.
    }
  }

  /// A double-page scan: shown alone in a spread.
  bool wide(int i) {
    final ui.Size? s = dims[i];
    return s != null && s.width > s.height * 1.1;
  }

  /// Height over width; pages not read yet borrow a known page's.
  double aspect(int i) {
    final ui.Size? s = dims[i] ?? (dims.isEmpty ? null : dims.values.first);
    return s == null ? 1.5 : s.height / s.width;
  }

  /// Decoded at the size it is drawn (device pixels), never above the image's
  /// own size. The same bytes and box give the same cache entry, so a
  /// prefetched page is already decoded when it slides in.
  static ImageProvider providerFor(Uint8List bytes, ui.Size boxPx) => ResizeImage(
    MemoryImage(bytes),
    width: boxPx.width.round().clamp(1, 1 << 14),
    height: boxPx.height.round().clamp(1, 1 << 14),
    policy: ResizeImagePolicy.fit,
    allowUpscaling: false,
  );

  // ------------------------------------------------------------ thumbnails

  static const int thumbWidth = 102; // 34dp at 3x.
  static const int _thumbBooks = 40;
  Directory? _thumbDir;
  final Map<int, Future<File?>> _thumbs = <int, Future<File?>>{};

  Future<Directory> _dir() async {
    if (_thumbDir != null) return _thumbDir!;
    final Directory root = Directory(p.join((await getTemporaryDirectory()).path, 'comic-thumbs'));
    final Directory d = Directory(p.join(root.path, fingerprint));
    if (!d.existsSync()) {
      await d.create(recursive: true);
      unawaited(_trim(root));
    }
    return _thumbDir = d;
  }

  /// Keeps the thumbnails of the last [_thumbBooks] comics opened.
  static Future<void> _trim(Directory root) async {
    final List<Directory> books = root.listSync().whereType<Directory>().toList()
      ..sort((Directory a, Directory b) => b.statSync().modified.compareTo(a.statSync().modified));
    for (final Directory d in books.skip(_thumbBooks)) {
      await d.delete(recursive: true);
    }
  }

  /// The page's thumbnail file, made on first ask from the page itself.
  Future<File?> thumb(int i) => _thumbs[i] ??= _makeThumb(i);

  File? thumbNow(int i) {
    final Directory? d = _thumbDir;
    if (d == null) return null;
    final File f = File(p.join(d.path, '$i.png'));
    return f.existsSync() ? f : null;
  }

  Future<File?> _makeThumb(int i) async {
    final Directory d = await _dir();
    final File f = File(p.join(d.path, '$i.png'));
    if (f.existsSync()) return f;
    final Uint8List? b = await bytes(i, prefetch: true);
    if (b == null || _disposed) {
      _thumbs.removeWhere((int k, Future<File?> _) => k == i);
      return null;
    }
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(b, targetWidth: thumbWidth);
      final ui.Image img = (await codec.getNextFrame()).image;
      codec.dispose();
      final ByteData? png = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (png == null) return null;
      await f.writeAsBytes(png.buffer.asUint8List(), flush: true);
      return f;
    } on Object {
      return null;
    }
  }

  void dispose() {
    _disposed = true;
    _bytes.clear();
    _pending.clear();
    _thumbs.clear();
    measured.dispose();
  }
}
