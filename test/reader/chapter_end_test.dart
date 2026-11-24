// Part L2: where a chapter ends in Reader mode. Chapters come from the table
// of contents (ReadingDocument.chapters), not from spine files; each starts
// on a new page, ends on a page that holds its last words, never on a blank
// page, and the footer's "End of chapter" is true on exactly that page.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/locator.dart';
import 'package:unfurl/features/reader/engine/layout.dart';
import 'package:unfurl/formats/reading_document.dart';
import 'package:unfurl/formats/text/text_formats.dart';

import 'harness.dart';

String _words(int n, String tag) => List<String>.generate(n, (int i) => '$tag$i').join(' ');

Block _h(String t, {int level = 1}) => Block(kind: BlockKind.heading, level: level, runs: <Inline>[Inline(t)]);
Block _p(String t) => Block(kind: BlockKind.paragraph, runs: <Inline>[Inline(t)]);

/// One spine file holding three chapters (TOC entries mid file), the shape
/// that made "end of chapter" land at the file's end.
ReadingDocument _oneFileThreeChapters() {
  final List<Block> blocks = <Block>[];
  final List<TocEntry> toc = <TocEntry>[];
  for (int c = 0; c < 3; c++) {
    toc.add(TocEntry(title: 'Chapter ${c + 1}', section: 0, block: blocks.length));
    blocks.add(_h('Chapter ${c + 1}'));
    for (int i = 0; i < 9; i++) {
      blocks.add(_p(_words(40, 'c${c}p$i.')));
    }
    blocks.add(_p(' ')); // trailing empty paragraph, as EPUB files often end
  }
  return ReadingDocument(
    title: 'b',
    sections: <Section>[Section(title: '', blocks: blocks)],
    toc: toc,
  );
}

/// One chapter spread over two spine files, then a second chapter.
ReadingDocument _chapterOverTwoFiles() => ReadingDocument(
  title: 'b',
  sections: <Section>[
    Section(title: '', blocks: <Block>[_h('One'), for (int i = 0; i < 5; i++) _p(_words(30, 'a$i.'))]),
    Section(title: '', blocks: <Block>[for (int i = 0; i < 5; i++) _p(_words(30, 'b$i.'))]),
    Section(title: '', blocks: <Block>[_h('Two'), for (int i = 0; i < 5; i++) _p(_words(30, 'c$i.'))]),
  ],
  toc: const <TocEntry>[
    TocEntry(title: 'One', section: 0),
    TocEntry(title: 'Two', section: 2),
  ],
);

Layout _layout(ReadingDocument doc, {double size = 18, Size page = const Size(360, 600)}) {
  final Layout l = Layout(
    doc: doc,
    style: styleOf(size: size),
    pageSize: page,
    images: ImageSizes.of(doc),
  );
  for (int s = 0; s < doc.sections.length; s++) {
    l.ensure(s);
  }
  return l;
}

int _g(ReadingDocument d, (int, int, int) at) => d.sections[at.$1].blocks[at.$2].start + at.$3;

/// Every chapter-end rule, checked on every page.
void _expectChapterEnds(ReadingDocument doc, Layout l) {
  final int pages = l.knownPages;
  final List<int> ends = <int>[];
  for (int p = 0; p < pages; p++) {
    final ReaderPage page = l.page(p)!;
    expect(page.fragments, isNotEmpty, reason: 'page $p is blank');
    expect(page.fragments.any((Fragment f) => f.block.text.trim().isNotEmpty), isTrue, reason: 'page $p is blank');
    final int first = _g(doc, page.first), last = _g(doc, page.last);
    if (doc.endsChapter(first, last)) ends.add(p);
    // A page never runs from one chapter into the next.
    expect(doc.chapterAt(last), doc.chapterAt(first), reason: 'page $p crosses a chapter');
  }
  // Exactly one "End of chapter" page per chapter, and it is that chapter's last page.
  expect(ends, hasLength(doc.chapters.length));
  for (int c = 0; c < doc.chapters.length; c++) {
    final int p = ends[c];
    expect(doc.chapterAt(_g(doc, l.page(p)!.first)), c);
    if (p + 1 < pages) expect(doc.chapterAt(_g(doc, l.page(p + 1)!.first)), c + 1);
    // The next chapter's first page opens with its heading block.
    if (c + 1 < doc.chapters.length) {
      final Fragment opening = l.page(p + 1)!.fragments.first;
      expect((opening.section, opening.blockIndex), (doc.chapters[c + 1].section, doc.chapters[c + 1].block));
    }
  }
  // A heading is never the last thing on a page when the text under it follows.
  for (int p = 0; p + 1 < pages; p++) {
    final Fragment tail = l.page(p)!.fragments.last;
    expect(tail.block.kind == BlockKind.heading, isFalse, reason: 'heading alone at the foot of page $p');
  }
}

void main() {
  test('chapters come from the TOC: one file with three chapters', () {
    final ReadingDocument doc = _oneFileThreeChapters();
    expect(doc.sections, hasLength(1));
    expect(doc.chapters.map((Chapter c) => c.title), <String>['Chapter 1', 'Chapter 2', 'Chapter 3']);
    final Layout l = _layout(doc);
    _expectChapterEnds(doc, l);
    l.dispose();
  });

  test('a chapter spread over two files ends where the next TOC entry starts', () {
    final ReadingDocument doc = _chapterOverTwoFiles();
    expect(doc.chapters, hasLength(2));
    expect(doc.chapterEnd(0), doc.sections[2].start);
    expect(doc.chapterAt(doc.sections[1].start), 0);
    final Layout l = _layout(doc);
    _expectChapterEnds(doc, l);
    l.dispose();
  });

  test('chapter ends hold after a font size change and a rotation', () {
    for (final ReadingDocument doc in <ReadingDocument>[_oneFileThreeChapters(), _chapterOverTwoFiles()]) {
      for (final (double size, Size page) in <(double, Size)>[
        (28, const Size(360, 600)),
        (36, const Size(360, 600)),
        (18, const Size(600, 340)),
        (28, const Size(600, 340)),
      ]) {
        final Layout l = _layout(doc, size: size, page: page);
        _expectChapterEnds(doc, l);
        l.dispose();
      }
    }
  });

  test('Markdown: heading chapters, the title is not a chapter of its own', () {
    final String md = <String>[
      '# Guide',
      for (int c = 1; c <= 4; c++) ...<String>['## Part $c', for (int i = 0; i < 6; i++) _words(35, 'm$c.$i.'), ''],
    ].join('\n\n');
    final ReadingDocument doc = TextFormats.markdown(Uint8List.fromList(utf8.encode(md)), 'guide.md');
    expect(doc.chapters.map((Chapter c) => c.title).toList(), <String>['Part 1', 'Part 2', 'Part 3', 'Part 4']);
    for (final double size in <double>[18, 30]) {
      final Layout l = _layout(doc, size: size);
      _expectChapterEnds(doc, l);
      l.dispose();
    }
  });

  test('plain text with no headings is one chapter that ends on its last page only', () {
    final String txt = List<String>.generate(40, (int i) => _words(40, 't$i.')).join('\n\n');
    final ReadingDocument doc = TextFormats.plain(Uint8List.fromList(utf8.encode(txt)), 'notes.txt');
    expect(doc.chapters, hasLength(1));
    final Layout l = _layout(doc);
    _expectChapterEnds(doc, l);
    l.dispose();
  });

  test('sections without a TOC (reflowed PDF, DOCX headings) are the chapters', () {
    final ReadingDocument doc = ReadingDocument(
      title: 'b',
      toc: const <TocEntry>[],
      sections: <Section>[
        for (int s = 0; s < 3; s++)
          Section(title: 'S$s', blocks: <Block>[_h('S$s'), for (int i = 0; i < 6; i++) _p(_words(40, 's$s.$i.'))]),
      ],
    );
    expect(doc.chapters, hasLength(3));
    final Layout l = _layout(doc);
    _expectChapterEnds(doc, l);
    l.dispose();
  });

  test('a short all-bold label line keeps with the text under it (no near-blank last page)', () {
    // A resume-like document: bold section labels, the last section short.
    final List<Block> blocks = <Block>[
      for (int s = 0; s < 6; s++) ...<Block>[
        Block(kind: BlockKind.paragraph, runs: <Inline>[Inline('SECTION $s', bold: true)]),
        for (int i = 0; i < 3; i++) _p(_words(18 + s * 3 + i, 'r$s.$i.')),
        // A role line: starts bold, then plain, then the list it introduces.
        Block(
          kind: BlockKind.paragraph,
          runs: <Inline>[Inline('Role $s', bold: true), const Inline(' | Company, 2020 to 2022')],
        ),
        for (int i = 0; i < 2; i++)
          Block(kind: BlockKind.listItem, level: 1, runs: <Inline>[Inline(_words(20 + i, 'l$s.$i.'))]),
      ],
    ];
    final ReadingDocument doc = ReadingDocument(
      title: 'r',
      sections: <Section>[Section(title: '', blocks: blocks)],
    );
    for (final double size in <double>[16, 18, 20, 22, 24, 28, 32]) {
      final Layout l = _layout(doc, size: size);
      for (int p = 0; p + 1 < l.knownPages; p++) {
        final Block tail = l.page(p)!.fragments.last.block;
        expect(tail.runs.first.bold, isFalse, reason: 'label alone at the foot of page $p, size $size');
      }
      l.dispose();
    }
  });

  test('words to the chapter end match a full count; a trailing image is content', () {
    for (final ReadingDocument doc in <ReadingDocument>[_oneFileThreeChapters(), _chapterOverTwoFiles()]) {
      for (int g = 0; g < doc.length; g += 37) {
        final int end = doc.chapterEnd(doc.chapterAt(g));
        expect(doc.wordsToChapterEnd(g), doc.wordsBetween(g, end), reason: 'at $g');
      }
    }
    final ReadingDocument withImage = ReadingDocument(
      title: 'i',
      sections: <Section>[
        Section(
          title: '',
          blocks: <Block>[
            _p('Last words.'),
            Block(kind: BlockKind.image, image: 'x'),
          ],
        ),
      ],
    );
    final Block words = withImage.sections[0].blocks[0];
    expect(withImage.endsChapter(0, words.start + words.text.length), isFalse);
    expect(ReadingDocument(title: 'e', sections: const <Section>[]).chapters, hasLength(1));
  });

  test('positions and highlights saved before the fix resolve to the same place', () {
    // Locators store a text quote and section/block/offset; chapters change
    // only pagination, never the document model they resolve against.
    final ReadingDocument doc = _oneFileThreeChapters();
    for (final (int, int, int) at in <(int, int, int)>[(0, 0, 0), (0, 5, 12), (0, 13, 40), (0, 25, 3)]) {
      final String saved = Locator.inDocument(doc, at.$1, at.$2, at.$3, length: 12).toJson();
      expect(Locator.fromJson(saved).resolveIn(_oneFileThreeChapters()), at);
      final Layout l = _layout(doc);
      final ReaderPage page = l.page(l.pageOf(at.$1, at.$2, at.$3))!;
      expect(page.contains(at.$1, at.$2, at.$3), isTrue);
      l.dispose();
    }
  });
}
