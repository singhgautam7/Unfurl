import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/features/reader/engine/layout.dart';
import 'package:unfurl/formats/reading_document.dart';

Uint8List gif(int w, int h, {String tag = 'GIF89a'}) =>
    Uint8List.fromList(<int>[...tag.codeUnits, w & 255, w >> 8, h & 255, h >> 8, 0, 0, 0]);

Uint8List bmp(int w, int h) {
  final ByteData d = ByteData(54)
    ..setUint8(0, 0x42)
    ..setUint8(1, 0x4D)
    ..setInt32(18, w, Endian.little)
    ..setInt32(22, h, Endian.little);
  return d.buffer.asUint8List();
}

void main() {
  for (final String name in <String>['figure-1.png', 'Receipt_0412.jpg', 'harbour.webp']) {
    testWidgets('sniff reads $name as the engine decodes it', (WidgetTester tester) async {
      final Uint8List bytes = File('test/fixtures/$name').readAsBytesSync();
      final Size? sniffed = ImageSizes.sniff(bytes);
      expect(sniffed, isNotNull);
      final Size decoded = (await tester.runAsync<Size>(() async {
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo frame = await codec.getNextFrame();
        final Size s = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
        frame.image.dispose();
        codec.dispose();
        return s;
      }))!;
      expect(sniffed, decoded);
    });
  }

  test('sniff reads GIF and BMP headers', () {
    expect(ImageSizes.sniff(gif(300, 200)), const Size(300, 200));
    expect(ImageSizes.sniff(gif(7, 9, tag: 'GIF87a')), const Size(7, 9));
    expect(ImageSizes.sniff(bmp(640, 480)), const Size(640, 480));
    expect(ImageSizes.sniff(bmp(640, -480)), const Size(640, 480), reason: 'top-down BMP');
  });

  test('sniff reads WebP lossless and extended headers', () {
    // VP8L: 14-bit width-1 and height-1 packed little-endian after 0x2F.
    final ByteData l = ByteData(30)
      ..setUint32(0, 0x46464952, Endian.little) // RIFF
      ..setUint32(8, 0x50424557, Endian.little) // WEBP
      ..setUint32(12, 0x4C385056, Endian.little) // VP8L
      ..setUint8(20, 0x2F)
      ..setUint32(21, (123 - 1) | ((77 - 1) << 14), Endian.little);
    expect(ImageSizes.sniff(l.buffer.asUint8List()), const Size(123, 77));
    final ByteData x = ByteData(30)
      ..setUint32(0, 0x46464952, Endian.little)
      ..setUint32(8, 0x50424557, Endian.little)
      ..setUint32(12, 0x58385056, Endian.little) // VP8X
      ..setUint8(24, (1000 - 1) & 255)
      ..setUint8(25, (1000 - 1) >> 8)
      ..setUint8(27, (500 - 1) & 255)
      ..setUint8(28, (500 - 1) >> 8);
    expect(ImageSizes.sniff(x.buffer.asUint8List()), const Size(1000, 500));
  });

  test('sniff gives null for truncated, unknown and random bytes, and never throws', () {
    for (final String name in <String>['figure-1.png', 'Receipt_0412.jpg', 'harbour.webp']) {
      final Uint8List bytes = File('test/fixtures/$name').readAsBytesSync();
      expect(ImageSizes.sniff(bytes.sublist(0, 10)), isNull, reason: name);
      for (int n = 0; n < 40; n++) {
        ImageSizes.sniff(bytes.sublist(0, n));
      }
    }
    expect(ImageSizes.sniff(Uint8List(0)), isNull);
    expect(ImageSizes.sniff(Uint8List.fromList(List<int>.generate(64, (int i) => (i * 37 + 11) & 255))), isNull);
    expect(ImageSizes.sniff(Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0xFF, 0xFF])), isNull);
  });

  test('loadKnown reads headers at once; ImageSizes.of is one per document', () {
    final Uint8List png = File('test/fixtures/figure-1.png').readAsBytesSync();
    final ReadingDocument doc = ReadingDocument(
      title: 't',
      sections: <Section>[Section(title: '', blocks: <Block>[])],
    );
    expect(identical(ImageSizes.of(doc), ImageSizes.of(doc)), isTrue);
    final ImageSizes sizes = ImageSizes();
    expect(sizes.loadKnown(<String, Uint8List>{'a': png}, <String>['a']), isTrue);
    expect(sizes['a'], isNotNull);
    expect(sizes.loadKnown(<String, Uint8List>{'b': Uint8List(40)}, <String>['b']), isFalse);
    expect(sizes['b'], isNull);
  });
}
