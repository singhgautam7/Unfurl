import 'dart:io';

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
}
