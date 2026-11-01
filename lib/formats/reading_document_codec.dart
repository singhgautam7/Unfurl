import 'dart:convert';
import 'dart:typed_data';

import 'reading_document.dart';

/// A [ReadingDocument] as bytes, so a reflowed document can sit on disk and
/// open at once next time. Pure Dart: it runs on an isolate.
///
/// Layout: `UNRF`, the [version] as a varint, then title, author, a flag byte
/// (simplified 1, scanned 2, mono 4), unit label, sections (title, blocks),
/// toc, anchors and resources. Unsigned numbers are LEB128 varints, signed
/// ones zig-zag varints, strings a varint byte length plus UTF-8. Offsets
/// that [ReadingDocument] computes (`start`, `length`, `text`) are not stored.
abstract final class ReadingDocumentCodec {
  /// Bump on any change to the byte layout.
  static const int version = 1;

  static const List<int> _magic = <int>[0x55, 0x4E, 0x52, 0x46]; // UNRF

  // Inline flags.
  static const int _bold = 1, _italic = 2, _mono = 4, _small = 8, _hasHref = 16;

  // Block flags: which optional fields follow.
  static const int _hasOrdinal = 1,
      _hasChecked = 2,
      _checkedValue = 4,
      _hasImage = 8,
      _hasRows = 16,
      _hasSource = 32,
      _hasAnchor = 64;

  static Uint8List encode(ReadingDocument doc) {
    final _Writer w = _Writer();
    for (final int b in _magic) {
      w.byte(b);
    }
    w.uint(version);
    w.string(doc.title);
    w.nullableString(doc.author);
    w.byte((doc.simplified ? 1 : 0) | (doc.scanned ? 2 : 0) | (doc.mono ? 4 : 0));
    w.string(doc.unitLabel);
    w.uint(doc.sections.length);
    for (final Section s in doc.sections) {
      w.string(s.title);
      w.uint(s.blocks.length);
      for (final Block b in s.blocks) {
        _writeBlock(w, b);
      }
    }
    w.uint(doc.toc.length);
    for (final TocEntry t in doc.toc) {
      w.string(t.title);
      w.uint(t.section);
      w.uint(t.block);
      w.sint(t.level);
    }
    w.uint(doc.anchors.length);
    doc.anchors.forEach((String key, (int, int) at) {
      w.string(key);
      w.sint(at.$1);
      w.sint(at.$2);
    });
    w.uint(doc.resources.length);
    doc.resources.forEach((String key, Uint8List data) {
      w.string(key);
      w.uint(data.length);
      w.bytes(data);
    });
    return w.finish();
  }

  static void _writeBlock(_Writer w, Block b) {
    w.uint(b.kind.index);
    w.sint(b.level);
    final int flags =
        (b.ordinal != null ? _hasOrdinal : 0) |
        (b.checked != null ? _hasChecked : 0) |
        (b.checked == true ? _checkedValue : 0) |
        (b.image != null ? _hasImage : 0) |
        (b.rows != null ? _hasRows : 0) |
        (b.source != null ? _hasSource : 0) |
        (b.anchor != null ? _hasAnchor : 0);
    w.byte(flags);
    if (b.ordinal != null) w.sint(b.ordinal!);
    if (b.image != null) w.string(b.image!);
    if (b.anchor != null) w.string(b.anchor!);
    w.uint(b.runs.length);
    for (final Inline r in b.runs) {
      w.byte(
        (r.bold ? _bold : 0) |
            (r.italic ? _italic : 0) |
            (r.mono ? _mono : 0) |
            (r.small ? _small : 0) |
            (r.href != null ? _hasHref : 0),
      );
      w.string(r.text);
      if (r.href != null) w.string(r.href!);
    }
    final List<List<String>>? rows = b.rows;
    if (rows != null) {
      w.uint(rows.length);
      for (final List<String> row in rows) {
        w.uint(row.length);
        for (final String cell in row) {
          w.string(cell);
        }
      }
    }
    final SourceRef? s = b.source;
    if (s != null) {
      w.uint(s.page);
      w.uint(s.start);
      w.uint(s.end);
      final List<int>? map = s.charMap;
      w.byte(map == null ? 0 : 1);
      if (map != null) {
        w.uint(map.length);
        int prev = 0;
        for (final int v in map) {
          w.sint(v - prev);
          prev = v;
        }
      }
    }
  }

  /// Null for bytes that aren't a complete document of this version.
  static ReadingDocument? decode(Uint8List bytes) {
    try {
      final _Reader r = _Reader(bytes);
      for (final int m in _magic) {
        if (r.byte() != m) return null;
      }
      if (r.uint() != version) return null;
      final String title = r.string();
      final String? author = r.nullableString();
      final int docFlags = r.byte();
      final String unitLabel = r.string();
      final List<Section> sections = <Section>[];
      final int sectionCount = r.count();
      for (int i = 0; i < sectionCount; i++) {
        final String sTitle = r.string();
        final int blockCount = r.count();
        final List<Block> blocks = <Block>[];
        for (int j = 0; j < blockCount; j++) {
          blocks.add(_readBlock(r));
        }
        sections.add(Section(title: sTitle, blocks: blocks));
      }
      final List<TocEntry> toc = <TocEntry>[];
      final int tocCount = r.count();
      for (int i = 0; i < tocCount; i++) {
        toc.add(TocEntry(title: r.string(), section: r.uint(), block: r.uint(), level: r.sint()));
      }
      final Map<String, (int, int)> anchors = <String, (int, int)>{};
      final int anchorCount = r.count();
      for (int i = 0; i < anchorCount; i++) {
        final String key = r.string();
        anchors[key] = (r.sint(), r.sint());
      }
      final Map<String, Uint8List> resources = <String, Uint8List>{};
      final int resourceCount = r.count();
      for (int i = 0; i < resourceCount; i++) {
        final String key = r.string();
        resources[key] = Uint8List.fromList(r.bytes(r.uint()));
      }
      if (!r.atEnd) return null;
      return ReadingDocument(
        title: title,
        author: author,
        sections: sections,
        toc: toc,
        resources: resources,
        simplified: docFlags & 1 != 0,
        scanned: docFlags & 2 != 0,
        unitLabel: unitLabel,
        anchors: anchors,
        mono: docFlags & 4 != 0,
      );
    } catch (_) {
      return null;
    }
  }

  static Block _readBlock(_Reader r) {
    final int kindIndex = r.uint();
    if (kindIndex >= BlockKind.values.length) throw const FormatException('block kind');
    final int level = r.sint();
    final int flags = r.byte();
    final int? ordinal = flags & _hasOrdinal != 0 ? r.sint() : null;
    final String? image = flags & _hasImage != 0 ? r.string() : null;
    final String? anchor = flags & _hasAnchor != 0 ? r.string() : null;
    final int runCount = r.count();
    final List<Inline> runs = <Inline>[];
    for (int i = 0; i < runCount; i++) {
      final int f = r.byte();
      final String text = r.string();
      final String? href = f & _hasHref != 0 ? r.string() : null;
      runs.add(
        Inline(
          text,
          bold: f & _bold != 0,
          italic: f & _italic != 0,
          mono: f & _mono != 0,
          href: href,
          small: f & _small != 0,
        ),
      );
    }
    List<List<String>>? rows;
    if (flags & _hasRows != 0) {
      rows = <List<String>>[];
      final int rowCount = r.count();
      for (int i = 0; i < rowCount; i++) {
        final int cells = r.count();
        rows.add(<String>[for (int c = 0; c < cells; c++) r.string()]);
      }
    }
    SourceRef? source;
    if (flags & _hasSource != 0) {
      final int page = r.uint();
      final int start = r.uint();
      final int end = r.uint();
      List<int>? map;
      if (r.byte() == 1) {
        final int n = r.count();
        map = List<int>.filled(n, 0);
        int prev = 0;
        for (int i = 0; i < n; i++) {
          prev += r.sint();
          map[i] = prev;
        }
      }
      source = SourceRef(page: page, start: start, end: end, charMap: map);
    }
    return Block(
      kind: BlockKind.values[kindIndex],
      runs: runs,
      level: level,
      ordinal: ordinal,
      checked: flags & _hasChecked != 0 ? flags & _checkedValue != 0 : null,
      image: image,
      rows: rows,
      source: source,
      anchor: anchor,
    );
  }
}

/// A byte buffer that doubles when full.
class _Writer {
  Uint8List _buf = Uint8List(1 << 16);
  int _len = 0;

  void _room(int n) {
    if (_len + n <= _buf.length) return;
    int size = _buf.length * 2;
    while (size < _len + n) {
      size *= 2;
    }
    final Uint8List next = Uint8List(size)..setRange(0, _len, _buf);
    _buf = next;
  }

  void byte(int b) {
    _room(1);
    _buf[_len++] = b;
  }

  void uint(int v) {
    _room(10);
    while (v > 0x7F || v < 0) {
      _buf[_len++] = (v & 0x7F) | 0x80;
      v >>>= 7;
    }
    _buf[_len++] = v;
  }

  void sint(int v) => uint((v << 1) ^ (v >> 63));

  void bytes(Uint8List data) {
    _room(data.length);
    _buf.setRange(_len, _len + data.length, data);
    _len += data.length;
  }

  void string(String s) {
    final Uint8List data = utf8.encode(s);
    uint(data.length);
    bytes(data);
  }

  void nullableString(String? s) {
    byte(s == null ? 0 : 1);
    if (s != null) string(s);
  }

  /// Exactly the bytes written (a copy, so the spare capacity is not kept or sent).
  Uint8List finish() => _buf.sublist(0, _len);
}

/// Reads what [_Writer] wrote; throws on anything that runs past the end.
class _Reader {
  _Reader(this._buf);

  final Uint8List _buf;
  int _pos = 0;

  bool get atEnd => _pos == _buf.length;

  int byte() {
    if (_pos >= _buf.length) throw const FormatException('truncated');
    return _buf[_pos++];
  }

  int uint() {
    int result = 0;
    for (int shift = 0; shift < 70; shift += 7) {
      final int b = byte();
      result |= (b & 0x7F) << shift;
      if (b & 0x80 == 0) return result;
    }
    throw const FormatException('varint');
  }

  int sint() {
    final int v = uint();
    return (v >>> 1) ^ -(v & 1);
  }

  /// An element count. Every element takes at least a byte, so a count above
  /// what is left is corrupt (and must not size an allocation).
  int count() {
    final int n = uint();
    if (n < 0 || n > _buf.length - _pos) throw const FormatException('count');
    return n;
  }

  Uint8List bytes(int n) {
    if (n < 0 || n > _buf.length - _pos) throw const FormatException('truncated');
    final Uint8List out = Uint8List.sublistView(_buf, _pos, _pos + n);
    _pos += n;
    return out;
  }

  String string() => utf8.decode(bytes(uint()));

  String? nullableString() => byte() == 0 ? null : string();
}
