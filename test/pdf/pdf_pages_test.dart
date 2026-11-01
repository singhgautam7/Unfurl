import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/features/pdf/pdf_pages.dart';
import 'package:unfurl/features/pdf/pdf_render.dart';

/// These open real PDFs, so they need a host PDFium: set PDFIUM_PATH to a
/// libpdfium.so (pdfium-binaries' linux-x64 build of the release pdfium_dart
/// pins). Without it they are skipped; the on-device tests cover the rest.
final String? _pdfium = Platform.environment['PDFIUM_PATH'];

void main() {
  late PdfDocument pdf;
  late PageRenderer renderer;

  setUpAll(() async {
    if (_pdfium == null) return;
    Pdfrx.pdfiumModulePath = _pdfium;
    await pdfrxInitialize();
    pdf = await PdfDocument.openFile('test/fixtures/origin-of-species.pdf');
  });

  tearDownAll(() async {
    if (_pdfium != null) await pdf.dispose();
  });

  setUp(() {
    if (_pdfium != null) renderer = PageRenderer(pdf);
  });

  tearDown(() {
    if (_pdfium != null) renderer.dispose();
  });

  final GlobalKey<PdfPagesState> key = GlobalKey<PdfPagesState>();
  late List<(int, double)> pages;
  late List<(int, Offset)> taps, presses, moves;
  late int builds;

  Widget view({bool paged = false}) {
    pages = <(int, double)>[];
    taps = <(int, Offset)>[];
    presses = <(int, Offset)>[];
    moves = <(int, Offset)>[];
    builds = 0;
    return MaterialApp(
      theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
      home: PdfPages(
        key: key,
        pdf: pdf,
        renderer: renderer,
        initialPage: 1,
        paged: paged,
        topInset: 0,
        lookFor: (int p) => const PageLook(),
        paintFor: (int p) {
          builds++;
          return const <(Rect, Color)>[];
        },
        pageAspect: (int p) => pdf.pages[p - 1].width / pdf.pages[p - 1].height,
        cropFor: (int p) => null,
        needText: (int p) {},
        onPage: (int p, double o) => pages.add((p, o)),
        onTap: (int p, Offset f, double x) => taps.add((p, f)),
        onLongPressStart: (int p, Offset f) => presses.add((p, f)),
        onLongPressMove: (int p, Offset f) => moves.add((p, f)),
        onLongPressEnd: () {},
      ),
    );
  }

  double scrolled() => -key.currentState!.pageRect(1)!.top;

  testWidgets('a fling keeps going after the finger lifts, decelerates, and stops', (WidgetTester tester) async {
    await tester.pumpWidget(view());
    await tester.pump();
    await tester.fling(find.byType(PdfPages), const Offset(0, -300), 3000);
    await tester.pump(); // the fling's first frame
    final double atRelease = scrolled();
    await tester.pump(const Duration(milliseconds: 100));
    final double later = scrolled();
    expect(later, greaterThan(atRelease));
    await tester.pump(const Duration(milliseconds: 100));
    final double step2 = scrolled() - later;
    expect(step2, lessThan(later - atRelease)); // slowing down
    await tester.pumpAndSettle();
    final double rest = scrolled();
    await tester.pump(const Duration(milliseconds: 500));
    expect(scrolled(), rest);
    expect(pages.last.$1, greaterThan(1));
  }, skip: _pdfium == null);

  testWidgets('a touch stops a fling and is not a tap', (WidgetTester tester) async {
    await tester.pumpWidget(view());
    await tester.pump();
    await tester.fling(find.byType(PdfPages), const Offset(0, -300), 4000);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(200, 300));
    final double stopped = scrolled();
    await tester.pump(const Duration(milliseconds: 400));
    expect(scrolled(), stopped);
    await tester.pump(kDoubleTapTimeout);
    expect(taps, isEmpty);
  }, skip: _pdfium == null);

  testWidgets('scrolling within a page rebuilds no page', (WidgetTester tester) async {
    await tester.pumpWidget(view());
    await tester.pump();
    final TestGesture g = await tester.startGesture(const Offset(200, 400));
    await g.moveBy(const Offset(0, -40)); // past the slop
    await tester.pump();
    final int before = builds;
    for (int i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, -4));
      await tester.pump();
    }
    expect(builds, before);
    expect(scrolled(), greaterThan(30));
    await g.up();
    await tester.pumpAndSettle();
  }, skip: _pdfium == null);

  testWidgets('a drag starts at the touch slop and then tracks the finger', (WidgetTester tester) async {
    await tester.pumpWidget(view());
    await tester.pump();
    final TestGesture g = await tester.startGesture(const Offset(200, 400));
    await g.moveBy(const Offset(0, -30));
    await tester.pump();
    final double start = scrolled();
    await g.moveBy(const Offset(0, -50));
    await tester.pump();
    expect(scrolled() - start, moreOrLessEquals(50, epsilon: 0.5));
    await g.up();
    await tester.pumpAndSettle();
  }, skip: _pdfium == null);

  testWidgets('taps and long presses report the page and a whole-page fraction', (WidgetTester tester) async {
    await tester.pumpWidget(view());
    await tester.pump();
    final Rect r = key.currentState!.pageRect(1)!;
    final Offset at = r.topLeft + Offset(r.width * 0.25, r.height * 0.5);
    await tester.tapAt(at);
    await tester.pump(kDoubleTapTimeout);
    expect(taps.single.$1, 1);
    expect(taps.single.$2.dx, moreOrLessEquals(0.25, epsilon: 0.01));
    expect(taps.single.$2.dy, moreOrLessEquals(0.5, epsilon: 0.01));
    final TestGesture g = await tester.startGesture(at);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(presses.single.$1, 1);
    await g.moveBy(Offset(0, r.height * 0.1));
    await tester.pump();
    expect(moves.last.$2.dy, moreOrLessEquals(0.6, epsilon: 0.01));
    await g.up();
    expect(scrolled(), 0); // a long press doesn't scroll
  }, skip: _pdfium == null);

  testWidgets('pinch zooms about the fingers; double tap zooms back out', (WidgetTester tester) async {
    await tester.pumpWidget(view());
    await tester.pump();
    final TestGesture a = await tester.startGesture(const Offset(150, 300));
    final TestGesture b = await tester.startGesture(const Offset(250, 300));
    for (int i = 0; i < 10; i++) {
      await a.moveBy(const Offset(-8, 0));
      await b.moveBy(const Offset(8, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    final double width = key.currentState!.pageRect(1)!.width;
    expect(width, greaterThan(800 - 24));
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(200, 300));
    await tester.pumpAndSettle();
    expect(key.currentState!.pageRect(1)!.width, moreOrLessEquals(800 - 24, epsilon: 0.5));
  }, skip: _pdfium == null);

  test('renders on screen come before renders near it', () async {
    final List<int> order = <int>[];
    Future<void> ask(int page, int priority) =>
        renderer.render(page, 200, const PageLook(), priority: priority).then((ui.Image? _) => order.add(page));
    final List<Future<void>> all = <Future<void>>[
      ask(5, RenderPriority.near),
      ask(6, RenderPriority.near),
      ask(7, RenderPriority.near),
      ask(8, RenderPriority.near),
      ask(1, RenderPriority.visible),
    ];
    await Future.wait(all);
    // Two start at once; of the rest the page on screen goes first.
    expect(order.indexOf(1), lessThan(order.indexOf(7)));
    expect(order.indexOf(1), lessThan(order.indexOf(8)));
  }, skip: _pdfium == null);

  test('a queued render for a page that left is dropped', () async {
    final Future<ui.Image?> a = renderer.render(3, 200, const PageLook(), priority: RenderPriority.near);
    final Future<ui.Image?> b = renderer.render(4, 200, const PageLook(), priority: RenderPriority.near);
    final Future<ui.Image?> c = renderer.render(9, 200, const PageLook(), priority: RenderPriority.near);
    renderer.cancelExcept(<int>{3, 4});
    expect(await c, isNull);
    expect(await a, isNotNull);
    expect(await b, isNotNull);
    expect(renderer.cached(3, 200, const PageLook()), isNotNull);
  }, skip: _pdfium == null);
}
