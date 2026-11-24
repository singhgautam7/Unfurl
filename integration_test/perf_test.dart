// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
// Pass 2 timings (specs/app-polish-2/performance.md): frames, first visits,
// opens, sheets, menus, page turns and memory on a realistic library. Nothing
// is asserted. Set up and run:
//
//   python3 tool/make_perf_fixtures.py
//   adb push build/perf_fixtures/. /data/local/tmp/unfurl/ && adb shell chmod -R a+rX /data/local/tmp/unfurl
//   flutter build apk --profile --target-platform android-arm64 -t integration_test/perf_test.dart
//   adb install -r build/app/outputs/flutter-apk/app-profile.apk
//   adb shell am start -n com.grs.unfurl/.MainActivity; adb logcat -s flutter
//
// `tool/perf_run.sh <serial> <apk> <out.txt>` does the last two steps and
// `python3 tool/perf_table.py before.txt after.txt` prints the comparison.
// The app's own data is never touched: in-memory settings, a database of its
// own, and files by path under /data/local/tmp/unfurl.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unfurl/app.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/library/enrich.dart';
import 'package:unfurl/core/library/library.dart';
import 'package:unfurl/core/open.dart';
import 'package:unfurl/core/platform/platform.dart';
import 'package:unfurl/core/providers.dart';
import 'package:unfurl/core/router/router.dart';
import 'package:unfurl/design_system/buttons.dart';
import 'package:unfurl/design_system/covers.dart';
import 'package:unfurl/design_system/nav_pill.dart';
import 'package:unfurl/features/comics/comics_screen.dart';
import 'package:unfurl/features/home/home_screen.dart';
import 'package:unfurl/features/library/library_screen.dart';
import 'package:unfurl/features/notes/notes_screen.dart';
import 'package:unfurl/features/office/image_screen.dart';
import 'package:unfurl/features/office/office_screens.dart';
import 'package:unfurl/features/office/sheet_screen.dart';
import 'package:unfurl/features/pdf/pdf_pages.dart';
import 'package:unfurl/features/reader/engine/reader_view.dart';
import 'package:unfurl/features/reader/reading_prefs.dart';
import 'package:unfurl/features/settings/more_screen.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

const String kDir = '/data/local/tmp/unfurl';

late ProviderContainer container;
late AppDatabase db;

void emit(Map<String, Object?> row) {
  // ignore: avoid_print
  print('perf: ${jsonEncode(row)}');
}

Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

final List<FrameTiming> _timings = <FrameTiming>[];

double _ms(Duration d) => d.inMicroseconds / 1000;

/// Every frame drawn while [action] runs (its scope in microseconds of the
/// engine's clock), build and raster apart.
Future<void> frames(String name, Future<void> Function() action) async {
  await wait(400);
  _timings.clear();
  final Stopwatch w = Stopwatch()..start();
  await action();
  w.stop();
  // The engine hands timings over in batches, about once a second.
  await wait(1300);
  final List<FrameTiming> t = List<FrameTiming>.of(_timings);
  if (t.isEmpty) return emit(<String, Object?>{'name': name, 'frames': 0});
  double p(List<double> xs, double q) => (List<double>.of(xs)..sort())[((xs.length - 1) * q).round()];
  final List<double> b = <double>[for (final FrameTiming f in t) _ms(f.buildDuration)];
  final List<double> r = <double>[for (final FrameTiming f in t) _ms(f.rasterDuration)];
  double r1(double v) => (v * 10).round() / 10;
  emit(<String, Object?>{
    'name': name,
    'frames': t.length,
    'b50': r1(p(b, .5)),
    'b90': r1(p(b, .9)),
    'bmax': r1(p(b, 1)),
    'r50': r1(p(r, .5)),
    'r90': r1(p(r, .9)),
    'rmax': r1(p(r, 1)),
    'b16': b.where((double x) => x > 16).length,
    'r16': r.where((double x) => x > 16).length,
  });
}

void time(String name, int ms) => emit(<String, Object?>{'name': name, 'ms': ms});

/// Polls on frames until [ok], at most [seconds]; the time it took, or -1.
Future<int> until(bool Function() ok, {int seconds = 30}) async {
  final Stopwatch w = Stopwatch()..start();
  while (!ok()) {
    if (w.elapsed.inSeconds >= seconds) return -1;
    await wait(4);
  }
  await WidgetsBinding.instance.endOfFrame;
  return w.elapsedMilliseconds;
}

Finder button(String label) => find.byWidgetPredicate((Widget w) => w is AppIconButton && w.semanticLabel == label);

bool painted(Finder f) => f.hitTestable().evaluate().isNotEmpty;

const List<String> kTabs = <String>['Home', 'Library', 'Notes', 'More'];

Finder tab(String name) => find.byType(switch (name) {
  'Home' => HomeScreen,
  'Library' => LibraryScreen,
  'Notes' => NotesScreen,
  _ => MoreScreen,
});

/// The nav pill's tab by its icon (labels show on the selected one only).
Finder navItem(String name) {
  final NavDestination d = kDestinations.firstWhere((NavDestination x) => x.label == name);
  return find.descendant(
    of: find.byType(NavPill),
    matching: find.byWidgetPredicate((Widget w) => w is Semantics && w.properties.label == d.label),
  );
}

Future<void> tapCenter(LiveWidgetController t, Finder f) async {
  if (f.evaluate().isEmpty) return emit(<String, Object?>{'name': 'MISSING ${f.describeMatch(Plurality.one)}'});
  final TestGesture g = await t.startGesture(t.getCenter(f.first));
  await wait(40);
  await g.up();
}

Future<void> go(LiveWidgetController t, String name) async {
  await tapCenter(t, navItem(name));
  await wait(750);
}

void enterText(String v) {
  if (find.byType(EditableText).hitTestable().evaluate().isEmpty) {
    return emit(<String, Object?>{'name': 'MISSING search field'});
  }
  final EditableTextState e = find
      .byType(EditableText)
      .hitTestable()
      .evaluate()
      .map((Element x) => (x as StatefulElement).state as EditableTextState)
      .first;
  e.userUpdateTextEditingValue(
    TextEditingValue(
      text: v,
      selection: TextSelection.collapsed(offset: v.length),
    ),
    SelectionChangedCause.keyboard,
  );
}

/// To a tab whatever the pill is doing (it hides on scroll), for the scenarios
/// that aren't about switching.
Future<void> goTo(String name) async {
  GoRouter.of(rootNavigatorKey.currentContext!).go('/${name.toLowerCase()}');
  await wait(900);
}

/// Real-time flings: [n] of them, [dy] pixels in 120 ms.
Future<void> flings(LiveWidgetController t, Offset from, Offset by, int n, {int rest = 900}) async {
  for (int i = 0; i < n; i++) {
    final TestGesture g = await t.startGesture(from);
    for (int s = 0; s < 8; s++) {
      await wait(12);
      await g.moveBy(by / 8, timeStamp: Duration(milliseconds: DateTime.now().millisecondsSinceEpoch));
    }
    await g.up(timeStamp: Duration(milliseconds: DateTime.now().millisecondsSinceEpoch));
    await wait(rest);
  }
}

Offset at(double x, double y) {
  final Size s =
      WidgetsBinding.instance.platformDispatcher.views.first.physicalSize /
      WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
  return Offset(s.width * x, s.height * y);
}

void push(String name, {String? mode}) {
  final String path = '$kDir/$name';
  unawaited(
    openDocument(
      rootNavigatorKey.currentContext!,
      DocRef(uri: 'file://${Uri.encodeFull(path)}', name: name, size: File(path).lengthSync()),
      mode: mode,
    ),
  );
}

/// Closes a sheet or menu; never leaves the tab.
Future<void> dismiss() async {
  if (rootNavigatorKey.currentState!.canPop()) await WidgetsBinding.instance.handlePopRoute();
}

Future<void> back(LiveWidgetController t) async {
  await WidgetsBinding.instance.handlePopRoute();
  await wait(900);
}

void rss(String name) => emit(<String, Object?>{'name': 'RSS $name', 'mb': ProcessInfo.currentRss ~/ (1024 * 1024)});

/// The library as a heavy reader has it: 500 files of every format, 120
/// opened books, 60 recents, 400 highlights, notes and bookmarks, 3,000 files
/// in one folder. Only files that exist on the device are ever opened.
class PerfLibrary extends Library {
  PerfLibrary(super.db);

  // The seeded folders have no grant: never rescanned, never "access lost".
  @override
  Future<void> refreshAll() async {}
}

Future<void> seed(AppDatabase d) async {
  final List<String> exts = <String>[
    'epub',
    'pdf',
    'mobi',
    'azw3',
    'fb2',
    'html',
    'cbz',
    'docx',
    'xlsx',
    'md',
    'txt',
    'jpg',
    'pptx',
  ];
  final DateTime now = DateTime.now();
  final int books = await d
      .into(d.folders)
      .insert(FoldersCompanion.insert(uri: 'content://tree/Books', name: 'Books', addedAt: now));
  final int big = await d
      .into(d.folders)
      .insert(FoldersCompanion.insert(uri: 'content://tree/Big', name: 'Big folder', addedAt: now));
  // Before the app lists its covers.
  final Directory covers = Directory('${(await getApplicationSupportDirectory()).path}/covers')
    ..createSync(recursive: true);
  for (int i = 0; i < 360; i++) {
    final File to = File('${covers.path}/fp$i.img');
    if (!to.existsSync()) File('$kDir/covers/${i % 40}.img').copySync(to.path);
  }
  await d.batch((Batch b) {
    for (int i = 0; i < 500; i++) {
      final String ext = exts[i % exts.length];
      b.insert(
        d.entries,
        EntriesCompanion.insert(
          folderId: books,
          docId: 'd$i',
          uri: 'content://tree/Books/d$i',
          parent: i % 5 == 0 ? 'Sub ${i % 8}' : '',
          name: 'A reasonably long file name $i.$ext',
          ext: ext,
          isDir: false,
          size: Value<int>(120000 + i * 977),
          modified: Value<int>(now.millisecondsSinceEpoch - i * 3600000),
          fingerprint: Value<String?>('fp$i'),
          title: Value<String?>('The Book With Number $i'),
          author: Value<String?>('Author ${i % 60}'),
          enriched: const Value<int>(1),
        ),
      );
    }
    for (int i = 0; i < 3000; i++) {
      b.insert(
        d.entries,
        EntriesCompanion.insert(
          folderId: big,
          docId: 'b$i',
          uri: 'content://tree/Big/b$i',
          parent: '',
          name: 'scan-$i.${i % 3 == 0 ? 'jpg' : 'pdf'}',
          ext: i % 3 == 0 ? 'jpg' : 'pdf',
          // Out of the Library (its 500 stay), still in its folder.
          hidden: const Value<bool>(true),
          isDir: false,
          size: Value<int>(5000 + i),
          modified: Value<int>(now.millisecondsSinceEpoch - i * 60000),
        ),
      );
    }
    for (int i = 0; i < 120; i++) {
      final String ext = exts[i % exts.length];
      b.insert(
        d.documents,
        DocumentsCompanion.insert(
          fingerprint: 'fp$i',
          uri: 'content://tree/Books/d$i',
          name: 'A reasonably long file name $i.$ext',
          format: 'epub',
          title: Value<String?>('The Book With Number $i'),
          author: Value<String?>('Author ${i % 60}'),
          addedAt: now,
          openedAt: Value<DateTime?>(now.subtract(Duration(hours: i + 1))),
          progress: Value<double>((i % 10) / 10),
          where: Value<String?>('Chapter ${i % 30}'),
        ),
      );
    }
    for (int i = 0; i < 60; i++) {
      final String ext = exts[i % exts.length];
      b.insert(
        d.recents,
        RecentsCompanion.insert(
          uri: 'content://tree/Books/d$i',
          fingerprint: Value<String?>('fp$i'),
          name: 'A reasonably long file name $i.$ext',
          size: Value<int>(120000 + i * 977),
          openedAt: now.subtract(Duration(hours: i + 1)),
        ),
      );
    }
    for (int i = 0; i < 400; i++) {
      b.insert(
        d.annotations,
        AnnotationsCompanion.insert(
          fingerprint: 'fp${i % 60}',
          kind: i % 7 == 0 ? 'bookmark' : 'highlight',
          color: Value<int?>(i % 7 == 0 ? null : i % 4),
          locator: '{"section":0,"block":$i,"offset":0}',
          quote: Value<String>(
            'A highlighted passage with enough words to take two or three lines in the list, number $i.',
          ),
          note: Value<String?>(i % 3 == 0 ? 'A note about this passage, number $i.' : null),
          label: Value<String>('Ch. ${i % 30} · ${i % 100}%'),
          progress: Value<double>((i % 100) / 100),
          createdAt: now.subtract(Duration(minutes: i * 13)),
        ),
      );
    }
  });
}

/// The app's own binding, not a test one: a test binding draws a frame on
/// every vsync whether or not the app asked for it (and turns semantics on),
/// which hides idle costs and floods the GPU.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final LiveWidgetController t = LiveWidgetController(WidgetsBinding.instance);
  SchedulerBinding.instance.addTimingsCallback(_timings.addAll);
  final File dbFile = File('${(await getApplicationDocumentsDirectory()).path}/unfurl_perf.sqlite');
  for (final String s in <String>['', '-wal', '-shm', '-journal']) {
    final File f = File('${dbFile.path}$s');
    if (f.existsSync()) f.deleteSync();
  }
  db = AppDatabase(driftDatabase(name: 'unfurl_perf'));
  await seed(db);
  SharedPreferences.setMockInitialValues(<String, Object>{AppSettings.kOnboarded: true, AppSettings.kOpenedFile: true});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  container = ProviderContainer(
    overrides: <Override>[
      prefsProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      libraryProvider.overrideWith((Ref ref) => PerfLibrary(db)),
    ],
  );
  await pdfrxFlutterInitialize();
  await Covers.dir();
  final Stopwatch boot = Stopwatch()..start();
  await frames('First: Home (boot)', () async {
    runApp(UncontrolledProviderScope(container: container, child: const UnfurlApp()));
    while (WidgetsBinding.instance.rootElement == null) {
      await wait(2);
    }
    await until(() => painted(find.byType(CoverTile)));
    time('boot to Home content', boot.elapsedMilliseconds);
    await wait(1500);
  });
  // Let anything that prepares in idle time finish, as a person looking at Home would.
  await wait(4000);
  rss('Home');
  await frames('Idle on Home, 5 s', () => wait(5000));

  // ------------------------------------------------------------- tabs
  for (final String name in kTabs.skip(1)) {
    await frames('First visit: $name', () async {
      final Stopwatch w = Stopwatch()..start();
      await tapCenter(t, navItem(name));
      // On stage and drawn (a page still sliding in counts).
      await until(() => tab(name).evaluate().isNotEmpty);
      time('tap to $name', w.elapsedMilliseconds);
      await wait(1200);
    });
  }
  await go(t, 'Home');
  await frames('Tab switch, all 12 pairs twice', () async {
    for (int round = 0; round < 2; round++) {
      for (final String a in kTabs) {
        for (final String b in kTabs) {
          if (a == b) continue;
          await go(t, a);
          await go(t, b);
        }
      }
    }
  });
  for (final String a in kTabs) {
    for (final String b in kTabs) {
      if (a == b) continue;
      await go(t, a);
      await frames('Tab $a to $b', () => go(t, b));
    }
  }

  // ---------------------------------------------------------- scrolls
  await goTo('Home');
  await frames('Scroll Home', () async {
    await flings(t, at(.5, .75), const Offset(0, -500), 2);
    await flings(t, at(.5, .35), const Offset(0, 500), 2);
    await flings(t, at(.8, .62), const Offset(-250, 0), 2);
  });
  await goTo('Library');
  await frames('Scroll Library grid', () => flings(t, at(.5, .75), const Offset(0, -600), 8));
  await flings(t, at(.5, .35), const Offset(0, 900), 12, rest: 250);
  await wait(800);
  await frames('Library filter chip x4', () async {
    for (final String label in <String>['EPUB', 'PDF', 'EPUB', 'All']) {
      final Finder f = find.text(label).hitTestable();
      if (f.evaluate().isEmpty) continue;
      await tapCenter(t, f);
      await wait(700);
    }
  });
  await frames('Library overflow menu x5', () async {
    for (int i = 0; i < 5; i++) {
      await tapCenter(t, button('Sort and view').hitTestable());
      await wait(600);
      await dismiss();
      await wait(500);
    }
  });
  await container.read(settingsProvider.notifier).setLibraryGrid(grid: false);
  await wait(800);
  await frames('Scroll Library list', () => flings(t, at(.5, .75), const Offset(0, -600), 8));
  await container.read(settingsProvider.notifier).setLibraryGrid(grid: true);
  await wait(500);
  await flings(t, at(.5, .35), const Offset(0, 900), 8, rest: 250);
  await wait(800);
  await frames('Book sheet (long press) x3', () async {
    for (int i = 0; i < 3; i++) {
      final TestGesture g = await t.startGesture(at(.5, .5));
      await wait(650);
      await g.up();
      await wait(700);
      await dismiss();
      await wait(600);
    }
  });
  await frames('Library search: open the field', () async {
    await tapCenter(t, button('Search library').hitTestable());
    await wait(900);
  });
  await frames('Library search: type 4 letters', () async {
    for (final String q in <String>['n', 'nu', 'num', 'numb']) {
      enterText(q);
      await wait(400);
    }
  });
  FocusManager.instance.primaryFocus?.unfocus();
  await wait(600);
  await frames('Library search: scroll the results', () => flings(t, at(.5, .7), const Offset(0, -500), 4));
  await dismiss();
  await wait(600);
  await frames('Open a 3,000 file folder', () async {
    final int id = (await (db.select(db.folders)..where((f) => f.name.equals('Big folder'))).getSingle()).id;
    unawaited(GoRouter.of(rootNavigatorKey.currentContext!).push('/folder/$id'));
    await wait(1800);
  });
  await frames('Scroll the 3,000 file folder', () => flings(t, at(.5, .75), const Offset(0, -600), 6));
  await back(t);
  await goTo('Notes');
  await frames('Scroll Notes', () => flings(t, at(.5, .75), const Offset(0, -600), 8));
  await goTo('More');
  await frames('Open Insights', () async {
    unawaited(GoRouter.of(rootNavigatorKey.currentContext!).push(Routes.insights));
    await wait(1600);
  });
  await frames('Scroll Insights', () => flings(t, at(.5, .75), const Offset(0, -500), 4));
  await back(t);
  await goTo('Home');
  await frames('Open Settings and Theme, and back', () async {
    unawaited(GoRouter.of(rootNavigatorKey.currentContext!).push(Routes.settings));
    await wait(900);
    unawaited(GoRouter.of(rootNavigatorKey.currentContext!).push(Routes.theme));
    await wait(900);
    await back(t);
    await back(t);
  });

  // ------------------------------------------------------------- opens
  bool reader() => painted(find.byType(ReaderView));
  bool pages() => painted(find.byType(PdfPages));
  final Map<String, bool Function()> files = <String, bool Function()>{
    'walden.html': reader, // warm up
    'big.epub': reader,
    'big.md': reader,
    'big.txt': reader,
    'yellow-wallpaper.mobi': reader,
    'yellow-wallpaper.azw3': reader,
    'onegin.fb2': reader,
    'pride-and-prejudice.epub': reader,
    'big.docx': () => painted(find.byType(DocxScreen)) && find.byType(RichText).evaluate().length > 10,
    'big.xlsx': () => painted(find.byType(SheetScreen)) && find.byType(CustomPaint).evaluate().length > 5,
    'Q3 review.pptx': () => painted(find.byType(PptxScreen)),
    'little-nemo-14.cbz': () => find
        .descendant(of: find.byType(ComicsScreen), matching: find.byType(RawImage))
        .evaluate()
        .any((Element e) => (e.widget as RawImage).image != null),
    'Receipt_0412.jpg': () => painted(find.byType(ImageScreen)),
    'big.pdf': pages,
  };
  for (final MapEntry<String, bool Function()> f in files.entries) {
    await frames('Open ${f.key}', () async {
      final Stopwatch w = Stopwatch()..start();
      push(f.key);
      final int ok = await until(f.value);
      time('open ${f.key}', ok < 0 ? -1 : w.elapsedMilliseconds);
      await wait(1200);
    });
    await back(t);
  }

  // ------------------------------------------------------------ reader
  push('big.epub');
  await until(reader);
  await wait(2500);
  await frames('Reader: 16 page turns (slide)', () async {
    for (int i = 0; i < 16; i++) {
      await t.tapAt(at(.92, .5));
      await wait(520);
    }
  });
  await frames('Reader: 6 page drags', () => flings(t, at(.8, .5), const Offset(-260, 0), 6, rest: 600));
  Future<void> chrome() async {
    if (!painted(button('More options'))) {
      await t.tapAt(at(.5, .5));
      await wait(700);
    }
  }

  await chrome();
  await frames('Reader: settings sheet x4', () async {
    for (int i = 0; i < 4; i++) {
      await chrome();
      await tapCenter(t, button('Reading settings').hitTestable());
      await wait(900);
      await dismiss();
      await wait(700);
    }
  });
  await frames('Reader: contents sheet x3', () async {
    for (int i = 0; i < 3; i++) {
      await chrome();
      await tapCenter(t, button('Contents').hitTestable());
      await wait(900);
      await dismiss();
      await wait(700);
    }
  });
  await frames('Reader: overflow menu x4', () async {
    for (int i = 0; i < 4; i++) {
      await chrome();
      await tapCenter(t, button('More options').hitTestable());
      await wait(600);
      await dismiss();
      await wait(500);
    }
  });
  await frames('Reader: selection x3', () async {
    for (int i = 0; i < 3; i++) {
      final TestGesture g = await t.startGesture(at(.5, .45));
      await wait(700);
      await g.up();
      await wait(700);
      await t.tapAt(at(.5, .85));
      await wait(600);
    }
  });
  await frames('Reader: font size, 4 steps', () async {
    final ReadingPrefsController c = container.read(readingPrefsProvider.notifier);
    final double size = container.read(readingPrefsProvider).size.toDouble();
    for (final double d in <double>[1, 2, 1, 0]) {
      c.update((ReadingPrefs p) => p.copyWith(size: size + d));
      await wait(900);
    }
  });
  container.read(readingPrefsProvider.notifier).update((ReadingPrefs p) => p.copyWith(layout: ReaderLayout.scroll));
  await wait(1500);
  await frames('Reader: continuous, 8 flings', () => flings(t, at(.5, .75), const Offset(0, -600), 8));
  rss('big.epub');
  await frames('Reader: 60 s of reading (memory)', () async {
    for (int i = 0; i < 40; i++) {
      await flings(t, at(.5, .75), const Offset(0, -600), 1, rest: 1000);
    }
  });
  rss('big.epub after 40 flings');
  container.read(readingPrefsProvider.notifier).update((ReadingPrefs p) => p.copyWith(layout: ReaderLayout.paged));
  await wait(500);
  await back(t);

  // --------------------------------------------------------------- pdf
  push('big.pdf');
  await until(pages);
  await wait(2000);
  await frames('PDF: 10 flings', () => flings(t, at(.5, .75), const Offset(0, -600), 10));
  rss('big.pdf');
  await frames('PDF: 60 s of reading (memory)', () async {
    for (int i = 0; i < 40; i++) {
      await flings(t, at(.5, .75), const Offset(0, -600), 1, rest: 1000);
    }
  });
  rss('big.pdf after 40 flings');
  await chrome();
  await frames('PDF: contents sheet x3', () async {
    for (int i = 0; i < 3; i++) {
      await chrome();
      await tapCenter(t, button('Contents').hitTestable());
      await wait(900);
      await dismiss();
      await wait(700);
    }
  });
  await frames('PDF: page settings sheet x3', () async {
    for (int i = 0; i < 3; i++) {
      await chrome();
      await tapCenter(t, button('Page settings').hitTestable());
      await wait(900);
      await dismiss();
      await wait(700);
    }
  });
  await back(t);
  for (int i = 0; i < 2; i++) {
    await frames('PDF to Reader mode (${i == 0 ? 'cold' : 'cached'})', () async {
      final Stopwatch w = Stopwatch()..start();
      push('big.pdf', mode: 'reader');
      final int ok = await until(reader, seconds: 120);
      time('big.pdf in Reader mode, ${i == 0 ? 'cold' : 'cached'}', ok < 0 ? -1 : w.elapsedMilliseconds);
      await wait(1500);
    });
    await back(t);
  }
  push('two-column.pdf');
  await until(pages);
  await wait(1200);
  await frames('Page to Reader and back x3', () async {
    for (int i = 0; i < 3; i++) {
      for (final String mode in <String>['Reader mode', 'Page view']) {
        await chrome();
        final Finder f = find
            .byWidgetPredicate((Widget w) => w is Semantics && w.properties.label == mode)
            .hitTestable();
        if (f.evaluate().isEmpty) continue;
        await tapCenter(t, f);
        await wait(1600);
      }
    }
  });
  await back(t);

  // ------------------------------------------------------------ office
  push('big.docx');
  await until(files['big.docx']!);
  await wait(1500);
  await frames('DOCX: 8 flings', () => flings(t, at(.5, .75), const Offset(0, -600), 8));
  await back(t);
  push('big.xlsx');
  await until(files['big.xlsx']!);
  await wait(1500);
  await frames('XLSX: 8 flings', () => flings(t, at(.5, .75), const Offset(0, -600), 8));
  await back(t);
  push('little-nemo-14.cbz');
  await until(files['little-nemo-14.cbz']!);
  await wait(1000);
  await frames('Comics: 6 page swipes', () => flings(t, at(.8, .5), const Offset(-260, 0), 6));
  await back(t);
  rss('end');
  emit(<String, Object?>{'name': 'done'});
}
