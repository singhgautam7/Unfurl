import 'dart:convert';
import 'dart:typed_data';

import 'package:markdown/markdown.dart' as md;

import '../html_blocks.dart';
import '../reading_document.dart';

/// Markdown and plain text into the reader (Reader mode is their only view).
abstract final class TextFormats {
  static String decode(Uint8List bytes) {
    final Uint8List b = bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF
        ? bytes.sublist(3)
        : bytes;
    try {
      return utf8.decode(b);
    } on FormatException {
      return latin1.decode(b);
    }
  }

  static ReadingDocument markdown(Uint8List bytes, String name) {
    final String html = md.markdownToHtml(decode(bytes), extensionSet: md.ExtensionSet.gitHubWeb);
    final List<Block> blocks = HtmlBlocks(resolveImage: (_) => null).convert(HtmlBlocks.parse('<body>$html</body>'));
    final String title =
        blocks.where((Block b) => b.kind == BlockKind.heading && b.level == 1).map((Block b) => b.text).firstOrNull ??
        _stem(name);
    return ReadingDocument(
      title: title,
      unitLabel: 'Section',
      sections: <Section>[
        Section(title: _stem(name), blocks: blocks.isEmpty ? <Block>[_empty()] : blocks),
      ],
      toc: <TocEntry>[
        for (int i = 0; i < blocks.length; i++)
          if (blocks[i].kind == BlockKind.heading && blocks[i].level <= 3)
            TocEntry(title: blocks[i].text, section: 0, block: i, level: blocks[i].level - 1),
      ],
    );
  }

  static ReadingDocument plain(Uint8List bytes, String name) {
    final String text = decode(bytes).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final List<String> lines = text.split('\n');
    final List<String> nonEmpty = lines.where((String l) => l.trim().isNotEmpty).toList();
    // Code or a table: symbols, pipes, indentation. Lists: short lines.
    final int codeLike = nonEmpty.where((String l) => RegExp(r'[{};=|<>]|^\s{2,}|^[-+]{3,}').hasMatch(l)).length;
    final bool mono = nonEmpty.isNotEmpty && codeLike / nonEmpty.length > 0.3;
    final bool lineByLine =
        mono || (nonEmpty.isNotEmpty && nonEmpty.where((String l) => l.length < 60).length / nonEmpty.length > 0.7);
    final List<Block> blocks = <Block>[];
    if (mono) {
      // Code or a table: only the font changes (board 4, V4). Each run of
      // lines is one paragraph with its line breaks and indents kept, so it
      // reads as one piece, not a box per line.
      for (final String run in text.split(RegExp(r'\n[ \t]*\n'))) {
        final String kept = run.replaceAll(RegExp(r'^\n+|\s+$'), '');
        if (kept.trim().isNotEmpty) {
          blocks.add(Block(kind: BlockKind.paragraph, runs: <Inline>[Inline(kept, mono: true)]));
        }
      }
    } else if (lineByLine) {
      for (final String l in lines) {
        blocks.add(Block(kind: BlockKind.paragraph, runs: <Inline>[Inline(l.trim())]));
      }
      while (blocks.isNotEmpty && blocks.last.text.isEmpty) {
        blocks.removeLast();
      }
    } else {
      for (final String para in text.split(RegExp(r'\n\s*\n'))) {
        final String joined = para.split('\n').map((String l) => l.trim()).join(' ').trim();
        if (joined.isNotEmpty) blocks.add(Block(kind: BlockKind.paragraph, runs: <Inline>[Inline(joined)]));
      }
    }
    return ReadingDocument(
      title: _stem(name),
      unitLabel: 'Section',
      mono: mono,
      sections: <Section>[
        Section(title: _stem(name), blocks: blocks.isEmpty ? <Block>[_empty()] : blocks),
      ],
      toc: const <TocEntry>[],
    );
  }

  static Block _empty() => Block(kind: BlockKind.paragraph, runs: const <Inline>[Inline('')]);

  static String _stem(String name) {
    final int dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }
}
