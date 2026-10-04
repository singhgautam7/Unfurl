import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../charsets.dart';
import '../epub/epub.dart' show BookMeta;
import '../format_problem.dart';
import '../html_blocks.dart';
import '../reading_document.dart';

/// FictionBook 2 (`.fb2`) and zipped FictionBook (`.fbz`, `.fb2.zip`): one
/// XML file with the text in `<body>` sections and images as base64
/// `<binary>` elements. Read through [HtmlBlocks] with FB2's tags mapped to
/// their HTML equivalents. Pure Dart, run in an isolate.
class Fb2 {
  Fb2._(this._doc);

  factory Fb2.open(Uint8List bytes) {
    Uint8List xml = bytes;
    if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      final Archive zip = ZipDecoder().decodeBytes(bytes);
      final ArchiveFile? f = zip.files
          .where((ArchiveFile f) => f.isFile && f.name.toLowerCase().endsWith('.fb2'))
          .firstOrNull;
      if (f == null) throw const FormatProblem(ProblemKind.damaged, 'No .fb2 inside the archive');
      xml = f.content;
    }
    final String text = Charsets.decode(xml, Charsets.declared(xml));
    try {
      return Fb2._(XmlDocument.parse(text, entityMapping: const XmlDefaultEntityMapping.html5()));
    } on XmlException {
      return Fb2._(HtmlBlocks.parse(text));
    }
  }

  final XmlDocument _doc;

  static const Map<String, String> _aliases = <String, String>{
    'title': 'h2',
    'subtitle': 'h3',
    'emphasis': 'em',
    'strikethrough': 'span',
    'epigraph': 'blockquote',
    'cite': 'blockquote',
    'poem': 'blockquote',
    'stanza': 'div',
    'v': 'p',
    'text-author': 'p',
    'empty-line': 'br',
    'annotation': 'div',
    'date': 'p',
  };

  Iterable<XmlElement> _all(String local, [XmlNode? under]) =>
      (under ?? _doc).descendantElements.where((XmlElement e) => e.localName == local);

  XmlElement? get _titleInfo => _all('title-info').firstOrNull;

  String? get _title {
    final String? t = _titleInfo == null ? null : _all('book-title', _titleInfo).firstOrNull?.innerText.trim();
    return t == null || t.isEmpty ? null : t;
  }

  String? get _author {
    final XmlElement? info = _titleInfo;
    if (info == null) return null;
    final List<String> names = <String>[
      for (final XmlElement a in _all('author', info))
        <String>[
          for (final String part in <String>['first-name', 'middle-name', 'last-name'])
            ?_all(part, a).firstOrNull?.innerText.trim(),
        ].where((String s) => s.isNotEmpty).join(' ').ifEmpty(_all('nickname', a).firstOrNull?.innerText.trim() ?? ''),
    ].where((String s) => s.isNotEmpty).toList();
    return names.isEmpty ? null : names.join(', ');
  }

  late final Map<String, XmlElement> _binaries = <String, XmlElement>{
    for (final XmlElement b in _all('binary'))
      if (b.getAttribute('id') case final String id) id: b,
  };

  Uint8List? _binary(String href) {
    final XmlElement? b = _binaries[href.startsWith('#') ? href.substring(1) : href];
    if (b == null) return null;
    try {
      return base64.decode(b.innerText.replaceAll(RegExp(r'\s+'), ''));
    } on FormatException {
      return null;
    }
  }

  /// A title's lines are `<p>`s; as a heading they are one line of text.
  static XmlElement _flatTitles(XmlElement e) {
    for (final XmlElement t
        in e.descendantElements.where((XmlElement x) => x.localName == 'title' || x.localName == 'subtitle').toList()) {
      final String text = t.childElements.isEmpty
          ? t.innerText
          : t.childElements.map((XmlElement p) => p.innerText.trim()).where((String s) => s.isNotEmpty).join(' ');
      t.children
        ..clear()
        ..add(XmlText(text));
    }
    return e;
  }

  BookMeta meta() {
    final XmlElement? cover = _titleInfo == null ? null : _all('coverpage', _titleInfo).firstOrNull;
    final XmlElement? image = cover == null ? null : _all('image', cover).firstOrNull;
    final String? href = image == null ? null : HtmlBlocks.attr(image, 'href');
    return BookMeta(title: _title, author: _author, cover: href == null ? null : _binary(href));
  }

  ReadingDocument document() {
    final Map<String, Uint8List> resources = <String, Uint8List>{};
    final List<Section> sections = <Section>[];
    final Map<String, (int, int)> anchors = <String, (int, int)>{};

    List<Block> convert(XmlElement e) =>
        HtmlBlocks(
          aliases: _aliases,
          resolveImage: (String src) {
            final String key = src.startsWith('#') ? src.substring(1) : src;
            if (resources.containsKey(key)) return key;
            final Uint8List? b = _binary(key);
            if (b == null) return null;
            resources[key] = b;
            return key;
          },
          resolveLink: (String href) => href.startsWith('#') ? href.substring(1) : href,
        ).convert(
          XmlDocument(<XmlNode>[
            XmlElement(const XmlName.qualified('body'), const <XmlAttribute>[], <XmlNode>[_flatTitles(e.copy())]),
          ]),
        );

    void add(List<Block> blocks, {String? title, String? id}) {
      if (blocks.isEmpty) return;
      if (id != null) anchors[id] = (sections.length, 0);
      for (int b = 0; b < blocks.length; b++) {
        if (blocks[b].anchor != null) anchors[blocks[b].anchor!] = (sections.length, b);
      }
      sections.add(
        Section(
          title:
              title ??
              blocks.where((Block b) => b.kind == BlockKind.heading).map((Block b) => b.text).firstOrNull ??
              '',
          blocks: blocks,
        ),
      );
    }

    final List<XmlElement> bodies = _all('body').toList();
    for (final XmlElement body in bodies) {
      final bool notes = body.getAttribute('name') != null;
      if (notes) {
        add(convert(body), title: _all('title', body).firstOrNull?.innerText.trim() ?? 'Notes');
        continue;
      }
      // What comes before the first section (the book's title page, an
      // epigraph) is a section of its own; then one per top-level section.
      final XmlElement lead = XmlElement(const XmlName.qualified('div'));
      for (final XmlElement child in body.childElements) {
        if (child.localName == 'section') {
          add(convert(lead));
          lead.children.clear();
          add(convert(child), id: child.getAttribute('id'));
        } else {
          lead.children.add(child.copy());
        }
      }
      add(convert(lead));
    }
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
      title: _title ?? '',
      author: _author,
      sections: sections,
      resources: resources,
      anchors: anchors,
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
