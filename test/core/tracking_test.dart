import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/tracking/session.dart';
import 'package:unfurl/core/tracking/stats_store.dart';
import 'package:unfurl/core/tracking/tracker.dart';

/// A UTC clock shifted by [offset] stands in for the device's timezone.
DateTime Function(DateTime) zone(Duration offset) =>
    (DateTime d) => d.toUtc().add(offset);

final DateTime t0 = DateTime.utc(2026, 10, 4, 9);

LiveSession session({String mode = 'reader', Duration idle = TrackingRules.defaultIdle, DateTime? at}) => LiveSession(
  fingerprint: 'fp',
  format: 'epub',
  mode: mode,
  now: at ?? t0,
  idle: idle,
  wordsBetween: (int a, int b) => (b - a) ~/ 6,
  startIndex: 0,
  startPage: 0,
  toLocal: zone(Duration.zero),
);

void main() {
  group('idle threshold', () {
    test('3x the median page time, within 60 s and 5 min; 120 s before there is one', () {
      expect(TrackingRules.idleFor(0), const Duration(seconds: 120));
      expect(TrackingRules.idleFor(10000), const Duration(seconds: 60));
      expect(TrackingRules.idleFor(40000), const Duration(seconds: 120));
      expect(TrackingRules.idleFor(400000), const Duration(minutes: 5));
    });

    test('idle stops the clock a third of the threshold after the last activity', () {
      final LiveSession s = session();
      s.activity(t0.add(const Duration(seconds: 30)));
      // Nothing for 10 minutes: credited up to 30 s + 40 s.
      s.flush(t0.add(const Duration(minutes: 10)));
      expect(s.activeMs, 70000);
      expect(s.reading, isFalse);
      // A touch resumes it.
      s.activity(t0.add(const Duration(minutes: 11)));
      s.flush(t0.add(const Duration(minutes: 12)));
      expect(s.activeMs, 70000 + 60000);
    });

    test('background and screen off pause; listening counts apart from reading', () {
      final LiveSession s = session();
      s.background(t0.add(const Duration(seconds: 50)));
      s.foreground(t0.add(const Duration(minutes: 5)));
      s.setListening(t0.add(const Duration(minutes: 6)), on: true);
      // Listening goes on with the screen off.
      s.background(t0.add(const Duration(minutes: 7)));
      s.setListening(t0.add(const Duration(minutes: 9)), on: false);
      s.end(t0.add(const Duration(minutes: 9)));
      expect(s.activeMs, 50000 + 60000);
      expect(s.listeningMs, 3 * 60000);
    });
  });

  test('sessions under 30 s are not sessions', () {
    final LiveSession s = session()..end(t0.add(const Duration(seconds: 29)));
    expect(s.counts, isFalse);
    final LiveSession l = session()..end(t0.add(const Duration(seconds: 30)));
    expect(l.counts, isTrue);
  });

  group('forward-only progress', () {
    test('Reader mode: words past the furthest point; rereading and jumps add nothing', () {
      final LiveSession s = session();
      s.readerAt(t0.add(const Duration(seconds: 60)), 600); // 100 words in a minute
      s.readerAt(t0.add(const Duration(seconds: 70)), 300); // back: nothing
      s.readerAt(t0.add(const Duration(seconds: 90)), 900); // 50 more past 600
      s.readerAt(t0.add(const Duration(seconds: 95)), 60000, jump: true); // scrubber
      s.readerAt(t0.add(const Duration(seconds: 96)), 120000); // 10,000 words in 1 s: a jump
      expect(s.words, 150);
    });

    test('Page view and comics: unique pages read for 2 s or more', () {
      final LiveSession s = session(mode: 'page');
      s.pageAt(t0.add(const Duration(seconds: 20)), 1); // page 0 read
      s.pageAt(t0.add(const Duration(seconds: 21)), 2); // page 1 flicked past
      s.pageAt(t0.add(const Duration(seconds: 40)), 1); // page 2 read
      s.pageAt(t0.add(const Duration(seconds: 60)), 50, jump: true); // page 1 again, then a jump
      s.end(t0.add(const Duration(seconds: 90))); // page 50 read
      expect(s.pages, <int>{0, 2, 50});
    });
  });

  group('days', () {
    test('a session across midnight is split between the days and hours', () {
      final LiveSession s = session(at: DateTime.utc(2026, 10, 4, 23, 50));
      for (int m = 1; m <= 11; m++) {
        s.activity(DateTime.utc(2026, 10, 4, 23, 50 + m));
      }
      s.end(DateTime.utc(2026, 10, 5, 0, 1));
      expect(s.dayMs, <int, int>{20261004: 10 * 60000, 20261005: 60000});
      expect(s.dayHourMs[20261004]![23], 10 * 60000);
      expect(s.dayHourMs[20261005]![0], 60000);
    });

    test('a timezone change mid-session files time under the new local day', () {
      Duration offset = Duration.zero;
      final LiveSession s = LiveSession(
        fingerprint: 'fp',
        format: 'epub',
        mode: 'reader',
        now: DateTime.utc(2026, 10, 4, 22),
        toLocal: (DateTime d) => d.add(offset),
      );
      s.flush(DateTime.utc(2026, 10, 4, 22, 1));
      offset = const Duration(hours: 5, minutes: 30); // flew east: now 03:31 on the 5th
      s.activity(DateTime.utc(2026, 10, 4, 22, 1, 30));
      s.end(DateTime.utc(2026, 10, 4, 22, 2));
      expect(s.dayMs, <int, int>{20261004: 60000, 20261005: 60000});
      expect(s.dayHourMs[20261005]![3], 60000);
    });
  });

  group('aggregates', () {
    late AppDatabase db;
    late StatsStore store;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = StatsStore(db);
    });
    tearDown(() => db.close());

    test('a finished session updates the day, the book and the book day in one go', () async {
      final LiveSession s = session()
        ..readerAt(t0.add(const Duration(minutes: 2)), 1200)
        ..end(t0.add(const Duration(minutes: 3)));
      await store.finish(s, t0.add(const Duration(minutes: 3)));
      final DailyStat d = (await db.select(db.dailyStats).get()).single;
      expect(
        (d.day, d.readingMs, d.sessions, d.words, d.readerMs, d.longestFp),
        (20261004, 180000, 1, 200, 180000, 'fp'),
      );
      expect(jsonDecode(d.formatMs), <String, Object?>{'epub': 180000});
      expect(d.hourMs.split(',')[9], '180000');
      final BookStat b = (await store.book('fp'))!;
      expect((b.readingMs, b.sessions, b.readerWords), (180000, 1, 200));
      expect((await db.select(db.bookDays).get()).single.ms, 180000);
      expect((await db.select(db.readingSessions).get()).single.open, isFalse);
      // A second session adds to the same rows.
      final LiveSession s2 = session(at: t0.add(const Duration(hours: 2)))
        ..end(t0.add(const Duration(hours: 2, minutes: 1)));
      await store.finish(s2, t0.add(const Duration(hours: 2, minutes: 1)));
      final DailyStat d2 = (await db.select(db.dailyStats).get()).single;
      expect((d2.readingMs, d2.sessions), (240000, 2));
      expect((await store.book('fp'))!.sessions, 2);
    });

    test('a session under 30 s leaves no trace, even after a checkpoint', () async {
      final LiveSession s = session();
      await store.checkpoint(s, t0.add(const Duration(seconds: 10)));
      s.end(t0.add(const Duration(seconds: 20)));
      await store.finish(s, t0.add(const Duration(seconds: 20)));
      expect(await db.select(db.readingSessions).get(), isEmpty);
      expect(await db.select(db.dailyStats).get(), isEmpty);
    });

    test('checkpoint and recovery: a crash loses at most the last minute', () async {
      DateTime now = t0;
      final ReadingSessionTracker tracker = ReadingSessionTracker(
        store,
        clock: () => now,
        toLocal: zone(Duration.zero),
      );
      TestWidgetsFlutterBinding.ensureInitialized();
      await tracker.open(owner: tracker, fingerprint: 'fp', format: 'kindle', mode: 'reader');
      now = t0.add(const Duration(seconds: 50));
      tracker.activity();
      now = t0.add(const Duration(seconds: 61));
      await tracker.checkpoint();
      // The app dies here. Next launch:
      final ReadingSessionTracker next = ReadingSessionTracker(StatsStore(db));
      await next.recover();
      final DailyStat d = (await db.select(db.dailyStats).get()).single;
      expect(d.readingMs, 61000);
      expect(jsonDecode(d.formatMs), <String, Object?>{'kindle': 61000});
      expect((await db.select(db.readingSessions).get()).single.open, isFalse);
      // Recovered once only.
      await next.recover();
      expect((await db.select(db.dailyStats).get()).single.readingMs, 61000);
    });

    test('speeds: the book once read 10 min, else 30 days of your own, else none', () async {
      expect((await store.speeds('fp', now: t0)).wpm, isNull);
      // 40 minutes in Reader mode, 10,000 words: 250 wpm.
      final LiveSession s = session();
      for (int m = 1; m <= 40; m++) {
        s.readerAt(t0.add(Duration(minutes: m)), m * 1500);
      }
      s.end(t0.add(const Duration(minutes: 40)));
      await store.finish(s, t0.add(const Duration(minutes: 40)));
      expect((await store.speeds('fp', now: t0)).wpm, closeTo(250, 1));
      expect((await store.speeds('other', now: t0)).wpm, closeTo(250, 1));
    });

    test('finishing a book records the date once; unfinishing clears it', () async {
      await store.setFinished('fp', finished: true);
      final DateTime? first = (await store.book('fp'))!.finishedAt;
      expect(first, isNotNull);
      await store.setFinished('fp', finished: true);
      expect((await store.book('fp'))!.finishedAt, first);
      await store.setFinished('fp', finished: false);
      expect((await store.book('fp'))!.finishedAt, isNull);
    });
  });

  test('running median moves an eighth of the way', () {
    expect(nudgeMedian(0, 30000), 30000);
    expect(nudgeMedian(30000, 38000), 31000);
    expect(nudgeMedian(30000, null), 30000);
  });
}
