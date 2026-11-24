import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../formats/books.dart';
import '../../formats/comics/comic_archive.dart';
import '../../formats/epub/epub.dart' show BookMeta;
import '../../formats/format_problem.dart';
import '../../formats/format_registry.dart';
import '../db/database.dart';
import '../files.dart';
import 'library.dart';

/// Covers on disk, keyed by fingerprint, capped in size. EPUB covers are the
/// book's own art; a PDF's is its first page. Decoded at display size by the
/// tile (`ResizeImage`), so memory holds thumbnails, never full images.
abstract final class Covers {
  static Directory? _dir;

  @visibleForTesting
  static Directory? directoryOverride;
  @visibleForTesting
  static int? capOverride;
  static const int capBytes = 60 * 1024 * 1024;

  /// What is on disk: fingerprint to size in bytes (0: looked for, no cover
  /// art). Read once, off the UI isolate; a tile never touches the disk.
  static final Map<String, int> _sizes = <String, int>{};
  static int _total = 0;

  /// One listenable per cover asked for, so a new cover repaints its own tile.
  static final Map<String, ValueNotifier<File?>> _watched = <String, ValueNotifier<File?>>{};
  static final ValueNotifier<File?> _none = ValueNotifier<File?>(null);

  static Future<Directory>? _opening;

  static Future<Directory> dir() => _opening ??= _open();

  static Future<Directory> _open() async {
    // App storage, not the cache: Android purges caches when space runs low,
    // and every cover would be read again. The cap below keeps it bounded.
    final Directory d = directoryOverride ?? Directory(p.join((await getApplicationSupportDirectory()).path, 'covers'));
    await d.create(recursive: true);
    final Map<String, int> found = await _list(d.path);
    _dir = d;
    found.forEach((String fp, int bytes) => _sizes.putIfAbsent(fp, () => bytes));
    _total = _sizes.values.fold(0, (int a, int b) => a + b);
    // Tiles built before the directory was known look again.
    for (final MapEntry<String, ValueNotifier<File?>> w in _watched.entries) {
      w.value.value = fileFor(w.key);
    }
    return d;
  }

  /// Static and path only, for the isolate.
  static Future<Map<String, int>> _list(String path) => Isolate.run(
    () => <String, int>{
      for (final FileSystemEntity e in Directory(path).listSync())
        if (e is File && e.path.endsWith('.img')) p.basenameWithoutExtension(e.path): e.lengthSync(),
    },
  );

  static File _file(String fingerprint) => File(p.join(_dir!.path, '$fingerprint.img'));

  /// The cover file if one has been made. An empty file marks a book that
  /// has no cover art, so it isn't read again.
  static File? fileFor(String? fingerprint) =>
      fingerprint == null || _dir == null || (_sizes[fingerprint] ?? 0) == 0 ? null : _file(fingerprint);

  /// [fileFor], live: changes when this book's cover is made.
  static ValueListenable<File?> watch(String? fingerprint) =>
      fingerprint == null ? _none : _watched.putIfAbsent(fingerprint, () => ValueNotifier<File?>(fileFor(fingerprint)));

  /// Whether this book's cover was looked for (Android may clear the cache).
  static bool tried(String fingerprint) => _sizes.containsKey(fingerprint);

  static Future<void> write(String fingerprint, Uint8List bytes) async {
    await dir();
    await _file(fingerprint).writeAsBytes(bytes, flush: true);
    _total += bytes.length - (_sizes[fingerprint] ?? 0);
    _sizes[fingerprint] = bytes.length;
    final ValueNotifier<File?>? w = _watched[fingerprint];
    w?.value = fileFor(fingerprint);
    if (_total > (capOverride ?? capBytes)) await _trim();
  }

  /// Oldest covers go first once the cache passes its cap.
  static Future<void> _trim() async {
    final List<String> gone = await _trimIn(_dir!.path, capOverride ?? capBytes);
    for (final String fp in gone) {
      _total -= _sizes.remove(fp) ?? 0;
      _watched[fp]?.value = null;
    }
  }

  static Future<List<String>> _trimIn(String path, int cap) => Isolate.run(() {
    final List<(File, FileStat)> stats = <(File, FileStat)>[
      for (final FileSystemEntity e in Directory(path).listSync())
        if (e is File) (e, e.statSync()),
    ]..sort(((File, FileStat) a, (File, FileStat) b) => b.$2.accessed.compareTo(a.$2.accessed));
    int total = 0;
    final List<String> gone = <String>[];
    for (final (File f, FileStat s) in stats) {
      total += s.size;
      if (total <= cap) continue;
      f.deleteSync();
      gone.add(p.basenameWithoutExtension(f.path));
    }
    return gone;
  });

  /// A comic's cover: its first page, cropped to 2:3 from the top (board 6,
  /// V3), as a small PNG. Decoded at the target width, never at full size.
  static Future<Uint8List?> comicCover(Uint8List page, {int width = 288}) async {
    final ui.Codec codec = await ui.instantiateImageCodec(page, targetWidth: width);
    final ui.Image img = (await codec.getNextFrame()).image;
    codec.dispose();
    try {
      final int height = (width * 1.5).round();
      final ui.PictureRecorder rec = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(rec);
      final double scale = width / img.width > height / img.height ? width / img.width : height / img.height;
      final double w = img.width * scale;
      // Wider than 2:3 (a spread): centred; taller: from the top.
      canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        ui.Rect.fromLTWH((width - w) / 2, 0, w, img.height * scale),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      final ui.Image out = await rec.endRecording().toImage(width, height);
      final ByteData? png = await out.toByteData(format: ui.ImageByteFormat.png);
      out.dispose();
      return png?.buffer.asUint8List();
    } finally {
      img.dispose();
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
            for (final TypedResult r
                in await (db.selectOnly(db.entries)
                      ..addColumns(<Expression<Object>>[db.entries.id, db.entries.fingerprint])
                      ..where(db.entries.enriched.equals(1) & db.entries.fingerprint.isNotNull()))
                    .get())
              if (!Covers.tried(r.read(db.entries.fingerprint)!)) r.read(db.entries.id)!,
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
          if (_marks.length >= 25 || _sinceFlush.elapsedMilliseconds > 1000) await _flush();
        }
        await _flush();
      } while (_again);
    } finally {
      _running = false;
    }
  }

  /// Static, so the isolate's closure carries only the bytes.
  static Future<BookMeta> _meta(String format, Uint8List bytes, String name) =>
      Isolate.run(() => Books.meta(format, bytes, name));

  /// Results waiting to be written: every write to entries re-runs the
  /// library's queries, so they go in together, about once a second.
  final Map<int, EntriesCompanion> _marks = <int, EntriesCompanion>{};
  final Stopwatch _sinceFlush = Stopwatch()..start();

  Future<void> _flush() async {
    _sinceFlush.reset();
    if (_marks.isEmpty) return;
    final Map<int, EntriesCompanion> marks = Map<int, EntriesCompanion>.of(_marks);
    _marks.clear();
    await library.db.batch((Batch b) {
      marks.forEach(
        (int id, EntriesCompanion c) => b.update(library.db.entries, c, where: ($EntriesTable x) => x.id.equals(id)),
      );
    });
  }

  Future<void> _one(Entry e) async {
    Future<void> mark(EntriesCompanion c) async => _marks[e.id] = c;
    String? fp;
    try {
      await pdfrxFlutterInitialize();
      await Covers.dir();
      fp = await Files.fingerprint(e.uri);
      if (fp == null) return await mark(const EntriesCompanion(enriched: Value<int>(-1)));
      final Uint8List head = await Files.withFd<Uint8List>(e.uri, (Fd fd) async => fd.read(0, 512)) ?? Uint8List(0);
      final FormatModule? format = Formats.sniff(head, Formats.of(e.name, e.mime));
      String? title, author, issue;
      int? units;
      if (format == Formats.pdf) {
        await Files.withFd<void>(e.uri, (Fd fd) async {
          final PdfDocument doc = await Files.openPdf(fd, name: e.name, passwordProvider: () => null);
          try {
            units = doc.pages.length;
            if (!Covers.tried(fp!)) await Covers.write(fp, await Covers.renderFirstPage(doc) ?? Uint8List(0));
          } finally {
            await doc.dispose();
          }
        });
      } else if (format == Formats.comics) {
        final ComicArchive comic = await ComicArchive.open(e.uri);
        try {
          title = comic.info?.displayTitle;
          author = comic.info?.writer;
          issue = comic.info?.issue;
          units = comic.pages.length;
          if (!Covers.tried(fp)) {
            final Uint8List? first = await comic.page(0);
            await Covers.write(fp, (first == null ? null : await Covers.comicCover(first)) ?? Uint8List(0));
          }
        } finally {
          await comic.close();
        }
      } else if (format != null) {
        final Uint8List? bytes = await Files.readAll(e.uri);
        if (bytes == null) return await mark(const EntriesCompanion(enriched: Value<int>(-1)));
        final BookMeta meta = await _meta(format.id, bytes, e.name);
        title = meta.title;
        author = meta.author;
        units = meta.units;
        if (!Covers.tried(fp)) await Covers.write(fp, meta.cover ?? Uint8List(0));
      }
      await mark(
        EntriesCompanion(
          fingerprint: Value<String?>(fp),
          title: Value<String?>(title),
          author: Value<String?>(author),
          units: Value<int?>(units),
          issue: Value<String?>(issue),
          enriched: const Value<int>(1),
        ),
      );
    } on FormatProblem catch (p) {
      // Protected or an unreadable variant: listed with its state, never retried.
      await mark(
        EntriesCompanion(
          fingerprint: Value<String?>(fp),
          enriched: Value<int>(switch (p.kind) {
            ProblemKind.drm => -2,
            ProblemKind.unsupported => -3,
            ProblemKind.damaged => -1,
          }),
        ),
      );
    } catch (error) {
      // Locked, damaged or unreadable: listed by name, opened on demand.
      debugPrint('Enricher: ${e.name}: $error');
      await mark(const EntriesCompanion(enriched: Value<int>(-1)));
    }
  }
}
