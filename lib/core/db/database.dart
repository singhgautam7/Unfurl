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

  /// How it was added (schema 2): `saf_folder` (a tree URI from Android's
  /// picker), `path_folder` (a path, picked in Files with all-files access) or
  /// `device` (the one hidden row that holds "Find books across this device").
  TextColumn get source => text().withDefault(const Constant('saf_folder'))();
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

  /// Pages (PDF, comics) or chapters (EPUB).
  IntColumn get units => integer().nullable()();

  /// A comic's issue or volume ("#14", "Vol. 2"), from its ComicInfo (schema 3).
  TextColumn get issue => text().nullable()();

  /// 0 never read, 1 metadata read, -1 unreadable, -2 protected (DRM),
  /// -3 a variant Unfurl can't read (Topaz, KFX, RAR 5).
  IntColumn get enriched => integer().withDefault(const Constant(0))();

  /// "Remove from library": hidden here; the file stays on the phone.
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  /// How it was found (schema 2): `saf_folder`, `path_folder` or `device`.
  TextColumn get source => text().withDefault(const Constant('saf_folder'))();

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

  /// A comic's issue or volume (schema 3).
  TextColumn get issue => text().nullable()();

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

/// Folders in the Files tab (schema 2): pinned ones and the recently opened.
class Places extends Table {
  TextColumn get path => text()();
  TextColumn get name => text()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get visitedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{path};
}

/// One reading session (schema 3, `ReadingSessionTracker`): time with a
/// document open, the screen on and the reader in front, keyed by
/// fingerprint. Written while it runs (checkpointed every 60 s); folded into
/// [DailyStats], [BookStats] and [BookDays] once, when it ends. Insights read
/// only those aggregates, never this table.
@TableIndex(name: 'sessions_doc', columns: <Symbol>{#fingerprint})
@TableIndex(name: 'sessions_open', columns: <Symbol>{#open})
class ReadingSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fingerprint => text()();

  /// Registry id ('epub', 'kindle', 'comics'...), for the formats breakdown.
  TextColumn get format => text()();

  /// 'reader', 'page' (PDF, DOCX pages, slides) or 'comics'.
  TextColumn get mode => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();

  /// The local date it started, as yyyymmdd.
  IntColumn get day => integer()();

  /// The local hour it started, for time of day.
  IntColumn get hour => integer().withDefault(const Constant(0))();
  IntColumn get activeMs => integer().withDefault(const Constant(0))();
  IntColumn get listeningMs => integer().withDefault(const Constant(0))();
  TextColumn get fromLocator => text().nullable()();
  TextColumn get toLocator => text().nullable()();

  /// Forward progress only: words read (Reader mode), unique pages (Page
  /// view, comics).
  IntColumn get words => integer().withDefault(const Constant(0))();
  IntColumn get pages => integer().withDefault(const Constant(0))();

  /// Still running: a crash leaves it open, and the next launch folds it in.
  BoolColumn get open => boolean().withDefault(const Constant(true))();
}

/// Reading per local day (yyyymmdd), kept incrementally: a year of Insights
/// is at most 366 rows.
class DailyStats extends Table {
  IntColumn get day => integer()();
  IntColumn get readingMs => integer().withDefault(const Constant(0))();
  IntColumn get listeningMs => integer().withDefault(const Constant(0))();
  IntColumn get words => integer().withDefault(const Constant(0))();
  IntColumn get pages => integer().withDefault(const Constant(0))();
  IntColumn get sessions => integer().withDefault(const Constant(0))();

  /// Time and progress per mode, for reading speed.
  IntColumn get readerMs => integer().withDefault(const Constant(0))();
  IntColumn get readerWords => integer().withDefault(const Constant(0))();
  IntColumn get pageMs => integer().withDefault(const Constant(0))();
  IntColumn get pagePages => integer().withDefault(const Constant(0))();

  /// The day's longest session and its book.
  IntColumn get longestMs => integer().withDefault(const Constant(0))();
  TextColumn get longestFp => text().nullable()();

  /// Reading ms per format id, as JSON.
  TextColumn get formatMs => text().withDefault(const Constant('{}'))();

  /// Reading ms per local hour, 24 comma-separated numbers.
  TextColumn get hourMs => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{day};
}

/// Totals per document (fingerprint), kept incrementally.
@TableIndex(name: 'book_stats_time', columns: <Symbol>{#readingMs})
class BookStats extends Table {
  TextColumn get fingerprint => text()();
  IntColumn get readingMs => integer().withDefault(const Constant(0))();
  IntColumn get listeningMs => integer().withDefault(const Constant(0))();
  IntColumn get sessions => integer().withDefault(const Constant(0))();
  IntColumn get words => integer().withDefault(const Constant(0))();
  IntColumn get pages => integer().withDefault(const Constant(0))();
  IntColumn get readerMs => integer().withDefault(const Constant(0))();
  IntColumn get readerWords => integer().withDefault(const Constant(0))();
  IntColumn get pageMs => integer().withDefault(const Constant(0))();
  IntColumn get pagePages => integer().withDefault(const Constant(0))();
  IntColumn get longestMs => integer().withDefault(const Constant(0))();

  /// A running median of time per page or screen, for the idle threshold.
  IntColumn get medianPageMs => integer().withDefault(const Constant(0))();

  /// Words in the book and words after the last place read (Reader mode),
  /// for "Estimated time left" (schema 4). Page and comic books use units.
  IntColumn get totalWords => integer().nullable()();
  IntColumn get wordsLeft => integer().nullable()();
  DateTimeColumn get firstRead => dateTime().nullable()();
  DateTimeColumn get lastRead => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{fingerprint};
}

/// Reading ms per document per day: book insights' 30-day chart.
class BookDays extends Table {
  TextColumn get fingerprint => text()();
  IntColumn get day => integer()();
  IntColumn get ms => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{fingerprint, day};
}

@DriftDatabase(
  tables: <Type>[
    Folders,
    Entries,
    Documents,
    Annotations,
    Recents,
    Places,
    ReadingSessions,
    DailyStats,
    BookStats,
    BookDays,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'unfurl'));

  /// Bump with a tested migration on every schema change (data rule 4).
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createSearch();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // v2: where folders and entries came from, and the Files tab's places.
        await m.addColumn(folders, folders.source);
        await m.addColumn(entries, entries.source);
        await m.createTable(places);
      }
      if (from < 3) {
        // v3: comic issues; reading sessions and the aggregates Insights read.
        await m.addColumn(entries, entries.issue);
        await m.addColumn(documents, documents.issue);
        await m.createTable(readingSessions);
        await m.createTable(dailyStats);
        await m.createTable(bookStats);
        await m.createTable(bookDays);
        await m.createIndex(sessionsDoc);
        await m.createIndex(sessionsOpen);
        await m.createIndex(bookStatsTime);
        // New book formats: device discovery runs again to find them, and
        // entries that failed as unknown get another look.
        await customStatement("UPDATE folders SET path = '' WHERE source = 'device'");
      } else if (from < 4) {
        // v3 builds before book word counts (schema 3 existed only on test devices).
        await m.addColumn(bookStats, bookStats.totalWords);
        await m.addColumn(bookStats, bookStats.wordsLeft);
      }
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
