import 'dart:convert';
import 'dart:typed_data';

import '../charsets.dart';
import '../epub/epub.dart' show BookMeta;
import '../format_problem.dart';
import '../html_blocks.dart';
import '../reading_document.dart';

/// MOBI (Mobipocket 6), AZW and AZW3/KF8, and PalmDOC `.prc`, into a
/// [ReadingDocument]. Follows foliate-js's `mobi.js` (MIT, John Factotum):
/// a Palm database of records; text records compressed with PalmDOC LZ77
/// or HUFF/CDIC; EXTH metadata; KF8 text reassembled from skeletons and
/// fragments. Pure Dart, run in an isolate. Protected files throw
/// [FormatProblem.drm]; DRM is never removed.
class Mobi {
  Mobi._(this._bytes, this._offsets);

  factory Mobi.open(Uint8List bytes) {
    if (bytes.length < 86) throw const FormatProblem(ProblemKind.damaged, 'Too short for a Kindle book');
    final ByteData d = ByteData.sublistView(bytes);
    final int n = d.getUint16(76);
    final List<int> offsets = <int>[for (int i = 0; i < n; i++) d.getUint32(78 + i * 8), bytes.length];
    final Mobi m = Mobi._(bytes, offsets);
    m._init();
    return m;
  }

  final Uint8List _bytes;
  final List<int> _offsets;

  late _Header _h;

  /// The PDB record where KF8's own record 0 sits (0 for MOBI 6 and pure KF8).
  int _start = 0;

  /// Resources (images) are numbered from record 0's first resource record.
  int _resourceStart = 0;
  bool _kf8 = false;
  bool _palmDoc = false;
  final Map<int, List<Uint8List>> _exth = <int, List<Uint8List>>{};

  int get _count => _offsets.length - 1;

  Uint8List _record(int i) {
    if (i < 0 || i >= _count) throw const FormatProblem(ProblemKind.damaged, 'Missing record');
    final int a = _offsets[i], b = _offsets[i + 1];
    if (a > b || b > _bytes.length) throw const FormatProblem(ProblemKind.damaged, 'Bad record table');
    return Uint8List.sublistView(_bytes, a, b);
  }

  void _init() {
    final String type = ascii.decode(Uint8List.sublistView(_bytes, 60, 68), allowInvalid: true);
    final Uint8List r0 = _record(0);
    _palmDoc = type == 'TEXtREAd';
    if (!_palmDoc && type != 'BOOKMOBI') {
      throw const FormatProblem(ProblemKind.unsupported, 'Not a MOBI or PalmDOC book');
    }
    _h = _Header.parse(r0);
    if (_h.encryption != 0) throw const FormatProblem(ProblemKind.drm, 'Kindle DRM');
    if (_palmDoc) return;
    _readExth(r0, _h);
    _resourceStart = _h.resourceStart;
    _kf8 = _h.version >= 8;
    final int boundary = _u32(_exth[121]?.first) ?? 0xFFFFFFFF;
    if (!_kf8 && boundary < _count) {
      // A combo file: MOBI 6 for old readers, then KF8. Prefer KF8.
      final int at = ascii.decode(_record(boundary).take(8).toList(), allowInvalid: true) == 'BOUNDARY'
          ? boundary + 1
          : boundary;
      try {
        final _Header k = _Header.parse(_record(at));
        if (k.magic == 'MOBI' && k.version >= 8) {
          _h = k;
          _start = at;
          _kf8 = true;
        }
      } on Object {
        // Keep the MOBI 6 part.
      }
    }
  }

  void _readExth(Uint8List r0, _Header h) {
    if (h.exthFlag & 0x40 == 0) return;
    final int s = 16 + h.length;
    if (s + 12 > r0.length || ascii.decode(r0.sublist(s, s + 4), allowInvalid: true) != 'EXTH') return;
    final ByteData d = ByteData.sublistView(r0);
    final int count = d.getUint32(s + 8);
    int pos = s + 12;
    for (int i = 0; i < count && pos + 8 <= r0.length; i++) {
      final int type = d.getUint32(pos), len = d.getUint32(pos + 4);
      if (len < 8 || pos + len > r0.length) break;
      (_exth[type] ??= <Uint8List>[]).add(Uint8List.sublistView(r0, pos + 8, pos + len));
      pos += len;
    }
  }

  static int? _u32(Uint8List? b) => b == null || b.length < 4 ? null : ByteData.sublistView(b).getUint32(0);

  String _str(Uint8List b) => Charsets.decode(b, _h.encoding == 65001 ? 'utf-8' : 'cp1252');

  String? _exthText(int type) {
    final List<Uint8List>? v = _exth[type];
    if (v == null || v.isEmpty) return null;
    final String t = v.map(_str).join(', ').trim();
    return t.isEmpty ? null : t;
  }

  String get _title {
    final String? exth = _exthText(503);
    if (exth != null) return exth;
    final Uint8List r0 = _record(0);
    if (!_palmDoc && _h.titleOffset + _h.titleLength <= r0.length && _h.titleLength > 0) {
      return _str(r0.sublist(_h.titleOffset, _h.titleOffset + _h.titleLength)).trim();
    }
    return latin1.decode(_bytes.sublist(0, 32)).replaceAll(RegExp(r'\x00.*', dotAll: true), '').trim();
  }

  /// Pages turn right to left (manga, Japanese, Arabic).
  bool get rtl => _exthText(527) == 'rtl';

  BookMeta meta() {
    final int? cover = _u32(_exth[201]?.first);
    Uint8List? image;
    if (cover != null && cover != 0xFFFFFFFF) image = _resource(cover);
    return BookMeta(title: _title, author: _exthText(100), cover: image);
  }

  Uint8List? _resource(int index) {
    try {
      final Uint8List r = _record(_resourceStart + index);
      return _isImage(r) ? r : null;
    } on FormatProblem {
      return null;
    }
  }

  static bool _isImage(Uint8List b) =>
      b.length > 4 &&
      ((b[0] == 0xFF && b[1] == 0xD8) || // JPEG
          (b[0] == 0x89 && b[1] == 0x50) || // PNG
          (b[0] == 0x47 && b[1] == 0x49) || // GIF
          (b[0] == 0x42 && b[1] == 0x4D)); // BMP

  // ------------------------------------------------------------ text

  late final Uint8List _text = _readText();

  Uint8List _readText() {
    final _Decompress decompress = switch (_h.compression) {
      1 => (Uint8List b) => b,
      2 => _palmDocDecompress,
      17480 => _Huff(this).decompress,
      _ => throw const FormatProblem(ProblemKind.unsupported, 'Unknown compression'),
    };
    final BytesBuilder out = BytesBuilder(copy: false);
    for (int i = 1; i <= _h.numTextRecords; i++) {
      out.add(decompress(_trim(_record(_start + i))));
    }
    final Uint8List all = out.takeBytes();
    return _h.textLength > 0 && _h.textLength < all.length ? Uint8List.sublistView(all, 0, _h.textLength) : all;
  }

  /// Drops the trailing entries the header's flags say each record carries.
  Uint8List _trim(Uint8List r) {
    final int flags = _h.trailingFlags;
    int end = r.length;
    for (int f = flags >> 1; f != 0; f >>= 1) {
      if (f & 1 == 0) continue;
      int v = 0;
      for (int i = (end - 4).clamp(0, end); i < end; i++) {
        final int b = r[i];
        if (b & 0x80 != 0) v = 0;
        v = (v << 7) | (b & 0x7F);
      }
      end -= v;
      if (end < 0) return Uint8List(0);
    }
    if (flags & 1 != 0 && end > 0) end -= (r[end - 1] & 3) + 1;
    return Uint8List.sublistView(r, 0, end.clamp(0, r.length));
  }

  static Uint8List _palmDocDecompress(Uint8List src) {
    final List<int> out = <int>[];
    int i = 0;
    while (i < src.length) {
      final int c = src[i++];
      if (c == 0 || (c >= 0x09 && c <= 0x7F)) {
        out.add(c);
      } else if (c <= 0x08) {
        for (int k = 0; k < c && i < src.length; k++) {
          out.add(src[i++]);
        }
      } else if (c <= 0xBF) {
        if (i >= src.length) break;
        final int pair = ((c << 8) | src[i++]) & 0x3FFF;
        final int dist = pair >> 3, len = (pair & 7) + 3;
        final int from = out.length - dist;
        if (from < 0) continue;
        for (int k = 0; k < len; k++) {
          out.add(out[from + k]);
        }
      } else {
        out
          ..add(0x20)
          ..add(c ^ 0x80);
      }
    }
    return Uint8List.fromList(out);
  }

  // ------------------------------------------------------------ document

  ReadingDocument document() {
    if (_palmDoc) return _plain();
    return _kf8 ? _kf8Document() : _mobi6Document();
  }

  ReadingDocument _plain() {
    final String text = _str(_text);
    final List<Block> blocks = <Block>[
      for (final String para in text.split(RegExp(r'\r?\n\s*\r?\n')))
        if (para.trim().isNotEmpty) Block(kind: BlockKind.paragraph, runs: <Inline>[Inline(para.trim())]),
    ];
    return ReadingDocument(
      title: _title,
      sections: <Section>[Section(title: '', blocks: blocks.isEmpty ? _emptyBlocks() : blocks)],
    );
  }

  static List<Block> _emptyBlocks() => <Block>[
    Block(kind: BlockKind.paragraph, runs: const <Inline>[Inline('')]),
  ];

  /// Inserts an empty anchor `<a id="...">` at each byte position (moved
  /// before a tag the position falls inside). Positions are bytes, so this
  /// works on a Latin-1 view, where one char is one byte.
  static String _insertAnchors(String raw, Map<int, String> at) {
    final List<int> positions = at.keys.toList()..sort();
    final StringBuffer out = StringBuffer();
    int from = 0;
    for (final int p0 in positions) {
      int p = p0.clamp(0, raw.length);
      final int lt = raw.lastIndexOf('<', p == 0 ? 0 : p - 1);
      if (lt >= 0 && raw.lastIndexOf('>', p == 0 ? 0 : p - 1) < lt) p = lt;
      if (p < from) p = from;
      out
        ..write(raw.substring(from, p))
        ..write('<a id="${at[p0]}"></a>');
      from = p;
    }
    out.write(raw.substring(from));
    return out.toString();
  }

  final Map<String, Uint8List> _resources = <String, Uint8List>{};

  String? _image(String src) {
    int? index;
    if (src.startsWith('kindle:embed:')) {
      final String code = src.substring(13).split('?').first;
      index = int.tryParse(code, radix: 32);
      if (index != null) index -= 1;
    } else {
      index = int.tryParse(src);
      if (index != null) index -= 1;
    }
    if (index == null || index < 0) return null;
    final String key = 'res$index';
    if (_resources.containsKey(key)) return key;
    final Uint8List? r = _resource(index);
    if (r == null) return null;
    _resources[key] = r;
    return key;
  }

  ReadingDocument _build(List<String> htmlSections, List<_NcxEntry> ncx) {
    final List<Section> sections = <Section>[];
    final Map<String, (int, int)> anchors = <String, (int, int)>{};
    for (final String html in htmlSections) {
      final List<Block> blocks = HtmlBlocks(
        resolveImage: _image,
        resolveLink: (String href) => href.startsWith('#') ? href.substring(1) : href,
      ).convert(HtmlBlocks.parse(html));
      if (blocks.isEmpty) {
        // Keep anchors that point at an empty page alive: the next section.
        for (final Match m in RegExp(r'id="([^"]+)"').allMatches(html)) {
          anchors[m.group(1)!] = (sections.length, 0);
        }
        continue;
      }
      for (final Match m in RegExp(r'id="([^"]+)"').allMatches(html)) {
        anchors.putIfAbsent(m.group(1)!, () => (sections.length, 0));
      }
      for (int b = 0; b < blocks.length; b++) {
        if (blocks[b].anchor != null) anchors[blocks[b].anchor!] = (sections.length, b);
      }
      final String title =
          blocks.where((Block b) => b.kind == BlockKind.heading).map((Block b) => b.text).firstOrNull ?? '';
      sections.add(Section(title: title, blocks: blocks));
    }
    // An anchor seen before its section's first block but pointing past the
    // last section: clamp.
    anchors.updateAll(
      (String _, (int, int) v) => v.$1 >= sections.length ? (sections.isEmpty ? 0 : sections.length - 1, 0) : v,
    );
    if (sections.isEmpty) sections.add(Section(title: '', blocks: _emptyBlocks()));
    final List<TocEntry> toc = <TocEntry>[
      for (final _NcxEntry e in ncx)
        if (anchors[e.anchor] case final (int, int) at)
          TocEntry(title: e.label, section: at.$1, block: at.$2, level: e.level),
    ];
    return ReadingDocument(
      title: _title,
      author: _exthText(100),
      sections: sections,
      toc: toc.isEmpty ? null : toc,
      resources: _resources,
      anchors: anchors,
    );
  }

  ReadingDocument _mobi6Document() {
    String raw = latin1.decode(_text);
    final RegExp filepos = RegExp(r'''filepos\s*=\s*["']?0*(\d+)["']?''', caseSensitive: false);
    final List<_NcxEntry> ncx = _ncx();
    final Map<int, String> targets = <int, String>{
      for (final Match m in filepos.allMatches(raw)) int.parse(m.group(1)!): 'filepos${int.parse(m.group(1)!)}',
      for (final _NcxEntry e in ncx)
        if (e.filepos != null) e.filepos!: 'filepos${e.filepos}',
    };
    raw = _insertAnchors(
      raw,
      targets,
    ).replaceAllMapped(filepos, (Match m) => 'href="#filepos${int.parse(m.group(1)!)}"');
    final String html = _str(latin1.encode(raw));
    final List<String> parts = html.split(RegExp(r'<mbp:pagebreak[^>]*>', caseSensitive: false));
    return _build(parts, ncx);
  }

  // ------------------------------------------------------------ KF8

  ReadingDocument _kf8Document() {
    Uint8List flow = _text;
    if (_h.fdst != 0xFFFFFFFF) {
      try {
        final Uint8List f = _record(_start + _h.fdst);
        if (ascii.decode(f.sublist(0, 4), allowInvalid: true) == 'FDST') {
          final ByteData d = ByteData.sublistView(f);
          final int end = d.getUint32(12 + 4);
          if (end <= _text.length) flow = Uint8List.sublistView(_text, 0, end);
        }
      } on Object {
        // The whole text is one flow.
      }
    }
    final _Index skel = _index(_h.skel);
    final _Index frag = _index(_h.frag);
    final List<_Skel> skels = <_Skel>[
      for (final _IndexEntry e in skel.entries)
        _Skel(numFrag: e.tags[1]![0], offset: e.tags[6]![0], length: e.tags[6]![1]),
    ];
    final List<_Frag> frags = <_Frag>[
      for (final _IndexEntry e in frag.entries)
        _Frag(insertOffset: int.parse(e.name), offset: e.tags[6]![0], length: e.tags[6]![1]),
    ];
    // Which section each fragment lands in.
    final List<int> sectionOfFrag = <int>[];
    for (int s = 0; s < skels.length; s++) {
      for (int k = 0; k < skels[s].numFrag; k++) {
        sectionOfFrag.add(s);
      }
    }
    final String flowText = latin1.decode(flow);
    final RegExp pos = RegExp(r'kindle:pos:fid:([0-9A-Va-v]{4}):off:([0-9A-Va-v]{10})');
    final List<_NcxEntry> ncx = _ncx();
    final Set<(int, int)> targets = <(int, int)>{
      for (final Match m in pos.allMatches(flowText))
        (int.parse(m.group(1)!, radix: 32), int.parse(m.group(2)!, radix: 32)),
      for (final _NcxEntry e in ncx)
        if (e.fid != null) (e.fid!, e.off!),
    };
    final Map<int, Map<int, String>> anchorsBySection = <int, Map<int, String>>{};
    for (final (int fid, int off) in targets) {
      if (fid >= frags.length || fid >= sectionOfFrag.length) continue;
      final int s = sectionOfFrag[fid];
      final int p = frags[fid].insertOffset - skels[s].offset + off;
      (anchorsBySection[s] ??= <int, String>{})[p] = 'kpos${fid}_$off';
    }
    final List<String> htmls = <String>[];
    int fragAt = 0;
    for (int s = 0; s < skels.length; s++) {
      final _Skel k = skels[s];
      final int total = k.length + frags.skip(fragAt).take(k.numFrag).fold<int>(0, (int a, _Frag f) => a + f.length);
      if (k.offset + total > flowText.length) {
        fragAt += k.numFrag;
        continue;
      }
      final String rawSection = flowText.substring(k.offset, k.offset + total);
      String assembled = rawSection.substring(0, k.length);
      for (int i = 0; i < k.numFrag && fragAt + i < frags.length; i++) {
        final _Frag f = frags[fragAt + i];
        final int insert = (f.insertOffset - k.offset).clamp(0, assembled.length);
        final int from = k.length + f.offset;
        final String piece = rawSection.substring(
          from.clamp(0, rawSection.length),
          (from + f.length).clamp(0, rawSection.length),
        );
        assembled = assembled.substring(0, insert) + piece + assembled.substring(insert);
      }
      fragAt += k.numFrag;
      final Map<int, String>? anchors = anchorsBySection[s];
      if (anchors != null) assembled = _insertAnchors(assembled, anchors);
      assembled = assembled.replaceAllMapped(
        pos,
        (Match m) => '#kpos${int.parse(m.group(1)!, radix: 32)}_${int.parse(m.group(2)!, radix: 32)}',
      );
      htmls.add(_str(latin1.encode(assembled)));
    }
    if (htmls.isEmpty) return _mobi6FallbackFromFlow(flowText);
    return _build(htmls, ncx);
  }

  /// A KF8 book whose index tables are missing: read the flow as one page.
  ReadingDocument _mobi6FallbackFromFlow(String flowText) =>
      _build(<String>[_str(latin1.encode(flowText))], const <_NcxEntry>[]);

  // ------------------------------------------------------------ indexes

  _Index _index(int relative) {
    if (relative == 0xFFFFFFFF) return _Index(const <_IndexEntry>[], const <int, String>{});
    final int at = _start + relative;
    final Uint8List rec = _record(at);
    if (ascii.decode(rec.sublist(0, 4), allowInvalid: true) != 'INDX') {
      throw const FormatProblem(ProblemKind.damaged, 'Bad index');
    }
    final ByteData d = ByteData.sublistView(rec);
    final int headerLength = d.getUint32(4);
    final int numRecords = d.getUint32(24);
    final int numCncx = d.getUint32(52);
    final int tagx = headerLength;
    if (ascii.decode(rec.sublist(tagx, tagx + 4), allowInvalid: true) != 'TAGX') {
      throw const FormatProblem(ProblemKind.damaged, 'Bad index tags');
    }
    final int tagxLength = d.getUint32(tagx + 4);
    final int controlBytes = d.getUint32(tagx + 8);
    final List<List<int>> tagTable = <List<int>>[
      for (int i = 0; i < (tagxLength - 12) ~/ 4; i++) <int>[for (int k = 0; k < 4; k++) rec[tagx + 12 + i * 4 + k]],
    ];
    final Map<int, String> cncx = <int, String>{};
    int cncxBase = 0;
    for (int i = 0; i < numCncx; i++) {
      final Uint8List c = _record(at + numRecords + i + 1);
      int p = 0;
      while (p < c.length) {
        final int start = p;
        final (int len, int used) = _varLen(c, p);
        p += used;
        if (p + len > c.length) break;
        cncx[cncxBase + start] = _str(c.sublist(p, p + len));
        p += len;
      }
      cncxBase += 0x10000;
    }
    final List<_IndexEntry> entries = <_IndexEntry>[];
    for (int r = 0; r < numRecords; r++) {
      final Uint8List rec2 = _record(at + 1 + r);
      final ByteData d2 = ByteData.sublistView(rec2);
      final int idxt = d2.getUint32(20);
      final int count = d2.getUint32(24);
      for (int j = 0; j < count; j++) {
        final int offset = d2.getUint16(idxt + 4 + 2 * j);
        final int nameLen = rec2[offset];
        final String name = latin1.decode(rec2.sublist(offset + 1, offset + 1 + nameLen));
        final int startPos = offset + 1 + nameLen;
        int controlIndex = 0;
        int p = startPos + controlBytes;
        final List<(int, int?, int?, int)> tags = <(int, int?, int?, int)>[];
        for (final List<int> t in tagTable) {
          final int tag = t[0], numValues = t[1], mask = t[2], end = t[3];
          if (end & 1 != 0) {
            controlIndex++;
            continue;
          }
          final int value = rec2[startPos + controlIndex] & mask;
          if (value == mask) {
            if (_bits(mask) > 1) {
              final (int v, int used) = _varLen(rec2, p);
              tags.add((tag, null, v, numValues));
              p += used;
            } else {
              tags.add((tag, 1, null, numValues));
            }
          } else {
            tags.add((tag, value >> _trailingZeros(mask), null, numValues));
          }
        }
        final Map<int, List<int>> tagMap = <int, List<int>>{};
        for (final (int tag, int? valueCount, int? valueBytes, int numValues) in tags) {
          final List<int> values = <int>[];
          if (valueCount != null) {
            for (int k = 0; k < valueCount * numValues; k++) {
              final (int v, int used) = _varLen(rec2, p);
              values.add(v);
              p += used;
            }
          } else {
            int consumed = 0;
            while (consumed < valueBytes!) {
              final (int v, int used) = _varLen(rec2, p);
              values.add(v);
              p += used;
              consumed += used;
            }
          }
          tagMap[tag] = values;
        }
        entries.add(_IndexEntry(name, tagMap));
      }
    }
    return _Index(entries, cncx);
  }

  /// The book's contents (the NCX index), if it has one.
  List<_NcxEntry> _ncx() {
    if (_h.indx == 0xFFFFFFFF) return const <_NcxEntry>[];
    try {
      final _Index index = _index(_h.indx);
      return <_NcxEntry>[
        for (final _IndexEntry e in index.entries)
          if (index.cncx[e.tags[3]?.first] case final String label)
            _NcxEntry(
              label: label.trim(),
              level: e.tags[4]?.first ?? 0,
              filepos: _kf8 ? null : e.tags[1]?.first,
              fid: _kf8 ? e.tags[6]?.first : null,
              off: _kf8 ? e.tags[6]?.elementAtOrNull(1) : null,
            ),
      ];
    } on Object {
      return const <_NcxEntry>[];
    }
  }

  static (int, int) _varLen(Uint8List b, int i) {
    int v = 0, n = 0;
    for (int k = i; k < b.length && k < i + 4; k++) {
      v = (v << 7) | (b[k] & 0x7F);
      n++;
      if (b[k] & 0x80 != 0) break;
    }
    return (v, n);
  }

  static int _bits(int x) {
    int c = 0;
    for (int v = x; v != 0; v >>= 1) {
      c += v & 1;
    }
    return c;
  }

  static int _trailingZeros(int x) {
    if (x == 0) return 0;
    int c = 0;
    for (int v = x; v & 1 == 0; v >>= 1) {
      c++;
    }
    return c;
  }
}

typedef _Decompress = Uint8List Function(Uint8List);

class _Header {
  _Header({
    required this.compression,
    required this.textLength,
    required this.numTextRecords,
    required this.encryption,
    required this.magic,
    required this.length,
    required this.encoding,
    required this.version,
    required this.titleOffset,
    required this.titleLength,
    required this.resourceStart,
    required this.huffcdic,
    required this.numHuffcdic,
    required this.exthFlag,
    required this.trailingFlags,
    required this.indx,
    required this.fdst,
    required this.frag,
    required this.skel,
  });

  factory _Header.parse(Uint8List r) {
    final ByteData d = ByteData.sublistView(r);
    int u32(int at) => at + 4 <= r.length ? d.getUint32(at) : 0xFFFFFFFF;
    final String magic = r.length >= 20 ? ascii.decode(r.sublist(16, 20), allowInvalid: true) : '';
    final int length = magic == 'MOBI' ? u32(20) : 0;
    final int version = magic == 'MOBI' ? u32(36) : 0;
    return _Header(
      compression: d.getUint16(0),
      textLength: d.getUint32(4),
      numTextRecords: d.getUint16(8),
      encryption: d.getUint16(12),
      magic: magic,
      length: length,
      encoding: magic == 'MOBI' ? u32(28) : 1252,
      version: version,
      titleOffset: u32(84),
      titleLength: u32(88),
      resourceStart: u32(108),
      huffcdic: u32(112),
      numHuffcdic: u32(116),
      exthFlag: magic == 'MOBI' ? u32(128) : 0,
      trailingFlags: magic == 'MOBI' && length >= 0xE4 && version >= 5 && r.length >= 0xF4 ? d.getUint16(0xF2) : 0,
      indx: magic == 'MOBI' && length >= 0xE8 ? u32(244) : 0xFFFFFFFF,
      fdst: version >= 8 ? u32(192) : 0xFFFFFFFF,
      frag: version >= 8 ? u32(248) : 0xFFFFFFFF,
      skel: version >= 8 ? u32(252) : 0xFFFFFFFF,
    );
  }

  final int compression;
  final int textLength;
  final int numTextRecords;
  final int encryption;
  final String magic;
  final int length;
  final int encoding;
  final int version;
  final int titleOffset;
  final int titleLength;
  final int resourceStart;
  final int huffcdic;
  final int numHuffcdic;
  final int exthFlag;
  final int trailingFlags;
  final int indx;
  final int fdst;
  final int frag;
  final int skel;
}

/// HUFF/CDIC decompression: a Huffman code over a dictionary of byte
/// strings, each of which may itself be compressed.
class _Huff {
  _Huff(Mobi m) {
    final Uint8List huff = m._record(m._start + m._h.huffcdic);
    if (ascii.decode(huff.sublist(0, 4), allowInvalid: true) != 'HUFF') {
      throw const FormatProblem(ProblemKind.damaged, 'Bad HUFF record');
    }
    final ByteData d = ByteData.sublistView(huff);
    final int o1 = d.getUint32(8), o2 = d.getUint32(12);
    for (int i = 0; i < 256; i++) {
      final int x = d.getUint32(o1 + i * 4);
      _t1[i] = (x & 0x80 != 0, x & 0x1F, x >> 8);
    }
    for (int i = 0; i < 32; i++) {
      _t2[i + 1] = (d.getUint32(o2 + i * 8), d.getUint32(o2 + i * 8 + 4));
    }
    for (int i = 1; i < m._h.numHuffcdic; i++) {
      final Uint8List c = m._record(m._start + m._h.huffcdic + i);
      if (ascii.decode(c.sublist(0, 4), allowInvalid: true) != 'CDIC') {
        throw const FormatProblem(ProblemKind.damaged, 'Bad CDIC record');
      }
      final ByteData cd = ByteData.sublistView(c);
      final int headerLength = cd.getUint32(4), numEntries = cd.getUint32(8), codeLength = cd.getUint32(12);
      final int n = (1 << codeLength) < numEntries - _dict.length ? 1 << codeLength : numEntries - _dict.length;
      final Uint8List buf = Uint8List.sublistView(c, headerLength);
      final ByteData bd = ByteData.sublistView(buf);
      for (int k = 0; k < n; k++) {
        final int off = bd.getUint16(k * 2);
        final int x = bd.getUint16(off);
        final int len = x & 0x7FFF;
        _dict.add((Uint8List.sublistView(buf, off + 2, off + 2 + len), x & 0x8000 != 0));
      }
    }
  }

  final List<(bool, int, int)> _t1 = List<(bool, int, int)>.filled(256, (false, 0, 0));
  final List<(int, int)> _t2 = List<(int, int)>.filled(33, (0, 0));
  final List<(Uint8List, bool)> _dict = <(Uint8List, bool)>[];

  Uint8List decompress(Uint8List src) {
    final BytesBuilder out = BytesBuilder(copy: false);
    final int bitLength = src.length * 8;
    int i = 0;
    while (i < bitLength) {
      final int bits = _read32(src, i);
      var (bool found, int codeLength, int value) = _t1[bits >> 24];
      if (!found) {
        while (codeLength < 32 && (bits >> (32 - codeLength)) < _t2[codeLength].$1) {
          codeLength++;
        }
        value = _t2[codeLength].$2;
      }
      if (codeLength == 0) break;
      i += codeLength;
      if (i > bitLength) break;
      final int index = value - (bits >> (32 - codeLength));
      if (index < 0 || index >= _dict.length) break;
      var (Uint8List result, bool done) = _dict[index];
      if (!done) {
        result = decompress(result);
        _dict[index] = (result, true);
      }
      out.add(result);
    }
    return out.takeBytes();
  }

  static int _read32(Uint8List b, int from) {
    final int startByte = from >> 3;
    final int end = from + 32;
    final int endByte = end >> 3;
    int bits = 0;
    for (int k = startByte; k <= endByte; k++) {
      bits = (bits << 8) | (k < b.length ? b[k] : 0);
    }
    return (bits >> (8 - (end & 7))) & 0xFFFFFFFF;
  }
}

class _Index {
  _Index(this.entries, this.cncx);

  final List<_IndexEntry> entries;
  final Map<int, String> cncx;
}

class _IndexEntry {
  _IndexEntry(this.name, this.tags);

  final String name;
  final Map<int, List<int>> tags;
}

class _Skel {
  _Skel({required this.numFrag, required this.offset, required this.length});

  final int numFrag;
  final int offset;
  final int length;
}

class _Frag {
  _Frag({required this.insertOffset, required this.offset, required this.length});

  final int insertOffset;
  final int offset;
  final int length;
}

class _NcxEntry {
  _NcxEntry({required this.label, required this.level, this.filepos, this.fid, this.off});

  final String label;
  final int level;
  final int? filepos;
  final int? fid;
  final int? off;

  String get anchor => fid != null ? 'kpos${fid}_$off' : 'filepos$filepos';
}
