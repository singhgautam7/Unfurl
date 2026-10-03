import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import 'platform/platform.dart';

/// Reads a document through the descriptor Android handed over, with
/// `pread`, so every reader (PDFium, zip, the fingerprint) can seek without
/// copying the file. The descriptor is never reopened by path: Android's
/// storage layer refuses `/proc/self/fd/N` to an app without storage
/// permissions. Read-only: nothing here opens a file for writing (data rule 1).
abstract final class Files {
  /// Runs [body] with an open descriptor for [uri]; null when access is gone.
  static Future<T?> withFd<T>(String uri, Future<T> Function(Fd fd) body) async {
    final int? fd = await Platform.openFd(uri);
    if (fd == null) return null;
    try {
      return await body(Fd(fd));
    } finally {
      await Platform.closeFd(fd);
    }
  }

  /// The whole file, read off the UI isolate.
  static Future<Uint8List?> readAll(String uri) => withFd<Uint8List>(uri, (Fd fd) => Isolate.run(fd.readAll));

  /// A file's identity: size plus hashes of its first and last 64 KB. A file
  /// that moves, or whose folder is granted again, keeps its fingerprint and
  /// with it the reading position and every highlight (data rule 2).
  static Future<String?> fingerprint(String uri) =>
      withFd<String>(uri, (Fd fd) => Isolate.run(() => fingerprintOf(fd.length, fd.read)));

  static String fingerprintOf(int size, Uint8List Function(int position, int length) read) {
    const int chunk = 64 * 1024;
    final Uint8List head = read(0, chunk);
    final Uint8List tail = read(size > chunk ? size - chunk : 0, chunk);
    return '${size.toRadixString(36)}-${_fnv(head).toRadixString(36)}-${_fnv(tail).toRadixString(36)}';
  }

  /// A PDF read on demand through [fd], which must stay open until the
  /// document is disposed.
  static Future<PdfDocument> openPdf(Fd fd, {required String name, PdfPasswordProvider? passwordProvider}) =>
      PdfDocument.openCustom(
        read: fd.readInto,
        fileSize: fd.length,
        sourceName: name,
        passwordProvider: passwordProvider,
      );

  /// FNV-1a, 32-bit, twice with different offsets for 64 bits of spread.
  static int _fnv(Uint8List bytes) {
    int a = 0x811c9dc5, b = 0x050c5d1f;
    for (final int x in bytes) {
      a = ((a ^ x) * 0x01000193) & 0xffffffff;
      b = ((b ^ x) * 0x01000193) & 0xffffffff;
    }
    return ((a & 0x7fffffff) << 32) | b;
  }

  /// "1.2 MB", "96 KB".
  static String size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const List<String> _days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// "Yesterday", "Mon", "28 Sep", as the boards date files.
  static String when(int millis, {DateTime? now}) {
    if (millis <= 0) return '';
    final DateTime t = DateTime.fromMillisecondsSinceEpoch(millis);
    final DateTime n = now ?? DateTime.now();
    final int days = DateTime(n.year, n.month, n.day).difference(DateTime(t.year, t.month, t.day)).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return _days[t.weekday - 1];
    return t.year == n.year ? '${t.day} ${_months[t.month - 1]}' : '${t.day} ${_months[t.month - 1]} ${t.year}';
  }

  /// "2 days ago", "3 weeks ago", for notes.
  static String ago(DateTime t, {DateTime? now}) {
    final Duration d = (now ?? DateTime.now()).difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return d.inHours == 1 ? '1 hour ago' : '${d.inHours} hours ago';
    if (d.inDays == 1) return 'Yesterday';
    if (d.inDays < 7) return '${d.inDays} days ago';
    if (d.inDays < 14) return 'Last week';
    if (d.inDays < 31) return '${d.inDays ~/ 7} weeks ago';
    if (d.inDays < 62) return '1 month ago';
    return '${d.inDays ~/ 30} months ago';
  }
}

// The 64-bit variants exist on every Android ABI, so offsets past 2 GB work
// on 32-bit devices too.
@Native<Int64 Function(Int32, Pointer<Uint8>, Size, Int64)>(symbol: 'pread64', isLeaf: true)
external int _pread(int fd, Pointer<Uint8> buffer, int size, int offset);

@Native<Int64 Function(Int32, Int64, Int32)>(symbol: 'lseek64', isLeaf: true)
external int _lseek(int fd, int offset, int whence);

/// An open, read-only file descriptor. Positional reads only, so one
/// descriptor can serve several readers and isolates at once.
final class Fd {
  const Fd(this.fd);

  final int fd;

  int get length => _lseek(fd, 0, 2);

  /// Fills [buffer] from [position]; returns the bytes read (short at the end).
  int readInto(Uint8List buffer, int position, [int? size]) {
    final int want = size ?? buffer.length;
    int done = 0;
    while (done < want) {
      final Uint8List rest = Uint8List.sublistView(buffer, done, want);
      final int n = _pread(fd, rest.address, want - done, position + done);
      if (n <= 0) break;
      done += n;
    }
    return done;
  }

  Uint8List read(int position, int length) {
    final Uint8List b = Uint8List(length);
    return Uint8List.sublistView(b, 0, readInto(b, position));
  }

  Uint8List readAll() => read(0, length);
}
