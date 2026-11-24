import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unfurl/core/motion/haptics.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/design_system/app_header.dart';
import 'package:unfurl/design_system/app_icon.dart';
import 'package:unfurl/design_system/buttons.dart';
import 'package:unfurl/features/settings/info_screens.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

import '../ui/shell_test.dart' show pumpApp;

/// Counts its builds and depends on the header scope, as [AppHeader] does.
class _Probe extends StatelessWidget {
  const _Probe(this.count);
  final List<int> count;

  @override
  Widget build(BuildContext context) {
    count[0]++;
    HeaderFloat.maybeOf(context);
    return AppHeader(
      title: 'Title',
      onBack: () {},
      actions: <Widget>[
        AppIconButton(icon: AppIcons.search, semanticLabel: 'Search', onPressed: () {}),
        AppIconButton(icon: AppIcons.moreHoriz, semanticLabel: 'More options', onPressed: () {}),
      ],
    );
  }
}

class Harness {
  Harness(this.container, this.scroll, this.headerBuilds, this.bodyBuilds, this.taps);
  final ProviderContainer container;
  final ScrollController scroll;
  final List<int> headerBuilds;
  final List<int> bodyBuilds;
  final List<int> taps;
}

Future<Harness> pumpPage(WidgetTester tester, {Map<String, Object> prefs = const <String, Object>{}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final SharedPreferences p = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(overrides: <Override>[prefsProvider.overrideWithValue(p)]);
  addTearDown(container.dispose);
  final ScrollController sc = ScrollController();
  addTearDown(sc.dispose);
  final List<int> headerBuilds = <int>[0];
  final List<int> bodyBuilds = <int>[0];
  final List<int> taps = <int>[0];
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
        home: Scaffold(
          body: HeaderPage(
            header: _Probe(headerBuilds),
            body: (BuildContext context, double inset) => ListView(
              controller: sc,
              clipBehavior: Clip.none,
              padding: EdgeInsets.only(top: inset),
              children: <Widget>[
                Builder(
                  builder: (BuildContext _) {
                    bodyBuilds[0]++;
                    return const SizedBox(height: 48);
                  },
                ),
                for (int i = 0; i < 200; i++) SizedBox(height: 48, child: Text('row $i')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return Harness(container, sc, headerBuilds, bodyBuilds, taps);
}

Finder get _back => find.byType(AppIconButton).first;
double _buttonTop(WidgetTester t) => t.getRect(_back).top;

Future<void> jump(WidgetTester t, Harness h, double to) async {
  h.scroll.jumpTo(to);
  await t.pump();
}

/// A real scroll activity (continuous updates), pumped for [ms].
Future<void> glide(WidgetTester t, Harness h, double to, int ms) async {
  final Future<void> f = h.scroll.animateTo(
    to,
    duration: Duration(milliseconds: ms),
    curve: Curves.linear,
  );
  for (int i = 0; i < ms ~/ 16 + 2; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
  await f;
}

void main() {
  setUpAll(() async {
    final FontLoader sans = FontLoader('Instrument Sans')
      ..addFont(rootBundle.load('assets/fonts/instrument_sans/InstrumentSans-Variable.ttf'));
    await sans.load();
  });

  const double rest = 8;
  const double pill = 12;

  testWidgets('pill past 32 dp, header at 8 dp, no flicker between', (WidgetTester tester) async {
    final Harness h = await pumpPage(tester);
    expect(_buttonTop(tester), rest);
    await jump(tester, h, 31);
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), rest);
    await jump(tester, h, 32);
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), pill);
    for (final double y in <double>[20, 12, 9, 15, 31]) {
      await jump(tester, h, y);
      await tester.pumpAndSettle();
      expect(_buttonTop(tester), pill, reason: 'still the pill at $y');
    }
    await jump(tester, h, 8);
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), rest);
    for (final double y in <double>[9, 20, 31]) {
      await jump(tester, h, y);
      await tester.pumpAndSettle();
      expect(_buttonTop(tester), rest, reason: 'still the header at $y');
    }
  });

  testWidgets('a round trip leaves the header at exactly its rest rect', (WidgetTester tester) async {
    final Harness h = await pumpPage(tester);
    final Rect header = tester.getRect(find.byType(AppHeader));
    final Rect title = tester.getRect(find.text('Title'));
    final List<Rect> buttons = tester
        .widgetList(find.byType(AppIconButton))
        .map((Widget w) => tester.getRect(find.byWidget(w)))
        .toList();
    await jump(tester, h, 300);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AppHeader)), isNot(header));
    await jump(tester, h, 0);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AppHeader)), header);
    expect(tester.getRect(find.text('Title')), title);
    expect(
      tester.widgetList(find.byType(AppIconButton)).map((Widget w) => tester.getRect(find.byWidget(w))).toList(),
      buttons,
    );
  });

  testWidgets('Always never hides', (WidgetTester tester) async {
    final Harness h = await pumpPage(tester);
    for (double y = 0; y < 400; y += 10) {
      await jump(tester, h, y);
    }
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), pill);
  });

  testWidgets('When scrolling up: hides after 16 dp down, shows after 8 dp up', (WidgetTester tester) async {
    final Harness h = await pumpPage(tester, prefs: <String, Object>{AppSettings.kPillMode: 'scrollUp'});
    await jump(tester, h, 100);
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), lessThan(0), reason: '100 dp down in one go');
    await jump(tester, h, 94);
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), lessThan(0), reason: '6 up is not more than 8');
    await jump(tester, h, 90);
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), pill, reason: '10 up');
    for (int i = 1; i <= 3; i++) {
      await jump(tester, h, 90.0 + i * 5);
    }
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), pill, reason: '15 down is not more than 16');
    await jump(tester, h, 107);
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), lessThan(0), reason: '17 down');
    // A direction change resets the other counter: 6 up, then down again.
    await jump(tester, h, 101);
    await jump(tester, h, 105);
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), lessThan(0));
  });

  testWidgets('When scrolling stops: hides after 16 dp moved, shows 300 ms after the end', (WidgetTester tester) async {
    final Harness h = await pumpPage(tester, prefs: <String, Object>{AppSettings.kPillMode: 'scrollStop'});
    await jump(tester, h, 100);
    await tester.pumpAndSettle();
    final Future<void> f = h.scroll.animateTo(600, duration: const Duration(milliseconds: 500), curve: Curves.linear);
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_buttonTop(tester), lessThan(pill), reason: 'leaving');
    await tester.pump(const Duration(milliseconds: 400));
    await f;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(_buttonTop(tester), lessThan(0), reason: 'still hidden before 300 ms');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), pill);
  });

  testWidgets('Floating header off: the header scrolls away with the content', (WidgetTester tester) async {
    final Harness h = await pumpPage(tester, prefs: <String, Object>{AppSettings.kFloatingHeader: false});
    final Rect rect = tester.getRect(find.byType(AppHeader));
    await jump(tester, h, 20);
    expect(tester.getRect(find.byType(AppHeader)).top, rect.top - 20);
    await jump(tester, h, 500);
    expect(tester.getRect(find.byType(AppHeader)).top, rect.top - 64, reason: 'gone by its own height');
    await jump(tester, h, 0);
    expect(tester.getRect(find.byType(AppHeader)), rect);
  });

  testWidgets('a setting change updates an open page without a restart', (WidgetTester tester) async {
    final Harness h = await pumpPage(tester);
    await jump(tester, h, 200);
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), pill);
    await h.container.read(settingsProvider.notifier).setFloatingHeader(value: false);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AppHeader)).top, -64);
    await h.container.read(settingsProvider.notifier).setFloatingHeader(value: true);
    await h.container.read(settingsProvider.notifier).setPillMode(PillMode.scrollUp);
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), pill);
    await jump(tester, h, 240);
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), lessThan(0), reason: 'the new mode applies at once');
  });

  testWidgets('scrolling rebuilds neither the body nor the header', (WidgetTester tester) async {
    final Harness h = await pumpPage(tester, prefs: <String, Object>{AppSettings.kPillMode: 'scrollUp'});
    final int body = h.bodyBuilds[0];
    final int header = h.headerBuilds[0];
    // 2000 px in 50 steps: one change to the pill, one to hidden.
    for (int i = 1; i <= 50; i++) {
      await jump(tester, h, i * 40.0);
    }
    await tester.pumpAndSettle();
    expect(_buttonTop(tester), lessThan(0));
    // ignore: avoid_print
    print('rebuilds over 2000 px: header ${h.headerBuilds[0] - header}, body ${h.bodyBuilds[0] - body}');
    expect(h.headerBuilds[0] - header, 0);
    expect(h.bodyBuilds[0] - body, 0);
  });

  testWidgets('a hidden pill is out of semantics and takes no taps', (WidgetTester tester) async {
    final SemanticsHandle sem = tester.ensureSemantics();
    final Harness h = await pumpPage(tester, prefs: <String, Object>{AppSettings.kPillMode: 'scrollUp'});
    expect(find.semantics.byLabel('Back'), findsOneWidget);
    await jump(tester, h, 100);
    await jump(tester, h, 140);
    await tester.pumpAndSettle();
    expect(find.semantics.byLabel('Back'), findsNothing);
    expect(find.semantics.byLabel('Search'), findsNothing);
    final bool hit = find.byType(AppIconButton).hitTestable().evaluate().isNotEmpty;
    expect(hit, isFalse);
    sem.dispose();
  });

  testWidgets('pill and header carry the same buttons, labels and order, at 48 dp', (WidgetTester tester) async {
    final SemanticsHandle sem = tester.ensureSemantics();
    final Harness h = await pumpPage(tester);
    List<String> labels() =>
        tester.widgetList<AppIconButton>(find.byType(AppIconButton)).map((AppIconButton b) => b.semanticLabel).toList();
    List<String> semantic() => <String>[
      for (final String l in <String>['Back', 'Search', 'More options'])
        if (find.semantics.byLabel(l).evaluate().isNotEmpty) l,
    ];
    final List<String> before = labels();
    expect(semantic(), before.isEmpty ? <String>[] : <String>['Back', 'Search', 'More options']);
    void targets() {
      for (final Element e in find.byType(AppIconButton).evaluate()) {
        final Size s = tester.getSize(find.byElementPredicate((Element x) => x == e));
        expect(s.width, greaterThanOrEqualTo(48));
        expect(s.height, greaterThanOrEqualTo(48));
      }
    }

    targets();
    await jump(tester, h, 200);
    await tester.pumpAndSettle();
    expect(labels(), before);
    expect(semantic(), <String>['Back', 'Search', 'More options']);
    targets();
    sem.dispose();
  });

  testWidgets('Look settings persist and the haptics switch drives Haptics', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SharedPreferences p = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(overrides: <Override>[prefsProvider.overrideWithValue(p)]);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.of(ThemeFamily.saffron, Tone.light), home: const ThemeScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(find.text('Haptics'), 300, scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(Haptics.enabled, isFalse);
    await tester.tap(find.text('Haptics'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(Haptics.enabled, isTrue);
    await tester.ensureVisible(find.text('Floating header'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Floating header'));
    await tester.pump(const Duration(milliseconds: 300));
    // The pill choices are disabled with the header off; turn it back on.
    await tester.tap(find.text('Floating header'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(find.text('When scrolling up'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('When scrolling up'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    p = await SharedPreferences.getInstance();
    final AppSettings s = AppSettings.read(p);
    expect(s.haptics, isTrue);
    expect(s.floatingHeader, isTrue);
    expect(s.pillMode, PillMode.scrollUp);
  });

  testWidgets('Home, Theme and Settings fit 360x640 at text scale 2.0', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Theme'));
    // The Look previews never settle: step time instead.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
