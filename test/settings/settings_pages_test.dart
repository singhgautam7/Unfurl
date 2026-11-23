import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/motion/motion.dart';
import 'package:unfurl/core/motion/motion_level.dart';
import 'package:unfurl/design_system/containers.dart';
import 'package:unfurl/features/settings/settings_controller.dart';
import 'package:unfurl/core/motion/theme_ripple.dart';

import '../ui/shell_test.dart' show pumpApp;

/// Pages with the Look previews never settle: step time instead.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void _everyRowIsDescribed(WidgetTester tester) {
  final List<ListRow> rows = tester.widgetList<ListRow>(find.byType(ListRow)).toList();
  expect(rows, isNotEmpty);
  for (final ListRow r in rows) {
    expect(r.icon, isNotNull, reason: '${r.label} has an icon tile');
    expect(r.subtitle, isNotNull, reason: '${r.label} has a description');
    expect(r.subtitle!.trim(), isNotEmpty);
    expect(r.subtitle!.endsWith('.'), isFalse, reason: '${r.label}: no full stop');
    expect(r.value, isNull, reason: '${r.label}: no value on the right');
    expect(r.trailing, isNull, reason: '${r.label}: nothing custom on the right');
  }
}

void main() {
  setUpAll(() async {
    final FontLoader sans = FontLoader('Instrument Sans')
      ..addFont(rootBundle.load('assets/fonts/instrument_sans/InstrumentSans-Variable.ttf'));
    await sans.load();
  });

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('More, Settings, Theme and Controls rows: an icon tile, a description, no value on the right', (
    WidgetTester tester,
  ) async {
    tall(tester);
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('More'));
    await _settle(tester);
    _everyRowIsDescribed(tester);
    expect(find.text('Theme, reader, controls, library'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await _settle(tester);
    _everyRowIsDescribed(tester);

    await tester.tap(find.text('Controls'));
    await _settle(tester);
    _everyRowIsDescribed(tester);
    await tester.pageBack();
    await _settle(tester);

    await tester.tap(find.text('Theme'));
    await _settle(tester);
    _everyRowIsDescribed(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping a switch row title toggles once', (WidgetTester tester) async {
    tall(tester);
    final ProviderContainer container = await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('More'));
    await _settle(tester);
    await tester.tap(find.text('Settings'));
    await _settle(tester);
    await tester.tap(find.text('Theme'));
    await _settle(tester);
    expect(container.read(settingsProvider).expressive, isTrue);
    await tester.tap(find.text('Expressive colours'));
    await _settle(tester);
    expect(container.read(settingsProvider).expressive, isFalse, reason: 'flipped once, not twice');
    expect(container.read(settingsProvider).haptics, isFalse);
    await tester.ensureVisible(find.text('Haptics'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Haptics'));
    await _settle(tester);
    expect(container.read(settingsProvider).haptics, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Pure black is dimmed with a reason in Light; there is no wallpaper row without a seed', (
    WidgetTester tester,
  ) async {
    tall(tester);
    final ProviderContainer container = await pumpApp(tester);
    await container.read(settingsProvider.notifier).setThemeMode(ThemeMode.light);
    await tester.tap(find.bySemanticsLabel('More'));
    await _settle(tester);
    await tester.tap(find.text('Settings'));
    await _settle(tester);
    await tester.tap(find.text('Theme'));
    await _settle(tester);
    final ListRow black = tester.widget<ListRow>(find.widgetWithText(ListRow, 'Pure black'));
    expect(black.enabled, isFalse);
    expect(black.subtitle, 'Used in dark mode');
    expect(find.text('From your wallpaper'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a motion preference an older version stored is ignored', (WidgetTester tester) async {
    await pumpApp(tester, prefs: <String, Object>{'motion.preference': 'off'});
    final BuildContext ctx = tester.element(find.byType(Scaffold).first);
    expect(Motion.levelOf(ctx), MotionLevel.expressive);
    expect(find.text('Motion'), findsNothing);
  });

  testWidgets('a mode change on the Theme page runs the theme ripple', (WidgetTester tester) async {
    tall(tester);
    final ProviderContainer container = await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('More'));
    await _settle(tester);
    await tester.tap(find.text('Settings'));
    await _settle(tester);
    await tester.tap(find.text('Theme'));
    await _settle(tester);
    final Finder paints = find.descendant(of: find.byType(ThemeRipple), matching: find.byType(CustomPaint));
    final int rest = paints.evaluate().length;
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
    expect(paints.evaluate().length, greaterThan(rest), reason: 'the snapshot overlay is drawn');
    await _settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });
}
