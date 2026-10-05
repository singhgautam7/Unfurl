// Shared by the on-device suites: the app booted on in-memory settings and a
// fresh database, real-time waits that keep frames drawing, and the open
// flow. Fixtures come from test/fixtures, pushed to Download (see v3_test.dart).
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unfurl/app.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/open.dart';
import 'package:unfurl/core/platform/platform.dart';
import 'package:unfurl/core/providers.dart';
import 'package:unfurl/design_system/buttons.dart';
import 'package:unfurl/features/reader/engine/reader_view.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

const String fx = '/storage/emulated/0/Download/UnfurlFixtures';

late ProviderContainer container;
late AppDatabase db;

/// The app with fresh in-memory settings ([prefs] on top of onboarding) and database.
Future<void> boot(
  WidgetTester tester, [
  Map<String, Object> prefs = const <String, Object>{},
  AppDatabase? database,
]) async {
  // In-memory settings and database: the device's own app data is never touched.
  SharedPreferences.setMockInitialValues(<String, Object>{
    AppSettings.kOnboarded: true,
    AppSettings.kOpenedFile: true,
    ...prefs,
  });
  final SharedPreferences p = await SharedPreferences.getInstance();
  db = database ?? AppDatabase(NativeDatabase.memory());
  container = ProviderContainer(
    overrides: <Override>[prefsProvider.overrideWithValue(p), databaseProvider.overrideWithValue(db)],
  );
  // The database stays open: unawaited writes (covers, recents) can land
  // after a test ends, as they would in the app.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const UnfurlApp()));
  await settle(tester, const Duration(seconds: 1));
}

/// Real time passes (file reads, isolates, the Kotlin side) while frames draw.
Future<void> settle(WidgetTester tester, Duration d) async {
  final DateTime end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

Future<void> until(WidgetTester tester, bool Function() ok, String what, {int seconds = 30}) async {
  final DateTime end = DateTime.now().add(Duration(seconds: seconds));
  while (!ok()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

Future<void> open(WidgetTester tester, String name) async {
  final BuildContext context = tester.element(find.byType(Scaffold).first);
  unawaited(openDocument(context, DocRef(uri: 'file://$fx/$name', name: name, size: File('$fx/$name').lengthSync())));
  await settle(tester, const Duration(milliseconds: 300));
}

Future<void> close(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await settle(tester, const Duration(seconds: 1));
}

Finder button(String label) => find.byWidgetPredicate((Widget w) => w is AppIconButton && w.semanticLabel == label);

/// The reader's overflow menu, showing the chrome first if it's hidden.
Future<void> overflow(WidgetTester tester, String item) async {
  if (button('More options').hitTestable().evaluate().isEmpty) {
    await tester.tapAt(tester.getCenter(find.byType(ReaderView)));
    await settle(tester, const Duration(milliseconds: 600));
  }
  await tester.tap(button('More options'));
  await settle(tester, const Duration(milliseconds: 600));
  await tester.tap(find.text(item).last);
  await settle(tester, const Duration(milliseconds: 600));
}

ReaderController reader(WidgetTester tester) => tester.widget<ReaderView>(find.byType(ReaderView)).controller;

/// Global index of the last character on screen.
int lastIndex(ReaderController c) => c.doc.sections[c.lastVisible.$1].blocks[c.lastVisible.$2].start + c.lastVisible.$3;

/// What Kotlin would send when a volume key is pressed with paging on.
Future<void> volumeKey(WidgetTester tester, int delta) => tester.binding.defaultBinaryMessenger.handlePlatformMessage(
  'unfurl/platform',
  const StandardMethodCodec().encodeMethodCall(MethodCall('volumeKey', delta)),
  (_) {},
);
