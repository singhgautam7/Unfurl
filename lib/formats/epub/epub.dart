import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../format_problem.dart';
import '../html_blocks.dart';
import '../reading_document.dart';

/// Title, author and cover, read without converting the whole book.
class BookMeta {
  const BookMeta({this.title, this.author, this.cover, this.units});

  final String? title;
  final String? author;
  final Uint8List? cover;

  /// Chapters (EPUB) or pages (PDF).
  final int? units;
}

/// EPUB 2 and 3: OPF metadata, spine order, nav or NCX table of contents,
/// XHTML through [HtmlBlocks]. Runs in an isolate (pure Dart).
class Epub {
  Epub._(this._zip, this._opfPath, this._opf);

  factory Epub.open(Uint8List bytes) {
    final Archive zip = ZipDecoder().decodeBytes(bytes);
    _checkDrm(zip);
    final XmlDocument container = XmlDocument.parse(_text(zip, 'META-INF/container.xml')!);
    final String opfPath = container.descendantElements
        .firstWhere((XmlElement e) => e.localName == 'rootfile')
        .getAttribute('full-path')!;
    return Epub._(zip, opfPath, XmlDocument.parse(_text(zip, opfPath)!));
  }

  final Archive _zip;
  final String _opfPath;
  final XmlDocument _opf;

  /// Font obfuscation (IDPF and Adobe) only scrambles embedded fonts and the
  /// book still reads; any other encryption, an Adobe rights file or a
  /// Readium LCP licence means DRM. Detected, never removed.
  static void _checkDrm(Archive zip) {
    if (zip.findFile('META-INF/license.lcpl') != null) throw const FormatProblem(ProblemKind.drm, 'Readium LCP');
    if (zip.findFile('META-INF/rights.xml') != null) throw const FormatProblem(ProblemKind.drm, 'Adobe DRM');
    final String? enc = _text(zip, 'META-INF/encryption.xml');
    if (enc == null) return;
    const Set<String> obfuscation = <String>{'http://www.idpf.org/2008/embedding', 'http://ns.adobe.com/pdf/enc#RC'};
    final Iterable<String?> algorithms = XmlDocument.parse(enc).descendantElements
        .where((XmlElement e) => e.localName == 'EncryptionMethod')
        .map((XmlElement e) => e.getAttribute('Algorithm'));
    if (algorithms.any((String? a) => !obfuscation.contains(a))) {
      throw const FormatProblem(ProblemKind.drm, 'Encrypted');
    }
  }

  static String? _text(Archive zip, String path) {
    final ArchiveFile? f = zip.findFile(path) ?? zip.findFile(Uri.decodeFull(path));
    return f == null ? null : utf8.decode(f.content, allowMalformed: true);
  }

  String _resolve(String from, String href) {
    final String clean = Uri.decodeFull(href.split('#').first);
    return p.posix.normalize(p.posix.join(p.posix.dirname(from), clean));
  }

  late final Map<String, XmlElement> _manifest = <String, XmlElement>{
    for (final XmlElement item in _opf.descendantElements.where((XmlElement e) => e.localName == 'item'))
      item.getAttribute('id')!: item,
  };

  String? _meta(String name) => _opf.descendantElements
      .where((XmlElement e) => e.localName == name)
      .map((XmlElement e) => e.innerText.trim())
      .where((String t) => t.isNotEmpty)
      .firstOrNull;

  late final List<String> _spine = <String>[
    for (final XmlElement ref in _opf.descendantElements.where((XmlElement e) => e.localName == 'itemref'))
      if (ref.getAttribute('linear') != 'no' && _manifest[ref.getAttribute('idref')] != null)
        _resolve(_opfPath, _manifest[ref.getAttribute('idref')]!.getAttribute('href')!),
  ];

  BookMeta meta() => BookMeta(title: _meta('title'), author: _meta('creator'), cover: _cover(), units: _spine.length);

  Uint8List? _cover() {
    XmlElement? item = _manifest.values
        .where((XmlElement e) => (e.getAttribute('properties') ?? '').split(' ').contains('cover-image'))
        .firstOrNull;
    if (item == null) {
      final String? id = _opf.descendantElements
          .where((XmlElement e) => e.localName == 'meta' && e.getAttribute('name') == 'cover')
          .map((XmlElement e) => e.getAttribute('content'))
          .firstOrNull;
      item = id == null ? null : _manifest[id];
    }
    item ??= _manifest.values
        .where(
          (XmlElement e) =>
              (e.getAttribute('media-type') ?? '').startsWith('image/') &&
              (e.getAttribute('id') ?? '').toLowerCase().contains('cover'),
        )
        .firstOrNull;
    if (item == null) return null;
    return _zip.findFile(_resolve(_opfPath, item.getAttribute('href')!))?.content;
  }

  ReadingDocument document() {
    final Map<String, Uint8List> resources = <String, Uint8List>{};
    final List<Section> sections = <Section>[];
    final Map<String, int> sectionOf = <String, int>{};
    final Map<String, (int, int)> anchors = <String, (int, int)>{};
    final List<_NavPoint> nav = _nav();
    final Map<String, String> navTitle = <String, String>{for (final _NavPoint n in nav.reversed) n.path: n.title};
    for (final String path in _spine) {
      final String? html = _text(_zip, path);
      if (html == null) continue;
      final List<Block> blocks = HtmlBlocks(
        resolveImage: (String src) {
          final String key = _resolve(path, src);
          final ArchiveFile? f = _zip.findFile(key);
          if (f == null) return null;
          resources[key] = f.content;
          return key;
        },
        resolveLink: (String href) => href.startsWith('#')
            ? '$path$href'
            : _resolve(path, href) + (_fragment(href) == null ? '' : '#${_fragment(href)}'),
      ).convert(HtmlBlocks.parse(html));
      if (blocks.isEmpty) continue;
      final String title =
          navTitle[path] ??
          blocks.where((Block b) => b.kind == BlockKind.heading).map((Block b) => b.text).firstOrNull ??
          '';
      sectionOf[path] = sections.length;
      anchors[path] = (sections.length, 0);
      for (int b = 0; b < blocks.length; b++) {
        if (blocks[b].anchor != null) anchors['$path#${blocks[b].anchor}'] = (sections.length, b);
      }
      sections.add(Section(title: title, blocks: blocks));
    }
    final List<TocEntry> toc = <TocEntry>[
      for (final _NavPoint n in nav)
        if (sectionOf[n.path] != null)
          TocEntry(
            title: n.title,
            section: sectionOf[n.path]!,
            block: _anchorBlock(sections[sectionOf[n.path]!], n.fragment),
            level: n.level,
          ),
    ];
    if (sections.isEmpty) {
      sections.add(
        Section(
          title: '',
          blocks: <Block>[
            Block(kind: BlockKind.paragraph, runs: const <Inline>[Inline('')]),
          ],
        ),
      );
    }
    return ReadingDocument(
      title: _meta('title') ?? '',
      author: _meta('creator'),
      sections: sections,
      toc: toc.isEmpty ? null : toc,
      resources: resources,
      anchors: anchors,
    );
  }

  static int _anchorBlock(Section s, String? fragment) {
    if (fragment == null) return 0;
    final int i = s.blocks.indexWhere((Block b) => b.anchor == fragment);
    return i < 0 ? 0 : i;
  }

  /// The book's own table of contents: EPUB 3 nav first, then NCX.
  List<_NavPoint> _nav() {
    final XmlElement? navItem = _manifest.values
        .where((XmlElement e) => (e.getAttribute('properties') ?? '').split(' ').contains('nav'))
        .firstOrNull;
    if (navItem != null) {
      final String navPath = _resolve(_opfPath, navItem.getAttribute('href')!);
      final String? html = _text(_zip, navPath);
      if (html != null) {
        final XmlDocument doc = HtmlBlocks.parse(html);
        final XmlElement? toc =
            doc.descendantElements
                .where(
                  (XmlElement e) =>
                      e.localName == 'nav' &&
                      (e.getAttribute('type', namespaceUri: '*') ?? e.getAttribute('epub:type')) == 'toc',
                )
                .firstOrNull ??
            doc.descendantElements.where((XmlElement e) => e.localName == 'nav').firstOrNull;
        if (toc != null) {
          final List<_NavPoint> out = <_NavPoint>[];
          void walk(XmlElement ol, int level) {
            for (final XmlElement li in ol.childElements.where((XmlElement e) => e.localName == 'li')) {
              final XmlElement? a = li.childElements.where((XmlElement e) => e.localName == 'a').firstOrNull;
              final String? href = a?.getAttribute('href');
              if (a != null && href != null) {
                out.add(
                  _NavPoint(
                    a.innerText.replaceAll(RegExp(r'\s+'), ' ').trim(),
                    _resolve(navPath, href),
                    _fragment(href),
                    level,
                  ),
                );
              }
              for (final XmlElement sub in li.childElements.where((XmlElement e) => e.localName == 'ol')) {
                walk(sub, level + 1);
              }
            }
          }

          for (final XmlElement ol in toc.childElements.where((XmlElement e) => e.localName == 'ol')) {
            walk(ol, 0);
          }
          if (out.isNotEmpty) return out;
        }
      }
    }
    final String? ncxId = _opf.descendantElements
        .where((XmlElement e) => e.localName == 'spine')
        .firstOrNull
        ?.getAttribute('toc');
    final XmlElement? ncxItem = ncxId == null
        ? _manifest.values
              .where((XmlElement e) => e.getAttribute('media-type') == 'application/x-dtbncx+xml')
              .firstOrNull
        : _manifest[ncxId];
    if (ncxItem == null) return const <_NavPoint>[];
    final String ncxPath = _resolve(_opfPath, ncxItem.getAttribute('href')!);
    final String? ncx = _text(_zip, ncxPath);
    if (ncx == null) return const <_NavPoint>[];
    final List<_NavPoint> out = <_NavPoint>[];
    void walk(XmlElement parent, int level) {
      for (final XmlElement point in parent.childElements.where((XmlElement e) => e.localName == 'navPoint')) {
        final String label =
            point.descendantElements.where((XmlElement e) => e.localName == 'text').firstOrNull?.innerText.trim() ?? '';
        final String? src = point.descendantElements
            .where((XmlElement e) => e.localName == 'content')
            .firstOrNull
            ?.getAttribute('src');
        if (src != null) out.add(_NavPoint(label, _resolve(ncxPath, src), _fragment(src), level));
        walk(point, level + 1);
      }
    }

    final XmlElement? map = XmlDocument.parse(ncx).descendantElements
        .where((XmlElement e) => e.localName == 'navMap')
        .firstOrNull;
    if (map != null) walk(map, 0);
    return out;
  }

  static String? _fragment(String href) => href.contains('#') ? href.substring(href.indexOf('#') + 1) : null;
}

class _NavPoint {
  const _NavPoint(this.title, this.path, this.fragment, this.level);

  final String title;
  final String path;
  final String? fragment;
  final int level;
}
