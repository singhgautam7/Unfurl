import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/theme/tokens.dart';
import 'package:unfurl/features/reader/comfort.dart';

void main() {
  group('sleep timer', () {
    // Widget tests run timers on a fake clock; the timer's own clock follows it.
    Duration elapsed = Duration.zero;
    final DateTime start = DateTime(2026, 10, 5, 22);
    Future<void> pass(WidgetTester tester, Duration d) async {
      elapsed += d;
      await tester.pump(d);
    }

    testWidgets('counts down, fades the last 10 s, then expires once', (WidgetTester tester) async {
      elapsed = Duration.zero;
      int expired = 0;
      final SleepTimer t = SleepTimer(onExpire: () => expired++, clock: () => start.add(elapsed));
      t.set(15);
      expect((t.active, t.label, t.volume), (true, '15:00', 1.0));
      await pass(tester, const Duration(minutes: 14, seconds: 55));
      expect(t.fading, isTrue);
      expect(t.volume, closeTo(0.5, 0.05));
      await pass(tester, const Duration(seconds: 6));
      expect((expired, t.active), (1, false));
      await pass(tester, const Duration(minutes: 1));
      expect(expired, 1);
      t.dispose();
    });

    testWidgets('a touch during the fade starts it over; End of chapter waits for the chapter', (
      WidgetTester tester,
    ) async {
      elapsed = Duration.zero;
      int expired = 0;
      final SleepTimer t = SleepTimer(onExpire: () => expired++, clock: () => start.add(elapsed))..set(15);
      await pass(tester, const Duration(minutes: 14, seconds: 52));
      t.touched();
      expect(t.label, '15:00');
      t.set(null);
      expect((t.chapter, t.label, t.volume), (true, 'Chapter', 1.0));
      await pass(tester, const Duration(hours: 2));
      expect(expired, 0);
      t.chapterEnded();
      expect((expired, t.active), (1, false));
      t.dispose();
    });
  });

  group('auto-advance', () {
    test('nine speeds and the interval steps stay in range', () {
      final AutoAdvance s = AutoAdvance(
        vsync: const TestVSync(),
        paged: false,
        scrollBy: (_) => true,
        turn: () => true,
      );
      expect(s.readout, '${ComfortSpec.defaultLevel}');
      for (int i = 0; i < 20; i++) {
        s.step(1);
      }
      expect(s.level, 9);
      s.paged = true;
      expect(s.readout, '30s');
      s.step(1); // more often
      expect(s.seconds, 20);
      for (int i = 0; i < 20; i++) {
        s.step(-1);
      }
      expect(s.seconds, 120);
      s.dispose();
    });

    testWidgets('scrolls on the frame clock, eases up to speed, and stops at the end', (WidgetTester tester) async {
      double scrolled = 0;
      final AutoAdvance s = AutoAdvance(
        vsync: tester,
        paged: false,
        level: 4, // 60 dp/s
        scrollBy: (double px) {
          scrolled += px;
          return scrolled < 100;
        },
        turn: () => true,
      )..enable(on: true);
      await tester.pump();
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // About a second: 60 dp less the 300 ms ramp.
      expect(scrolled, inInclusiveRange(45, 60));
      for (int i = 0; i < 200 && s.running; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(s.running, isFalse);
      s.dispose();
    });

    testWidgets('paged: turns every interval; a touch pauses with the hint', (WidgetTester tester) async {
      int turns = 0;
      final AutoAdvance s = AutoAdvance(
        vsync: tester,
        paged: true,
        seconds: 10,
        scrollBy: (_) => true,
        turn: () {
          turns++;
          return true;
        },
      )..enable(on: true);
      await tester.pump();
      for (int i = 0; i < 21; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(turns, 2);
      s.pause(byTouch: true);
      expect((s.running, s.pausedByTouch, s.shown), (false, true, true));
      s.dispose();
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
