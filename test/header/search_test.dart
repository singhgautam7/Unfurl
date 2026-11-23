import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/design_system/app_header.dart';
import 'package:unfurl/design_system/buttons.dart';
import 'package:unfurl/design_system/search_field.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

const double _statusBar = 40;

/// A page whose header is a [HeaderSearch], under a 40 dp status bar.
Future<ScrollController> _pump(WidgetTester tester, {Map<String, Object> prefs = const <String, Object>{}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final SharedPreferences p = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(overrides: <Override>[prefsProvider.overrideWithValue(p)]);
  addTearDown(container.dispose);
  final ScrollController sc = ScrollController();
  addTearDown(sc.dispose);
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: _statusBar);
  tester.view.viewPadding = const FakeViewPadding(top: _statusBar);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
        home: Scaffold(
          body: HeaderPage(
            header: HeaderSearch(
              hint: 'Search notes',
              onChanged: (String _) {},
              builder: (BuildContext context, Widget? search) => AppHeader(title: 'Notes', actions: <Widget>[?search]),
            ),
            body: (BuildContext context, double inset) => ListView(
              controller: sc,
              clipBehavior: Clip.none,
              padding: EdgeInsets.only(top: inset),
              children: <Widget>[for (int i = 0; i < 200; i++) SizedBox(height: 48, child: Text('row $i'))],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return sc;
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byType(AppIconButton).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final FontLoader sans = FontLoader('Instrument Sans')
      ..addFont(rootBundle.load('assets/fonts/instrument_sans/InstrumentSans-Variable.ttf'));
    await sans.load();
  });

  testWidgets('open at rest, under a status bar: 48 dp field, hit-testable, an edge tap focuses', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    await _open(tester);
    final Finder field = find.byType(SearchField);
    expect(field.hitTestable(), findsOneWidget);
    final Rect r = tester.getRect(field);
    expect(r.height, 48);
    expect(r.top, greaterThan(_statusBar), reason: 'below the status bar');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isFalse);
    // The edge of the pill, not the text line.
    await tester.tapAt(Offset(r.right - 3, r.center.dy));
    await tester.pump();
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('scrolled, the open bar is the pill: 12 dp sides, 8 under the status bar, 56 tall', (
    WidgetTester tester,
  ) async {
    final ScrollController sc = await _pump(tester);
    await _open(tester);
    sc.jumpTo(100);
    await tester.pumpAndSettle();
    final Rect r = tester.getRect(find.byType(SearchField));
    expect(r.left, 12);
    expect(r.right, 360 - 12);
    expect(r.top, _statusBar + 8);
    expect(r.height, 56);
    expect(find.byType(SearchField).hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('text and focus survive the morph both ways, in the same field', (WidgetTester tester) async {
    final ScrollController sc = await _pump(tester);
    await _open(tester);
    await tester.enterText(find.byType(EditableText), 'draft');
    await tester.pump();
    final Element before = tester.element(find.byType(EditableText));
    sc.jumpTo(200);
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(EditableText)), same(before));
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'draft');
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    sc.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(EditableText)), same(before));
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'draft');
    expect(tester.getRect(find.byType(SearchField)).height, 48);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Floating header off: the open bar scrolls away with the page', (WidgetTester tester) async {
    final ScrollController sc = await _pump(tester, prefs: <String, Object>{AppSettings.kFloatingHeader: false});
    await _open(tester);
    final Rect rest = tester.getRect(find.byType(SearchField));
    sc.jumpTo(20);
    await tester.pump();
    expect(tester.getRect(find.byType(SearchField)).top, rest.top - 20);
    sc.jumpTo(500);
    await tester.pump();
    expect(tester.getRect(find.byType(SearchField)).bottom, lessThanOrEqualTo(0));
    await tester.pumpWidget(const SizedBox());
  });
}
