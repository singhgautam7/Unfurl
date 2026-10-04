import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/db/database.dart';

/// A database exactly as schema 1 left it (DDL captured from the v1 build),
/// with a folder, a book, its document record and a highlight in it. Built in
/// drift's raw setup hook, before AppDatabase opens it.
NativeDatabase v1WithData() => NativeDatabase.memory(
  setup: (db) {
    for (final String stmt in File('test/core/fixtures/schema_v1.sql').readAsStringSync().split(';\n')) {
      final String sql = stmt.trim().replaceAll(RegExp(r';$'), '');
      // FTS5's shadow tables come with its virtual table.
      if (sql.isNotEmpty && !sql.startsWith("CREATE TABLE 'entries_fts_")) db.execute(sql);
    }
    // Only once: setup runs on every open, and the upgrade must see v1 just once.
    if (db.userVersion != 0) return;
    db
      ..execute("INSERT INTO folders (uri, name, path, added_at) VALUES ('content://tree/Books', 'Books', 'Books', 1)")
      ..execute(
        'INSERT INTO entries (folder_id, doc_id, uri, parent, name, ext, is_dir, fingerprint, title) '
        "VALUES (1, 'd1', 'content://tree/Books/d1', '', 'pride.epub', 'epub', 0, 'fp1', 'Pride and Prejudice')",
      )
      ..execute(
        "INSERT INTO documents (fingerprint, uri, name, format, position, progress, added_at) VALUES ('fp1', 'content://tree/Books/d1', 'pride.epub', 'epub', '{\"s\":3}', 0.4, 1)",
      )
      ..execute(
        'INSERT INTO annotations (fingerprint, kind, color, locator, quote, note, created_at) '
        "VALUES ('fp1', 'highlight', 0, '{\"x\":\"truth\"}', 'truth', 'a note', 1)",
      )
      ..userVersion = 1;
  },
);

void main() {
  test('schema 1 to 2: every annotation, position and folder survives; new columns default', () async {
    final AppDatabase db = AppDatabase(v1WithData());
    final Annotation a = (await db.select(db.annotations).get()).single;
    expect((a.quote, a.note, a.locator), ('truth', 'a note', '{"x":"truth"}'));
    final Document d = (await db.select(db.documents).get()).single;
    expect((d.position, d.progress), ('{"s":3}', 0.4));
    final Folder f = (await db.select(db.folders).get()).single;
    expect((f.name, f.source), ('Books', 'saf_folder'));
    final Entry e = (await db.select(db.entries).get()).single;
    expect((e.title, e.source), ('Pride and Prejudice', 'saf_folder'));
    // The new table works, and search still finds the old entry.
    await db.into(db.places).insert(PlacesCompanion.insert(path: '/storage/emulated/0/Download', name: 'Download'));
    expect((await db.select(db.places).get()).single.pinned, isFalse);
    expect(await db.searchEntries('pride'), <int>[e.id]);
    await db.close();
  });

  test('schema 1 to 3: annotations and positions survive; v3 columns and tables work', () async {
    final AppDatabase db = AppDatabase(v1WithData());
    expect(db.schemaVersion, 3);
    final Annotation a = (await db.select(db.annotations).get()).single;
    expect((a.quote, a.note), ('truth', 'a note'));
    final Document d = (await db.select(db.documents).get()).single;
    expect((d.position, d.progress, d.issue), ('{"s":3}', 0.4, null));
    expect((await db.select(db.entries).get()).single.issue, isNull);
    // The aggregates Insights reads, and their indexes.
    await db.into(db.dailyStats).insert(DailyStatsCompanion.insert(day: const Value<int>(20261004)));
    await db.into(db.bookStats).insert(BookStatsCompanion.insert(fingerprint: 'fp1'));
    await db.into(db.bookDays).insert(BookDaysCompanion.insert(fingerprint: 'fp1', day: 20261004));
    expect((await db.select(db.dailyStats).get()).single.hourMs, '');
    final List<QueryRow> idx = await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'index'").get();
    expect(
      idx.map((QueryRow r) => r.read<String>('name')),
      containsAll(<String>['sessions_doc', 'sessions_open', 'book_stats_time']),
    );
    await db.close();
  });

  test('schema 2 to 3: the device row rescans for the new formats; data survives', () async {
    final AppDatabase db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          if (raw.userVersion != 0) return;
          for (final String stmt in File('test/core/fixtures/schema_v1.sql').readAsStringSync().split(';\n')) {
            final String sql = stmt.trim().replaceAll(RegExp(r';$'), '');
            if (sql.isNotEmpty && !sql.startsWith("CREATE TABLE 'entries_fts_")) raw.execute(sql);
          }
          // What schema 2's migration added.
          raw
            ..execute("ALTER TABLE folders ADD COLUMN source TEXT NOT NULL DEFAULT 'saf_folder'")
            ..execute("ALTER TABLE entries ADD COLUMN source TEXT NOT NULL DEFAULT 'saf_folder'")
            ..execute(
              'CREATE TABLE places (path TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, '
              'pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0, 1)), visited_at INTEGER NULL)',
            )
            ..execute(
              "INSERT INTO folders (uri, name, path, added_at, source) VALUES ('device://all', 'This device', 'gen:41', 1, 'device')",
            )
            ..execute(
              "INSERT INTO annotations (fingerprint, kind, color, locator, quote, created_at) VALUES ('fp9', 'bookmark', NULL, '{}', 'q', 1)",
            )
            ..userVersion = 2;
        },
      ),
    );
    final Folder device = (await db.select(db.folders).get()).single;
    expect((device.source, device.path), ('device', ''));
    expect((await db.select(db.annotations).get()).single.quote, 'q');
    await db
        .into(db.readingSessions)
        .insert(
          ReadingSessionsCompanion.insert(
            fingerprint: 'fp9',
            format: 'epub',
            mode: 'reader',
            startedAt: DateTime.utc(2026, 10, 4),
            endedAt: DateTime.utc(2026, 10, 4, 0, 5),
            day: 20261004,
          ),
        );
    expect((await db.select(db.readingSessions).get()).single.open, isTrue);
    await db.close();
  });
}
