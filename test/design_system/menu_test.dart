import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/motion/kit.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/design_system/app_icon.dart';
import 'package:unfurl/design_system/app_menu.dart';

const Size _phone = Size(360, 500);

Widget _app(
  List<AppMenuEntry<String>> entries, {
  MotionLevel level = MotionLevel.expressive,
  Alignment alignment = Alignment.topLeft,
  ValueChanged<String?>? onResult,
}) => MotionScope(
  level: level,
  child: MaterialApp(
    theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
    home: Scaffold(
      body: Align(
        alignment: alignment,
        child: Builder(
          builder: (BuildContext ctx) => IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () async {
              final String? v = await showAppMenu<String>(context: ctx, anchorContext: ctx, entries: entries);
              onResult?.call(v);
            },
          ),
        ),
      ),
    ),
  ),
);

List<AppMenuEntry<String>> _rows(int n) => <AppMenuEntry<String>>[
  for (int i = 0; i < n; i++) AppMenuEntry<String>(value: 'r$i', label: 'Row $i', icon: AppIcons.edit),
];

Future<void> _small(WidgetTester t) async {
  t.view.physicalSize = _phone;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Rect _panel(WidgetTester t) => t.getRect(find.byType(SingleChildScrollView));

void main() {
  testWidgets('one FadeTransition for the panel, and an icon on every row', (WidgetTester t) async {
    await _small(t);
    await t.pumpWidget(_app(_rows(6)));
    final int before = find.byType(FadeTransition).evaluate().length;
    await t.tap(find.byType(IconButton));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byType(FadeTransition).evaluate().length - before, 1);
    expect(
      find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(FadeTransition)),
      findsNothing,
    );
    expect(find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(AppIcon)), findsNWidgets(6));
    await t.pumpAndSettle();
  });

  testWidgets('a tap returns the row value; a disabled row does nothing', (WidgetTester t) async {
    await _small(t);
    String? result = 'none';
    await t.pumpWidget(
      _app(<AppMenuEntry<String>>[
        const AppMenuEntry<String>(value: 'off', label: 'Off row', icon: AppIcons.edit, enabled: false),
        const AppMenuEntry<String>(value: 'on', label: 'On row', icon: AppIcons.share),
      ], onResult: (String? v) => result = v),
    );
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    await t.tap(find.text('Off row'));
    await t.pumpAndSettle();
    expect(find.text('Off row'), findsOneWidget, reason: 'still open');
    expect(result, 'none');
    await t.tap(find.text('On row'));
    await t.pumpAndSettle();
    expect(result, 'on');
    expect(find.text('On row'), findsNothing);
  });

  testWidgets('a tall menu (30 rows, 360x500) scrolls and stays on screen', (WidgetTester t) async {
    await _small(t);
    await t.pumpWidget(_app(_rows(30)));
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    final Rect r = _panel(t);
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(_phone.height));
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(_phone.width));
    await t.drag(find.byType(SingleChildScrollView), const Offset(0, -3000));
    await t.pumpAndSettle();
    expect(t.getRect(find.text('Row 29')).bottom, lessThanOrEqualTo(r.bottom));
  });

  testWidgets('opens above when the anchor is at the bottom', (WidgetTester t) async {
    await _small(t);
    await t.pumpWidget(_app(_rows(4), alignment: Alignment.bottomRight));
    final Rect anchor = t.getRect(find.byType(IconButton));
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    final Rect r = _panel(t);
    expect(r.bottom, lessThanOrEqualTo(anchor.top));
    expect(r.right, closeTo(math.min(anchor.right, _phone.width - 8), 0.5), reason: 'aligned to the nearer edge');
    expect(r.width, 280);
  });

  testWidgets('a selected row shows a check', (WidgetTester t) async {
    await _small(t);
    await t.pumpWidget(
      _app(<AppMenuEntry<String>>[
        const AppMenuEntry<String>(value: 'a', label: 'A', icon: AppIcons.edit, selected: true),
        const AppMenuEntry<String>(value: 'b', label: 'B', icon: AppIcons.edit),
      ]),
    );
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    final Finder checks = find.byWidgetPredicate((Widget w) => w is AppIcon && w.icon == AppIcons.check);
    expect(checks, findsOneWidget);
  });

  for (final MotionLevel level in MotionLevel.values) {
    testWidgets('${level.name}: ${level == MotionLevel.expressive ? 'drops 8 dp' : 'does not translate'}', (
      WidgetTester t,
    ) async {
      await _small(t);
      await t.pumpWidget(_app(_rows(3), level: level));
      await t.tap(find.byType(IconButton));
      await t.pump();
      await t.pump(const Duration(milliseconds: 20));
      final double early = _panel(t).top;
      await t.pumpAndSettle();
      final double settled = _panel(t).top;
      if (level == MotionLevel.expressive) {
        expect(early, lessThan(settled));
      } else {
        expect(early, settled);
      }
    });
  }
}
