// On-device checks for v3 (Phase H): every new format through the real open
// flow (Kotlin comic archives included), tracking across a trip to the
// background, card export to MediaStore, auto-scroll with the sleep timer,
// volume-key paging and rotation. The host sets the state:
//
//   adb push test/fixtures/. /sdcard/Download/UnfurlFixtures
//   flutter build apk --profile --target-platform android-arm64 -t integration_test/v3_test.dart
//   adb install -r -d build/app/outputs/flutter-apk/app-profile.apk
//   adb shell appops set com.grs.unfurl MANAGE_EXTERNAL_STORAGE allow
//   adb shell am start -n com.grs.unfurl/.MainActivity; adb logcat -s flutter
//
// Settings and the database are in memory; the only thing written to the device is one card PNG in
// Pictures/Unfurl (the save under test).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/platform/platform.dart';
import 'package:unfurl/core/tracking/session.dart';
import 'package:unfurl/core/tracking/tracker.dart';
import 'package:unfurl/features/cards/card_editor.dart';
import 'package:unfurl/features/cards/share_card.dart';
import 'package:unfurl/features/comics/comics_screen.dart';
import 'package:unfurl/features/reader/engine/reader_view.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    for (int i = 0; i < 60 && !await Platform.hasAllFilesAccess(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  });

  testWidgets('every v3 format opens, or says why it can’t', (WidgetTester tester) async {
    await boot(tester);
    for (final String name in <String>[
      'yellow-wallpaper.azw3',
      'yellow-wallpaper.mobi',
      'onegin.fb2',
      'walden.fbz',
      'walden.html',
    ]) {
      await open(tester, name);
      await until(tester, () => find.byType(ReaderView).evaluate().isNotEmpty, name);
      expect(reader(tester).doc.sections, isNotEmpty, reason: name);
      await close(tester);
    }
    for (final String name in <String>[
      'little-nemo-14.cbz',
      'hokusai-manga-2.cb7',
      'krazy-kat-1922.cbr',
      'scan_0412.cbt',
      'mislabelled-zip.cbr',
    ]) {
      await open(tester, name);
      // A decoded page on screen, read through the Kotlin archive.
      await until(
        tester,
        () => find
            .descendant(of: find.byType(ComicsScreen), matching: find.byType(RawImage))
            .evaluate()
            .any((Element e) => (e.widget as RawImage).image != null),
        name,
      );
      await close(tester);
    }
    for (final (String name, String says) in <(String, String)>[
      ('drm-sample.epub', 'protected (DRM)'),
      ('drm-sample.azw', 'protected (DRM)'),
      ('kfx-sample.azw', 'protected (DRM)'), // DRMION: encrypted KFX
      ('topaz-sample.azw', 'Kindle file type isn’t supported'),
      ('rar5-sample.cbr', 'comic archive type isn’t supported'),
      ('truncated.cbz', 'This archive is damaged'),
    ]) {
      await open(tester, name);
      await until(tester, () => find.textContaining(says).evaluate().isNotEmpty, name);
      await close(tester);
    }
  });

  testWidgets('read, go to the background, come back: only time in front counts', (WidgetTester tester) async {
    await boot(tester);
    await open(tester, 'pride-and-prejudice.epub');
    await until(tester, () => find.byType(ReaderView).evaluate().isNotEmpty, 'the reader');
    final ReadingSessionTracker tracker = container.read(trackerProvider);
    Future<void> read(int seconds) async {
      for (int i = 0; i < seconds; i += 5) {
        tracker.activity();
        await settle(tester, const Duration(seconds: 5));
      }
    }

    await read(20);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // No frames are drawn in the background, so no pumping here.
    await Future<void>.delayed(const Duration(seconds: 15));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await read(15);
    await close(tester);
    await settle(tester, const Duration(seconds: 1));
    final DailyStat? today = await (db.select(
      db.dailyStats,
    )..where((DailyStats d) => d.day.equals(dayKey(DateTime.now())))).getSingleOrNull();
    // ignore: avoid_print
    print('v3 tracking: ${today?.readingMs} ms in front over 50 s open (15 s in the background)');
    expect(today, isNotNull);
    expect(today!.readingMs, inInclusiveRange(33000, 40000));
    expect(today.sessions, 1);
  });

  testWidgets('a highlight card saves to Pictures/Unfurl', (WidgetTester tester) async {
    await boot(tester);
    await open(tester, 'pride-and-prejudice.epub');
    await until(tester, () => find.byType(ReaderView).evaluate().isNotEmpty, 'the reader');
    unawaited(
      showCardEditor(
        tester.element(find.byType(ReaderView)),
        const CardContent(
          quote: 'It is a truth universally acknowledged.',
          title: 'Pride and Prejudice',
          author: 'Jane Austen',
          location: 'Ch. 1',
        ),
      ),
    );
    await settle(tester, const Duration(seconds: 1));
    await tester.tap(find.text('Save to Photos'));
    await until(tester, () => find.text('Saved to Pictures/Unfurl').evaluate().isNotEmpty, 'the save');
  });

  testWidgets('auto-scroll moves the page; the sleep timer is set from the menu', (WidgetTester tester) async {
    await boot(tester, <String, Object>{'reading.layout': 'scroll'});
    await open(tester, 'pride-and-prejudice.epub');
    await until(tester, () => find.byType(ReaderView).evaluate().isNotEmpty, 'the reader');
    // Let the chrome shown on opening hide on its own first (4 s).
    await settle(tester, const Duration(seconds: 5));
    final int start = reader(tester).globalIndex;
    await overflow(tester, 'Auto-scroll');
    await tester.tap(find.byType(Switch).first);
    await tester.binding.handlePopRoute();
    await settle(tester, const Duration(seconds: 8));
    expect(reader(tester).globalIndex, greaterThan(start), reason: 'auto-scroll moved on');
    await overflow(tester, 'Sleep timer');
    await tester.tap(find.text('15 min'));
    await settle(tester, const Duration(milliseconds: 600));
    await overflow(tester, 'Sleep timer');
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.label == '15 min' && (w.properties.checked ?? false),
      ),
      findsOneWidget,
      reason: 'the timer is running',
    );
    await tester.binding.handlePopRoute();
    await settle(tester, const Duration(milliseconds: 600));
    await close(tester);
  });

  testWidgets('volume keys turn pages; rotation keeps the place', (WidgetTester tester) async {
    await boot(tester, <String, Object>{'reading.layout': 'paged', 'reading.volumeKeys': true});
    await open(tester, 'pride-and-prejudice.epub');
    await until(tester, () => find.byType(ReaderView).evaluate().isNotEmpty, 'the reader');
    await settle(tester, const Duration(seconds: 1));
    final int first = reader(tester).globalIndex;
    for (int i = 0; i < 3; i++) {
      await volumeKey(tester, 1);
      await settle(tester, const Duration(milliseconds: 800));
    }
    final int third = reader(tester).globalIndex;
    expect(third, greaterThan(first));
    await volumeKey(tester, -1);
    await settle(tester, const Duration(milliseconds: 800));
    final int place = reader(tester).globalIndex;
    expect(place, inExclusiveRange(first, third));

    // Turn the window: the passage at the top of the page stays on screen.
    final Size size = tester.view.physicalSize;
    tester.view.physicalSize = Size(size.height, size.width);
    addTearDown(tester.view.resetPhysicalSize);
    await settle(tester, const Duration(seconds: 2));
    final ReaderController c = reader(tester);
    final (int turnedFrom, int turnedTo) = (c.globalIndex, lastIndex(c));
    tester.view.resetPhysicalSize();
    await settle(tester, const Duration(seconds: 2));
    final (int backFrom, int backTo) = (c.globalIndex, lastIndex(c));
    // ignore: avoid_print
    print('v3 rotation: place $place, turned $turnedFrom–$turnedTo, back $backFrom–$backTo');
    expect(place, inInclusiveRange(turnedFrom, turnedTo));
    expect(backFrom, place, reason: 'back on the very page it started on');
    expect(backTo, greaterThan(place));
    await close(tester);
  });
}
