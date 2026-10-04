import 'package:xml/xml.dart';

/// Real-world HTML (old MOBI markup, saved web pages) into an [XmlDocument]
/// that [HtmlBlocks] can walk: unquoted attributes, unclosed `<p>` and `<li>`,
/// void tags without a slash and stray end tags are all accepted. Not a full
/// HTML5 parser; just enough tree repair for reading.
abstract final class TagSoup {
  static final RegExp _token = RegExp(
    r'<!--[\s\S]*?(?:-->|$)|<!\[CDATA\[([\s\S]*?)\]\]>|<[!?][^>]*>|<(/?)([a-zA-Z][\w:.-]*)((?:\s+[^\s=>/]+(?:\s*=\s*(?:"[^"]*"|'
    "'[^']*'"
    r'|[^\s>]+))?)*)\s*(/?)>',
  );
  static final RegExp _attr = RegExp(r'''([^\s=>/]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?''');
  static const XmlEntityMapping _entities = XmlDefaultEntityMapping.html5();

  static const Set<String> _void = <String>{
    'br',
    'hr',
    'img',
    'input',
    'meta',
    'link',
    'area',
    'base',
    'col',
    'embed',
    'param',
    'source',
    'track',
    'wbr',
  };

  /// Opening one of these closes an open element of the same group first.
  static const Map<String, Set<String>> _autoClose = <String, Set<String>>{
    'p': <String>{'p'},
    'li': <String>{'li'},
    'dt': <String>{'dt', 'dd'},
    'dd': <String>{'dt', 'dd'},
    'tr': <String>{'tr', 'td', 'th'},
    'td': <String>{'td', 'th'},
    'th': <String>{'td', 'th'},
    'option': <String>{'option'},
  };

  /// Block starts that end an open paragraph.
  static const Set<String> _closesP = <String>{
    'div',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'ul',
    'ol',
    'table',
    'blockquote',
    'pre',
    'hr',
    'section',
    'p',
  };

  static XmlDocument parse(String html) {
    final XmlElement root = XmlElement(const XmlName.qualified('root'));
    final List<XmlElement> stack = <XmlElement>[root];
    int at = 0;
    void text(String s) {
      if (s.isNotEmpty) stack.last.children.add(XmlText(_entities.decode(s)));
    }

    late final String lower = html.toLowerCase();
    while (true) {
      final RegExpMatch? m = _token.allMatches(html, at).firstOrNull;
      if (m == null) break;
      text(html.substring(at, m.start));
      at = m.end;
      if (m.group(1) != null) {
        stack.last.children.add(XmlText(m.group(1)!));
        continue;
      }
      final String? name = m.group(3)?.toLowerCase();
      if (name == null) continue; // A comment, doctype or processing instruction.
      if (m.group(2) == '/') {
        final int open = stack.lastIndexWhere((XmlElement e) => e.name.qualified == name);
        if (open > 0) stack.removeRange(open, stack.length);
        continue;
      }
      if (_closesP.contains(name)) _closeOpen(stack, const <String>{'p'});
      final Set<String>? group = _autoClose[name];
      if (group != null) _closeOpen(stack, group);
      final XmlElement e = XmlElement(XmlName.qualified(name), _attributes(m.group(4) ?? ''));
      stack.last.children.add(e);
      if (name == 'script' || name == 'style') {
        // Raw text up to the end tag; dropped later, but never parsed.
        final int end = lower.indexOf('</$name', at);
        at = end < 0 ? html.length : end;
        continue;
      }
      if (m.group(5) != '/' && !_void.contains(name)) stack.add(e);
    }
    text(html.substring(at));
    return XmlDocument(<XmlNode>[root]);
  }

  /// Closes the innermost open element in [names], unless a list or table
  /// boundary sits between it and the top.
  static void _closeOpen(List<XmlElement> stack, Set<String> names) {
    for (int i = stack.length - 1; i > 0; i--) {
      final String n = stack[i].name.qualified;
      if (names.contains(n)) {
        stack.removeRange(i, stack.length);
        return;
      }
      if (n == 'ul' || n == 'ol' || n == 'table' || n == 'blockquote' || n == 'div' || n == 'body') return;
    }
  }

  static List<XmlAttribute> _attributes(String raw) {
    final Map<String, XmlAttribute> out = <String, XmlAttribute>{};
    for (final RegExpMatch a in _attr.allMatches(raw)) {
      final String name = a.group(1)!.toLowerCase();
      if (out.containsKey(name) || name.startsWith('xmlns')) continue;
      final String value = a.group(2) ?? a.group(3) ?? a.group(4) ?? '';
      try {
        out[name] = XmlAttribute(XmlName.qualified(name), _entities.decode(value));
      } on Object {
        // A name XML refuses ("2col", "@click"): not needed for reading.
      }
    }
    return out.values.toList();
  }
}
