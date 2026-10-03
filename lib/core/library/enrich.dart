import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../formats/epub/epub.dart';
import '../db/database.dart';
import '../files.dart';
import 'library.dart';

/// Covers on disk, keyed by fingerprint, capped in size. EPUB covers are the
/// book's own art; a PDF's is its first page. Decoded at display size by the
/// tile (`ResizeImage`), so memory holds thumbnails, never full images.
abstract final class Covers {
  static Directory? _dir;
  static final ValueNotifier<int> changed = ValueNotifier<int>(0);
  static const int capBytes = 60 * 1024 * 1024;

  static Future<Directory> dir() async {
    if (_dir != null) return _dir!;
    // App storage, not the cache: Android purges caches when space runs low,
    // and every cover would be read again. The cap below keeps it bounded.
    final Directory d = Directory(p.join((await getApplicationSupportDirectory()).path, 'covers'));
    await d.create(recursive: true);
    _dir = d;
    // Tiles built before the directory was known look again.
    changed.value++;
    return d;
  }

  /// The cover file if one has been made. An empty file marks a book that
  /// has no cover art, so it isn't read again.
  static File? fileFor(String? fingerprint) {
    if (fingerprint == null || _dir == null) return null;
    final File f = File(p.join(_dir!.path, '$fingerprint.img'));
    return f.existsSync() && f.lengthSync() > 0 ? f : null;
  }

  /// Whether this book's cover was looked for (Android may clear the cache).
  static bool tried(String fingerprint) => _dir != null && File(p.join(_dir!.path, '$fingerprint.img')).existsSync();

  static Future<void> write(String fingerprint, Uint8List bytes) async {
    await File(p.join((await dir()).path, '$fingerprint.img')).writeAsBytes(bytes, flush: true);
    changed.value++;
    unawaited(_trim());
  }

  /// Oldest covers go first once the cache passes its cap.
  static Future<void> _trim() async {
    final List<FileSystemEntity> files = (await dir()).listSync();
    int total = 0;
    final List<(File, FileStat)> stats = <(File, FileStat)>[
      for (final FileSystemEntity e in files)
        if (e is File) (e, e.statSync()),
    ]..sort(((File, FileStat) a, (File, FileStat) b) => b.$2.accessed.compareTo(a.$2.accessed));
    for (final (File f, FileStat s) in stats) {
      total += s.size;
      if (total > capBytes) await f.delete();
    }
  }

  /// The first page of a PDF as a small PNG.
  static Future<Uint8List?> renderFirstPage(PdfDocument doc, {double width = 288}) async {
    if (doc.pages.isEmpty) return null;
    final PdfPage page = doc.pages.first;
    final double scale = width / page.width;
    final PdfImage? image = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
      backgroundColor: 0xFFFFFFFF,
    );
    if (image == null) return null;
    try {
      final ui.Image ui0 = await image.createImage();
      final ByteData? png = await ui0.toByteData(format: ui.ImageByteFormat.png);
      ui0.dispose();
      return png?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

/// Reads each new book once in the background: fingerprint, title, author,
/// chapter or page count, and its cover. One file at a time, after scans, so
/// it never competes with the reader.
class Enricher {
  Enricher(this.library);

  final Library library;
  bool _running = false;
  bool _again = false;
  bool _retried = false;

  Future<void> run() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        final AppDatabase db = library.db;
        if (!_retried) {
          // ponytail: failures get one more try per launch; locked files fail
          // fast. Track a failure count if large broken libraries show up.
          _retried = true;
          await Covers.dir();
          await (db.update(
            db.entries,
          )..where((e) => e.enriched.equals(-1))).write(const EntriesCompanion(enriched: Value<int>(0)));
          // Covers can still go missing (cleared app storage, an older build).
          final List<int> lost = <int>[
            for (final Entry e in await (db.select(db.entries)..where((e) => e.enriched.equals(1))).get())
              if (e.fingerprint != null && !Covers.tried(e.fingerprint!)) e.id,
          ];
          if (lost.isNotEmpty) {
            await (db.update(
              db.entries,
            )..where((e) => e.id.isIn(lost))).write(const EntriesCompanion(enriched: Value<int>(0)));
          }
        }
        final List<Entry> todo =
            await (db.select(db.entries)
                  ..where((e) => e.enriched.equals(0) & e.isDir.equals(false) & e.ext.isIn(Library.bookExts))
                  ..limit(200))
                .get();
        for (final Entry e in todo) {
          await _one(e);
        }
      } while (_again);
    } finally {
      _running = false;
    }
  }

  /// Static, so the isolate's closure carries only the bytes.
  static Future<BookMeta> _meta(Uint8List bytes) => Isolate.run(() => Epub.open(bytes).meta());

  Future<void> _one(Entry e) async {
    final AppDatabase db = library.db;
    Future<void> mark(EntriesCompanion c) => (db.update(db.entries)..where((x) => x.id.equals(e.id))).write(c);
    try {
      await pdfrxFlutterInitialize();
      await Covers.dir();
      final String? fp = await Files.fingerprint(e.uri);
      if (fp == null) return await mark(const EntriesCompanion(enriched: Value<int>(-1)));
      String? title, author;
      int? units;
      if (e.ext == 'epub') {
        final Uint8List? bytes = await Files.readAll(e.uri);
        if (bytes == null) return await mark(const EntriesCompanion(enriched: Value<int>(-1)));
        final BookMeta meta = await _meta(bytes);
        title = meta.title;
        author = meta.author;
        units = meta.units;
        if (!Covers.tried(fp)) await Covers.write(fp, meta.cover ?? Uint8List(0));
      } else {
        await Files.withFd<void>(e.uri, (Fd fd) async {
          final PdfDocument doc = await Files.openPdf(fd, name: e.name, passwordProvider: () => null);
          try {
            units = doc.pages.length;
            if (!Covers.tried(fp)) await Covers.write(fp, await Covers.renderFirstPage(doc) ?? Uint8List(0));
          } finally {
            await doc.dispose();
          }
        });
      }
      await mark(
        EntriesCompanion(
          fingerprint: Value<String?>(fp),
          title: Value<String?>(title),
          author: Value<String?>(author),
          units: Value<int?>(units),
          enriched: const Value<int>(1),
        ),
      );
    } catch (error) {
      // Locked, damaged or unreadable: listed by name, opened on demand.
      debugPrint('Enricher: ${e.name}: $error');
      await mark(const EntriesCompanion(enriched: Value<int>(-1)));
    }
  }
}
