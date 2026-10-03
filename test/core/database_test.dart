import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/db/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('the schema creates, and library search finds titles through FTS', () async {
    final int folder = await db
        .into(db.folders)
        .insert(FoldersCompanion.insert(uri: 'content://t', name: 'Books', addedAt: DateTime(2026)));
    final int id = await db
        .into(db.entries)
        .insert(
          EntriesCompanion.insert(
            folderId: folder,
            docId: 'd1',
            uri: 'content://t/d1',
            parent: 'Austen',
            name: 'pride-and-prejudice.epub',
            ext: 'epub',
            isDir: false,
            title: const Value<String?>('Pride and Prejudice'),
            author: const Value<String?>('Jane Austen'),
          ),
        );
    expect(await db.searchEntries('prejud'), <int>[id]);
    expect(await db.searchEntries('austen'), <int>[id], reason: 'authors are searchable');
    expect(await db.searchEntries('darwin'), isEmpty);
  });
}
