import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../formats/format_registry.dart';
import '../db/database.dart';
import '../platform/platform.dart';

/// A book (PDF or EPUB) in the Library, with what Unfurl knows of it.
@immutable
class BookItem {
  const BookItem({required this.entry, required this.folder, this.doc});

  final Entry entry;
  final Folder folder;
  final Document? doc;

  String get title => doc?.title ?? entry.title ?? _stem(entry.name);
  String? get author => doc?.author ?? entry.author;
  double get progress => doc?.progress ?? 0;
  bool get finished => doc?.finished ?? false;
  bool get unread => !finished && progress <= 0;
  String? get fingerprint => entry.fingerprint ?? doc?.fingerprint;
  FormatModule get format => Formats.of(entry.name, entry.mime) ?? Formats.pdf;

  /// "Books › Austen": the folder, then the subfolders down to the file.
  String get path => <String>[folder.name, if (entry.parent.isNotEmpty) ...entry.parent.split('/')].join(' › ');

  DocRef get ref =>
      DocRef(uri: entry.uri, name: entry.name, size: entry.size, modified: entry.modified, mime: entry.mime);

  static String _stem(String name) {
    final int dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }
}

enum LibrarySort { recent, title, progress }

/// "1 readable file", "16 readable files".
String readableFiles(int n) => n == 1 ? '1 readable file' : '$n readable files';

/// A subfolder row: name and how many readable files sit at or below it.
@immutable
class SubfolderInfo {
  const SubfolderInfo({required this.name, required this.path, required this.readable, required this.total});

  final String name;

  /// Relative path from the granted root.
  final String path;
  final int readable;
  final int total;
}

/// The scan in progress, for the folder screen's "Scanning" card.
@immutable
class ScanState {
  const ScanState({required this.folderId, required this.found, required this.expected});

  final int folderId;
  final int found;

  /// The last scan's count, so the card can say "of about 600".
  final int expected;
}

/// Folders, the index, documents, annotations and recents. The only writer
/// of the database; nothing here ever writes to a user's file.
class Library {
  Library(this.db);

  final AppDatabase db;

  /// Folder id to an in-flight scan.
  final ValueNotifier<Map<int, ScanState>> scans = ValueNotifier<Map<int, ScanState>>(const <int, ScanState>{});
  final Map<int, StreamSubscription<List<ScannedEntry>>> _running = <int, StreamSubscription<List<ScannedEntry>>>{};
  final Map<int, Completer<void>> _finishing = <int, Completer<void>>{};

  /// The platform walks one folder at a time (one scan channel), so scans
  /// queue; a folder already waiting isn't queued twice.
  final Set<int> _queued = <int>{};
  Future<void> _queue = Future<void>.value();

  /// Called after each folder scan finishes, for metadata and covers.
  VoidCallback? onScanned;

  static const List<String> bookExts = <String>['pdf', 'epub'];

  // ---------------------------------------------------------------- folders

  Stream<List<Folder>> watchFolders() =>
      (db.select(db.folders)..orderBy(<OrderClauseGenerator<$FoldersTable>>[(f) => OrderingTerm.asc(f.name)])).watch();

  Future<Folder?> folder(int id) => (db.select(db.folders)..where((f) => f.id.equals(id))).getSingleOrNull();

  /// Adds a picked folder (or re-grants one already known) and scans it.
  Future<Folder> addFolder(PickedFolder picked) async {
    final Folder? existing = await (db.select(db.folders)..where((f) => f.uri.equals(picked.uri))).getSingleOrNull();
    final int id;
    if (existing != null) {
      id = existing.id;
      await (db.update(
        db.folders,
      )..where((f) => f.id.equals(id))).write(const FoldersCompanion(accessLost: Value<bool>(false)));
    } else {
      id = await db
          .into(db.folders)
          .insert(
            FoldersCompanion.insert(
              uri: picked.uri,
              name: picked.name,
              path: Value<String>(picked.path),
              addedAt: DateTime.now(),
            ),
          );
    }
    unawaited(scan(id));
    return (await folder(id))!;
  }

  /// Remove access: the grant is released and the folder leaves the index;
  /// documents keep their positions and notes (keyed by fingerprint).
  Future<void> removeFolder(Folder f) async {
    await _running.remove(f.id)?.cancel();
    final Completer<void>? finishing = _finishing.remove(f.id);
    if (finishing != null && !finishing.isCompleted) finishing.complete();
    await Platform.releaseFolder(f.uri);
    await (db.delete(db.folders)..where((x) => x.id.equals(f.id))).go();
  }

  /// Folders on their way out: hidden at once, released when the undo
  /// window closes.
  final ValueNotifier<Set<int>> removing = ValueNotifier<Set<int>>(const <int>{});
  final Map<int, Timer> _removeTimers = <int, Timer>{};

  /// The x on a folder: gone from the list now, access released after
  /// [delay] unless [undoRemove] comes first.
  void removeWithUndo(Folder f, {Duration delay = const Duration(seconds: 5)}) {
    removing.value = <int>{...removing.value, f.id};
    _removeTimers[f.id] = Timer(delay, () async {
      _removeTimers.remove(f.id);
      await removeFolder(f);
      removing.value = <int>{...removing.value}..remove(f.id);
    });
  }

  void undoRemove(int id) {
    _removeTimers.remove(id)?.cancel();
    removing.value = <int>{...removing.value}..remove(id);
  }

  /// Marks folders whose grant Android removed, and rescans the rest.
  Future<void> refreshAll() async {
    final List<String> granted = await Platform.persistedFolders();
    for (final Folder f in await db.select(db.folders).get()) {
      final bool lost = granted.isNotEmpty || !kIsWeb ? !granted.contains(f.uri) : false;
      if (lost != f.accessLost) {
        await (db.update(
          db.folders,
        )..where((x) => x.id.equals(f.id))).write(FoldersCompanion(accessLost: Value<bool>(lost)));
      }
      if (!lost) unawaited(scan(f.id));
    }
  }

  /// Walks the folder on the platform side and folds the batches into the
  /// index as they arrive: new rows in, changed rows updated (their
  /// fingerprint cleared if size or time moved), missing rows out.
  Future<void> scan(int folderId) {
    if (!_queued.add(folderId)) return _queue;
    return _queue = _queue
        .then((_) => _scan(folderId))
        .catchError((Object _) {})
        .whenComplete(() => _queued.remove(folderId));
  }

  Future<void> _scan(int folderId) async {
    final Folder? f = await folder(folderId);
    if (f == null) return;
    final int previous = await _count(folderId);
    final Map<String, Entry> known = <String, Entry>{
      for (final Entry e in await (db.select(db.entries)..where((x) => x.folderId.equals(folderId))).get()) e.docId: e,
    };
    final Set<String> seen = <String>{};
    final Completer<void> done = _finishing[folderId] = Completer<void>();
    int found = 0;
    _setScan(folderId, ScanState(folderId: folderId, found: 0, expected: previous));
    // Batches are written in arrival order; the end of the walk waits for
    // the last write before pruning what wasn't seen.
    Future<void> writes = Future<void>.value();
    _running[folderId] = Platform.scan(f.uri).listen(
      (List<ScannedEntry> batch) {
        found += batch.length;
        _setScan(folderId, ScanState(folderId: folderId, found: found, expected: previous));
        for (final ScannedEntry s in batch) {
          seen.add(s.docId);
        }
        writes = writes.then(
          (_) => db.batch((Batch b) {
            for (final ScannedEntry s in batch) {
              final Entry? old = known[s.docId];
              final int dot = s.name.lastIndexOf('.');
              final String ext = s.isDir || dot < 0 ? '' : s.name.substring(dot + 1).toLowerCase();
              if (old == null) {
                b.insert(
                  db.entries,
                  EntriesCompanion.insert(
                    folderId: folderId,
                    docId: s.docId,
                    uri: s.uri,
                    parent: s.parent,
                    name: s.name,
                    ext: ext,
                    mime: Value<String?>(s.mime),
                    isDir: s.isDir,
                    size: Value<int>(s.size),
                    modified: Value<int>(s.modified),
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
              } else if (old.size != s.size ||
                  old.modified != s.modified ||
                  old.name != s.name ||
                  old.parent != s.parent) {
                final bool contentChanged = old.size != s.size || old.modified != s.modified;
                b.update(
                  db.entries,
                  EntriesCompanion(
                    uri: Value<String>(s.uri),
                    parent: Value<String>(s.parent),
                    name: Value<String>(s.name),
                    ext: Value<String>(ext),
                    size: Value<int>(s.size),
                    modified: Value<int>(s.modified),
                    fingerprint: contentChanged ? const Value<String?>(null) : Value<String?>(old.fingerprint),
                    enriched: contentChanged ? const Value<int>(0) : Value<int>(old.enriched),
                  ),
                  where: ($EntriesTable x) => x.id.equals(old.id),
                );
              }
            }
          }),
        );
      },
      onError: (Object e) async {
        await writes;
        await (db.update(
          db.folders,
        )..where((x) => x.id.equals(folderId))).write(const FoldersCompanion(accessLost: Value<bool>(true)));
        if (!done.isCompleted) done.complete();
      },
      onDone: () async {
        await writes;
        final List<int> gone = <int>[
          for (final Entry e in known.values)
            if (!seen.contains(e.docId)) e.id,
        ];
        if (gone.isNotEmpty) await (db.delete(db.entries)..where((x) => x.id.isIn(gone))).go();
        await (db.update(
          db.folders,
        )..where((x) => x.id.equals(folderId))).write(FoldersCompanion(scannedAt: Value<DateTime?>(DateTime.now())));
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    await done.future;
    _running.remove(folderId);
    _finishing.remove(folderId);
    final Map<int, ScanState> next = Map<int, ScanState>.of(scans.value)..remove(folderId);
    scans.value = next;
    onScanned?.call();
  }

  void _setScan(int id, ScanState s) => scans.value = <int, ScanState>{...scans.value, id: s};

  Future<int> _count(int folderId) async {
    final Expression<int> n = db.entries.id.count();
    final TypedResult r =
        await (db.selectOnly(db.entries)
              ..addColumns(<Expression<Object>>[n])
              ..where(db.entries.folderId.equals(folderId)))
            .getSingle();
    return r.read(n) ?? 0;
  }

  // ---------------------------------------------------------------- browse

  /// Readable files (a format Unfurl opens) per folder, for the folder row.
  Stream<Map<int, int>> watchReadableCounts() {
    final Expression<int> n = db.entries.id.count();
    final List<String> exts = <String>[for (final FormatModule m in Formats.all) ...m.extensions];
    return (db.selectOnly(db.entries)
          ..addColumns(<Expression<Object>>[db.entries.folderId, n])
          ..where(db.entries.isDir.equals(false) & db.entries.ext.isIn(exts))
          ..groupBy(<Expression<Object>>[db.entries.folderId]))
        .watch()
        .map(
          (List<TypedResult> rows) => <int, int>{
            for (final TypedResult r in rows) r.read(db.entries.folderId)!: r.read(n) ?? 0,
          },
        );
  }

  /// Every book in every folder, with its document.
  Stream<List<BookItem>> watchBooks() {
    final JoinedSelectStatement<HasResultSet, dynamic> q = db.select(db.entries).join(<Join<HasResultSet, dynamic>>[
      innerJoin(db.folders, db.folders.id.equalsExp(db.entries.folderId)),
      leftOuterJoin(db.documents, db.documents.fingerprint.equalsExp(db.entries.fingerprint)),
    ])..where(db.entries.isDir.equals(false) & db.entries.hidden.equals(false) & db.entries.ext.isIn(bookExts));
    return q.watch().map(
      (List<TypedResult> rows) => <BookItem>[
        for (final TypedResult r in rows)
          BookItem(
            entry: r.readTable(db.entries),
            folder: r.readTable(db.folders),
            doc: r.readTableOrNull(db.documents),
          ),
      ],
    );
  }

  /// The ids of entries matching a search (FTS5).
  Future<Set<int>> search(String query) async => (await db.searchEntries(query)).toSet();

  /// One level of a folder: its entries (files and directories), with docs.
  Stream<List<(Entry, Document?)>> watchLevel(int folderId, String parent, {bool deep = false}) {
    final Expression<bool> where = deep
        ? db.entries.folderId.equals(folderId) &
              db.entries.isDir.equals(false) &
              (parent.isEmpty
                  ? const Constant<bool>(true)
                  : (db.entries.parent.equals(parent) | db.entries.parent.like('$parent/%')))
        : db.entries.folderId.equals(folderId) & db.entries.parent.equals(parent);
    final JoinedSelectStatement<HasResultSet, dynamic> q = db.select(db.entries).join(<Join<HasResultSet, dynamic>>[
      leftOuterJoin(db.documents, db.documents.fingerprint.equalsExp(db.entries.fingerprint)),
    ])..where(where);
    return q.watch().map(
      (List<TypedResult> rows) => <(Entry, Document?)>[
        for (final TypedResult r in rows) (r.readTable(db.entries), r.readTableOrNull(db.documents)),
      ],
    );
  }

  /// Readable and total file counts under each directory of a folder.
  Future<Map<String, (int, int)>> countsUnder(int folderId) async {
    final List<Entry> files = await (db.select(
      db.entries,
    )..where((x) => x.folderId.equals(folderId) & x.isDir.equals(false))).get();
    final Map<String, (int, int)> out = <String, (int, int)>{};
    for (final Entry e in files) {
      final bool readable = Formats.of(e.name, e.mime) != null;
      String dir = e.parent;
      while (true) {
        final (int r, int t) = out[dir] ?? (0, 0);
        out[dir] = (r + (readable ? 1 : 0), t + 1);
        if (dir.isEmpty) break;
        final int slash = dir.lastIndexOf('/');
        dir = slash < 0 ? '' : dir.substring(0, slash);
      }
    }
    return out;
  }

  Future<void> setHidden(int entryId, {required bool hidden}) =>
      (db.update(db.entries)..where((x) => x.id.equals(entryId))).write(EntriesCompanion(hidden: Value<bool>(hidden)));

  // ---------------------------------------------------------------- documents

  Future<Document?> document(String fingerprint) =>
      (db.select(db.documents)..where((d) => d.fingerprint.equals(fingerprint))).getSingleOrNull();

  Stream<Document?> watchDocument(String fingerprint) =>
      (db.select(db.documents)..where((d) => d.fingerprint.equals(fingerprint))).watchSingleOrNull();

  /// Called on open: records the document (keyed by fingerprint), its last
  /// known location, and ties every index row with that fingerprint to it.
  Future<Document> touch(String fingerprint, DocRef ref, {String? title, String? author, int? units}) async {
    final FormatModule? m = Formats.ofRef(ref);
    final Document? d = await document(fingerprint);
    // A book the library already read keeps its own title and author.
    if (title == null && d?.title == null) {
      final Entry? e =
          await (db.select(db.entries)
                ..where((x) => x.fingerprint.equals(fingerprint) & x.title.isNotNull())
                ..limit(1))
              .getSingleOrNull();
      title = e?.title;
      author ??= e?.author;
    }
    final DateTime now = DateTime.now();
    if (d == null) {
      await db
          .into(db.documents)
          .insert(
            DocumentsCompanion.insert(
              fingerprint: fingerprint,
              uri: ref.uri,
              name: ref.name,
              format: m?.id ?? ref.extension,
              title: Value<String?>(title),
              author: Value<String?>(author),
              units: Value<int?>(units),
              openedAt: Value<DateTime?>(now),
              addedAt: now,
              size: Value<int>(ref.size),
            ),
          );
    } else {
      await (db.update(db.documents)..where((x) => x.fingerprint.equals(fingerprint))).write(
        DocumentsCompanion(
          uri: Value<String>(ref.uri),
          name: Value<String>(ref.name),
          openedAt: Value<DateTime?>(now),
          title: title == null ? const Value<String?>.absent() : Value<String?>(title),
          author: author == null ? const Value<String?>.absent() : Value<String?>(author),
          units: units == null ? const Value<int?>.absent() : Value<int?>(units),
        ),
      );
    }
    await (db.update(
      db.entries,
    )..where((x) => x.uri.equals(ref.uri))).write(EntriesCompanion(fingerprint: Value<String?>(fingerprint)));
    return (await document(fingerprint))!;
  }

  /// Saved debounced while reading and on pause, as a `Locator`.
  Future<void> savePosition(
    String fingerprint, {
    required String locator,
    required double progress,
    required String where,
    required String mode,
    int? readMs,
    int? readWords,
  }) => db.customStatement(
    'UPDATE documents SET position = ?, progress = ?, "where" = ?, mode = ?, read_ms = read_ms + ?, read_words = read_words + ?, '
    'finished = CASE WHEN ? >= 0.999 THEN 1 ELSE finished END WHERE fingerprint = ?',
    <Object?>[locator, progress, where, mode, readMs ?? 0, readWords ?? 0, progress, fingerprint],
  );

  Future<void> setFinished(String fingerprint, {required bool finished}) =>
      (db.update(db.documents)..where((d) => d.fingerprint.equals(fingerprint))).write(
        DocumentsCompanion(
          finished: Value<bool>(finished),
          progress: finished ? const Value<double>(1) : const Value<double>.absent(),
        ),
      );

  /// Documents opened before, newest first: Continue reading and the recent
  /// books row.
  Stream<List<Document>> watchOpened() =>
      (db.select(db.documents)
            ..where((d) => d.openedAt.isNotNull())
            ..orderBy(<OrderClauseGenerator<$DocumentsTable>>[(d) => OrderingTerm.desc(d.openedAt)]))
          .watch();

  // ---------------------------------------------------------------- recents

  Future<void> addRecent(DocRef ref, String? fingerprint) => db
      .into(db.recents)
      .insertOnConflictUpdate(
        RecentsCompanion.insert(
          uri: ref.uri,
          fingerprint: Value<String?>(fingerprint),
          name: ref.name,
          mime: Value<String?>(ref.mime),
          size: Value<int>(ref.size),
          openedAt: DateTime.now(),
        ),
      );

  Stream<List<Recent>> watchRecents() =>
      (db.select(db.recents)
            ..orderBy(<OrderClauseGenerator<$RecentsTable>>[(r) => OrderingTerm.desc(r.openedAt)])
            ..limit(30))
          .watch();

  Future<void> removeRecent(String uri) => (db.delete(db.recents)..where((r) => r.uri.equals(uri))).go();

  Future<void> clearRecents() async {
    await db.delete(db.recents).go();
    await db.update(db.documents).write(const DocumentsCompanion(openedAt: Value<DateTime?>(null)));
  }

  // ---------------------------------------------------------------- annotations

  Stream<List<Annotation>> watchAnnotations(String fingerprint) =>
      (db.select(db.annotations)
            ..where((a) => a.fingerprint.equals(fingerprint))
            ..orderBy(<OrderClauseGenerator<$AnnotationsTable>>[(a) => OrderingTerm.asc(a.progress)]))
          .watch();

  /// Every annotation with its document, newest first (the Notes tab).
  Stream<List<(Annotation, Document?)>> watchAllAnnotations() {
    final JoinedSelectStatement<HasResultSet, dynamic> q = db.select(db.annotations).join(<Join<HasResultSet, dynamic>>[
      leftOuterJoin(db.documents, db.documents.fingerprint.equalsExp(db.annotations.fingerprint)),
    ])..orderBy(<OrderingTerm>[OrderingTerm.desc(db.annotations.createdAt)]);
    return q.watch().map(
      (List<TypedResult> rows) => <(Annotation, Document?)>[
        for (final TypedResult r in rows) (r.readTable(db.annotations), r.readTableOrNull(db.documents)),
      ],
    );
  }

  Future<int> addAnnotation(AnnotationsCompanion a) => db.into(db.annotations).insert(a);

  Future<void> updateAnnotation(int id, {int? color, String? note, bool clearNote = false}) =>
      (db.update(db.annotations)..where((a) => a.id.equals(id))).write(
        AnnotationsCompanion(
          color: color == null ? const Value<int?>.absent() : Value<int?>(color),
          note: clearNote
              ? const Value<String?>(null)
              : (note == null ? const Value<String?>.absent() : Value<String?>(note)),
        ),
      );

  Future<void> deleteAnnotation(int id) => (db.delete(db.annotations)..where((a) => a.id.equals(id))).go();

  Future<void> restoreAnnotation(Annotation a) => db.into(db.annotations).insertOnConflictUpdate(a);
}
