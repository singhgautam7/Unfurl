import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/formats/pdf/pdf_reflow.dart';
import 'package:unfurl/formats/reading_document.dart';

/// A 200 x 300 page; each character is 6 units wide and 8 tall.
PdfPageInput page(
  List<(String, double, double)> lines, {
  List<double> regions = const <double>[],
  List<PdfTable> tables = const <PdfTable>[],
}) {
  final StringBuffer text = StringBuffer();
  final List<double> rects = <double>[];
  for (final (String t, double x, double top) in lines) {
    for (int i = 0; i < t.length; i++) {
      text.write(t[i]);
      rects.addAll(<double>[x + i * 6, top, x + i * 6 + 5, top - 8]);
    }
    text.write('\n');
    rects.addAll(<double>[0, 0, 0, 0]);
  }
  return PdfPageInput(text: text.toString(), rects: rects, width: 200, height: 300, regions: regions, tables: tables);
}

void main() {
  test('a drawn picture is found, and its text leaves the flow for an image', () {
    final PdfPageInput p = page(<(String, double, double)>[
      ('Some body text above the chart.', 10, 290),
      ('Label', 60, 200),
      ('Body text below the chart.', 10, 100),
    ]);
    // Render 200 x 300 px (1 px per unit): a dark block from y 80 to 180.
    final Uint8List px = Uint8List(200 * 300 * 4)..fillRange(0, 200 * 300 * 4, 255);
    for (int y = 80; y < 180; y++) {
      for (int x = 40; x < 160; x++) {
        final int i = (y * 200 + x) * 4;
        px[i] = px[i + 1] = px[i + 2] = 30;
      }
    }
    final List<double> regions = PdfReflow.findRegions(p, px, 200, 300);
    expect(regions.length, 4, reason: 'one region');
    final String key = PdfReflow.regionKey(1, 0);
    final doc = PdfReflow.analyse(
      <PdfPageInput>[
        page(<(String, double, double)>[
          ('Some body text above the chart.', 10, 290),
          ('Label', 60, 200),
          ('Body text below the chart.', 10, 100),
        ], regions: regions),
      ],
      title: 't',
      images: <String, Uint8List>{key: Uint8List(1)},
    );
    final List<String> kinds = <String>[for (final b in doc.sections.expand((s) => s.blocks)) b.kind.name];
    expect(kinds, contains('image'));
    expect(doc.plainText, isNot(contains('Label')), reason: 'the label is inside the picture');
    expect(doc.plainText, contains('Body text below'));
  });

  test('text laid out in a grid becomes a table of text, not a picture', () {
    final List<(String, double, double)> lines = <(String, double, double)>[
      ('Intro paragraph line.', 10, 290),
      ('Name      Qty      Price', 10, 250),
      ('Apple     3        1.20', 10, 238),
      ('Pear      12       0.80', 10, 226),
    ];
    final PdfPageInput p = page(lines);
    final List<double> regions = PdfReflow.findRegions(p, null, 0, 0);
    expect(regions.length, 4);
    final PdfTable? t = PdfReflow.tableGrid(p, regions, null, 0, 0);
    expect(t, isNotNull);
    final ReadingDocument doc = PdfReflow.analyse(<PdfPageInput>[
      page(lines, tables: <PdfTable>[t!]),
    ], title: 't');
    final Block table = doc.sections.expand((Section s) => s.blocks).firstWhere((Block b) => b.kind == BlockKind.table);
    expect(table.rows, <List<String>>[
      <String>['Name', 'Qty', 'Price'],
      <String>['Apple', '3', '1.20'],
      <String>['Pear', '12', '0.80'],
    ]);
    expect(doc.plainText, contains('Intro paragraph'));
    // The cells keep a map back to the page, so marks and positions work.
    final (int pg, int at) = table.source!.locate(table.text.indexOf('Pear'));
    expect((pg, p.text.substring(at, at + 4)), (1, 'Pear'));
  });

  test('a table that runs onto the next page is one table, its repeated header dropped', () {
    PdfPageInput tablePage(List<(String, double, double)> lines) {
      final PdfPageInput p = page(lines);
      final PdfTable? t = PdfReflow.tableGrid(p, PdfReflow.findRegions(p, null, 0, 0), null, 0, 0);
      return page(lines, tables: <PdfTable>[t!]);
    }

    final ReadingDocument doc = PdfReflow.analyse(<PdfPageInput>[
      tablePage(<(String, double, double)>[
        ('Name      Qty      Price', 10, 250),
        ('Apple     3        1.20', 10, 238),
        ('Pear      12       0.80', 10, 226),
      ]),
      tablePage(<(String, double, double)>[
        ('Name      Qty      Price', 10, 250),
        ('Plum      7        0.40', 10, 238),
        ('Fig       2        2.10', 10, 226),
      ]),
    ], title: 't');
    final List<Block> tables = <Block>[
      for (final Block b in doc.sections.expand((Section s) => s.blocks))
        if (b.kind == BlockKind.table) b,
    ];
    expect(tables.length, 1);
    expect(tables.single.rows!.map((List<String> r) => r.first), <String>['Name', 'Apple', 'Pear', 'Plum', 'Fig']);
    final (int pg, int at) = tables.single.source!.locate(tables.single.text.indexOf('Plum'));
    expect(pg, 2, reason: 'rows from page 2 still map to page 2');
    expect(at, greaterThan(0));
  });

  test('symbol-font bullets become list items, wrapped lines stay with them', () {
    final doc = PdfReflow.analyse(<PdfPageInput>[
      page(<(String, double, double)>[
        ('A paragraph that opens the page and runs long.', 10, 290),
        ('\uF0B7 First item that wraps onto', 10, 270),
        ('a second line.', 22, 258),
        ('\uF0B7 Second item.', 10, 246),
      ]),
    ], title: 't');
    final List<String> items = <String>[
      for (final b in doc.sections.expand((s) => s.blocks))
        if (b.kind.name == 'listItem') b.text,
    ];
    expect(items, <String>['First item that wraps onto a second line.', 'Second item.']);
  });
}
