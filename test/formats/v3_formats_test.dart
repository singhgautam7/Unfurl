import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/formats/books.dart';
import 'package:unfurl/formats/comics/comic_archive.dart';
import 'package:unfurl/formats/epub/epub.dart';
import 'package:unfurl/formats/format_problem.dart';
import 'package:unfurl/formats/format_registry.dart';
import 'package:unfurl/formats/reading_document.dart';

Uint8List fixture(String name) => File('test/fixtures/$name').readAsBytesSync();

Matcher problem(ProblemKind kind) => throwsA(isA<FormatProblem>().having((FormatProblem p) => p.kind, 'kind', kind));

void main() {
  group('Kindle', () {
    test('MOBI 6 (PalmDOC): title, author, chapters and contents', () {
      final Uint8List b = fixture('yellow-wallpaper.mobi');
      final BookMeta meta = Books.meta('kindle', b, 'yellow-wallpaper.mobi');
      expect(meta.title, contains('Yellow Wallpaper'));
      expect(meta.author, contains('Gilman'));
      final ReadingDocument d = Books.document('kindle', b, 'yellow-wallpaper.mobi');
      expect(d.plainText, contains('It is very seldom that mere ordinary people like John and myself'));
      expect(d.sections.length, greaterThan(1));
      expect(d.plainText, isNot(contains('<')));
    });

    test('AZW3 (KF8): skeletons and fragments reassemble into readable text', () {
      final Uint8List b = fixture('yellow-wallpaper.azw3');
      final ReadingDocument d = Books.document('kindle', b, 'yellow-wallpaper.azw3');
      expect(d.title, contains('Yellow Wallpaper'));
      expect(d.plainText, contains('It is very seldom that mere ordinary people like John and myself'));
      expect(d.plainText, isNot(contains('aid=')));
      expect(d.toc, isNotEmpty);
      // Each contents entry lands inside the book.
      for (final TocEntry t in d.toc) {
        expect(t.section, lessThan(d.sections.length));
      }
      expect(Books.meta('kindle', b, 'x.azw3').cover, isNotNull);
    });

    test('a MOBI with the encryption flag set is protected', () {
      expect(() => Books.document('kindle', fixture('drm-sample.azw'), 'drm-sample.azw'), problem(ProblemKind.drm));
    });
  });

  group('FB2', () {
    test('Windows-1251 FB2: author, title, sections, notes, cover', () {
      final Uint8List b = fixture('onegin.fb2');
      final BookMeta meta = Books.meta('fb2', b, 'onegin.fb2');
      expect(meta.title, 'Евгений Онегин');
      expect(meta.author, 'Александр Пушкин');
      expect(meta.cover, isNotNull);
      final ReadingDocument d = Books.document('fb2', b, 'onegin.fb2');
      expect(d.sections.map((Section s) => s.title), containsAll(<String>['Глава первая', 'Глава вторая', '1']));
      expect(d.plainText, contains('Мой дядя самых честных правил'));
      expect(d.anchors['n1'], isNotNull);
      final Block verse = d.sections.expand((Section s) => s.blocks).firstWhere((Block b) => b.text.startsWith('Мой'));
      expect(verse.kind, BlockKind.quote);
    });

    test('FBZ: the FB2 inside the zip', () {
      final ReadingDocument d = Books.document('fb2', fixture('walden.fbz'), 'walden.fbz');
      expect(d.title, 'Walden');
      expect(d.author, 'Henry David Thoreau');
      expect(d.plainText, contains('Simplify, simplify.'));
    });
  });

  test('HTML: tag soup repaired, scripts and styles dropped, data images kept', () {
    final ReadingDocument d = Books.document('html', fixture('walden.html'), 'walden.html');
    expect(d.title, 'Walden');
    expect(d.author, 'Henry David Thoreau');
    expect(d.plainText, isNot(contains('tracking')));
    expect(d.plainText, isNot(contains('color: red')));
    final List<Block> blocks = d.sections.single.blocks;
    expect(blocks.where((Block b) => b.kind == BlockKind.listItem).map((Block b) => b.text), <String>[
      'Shelter',
      'Food',
      'Fuel',
    ]);
    expect(blocks.where((Block b) => b.kind == BlockKind.image), hasLength(1));
    expect(d.resources, hasLength(1));
    expect(d.anchors['economy'], isNotNull);
    expect(d.toc.map((TocEntry t) => t.title), containsAll(<String>['Economy', 'Where I Lived']));
  });

  group('DRM', () {
    test('EPUB with real encryption is protected; font obfuscation still opens', () {
      expect(() => Epub.open(fixture('drm-sample.epub')), problem(ProblemKind.drm));
      expect(Epub.open(fixture('font-obfuscated.epub')).document().plainText, contains('truth universally'));
    });
  });

  group('magic bytes', () {
    Uint8List head(String name) {
      final Uint8List b = fixture(name);
      return Uint8List.sublistView(b, 0, b.length < 512 ? b.length : 512);
    }

    test('Kindle variants', () {
      expect(Formats.sniff(head('yellow-wallpaper.mobi'), Formats.kindle), Formats.kindle);
      expect(Formats.sniff(head('yellow-wallpaper.azw3'), Formats.kindle), Formats.kindle);
      expect(() => Formats.sniff(head('kfx-sample.azw'), Formats.kindle), problem(ProblemKind.drm));
      expect(() => Formats.sniff(head('topaz-sample.azw'), Formats.kindle), problem(ProblemKind.unsupported));
    });

    test('a PDF or EPUB under the wrong name opens as what it is', () {
      expect(Formats.sniff(head('origin-of-species.pdf'), Formats.txt), Formats.pdf);
      expect(Formats.sniff(head('pride-and-prejudice.epub'), Formats.comics), Formats.epub);
    });

    test('RAR 5 comics are an unsupported variant; a zip named .cbr stays a comic', () {
      expect(() => Formats.sniff(head('rar5-sample.cbr'), Formats.comics), problem(ProblemKind.unsupported));
      expect(Formats.sniff(head('mislabelled-zip.cbr'), Formats.comics), Formats.comics);
    });
  });

  group('registry', () {
    test('every new extension maps to its module and family', () {
      expect(Formats.of('a.azw3')!.group, FormatGroup.kindle);
      expect(Formats.of('a.prc'), Formats.kindle);
      expect(Formats.of('war-and-peace.fb2.zip'), Formats.fb2);
      expect(Formats.of('a.xhtml'), Formats.html);
      expect(Formats.of('a.cb7')!.view, ViewKind.comics);
      expect(Formats.of('notes.md')!.group, FormatGroup.documents);
    });

    test('badges show the real extension, not the family', () {
      expect(Formats.labelOf('monte-cristo.azw3'), 'AZW3');
      expect(Formats.labelOf('war-and-peace.fb2.zip'), 'FBZ');
      expect(Formats.labelOf('walden.htm'), 'HTML');
    });

    test('comics have no Reader mode, highlights or read aloud', () {
      expect(<bool>[Formats.comics.readerMode, Formats.comics.annotations, Formats.comics.tts], everyElement(isFalse));
      expect(Formats.comics.tracked, isTrue);
      expect(Formats.image.tracked, isFalse);
    });

    test('the Library lists every book family', () {
      expect(
        Formats.bookExtensions,
        containsAll(<String>['pdf', 'epub', 'mobi', 'azw3', 'fb2', 'fbz', 'html', 'cbz', 'cbr']),
      );
      expect(Formats.bookExtensions, isNot(contains('docx')));
    });
  });

  group('comics', () {
    test('natural sort: numbers as numbers', () {
      final List<String> names = <String>['p10.png', 'p2.png', 'p1.png', 'P3.png', 'ch 10/01.jpg', 'ch 9/02.jpg']
        ..sort(naturalCompare);
      expect(names, <String>['ch 9/02.jpg', 'ch 10/01.jpg', 'p1.png', 'p2.png', 'P3.png', 'p10.png']);
    });

    test('ComicInfo: series as title, issue, writer, manga direction', () {
      final ComicInfo i = ComicInfo.parse(
        '<ComicInfo><Series>Hokusai Manga</Series><Volume>2</Volume><Writer>Hokusai</Writer>'
        '<Manga>YesAndRightToLeft</Manga></ComicInfo>',
      )!;
      expect((i.displayTitle, i.issue, i.writer, i.rtl), ('Hokusai Manga', 'Vol. 2', 'Hokusai', true));
      expect(ComicInfo.parse('<ComicInfo><Number>14</Number></ComicInfo>')!.issue, '#14');
      expect(ComicInfo.parse('not xml <'), isNull);
    });
  });
}
