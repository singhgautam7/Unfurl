import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/features/reader/engine/layout.dart';
import 'package:unfurl/features/reader/engine/reader_view.dart';

import 'harness.dart';

void main() {
  testWidgets('a hidden Reader mode parks its layout and the next one takes it', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.reset);
    final ReaderController c = ReaderController(paragraphs());
    final ReaderLayoutCache cache = ReaderLayoutCache();
    addTearDown(cache.dispose);

    await tester.pumpWidget(readerView(c, cache: cache));
    await tester.pumpAndSettle();
    for (int i = 0; i < 3; i++) {
      c.turn(1);
      await tester.pumpAndSettle();
    }
    final (int, int, int) place = c.position;
    expect(cache.parked, isNull, reason: 'in use, not parked');

    await tester.pumpWidget(const SizedBox());
    final Layout? parked = cache.parked;
    expect(parked, isNotNull);

    await tester.pumpWidget(readerView(c, cache: cache));
    expect(cache.parked, isNull, reason: 'handed over to the new view');
    expect(c.layoutComplete, isTrue, reason: 'a complete layout is complete at once');
    await tester.pumpAndSettle();
    expect(c.position, place, reason: 'same page');

    await tester.pumpWidget(const SizedBox());
    expect(identical(cache.parked, parked), isTrue, reason: 'the same layout, not a new one');
  });

  testWidgets('a different style or size does not take the parked layout', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.reset);
    final ReaderController c = ReaderController(paragraphs());
    final ReaderLayoutCache cache = ReaderLayoutCache();
    addTearDown(cache.dispose);

    await tester.pumpWidget(readerView(c, cache: cache));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    final Layout parked = cache.parked!;
    expect(
      cache.take(doc: c.doc, style: styleOf(size: 22), pageSize: parked.pageSize, columns: 1),
      isNull,
      reason: 'another style',
    );
    expect(cache.parked, isNull, reason: 'and the old one is gone');

    cache.park(
      Layout(doc: c.doc, style: styleOf(), pageSize: const Size(100, 200), images: ImageSizes.of(c.doc)),
      columns: 1,
    );
    expect(
      cache.take(doc: c.doc, style: styleOf(), pageSize: const Size(101, 200), columns: 1),
      isNull,
      reason: 'size',
    );
    final Layout again = Layout(
      doc: c.doc,
      style: styleOf(),
      pageSize: const Size(100, 200),
      images: ImageSizes.of(c.doc),
    );
    cache.park(again, columns: 2);
    expect(
      cache.take(doc: c.doc, style: styleOf(), pageSize: const Size(100, 200), columns: 1),
      isNull,
      reason: 'columns',
    );
    cache.park(
      Layout(doc: c.doc, style: styleOf(), pageSize: const Size(100, 200), images: ImageSizes.of(c.doc)),
      columns: 1,
    );
    expect(
      cache.take(doc: paragraphs(1), style: styleOf(), pageSize: const Size(100, 200), columns: 1),
      isNull,
      reason: 'doc',
    );
  });

  testWidgets('a view of another style starts a new layout and parks that one', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.reset);
    final ReaderController c = ReaderController(paragraphs());
    final ReaderLayoutCache cache = ReaderLayoutCache();
    addTearDown(cache.dispose);

    await tester.pumpWidget(readerView(c, cache: cache));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    final Layout first = cache.parked!;

    await tester.pumpWidget(readerView(c, cache: cache, style: styleOf(size: 22)));
    await tester.pumpAndSettle();
    expect(cache.parked, isNull);
    await tester.pumpWidget(const SizedBox());
    expect(cache.parked, isNotNull);
    expect(identical(cache.parked, first), isFalse);
  });
}
