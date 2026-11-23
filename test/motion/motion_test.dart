import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unfurl/core/motion/kit.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

Widget host(MotionLevel level, Widget child) => MaterialApp(
  home: MotionScope(
    level: level,
    child: Scaffold(body: Center(child: child)),
  ),
);

double scaleOf(WidgetTester t, Finder inside) {
  final Transform tr = t.widget<Transform>(find.descendant(of: inside, matching: find.byType(Transform)).first);
  return tr.transform.storage[0];
}

void main() {
  group('resolveMotionLevel', () {
    test('Remove animations wins over everything', () {
      for (final DeviceClass d in DeviceClass.values) {
        expect(resolveMotionLevel(d, systemOff: true), MotionLevel.off);
      }
    });
    test('otherwise the device class decides', () {
      expect(resolveMotionLevel(DeviceClass.low, systemOff: false), MotionLevel.subtle);
      expect(resolveMotionLevel(DeviceClass.normal, systemOff: false), MotionLevel.expressive);
      expect(resolveMotionLevel(DeviceClass.unknown, systemOff: false), MotionLevel.expressive);
    });
    test('device class cut is 3.5 GB or the low-RAM flag', () {
      expect(classifyDevice(ramMb: 3000), DeviceClass.low);
      expect(classifyDevice(ramMb: 8000, lowRamFlag: true), DeviceClass.low);
      expect(classifyDevice(ramMb: 8000), DeviceClass.normal);
    });
  });

  testWidgets('Motion.levelOf falls back to the MediaQuery without a scope', (WidgetTester t) async {
    late MotionLevel level;
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (BuildContext c) {
            level = Motion.levelOf(c);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(level, MotionLevel.off);
  });

  testWidgets('springTo keeps velocity when retargeted mid-flight', (WidgetTester t) async {
    final AnimationController c = AnimationController.unbounded(vsync: t);
    addTearDown(c.dispose);
    unawaited(c.springTo(1, Motion.springDefault));
    await t.pump();
    await t.pump(const Duration(milliseconds: 80));
    final double v = c.value;
    final double vel = c.velocity;
    expect(v, greaterThan(0));
    expect(vel, greaterThan(0));
    unawaited(c.springTo(0, Motion.springDefault));
    expect(c.value, v); // no jump
    await t.pump(const Duration(milliseconds: 16));
    expect(c.value, greaterThan(v - 0.05)); // still moving up on the old momentum
    await t.pumpAndSettle();
    expect(c.value, 0);
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  group('Settings', () {
    test('persist and re-read', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppSettings d = AppSettings.read(prefs);
      expect(d.haptics, isFalse);
      expect(d.floatingHeader, isTrue);
      expect(d.pillMode, PillMode.always);
      expect(d.deviceClass, DeviceClass.unknown);
      await prefs.setBool(AppSettings.kHaptics, true);
      await prefs.setBool(AppSettings.kFloatingHeader, false);
      await prefs.setString(AppSettings.kPillMode, 'scrollStop');
      await prefs.setString(AppSettings.kDeviceClass, 'low');
      final AppSettings s = AppSettings.read(prefs);
      expect(s.haptics, isTrue);
      expect(s.floatingHeader, isFalse);
      expect(s.pillMode, PillMode.scrollStop);
      expect(s.deviceClass, DeviceClass.low);
    });
  });

  group('Pressable', () {
    int buzzes = 0;
    setUp(() {
      buzzes = 0;
      Haptics.reset();
      Haptics.enabled = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'HapticFeedback.vibrate') buzzes++;
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

    testWidgets('scales and morphs at Expressive, then springs back and idles', (WidgetTester t) async {
      final List<double> radii = <double>[];
      await t.pumpWidget(
        host(
          MotionLevel.expressive,
          Pressable(
            kind: PressKind.card,
            onTap: () {},
            child: const SizedBox(key: Key('p'), width: 100, height: 100),
          ),
        ),
      );
      final Finder p = find.byType(Pressable);
      final TestGesture g = await t.startGesture(t.getCenter(p));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(scaleOf(t, p), lessThan(0.99));
      await g.up();
      await t.pumpAndSettle();
      expect(scaleOf(t, p), 1);
      expect(t.binding.hasScheduledFrame, isFalse);

      await t.pumpWidget(
        host(
          MotionLevel.expressive,
          Pressable(
            kind: PressKind.iconButton,
            builder: (BuildContext c, double r, double v) {
              radii.add(r);
              return const SizedBox(width: 40, height: 40);
            },
          ),
        ),
      );
      final TestGesture g2 = await t.startGesture(t.getCenter(find.byType(Pressable)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 150));
      expect(radii.first, Motion.radiusRest);
      expect(radii.last, lessThan(Motion.radiusRest));
      await g2.up();
      await t.pumpAndSettle();
      expect(radii.last, Motion.radiusRest);
    });

    testWidgets('does not scale or morph at Off, and Subtle only scales .99', (WidgetTester t) async {
      await t.pumpWidget(host(MotionLevel.off, Pressable(onTap: () {}, child: const SizedBox(width: 80, height: 80))));
      final TestGesture g = await t.startGesture(t.getCenter(find.byType(Pressable)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(scaleOf(t, find.byType(Pressable)), 1);
      await g.up();
      await t.pumpAndSettle();

      await t.pumpWidget(
        host(MotionLevel.subtle, Pressable(onTap: () {}, child: const SizedBox(width: 80, height: 80))),
      );
      final TestGesture g2 = await t.startGesture(t.getCenter(find.byType(Pressable)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(scaleOf(t, find.byType(Pressable)), closeTo(Motion.pressScaleSubtle, 0.002));
      await g2.up();
      await t.pumpAndSettle();
    });

    testWidgets('haptics fire only when enabled', (WidgetTester t) async {
      int taps = 0;
      await t.pumpWidget(
        host(MotionLevel.expressive, Pressable(onTap: () => taps++, child: const SizedBox(width: 80, height: 80))),
      );
      await t.tap(find.byType(Pressable));
      await t.pumpAndSettle();
      expect(taps, 1);
      expect(buzzes, 0);
      Haptics.enabled = true;
      await t.tap(find.byType(Pressable));
      await t.pumpAndSettle();
      expect(taps, 2);
      expect(buzzes, 1);
    });
  });

  group('kit renders and settles at every level', () {
    for (final MotionLevel level in MotionLevel.values) {
      testWidgets('RollingNumber $level', (WidgetTester t) async {
        Widget w(int v) => host(level, RollingNumber(value: v, style: const TextStyle(fontSize: 20), animateIn: true));
        await t.pumpWidget(w(9));
        await t.pumpAndSettle();
        await t.pumpWidget(w(120));
        await t.pumpAndSettle();
        expect(find.text('120'), findsOneWidget);
        expect(t.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('ChartDrawIn $level', (WidgetTester t) async {
        double last = -1;
        await t.pumpWidget(
          host(
            level,
            ChartDrawIn(
              kind: ChartKind.bars,
              count: 9,
              builder: (BuildContext c, ChartProgress p) {
                last = p.linear;
                return const SizedBox(width: 10, height: 10);
              },
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(last, 1);
        expect(t.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('ShapeLoader $level', (WidgetTester t) async {
        await t.pumpWidget(host(level, const ShapeLoader()));
        await t.pump(const Duration(milliseconds: 700));
        expect(find.byType(ShapeLoader), findsOneWidget);
        // Off draws a still shape: nothing keeps asking for frames.
        if (level == MotionLevel.off) expect(t.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('ExpandCollapse and ChevronTurn $level', (WidgetTester t) async {
        Widget w(bool open) => host(
          level,
          Column(
            children: <Widget>[
              ChevronTurn(expanded: open),
              ExpandCollapse(expanded: open, child: const Text('body')),
            ],
          ),
        );
        await t.pumpWidget(w(false));
        await t.pumpAndSettle();
        expect(find.text('body', skipOffstage: true), findsNothing);
        await t.pumpWidget(w(true));
        await t.pumpAndSettle();
        expect(find.text('body'), findsOneWidget);
        await t.pumpWidget(w(false));
        await t.pumpAndSettle();
        expect(find.text('body'), findsNothing);
        expect(t.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('SkeletonCrossFade $level', (WidgetTester t) async {
        Widget w(bool loading) => host(
          level,
          SkeletonCrossFade(loading: loading, placeholder: const Text('wait'), child: const Text('done')),
        );
        await t.pumpWidget(w(true));
        expect(find.text('wait'), findsOneWidget);
        await t.pumpWidget(w(false));
        await t.pumpAndSettle();
        expect(find.text('done'), findsOneWidget);
        expect(find.text('wait'), findsNothing);
        expect(t.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('AnimatedWeight $level', (WidgetTester t) async {
        Widget w(bool a) => host(level, AnimatedWeight('Home', isActive: a));
        await t.pumpWidget(w(false));
        final double before = t.getSize(find.byType(AnimatedWeight)).width;
        await t.pumpWidget(w(true));
        await t.pumpAndSettle();
        expect(t.getSize(find.byType(AnimatedWeight)).width, before); // width reserved
        expect(t.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('AnimatedListItem and StaggeredEntrance $level', (WidgetTester t) async {
        bool removed = false;
        Widget w(bool present) => host(
          level,
          Column(
            children: <Widget>[
              const StaggeredEntrance(index: 9, child: Text('a')),
              AnimatedListItem(
                animateIn: true,
                present: present,
                onRemoved: () => removed = true,
                child: const Text('b'),
              ),
            ],
          ),
        );
        await t.pumpWidget(w(true));
        await t.pumpAndSettle();
        await t.pumpWidget(w(false));
        await t.pumpAndSettle();
        expect(removed, isTrue);
        expect(t.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('ThemeRipple $level runs the change and leaves no overlay', (WidgetTester t) async {
        bool applied = false;
        late BuildContext ctx;
        await t.pumpWidget(
          host(
            level,
            ThemeRipple(
              child: Builder(
                builder: (BuildContext c) {
                  ctx = c;
                  return const SizedBox(width: 50, height: 50);
                },
              ),
            ),
          ),
        );
        final Finder paints = find.descendant(of: find.byType(ThemeRipple), matching: find.byType(CustomPaint));
        final int rest = paints.evaluate().length;
        await t.runAsync(() async {});
        final Future<void> f = ThemeRipple.of(ctx).run(const Offset(20, 20), () => applied = true);
        await t.pumpAndSettle();
        await f;
        await t.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 5),
        );
        expect(applied, isTrue);
        expect(paints.evaluate().length, rest);
        expect(t.binding.hasScheduledFrame, isFalse);
      });
    }
  });

  test('Motion.of is the 90 ms fade whenever the level is not Expressive', () {
    expect(Motion.reducedFade, const Duration(milliseconds: 90));
    expect(Motion.staggerDelay(0), Duration.zero);
    expect(Motion.staggerDelay(3), const Duration(milliseconds: 90));
    expect(Motion.staggerDelay(40), const Duration(milliseconds: 150));
  });
}
