import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unfurl/app.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/providers.dart';
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

  testWidgets('the label drops at a large text scale; the glyphs stay', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    expect(pillText('Home'), findsNothing);
    expect(find.bySemanticsLabel('Home'), findsOneWidget);
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
    for (final String page in <String>['Settings', 'Folders', 'About', 'Privacy policy', 'Licences']) {
      await tester.ensureVisible(find.text(page));
      await tester.pumpAndSettle();
      await tester.tap(find.text(page));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
    }
    // A RenderFlex overflow anywhere above fails the test on its own.
  });
}
