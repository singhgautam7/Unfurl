import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unfurl/core/explorer.dart';
import 'package:unfurl/core/platform/platform.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

const MethodChannel platform = MethodChannel('unfurl/platform');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Android's answer, as MainActivity sends it on resume.
  Future<void> resume(bool granted) => messenger.handlePlatformMessage(
    'unfurl/platform',
    const StandardMethodCodec().encodeMethodCall(MethodCall('allFilesAccess', granted)),
    (_) {},
  );

  Future<ProviderContainer> start({required bool android, bool? cached}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{FilesAccessController.kLastGranted: ?cached});
    final SharedPreferences p = await SharedPreferences.getInstance();
    messenger.setMockMethodCallHandler(platform, (MethodCall c) async {
      if (c.method == 'hasAllFilesAccess') return android;
      if (c.method == 'requestAllFilesAccess') return true;
      return null;
    });
    final ProviderContainer c = ProviderContainer(overrides: <Override>[prefsProvider.overrideWithValue(p)]);
    addTearDown(c.dispose);
    c.listen(filesAccessProvider, (_, _) {});
    await pumpEventQueue();
    return c;
  }

  test('the first state is the cached one, then Android answers', () async {
    final ProviderContainer c = await start(android: true, cached: false);
    expect(c.read(filesAccessProvider).granted, isTrue);
    expect(c.read(filesAccessProvider).justGranted, isFalse, reason: 'not asked for this session');
  });

  test('asking, then coming back without turning it on: still off', () async {
    final ProviderContainer c = await start(android: false);
    await c.read(filesAccessProvider.notifier).request();
    await resume(false);
    expect(c.read(filesAccessProvider), const FilesAccess(granted: false, note: AccessNote.stillOff));
  });

  test('asking, then turning it on: granted, with the snackbar once', () async {
    final ProviderContainer c = await start(android: false);
    await c.read(filesAccessProvider.notifier).request();
    await resume(true);
    expect(c.read(filesAccessProvider), const FilesAccess(granted: true, justGranted: true));
    c.read(filesAccessProvider.notifier).acknowledge();
    expect(c.read(filesAccessProvider).justGranted, isFalse);
  });

  test('turned off in system settings while away: turned off, and remembered', () async {
    final ProviderContainer c = await start(android: true, cached: true);
    await resume(false);
    expect(c.read(filesAccessProvider), const FilesAccess(granted: false, note: AccessNote.turnedOff));
    expect((await SharedPreferences.getInstance()).getBool(FilesAccessController.kLastGranted), isFalse);
    await resume(true);
    expect(c.read(filesAccessProvider), const FilesAccess(granted: true), reason: 're-granted, no snackbar unasked');
  });

  test('listings stream heads then pages by id; problems arrive by name; a new one never kills another', () async {
    MockStreamHandlerEventSink? sink;
    messenger.setMockStreamHandler(
      const EventChannel('unfurl/list'),
      MockStreamHandler.inline(onListen: (Object? _, MockStreamHandlerEventSink s) => sink = s),
    );
    final List<int> cancelled = <int>[];
    messenger.setMockMethodCallHandler(platform, (MethodCall c) async {
      final Map<Object?, Object?> a = (c.arguments as Map<Object?, Object?>?) ?? const <Object?, Object?>{};
      if (c.method == 'listCancel') cancelled.add(a['id']! as int);
      if (c.method != 'listStart') return null;
      final int id = a['id']! as int;
      if ((a['path']! as String).endsWith('Android/data')) {
        sink!.success(<String, Object?>{'id': id, 'kind': 'error', 'code': 'restricted'});
        return null;
      }
      sink!
        ..success(<String, Object?>{'id': id, 'kind': 'head', 'total': 3, 'dirs': 1})
        ..success(<String, Object?>{
          'id': id,
          'kind': 'page',
          'from': 0,
          'rows': <Object?>[
            <Object?>['Books', true, 0, 1],
            <Object?>['a.pdf', false, 10, 2],
          ],
        })
        ..success(<String, Object?>{
          'id': id,
          'kind': 'page',
          'from': 2,
          'rows': <Object?>[
            <Object?>['b.epub', false, 20, 3],
          ],
        })
        ..success(<String, Object?>{'id': id, 'kind': 'done'});
      return null;
    });
    final DirListing a = DirListing('/storage/emulated/0/Download', sort: 'name', hidden: false);
    await pumpEventQueue();
    // A second folder opens before the first is let go, then the first goes.
    final DirListing b = DirListing('/storage/emulated/0/Documents', sort: 'name', hidden: false);
    a.dispose();
    await pumpEventQueue();
    expect(b.total, 3);
    expect(b.entries.map((DirEntry e) => e.name), <String>['Books', 'a.pdf', 'b.epub']);
    expect(b.entries.first.isDir, isTrue);
    expect(b.done, isTrue);
    b.dispose();

    final DirListing r = DirListing('/storage/emulated/0/Android/data', sort: 'name', hidden: false);
    await pumpEventQueue();
    expect(r.problem, DirProblem.restricted);
    r.dispose();
  });
}
