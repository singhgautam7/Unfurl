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
    expect(db.schemaVersion, 5);
    final Annotation a = (await db.select(db.annotations).get()).single;
    expect((a.quote, a.note), ('truth', 'a note'));
    final Document d = (await db.select(db.documents).get()).single;
    expect((d.position, d.progress, d.issue), ('{"s":3}', 0.4, null));
    expect((await db.select(db.entries).get()).single.issue, isNull);
    // The aggregates Insights reads, and their indexes.
    await db.into(db.dailyStats).insert(DailyStatsCompanion.insert(day: const Value<int>(20261004)));
    await db
        .into(db.bookStats)
        .insert(
          BookStatsCompanion.insert(
            fingerprint: 'fp1',
            totalWords: const Value<int?>(1000),
            wordsLeft: const Value<int?>(400),
          ),
        );
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

  test('schema 3 to 4: book word counts are added; sessions and stats survive', () async {
    final File f = File('${Directory.systemTemp.createTempSync('unfurl').path}/v3.db');
    final AppDatabase v3 = AppDatabase(NativeDatabase(f));
    await v3.into(v3.bookStats).insert(BookStatsCompanion.insert(fingerprint: 'fp', readingMs: const Value<int>(5000)));
    await v3.customStatement('ALTER TABLE book_stats DROP COLUMN total_words');
    await v3.customStatement('ALTER TABLE book_stats DROP COLUMN words_left');
    for (final String column in <String>['authority', 'doc_id', 'sender', 'sender_package', 'persisted']) {
      await v3.customStatement('ALTER TABLE recents DROP COLUMN $column');
    }
    await v3.customStatement('DROP INDEX recents_fp');
    await v3.customStatement('PRAGMA user_version = 3');
    await v3.close();
    final AppDatabase db = AppDatabase(NativeDatabase(f));
    final BookStat b = (await db.select(db.bookStats).get()).single;
    expect((b.readingMs, b.totalWords), (5000, null));
    await db.close();
  });

  test('schema 4 to 5: recents learn where they came from; rows, places and highlights survive', () async {
    final File f = File('${Directory.systemTemp.createTempSync('unfurl').path}/v4.db');
    final AppDatabase v4 = AppDatabase(NativeDatabase(f));
    await v4
        .into(v4.recents)
        .insert(
          RecentsCompanion.insert(
            uri: 'content://a/1',
            fingerprint: const Value<String?>('fp'),
            name: 'abc.pdf',
            openedAt: DateTime(2026),
          ),
        );
    await v4
        .into(v4.documents)
        .insert(
          DocumentsCompanion.insert(
            fingerprint: 'fp',
            uri: 'content://a/1',
            name: 'abc.pdf',
            format: 'pdf',
            position: const Value<String?>('{"s":1}'),
            addedAt: DateTime(2026),
          ),
        );
    await v4
        .into(v4.annotations)
        .insert(
          AnnotationsCompanion.insert(
            fingerprint: 'fp',
            kind: 'highlight',
            locator: '{}',
            quote: const Value<String>('kept'),
            createdAt: DateTime(2026),
          ),
        );
    for (final String column in <String>['authority', 'doc_id', 'sender', 'sender_package', 'persisted']) {
      await v4.customStatement('ALTER TABLE recents DROP COLUMN $column');
    }
    await v4.customStatement('DROP INDEX recents_fp');
    await v4.customStatement('PRAGMA user_version = 4');
    await v4.close();
    final AppDatabase db = AppDatabase(NativeDatabase(f));
    final Recent r = (await db.select(db.recents).get()).single;
    expect((r.uri, r.fingerprint, r.docId, r.sender, r.persisted), ('content://a/1', 'fp', null, null, false));
    expect((await db.select(db.documents).get()).single.position, '{"s":1}');
    expect((await db.select(db.annotations).get()).single.quote, 'kept');
    await (db.update(db.recents)).write(const RecentsCompanion(docId: Value<String?>('primary:Docs/abc.pdf')));
    expect((await db.select(db.recents).get()).single.docId, 'primary:Docs/abc.pdf');
    await db.close();
  });
}
