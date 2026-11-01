import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:unfurl/core/reflow_cache.dart';
import 'package:unfurl/formats/reading_document.dart';

ReadingDocument _doc(String text) => ReadingDocument(
  title: 'Doc',
  sections: <Section>[
    Section(
      title: 'One',
      blocks: <Block>[
        Block(kind: BlockKind.paragraph, runs: <Inline>[Inline(text)]),
      ],
    ),
  ],
  resources: <String, Uint8List>{
    'img': Uint8List.fromList(<int>[0, 1, 255]),
  },
);

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('reflow_cache_test');
    ReflowCache.directoryOverride = dir;
  });

  tearDown(() {
    ReflowCache.directoryOverride = null;
    ReflowCache.capOverride = null;
    dir.deleteSync(recursive: true);
  });

  List<String> names() => <String>[for (final FileSystemEntity e in dir.listSync()) p.basename(e.path)]..sort();

  File file(String fp) =>
      dir.listSync().whereType<File>().firstWhere((File f) => p.basename(f.path).startsWith('$fp.'));

  test('a missing entry reads as null', () async {
    expect(await ReflowCache.read('fp', producer: 'pdf', version: 1), isNull);
  });

  test('write then read returns an equal document', () async {
    await ReflowCache.write('fp', _doc('hello world'), producer: 'pdf', version: 1);
    final ReadingDocument? back = await ReflowCache.read('fp', producer: 'pdf', version: 1);
    expect(back, isNotNull);
    expect(back!.plainText, 'hello world');
    expect(back.resources['img'], Uint8List.fromList(<int>[0, 1, 255]));
    expect(names().where((String n) => n.endsWith('.tmp')), isEmpty);
  });

  test('a different version or producer misses', () async {
    await ReflowCache.write('fp', _doc('a'), producer: 'pdf', version: 1);
    expect(await ReflowCache.read('fp', producer: 'pdf', version: 2), isNull);
    expect(await ReflowCache.read('fp', producer: 'epub', version: 1), isNull);
    expect(await ReflowCache.read('other', producer: 'pdf', version: 1), isNull);
  });

  test('writing version 2 removes the version 1 file', () async {
    await ReflowCache.write('fp', _doc('a'), producer: 'pdf', version: 1);
    await ReflowCache.write('fp', _doc('b'), producer: 'epub', version: 1);
    await ReflowCache.write('fp', _doc('c'), producer: 'pdf', version: 2);
    final List<String> left = names();
    expect(left.length, 2);
    expect(left.any((String n) => n.startsWith('fp.pdf.1.')), isFalse);
    expect(left.any((String n) => n.startsWith('fp.pdf.2.')), isTrue);
    expect(left.any((String n) => n.startsWith('fp.epub.1.')), isTrue);
  });

  test('a corrupt file reads as null and is deleted', () async {
    await ReflowCache.write('fp', _doc('a'), producer: 'pdf', version: 1);
    final File f = file('fp');
    final Random rnd = Random(3);
    f.writeAsBytesSync(List<int>.generate(200, (int _) => rnd.nextInt(256)));
    expect(await ReflowCache.read('fp', producer: 'pdf', version: 1), isNull);
    expect(f.existsSync(), isFalse);
  });

  test('remove deletes every entry for a fingerprint only', () async {
    await ReflowCache.write('fp', _doc('a'), producer: 'pdf', version: 1);
    await ReflowCache.write('fp', _doc('b'), producer: 'epub', version: 1);
    await ReflowCache.write('fp2', _doc('c'), producer: 'pdf', version: 1);
    await ReflowCache.remove('fp');
    final List<String> left = names();
    expect(left.length, 1);
    expect(left.single.startsWith('fp2.'), isTrue);
  });

  test('trimming drops the least recently used entry once over the cap', () async {
    await ReflowCache.write('a', _doc('x' * 100), producer: 'pdf', version: 1);
    await ReflowCache.write('b', _doc('y' * 100), producer: 'pdf', version: 1);
    await ReflowCache.write('c', _doc('z' * 100), producer: 'pdf', version: 1);
    final int size = file('a').lengthSync();
    final DateTime now = DateTime.now();
    file('a').setLastModifiedSync(now.subtract(const Duration(days: 3)));
    file('b').setLastModifiedSync(now.subtract(const Duration(days: 2)));
    file('c').setLastModifiedSync(now.subtract(const Duration(days: 1)));

    // Reading 'a' makes it the newest, so 'b' is now the oldest.
    expect(await ReflowCache.read('a', producer: 'pdf', version: 1), isNotNull);

    // Room for two entries: a fourth write is the newest, then 'a'.
    ReflowCache.capOverride = size * 2 + size ~/ 2;
    await ReflowCache.write('d', _doc('w' * 100), producer: 'pdf', version: 1);
    final List<String> left = names();
    expect(left.length, 2, reason: '$left');
    expect(left.any((String n) => n.startsWith('d.')), isTrue);
    expect(left.any((String n) => n.startsWith('a.')), isTrue);
  });

  test('trim removes stray old tmp files but not fresh ones', () async {
    final File old = File(p.join(dir.path, 'x.pdf.1.c1.bin.tmp'))..writeAsBytesSync(<int>[1]);
    old.setLastModifiedSync(DateTime.now().subtract(const Duration(minutes: 30)));
    final File fresh = File(p.join(dir.path, 'y.pdf.1.c1.bin.tmp'))..writeAsBytesSync(<int>[1]);
    await ReflowCache.write('fp', _doc('a'), producer: 'pdf', version: 1);
    expect(old.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
  });
}
