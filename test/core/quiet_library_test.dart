// What the library writes and reads: a write to entries, documents or folders
// re-runs the queries behind Home and Library, so nothing is written that
// didn't change.
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/library/enrich.dart';
import 'package:unfurl/core/library/library.dart';
import 'package:unfurl/core/platform/platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Library lib;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    lib = Library(db);
  });
  tearDown(() => db.close());

  Future<int> folder() =>
      db.into(db.folders).insert(FoldersCompanion.insert(uri: 'content://tree/A', name: 'A', addedAt: DateTime(2026)));

  Future<void> entry(int folder, String name, {String parent = '', String? mime, String? fp}) => db
      .into(db.entries)
      .insert(
        EntriesCompanion.insert(
          folderId: folder,
          docId: '$parent/$name',
          uri: 'content://tree/A/$parent/$name',
          parent: parent,
          name: name,
          ext: name.contains('.') ? name.split('.').last : '',
          mime: Value<String?>(mime),
          isDir: false,
          fingerprint: Value<String?>(fp),
        ),
      );

  test('counts roll up from every directory to its parents', () async {
    final int f = await folder();
    await entry(f, 'a.pdf');
    await entry(f, 'b.zip');
    await entry(f, 'c.epub', parent: 'x/y');
    await entry(f, 'd.bin', parent: 'x/y');
    await entry(f, 'e.txt', parent: 'x');
    expect(await lib.countsUnder(f), <String, (int, int)>{'': (3, 5), 'x': (2, 3), 'x/y': (1, 2)});
  });

  test('opening a book again leaves the index alone', () async {
    final int f = await folder();
    await entry(f, 'a.pdf', fp: 'fp1');
    const DocRef ref = DocRef(uri: 'content://tree/A//a.pdf', name: 'a.pdf');
    int writes = 0;
    final sub = db.tableUpdates(TableUpdateQuery.onTable(db.entries)).listen((_) => writes++);
    await lib.touch('fp1', ref);
    await lib.touch('fp1', ref);
    await pumpEventQueue();
    expect(writes, 0);
    await lib.touch('fp2', ref); // its content changed
    await pumpEventQueue();
    expect(writes, 1);
    await sub.cancel();
  });

  test('closing a document tells the lists once; saving a place does not', () async {
    await lib.touch('fp1', const DocRef(uri: 'content://a', name: 'a.pdf'));
    await pumpEventQueue();
    int updates = 0;
    final sub = db.tableUpdates(TableUpdateQuery.onTable(db.documents)).listen((_) => updates++);
    await lib.savePosition('fp1', locator: '{}', progress: 0.5, where: 'p. 2', mode: 'page');
    await pumpEventQueue();
    expect(updates, 0);
    lib.documentsChanged();
    await pumpEventQueue();
    expect(updates, 1);
    await sub.cancel();
  });

  test('a resume right after a rescan checks the grants and walks nothing', () async {
    await folder();
    int walks = 0;
    bool granted = true;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('unfurl/platform'),
      (MethodCall c) async => c.method == 'persistedFolders' ? <String>[if (granted) 'content://tree/A'] : null,
    );
    messenger.setMockStreamHandler(
      const EventChannel('unfurl/scan'),
      MockStreamHandler.inline(
        onListen: (Object? args, MockStreamHandlerEventSink sink) {
          walks++;
          sink.endOfStream();
        },
      ),
    );
    await lib.refreshAll();
    await pumpEventQueue(times: 100);
    expect(walks, 1);
    await lib.refreshAll();
    await pumpEventQueue(times: 100);
    expect(walks, 1);
    granted = false;
    await lib.refreshAll();
    expect((await lib.watchFolders().first).single.accessLost, isTrue);
    granted = true;
    await lib.refreshAll();
    await pumpEventQueue(times: 100);
    expect((await lib.watchFolders().first).single.accessLost, isFalse);
    expect(walks, 2, reason: 'a folder that came back is walked at once');
    messenger.setMockMethodCallHandler(const MethodChannel('unfurl/platform'), null);
  });

  test('covers: an index read once, one notifier per cover, trimmed past the cap', () async {
    final Directory dir = Directory.systemTemp.createTempSync('covers');
    File('${dir.path}/old.img').writeAsBytesSync(List<int>.filled(10, 1));
    File('${dir.path}/none.img').createSync();
    Covers.directoryOverride = dir;
    final List<String> changes = <String>[];
    Covers.watch('new').addListener(() => changes.add('new'));
    Covers.watch('other').addListener(() => changes.add('other'));
    await Covers.dir();
    expect(Covers.fileFor('old'), isNotNull);
    expect((Covers.fileFor('none'), Covers.tried('none')), (null, true), reason: 'looked for, no art');
    expect(Covers.tried('new'), isFalse);
    await Covers.write('new', Uint8List(20));
    expect(Covers.watch('new').value?.path, endsWith('new.img'));
    expect(changes, <String>['new']);
    Covers.capOverride = 25;
    File('${dir.path}/old.img').setLastAccessedSync(DateTime(2020));
    await Covers.write('third', Uint8List(4));
    expect(Covers.tried('old'), isFalse, reason: 'the least recently used goes first');
    expect(Covers.fileFor('third'), isNotNull);
    Covers.capOverride = null;
  });
}
