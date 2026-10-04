import 'package:xml/xml.dart';

import 'reading_document.dart';
import 'tag_soup.dart';

/// Turns (X)HTML into reader blocks: headings, paragraphs, quotes, list
/// items, code, images, tables and rules, with bold, italic, mono, links and
/// small text inline. Publisher CSS is dropped on purpose: the reader's own
/// typography and theme always win.
class HtmlBlocks {
  HtmlBlocks({required this.resolveImage, this.resolveLink, this.aliases = const <String, String>{}});

  /// Maps an `src` to a resource key, or null to drop the image.
  final String? Function(String src) resolveImage;

  /// Maps an internal `href` to a key in [ReadingDocument.anchors].
  final String Function(String href)? resolveLink;

  /// Other vocabularies read as HTML: FB2's `emphasis` as `em`, `title` as
  /// `h2` and so on.
  final Map<String, String> aliases;

  final List<Block> _blocks = <Block>[];
  List<Inline> _runs = <Inline>[];
  String? _pendingAnchor;

  static XmlDocument parse(String html) {
    try {
      return XmlDocument.parse(html, entityMapping: const XmlDefaultEntityMapping.html5());
    } on XmlException {
      // Markdown output, sloppy XHTML, old MOBI markup: repair the tree.
      return TagSoup.parse(html);
    }
  }

  /// An attribute by local name, whatever its prefix (`l:href`, `xlink:href`).
  static String? attr(XmlElement e, String local) =>
      e.attributes.where((XmlAttribute a) => a.name.local == local).firstOrNull?.value;

  List<Block> convert(XmlNode root) {
    final XmlElement? body = root.descendants
        .whereType<XmlElement>()
        .where((XmlElement e) => e.localName == 'body')
        .firstOrNull;
    _walk(body ?? root, const _Marks(), quote: false, depth: 0);
    _flush(BlockKind.paragraph);
    return _blocks;
  }

  static const Set<String> _blockTags = <String>{
    'p',
    'div',
    'section',
    'article',
    'body',
    'main',
    'header',
    'footer',
    'aside',
    'nav',
    'figure',
    'figcaption',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'blockquote',
    'ul',
    'ol',
    'li',
    'pre',
    'table',
    'hr',
    'dl',
    'dt',
    'dd',
    'center',
  };

  void _walk(XmlNode node, _Marks marks, {required bool quote, required int depth}) {
    for (final XmlNode child in node.children) {
      if (child is XmlText || child is XmlCDATA) {
        _addText(child.value ?? '', marks);
        continue;
      }
      if (child is! XmlElement) continue;
      final String tag = aliases[child.localName] ?? child.localName.toLowerCase();
      final String? id = child.getAttribute('id');
      if (id != null) _pendingAnchor ??= id;
      switch (tag) {
        case 'script' || 'style' || 'head' || 'title':
          continue;
        case 'br':
          _runs.add(Inline('\n', bold: marks.bold, italic: marks.italic));
        case 'img' || 'image':
          _flush(quote ? BlockKind.quote : BlockKind.paragraph);
          final String? src = attr(child, 'src') ?? attr(child, 'href') ?? attr(child, 'recindex');
          final String? key = src == null ? null : resolveImage(src);
          if (key != null) {
            _blocks.add(
              Block(kind: BlockKind.image, image: key, runs: <Inline>[Inline(child.getAttribute('alt') ?? '')]),
            );
          }
        case 'svg':
          _walk(child, marks, quote: quote, depth: depth);
        case 'hr':
          _flush(BlockKind.paragraph);
          _blocks.add(Block(kind: BlockKind.rule));
        case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
          _flush(quote ? BlockKind.quote : BlockKind.paragraph);
          _walk(child, marks, quote: quote, depth: depth);
          _flush(BlockKind.heading, level: int.parse(tag.substring(1)));
        case 'blockquote':
          _flush(BlockKind.paragraph);
          _walk(child, marks, quote: true, depth: depth);
          _flush(BlockKind.quote);
        case 'pre':
          _flush(quote ? BlockKind.quote : BlockKind.paragraph);
          _runs.add(Inline(child.innerText.replaceAll(RegExp(r'\n$'), ''), mono: true));
          _flush(BlockKind.code);
        case 'ul' || 'ol':
          _flush(quote ? BlockKind.quote : BlockKind.paragraph);
          int n = int.tryParse(child.getAttribute('start') ?? '') ?? 1;
          for (final XmlElement li in child.childElements.where((XmlElement e) => e.localName == 'li')) {
            final bool? checked = _checkbox(li);
            _walk(li, marks, quote: quote, depth: depth + 1);
            _flushList(depth, tag == 'ol' ? n++ : null, checked);
          }
        case 'table':
          _flush(quote ? BlockKind.quote : BlockKind.paragraph);
          final List<List<String>> rows = <List<String>>[
            for (final XmlElement tr in child.descendantElements.where((XmlElement e) => e.localName == 'tr'))
              <String>[
                for (final XmlElement cell in tr.childElements.where(
                  (XmlElement e) => e.localName == 'td' || e.localName == 'th',
                ))
                  cell.innerText.replaceAll(RegExp(r'\s+'), ' ').trim(),
              ],
          ];
          if (rows.isNotEmpty) _blocks.add(Block(kind: BlockKind.table, rows: rows));
        case 'figcaption':
          _flush(BlockKind.paragraph);
          _walk(child, marks.copyWith(italic: true), quote: quote, depth: depth);
          _flush(BlockKind.caption);
        case 'input':
          continue; // A task list's box; read by `_checkbox`.
        default:
          if (_blockTags.contains(tag)) {
            _flush(quote ? BlockKind.quote : BlockKind.paragraph);
            _walk(child, marks, quote: quote, depth: depth);
            _flush(quote ? BlockKind.quote : BlockKind.paragraph);
          } else {
            _walk(child, _inlineMarks(tag, child, marks), quote: quote, depth: depth);
          }
      }
    }
  }

  _Marks _inlineMarks(String tag, XmlElement e, _Marks m) => switch (tag) {
    'b' || 'strong' => m.copyWith(bold: true),
    'i' || 'em' || 'cite' || 'dfn' || 'var' => m.copyWith(italic: true),
    'code' || 'kbd' || 'samp' || 'tt' => m.copyWith(mono: true),
    'sup' || 'sub' || 'small' => m.copyWith(small: true),
    'a' => m.copyWith(href: _link(attr(e, 'href'))),
    _ => m,
  };

  String? _link(String? href) {
    if (href == null || href.isEmpty) return null;
    if (RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(href)) return href;
    return resolveLink?.call(href) ?? href;
  }

  bool? _checkbox(XmlElement li) {
    final XmlElement? box = li.descendantElements.where((XmlElement e) => e.localName == 'input').firstOrNull;
    if (box != null && box.getAttribute('type') == 'checkbox') return box.getAttribute('checked') != null;
    return null;
  }

  void _addText(String raw, _Marks m) {
    final String text = raw.replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return;
    if (text == ' ' && (_runs.isEmpty || _runs.last.text.endsWith(' ') || _runs.last.text.endsWith('\n'))) return;
    _runs.add(Inline(text, bold: m.bold, italic: m.italic, mono: m.mono, href: m.href, small: m.small));
  }

  List<Inline>? _take() {
    final List<Inline> runs = _merge(_runs);
    _runs = <Inline>[];
    if (runs.isEmpty) return null;
    // Trim the paragraph's outer whitespace.
    runs[0] = runs[0].copyWith(text: runs[0].text.trimLeft());
    final int last = runs.length - 1;
    runs[last] = runs[last].copyWith(text: runs[last].text.trimRight());
    runs.removeWhere((Inline r) => r.text.isEmpty);
    return runs.isEmpty ? null : runs;
  }

  void _flush(BlockKind kind, {int level = 0}) {
    final List<Inline>? runs = _take();
    if (runs == null) return;
    _blocks.add(Block(kind: kind, runs: runs, level: level, anchor: _pendingAnchor));
    _pendingAnchor = null;
  }

  void _flushList(int depth, int? ordinal, bool? checked) {
    final List<Inline>? runs = _take();
    if (runs == null) return;
    _blocks.add(
      Block(
        kind: BlockKind.listItem,
        runs: runs,
        level: depth,
        ordinal: ordinal,
        checked: checked,
        anchor: _pendingAnchor,
      ),
    );
    _pendingAnchor = null;
  }

  /// Joins neighbouring runs with the same marks.
  static List<Inline> _merge(List<Inline> runs) {
    final List<Inline> out = <Inline>[];
    for (final Inline r in runs) {
      if (out.isNotEmpty) {
        final Inline p = out.last;
        if (p.bold == r.bold && p.italic == r.italic && p.mono == r.mono && p.href == r.href && p.small == r.small) {
          out[out.length - 1] = p.copyWith(text: p.text + r.text);
          continue;
        }
      }
      out.add(r);
    }
    return out;
  }
}

class _Marks {
  const _Marks({this.bold = false, this.italic = false, this.mono = false, this.small = false, this.href});

  final bool bold;
  final bool italic;
  final bool mono;
  final bool small;
  final String? href;

  _Marks copyWith({bool? bold, bool? italic, bool? mono, bool? small, String? href}) => _Marks(
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    mono: mono ?? this.mono,
    small: small ?? this.small,
    href: href ?? this.href,
  );
}
