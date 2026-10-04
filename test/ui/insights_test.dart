import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unfurl/app.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/providers.dart';
import 'package:unfurl/core/router/router.dart';
import 'package:unfurl/core/tracking/session.dart';
import 'package:unfurl/features/insights/book_insights.dart';
import 'package:unfurl/features/insights/insights_data.dart';
import 'package:unfurl/features/insights/insights_screen.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

/// Sunday 4 October 2026, as on board 6.
final DateTime today = DateTime(2026, 10, 4);

Future<AppDatabase> pumpInsights(
  WidgetTester tester, {
  Future<void> Function(AppDatabase db)? seed,
  Size size = const Size(400, 900),
  bool open = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{AppSettings.kOnboarded: true, AppSettings.kOpenedFile: true});
  final SharedPreferences p = await SharedPreferences.getInstance();
  final AppDatabase db = AppDatabase(NativeDatabase.memory());
  await seed?.call(db);
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      prefsProvider.overrideWithValue(p),
      databaseProvider.overrideWithValue(db),
      insightsClockProvider.overrideWithValue(() => today),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await db.close();
  });
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const UnfurlApp()));
  await tester.pumpAndSettle();
  if (open) {
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(Routes.insights));
    await tester.pumpAndSettle();
  }
  return db;
}

Future<void> day(
  AppDatabase db,
  DateTime d,
  int minutes, {
  int readerMinutes = 0,
  int words = 0,
  int sessions = 1,
  String format = 'epub',
  int hour = 21,
}) => db
    .into(db.dailyStats)
    .insert(
      DailyStatsCompanion.insert(
        day: Value<int>(dayKey(d)),
        readingMs: Value<int>(minutes * 60000),
        sessions: Value<int>(sessions),
        readerMs: Value<int>(readerMinutes * 60000),
        readerWords: Value<int>(words),
        longestMs: Value<int>(minutes * 60000),
        longestFp: const Value<String?>('fp1'),
        formatMs: Value<String>('{"$format": ${minutes * 60000}}'),
        hourMs: Value<String>(<int>[for (int h = 0; h < 24; h++) h == hour ? minutes * 60000 : 0].join(',')),
      ),
    );

Future<void> book(AppDatabase db, String fp, String title, int minutes, {String name = 'book.epub'}) async {
  await db
      .into(db.documents)
      .insert(
        DocumentsCompanion.insert(
          fingerprint: fp,
          uri: 'content://x/$fp',
          name: name,
          format: 'epub',
          title: Value<String?>(title),
          addedAt: today,
          openedAt: Value<DateTime?>(today),
          progress: const Value<double>(0.62),
        ),
      );
  await db
      .into(db.bookStats)
      .insert(
        BookStatsCompanion.insert(
          fingerprint: fp,
          readingMs: Value<int>(minutes * 60000),
          sessions: const Value<int>(31),
          readerMs: Value<int>(minutes * 60000),
          readerWords: Value<int>(minutes * 248),
          firstRead: Value<DateTime?>(DateTime(2026, 8, 12)),
          lastRead: Value<DateTime?>(today),
          wordsLeft: const Value<int?>(84000),
        ),
      );
}

void unawaited(Future<void>? f) {}

/// The Insights screen's own list (the tab underneath has lists too).
Finder get insightsList => find.descendant(of: find.byType(InsightsScreen), matching: find.byType(Scrollable)).first;

/// A widget test with the semantics tree on, so labels can be found.
void semanticsTest(String name, Future<void> Function(WidgetTester tester) body) =>
    testWidgets(name, (WidgetTester tester) async {
      final SemanticsHandle h = tester.ensureSemantics();
      try {
        await body(tester);
      } finally {
        h.dispose();
      }
    });

void main() {
  semanticsTest('no data yet: the empty message and a blank heatmap; More says so too', (WidgetTester tester) async {
    await pumpInsights(tester);
    expect(find.text('Nothing to show yet'), findsOneWidget);
    expect(find.text('No reading days yet'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Insights. No reading yet')), findsOneWidget);
  });

  semanticsTest('a few days: totals and the week fill in; speed and patterns say when', (WidgetTester tester) async {
    await pumpInsights(
      tester,
      seed: (AppDatabase db) async {
        await day(db, DateTime(2026, 10, 2), 18);
        await day(db, DateTime(2026, 10, 3), 9);
        await day(db, today, 19);
      },
    );
    expect(find.bySemanticsLabel('Today: 19 min'), findsOneWidget);
    expect(find.bySemanticsLabel('This week: 46 min'), findsOneWidget);
    expect(find.text('46 min'), findsWidgets);
    expect(find.text('28 Sep – 4 Oct'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Reader mode: —, after 30 min in Reader')), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('appear after 7 days'), 300, scrollable: insightsList);
    expect(find.textContaining('appear after 7 days with reading'), findsOneWidget);
  });

  semanticsTest('full: speed, time of day, formats and most-read; the chart steps by month', (
    WidgetTester tester,
  ) async {
    await pumpInsights(
      tester,
      seed: (AppDatabase db) async {
        for (int i = 0; i < 60; i++) {
          await day(
            db,
            today.subtract(Duration(days: i)),
            40,
            readerMinutes: 40,
            words: 40 * 252,
            format: i.isEven ? 'epub' : 'kindle',
          );
        }
        await book(db, 'fp1', 'The Count of Monte Cristo', 2300);
        await book(db, 'fp2', 'Middlemarch', 1865);
      },
    );
    expect(find.bySemanticsLabel(RegExp('Reader mode: 252 wpm')), findsOneWidget);
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('Oct 2026'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Earlier'));
    await tester.pumpAndSettle();
    expect(find.text('Sep 2026'), findsOneWidget);
    await tester.scrollUntilVisible(
      find
          .descendant(
            of: find.byType(InsightsScreen),
            matching: find.widgetWithText(InkWell, 'The Count of Monte Cristo'),
          )
          .first,
      400,
      scrollable: insightsList,
    );
    expect(find.text('Mostly 21:00–23:00'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'EPUB: \d+%')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Kindle: \d+%')), findsOneWidget);
    // A most-read row opens that book's insights.
    await tester.ensureVisible(
      find
          .descendant(
            of: find.byType(InsightsScreen),
            matching: find.widgetWithText(InkWell, 'The Count of Monte Cristo'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(InsightsScreen),
            matching: find.widgetWithText(InkWell, 'The Count of Monte Cristo'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Book insights'), findsOneWidget);
    expect(find.bySemanticsLabel('Time spent: 38 h 20 min'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Estimated time left: about 5 h 39 min, at 248 wpm')), findsOneWidget);
  });

  semanticsTest('book insights before any reading: zeros, "Not yet", nothing to chart', (WidgetTester tester) async {
    await pumpInsights(
      tester,
      open: false,
      seed: (AppDatabase db) => db
          .into(db.documents)
          .insert(
            DocumentsCompanion.insert(
              fingerprint: 'm',
              uri: 'content://x/m',
              name: 'moby-dick.mobi',
              format: 'kindle',
              title: const Value<String?>('Moby-Dick'),
              addedAt: DateTime(2026, 10, 2),
              openedAt: Value<DateTime?>(DateTime(2026, 10, 2)),
            ),
          ),
    );
    unawaited(
      showBookInsights(
        tester.element(find.byType(Scaffold).first),
        fingerprint: 'm',
        title: 'Moby-Dick',
        name: 'moby-dick.mobi',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Opened 2 Oct. No reading time yet.'), findsOneWidget);
    expect(find.bySemanticsLabel('Time spent: 0 min'), findsOneWidget);
    expect(find.bySemanticsLabel('Started: Not yet'), findsOneWidget);
    expect(find.text('Nothing to chart yet'), findsOneWidget);
    expect(find.text('MOBI'), findsOneWidget);
  });

  semanticsTest('expanded: a two-column dashboard and book insights as a 400dp panel', (WidgetTester tester) async {
    await pumpInsights(
      tester,
      size: const Size(1280, 800),
      seed: (AppDatabase db) async {
        for (int i = 0; i < 30; i++) {
          await day(db, today.subtract(Duration(days: i)), 30, readerMinutes: 30, words: 30 * 250);
        }
        await book(db, 'fp1', 'Pride and Prejudice', 552);
      },
    );
    final Offset overview = tester.getTopLeft(find.bySemanticsLabel(RegExp('^Today:')));
    final Offset speed = tester.getTopLeft(find.text('READING SPEED'));
    expect(speed.dx, greaterThan(overview.dx + 400));
    expect((speed.dy - overview.dy).abs(), lessThan(120));
    await tester.scrollUntilVisible(
      find
          .descendant(of: find.byType(InsightsScreen), matching: find.widgetWithText(InkWell, 'Pride and Prejudice'))
          .first,
      300,
      scrollable: insightsList,
    );
    await tester.ensureVisible(
      find
          .descendant(of: find.byType(InsightsScreen), matching: find.widgetWithText(InkWell, 'Pride and Prejudice'))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(of: find.byType(InsightsScreen), matching: find.widgetWithText(InkWell, 'Pride and Prejudice'))
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(SidePanel)).width, 400);
  });
}
