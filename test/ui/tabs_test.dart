import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/motion/kit.dart';
import 'package:unfurl/core/router/branch_stack.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/features/home/home_screen.dart';
import 'package:unfurl/features/library/library_screen.dart';
import 'package:unfurl/features/notes/notes_screen.dart';

import 'shell_test.dart' show pumpApp;

/// Four coloured pages in a [BranchStack].
class Host extends StatefulWidget {
  const Host({this.level = MotionLevel.expressive, super.key});

  final MotionLevel level;

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  int index = 0;

  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
    home: MotionScope(
      level: widget.level,
      child: BranchStack(
        index: index,
        onSelect: go,
        children: <Widget>[
          for (int i = 0; i < 4; i++)
            KeyedSubtree(
              key: ValueKey<int>(i),
              child: Center(child: Text('page $i')),
            ),
        ],
      ),
    ),
  );
}

void main() {
  Future<HostState> pump(WidgetTester tester, [MotionLevel level = MotionLevel.expressive]) async {
    await tester.pumpWidget(Host(level: level));
    return tester.state<HostState>(find.byType(Host));
  }

  double x(WidgetTester tester, int i) => tester.getTopLeft(find.byKey(ValueKey<int>(i), skipOffstage: false)).dx / 800;

  bool shown(int i) => find.text('page $i').evaluate().isNotEmpty;

  for (final MotionLevel level in <MotionLevel>[MotionLevel.expressive, MotionLevel.subtle]) {
    testWidgets('$level: mid-slide both pages are side by side; at rest only one is on stage', (
      WidgetTester tester,
    ) async {
      final HostState host = await pump(tester, level);
      host.go(1);
      await tester.pump(); // builds the page; the clock starts after this frame
      await tester.pump();
      expect(x(tester, 0), closeTo(0, 0.001), reason: 'no slide is spent on the frame that builds the page');
      await tester.pump(const Duration(milliseconds: 150));
      final double left = x(tester, 0), right = x(tester, 1);
      expect(left, inInclusiveRange(-0.9, -0.1));
      expect(right - left, closeTo(1, 0.001));
      await tester.pumpAndSettle();
      expect((shown(0), shown(1), x(tester, 1)), (false, true, 0));
    });
  }

  testWidgets('a far tab slides in from next door', (WidgetTester tester) async {
    final HostState host = await pump(tester);
    host.go(3);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(x(tester, 3) - x(tester, 0), closeTo(1, 0.001));
    expect((shown(1), shown(2)), (false, false));
    await tester.pumpAndSettle();
    expect(x(tester, 3), 0);
  });

  testWidgets('a tap mid-slide carries on from where the pages are', (WidgetTester tester) async {
    final HostState host = await pump(tester);
    host.go(1);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final double before = x(tester, 1);
    host.go(0);
    await tester.pump();
    expect(x(tester, 1), closeTo(before, 0.02));
    await tester.pumpAndSettle();
    expect((shown(0), shown(1)), (true, false));
  });

  testWidgets('Off switches at once', (WidgetTester tester) async {
    final HostState host = await pump(tester, MotionLevel.off);
    host.go(2);
    await tester.pump();
    expect((shown(0), shown(2), x(tester, 2)), (false, true, 0));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a short drag returns, a long one and a fling switch', (WidgetTester tester) async {
    final HostState host = await pump(tester);
    final TestGesture g = await tester.startGesture(const Offset(400, 300));
    await g.moveBy(const Offset(-30, 0));
    await g.moveBy(const Offset(-170, 0));
    await tester.pump(const Duration(seconds: 1));
    expect(x(tester, 0), lessThan(-0.1), reason: 'it follows the finger');
    await g.up();
    await tester.pumpAndSettle();
    expect(host.index, 0);

    await tester.dragFrom(const Offset(700, 300), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(host.index, 1);

    await tester.fling(find.text('page 1'), const Offset(-80, 0), 1200);
    await tester.pumpAndSettle();
    expect(host.index, 2);

    // Past the last page there is nothing to switch to.
    host.go(3);
    await tester.pumpAndSettle();
    await tester.fling(find.text('page 3'), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    expect((host.index, x(tester, 3)), (3, 0));
  });

  testWidgets('tabs are built ahead, offstage, untouchable and still; a visit then builds nothing new', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(LibraryScreen, skipOffstage: false), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(NotesScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(LibraryScreen), findsNothing, reason: 'offstage');
    expect(find.byType(HomeScreen).hitTestable(), findsOneWidget);
    expect(BranchStack.warming.value, isNull);
    expect(TickerMode.valuesOf(tester.element(find.byType(LibraryScreen, skipOffstage: false))).enabled, isFalse);
    expect(tester.hasRunningAnimations, isFalse);
    final Element before = tester.element(find.byType(LibraryScreen, skipOffstage: false));
    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(LibraryScreen)), same(before));
  });
}
