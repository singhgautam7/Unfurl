import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/library/library.dart';
import 'package:unfurl/core/platform/platform.dart';

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

  test('pinning and visiting a folder update the Files lists live, without clobbering each other', () async {
    final Library lib = Library(db);
    final Stream<List<Place>> pinned = lib.watchPinned();
    final Future<void> sawPin = expectLater(
      pinned.map((List<Place> p) => p.map((Place x) => x.path).toList()),
      emitsThrough(<String>['/storage/emulated/0/Download']),
    );
    await lib.visit('/storage/emulated/0/Download', 'Download');
    await lib.setPinned('/storage/emulated/0/Download', 'Download', pinned: true);
    await sawPin;
    final Place p = (await lib.watchRecentPlaces().first).single;
    expect(p.pinned, isTrue);
    expect(p.visitedAt, isNotNull, reason: 'pinning keeps the visit');
  });

  test('one file reached through two apps is one recent', () async {
    final Library lib = Library(db);
    Future<void> opened(String uri, String fp, int minute) => db
        .into(db.recents)
        .insert(
          RecentsCompanion.insert(
            uri: uri,
            fingerprint: Value<String?>(fp),
            name: uri,
            openedAt: DateTime(2026, 10, 4, 1, minute),
          ),
        );
    await opened('content://a/1', 'fp1', 1);
    await opened('content://b/9', 'fp1', 2);
    await opened('content://a/2', 'fp2', 3);
    final List<Recent> r = await lib.watchRecents().first;
    expect(r.map((Recent x) => x.uri), <String>['content://a/2', 'content://b/9']);
  });

  test('an unreadable file leaves Home and Recents, unless it was read before', () async {
    final Library lib = Library(db);
    Future<void> open(String fp) async {
      final DocRef ref = DocRef(uri: 'content://x/$fp', name: '$fp.epub');
      await lib.touch(fp, ref);
      await lib.addRecent(ref, fp);
    }

    await open('drm');
    await open('read');
    await lib.savePosition('read', locator: '{}', progress: 0.2, where: 'Ch. 1', mode: 'reader');
    await lib.unreadable('drm');
    await lib.unreadable('read');
    expect(await lib.document('drm'), isNull);
    expect(await lib.document('read'), isNotNull);
    expect((await lib.watchRecents().first).map((Recent r) => r.fingerprint), <String>['read']);
  });
}
