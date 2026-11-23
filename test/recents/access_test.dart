import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/library/access.dart';
import 'package:unfurl/core/platform/platform.dart';

void main() {
  group('sortAccess', () {
    test('readable wins over everything', () {
      expect(sortAccess(readable: true, docId: null, exists: null), FileAccess.readable);
      expect(sortAccess(readable: true, docId: 'primary:a.pdf', exists: false), FileAccess.readable);
    });
    test('no exact location is unknown, whatever else is claimed', () {
      for (final bool? exists in <bool?>[true, false, null]) {
        expect(sortAccess(readable: false, docId: null, exists: exists), FileAccess.unknown);
      }
    });
    test('gone only when the exact place was looked at and is empty', () {
      const String at = 'primary:Download/abc.pdf';
      expect(sortAccess(readable: false, docId: at, exists: false), FileAccess.gone);
      expect(sortAccess(readable: false, docId: at, exists: true), FileAccess.noAccess);
      expect(
        sortAccess(readable: false, docId: at, exists: null),
        FileAccess.noAccess,
        reason: 'Android could not tell',
      );
    });
  });

  group('DocId', () {
    test('the folder and its label', () {
      expect(const DocId('primary:Download/Reports/a.pdf').folder.id, 'primary:Download/Reports');
      expect(const DocId('primary:Download/Reports/a.pdf').folder.label, 'Download › Reports');
      expect(const DocId('primary:a.pdf').folder.id, 'primary:');
      expect(const DocId('primary:a.pdf').folder.label, 'Internal storage');
      expect(const DocId('1A2B-3C4D:Books/b.epub').folder.id, '1A2B-3C4D:Books');
      expect(const DocId('1A2B-3C4D:b.epub').folder.label, 'SD card');
    });
    test('what the folder picker gives to apps', () {
      bool ok(String id, [int sdk = 36]) => DocId(id).grantable(sdk);
      for (final String no in <String>[
        'primary:',
        '1A2B-3C4D:',
        'primary:Download',
        'primary:download',
        'primary:Android',
        'primary:Android/data',
        'primary:Android/data/com.x/files',
        'primary:Android/obb/com.x',
      ]) {
        expect(ok(no), isFalse, reason: no);
        expect(ok(no, 30), isFalse, reason: '$no on API 30');
        expect(ok(no, 29), isTrue, reason: '$no before Android 11');
      }
      for (final String yes in <String>[
        'primary:Download/Reports',
        'primary:Documents',
        'primary:Android/media',
        'primary:Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
        '1A2B-3C4D:Books',
      ]) {
        expect(ok(yes), isTrue, reason: yes);
      }
    });
  });

  test('what each state offers', () {
    AccessProblem p(FileAccess s, {String? at, bool app = true, int sdk = 36}) => AccessProblem(
      state: s,
      ref: const DocRef(uri: 'content://x', name: 'x.pdf'),
      docId: at == null ? null : DocId(at),
      folderApp: app,
      sdk: sdk,
    );
    expect(p(FileAccess.noAccess, at: 'primary:Download/R/x.pdf').canAllow, isTrue);
    expect(p(FileAccess.noAccess, at: 'primary:Download/x.pdf').canAllow, isFalse);
    expect(p(FileAccess.noAccess, at: 'primary:Download/x.pdf').canShowFolder, isTrue);
    expect(p(FileAccess.noAccess, at: 'primary:Download/x.pdf', app: false).canShowFolder, isFalse);
    expect(p(FileAccess.unknown).canAllow, isFalse);
    expect(p(FileAccess.unknown).canShowFolder, isFalse);
    expect(p(FileAccess.gone, at: 'primary:Docs/x.pdf').canAllow, isFalse);
  });
}
