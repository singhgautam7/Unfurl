import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../format_problem.dart';

/// A comic archive opened on the platform side (`Comics.kt`): page names in
/// reading order, its ComicInfo, and pages read one at a time on demand.
class ComicArchive {
  ComicArchive._(this._id, this.pages, this.info, {required this.damaged, this.total});

  static const MethodChannel _channel = MethodChannel('unfurl/platform');

  final int _id;

  /// Image entries, naturally sorted ("page2" before "page10").
  final List<String> pages;
  final ComicInfo? info;

  /// Some pages couldn't be read; [pages] holds the ones that could.
  final bool damaged;

  /// Pages the archive claims, when it could be listed.
  final int? total;

  bool _closed = false;

  static Future<ComicArchive> open(String uri) async {
    try {
      final Map<Object?, Object?> m = (await _channel.invokeMapMethod<Object?, Object?>('comicOpen', <String, Object?>{
        'uri': uri,
      }))!;
      final List<String> names = (m['names']! as List<Object?>).cast<String>()..sort(naturalCompare);
      final String? xml = m['info'] as String?;
      return ComicArchive._(
        m['id']! as int,
        names,
        xml == null ? null : ComicInfo.parse(xml),
        damaged: m['damaged']! as bool,
        total: m['total'] as int?,
      );
    } on PlatformException catch (e) {
      throw FormatProblem(switch (e.code) {
        'unsupported' => ProblemKind.unsupported,
        _ => ProblemKind.damaged,
      }, e.message ?? 'Unreadable archive');
    }
  }

  /// The encoded bytes of page [index]; null if it can't be read. A
  /// [cancellable] read (a prefetch) is skipped once [cancelPending] runs.
  Future<Uint8List?> page(int index, {bool cancellable = false}) async {
    if (_closed || index < 0 || index >= pages.length) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('comicPage', <String, Object?>{
        'id': _id,
        'name': pages[index],
        'cancellable': cancellable,
      });
    } on PlatformException {
      return null;
    }
  }

  /// Drops prefetches already queued (pages scrolled away).
  Future<void> cancelPending() => _channel.invokeMethod<void>('comicCancel', <String, Object?>{'id': _id});

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _channel.invokeMethod<void>('comicClose', <String, Object?>{'id': _id});
  }
}

/// `ComicInfo.xml` (the ComicRack schema): what the Library shows and the
/// default reading direction.
class ComicInfo {
  const ComicInfo({this.title, this.series, this.number, this.volume, this.writer, this.rtl = false, this.pageCount});

  static ComicInfo? parse(String xml) {
    try {
      final XmlDocument doc = XmlDocument.parse(xml);
      String? field(String name) {
        final String? t = doc.descendantElements
            .where((XmlElement e) => e.localName == name)
            .firstOrNull
            ?.innerText
            .trim();
        return t == null || t.isEmpty ? null : t;
      }

      return ComicInfo(
        title: field('Title'),
        series: field('Series'),
        number: field('Number'),
        volume: field('Volume'),
        writer: field('Writer'),
        rtl: field('Manga') == 'YesAndRightToLeft',
        pageCount: int.tryParse(field('PageCount') ?? ''),
      );
    } on XmlException {
      return null;
    }
  }

  final String? title;
  final String? series;
  final String? number;
  final String? volume;
  final String? writer;
  final bool rtl;
  final int? pageCount;

  /// "#14", "Vol. 2": the issue badge and meta line (board 6, V3 covers).
  String? get issue => number != null ? '#$number' : (volume != null ? 'Vol. $volume' : null);

  /// Series is the title on a comic's tile; else the issue's own title.
  String? get displayTitle => series ?? title;
}

/// Natural order: digit runs compare as numbers, the rest case-insensitively,
/// so "page2.jpg" sorts before "page10.jpg" and "Ch 9/01" before "Ch 10/01".
int naturalCompare(String a, String b) {
  final RegExp chunk = RegExp(r'\d+|\D+');
  final List<String> x = chunk.allMatches(a.toLowerCase()).map((Match m) => m[0]!).toList();
  final List<String> y = chunk.allMatches(b.toLowerCase()).map((Match m) => m[0]!).toList();
  for (int i = 0; i < x.length && i < y.length; i++) {
    final int? nx = int.tryParse(x[i]), ny = int.tryParse(y[i]);
    final int c = nx != null && ny != null
        ? (nx != ny ? nx.compareTo(ny) : x[i].length.compareTo(y[i].length))
        : x[i].compareTo(y[i]);
    if (c != 0) return c;
  }
  final int c = x.length.compareTo(y.length);
  return c != 0 ? c : a.compareTo(b);
}
