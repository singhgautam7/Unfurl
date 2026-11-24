import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/library/library.dart';
import 'package:unfurl/core/providers.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

/// A Library whose folder level is a stream the test drives, counting what the
/// screen asks of it.
class FakeLibrary extends Library {
  FakeLibrary(super.db);

  // ignore: close_sinks (lives as long as the test)
  final StreamController<List<(Entry, Document?)>> rows = StreamController<List<(Entry, Document?)>>.broadcast();
  int watches = 0;
  int counts = 0;

  @override
  Stream<List<(Entry, Document?)>> watchLevel(int folderId, String parent, {bool deep = false}) {
    watches++;
    return rows.stream;
  }

  @override
  Future<Map<String, (int, int)>> countsUnder(int folderId) {
    counts++;
    return Future<Map<String, (int, int)>>.value(const <String, (int, int)>{});
  }
}

Folder folderRow({int id = 1}) => Folder(
  id: id,
  uri: 'content://tree/Books',
  name: 'Books',
  path: '',
  addedAt: DateTime(2026),
  accessLost: false,
  source: 'saf',
);

Entry entryRow(int i, {String? name, bool dir = false}) {
  final String ext = i.isEven ? 'epub' : 'cbz';
  return Entry(
    id: i,
    folderId: 1,
    docId: 'd$i',
    uri: 'content://tree/Books/d$i',
    parent: '',
    name: name ?? 'b${i.toString().padLeft(4, '0')}.$ext',
    ext: dir ? '' : ext,
    isDir: dir,
    size: 1000 + i,
    modified: i,
    enriched: 1,
    hidden: false,
    source: 'saf',
  );
}

Annotation annotationRow(int i, {String fingerprint = 'fp', String kind = 'highlight'}) => Annotation(
  id: i,
  fingerprint: fingerprint,
  kind: kind,
  color: kind == 'highlight' ? i % 4 : null,
  locator: '{}',
  quote: 'Quote number $i',
  label: 'Ch. $i',
  progress: i / 1000,
  mode: 'page',
  createdAt: DateTime(2026),
);

/// [child] in the app's theme at [size] and [textScale], with [overrides].
Future<ProviderContainer> pumpScreen(
  WidgetTester t,
  Widget child, {
  Size size = const Size(400, 900),
  double textScale = 1,
  List<Override> overrides = const <Override>[],
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final SharedPreferences p = await SharedPreferences.getInstance();
  final AppDatabase db = AppDatabase(NativeDatabase.memory());
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[prefsProvider.overrideWithValue(p), databaseProvider.overrideWithValue(db), ...overrides],
  );
  addTearDown(() async {
    container.dispose();
    await db.close();
  });
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
        builder: (BuildContext context, Widget? c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: child,
      ),
    ),
  );
  return container;
}
