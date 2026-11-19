import 'dart:math' as math;

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

  /// The reader's chapters: from the table of contents when there is one
  /// (an EPUB spine file can hold several chapters, and a chapter can span
  /// several files; Markdown, HTML and plain text are one section with
  /// heading entries), else one per section. Entries at the shallowest TOC
  /// level that has two or more; text before the first is chapter 0.
  late final List<Chapter> chapters = _chapters();

  List<Chapter> _chapters() {
    int startOf(TocEntry e) {
      final List<Block> blocks = sections[e.section].blocks;
      return blocks.isEmpty ? sections[e.section].start : blocks[e.block.clamp(0, blocks.length - 1)].start;
    }

    final List<TocEntry> valid = <TocEntry>[
      for (final TocEntry e in toc)
        if (e.section >= 0 && e.section < sections.length) e,
    ];
    if (sections.isEmpty) return const <Chapter>[Chapter(title: '', section: 0, start: 0)];
    if (valid.isEmpty) {
      return <Chapter>[
        for (int s = 0; s < sections.length; s++)
          Chapter(title: sections[s].title, section: s, start: sections[s].start),
      ];
    }
    final int deepest = valid.map((TocEntry e) => e.level).reduce(math.max);
    int level = valid.map((TocEntry e) => e.level).reduce(math.min);
    while (level < deepest && valid.where((TocEntry e) => e.level <= level).length < 2) {
      level++;
    }
    final List<TocEntry> picked = valid.where((TocEntry e) => e.level <= level).toList();
    // A lone shallower entry first (a Markdown `# Title` above `##` chapters)
    // is the book's title, not a chapter of its own.
    final List<TocEntry> shallower = picked.where((TocEntry e) => e.level < level).toList();
    if (shallower.length == 1 && identical(shallower.single, picked.first)) picked.removeAt(0);
    final List<Chapter> out = <Chapter>[];
    for (final TocEntry e in picked) {
      final int start = startOf(e);
      if (out.any((Chapter c) => c.start == start)) continue;
      final int block = sections[e.section].blocks.isEmpty
          ? 0
          : e.block.clamp(0, sections[e.section].blocks.length - 1);
      out.add(Chapter(title: e.title, section: e.section, block: block, start: start));
    }
    out.sort((Chapter a, Chapter b) => a.start.compareTo(b.start));
    if (out.first.start > 0) {
      // Text before the first chapter is chapter 0, unless it is only
      // headings (a title): those belong to the first chapter.
      final bool titleOnly = <Block>[
        for (final Section s in sections)
          for (final Block b in s.blocks)
            if (b.start < out.first.start) b,
      ].every((Block b) => b.kind == BlockKind.heading || b.text.trim().isEmpty);
      final Chapter c = out.first;
      out[0] = titleOnly ? Chapter(title: c.title, section: 0, start: 0) : c;
      if (!titleOnly) out.insert(0, const Chapter(title: '', section: 0, start: 0));
    }
    return out;
  }

  /// The chapter holding global index [global].
  int chapterAt(int global) {
    int lo = 0, hi = chapters.length - 1;
    while (lo < hi) {
      final int mid = (lo + hi + 1) >> 1;
      if (chapters[mid].start <= global) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Global index just past chapter [i]'s text (the next chapter's start).
  int chapterEnd(int i) => i + 1 < chapters.length ? chapters[i + 1].start : length;

  /// Whether a page from global [first] to [last] holds the end of its
  /// chapter: nothing but whitespace is left between [last] and the next
  /// chapter (or the end of the book).
  bool endsChapter(int first, int last) {
    final int end = chapterEnd(chapterAt(first));
    if (last >= end - 1) return true;
    // Walk forward from [last]: usually the first block decides.
    for (int i = _blockAt(last); i < _flat.length && _flat[i].start < end; i++) {
      final Block b = _flat[i];
      if (b.kind == BlockKind.image || b.kind == BlockKind.rule || b.kind == BlockKind.table) {
        if (b.start >= last) return false;
        continue;
      }
      final int from = (last - b.start).clamp(0, b.text.length);
      if (b.text.substring(from).trim().isNotEmpty) return false;
    }
    return true;
  }

  /// Words from global [from] to the end of its chapter, from per-block
  /// counts made once (the footer asks on every page).
  int wordsToChapterEnd(int from) {
    final int end = chapterEnd(chapterAt(from));
    final int i = _blockAt(from);
    if (i >= _flat.length) return 0;
    final Block b = _flat[i];
    final int partial = _countWords(b.text.substring((from - b.start).clamp(0, b.text.length)));
    final int j = _blockAt(end); // the next chapter's first block, or the end
    return partial + (j > i + 1 ? _wordsBefore[j] - _wordsBefore[i + 1] : 0);
  }

  late final List<Block> _flat = <Block>[for (final Section s in sections) ...s.blocks];

  /// Words in the flat blocks before index i (length + 1 entries).
  // ponytail: counted once on the UI isolate (tens of ms for a very large
  // TXT); move to an isolate if the first footer ever janks.
  late final List<int> _wordsBefore = () {
    final List<int> out = <int>[0];
    for (final Block b in _flat) {
      out.add(out.last + _countWords(b.text));
    }
    return out;
  }();

  /// Index of the flat block holding global [index] (or the count, past the end).
  int _blockAt(int index) {
    int lo = 0, hi = _flat.length;
    while (lo < hi) {
      final int mid = (lo + hi) >> 1;
      if (_flat[mid].start + _flat[mid].text.length < index) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  static final RegExp _word = RegExp(r'\S+');
  static int _countWords(String s) => _word.allMatches(s).length;

  /// Blocks that open a chapter inside a section: pagination starts a page there.
  late final Set<(int, int)> chapterBlocks = <(int, int)>{
    for (final Chapter c in chapters)
      if (c.block > 0) (c.section, c.block),
  };

  /// Words, for the time-left estimate.
  int wordsBetween(int fromGlobal, int toGlobal) {
    final String slice = plainText.substring(
      fromGlobal.clamp(0, plainText.length),
      toGlobal.clamp(0, plainText.length),
    );
    return slice.split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).length;
  }
}

/// Where a chapter starts: its (section, block) and global index.
@immutable
class Chapter {
  const Chapter({required this.title, required this.section, required this.start, this.block = 0});

  final String title;
  final int section;
  final int block;
  final int start;
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
