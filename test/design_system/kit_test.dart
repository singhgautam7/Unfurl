import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/motion/kit.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/design_system/app_icon.dart';
import 'package:unfurl/design_system/buttons.dart';
import 'package:unfurl/design_system/chips.dart';
import 'package:unfurl/design_system/containers.dart';
import 'package:unfurl/design_system/search_field.dart';

final UnfurlColors colors = AppTheme.of(ThemeFamily.saffron, Tone.light).extension<UnfurlColors>()!;

Widget host(Widget child, {MotionLevel level = MotionLevel.expressive, double scale = 1}) => MaterialApp(
  theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
  builder: (BuildContext c, Widget? w) => MediaQuery(
    data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
    child: w!,
  ),
  home: MotionScope(
    level: level,
    child: Scaffold(body: Center(child: child)),
  ),
);

double radiusIn(WidgetTester t, Finder of) {
  final Material m = t.widget<Material>(find.descendant(of: of, matching: find.byType(Material)).first);
  return (m.shape! as RoundedRectangleBorder).borderRadius.resolve(TextDirection.ltr).topLeft.x;
}

Rect materialRect(WidgetTester t, Finder of) =>
    t.getRect(find.descendant(of: of, matching: find.byType(Material)).first);

void main() {
  group('corner morph while held', () {
    Future<(double, double)> heldAndBack(WidgetTester t, Finder f) async {
      final TestGesture g = await t.startGesture(t.getCenter(f));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      final double held = radiusIn(t, f);
      await g.up();
      await t.pumpAndSettle();
      return (held, radiusIn(t, f));
    }

    testWidgets('AppButton: 12 at 56, back to a pill; 8 at 40', (WidgetTester t) async {
      await t.pumpWidget(host(AppButton(label: 'Save', onPressed: () {})));
      final (double, double) big = await heldAndBack(t, find.byType(AppButton));
      expect(big.$1, closeTo(12, 0.6));
      expect(big.$2, 28);
      await t.pumpWidget(host(AppButton(label: 'Save', height: 40, onPressed: () {})));
      final (double, double) small = await heldAndBack(t, find.byType(AppButton));
      expect(small.$1, closeTo(8, 0.6));
      expect(small.$2, 20);
    });

    testWidgets('AppIconButton goes to 12, back to a circle', (WidgetTester t) async {
      await t.pumpWidget(host(AppIconButton(icon: AppIcons.search, semanticLabel: 'Go', onPressed: () {})));
      final (double, double) r = await heldAndBack(t, find.byType(AppIconButton));
      expect(r.$1, closeTo(12, 0.6));
      expect(r.$2, 20);
    });

    testWidgets('a circle FAB morphs to 12 through the builder', (WidgetTester t) async {
      final List<double> seen = <double>[];
      await t.pumpWidget(
        host(
          Pressable(
            kind: PressKind.fab,
            restRadius: 28,
            onTap: () {},
            builder: (BuildContext c, double r, double v) {
              seen.add(r);
              return const SizedBox.square(dimension: 56);
            },
          ),
        ),
      );
      final TestGesture g = await t.startGesture(t.getCenter(find.byType(Pressable)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(seen.first, 28);
      expect(seen.last, closeTo(12, 0.6));
      await g.up();
      await t.pumpAndSettle();
      expect(seen.last, 28);
    });
  });

  testWidgets('a disabled or loading button does nothing', (WidgetTester t) async {
    int taps = 0;
    await t.pumpWidget(host(const AppButton(label: 'Off', onPressed: null)));
    final TestGesture g = await t.startGesture(t.getCenter(find.byType(AppButton)));
    await t.pump(const Duration(milliseconds: 300));
    expect(radiusIn(t, find.byType(AppButton)), 28);
    await g.up();
    await t.pumpAndSettle();
    await t.pumpWidget(host(AppButton(label: 'Wait', isLoading: true, onPressed: () => taps++)));
    await t.tap(find.byType(AppButton));
    await t.pump();
    expect(taps, 0);
    expect(find.byType(ShapeLoader), findsOneWidget);
  });

  group('PillChip', () {
    testWidgets('32dp drawn in a 48dp hit region', (WidgetTester t) async {
      await t.pumpWidget(host(PillChip(label: 'All', onTap: () {})));
      expect(t.getSize(find.byType(PillChip)).height, 48);
      expect(materialRect(t, find.byType(PillChip)).height, PillChip.height);
      await t.pumpWidget(host(PillChip(label: 'All', onTap: () {})));
    });

    testWidgets('tapping the hit region above the pill selects it', (WidgetTester t) async {
      int taps = 0;
      await t.pumpWidget(host(PillChip(label: 'All', onTap: () => taps++)));
      final Rect r = t.getRect(find.byType(PillChip));
      await t.tapAt(Offset(r.center.dx, r.top + 2));
      expect(taps, 1);
    });

    testWidgets('ChipWrap: the gap down equals the gap across', (WidgetTester t) async {
      await t.pumpWidget(
        host(
          SizedBox(
            width: 300,
            child: ChipWrap(
              children: <Widget>[for (int i = 0; i < 6; i++) PillChip(label: 'Chip $i', onTap: () {})],
            ),
          ),
        ),
      );
      final List<Rect> r = <Rect>[
        for (final Element e in find.byType(PillChip).evaluate()) materialRect(t, find.byWidget(e.widget)),
      ];
      final double across = r[1].left - r[0].right;
      final int next = r.indexWhere((Rect x) => x.top > r[0].bottom);
      expect(next, greaterThan(0));
      expect(r[next].top - r[0].bottom, closeTo(across, 0.01));
      expect(across, 8);
    });

    testWidgets('the count grows in over frames, not in one', (WidgetTester t) async {
      Widget chip(bool sel) => host(PillChip(label: 'All', selected: sel, count: 12, onTap: () {}));
      await t.pumpWidget(chip(false));
      final double before = t.getSize(find.byType(PillChip)).width;
      await t.pumpWidget(chip(true));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      final double mid = t.getSize(find.byType(PillChip)).width;
      await t.pumpAndSettle();
      final double after = t.getSize(find.byType(PillChip)).width;
      expect(after, greaterThan(before));
      expect(mid, greaterThan(before));
      expect(mid, lessThan(after));
    });
  });

  testWidgets('SegmentedToggle: the selected segment is primary', (WidgetTester t) async {
    await t.pumpWidget(
      host(
        SegmentedToggle<int>(
          options: const <(int, String, IconData?)>[(0, 'One', null), (1, 'Two', null)],
          selected: 1,
          onChanged: (_) {},
        ),
      ),
    );
    await t.pumpAndSettle();
    final Material m = t.widget<Material>(
      find.descendant(of: find.byType(SegmentedToggle<int>), matching: find.byType(Material)).at(1),
    );
    expect(m.color, colors.primary);
    expect(m.borderRadius!.resolve(TextDirection.ltr).topLeft.x, kSelectedRadius);
  });

  group('one tap, one haptic, one toggle', () {
    final List<String> buzzes = <String>[];
    DateTime clock = DateTime(2026);
    setUp(() {
      buzzes.clear();
      Haptics.enabled = true;
      // Every call is a second apart, so the 50 ms throttle hides no double tick.
      Haptics.now = () => clock = clock.add(const Duration(seconds: 1));
      Haptics.reset();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall c) async {
          if (c.method == 'HapticFeedback.vibrate') buzzes.add(c.arguments as String);
          return null;
        },
      );
    });
    tearDown(() {
      Haptics.enabled = false;
      Haptics.now = DateTime.now;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    testWidgets('a switch row: tapping the title toggles once and ticks once', (WidgetTester t) async {
      bool on = false;
      int calls = 0;
      await t.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext c, StateSetter set) => host(
            SizedBox(
              width: 360,
              child: ListRow(
                label: 'Haptics',
                subtitle: 'Small taps',
                switchValue: on,
                onChanged: (bool v) => set(() {
                  calls++;
                  on = v;
                }),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Haptics'));
      await t.pumpAndSettle();
      expect(calls, 1);
      expect(on, isTrue);
      expect(buzzes.length, 1);
      await t.tap(find.byType(Switch), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(calls, 2);
      expect(on, isFalse);
      expect(buzzes.length, 2);
    });

    testWidgets('a switch row is one toggled semantics node', (WidgetTester t) async {
      final SemanticsHandle h = t.ensureSemantics();
      await t.pumpWidget(
        host(
          SizedBox(
            width: 360,
            child: ListRow(label: 'Haptics', switchValue: true, onChanged: (_) {}),
          ),
        ),
      );
      expect(
        t.getSemantics(find.byType(ListRow)),
        matchesSemantics(
          label: 'Haptics',
          isToggled: true,
          isEnabled: true,
          hasEnabledState: true,
          hasToggledState: true,
          hasTapAction: true,
        ),
      );
      expect(t.getSize(find.byType(ListRow)).height, greaterThanOrEqualTo(56));
      h.dispose();
    });

    testWidgets('a chip and a segment tick once per tap', (WidgetTester t) async {
      await t.pumpWidget(host(PillChip(label: 'All', onTap: () {})));
      await t.tap(find.byType(PillChip));
      await t.pumpAndSettle();
      expect(buzzes.length, 1);
      buzzes.clear();
      int value = 0;
      await t.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext c, StateSetter set) => host(
            SegmentedToggle<int>(
              options: const <(int, String, IconData?)>[(0, 'One', null), (1, 'Two', null)],
              selected: value,
              onChanged: (int v) => set(() => value = v),
            ),
          ),
        ),
      );
      await t.tap(find.text('Two'));
      await t.pumpAndSettle();
      expect(value, 1);
      expect(buzzes.length, 1);
    });

    testWidgets('a button, an icon button and a card tick once; a long press does not tick as a tap', (
      WidgetTester t,
    ) async {
      int longs = 0;
      await t.pumpWidget(
        host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppButton(label: 'Go', onPressed: () {}),
              AppIconButton(icon: AppIcons.search, semanticLabel: 'Find', onPressed: () {}),
              SurfaceCard(onTap: () {}, child: const Text('Card')),
              SurfaceCard(onLongPress: () => longs++, child: const Text('Hold')),
            ],
          ),
        ),
      );
      for (final Finder f in <Finder>[find.byType(AppButton), find.byType(AppIconButton), find.text('Card')]) {
        buzzes.clear();
        await t.tap(f);
        await t.pumpAndSettle();
        expect(buzzes.length, 1, reason: '$f');
      }
      buzzes.clear();
      await t.longPress(find.text('Hold'));
      await t.pumpAndSettle();
      expect(longs, 1);
      expect(buzzes.length, 1); // the long-press haptic only
    });
  });

  testWidgets('SectionHeader: the action text ends on the right edge, in a 48dp target', (WidgetTester t) async {
    await t.pumpWidget(
      host(
        SizedBox(
          width: 300,
          child: SectionHeader(label: 'Recent', action: 'Library', onAction: () {}),
        ),
      ),
    );
    expect(t.getRect(find.text('Library')).right, closeTo(t.getRect(find.byType(SectionHeader)).right, 0.01));
    final Size target = t.getSize(find.byType(Pressable));
    expect(target.height, greaterThanOrEqualTo(48));
    expect(target.width, greaterThanOrEqualTo(48));
  });

  testWidgets('SearchField: a tap on the pill edge focuses it; it is 48dp', (WidgetTester t) async {
    final FocusNode focus = FocusNode();
    addTearDown(focus.dispose);
    await t.pumpWidget(
      host(
        SizedBox(
          width: 320,
          child: SearchField(hint: 'Search', onChanged: (_) {}, focusNode: focus),
        ),
      ),
    );
    final Rect r = t.getRect(find.byType(SearchField));
    expect(r.height, 48);
    expect(focus.hasFocus, isFalse);
    await t.tapAt(Offset(r.left + 4, r.center.dy));
    await t.pump();
    expect(focus.hasFocus, isTrue);
    focus.unfocus();
    await t.pump();
    await t.tapAt(Offset(r.center.dx, r.top + 2));
    await t.pump();
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('at 2.0 text on 360dp nothing overflows', (WidgetTester t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      host(
        scale: 2,
        SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ListRow(
                  label: 'Keep the screen on while reading',
                  icon: AppIcons.search,
                  subtitle: 'A long line',
                  switchValue: true,
                  onChanged: (_) {},
                ),
                ListRow(label: 'Folders', value: 'Documents and downloads', onTap: () {}),
                AppButton(label: 'Open the file', icon: AppIcons.search, onPressed: () {}),
                AppButton(label: 'Cancel', type: AppButtonType.outline, height: 40, onPressed: () {}),
                ChipWrap(
                  children: <Widget>[
                    PillChip(label: 'All', selected: true, count: 120, onTap: () {}),
                    PillChip(label: 'Documents', onTap: () {}),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
