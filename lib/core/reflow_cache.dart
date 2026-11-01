import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../formats/reading_document.dart';
import '../formats/reading_document_codec.dart';

/// Reflowed documents on disk, keyed by fingerprint. Reader mode for a big PDF
/// takes a long time to prepare; keeping the result means it opens at once
/// next time. Entries are read-only copies of derived data, never user files.
abstract final class ReflowCache {
  /// The user chose this: app storage (not the purgeable cache), 300 MB cap.
  static const int capBytes = 300 * 1024 * 1024;

  @visibleForTesting
  static Directory? directoryOverride;
  @visibleForTesting
  static int? capOverride;

  static Directory? _dir;

  static Future<Directory> _directory() async {
    final Directory? forTest = directoryOverride;
    if (forTest != null) {
      await forTest.create(recursive: true);
      return forTest;
    }
    if (_dir != null) return _dir!;
    // App storage, not the cache: Android purges caches when space runs low,
    // and a big book would have to be prepared all over again.
    final Directory d = Directory(p.join((await getApplicationSupportDirectory()).path, 'reflow'));
    await d.create(recursive: true);
    return _dir = d;
  }

  static String _name(String fingerprint, String producer, int version) =>
      '$fingerprint.$producer.$version.c${ReadingDocumentCodec.version}.bin';

  /// The document [producer] (e.g. 'pdf') made at [version] for this fingerprint, or null.
  static Future<ReadingDocument?> read(String fingerprint, {required String producer, required int version}) async {
    try {
      final File file = File(p.join((await _directory()).path, _name(fingerprint, producer, version)));
      if (!file.existsSync()) return null;
      final Uint8List bytes = await file.readAsBytes();
      final ReadingDocument? doc = await _decode(bytes);
      if (doc == null) {
        // Damaged or from a layout this build does not know: prepare it again.
        await file.delete();
        return null;
      }
      // Android mounts storage noatime, so the modified time is the LRU clock.
      await file.setLastModified(DateTime.now());
      return doc;
    } catch (_) {
      return null;
    }
  }

  /// Stores it (best effort: failures are swallowed), then trims the cache to its cap.
  static Future<void> write(
    String fingerprint,
    ReadingDocument doc, {
    required String producer,
    required int version,
  }) async {
    try {
      final Directory dir = await _directory();
      final String name = _name(fingerprint, producer, version);
      final Uint8List bytes = await _encode(doc);
      // Written beside the real name and renamed, so a crash never leaves a
      // half file where read looks.
      final File tmp = File(p.join(dir.path, '$name.tmp'));
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(p.join(dir.path, name));
      final String prefix = '$fingerprint.$producer.';
      for (final FileSystemEntity e in dir.listSync()) {
        final String base = p.basename(e.path);
        if (e is File && base.startsWith(prefix) && base.endsWith('.bin') && base != name) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
      await _trim(dir);
    } catch (_) {}
  }

  /// Forgets every entry for this fingerprint.
  static Future<void> remove(String fingerprint) async {
    try {
      final Directory dir = await _directory();
      final String prefix = '$fingerprint.';
      for (final FileSystemEntity e in dir.listSync()) {
        if (e is File && p.basename(e.path).startsWith(prefix)) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Least recently used entries go first once the cache passes its cap.
  static Future<void> _trim(Directory dir) async {
    final int cap = capOverride ?? capBytes;
    final DateTime stale = DateTime.now().subtract(const Duration(minutes: 10));
    final List<(File, DateTime, int)> entries = <(File, DateTime, int)>[];
    for (final FileSystemEntity e in dir.listSync()) {
      if (e is! File) continue;
      try {
        final FileStat stat = e.statSync();
        if (e.path.endsWith('.tmp')) {
          // Left by a write that never finished.
          if (stat.modified.isBefore(stale)) await e.delete();
        } else if (e.path.endsWith('.bin')) {
          entries.add((e, stat.modified, stat.size));
        }
      } catch (_) {}
    }
    entries.sort(((File, DateTime, int) a, (File, DateTime, int) b) => b.$2.compareTo(a.$2));
    int total = 0;
    for (final (File f, DateTime _, int size) in entries) {
      total += size;
      if (total > cap) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }

  // Static, so the isolate closure captures only plain data.
  static Future<Uint8List> _encode(ReadingDocument doc) => Isolate.run(() => ReadingDocumentCodec.encode(doc));

  static Future<ReadingDocument?> _decode(Uint8List bytes) => Isolate.run(() => ReadingDocumentCodec.decode(bytes));
}
