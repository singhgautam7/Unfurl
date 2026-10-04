import 'package:flutter/foundation.dart';

/// The one model every Reader-mode format becomes (EPUB, Markdown, TXT,
/// DOCX, a PPTX outline, a reflowed PDF). One reader renders it, so
/// typography, themes, highlights and read aloud are implemented once.
///
/// Positions inside it are (section, block, character offset into
/// [Block.text]); a [SourceRef] on a block says where that text came from in
/// the original, which is what lets Page and Reader mode share a place.
@immutable
class ReadingDocument {
  ReadingDocument({
    required this.title,
    required this.sections,
    this.author,
    List<TocEntry>? toc,
    this.resources = const <String, Uint8List>{},
    this.simplified = false,
    this.scanned = false,
    this.unitLabel = 'Chapter',
    this.anchors = const <String, (int, int)>{},
    this.mono = false,
  }) : toc = toc ?? _defaultToc(sections) {
    int total = 0;
    for (final Section s in sections) {
      s.start = total;
      for (final Block b in s.blocks) {
        b.start = total;
        total += b.text.length + 1;
      }
    }
    length = total;
  }

  /// A view onto some of another document's sections that leaves their
  /// global offsets alone (scroll layout lays blocks out one at a time).
  ReadingDocument.view(ReadingDocument of, this.sections)
    : title = of.title,
      author = of.author,
      toc = const <TocEntry>[],
      resources = of.resources,
      simplified = of.simplified,
      scanned = of.scanned,
      unitLabel = of.unitLabel,
      anchors = const <String, (int, int)>{},
      mono = of.mono {
    length = of.length;
  }

  final String title;
  final String? author;
  final List<Section> sections;
  final List<TocEntry> toc;

  /// Images by the key a [Block.image] names.
  final Map<String, Uint8List> resources;

  /// The PDF analyser linearised tables, columns or floats.
  final bool simplified;

  /// A PDF whose pages are images with no text: nothing to reflow.
  final bool scanned;

  /// "Chapter", "Section", "Slide", "Page": how the running head and the
  /// scrubber name a section.
  final String unitLabel;

  /// Plain text that looks like code or a table: set in mono.
  final bool mono;

  /// Internal link targets ("chapter1.xhtml#note3") to (section, block).
  final Map<String, (int, int)> anchors;

  /// Characters in the whole document (each block plus one break).
  late final int length;

  static List<TocEntry> _defaultToc(List<Section> sections) => <TocEntry>[
    for (int i = 0; i < sections.length; i++)
      if (sections[i].title.isNotEmpty) TocEntry(title: sections[i].title, section: i),
  ];

  /// 0..1 for a position.
  double progressAt(int section, int block, int offset) {
    if (length == 0 || sections.isEmpty) return 0;
    final Block b = sections[section].blocks[block];
    return ((b.start + offset) / length).clamp(0, 1);
  }

  /// The position at a 0..1 fraction of the document.
  (int, int, int) positionAt(double fraction) {
    final int target = (fraction.clamp(0, 1) * length).round();
    for (int s = 0; s < sections.length; s++) {
      final List<Block> blocks = sections[s].blocks;
      for (int b = 0; b < blocks.length; b++) {
        final Block block = blocks[b];
        if (target <= block.start + block.text.length) {
          return (s, b, (target - block.start).clamp(0, block.text.length));
        }
      }
    }
    return (sections.length - 1, sections.last.blocks.length - 1, 0);
  }

  /// All text, blocks separated by newlines; the space quote anchors search.
  late final String plainText = <String>[
    for (final Section s in sections)
      for (final Block b in s.blocks) b.text,
  ].join('\n');

  /// The block and offset holding global character index [index] of
  /// [plainText].
  (int, int, int) positionOfIndex(int index) {
    for (int s = 0; s < sections.length; s++) {
      for (int b = 0; b < sections[s].blocks.length; b++) {
        final Block block = sections[s].blocks[b];
        if (index <= block.start + block.text.length) return (s, b, (index - block.start).clamp(0, block.text.length));
      }
    }
    return (0, 0, 0);
  }

  /// Words, for the time-left estimate.
  int wordsBetween(int fromGlobal, int toGlobal) {
    final String slice = plainText.substring(
      fromGlobal.clamp(0, plainText.length),
      toGlobal.clamp(0, plainText.length),
    );
    return slice.split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).length;
  }
}

class Section {
  Section({required this.title, required this.blocks});

  final String title;
  final List<Block> blocks;

  /// Global character index of the first block; set by [ReadingDocument].
  int start = 0;
}

@immutable
class TocEntry {
  const TocEntry({required this.title, required this.section, this.block = 0, this.level = 0});

  final String title;
  final int section;
  final int block;
  final int level;
}

enum BlockKind { heading, paragraph, quote, listItem, code, image, table, rule, caption }

/// One run of inline text with its marks.
@immutable
class Inline {
  const Inline(this.text, {this.bold = false, this.italic = false, this.mono = false, this.href, this.small = false});

  final String text;
  final bool bold;
  final bool italic;
  final bool mono;
  final String? href;

  /// Superscript, footnote markers, captions inside a paragraph.
  final bool small;

  Inline copyWith({String? text}) =>
      Inline(text ?? this.text, bold: bold, italic: italic, mono: mono, href: href, small: small);
}

/// Where a block's text came from in the original file.
@immutable
class SourceRef {
  const SourceRef({required this.page, this.start = 0, this.end = 0, this.charMap});

  /// 1-based unit: the PDF page, DOCX paragraph or PPTX slide it starts on.
  final int page;

  /// Character range in that unit's own text (linear sources).
  final int start;
  final int end;

  /// A reflowed PDF: block offset i came from `page * kPage + index` of the
  /// page text, or -1 for a character the analyser inserted. A paragraph
  /// rejoined across a page break carries both pages.
  final List<int>? charMap;

  static const int kPage = 1 << 20;

  /// The (page, page character) behind block offset [offset].
  (int, int) locate(int offset) {
    final List<int>? map = charMap;
    if (map == null || map.isEmpty) return (page, (start + offset).clamp(start, end));
    for (int i = offset.clamp(0, map.length - 1); i >= 0; i--) {
      if (map[i] >= 0) return (map[i] ~/ kPage, map[i] % kPage);
    }
    for (final int v in map) {
      if (v >= 0) return (v ~/ kPage, v % kPage);
    }
    return (page, start);
  }

  int get lastPage {
    final List<int>? map = charMap;
    if (map == null) return page;
    for (int i = map.length - 1; i >= 0; i--) {
      if (map[i] >= 0) return map[i] ~/ kPage;
    }
    return page;
  }

  /// The block offset of page character [index] on [onPage], or null if this
  /// block does not hold it.
  /// This block's first character on page [onPage], in that page's text.
  int? firstOn(int onPage) {
    final List<int>? map = charMap;
    if (map == null) return onPage == page ? start : null;
    for (final int v in map) {
      if (v >= 0 && v ~/ kPage == onPage) return v % kPage;
    }
    return null;
  }

  int? offsetOf(int onPage, int index) {
    if (onPage < page || onPage > lastPage) return null;
    final List<int>? map = charMap;
    if (map == null) return index < start || index > end ? null : index - start;
    final int key = onPage * kPage + index;
    int? best;
    for (int i = 0; i < map.length; i++) {
      final int v = map[i];
      if (v < 0) continue;
      if (v <= key && v ~/ kPage == onPage) best = i;
    }
    if (best == null) {
      // Before this block's first character on that page.
      final int first = map.indexWhere((int v) => v >= 0 && v ~/ kPage == onPage);
      return first >= 0 && map[first] > key && onPage == page ? null : (first < 0 ? null : first);
    }
    return best;
  }
}

class Block {
  Block({
    required this.kind,
    this.runs = const <Inline>[],
    this.level = 0,
    this.ordinal,
    this.checked,
    this.image,
    this.rows,
    this.source,
    this.anchor,
  }) : text = kind == BlockKind.table
           ? rows!.map((List<String> r) => r.join('\t')).join('\n')
           : runs.map((Inline r) => r.text).join();

  final BlockKind kind;
  final List<Inline> runs;

  /// Heading level (1 largest) or list depth.
  final int level;

  /// A numbered list item's number; null for bullets.
  final int? ordinal;

  /// A task list item.
  final bool? checked;

  /// Resource key of an image block.
  final String? image;

  /// A table's cells.
  final List<List<String>>? rows;
  final SourceRef? source;

  /// An id links can target (an EPUB fragment).
  final String? anchor;

  /// The block's plain text; offsets in a [Locator] count into this.
  final String text;

  /// Global character index; set by [ReadingDocument].
  int start = 0;
}
