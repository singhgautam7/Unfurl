import 'dart:convert';
import 'dart:typed_data';

/// Decoding for the legacy 8-bit encodings old ebooks use: Windows-1252
/// (MOBI's "1252", most Western FB2 and HTML) and Windows-1251 (Russian FB2).
/// Anything else is read as UTF-8, falling back to Windows-1252.
abstract final class Charsets {
  static String decode(Uint8List bytes, String? label) {
    final String l = (label ?? 'utf-8').toLowerCase().replaceAll('_', '-');
    if (l.contains('1251')) return _table(bytes, _cp1251);
    if (l.contains('1252') || l == 'latin1' || l == 'iso-8859-1' || l == 'us-ascii' || l == 'ascii') {
      return _table(bytes, _cp1252);
    }
    try {
      return utf8.decode(_stripBom(bytes));
    } on FormatException {
      return _table(bytes, _cp1252);
    }
  }

  static Uint8List _stripBom(Uint8List b) =>
      b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF ? Uint8List.sublistView(b, 3) : b;

  static String _table(Uint8List bytes, List<int> high) {
    final List<int> codes = List<int>.filled(bytes.length, 0);
    for (int i = 0; i < bytes.length; i++) {
      final int b = bytes[i];
      codes[i] = b < 0x80 ? b : high[b - 0x80];
    }
    return String.fromCharCodes(codes);
  }

  /// The encoding an XML or HTML document declares in its first bytes.
  static String? declared(Uint8List bytes) {
    final String head = latin1.decode(Uint8List.sublistView(bytes, 0, bytes.length < 1024 ? bytes.length : 1024));
    return RegExp(r'''encoding\s*=\s*["']([\w-]+)''').firstMatch(head)?.group(1) ??
        RegExp(r'''charset\s*=\s*["']?([\w-]+)''', caseSensitive: false).firstMatch(head)?.group(1);
  }

  static final List<int> _cp1252 = <int>[
    0x20AC,
    0x81,
    0x201A,
    0x0192,
    0x201E,
    0x2026,
    0x2020,
    0x2021,
    0x02C6,
    0x2030,
    0x0160,
    0x2039,
    0x0152,
    0x8D,
    0x017D,
    0x8F, //
    0x90,
    0x2018,
    0x2019,
    0x201C,
    0x201D,
    0x2022,
    0x2013,
    0x2014,
    0x02DC,
    0x2122,
    0x0161,
    0x203A,
    0x0153,
    0x9D,
    0x017E,
    0x0178,
    for (int i = 0xA0; i <= 0xFF; i++) i,
  ];

  static final List<int> _cp1251 = <int>[
    0x0402,
    0x0403,
    0x201A,
    0x0453,
    0x201E,
    0x2026,
    0x2020,
    0x2021,
    0x20AC,
    0x2030,
    0x0409,
    0x2039,
    0x040A,
    0x040C,
    0x040B,
    0x040F, //
    0x0452,
    0x2018,
    0x2019,
    0x201C,
    0x201D,
    0x2022,
    0x2013,
    0x2014,
    0x98,
    0x2122,
    0x0459,
    0x203A,
    0x045A,
    0x045C,
    0x045B,
    0x045F,
    0xA0, 0x040E, 0x045E, 0x0408, 0xA4, 0x0490, 0xA6, 0xA7, 0x0401, 0xA9, 0x0404, 0xAB, 0xAC, 0xAD, 0xAE, 0x0407, //
    0xB0, 0xB1, 0x0406, 0x0456, 0x0491, 0xB5, 0xB6, 0xB7, 0x0451, 0x2116, 0x0454, 0xBB, 0x0458, 0x0405, 0x0455, 0x0457,
    for (int i = 0x0410; i <= 0x044F; i++) i,
  ];
}
