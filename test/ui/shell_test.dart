import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unfurl/app.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/providers.dart';
import 'package:unfurl/core/router/router.dart';
import 'package:go_router/go_router.dart';
import 'package:unfurl/core/router/nav_shell.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/design_system/nav_pill.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

/// The app past onboarding, with a file opened once (so the pill shows), on
/// an in-memory database. The platform channel is absent; `Platform` answers
/// null to every call, as it does here.
Future<ProviderContainer> pumpApp(WidgetTester tester, {Map<String, Object> prefs = const <String, Object>{}}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    AppSettings.kOnboarded: true,
    AppSettings.kOpenedFile: true,
    ...prefs,
  });
  final SharedPreferences p = await SharedPreferences.getInstance();
  final AppDatabase db = AppDatabase(NativeDatabase.memory());
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[prefsProvider.overrideWithValue(p), databaseProvider.overrideWithValue(db)],
  );
  addTearDown(() async {
    container.dispose();
    await db.close();
  });
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const UnfurlApp()));
  await tester.pumpAndSettle();
  return container;
}

/// Labels inside the pill only (the screens carry the same words in titles).
Finder pillText(String label) => find.descendant(of: find.byType(NavPill), matching: find.text(label));

void main() {
  testWidgets('only the selected destination shows its label, and a tap moves it', (WidgetTester tester) async {
    await pumpApp(tester);
    expect(pillText('Home'), findsOneWidget);
    expect(pillText('Library'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pumpAndSettle();
    expect(pillText('Library'), findsOneWidget);
    expect(pillText('Home'), findsNothing);
    expect(find.text('Library'), findsNWidgets(2)); // header and pill
  });

  /// The pill measures its label in the real typeface (tests otherwise draw
  /// square placeholder glyphs).
  setUpAll(() async {
    final FontLoader sans = FontLoader('Instrument Sans')
      ..addFont(rootBundle.load('assets/fonts/instrument_sans/InstrumentSans-Variable.ttf'));
    await sans.load();
  });

  Future<void> at360(WidgetTester tester, double scale) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  testWidgets('five tabs fit at 360dp with Library labelled up to 130% (N1)', (WidgetTester tester) async {
    await at360(tester, 1.3);
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pumpAndSettle();
    expect(pillText('Library'), findsOneWidget);
    // The pill keeps a 16dp margin each side.
    expect(tester.getSize(find.byType(NavPill)).width, lessThanOrEqualTo(360 - 32));
    for (final String tab in <String>['Home', 'Library', 'Files', 'Notes', 'More']) {
      expect(find.descendant(of: find.byType(NavPill), matching: find.bySemanticsLabel(tab)), findsOneWidget);
    }
  });

  testWidgets('at the largest font the active tab drops its label for a tooltip (N1)', (WidgetTester tester) async {
    await at360(tester, 2);
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pumpAndSettle();
    expect(pillText('Library'), findsNothing);
    expect(
      find.descendant(of: find.byType(NavPill), matching: find.bySemanticsLabel('Library')),
      findsOneWidget,
      reason: 'the label is the content description',
    );
    expect(find.byTooltip('Library'), findsOneWidget);
    expect(tester.getSize(find.byType(NavPill)).width, lessThanOrEqualTo(360 - 32));
  });

  testWidgets('re-tapping a tab returns it to its root; each tab keeps its own stack', (WidgetTester tester) async {
    await pumpApp(tester);
    final GoRouter router = GoRouter.of(tester.element(find.byType(NavPill)));
    // Into a folder inside Library (an empty in-memory library: a missing id still pushes a page).
    router.go('/library/folders');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/library/folders');
    expect(find.byType(NavPill).hitTestable(), findsNothing, reason: 'the pill steps away inside a tab');
    // Another tab, then back: Library is where it was.
    router.go(Routes.files);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/library/folders');
  });

  testWidgets('back from another tab lands on Home', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing marked yet'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(pillText('Home'), findsOneWidget);
  });

  testWidgets('a pushed page covers the pill and pops back to its tab', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // Mid-transition: still animating, not snapped.
    expect(find.byType(FadeTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(find.byType(NavPill).hitTestable(), findsNothing);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(pillText('More'), findsOneWidget);
  });

  testWidgets('navHidden slides the pill away and back', (WidgetTester tester) async {
    final ProviderContainer c = await pumpApp(tester);
    c.read(navHiddenProvider.notifier).set(hidden: true);
    await tester.pumpAndSettle();
    expect(find.byType(NavPill).hitTestable(), findsNothing);
    c.read(navHiddenProvider.notifier).set(hidden: false);
    await tester.pumpAndSettle();
    expect(find.byType(NavPill).hitTestable(), findsOneWidget);
  });

  testWidgets('the first frame uses the cached theme', (WidgetTester tester) async {
    await pumpApp(
      tester,
      prefs: <String, Object>{AppSettings.kMode: 'dark', AppSettings.kAmoled: true, AppSettings.kDynamic: false},
    );
    final BuildContext ctx = tester.element(find.byType(NavPill));
    expect(Theme.of(ctx).extension<UnfurlColors>()!.tone, Tone.amoled);
  });

  testWidgets('a new wallpaper seed is applied and cached for the launch window', (WidgetTester tester) async {
    final ProviderContainer c = await pumpApp(tester);
    await c.read(settingsProvider.notifier).setWallpaperSeed(const Color(0xFF3367D6));
    await tester.pumpAndSettle();
    final SharedPreferences p = c.read(prefsProvider);
    expect(p.getInt(AppSettings.kSeed), 0xFF3367D6);
    expect(
      p.getInt(AppSettings.kLaunchLight),
      ThemeFamily.fromSeed(const Color(0xFF3367D6)).colors(Tone.light).surface.toARGB32(),
    );
    expect(AppSettings.read(p).family, ThemeFamily.fromSeed(const Color(0xFF3367D6)));
  });

  testWidgets('every tab and pushed page fits a 360dp phone at the largest font scale', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    for (final String tab in <String>['Library', 'Notes', 'More', 'Home']) {
      await tester.tap(find.bySemanticsLabel(tab));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    for (final String page in <String>['Settings', 'Privacy', 'Permissions', 'Licences', 'About']) {
      await tester.ensureVisible(find.text(page));
      await tester.pumpAndSettle();
      await tester.tap(find.text(page));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
    }
    // Settings › Theme: the family grid at the largest text.
    await tester.scrollUntilVisible(find.text('Settings'), -200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    // Appearance › Theme, by its value (the Reader section has a "Theme" too).
    await tester.tap(find.text('Saffron · System'));
    await tester.pumpAndSettle();
    expect(find.text('Saffron'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    // Settings › Reader: every reading control, and Folders from Library.
    await tester.tap(find.text('Reader').first);
    await tester.pumpAndSettle();
    expect(find.text('Reader colours'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Folders'), 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Folders'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    // A RenderFlex overflow anywhere above fails the test on its own.
  });
}
