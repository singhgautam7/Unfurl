import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// One sheet as displayed text, row-major, plus cell comments.
class SheetData {
  SheetData(this.name, this.rows, {this.comments = const <(int, int), String>{}, this.numeric = const <(int, int)>{}})
    : columns = rows.fold<int>(0, (int m, List<String> r) => math.max(m, r.length));

  final String name;
  final List<List<String>> rows;
  final int columns;
  final Map<(int, int), String> comments;

  /// Cells holding numbers, which align to the end.
  final Set<(int, int)> numeric;

  String cell(int r, int c) => r < rows.length && c < rows[r].length ? rows[r][c] : '';
}

/// XLSX, XLS, ODS and CSV into [SheetData], off the UI isolate.
abstract final class Sheets {
  static List<SheetData> parse(Uint8List bytes, String ext) => switch (ext) {
    'xlsx' || 'xlsm' => _xlsx(bytes),
    'ods' => _ods(bytes),
    'xls' => Xls(bytes).sheets(),
    _ => <SheetData>[_csv(_decode(bytes), ext == 'tsv' ? '\t' : null)],
  };

  /// Column letters: 0 is A, 26 is AA.
  static String column(int c) {
    String s = '';
    int n = c + 1;
    while (n > 0) {
      final int m = (n - 1) % 26;
      s = String.fromCharCode(65 + m) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  static String formatNumber(double v) {
    if (v.isNaN || v.isInfinite) return v.toString();
    final bool whole = v == v.roundToDouble() && v.abs() < 1e15;
    final String fixed = whole ? v.toInt().abs().toString() : v.abs().toStringAsFixed(2);
    final List<String> parts = fixed.split('.');
    final String grouped = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '${v < 0 ? '-' : ''}$grouped${parts.length > 1 ? '.${parts[1]}' : (whole && v.abs() >= 1000 ? '.00' : '')}';
  }

  static String _decode(Uint8List b) {
    try {
      return utf8.decode(b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF ? b.sublist(3) : b);
    } on FormatException {
      return latin1.decode(b);
    }
  }

  static SheetData _csv(String text, String? delimiter) {
    final String sep =
        delimiter ?? (text.split('\n').first.split(';').length > text.split('\n').first.split(',').length ? ';' : ',');
    final List<List<String>> rows = <List<String>>[];
    final Set<(int, int)> numeric = <(int, int)>{};
    List<String> row = <String>[];
    final StringBuffer cell = StringBuffer();
    bool quoted = false;
    for (int i = 0; i < text.length; i++) {
      final String ch = text[i];
      if (quoted) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          cell.write(ch);
        }
      } else if (ch == '"') {
        quoted = true;
      } else if (ch == sep) {
        row.add(cell.toString());
        cell.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
      } else {
        cell.write(ch);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    for (int r = 0; r < rows.length; r++) {
      for (int c = 0; c < rows[r].length; c++) {
        if (r > 0 && double.tryParse(rows[r][c].trim()) != null) numeric.add((r, c));
      }
    }
    return SheetData('Sheet 1', rows, numeric: numeric);
  }

  static (int, int) _ref(String ref) {
    final RegExpMatch m = RegExp(r'([A-Z]+)(\d+)').firstMatch(ref)!;
    int c = 0;
    for (final int u in m[1]!.codeUnits) {
      c = c * 26 + (u - 64);
    }
    return (int.parse(m[2]!) - 1, c - 1);
  }

  static List<SheetData> _xlsx(Uint8List bytes) {
    final Archive zip = ZipDecoder().decodeBytes(bytes);
    String? text(String path) {
      final ArchiveFile? f = zip.findFile(path);
      return f == null ? null : utf8.decode(f.content, allowMalformed: true);
    }

    final List<String> shared = <String>[
      if (text('xl/sharedStrings.xml') != null)
        for (final XmlElement si in XmlDocument.parse(
          text('xl/sharedStrings.xml')!,
        ).descendantElements.where((XmlElement e) => e.localName == 'si'))
          si.descendantElements.where((XmlElement e) => e.localName == 't').map((XmlElement e) => e.innerText).join(),
    ];
    Map<String, String> rels(String part) {
      final String? xml = text(p.posix.join(p.posix.dirname(part), '_rels', '${p.posix.basename(part)}.rels'));
      if (xml == null) return const <String, String>{};
      return <String, String>{
        for (final XmlElement r in XmlDocument.parse(
          xml,
        ).descendantElements.where((XmlElement e) => e.localName == 'Relationship'))
          r.getAttribute('Id')!: _target(part, r.getAttribute('Target')!),
      };
    }

    final Map<String, String> wbRels = rels('xl/workbook.xml');
    final List<SheetData> out = <SheetData>[];
    for (final XmlElement s in XmlDocument.parse(
      text('xl/workbook.xml')!,
    ).descendantElements.where((XmlElement e) => e.localName == 'sheet')) {
      final String? rid = s.attributes
          .where((XmlAttribute a) => a.localName == 'id')
          .map((XmlAttribute a) => a.value)
          .firstOrNull;
      final String? part = rid == null ? null : wbRels[rid];
      final String? xml = part == null ? null : text(part);
      if (part == null || xml == null) continue;
      final List<List<String>> rows = <List<String>>[];
      final Set<(int, int)> numeric = <(int, int)>{};
      for (final XmlElement c in XmlDocument.parse(
        xml,
      ).descendantElements.where((XmlElement e) => e.localName == 'c')) {
        final (int r, int col) = _ref(c.getAttribute('r') ?? 'A1');
        final String type = c.getAttribute('t') ?? 'n';
        final String? v = c.childElements.where((XmlElement e) => e.localName == 'v').firstOrNull?.innerText;
        String value;
        switch (type) {
          case 's':
            value = shared.elementAtOrNull(int.tryParse(v ?? '') ?? -1) ?? '';
          case 'inlineStr':
            value = c.descendantElements
                .where((XmlElement e) => e.localName == 't')
                .map((XmlElement e) => e.innerText)
                .join();
          case 'b':
            value = v == '1' ? 'TRUE' : 'FALSE';
          case 'str' || 'e':
            value = v ?? '';
          default:
            final double? d = double.tryParse(v ?? '');
            value = d == null ? (v ?? '') : formatNumber(d);
            if (d != null) numeric.add((r, col));
        }
        while (rows.length <= r) {
          rows.add(<String>[]);
        }
        final List<String> row = rows[r];
        while (row.length <= col) {
          row.add('');
        }
        row[col] = value;
      }
      final Map<(int, int), String> comments = <(int, int), String>{};
      for (final String target in rels(part).values.where((String t) => t.contains('comments'))) {
        final String? cx = text(target);
        if (cx == null) continue;
        for (final XmlElement cm in XmlDocument.parse(
          cx,
        ).descendantElements.where((XmlElement e) => e.localName == 'comment')) {
          comments[_ref(cm.getAttribute('ref') ?? 'A1')] = cm.descendantElements
              .where((XmlElement e) => e.localName == 't')
              .map((XmlElement e) => e.innerText)
              .join()
              .trim();
        }
      }
      out.add(SheetData(s.getAttribute('name') ?? 'Sheet', rows, comments: comments, numeric: numeric));
    }
    return out;
  }

  static List<SheetData> _ods(Uint8List bytes) {
    final Archive zip = ZipDecoder().decodeBytes(bytes);
    final XmlDocument doc = XmlDocument.parse(utf8.decode(zip.findFile('content.xml')!.content, allowMalformed: true));
    final List<SheetData> out = <SheetData>[];
    for (final XmlElement table in doc.descendantElements.where((XmlElement e) => e.localName == 'table')) {
      final List<List<String>> rows = <List<String>>[];
      final Set<(int, int)> numeric = <(int, int)>{};
      for (final XmlElement tr in table.descendantElements.where((XmlElement e) => e.localName == 'table-row')) {
        final int repeat = math.min(int.tryParse(tr.getAttribute('table:number-rows-repeated') ?? '') ?? 1, 1000);
        final List<String> row = <String>[];
        for (final XmlElement tc in tr.childElements.where(
          (XmlElement e) => e.localName == 'table-cell' || e.localName == 'covered-table-cell',
        )) {
          final int span = math.min(int.tryParse(tc.getAttribute('table:number-columns-repeated') ?? '') ?? 1, 500);
          final String type = tc.getAttribute('office:value-type') ?? '';
          final double? n = double.tryParse(tc.getAttribute('office:value') ?? '');
          final String value = type == 'float' && n != null
              ? formatNumber(n)
              : tc.childElements
                    .where((XmlElement e) => e.localName == 'p')
                    .map((XmlElement e) => e.innerText)
                    .join('\n');
          for (int i = 0; i < span; i++) {
            if (type == 'float') numeric.add((rows.length, row.length));
            row.add(value);
          }
        }
        while (row.isNotEmpty && row.last.isEmpty) {
          row.removeLast();
        }
        for (int i = 0; i < repeat; i++) {
          rows.add(List<String>.of(row));
        }
      }
      while (rows.isNotEmpty && rows.last.isEmpty) {
        rows.removeLast();
      }
      out.add(SheetData(table.getAttribute('table:name') ?? 'Sheet', rows, numeric: numeric));
    }
    return out;
  }
}

/// Legacy Excel (BIFF8 inside an OLE2 compound file): enough of both to show
/// every sheet's values. Formatting and charts are not read.
class Xls {
  Xls(this._bytes) : _data = ByteData.sublistView(_bytes);

  final Uint8List _bytes;
  final ByteData _data;

  List<SheetData> sheets() {
    final Uint8List wb = _stream(<String>{'Workbook', 'Book'});
    final ByteData d = ByteData.sublistView(wb);
    final List<(String, int)> bounds = <(String, int)>[];
    final List<String> sst = <String>[];
    int pos = 0;
    // Globals: sheet names and offsets, the shared string table.
    while (pos + 4 <= wb.length) {
      final int type = d.getUint16(pos, Endian.little), len = d.getUint16(pos + 2, Endian.little);
      final int body = pos + 4;
      if (type == 0x0085) {
        final int offset = d.getUint32(body, Endian.little);
        final (String name, _) = _shortString(wb, body + 6);
        bounds.add((name, offset));
      } else if (type == 0x00FC) {
        _readSst(wb, pos, sst);
      } else if (type == 0x000A) {
        break;
      }
      pos = body + len;
    }
    final List<SheetData> out = <SheetData>[];
    for (final (String name, int offset) in bounds) {
      final Map<(int, int), String> cells = <(int, int), String>{};
      final Set<(int, int)> numeric = <(int, int)>{};
      int maxR = -1, maxC = -1;
      void put(int r, int c, String v, {bool number = false}) {
        cells[(r, c)] = v;
        if (number) numeric.add((r, c));
        maxR = math.max(maxR, r);
        maxC = math.max(maxC, c);
      }

      int q = offset;
      (int, int)? pendingFormula;
      while (q + 4 <= wb.length) {
        final int type = d.getUint16(q, Endian.little), len = d.getUint16(q + 2, Endian.little);
        final int b = q + 4;
        if (type == 0x000A) break;
        switch (type) {
          case 0x0203: // NUMBER
            put(
              d.getUint16(b, Endian.little),
              d.getUint16(b + 2, Endian.little),
              Sheets.formatNumber(d.getFloat64(b + 6, Endian.little)),
              number: true,
            );
          case 0x027E: // RK
            put(
              d.getUint16(b, Endian.little),
              d.getUint16(b + 2, Endian.little),
              Sheets.formatNumber(_rk(d.getUint32(b + 6, Endian.little))),
              number: true,
            );
          case 0x00BD: // MULRK
            final int r = d.getUint16(b, Endian.little);
            final int first = d.getUint16(b + 2, Endian.little);
            final int count = (len - 6) ~/ 6;
            for (int i = 0; i < count; i++) {
              put(r, first + i, Sheets.formatNumber(_rk(d.getUint32(b + 4 + i * 6 + 2, Endian.little))), number: true);
            }
          case 0x00FD: // LABELSST
            put(
              d.getUint16(b, Endian.little),
              d.getUint16(b + 2, Endian.little),
              sst.elementAtOrNull(d.getUint32(b + 6, Endian.little)) ?? '',
            );
          case 0x0204: // LABEL
            final (String s, _) = _longString(wb, b + 6);
            put(d.getUint16(b, Endian.little), d.getUint16(b + 2, Endian.little), s);
          case 0x0006: // FORMULA: the cached result
            final int r = d.getUint16(b, Endian.little), c = d.getUint16(b + 2, Endian.little);
            if (d.getUint16(b + 12, Endian.little) != 0xFFFF) {
              put(r, c, Sheets.formatNumber(d.getFloat64(b + 6, Endian.little)), number: true);
            } else if (wb[b + 6] == 0) {
              pendingFormula = (r, c);
            } else if (wb[b + 6] == 1) {
              put(r, c, wb[b + 8] == 1 ? 'TRUE' : 'FALSE');
            }
          case 0x0207: // STRING, a formula's text result
            if (pendingFormula != null) {
              final (String s, _) = _longString(wb, b);
              put(pendingFormula.$1, pendingFormula.$2, s);
              pendingFormula = null;
            }
          case 0x0205: // BOOLERR
            put(
              d.getUint16(b, Endian.little),
              d.getUint16(b + 2, Endian.little),
              wb[b + 7] == 0 ? (wb[b + 6] == 1 ? 'TRUE' : 'FALSE') : '#ERR',
            );
        }
        q = b + len;
      }
      final List<List<String>> rows = <List<String>>[
        for (int r = 0; r <= maxR; r++) <String>[for (int c = 0; c <= maxC; c++) cells[(r, c)] ?? ''],
      ];
      out.add(SheetData(name, rows, numeric: numeric));
    }
    return out;
  }

  static double _rk(int rk) {
    final double v = (rk & 2) != 0
        ? (rk >> 2).toDouble()
        : ByteData(8).let((ByteData b) {
            b.setUint32(4, rk & 0xFFFFFFFC, Endian.little);
            return b.getFloat64(0, Endian.little);
          });
    return (rk & 1) != 0 ? v / 100 : v;
  }

  /// BIFF8 short string: 1-byte length, flags, chars.
  static (String, int) _shortString(Uint8List b, int at) {
    final int n = b[at];
    final bool wide = b[at + 1] & 1 == 1;
    final int start = at + 2;
    return (_chars(b, start, n, wide), start + n * (wide ? 2 : 1));
  }

  /// BIFF8 string with a 2-byte length.
  static (String, int) _longString(Uint8List b, int at) {
    final int n = b[at] | (b[at + 1] << 8);
    final bool wide = b[at + 2] & 1 == 1;
    final int start = at + 3;
    return (_chars(b, start, n, wide), start + n * (wide ? 2 : 1));
  }

  static String _chars(Uint8List b, int start, int n, bool wide) {
    if (!wide) return latin1.decode(b.sublist(start, math.min(start + n, b.length)));
    final List<int> units = <int>[
      for (int i = 0; i < n && start + i * 2 + 1 < b.length; i++) b[start + i * 2] | (b[start + i * 2 + 1] << 8),
    ];
    return String.fromCharCodes(units);
  }

  /// The SST, following CONTINUE records (each continuation of character
  /// data restarts with its own flags byte).
  static void _readSst(Uint8List wb, int recordAt, List<String> out) {
    final ByteData d = ByteData.sublistView(wb);
    // Gather the record and its continuations as segments.
    final List<(int, int)> segs = <(int, int)>[];
    int pos = recordAt;
    while (true) {
      final int type = d.getUint16(pos, Endian.little), len = d.getUint16(pos + 2, Endian.little);
      if (segs.isNotEmpty && type != 0x003C) break;
      segs.add((pos + 4, len));
      pos += 4 + len;
      if (pos + 4 > wb.length) break;
    }
    int seg = 0, at = segs[0].$1 + 8;
    int segEnd() => segs[seg].$1 + segs[seg].$2;
    void next() {
      seg++;
      at = seg < segs.length ? segs[seg].$1 : wb.length;
    }

    int u8() {
      if (at >= segEnd()) next();
      return wb[at++];
    }

    int u16() => u8() | (u8() << 8);
    int u32() => u16() | (u16() << 16);
    final int unique = d.getUint32(segs[0].$1 + 4, Endian.little);
    for (int i = 0; i < unique && seg < segs.length; i++) {
      final int n = u16();
      int flags = u8();
      final int runs = flags & 8 != 0 ? u16() : 0;
      final int ext = flags & 4 != 0 ? u32() : 0;
      final StringBuffer s = StringBuffer();
      int read = 0;
      while (read < n) {
        if (at >= segEnd()) {
          next();
          if (seg >= segs.length) break;
          flags = wb[at++];
        }
        final bool wide = flags & 1 == 1;
        s.writeCharCode(wide ? (wb[at] | (wb[at + 1] << 8)) : wb[at]);
        at += wide ? 2 : 1;
        read++;
      }
      for (int k = 0; k < runs * 4 + ext; k++) {
        u8();
      }
      out.add(s.toString());
    }
  }

  // ------------------------------------------------------------ OLE2

  Uint8List _stream(Set<String> names) {
    final int sectorSize = 1 << _data.getUint16(0x1E, Endian.little);
    final int miniSize = 1 << _data.getUint16(0x20, Endian.little);
    final int dirStart = _data.getInt32(0x30, Endian.little);
    final int miniCutoff = _data.getUint32(0x38, Endian.little);
    final int miniFatStart = _data.getInt32(0x3C, Endian.little);
    final int difatStart = _data.getInt32(0x44, Endian.little);
    int sectorAt(int s) => 512 + s * sectorSize;

    final List<int> fatSectors = <int>[
      for (int i = 0; i < 109; i++)
        if (_data.getInt32(0x4C + i * 4, Endian.little) >= 0) _data.getInt32(0x4C + i * 4, Endian.little),
    ];
    int difat = difatStart;
    while (difat >= 0 && difat < 0x7FFFFFF0) {
      final int base = sectorAt(difat);
      for (int i = 0; i < sectorSize ~/ 4 - 1; i++) {
        final int v = _data.getInt32(base + i * 4, Endian.little);
        if (v >= 0) fatSectors.add(v);
      }
      difat = _data.getInt32(base + sectorSize - 4, Endian.little);
    }
    final List<int> fat = <int>[
      for (final int s in fatSectors)
        for (int i = 0; i < sectorSize ~/ 4; i++) _data.getInt32(sectorAt(s) + i * 4, Endian.little),
    ];
    Uint8List chain(int start, {int? size}) {
      final BytesBuilder out = BytesBuilder(copy: false);
      int s = start, guard = 0;
      while (s >= 0 && s < fat.length && guard++ < fat.length) {
        final int at = sectorAt(s);
        out.add(_bytes.sublist(at, math.min(at + sectorSize, _bytes.length)));
        s = fat[s];
      }
      final Uint8List all = out.takeBytes();
      return size == null || size > all.length ? all : all.sublist(0, size);
    }

    final Uint8List dir = chain(dirStart);
    final ByteData dd = ByteData.sublistView(dir);
    Uint8List? rootStream;
    for (int e = 0; e + 128 <= dir.length; e += 128) {
      final int nameLen = dd.getUint16(e + 64, Endian.little);
      if (nameLen < 2) continue;
      final String name = String.fromCharCodes(<int>[
        for (int i = 0; i < nameLen ~/ 2 - 1; i++) dd.getUint16(e + i * 2, Endian.little),
      ]);
      final int type = dir[e + 66];
      final int start = dd.getInt32(e + 116, Endian.little);
      final int size = dd.getUint32(e + 120, Endian.little);
      if (type == 5) rootStream = chain(start, size: size);
      if (type == 2 && names.contains(name)) {
        if (size >= miniCutoff) return chain(start, size: size);
        // Small streams live in the mini stream, chained by the mini FAT.
        final Uint8List miniFatBytes = chain(miniFatStart);
        final ByteData mf = ByteData.sublistView(miniFatBytes);
        final BytesBuilder out = BytesBuilder(copy: false);
        int s = start, guard = 0;
        while (s >= 0 && s * 4 < miniFatBytes.length && guard++ < 1 << 20) {
          out.add(rootStream!.sublist(s * miniSize, math.min((s + 1) * miniSize, rootStream.length)));
          s = mf.getInt32(s * 4, Endian.little);
        }
        final Uint8List all = out.takeBytes();
        return all.sublist(0, math.min(size, all.length));
      }
    }
    throw const FormatException('No workbook stream');
  }
}

extension<T> on T {
  R let<R>(R Function(T it) f) => f(this);
}

/// A relationship target: package-absolute ("/xl/...") or relative to the part.
String _target(String part, String target) =>
    target.startsWith('/') ? target.substring(1) : p.posix.normalize(p.posix.join(p.posix.dirname(part), target));
