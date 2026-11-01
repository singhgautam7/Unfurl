import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/formats/reading_document.dart';
import 'package:unfurl/formats/reading_document_codec.dart';

ReadingDocument _full() {
  final List<Block> blocks = <Block>[
    for (final BlockKind k in BlockKind.values)
      if (k != BlockKind.table) Block(kind: k, runs: <Inline>[Inline('Kind ${k.name} café \u{1F600}')], level: k.index),
    Block(
      kind: BlockKind.table,
      rows: <List<String>>[
        <String>['a', 'b'],
        <String>['c', ''],
      ],
    ),
    Block(
      kind: BlockKind.paragraph,
      runs: const <Inline>[
        Inline('plain '),
        Inline('bold', bold: true),
        Inline('italic', italic: true),
        Inline('mono', mono: true),
        Inline('small', small: true),
        Inline('link', href: 'chapter1.xhtml#n3'),
        Inline('all', bold: true, italic: true, mono: true, small: true, href: 'x'),
      ],
      anchor: 'frag',
      source: const SourceRef(page: 3, start: 10, end: 99),
    ),
    Block(kind: BlockKind.heading, runs: const <Inline>[Inline('H')], level: 2, anchor: 'h'),
    Block(kind: BlockKind.listItem, runs: const <Inline>[Inline('zero')], ordinal: 0, checked: true),
    Block(kind: BlockKind.listItem, runs: const <Inline>[Inline('big')], ordinal: 123456789012, checked: false),
    Block(kind: BlockKind.listItem, runs: const <Inline>[Inline('neg')], ordinal: -5),
    Block(kind: BlockKind.image, image: 'img/1.png'),
    Block(
      kind: BlockKind.paragraph,
      runs: const <Inline>[Inline('abcdefgh')],
      source: const SourceRef(
        page: 400,
        start: 1,
        end: 2,
        charMap: <int>[
          400 * (1 << 20) + 9000,
          400 * (1 << 20) + 9001,
          -1,
          -1,
          401 * (1 << 20) + 5,
          3,
          400 * (1 << 20) + 9000,
          -1,
        ],
      ),
    ),
    Block(
      kind: BlockKind.paragraph,
      runs: const <Inline>[Inline('x')],
      source: const SourceRef(page: 1, charMap: <int>[]),
    ),
  ];
  return ReadingDocument(
    title: 'Título',
    author: 'An Author',
    sections: <Section>[
      Section(title: '', blocks: blocks.sublist(0, 3)),
      Section(title: 'Two', blocks: blocks.sublist(3)),
      Section(title: 'Empty', blocks: <Block>[]),
    ],
    toc: const <TocEntry>[
      TocEntry(title: 'Two', section: 1, block: 4, level: 2),
      TocEntry(title: 'Back', section: 0, block: 1, level: -1),
    ],
    resources: <String, Uint8List>{
      'img/1.png': Uint8List.fromList(<int>[0, 255, 0, 1, 254, 255, 0]),
      'empty': Uint8List(0),
    },
    simplified: true,
    scanned: true,
    unitLabel: 'Page',
    anchors: const <String, (int, int)>{'a#1': (1, 2), 'b': (0, 0), 'neg': (-1, 70000)},
    mono: true,
  );
}

void _expectSame(ReadingDocument a, ReadingDocument b) {
  expect(b.title, a.title);
  expect(b.author, a.author);
  expect(b.plainText, a.plainText);
  expect(b.length, a.length);
  expect(b.simplified, a.simplified);
  expect(b.scanned, a.scanned);
  expect(b.mono, a.mono);
  expect(b.unitLabel, a.unitLabel);
  expect(b.sections.length, a.sections.length);
  for (int s = 0; s < a.sections.length; s++) {
    final Section sa = a.sections[s], sb = b.sections[s];
    expect(sb.title, sa.title);
    expect(sb.start, sa.start);
    expect(sb.blocks.length, sa.blocks.length);
    for (int i = 0; i < sa.blocks.length; i++) {
      final Block x = sa.blocks[i], y = sb.blocks[i];
      final String at = 'section $s block $i';
      expect(y.kind, x.kind, reason: at);
      expect(y.text, x.text, reason: at);
      expect(y.start, x.start, reason: at);
      expect(y.level, x.level, reason: at);
      expect(y.ordinal, x.ordinal, reason: at);
      expect(y.checked, x.checked, reason: at);
      expect(y.image, x.image, reason: at);
      expect(y.rows, x.rows, reason: at);
      expect(y.anchor, x.anchor, reason: at);
      expect(y.runs.length, x.runs.length, reason: at);
      for (int r = 0; r < x.runs.length; r++) {
        expect(y.runs[r].text, x.runs[r].text);
        expect(y.runs[r].bold, x.runs[r].bold);
        expect(y.runs[r].italic, x.runs[r].italic);
        expect(y.runs[r].mono, x.runs[r].mono);
        expect(y.runs[r].small, x.runs[r].small);
        expect(y.runs[r].href, x.runs[r].href);
      }
      expect(y.source == null, x.source == null, reason: at);
      if (x.source != null) {
        expect(y.source!.page, x.source!.page, reason: at);
        expect(y.source!.start, x.source!.start, reason: at);
        expect(y.source!.end, x.source!.end, reason: at);
        expect(y.source!.charMap, x.source!.charMap, reason: at);
      }
    }
  }
  expect(b.toc.length, a.toc.length);
  for (int i = 0; i < a.toc.length; i++) {
    expect(b.toc[i].title, a.toc[i].title);
    expect(b.toc[i].section, a.toc[i].section);
    expect(b.toc[i].block, a.toc[i].block);
    expect(b.toc[i].level, a.toc[i].level);
  }
  expect(b.anchors, a.anchors);
  expect(b.resources.keys.toList(), a.resources.keys.toList());
  a.resources.forEach((String k, Uint8List v) => expect(b.resources[k], v));
}

void main() {
  group('ReadingDocumentCodec', () {
    test('round trips a document that uses every field', () {
      final ReadingDocument doc = _full();
      final ReadingDocument? back = ReadingDocumentCodec.decode(ReadingDocumentCodec.encode(doc));
      expect(back, isNotNull);
      _expectSame(doc, back!);
    });

    test('round trips a null author, no sections and an empty toc', () {
      final ReadingDocument doc = ReadingDocument(title: '', sections: const <Section>[], toc: const <TocEntry>[]);
      final ReadingDocument? back = ReadingDocumentCodec.decode(ReadingDocumentCodec.encode(doc));
      expect(back, isNotNull);
      expect(back!.author, isNull);
      expect(back.sections, isEmpty);
      expect(back.toc, isEmpty);
      expect(back.unitLabel, 'Chapter');
    });

    test('an empty toc stays empty even when sections have titles', () {
      final ReadingDocument doc = ReadingDocument(
        title: 't',
        sections: <Section>[Section(title: 'Named', blocks: <Block>[])],
        toc: const <TocEntry>[],
      );
      expect(ReadingDocumentCodec.decode(ReadingDocumentCodec.encode(doc))!.toc, isEmpty);
    });

    test('rejects bad input without throwing', () {
      final Uint8List good = ReadingDocumentCodec.encode(_full());
      expect(ReadingDocumentCodec.decode(Uint8List(0)), isNull);

      final Uint8List magic = Uint8List.fromList(good)..[0] = 0x58;
      expect(ReadingDocumentCodec.decode(magic), isNull);

      final Uint8List other = Uint8List.fromList(good)..[4] = ReadingDocumentCodec.version + 1;
      expect(ReadingDocumentCodec.decode(other), isNull);

      for (int cut = 0; cut < good.length; cut += 7) {
        expect(ReadingDocumentCodec.decode(Uint8List.sublistView(good, 0, cut)), isNull, reason: 'cut at $cut');
      }
      expect(ReadingDocumentCodec.decode(Uint8List.sublistView(good, 0, good.length - 1)), isNull);

      final Uint8List extra = Uint8List(good.length + 1)..setRange(0, good.length, good);
      expect(ReadingDocumentCodec.decode(extra), isNull);
    });

    test('rejects an out-of-range block kind', () {
      // Header: 4 magic, version, title 'a' (2), author absent (1), flags (1),
      // unit label 'Chapter' (8), one section (1), its title 's' (2), one block (1).
      final ReadingDocument doc = ReadingDocument(
        title: 'a',
        sections: <Section>[
          Section(
            title: 's',
            blocks: <Block>[Block(kind: BlockKind.rule)],
          ),
        ],
        toc: const <TocEntry>[],
      );
      final Uint8List bytes = ReadingDocumentCodec.encode(doc);
      const int kindAt = 4 + 1 + 2 + 1 + 1 + 8 + 1 + 2 + 1;
      expect(bytes[kindAt], BlockKind.rule.index);
      final Uint8List bad = Uint8List.fromList(bytes)..[kindAt] = BlockKind.values.length;
      expect(ReadingDocumentCodec.decode(bad), isNull);
    });

    test('performance: ~1M characters, 5,000 blocks, charMaps, 50 resources of 100 KB', () {
      final Random rnd = Random(7);
      const int blockCount = 5000;
      const int charsPerBlock = 200;
      final List<Section> sections = <Section>[];
      for (int s = 0; s < 50; s++) {
        final List<Block> blocks = <Block>[];
        for (int i = 0; i < blockCount ~/ 50; i++) {
          final int n = s * 100 + i;
          final String text = String.fromCharCodes(List<int>.generate(charsPerBlock, (int c) => 97 + (c * 7 + n) % 26));
          blocks.add(
            Block(
              kind: BlockKind.paragraph,
              runs: <Inline>[
                Inline(text.substring(0, 100)),
                Inline(text.substring(100), bold: n.isEven),
              ],
              source: SourceRef(
                page: n + 1,
                charMap: <int>[
                  for (int c = 0; c < charsPerBlock; c++) c % 37 == 0 ? -1 : (n + 1) * SourceRef.kPage + c + 3,
                ],
              ),
            ),
          );
        }
        sections.add(Section(title: 'S$s', blocks: blocks));
      }
      final Map<String, Uint8List> resources = <String, Uint8List>{
        for (int i = 0; i < 50; i++)
          'r$i': Uint8List.fromList(List<int>.generate(100 * 1024, (int _) => rnd.nextInt(256))),
      };
      final ReadingDocument doc = ReadingDocument(title: 'Big', sections: sections, resources: resources);
      expect(doc.length, greaterThan(1000000));

      final Stopwatch encodeWatch = Stopwatch()..start();
      final Uint8List bytes = ReadingDocumentCodec.encode(doc);
      encodeWatch.stop();
      final Stopwatch decodeWatch = Stopwatch()..start();
      final ReadingDocument? back = ReadingDocumentCodec.decode(bytes);
      decodeWatch.stop();
      // ignore: avoid_print
      print(
        'codec perf: encode ${encodeWatch.elapsedMilliseconds} ms, decode ${decodeWatch.elapsedMilliseconds} ms, '
        '${bytes.length} bytes (${doc.length} chars, $blockCount blocks)',
      );
      expect(back, isNotNull);
      expect(back!.length, doc.length);
      expect(back.sections[7].blocks[3].source!.charMap, doc.sections[7].blocks[3].source!.charMap);
      expect(encodeWatch.elapsedMilliseconds, lessThan(3000));
      expect(decodeWatch.elapsedMilliseconds, lessThan(3000));
    });
  });
}
