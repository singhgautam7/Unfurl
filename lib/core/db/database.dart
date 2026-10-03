import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// A granted folder tree (read-only, persisted SAF grant).
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uri => text().unique()();
  TextColumn get name => text()();

  /// "Download › Darwin".
  TextColumn get path => text().withDefault(const Constant(''))();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get scannedAt => dateTime().nullable()();
  BoolColumn get accessLost => boolean().withDefault(const Constant(false))();
}

/// The library index: every file and directory under every granted folder.
@TableIndex(name: 'entries_parent', columns: <Symbol>{#folderId, #parent})
@TableIndex(name: 'entries_ext', columns: <Symbol>{#ext})
@TableIndex(name: 'entries_fp', columns: <Symbol>{#fingerprint})
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get folderId => integer().references(Folders, #id, onDelete: KeyAction.cascade)();
  TextColumn get docId => text()();
  TextColumn get uri => text()();

  /// Directory relative to the folder root, '' at the root.
  TextColumn get parent => text()();
  TextColumn get name => text()();
  TextColumn get ext => text()();
  TextColumn get mime => text().nullable()();
  BoolColumn get isDir => boolean()();
  IntColumn get size => integer().withDefault(const Constant(0))();
  IntColumn get modified => integer().withDefault(const Constant(0))();

  /// Filled when the file is first read (opened or enriched).
  TextColumn get fingerprint => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get author => text().nullable()();

  /// Pages (PDF) or chapters (EPUB).
  IntColumn get units => integer().nullable()();

  /// 0 never read, 1 metadata read, -1 unreadable.
  IntColumn get enriched => integer().withDefault(const Constant(0))();

  /// "Remove from library": hidden here; the file stays on the phone.
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{folderId, docId},
  ];
}

/// Everything Unfurl knows about a document, keyed by fingerprint (data
/// rule 2) so a moved or re-granted file keeps its place and notes.
class Documents extends Table {
  TextColumn get fingerprint => text()();

  /// Where it was last seen.
  TextColumn get uri => text()();
  TextColumn get name => text()();
  TextColumn get format => text()();
  TextColumn get title => text().nullable()();
  TextColumn get author => text().nullable()();

  /// The reading position, a `Locator` (data rule 3).
  TextColumn get position => text().nullable()();
  RealColumn get progress => real().withDefault(const Constant(0))();

  /// 'page' or 'reader': resume reopens in the mode last used.
  TextColumn get mode => text().nullable()();
  BoolColumn get finished => boolean().withDefault(const Constant(false))();
  IntColumn get units => integer().nullable()();

  /// Where the position sits, for display: "Chapter 34", "Page 207 of 502".
  TextColumn get where => text().nullable()();
  DateTimeColumn get openedAt => dateTime().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  /// Reading pace, for "6 min left in chapter".
  IntColumn get readMs => integer().withDefault(const Constant(0))();
  IntColumn get readWords => integer().withDefault(const Constant(0))();
  IntColumn get size => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{fingerprint};
}

/// Highlights, notes and bookmarks, anchored by `Locator`.
@TableIndex(name: 'annotations_doc', columns: <Symbol>{#fingerprint})
class Annotations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fingerprint => text()();

  /// 'highlight' or 'bookmark'. A highlight with [note] is a note.
  TextColumn get kind => text()();

  /// `HighlightColor` index.
  IntColumn get color => integer().nullable()();
  TextColumn get locator => text()();
  TextColumn get quote => text().withDefault(const Constant(''))();
  TextColumn get note => text().nullable()();

  /// "Ch. 34 · 62%", "p. 62".
  TextColumn get label => text().withDefault(const Constant(''))();
  RealColumn get progress => real().withDefault(const Constant(0))();

  /// The mode it was made in, so a tap reopens there.
  TextColumn get mode => text().withDefault(const Constant('reader'))();
  DateTimeColumn get createdAt => dateTime()();
}

/// Files opened directly (Open file, Open with), newest first.
class Recents extends Table {
  TextColumn get uri => text()();
  TextColumn get fingerprint => text().nullable()();
  TextColumn get name => text()();
  TextColumn get mime => text().nullable()();
  IntColumn get size => integer().withDefault(const Constant(0))();
  DateTimeColumn get openedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{uri};
}

@DriftDatabase(tables: <Type>[Folders, Entries, Documents, Annotations, Recents])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'unfurl'));

  /// Bump with a tested migration on every schema change (data rule 4).
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createSearch();
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// FTS5 over name, title and author, kept in step by triggers.
  Future<void> _createSearch() async {
    await customStatement(
      "CREATE VIRTUAL TABLE entries_fts USING fts5(name, title, author, content='entries', content_rowid='id', "
      "tokenize='unicode61 remove_diacritics 2')",
    );
    await customStatement(
      'CREATE TRIGGER entries_ai AFTER INSERT ON entries BEGIN '
      'INSERT INTO entries_fts(rowid, name, title, author) VALUES (new.id, new.name, new.title, new.author); END',
    );
    await customStatement(
      'CREATE TRIGGER entries_ad AFTER DELETE ON entries BEGIN '
      "INSERT INTO entries_fts(entries_fts, rowid, name, title, author) VALUES ('delete', old.id, old.name, old.title, old.author); END",
    );
    await customStatement(
      'CREATE TRIGGER entries_au AFTER UPDATE OF name, title, author ON entries BEGIN '
      "INSERT INTO entries_fts(entries_fts, rowid, name, title, author) VALUES ('delete', old.id, old.name, old.title, old.author); "
      'INSERT INTO entries_fts(rowid, name, title, author) VALUES (new.id, new.name, new.title, new.author); END',
    );
  }

  /// Entry ids matching every word of [query] as a prefix, best first.
  Future<List<int>> searchEntries(String query, {int limit = 200}) async {
    final List<String> tokens = query
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((String t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return const <int>[];
    final String match = tokens.map((String t) => '"$t"*').join(' ');
    final List<QueryRow> rows = await customSelect(
      'SELECT rowid FROM entries_fts WHERE entries_fts MATCH ? ORDER BY rank LIMIT ?',
      variables: <Variable<Object>>[Variable<String>(match), Variable<int>(limit)],
      readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{entries},
    ).get();
    return rows.map((QueryRow r) => r.read<int>('rowid')).toList();
  }
}
