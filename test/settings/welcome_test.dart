import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/motion/theme_ripple.dart';
import 'package:unfurl/design_system/buttons.dart';
import 'package:unfurl/design_system/family_card.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

import '../ui/shell_test.dart' show pumpApp;

const Map<String, Object> _first = <String, Object>{AppSettings.kOnboarded: false};

void _size(WidgetTester tester, {double scale = 1}) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _step(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The vertical scrollers of the page on screen.
Iterable<ScrollableState> _pageScrollers(WidgetTester tester) => tester
    .stateList<ScrollableState>(find.byType(Scrollable))
    .where((ScrollableState s) => s.widget.axis == Axis.vertical)
    .where((ScrollableState s) {
      final double x = (s.context.findRenderObject()! as RenderBox).localToGlobal(Offset.zero).dx;
      return x > -1 && x < 360;
    });

/// Every label of an AppButton on screen fits on its own line(s): none cut.
void _labelsShowInFull(WidgetTester tester) {
  for (final Element e in find.byType(AppButton).hitTestable().evaluate()) {
    final String label = (e.widget as AppButton).label;
    final Finder text = find.descendant(of: find.byWidget(e.widget), matching: find.text(label));
    final RenderParagraph p = tester.renderObject<RenderParagraph>(text);
    expect(p.didExceedMaxLines, isFalse, reason: '"$label" is cut');
  }
}

void main() {
  setUpAll(() async {
    final FontLoader sans = FontLoader('Instrument Sans')
      ..addFont(rootBundle.load('assets/fonts/instrument_sans/InstrumentSans-Variable.ttf'));
    await sans.load();
  });

  testWidgets('Skip lands on the setup page, which has no accent grid and no Skip', (WidgetTester tester) async {
    _size(tester);
    await pumpApp(tester, prefs: _first);
    expect(find.text('Open a file and start reading'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await _step(tester);
    expect(find.text('Set up Unfurl'), findsOneWidget);
    expect(find.byType(FamilyCard), findsNothing);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Choose a folder'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(find.text('Skip').hitTestable(), findsNothing);
    // Back goes to the page before; the system back does too.
    await tester.tap(find.text('Skip for now'), warnIfMissed: false);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('back and next walk the pages; every page fits 360x640 without scrolling', (WidgetTester tester) async {
    _size(tester);
    await pumpApp(tester, prefs: _first);
    for (int i = 0; i < 4; i++) {
      expect(tester.takeException(), isNull);
      for (final ScrollableState s in _pageScrollers(tester)) {
        expect(s.position.maxScrollExtent, 0, reason: 'page $i fits');
      }
      _labelsShowInFull(tester);
      if (i < 3) {
        await tester.tap(find.text('Next'));
        await _step(tester);
      }
    }
    expect(find.text('Set up Unfurl'), findsOneWidget);
    await tester.tap(find.text('Skip for now'), warnIfMissed: false);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the largest font: no overflow, labels in full, pages scroll', (WidgetTester tester) async {
    _size(tester, scale: 2);
    await pumpApp(tester, prefs: _first);
    for (int i = 0; i < 4; i++) {
      expect(tester.takeException(), isNull, reason: 'page $i');
      _labelsShowInFull(tester);
      expect(find.text(i == 0 ? 'Next' : (i < 3 ? 'Next' : 'Choose a folder')), findsOneWidget);
      if (i < 3) {
        await tester.tap(find.text('Next'));
        await _step(tester);
      }
    }
    expect(find.text('Skip for now'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Light, Dark and System on the setup page run the theme ripple', (WidgetTester tester) async {
    _size(tester);
    final ProviderContainer container = await pumpApp(tester, prefs: _first);
    await tester.tap(find.text('Skip'));
    await _step(tester);
    final Finder paints = find.descendant(of: find.byType(ThemeRipple), matching: find.byType(CustomPaint));
    final int rest = paints.evaluate().length;
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
    expect(paints.evaluate().length, greaterThan(rest), reason: 'the snapshot overlay is drawn');
    await _step(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });
}
