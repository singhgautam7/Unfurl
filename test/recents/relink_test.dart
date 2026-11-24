import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/library/access.dart';
import 'package:unfurl/core/library/library.dart';
import 'package:unfurl/core/platform/platform.dart';

const String kOld = 'content://com.whatsapp.provider.media/item/7';
const String kNew =
    'content://com.android.externalstorage.documents/tree/primary%3ADocs/document/primary%3ADocs%2Fabc.pdf';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('unfurl/platform');
  late AppDatabase db;
  late Library lib;

  /// The Kotlin side: [readable] URIs answer stat, [probe] answers probeFile.
  void platform({Set<String> readable = const <String>{}, Map<String, Object?> probe = const <String, Object?>{}}) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        MethodCall c,
      ) async {
        final Map<Object?, Object?> a = (c.arguments as Map<Object?, Object?>?) ?? const <Object?, Object?>{};
        return switch (c.method) {
          'stat' when readable.contains(a['uri']) => <String, Object?>{'uri': a['uri'], 'name': 'abc.pdf', 'size': 9},
          'probeFile' => <String, Object?>{'sdk': 36, 'docId': a['docId'], ...probe},
          _ => null,
        };
      });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    lib = Library(db);
    platform();
    // Opened from WhatsApp, read to chapter 4, with a highlight and a note.
    const DocRef ref = DocRef(
      uri: kOld,
      name: 'abc.pdf',
      size: 9,
      source: FileSource(authority: 'com.whatsapp.provider.media', sender: 'WhatsApp', senderPackage: 'com.whatsapp'),
    );
    await lib.touch('fp1', ref);
    await lib.addRecent(ref, 'fp1');
    await lib.savePosition('fp1', locator: '{"s":3}', progress: 0.4, where: 'Chapter 4', mode: 'reader');
    await lib.addAnnotation(
      AnnotationsCompanion.insert(
        fingerprint: 'fp1',
        kind: 'highlight',
        locator: '{"q":"truth"}',
        quote: const Value<String>('truth'),
        note: const Value<String?>('a note'),
        createdAt: DateTime(2026),
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> expectKept() async {
    final Document d = (await lib.document('fp1'))!;
    expect((d.position, d.progress, d.where, d.mode), ('{"s":3}', 0.4, 'Chapter 4', 'reader'));
    final Annotation a = (await lib.watchAnnotations('fp1').first).single;
    expect((a.quote, a.note, a.locator), ('truth', 'a note', '{"q":"truth"}'));
  }

  test('relinking moves the Recents row and keeps the place, highlights and notes', () async {
    await lib.relink(kOld, const DocRef(uri: kNew, name: 'abc.pdf', size: 9), 'fp1');
    final Recent r = (await lib.watchRecents().first).single;
    expect((r.uri, r.fingerprint, r.sender), (kNew, 'fp1', 'WhatsApp'));
    expect((await lib.document('fp1'))!.uri, kNew);
    await expectKept();
  });

  test('opening it again from Recents keeps what is known of where it came from', () async {
    await lib.addRecent(const DocRef(uri: kOld, name: 'abc.pdf', size: 9), 'fp1');
    final Recent r = (await lib.recent(kOld))!;
    expect((r.sender, r.senderPackage, r.authority), ('WhatsApp', 'com.whatsapp', 'com.whatsapp.provider.media'));
  });

  test('Remove from Recents takes it off Home and Recents and keeps its data', () async {
    await lib.forgetRecent(kOld);
    expect(await lib.watchRecents().first, isEmpty);
    expect(await lib.watchOpened().first, isEmpty);
    await expectKept();
  });

  test('a WhatsApp file with no location is unknown and names the sender', () async {
    final (DocRef? found, AccessProblem? p) = await lib.locate(const DocRef(uri: kOld, name: 'abc.pdf'));
    expect(found, isNull);
    expect((p!.state, p.sender, p.canAllow, p.canShowFolder), (FileAccess.unknown, 'WhatsApp', false, false));
  });

  test('a known location: no access, then gone when Android says nothing is there', () async {
    platform(probe: <String, Object?>{'docId': 'primary:Docs/abc.pdf', 'exists': true, 'folderApp': true});
    final (_, AccessProblem? here) = await lib.locate(const DocRef(uri: kOld, name: 'abc.pdf'));
    expect((here!.state, here.canAllow, here.canShowFolder), (FileAccess.noAccess, true, true));
    platform(probe: <String, Object?>{'docId': 'primary:Docs/abc.pdf', 'exists': false});
    final (_, AccessProblem? gone) = await lib.locate(const DocRef(uri: kOld, name: 'abc.pdf'));
    expect(gone!.state, FileAccess.gone);
  });

  test('a folder already allowed that holds the file opens it, without asking', () async {
    platform(
      readable: <String>{kNew},
      probe: <String, Object?>{'docId': 'primary:Docs/abc.pdf', 'exists': true, 'covered': kNew},
    );
    final (DocRef? found, AccessProblem? p) = await lib.locate(const DocRef(uri: kOld, name: 'abc.pdf'));
    expect((found?.uri, p), (kNew, null));
  });
}
