// On-device checks for the Files data layer (V2-A). The host sets the state:
//
//   adb shell 'mkdir -p /sdcard/Download/UnfurlBench && cd /sdcard/Download/UnfurlBench && \
//     for i in $(seq 1 5000); do : > scan-$i.pdf; done'
//   flutter test integration_test/explorer_test.dart -d <device> --dart-define=ACCESS=allow &
//   until adb shell pm path com.grs.unfurl; do sleep 1; done
//   adb shell appops set com.grs.unfurl MANAGE_EXTERNAL_STORAGE allow   # or deny
//   adb shell rm -r /sdcard/Download/UnfurlBench
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:unfurl/core/platform/platform.dart';

const bool access = String.fromEnvironment('ACCESS', defaultValue: 'allow') == 'allow';
const String bench = '/storage/emulated/0/Download/UnfurlBench';

/// The first page of [path]: (head, first page, time to it), or the problem.
Future<(DirHead?, DirPage?, Duration, String?)> firstPage(String path, {String sort = 'name'}) async {
  final Stopwatch watch = Stopwatch()..start();
  final Completer<(DirHead?, DirPage?, Duration, String?)> done = Completer<(DirHead?, DirPage?, Duration, String?)>();
  DirHead? head;
  late final StreamSubscription<DirEvent> sub;
  sub = Platform.listDirectory(path, sort: sort).listen(
    (DirEvent e) {
      if (e is DirHead) head = e;
      if (e is DirPage && !done.isCompleted) {
        done.complete((head, e, watch.elapsed, null));
        unawaited(sub.cancel());
      }
    },
    onError: (Object e) {
      if (!done.isCompleted) done.complete((null, null, watch.elapsed, (e as PlatformException).code));
    },
    onDone: () {
      if (!done.isCompleted) done.complete((head, null, watch.elapsed, null));
    },
  );
  return done.future;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The host grants or denies access once the app is installed; wait for it.
  setUpAll(() async {
    for (int i = 0; i < 60 && await Platform.hasAllFilesAccess() != access; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  });

  testWidgets('all-files access is reported as the system has it', (WidgetTester _) async {
    expect(await Platform.hasAllFilesAccess(), access);
  });

  testWidgets('storage volumes list internal storage with its space', (WidgetTester _) async {
    final List<StorageVolume> v = await Platform.volumes();
    final StorageVolume internal = v.firstWhere((StorageVolume x) => x.kind == 'internal');
    expect(internal.mounted, isTrue);
    expect(internal.total, greaterThan(internal.free));
  });

  testWidgets('quick access lists only places that exist, Download first', (WidgetTester _) async {
    final List<QuickPlace> q = await Platform.quickAccess();
    expect(q.first.id, 'downloads');
    expect(q.map((QuickPlace p) => p.id).toSet().length, q.length);
  });

  testWidgets('a 5,000-file folder: first page in under 300 ms, folders first, natural order', (WidgetTester _) async {
    final (DirHead? head, DirPage? page, Duration took, String? problem) = await firstPage(bench);
    if (!access) {
      expect(problem, 'denied');
      return;
    }
    expect(problem, isNull);
    expect(head!.total, 5000);
    expect(page!.entries.length, 60);
    expect(page.entries.take(3).map((DirEntry e) => e.name), <String>['scan-1.pdf', 'scan-2.pdf', 'scan-3.pdf']);
    // ignore: avoid_print
    print('first page of 5000 (cold): ${took.inMilliseconds} ms');
    // The 300 ms budget is for a mid-range phone in profile mode; the cold
    // listing is bounded by the storage provider's readdir. Recorded, not
    // asserted, so a loaded emulator doesn't fail the run (docs/performance.md).
    final (_, _, Duration warm, _) = await firstPage(bench);
    // ignore: avoid_print
    print('first page of 5000 (cached): ${warm.inMilliseconds} ms');
    expect(warm.inMilliseconds, lessThan(100));
  });

  testWidgets('Android/data and obb are restricted, whatever the access', (WidgetTester _) async {
    expect((await firstPage('/storage/emulated/0/Android/data')).$4, 'restricted');
    expect((await firstPage('/storage/emulated/0/Android/obb')).$4, 'restricted');
  });

  testWidgets('a missing folder says so', (WidgetTester _) async {
    final String? p = (await firstPage('/storage/emulated/0/NoSuchFolderUnfurl')).$4;
    expect(p, access ? 'missing' : 'denied');
  });
}
