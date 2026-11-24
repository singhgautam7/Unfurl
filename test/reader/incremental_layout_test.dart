import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unfurl/features/reader/engine/layout.dart';
import 'package:unfurl/features/reader/engine/reader_view.dart';
import 'package:unfurl/features/reader/reading_prefs.dart';
import 'package:unfurl/features/settings/settings_controller.dart';
import 'package:unfurl/formats/reading_document.dart';

import 'harness.dart';

List<((int, int, int), (int, int, int))> bounds(Layout l) => <((int, int, int), (int, int, int))>[
  for (final List<ReaderPage>? pages in l.sections)
    for (final ReaderPage p in pages ?? const <ReaderPage>[]) (p.first, p.last),
];

/// A prefs store that records which keys were written.
class _Prefs implements SharedPreferences {
  final Map<String, Object> values = <String, Object>{};
  final List<String> writes = <String>[];

  @override
  Future<bool> setString(String key, String value) async {
    writes.add(key);
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    writes.add(key);
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    writes.add(key);
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  String? getString(String key) => values[key] as String?;

  @override
  double? getDouble(String key) => values[key] as double?;

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The rest of the book fills in between frames.
Future<void> filled(WidgetTester tester, ReaderController c) async {
  for (int i = 0; i < 2000 && !c.layoutComplete; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
  expect(c.layoutComplete, isTrue);
}

void main() {
  const Size screen = Size(400, 860);
  void window(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = screen;
    addTearDown(tester.view.reset);
  }

  test('layout in slices has the page boundaries of one synchronous layout', () {
    final ReadingDocument doc = paragraphs(1500);
    Layout make() => Layout(doc: doc, style: styleOf(), pageSize: const Size(340, 700), images: ImageSizes.of(doc));
    final Layout whole = make()..ensure(0);
    final Layout sliced = make();
    addTearDown(whole.dispose);
    addTearDown(sliced.dispose);
    // A tiny budget: many slices, each stopping at a block.
    int slices = 0;
    while (sliced.step(0, const Duration(microseconds: 200))) {
      slices++;
    }
    expect(slices, greaterThan(5), reason: 'it took several slices, not one pass');
    expect(sliced.complete, isTrue);
    expect(bounds(sliced), bounds(whole));
    // Reaching a far place first (lays out up to it, not past it) changes nothing.
    final Layout toward = make();
    addTearDown(toward.dispose);
    expect(toward.pageOf(0, 900, 0), greaterThan(10));
    expect(toward.blocksLaid, lessThan(1500));
    expect(toward.covers(0, 900, 0), isTrue);
    toward.ensure(0);
    expect(bounds(toward), bounds(whole));
  });

  testWidgets(
    'a big single section: the first frame lays out the page, not the section; settled, it matches a full layout',
    (WidgetTester tester) async {
      window(tester);
      final ReadingDocument doc = paragraphs(4000);
      final ReaderController c = ReaderController(doc);
      final ReaderLayoutCache cache = ReaderLayoutCache();
      addTearDown(cache.dispose);

      await tester.pumpWidget(readerView(c, cache: cache));
      await tester.pumpWidget(const SizedBox());
      final Layout partial = cache.parked!;
      expect(partial.complete, isFalse);
      expect(partial.blocksLaid, lessThan(4000 ~/ 4), reason: 'no full synchronous layout');
      expect(partial.sections[0], isNotEmpty);

      await tester.pumpWidget(readerView(c, cache: cache));
      await filled(tester, c);
      expect(c.layoutComplete, isTrue);
      await tester.pumpWidget(const SizedBox());
      final Layout done = cache.parked!;
      final Layout full = Layout(doc: doc, style: styleOf(), pageSize: done.pageSize, images: ImageSizes.of(doc))
        ..ensure(0);
      addTearDown(full.dispose);
      expect(done.complete, isTrue);
      expect(bounds(done), bounds(full));
    },
  );

  testWidgets('a font step keeps the passage on screen', (WidgetTester tester) async {
    window(tester);
    final ReaderController c = ReaderController(paragraphs(600), start: (0, 300, 40));
    await tester.pumpWidget(readerView(c));
    await tester.pumpAndSettle();
    final int at = c.doc.sections[0].blocks[300].start + 40;
    bool shown() => c.globalIndex <= at && lastIndexOf(c) >= at;
    expect(shown(), isTrue, reason: 'opens at the saved place');
    for (final double size in <double>[22, 26, 14]) {
      await tester.pumpWidget(readerView(c, style: styleOf(size: size)));
      await tester.pumpAndSettle();
      expect(shown(), isTrue, reason: 'size $size');
      await filled(tester, c);
      expect(shown(), isTrue, reason: 'size $size, the whole book laid out');
    }
  });

  testWidgets('a page turn rebuilds the footer, not the parent', (WidgetTester tester) async {
    window(tester);
    final ReaderController c = ReaderController(paragraphs());
    int parent = 0, footer = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            parent++;
            return ReaderView(
              controller: c,
              style: styleOf(),
              layoutMode: ReaderLayout.paged,
              pageTurn: PageTurn.none,
              onCentreTap: () {},
              onLink: (_) {},
              onMarkTap: (_, _) {},
              onSelection: (_) {},
              onFontStep: (_) {},
              footer: ((int, int, int) a, (int, int, int) b) {
                footer++;
                return ('${a.$2}', '${b.$2}');
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final int before = footer;
    expect(parent, 1);
    c.turn(1);
    await tester.pumpAndSettle();
    expect(footer, greaterThan(before), reason: 'the footer follows the page');
    expect(parent, 1, reason: 'nothing above the reader rebuilt');
  });

  testWidgets('prefs write only what changed, once, after a pause, and flush on dispose', (WidgetTester tester) async {
    final _Prefs prefs = _Prefs();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[prefsProvider.overrideWithValue(prefs)],
    );
    final ReadingPrefsController ctl = container.read(readingPrefsProvider.notifier);
    expect(prefs.writes, isEmpty, reason: 'reading writes nothing');

    // A slider drag: state is live at once, the disk waits.
    for (int i = 1; i <= 10; i++) {
      ctl.update((ReadingPrefs p) => p.copyWith(brightness: i / 10));
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(container.read(readingPrefsProvider).brightness, 1.0);
    expect(prefs.writes, isEmpty, reason: 'debounced while it moves');
    await tester.pump(const Duration(seconds: 1));
    expect(prefs.writes, <String>['reading.brightness'], reason: 'one write, one key');

    ctl.update((ReadingPrefs p) => p.copyWith(size: 22, justify: false));
    prefs.writes.clear();
    container.dispose();
    await tester.pump();
    expect(prefs.writes.toSet(), <String>{'reading.size', 'reading.justify'}, reason: 'flushed on dispose');
    expect(prefs.writes.length, 2);
  });
  testWidgets('however little is laid out, a turn has a page to turn to', (WidgetTester tester) async {
    window(tester);
    final ReaderController c = ReaderController(paragraphs(2000));
    await tester.pumpWidget(readerView(c));
    await tester.pumpAndSettle();
    expect(c.layoutComplete, isFalse);
    int last = c.globalIndex;
    for (int i = 0; i < 30; i++) {
      c.turn(1);
      // No time passes between the turns but the turn's own.
      await tester.pumpAndSettle();
      expect(c.globalIndex, greaterThan(last), reason: 'turn $i');
      last = c.globalIndex;
    }
    await tester.pumpWidget(const SizedBox());
  });

  test('one paragraph as long as a book paginates without laying the rest of it out for every page', () {
    final String text = List<String>.generate(30000, (int i) => 'word${i % 97}').join(' ');
    ReadingDocument one() => ReadingDocument(
      title: 'One',
      sections: <Section>[
        Section(
          title: 'One',
          blocks: <Block>[
            Block(kind: BlockKind.paragraph, runs: <Inline>[Inline(text)]),
          ],
        ),
      ],
    );
    final ReadingDocument doc = one();
    final Layout l = Layout(doc: doc, style: styleOf(), pageSize: const Size(340, 700), images: ImageSizes.of(doc));
    addTearDown(l.dispose);
    final Stopwatch w = Stopwatch()..start();
    l.ensure(0);
    // ignore: avoid_print
    print('30,000 words in one paragraph: ${l.knownPages} pages in ${w.elapsedMilliseconds} ms');
    expect(l.knownPages, greaterThan(50));
    // Nothing is lost or doubled, and every page but the last is full.
    int at = 0;
    for (final ReaderPage p in l.sections[0]!) {
      expect(p.first.$3, inInclusiveRange(at, at + 1));
      at = p.last.$3;
      if (p != l.sections[0]!.last) expect(p.fragments.last.rect.bottom, greaterThan(600));
    }
    expect(at, text.length);
  });

  test('a page shown again has the text it was laid out with; what is far away is let go', () {
    final ReadingDocument doc = paragraphs(1500);
    final Layout l = Layout(doc: doc, style: styleOf(), pageSize: const Size(340, 700), images: ImageSizes.of(doc))
      ..ensure(0);
    addTearDown(l.dispose);
    final List<List<Rect>> first = <List<Rect>>[
      for (final Fragment f in l.sections[0]!.first.fragments) f.boxes(f.start, f.end),
    ];
    for (final ReaderPage p in l.sections[0]!) {
      for (final Fragment f in p.fragments) {
        expect(f.painter, isNotNull);
        expect(f.rect.height, f.painter!.height);
      }
    }
    expect(<List<Rect>>[for (final Fragment f in l.sections[0]!.first.fragments) f.boxes(f.start, f.end)], first);
  });
}

int lastIndexOf(ReaderController c) =>
    c.doc.sections[c.lastVisible.$1].blocks[c.lastVisible.$2].start + c.lastVisible.$3;
