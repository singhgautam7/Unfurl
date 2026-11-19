import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/motion/kit.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/design_system/app_icon.dart';
import 'package:unfurl/design_system/app_snackbar.dart';
import 'package:unfurl/design_system/buttons.dart';
import 'package:unfurl/design_system/chips.dart';
import 'package:unfurl/design_system/family_card.dart';
import 'package:unfurl/design_system/nav_pill.dart';

Widget host(Widget child, {MotionLevel level = MotionLevel.expressive}) => MaterialApp(
  theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
  home: MotionScope(
    level: level,
    child: Scaffold(body: Center(child: child)),
  ),
);

/// Corner radius of every Material under [of] that has a plain border radius.
List<double> radii(WidgetTester t, Finder of) => <double>[
  for (final Material m in t.widgetList<Material>(find.descendant(of: of, matching: find.byType(Material))))
    if (m.borderRadius != null) m.borderRadius!.resolve(TextDirection.ltr).topLeft.x,
];

const List<(int, String, IconData?)> three = <(int, String, IconData?)>[
  (0, 'One', null),
  (1, 'Two', null),
  (2, 'Three', null),
];

void main() {
  for (final MotionLevel level in MotionLevel.values) {
    testWidgets('SegmentedToggle: selected 12dp, unselected a full pill at ${level.name}', (WidgetTester t) async {
      await t.pumpWidget(
        host(
          SegmentedToggle<int>(options: three, selected: 1, onChanged: (_) {}),
          level: level,
        ),
      );
      await t.pumpAndSettle();
      expect(radii(t, find.byType(SegmentedToggle<int>)), <double>[20, kSelectedRadius, 20]);
    });
  }

  testWidgets('SegmentedToggle: tap changes the value and morphs the shape', (WidgetTester t) async {
    int value = 0;
    await t.pumpWidget(
      StatefulBuilder(
        builder: (BuildContext c, StateSetter set) =>
            host(SegmentedToggle<int>(options: three, selected: value, onChanged: (int v) => set(() => value = v))),
      ),
    );
    await t.tap(find.text('Three'));
    await t.pumpAndSettle();
    expect(value, 2);
    expect(radii(t, find.byType(SegmentedToggle<int>)), <double>[20, 20, kSelectedRadius]);
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('PillChip: selected is a 12dp squircle, unselected a full pill', (WidgetTester t) async {
    Widget chips(bool sel) => host(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PillChip(label: 'A', selected: sel, onTap: () {}),
          PillChip(label: 'B', onTap: () {}),
        ],
      ),
    );
    double radiusOf(String label) {
      final Material m = t.widget<Material>(
        find.descendant(of: find.widgetWithText(PillChip, label), matching: find.byType(Material)).first,
      );
      return (m.shape! as RoundedRectangleBorder).borderRadius.resolve(TextDirection.ltr).topLeft.x;
    }

    await t.pumpWidget(chips(false));
    await t.pumpAndSettle();
    expect(radiusOf('A'), PillChip.minHeight / 2);
    await t.pumpWidget(chips(true));
    await t.pumpAndSettle();
    expect(radiusOf('A'), kSelectedRadius);
    expect(radiusOf('B'), PillChip.minHeight / 2);
  });

  testWidgets('AppIconButton morphs under the finger at Expressive, stays round at Off', (WidgetTester t) async {
    Future<ShapeBorder> pressed(MotionLevel level) async {
      await t.pumpWidget(
        host(
          AppIconButton(icon: AppIcons.search, semanticLabel: 'Go', onPressed: () {}),
          level: level,
        ),
      );
      final TestGesture g = await t.startGesture(t.getCenter(find.byType(AppIconButton)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
      final Material m = t.widget<Material>(
        find.descendant(of: find.byType(AppIconButton), matching: find.byType(Material)).first,
      );
      await g.up();
      await t.pumpAndSettle();
      return m.shape!;
    }

    final ShapeBorder ex = await pressed(MotionLevel.expressive);
    expect(ex, isA<RoundedRectangleBorder>());
    expect((ex as RoundedRectangleBorder).borderRadius.resolve(TextDirection.ltr).topLeft.x, lessThan(20));
    expect(await pressed(MotionLevel.off), isA<CircleBorder>());
    // Released: round again.
    final Material m = t.widget<Material>(
      find.descendant(of: find.byType(AppIconButton), matching: find.byType(Material)).first,
    );
    expect(m.shape, isA<CircleBorder>());
  });

  group('NavPill', () {
    final List<String> haptics = <String>[];
    setUp(() {
      haptics.clear();
      Haptics.enabled = true;
      Haptics.reset();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall c) async {
          if (c.method == 'HapticFeedback.vibrate') haptics.add(c.arguments as String);
          return null;
        },
      );
    });
    tearDown(() {
      Haptics.enabled = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    for (final MotionLevel level in MotionLevel.values) {
      testWidgets('indicator moves to the tapped tab and settles at ${level.name}', (WidgetTester t) async {
        int index = 0;
        await t.pumpWidget(
          StatefulBuilder(
            builder: (BuildContext c, StateSetter set) => host(
              NavPill(index: index, onSelect: (int i) => set(() => index = i)),
              level: level,
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.bySemanticsLabel('Library'));
        await t.pumpAndSettle();
        expect(index, 1);
        // Settled: no frame is scheduled and the label sits on the new tab only.
        expect(t.binding.hasScheduledFrame, isFalse);
        expect(find.text('Library'), findsOneWidget);
        expect(find.text('Home'), findsNothing);
      });
    }

    testWidgets('a haptic tick on a tab change, none on the active tab', (WidgetTester t) async {
      int index = 0;
      await t.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext c, StateSetter set) =>
              host(NavPill(index: index, onSelect: (int i) => set(() => index = i))),
        ),
      );
      await t.tap(find.bySemanticsLabel('Home'));
      await t.pumpAndSettle();
      expect(haptics, isEmpty);
      await t.tap(find.bySemanticsLabel('Notes'));
      await t.pumpAndSettle();
      expect(haptics, <String>['HapticFeedbackType.selectionClick']);
    });
  });

  testWidgets('FamilyCard shows its check only when selected', (WidgetTester t) async {
    bool hasCheck() => t.any(find.byWidgetPredicate((Widget w) => w is AppIcon && w.icon == AppIcons.check));
    Widget card(bool sel) => host(
      SizedBox(
        width: 180,
        child: FamilyCard(family: ThemeFamily.saffron, tone: Tone.light, selected: sel, onTap: () {}),
      ),
    );
    await t.pumpWidget(card(false));
    await t.pumpAndSettle();
    expect(hasCheck(), isFalse);
    await t.pumpWidget(card(true));
    await t.pumpAndSettle();
    expect(hasCheck(), isTrue);
    await t.pumpWidget(card(false));
    await t.pumpAndSettle();
    expect(hasCheck(), isFalse);
  });

  group('AppSnackbar', () {
    Future<void> show(WidgetTester t, void Function(BuildContext) f) async {
      late BuildContext ctx;
      await t.pumpWidget(
        host(
          Builder(
            builder: (BuildContext c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      f(ctx);
      await t.pump();
    }

    testWidgets('dismisses itself after the toast time', (WidgetTester t) async {
      await show(t, (BuildContext c) => AppSnackbar.info(c, 'Saved'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Saved'), findsOneWidget);
      await t.pump(Motion.toast);
      await t.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('the close button dismisses it', (WidgetTester t) async {
      await show(t, (BuildContext c) => AppSnackbar.info(c, 'Hello'));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byTooltip('Dismiss'));
      await t.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
    });
  });

  testWidgets('touch targets are at least 48dp', (WidgetTester t) async {
    final SemanticsHandle h = t.ensureSemantics();
    await t.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppIconButton(icon: AppIcons.search, semanticLabel: 'Go', onPressed: () {}),
            AppButton(label: 'Save', onPressed: () {}),
            SegmentedToggle<int>(options: three, selected: 0, onChanged: (_) {}),
            NavPill(index: 0, onSelect: (_) {}),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    h.dispose();
  });
}
