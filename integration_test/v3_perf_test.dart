// On-device timings for v3 (Phase I), recorded rather than asserted: the
// emulator is not a mid-range phone (docs/performance.md). Set up as for
// v3_test.dart, then build with
//
//   flutter build apk --profile --target-platform android-arm64 -t integration_test/v3_perf_test.dart
//
// and read `adb logcat -s flutter` for the "perf:" lines.
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/library/library.dart';
import 'package:unfurl/core/router/router.dart';
import 'package:unfurl/core/tracking/session.dart';
import 'package:unfurl/core/tracking/stats_store.dart';
import 'package:unfurl/features/comics/comics_screen.dart';
import 'package:unfurl/features/insights/insights_data.dart';
import 'package:unfurl/features/insights/insights_screen.dart';
import 'package:unfurl/features/pdf/pdf_screen.dart';
import 'package:unfurl/features/reader/engine/reader_view.dart';

import 'harness.dart';

void report(String what) {
  // ignore: avoid_print
  print('perf: $what');
}

int median(List<int> xs) => (List<int>.of(xs)..sort())[xs.length ~/ 2];

/// Frame build and raster times while [action] runs.
Future<void> frames(String what, Future<void> Function() action) async {
  final List<FrameTiming> t = <FrameTiming>[];
  void add(List<FrameTiming> f) => t.addAll(f);
  SchedulerBinding.instance.addTimingsCallback(add);
  await action();
  // Timings arrive in batches about once a second.
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  SchedulerBinding.instance.removeTimingsCallback(add);
  if (t.isEmpty) return report('$what: no frames');
  int p(List<int> xs, double q) => (List<int>.of(xs)..sort())[((xs.length - 1) * q).round()];
  final List<int> build = <int>[for (final FrameTiming f in t) f.buildDuration.inMicroseconds];
  final List<int> raster = <int>[for (final FrameTiming f in t) f.rasterDuration.inMicroseconds];
  final int slow = t.where((FrameTiming f) => f.totalSpan.inMicroseconds > 16667).length;
  report(
    '$what: ${t.length} frames, build p50 ${p(build, .5) / 1000} p90 ${p(build, .9) / 1000} p99 ${p(build, .99) / 1000} ms, '
    'raster p50 ${p(raster, .5) / 1000} p90 ${p(raster, .9) / 1000} p99 ${p(raster, .99) / 1000} ms, '
    'over 16.7 ms: $slow (${(100 * slow / t.length).toStringAsFixed(1)}%)',
  );
}

/// Opens [name] and reports the time until [ready].
Future<void> timeOpen(WidgetTester tester, String name, bool Function() ready) async {
  final Stopwatch w = Stopwatch()..start();
  await open(tester, name);
  final DateTime end = DateTime.now().add(const Duration(seconds: 30));
  while (!ready() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await tester.pump();
  }
  report('open $name: ${w.elapsedMilliseconds} ms${ready() ? '' : ' (not ready after 30 s)'}');
}

bool comicPage() => find
    .descendant(of: find.byType(ComicsScreen), matching: find.byType(RawImage))
    .evaluate()
    .any((Element e) => (e.widget as RawImage).image != null);

Future<void> flings(WidgetTester tester, Finder on, Offset by, int n) async {
  for (int i = 0; i < n; i++) {
    await tester.fling(on, by, 2500);
    await settle(tester, const Duration(milliseconds: 900));
  }
}

/// A year of reading: a day row for every day, 300 books with stats and 30
/// days each, as a heavy reader's Insights would hold.
Future<void> seedYear(AppDatabase db) async {
  final DateTime today = DateTime.now();
  await db.batch((Batch b) {
    for (int i = 0; i < 365; i++) {
      final int m = 10 + (i * 37) % 80;
      b.insert(
        db.dailyStats,
        DailyStatsCompanion.insert(
          day: Value<int>(dayKey(today.subtract(Duration(days: i)))),
          readingMs: Value<int>(m * 60000),
          sessions: const Value<int>(2),
          readerMs: Value<int>(m * 40000),
          readerWords: Value<int>(m * 160),
          longestMs: Value<int>(m * 30000),
          longestFp: Value<String?>('fp${i % 300}'),
          formatMs: Value<String>('{"epub": ${m * 40000}, "pdf": ${m * 20000}}'),
          hourMs: Value<String>(<int>[for (int h = 0; h < 24; h++) h == 21 ? m * 60000 : 0].join(',')),
        ),
      );
    }
    for (int i = 0; i < 300; i++) {
      b.insert(
        db.documents,
        DocumentsCompanion.insert(
          fingerprint: 'fp$i',
          uri: 'content://x/$i',
          name: 'book-$i.epub',
          format: 'epub',
          title: Value<String?>('Book $i'),
          addedAt: today,
          openedAt: Value<DateTime?>(today.subtract(Duration(days: i))),
          progress: Value<double>((i % 10) / 10),
        ),
      );
      b.insert(
        db.bookStats,
        BookStatsCompanion.insert(
          fingerprint: 'fp$i',
          readingMs: Value<int>((300 - i) * 600000),
          sessions: const Value<int>(12),
          readerMs: Value<int>((300 - i) * 400000),
          readerWords: Value<int>((300 - i) * 1000),
          firstRead: Value<DateTime?>(today.subtract(Duration(days: 30 + i))),
          lastRead: Value<DateTime?>(today.subtract(Duration(days: i))),
          wordsLeft: const Value<int?>(40000),
        ),
      );
      for (int d = 0; d < 30; d++) {
        b.insert(
          db.bookDays,
          BookDaysCompanion.insert(
            fingerprint: 'fp$i',
            day: dayKey(today.subtract(Duration(days: i + d))),
            ms: const Value<int>(1200000),
          ),
        );
      }
    }
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(pdfrxFlutterInitialize);

  testWidgets('perf: opening each format', (WidgetTester tester) async {
    await boot(tester);
    bool readerReady() => find.byType(ReaderView).evaluate().isNotEmpty;
    // Warm the isolates and fonts once so the numbers are per file.
    await timeOpen(tester, 'walden.html', readerReady);
    await close(tester);
    for (final String name in <String>[
      'pride-and-prejudice.epub',
      'yellow-wallpaper.azw3',
      'yellow-wallpaper.mobi',
      'onegin.fb2',
      'walden.fbz',
    ]) {
      await timeOpen(tester, name, readerReady);
      await close(tester);
    }
    for (final String name in <String>[
      'little-nemo-14.cbz',
      'hokusai-manga-2.cb7',
      'krazy-kat-1922.cbr',
      'scan_0412.cbt',
    ]) {
      await timeOpen(tester, name, comicPage);
      await close(tester);
    }
    await timeOpen(tester, 'origin-of-species.pdf', () => find.byType(PdfScreen).evaluate().isNotEmpty);
    await close(tester);
  });

  testWidgets('perf: scrolling and paging', (WidgetTester tester) async {
    await boot(tester, <String, Object>{'reading.layout': 'scroll'});
    await open(tester, 'pride-and-prejudice.epub');
    await until(tester, () => find.byType(ReaderView).evaluate().isNotEmpty, 'the reader');
    await settle(tester, const Duration(seconds: 1));
    await frames('Reader, Scroll, 6 flings', () => flings(tester, find.byType(ReaderView), const Offset(0, -900), 6));
    await close(tester);
    await open(tester, 'origin-of-species.pdf');
    await settle(tester, const Duration(seconds: 2));
    await frames('PDF, continuous, 6 flings', () => flings(tester, find.byType(PdfScreen), const Offset(0, -900), 6));
    await close(tester);
    await open(tester, 'little-nemo-14.cbz');
    await until(tester, comicPage, 'a comic page');
    await frames('Comics, 6 page swipes', () => flings(tester, find.byType(ComicsScreen), const Offset(-500, 0), 6));
    await close(tester);
  });

  testWidgets('perf: a large library and a year of Insights', (WidgetTester tester) async {
    final AppDatabase big = AppDatabase(NativeDatabase.memory());
    final int folder = await big
        .into(big.folders)
        .insert(FoldersCompanion.insert(uri: 'content://tree/Books', name: 'Books', addedAt: DateTime(2026)));
    await big.batch((Batch b) {
      for (int i = 0; i < 5000; i++) {
        b.insert(
          big.entries,
          EntriesCompanion.insert(
            folderId: folder,
            docId: 'd$i',
            uri: 'content://tree/Books/d$i',
            parent: '',
            name: i % 97 == 0 ? 'walden-$i.epub' : 'book-$i.${i.isEven ? 'epub' : 'pdf'}',
            ext: i.isEven ? 'epub' : 'pdf',
            isDir: false,
            title: Value<String?>(i % 97 == 0 ? 'Walden $i' : 'Book $i'),
            enriched: const Value<int>(1),
          ),
        );
      }
    });
    await seedYear(big);

    final Library lib = Library(big);
    final List<int> search = <int>[];
    for (int i = 0; i < 15; i++) {
      final Stopwatch w = Stopwatch()..start();
      final Set<int> hits = await lib.search(i.isEven ? 'walden' : 'book 4');
      search.add(w.elapsedMicroseconds);
      if (i == 0) report('search hits: ${hits.length}');
    }
    report('Library search, 5,000 files: median ${median(search) / 1000} ms (budget 50 ms)');

    final StatsStore stats = StatsStore(big);
    final List<int> fold = <int>[];
    for (int i = 0; i < 10; i++) {
      final DateTime t0 = DateTime.now().subtract(Duration(minutes: 30 + i * 6));
      final LiveSession s = LiveSession(fingerprint: 'fp$i', format: 'epub', mode: 'reader', now: t0);
      for (int m = 1; m <= 5; m++) {
        s.activity(t0.add(Duration(minutes: m)));
      }
      s.end(t0.add(const Duration(minutes: 5)));
      final Stopwatch w = Stopwatch()..start();
      await stats.finish(s, t0.add(const Duration(minutes: 5)));
      fold.add(w.elapsedMicroseconds);
    }
    report('session fold-in over a year of stats: median ${median(fold) / 1000} ms');

    await boot(tester, const <String, Object>{}, big);
    final List<int> compute = <int>[];
    for (int i = 0; i < 5; i++) {
      container.invalidate(insightsProvider);
      final Stopwatch w = Stopwatch()..start();
      await container.read(insightsProvider.future);
      compute.add(w.elapsedMicroseconds);
    }
    report('Insights data, a year and 300 books: median ${median(compute) / 1000} ms');

    await frames('Library grid, 5,000 files, 6 flings', () async {
      await tester.tap(find.bySemanticsLabel('Library').first);
      await settle(tester, const Duration(seconds: 2));
      await flings(tester, find.byType(CustomScrollView).first, const Offset(0, -1200), 6);
    });
    container.invalidate(insightsProvider);
    final Stopwatch shown = Stopwatch()..start();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(Routes.insights));
    await until(
      tester,
      () => find.text('MOST-READ BOOKS').evaluate().isNotEmpty || find.text('Most-read books').evaluate().isNotEmpty,
      'Insights',
      seconds: 20,
    );
    report('Insights screen to content: ${shown.elapsedMilliseconds} ms');
    await frames('Insights, 4 flings', () => flings(tester, find.byType(InsightsScreen), const Offset(0, -900), 4));
  });
}
