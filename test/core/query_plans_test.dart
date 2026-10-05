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
import 'package:unfurl/core/tracking/stats_store.dart';
import 'package:unfurl/features/insights/book_insights.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

/// Every SELECT the app runs, with its arguments.
class Recorder extends QueryInterceptor {
  final Map<String, List<Object?>> selects = <String, List<Object?>>{};

  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor executor, String statement, List<Object?> args) {
    selects.putIfAbsent(statement, () => args);
    return super.runSelect(executor, statement, args);
  }
}

/// Tables that grow with the library or with reading; a full scan of one in
/// a query the app runs is a missing index. Small or bounded tables (folders,
/// places, recents, daily_stats by key range, documents in Home's short
/// lists) may scan.
const Set<String> big = <String>{'entries', 'annotations', 'reading_sessions', 'book_days'};

void main() {
  testWidgets('the queries behind Home, Library, Notes, Insights and tracking use indexes', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Recorder rec = Recorder();
    final NativeDatabase raw = NativeDatabase.memory();
    final AppDatabase db = AppDatabase(raw.interceptWith(rec));
    final int folder = await db
        .into(db.folders)
        .insert(FoldersCompanion.insert(uri: 'content://tree/Books', name: 'Books', addedAt: DateTime(2026)));
    for (int i = 0; i < 40; i++) {
      await db
          .into(db.entries)
          .insert(
            EntriesCompanion.insert(
              folderId: folder,
              docId: 'd$i',
              uri: 'content://tree/Books/d$i',
              parent: '',
              name: 'book-$i.epub',
              ext: 'epub',
              isDir: false,
              fingerprint: Value<String?>('fp$i'),
              enriched: const Value<int>(1),
            ),
          );
      await db
          .into(db.documents)
          .insert(
            DocumentsCompanion.insert(
              fingerprint: 'fp$i',
              uri: 'content://tree/Books/d$i',
              name: 'book-$i.epub',
              format: 'epub',
              addedAt: DateTime(2026),
              openedAt: Value<DateTime?>(DateTime(2026, 10, 1 + i % 4)),
              title: Value<String?>('Book $i'),
            ),
          );
      await db
          .into(db.annotations)
          .insert(
            AnnotationsCompanion.insert(
              fingerprint: 'fp$i',
              kind: 'highlight',
              locator: '{}',
              quote: Value<String>('Quote $i'),
              createdAt: DateTime(2026),
            ),
          );
    }
    // A finished session folds into the aggregates, as the tracker does.
    final StatsStore stats = StatsStore(db);
    final DateTime t0 = DateTime(2026, 10, 4, 21);
    final LiveSession s = LiveSession(fingerprint: 'fp1', format: 'epub', mode: 'reader', now: t0);
    for (int m = 1; m <= 5; m++) {
      s.activity(t0.add(Duration(minutes: m)));
    }
    s.end(t0.add(const Duration(minutes: 5)));
    await stats.finish(s, t0.add(const Duration(minutes: 5)));
    await stats.speeds('fp1');
    await stats.recover();

    SharedPreferences.setMockInitialValues(<String, Object>{
      AppSettings.kOnboarded: true,
      AppSettings.kOpenedFile: true,
    });
    final SharedPreferences p = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[prefsProvider.overrideWithValue(p), databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await db.close();
    });
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const UnfurlApp()));
    await tester.pumpAndSettle();
    for (final String tab in <String>['Library', 'Notes', 'More']) {
      await tester.tap(find.bySemanticsLabel(tab).first);
      await tester.pumpAndSettle();
    }
    final BuildContext ctx = tester.element(find.byType(Scaffold).first);
    unawaited(GoRouter.of(ctx).push(Routes.insights));
    await tester.pumpAndSettle();
    unawaited(showBookInsights(ctx, fingerprint: 'fp1', title: 'Book 1', name: 'book-1.epub'));
    await tester.pumpAndSettle();

    final List<String> scans = <String>[];
    for (final MapEntry<String, List<Object?>> q in rec.selects.entries.toList()) {
      if (q.key.startsWith('EXPLAIN')) continue;
      final List<QueryRow> plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN ${q.key}',
            variables: <Variable<Object>>[for (final Object? a in q.value) Variable<Object>(a)],
          )
          .get();
      // --dart-define=PLANS=true prints every plan.
      if (const bool.fromEnvironment('PLANS')) {
        // ignore: avoid_print
        print('${plan.map((QueryRow r) => r.read<String>('detail')).join(' | ')}  ←  ${q.key}');
      }
      for (final QueryRow r in plan) {
        final String d = r.read<String>('detail');
        final RegExpMatch? m = RegExp(r'^SCAN (\w+)(?! USING)').firstMatch(d);
        // A query without WHERE reads every row on purpose (Notes lists every highlight).
        if (m != null && big.contains(m[1]) && q.key.contains('WHERE')) scans.add('$d  ←  ${q.key}');
      }
    }
    // ignore: avoid_print
    print('${rec.selects.length} distinct SELECTs checked');
    expect(scans, isEmpty, reason: scans.join('\n'));
  });
}

void unawaited(Future<void>? f) {}
