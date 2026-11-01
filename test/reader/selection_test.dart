import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/design_system/selection_handle.dart';
import 'package:unfurl/features/reader/engine/layout.dart';
import 'package:unfurl/features/reader/engine/reader_style.dart';
import 'package:unfurl/features/reader/engine/reader_view.dart';
import 'package:unfurl/features/reader/reading_prefs.dart';

import 'harness.dart';

void main() {
  testWidgets('paged: long press selects a word, dragging extends it both ways, handles move the ends', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.reset);
    final ReaderController c = ReaderController(paragraphs());
    final List<List<Rect>> reported = <List<Rect>>[];
    await tester.pumpWidget(readerView(c, onSelection: reported.add));
    await tester.pumpAndSettle();

    // Where a word in the middle of the first paragraph sits on screen.
    final ReaderStyle style = styleOf();
    final Layout l = Layout(
      doc: c.doc,
      style: style,
      pageSize: Size(400 - style.margin * 2, 860 - 64 - 66),
      images: ImageSizes.of(c.doc),
    )..ensure(0);
    final String text = c.doc.sections[0].blocks[0].text;
    final int w = text.indexOf('brown', 150);
    final Rect box = l.page(0)!.fragments.first.boxes(w, w + 5).first;
    final Offset at = box.center + Offset(style.margin, 64);
    final double line = style.size * style.lineHeight;

    final TestGesture g = await tester.startGesture(at);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(c.selection, (w, w + 5), reason: 'the word under the finger');

    // Up and back a line: the selection grows backwards from the word.
    await g.moveTo(at - const Offset(0, 6));
    await tester.pump();
    await g.moveTo(at - Offset(80, line));
    await tester.pump();
    final (int, int) back = c.selection!;
    expect(back.$1, lessThan(w));
    expect(back.$2, w + 5);

    // Down a line: forwards from the word.
    await g.moveTo(at + Offset(60, line));
    await tester.pump();
    final (int, int) fwd = c.selection!;
    expect(fwd.$1, w);
    expect(fwd.$2, greaterThan(w + 5));
    expect(find.byType(SelectionHandle), findsNothing, reason: 'hidden while the finger drags');

    await g.up();
    await tester.pumpAndSettle();
    expect(find.byType(SelectionHandle), findsNWidgets(2));
    expect(reported.last, isNotEmpty, reason: 'the toolbar follows the selection');

    // The end handle, a line down.
    final int end = c.selection!.$2;
    await tester.drag(find.byType(SelectionHandle).last, Offset(0, line));
    await tester.pumpAndSettle();
    expect(c.selection!.$1, w);
    expect(c.selection!.$2, greaterThan(end));

    // The start handle, a line up, moves the start and leaves the end.
    final int end2 = c.selection!.$2;
    await tester.drag(find.byType(SelectionHandle).first, Offset(0, -line));
    await tester.pumpAndSettle();
    expect(c.selection!.$1, lessThan(w));
    expect(c.selection!.$2, end2);
    expect(find.byType(SelectionHandle), findsNWidgets(2));
  });

  testWidgets('scroll: dragging from one block into the next extends across blocks, handles follow the scroll', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 860);
    addTearDown(tester.view.reset);
    final ReaderController c = ReaderController(paragraphs());
    final List<List<Rect>> reported = <List<Rect>>[];
    await tester.pumpWidget(readerView(c, layout: ReaderLayout.scroll, onSelection: reported.add));
    await tester.pumpAndSettle();

    final Finder blocks = find.byWidgetPredicate((Widget w) => w.runtimeType.toString() == '_ScrollBlock');
    final Rect b0 = tester.getRect(blocks.at(0)), b1 = tester.getRect(blocks.at(1));
    final double line = styleOf().size * styleOf().lineHeight;
    final int firstEnd = c.doc.sections[0].blocks[0].start + c.doc.sections[0].blocks[0].text.length;

    final Offset at = Offset(b0.left + 30, b0.top + line / 2);
    final TestGesture g = await tester.startGesture(at);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(c.selection, isNotNull);
    expect(c.selection!.$2, lessThan(firstEnd), reason: 'one word to begin with');
    final int from = c.selection!.$1;
    expect(reported.last, isNotEmpty);

    await g.moveTo(at + const Offset(0, 8));
    await tester.pump();
    await g.moveTo(Offset(b1.left + 80, b1.top + line * 1.5));
    await tester.pump();
    expect(c.selection!.$1, from);
    expect(c.selection!.$2, greaterThan(firstEnd), reason: 'into the next block');
    expect(find.byType(SelectionHandle), findsNothing);

    await g.up();
    await tester.pumpAndSettle();
    expect(find.byType(SelectionHandle), findsNWidgets(2));
    expect(reported.last, isNotEmpty);

    // Scrolling with a selection: the handles ride with the text.
    final Offset before = tester.getTopLeft(find.byType(SelectionHandle).last);
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    final Offset after = tester.getTopLeft(find.byType(SelectionHandle).last);
    expect(after.dy, lessThan(before.dy - 40));
    expect(c.selection!.$1, from, reason: 'scrolling keeps the selection');

    // The end handle, a line down, extends the selection.
    final int end = c.selection!.$2;
    await tester.drag(find.byType(SelectionHandle).last, Offset(0, line));
    await tester.pumpAndSettle();
    expect(c.selection!.$2, greaterThan(end));
    expect(c.selection!.$1, from);

    // A tap clears it and the handles go.
    await tester.tapAt(const Offset(200, 600));
    await tester.pumpAndSettle();
    expect(c.selection, isNull);
    expect(find.byType(SelectionHandle), findsNothing);
  });
}
