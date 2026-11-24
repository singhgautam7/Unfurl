import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/providers.dart';
import 'package:unfurl/design_system/chips.dart';
import 'package:unfurl/design_system/containers.dart';
import 'package:unfurl/design_system/covers.dart' show CoverTile;
import 'package:unfurl/features/folders/folder_screens.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

import 'lists_harness.dart';

List<(Entry, Document?)> rows(int n) => <(Entry, Document?)>[for (int i = 0; i < n; i++) (entryRow(i), null)];

/// Pumps a library folder screen fed by [lib]; [enabled] switches its tickers
/// off like a route above it does.
Future<void> pumpFolder(
  WidgetTester t,
  FakeLibrary Function(AppDatabase) make,
  ValueNotifier<bool> enabled, {
  Size size = const Size(400, 900),
  double textScale = 1,
  List<(Entry, Document?)>? first,
  bool grid = false,
}) async {
  late FakeLibrary lib;
  await pumpScreen(
    t,
    ValueListenableBuilder<bool>(
      valueListenable: enabled,
      builder: (BuildContext context, bool on, Widget? _) => TickerMode(
        enabled: on,
        child: const FolderScreen(folderId: 1, path: ''),
      ),
    ),
    size: size,
    textScale: textScale,
    prefs: <String, Object>{AppSettings.kLibraryGrid: grid},
    overrides: <Override>[
      libraryProvider.overrideWith((Ref ref) => lib = make(ref.watch(databaseProvider))),
      foldersProvider.overrideWith((Ref ref) => Stream<List<Folder>>.value(<Folder>[folderRow()])),
    ],
  );
  await t.pump();
  if (first != null) {
    lib.rows.add(first);
    await t.pump();
  }
}

void main() {
  for (final bool grid in <bool>[false, true]) {
    testWidgets('3,000 entries as a ${grid ? 'grid' : 'list'}: a filter keeps surviving rows and chips, never blanks', (
      WidgetTester t,
    ) async {
      late FakeLibrary lib;
      final ValueNotifier<bool> on = ValueNotifier<bool>(true);
      await pumpFolder(t, (db) => lib = FakeLibrary(db), on, first: rows(3000), grid: grid);
      await t.pumpAndSettle();
      expect(lib.watches, 1);
      final Key two = ValueKey<String>(entryRow(2).uri);
      final Element row = t.element(find.byKey(two));
      final Finder comics = find.widgetWithText(PillChip, 'Comics');
      final Element chip = t.element(comics);
      expect(find.byType(grid ? CoverTile : ListGroupRow), findsWidgets);

      await t.tap(find.widgetWithText(PillChip, 'EPUB'));
      await t.pump();
      expect(find.byType(grid ? CoverTile : ListGroupRow), findsWidgets, reason: 'the list is never blank');
      await t.pumpAndSettle();
      expect(find.byKey(ValueKey<String>(entryRow(3).uri)), findsNothing, reason: 'a comic left');
      expect(identical(t.element(find.byKey(two)), row), isTrue, reason: 'surviving row keeps its element');
      expect(identical(t.element(comics), chip), isTrue, reason: 'chips stay mounted');
      // Lazy, not 3,000 rows.
      expect(t.widgetList(find.byType(grid ? CoverTile : ListGroupRow)).length, lessThan(60));
    });
  }

  testWidgets('a covered screen loads and counts nothing; uncovered it catches up', (WidgetTester t) async {
    late FakeLibrary lib;
    final ValueNotifier<bool> on = ValueNotifier<bool>(true);
    await pumpFolder(t, (db) => lib = FakeLibrary(db), on, first: rows(10));
    await t.pump(const Duration(seconds: 1));
    expect(lib.watches, 1);
    expect(lib.counts, 1);

    on.value = false;
    await t.pump();
    expect(lib.rows.hasListener, isFalse, reason: 'subscription released while covered');
    for (int i = 0; i < 5; i++) {
      lib.rows.add(rows(10 + i));
    }
    await t.pump(const Duration(seconds: 1));
    expect(lib.counts, 1);
    expect(lib.watches, 1);

    on.value = true;
    await t.pump();
    expect(lib.watches, 2);
  });

  testWidgets('a burst of emissions counts at most twice', (WidgetTester t) async {
    late FakeLibrary lib;
    final ValueNotifier<bool> on = ValueNotifier<bool>(true);
    await pumpFolder(t, (db) => lib = FakeLibrary(db), on, first: rows(10));
    for (int i = 1; i <= 10; i++) {
      lib.rows.add(rows(10 + i));
      await t.pump(const Duration(milliseconds: 5));
    }
    await t.pump(const Duration(seconds: 2));
    expect(lib.counts, lessThanOrEqualTo(2));
    expect(lib.counts, greaterThanOrEqualTo(2), reason: 'a final load after the last emission');
  });

  for (final bool grid in <bool>[false, true]) {
    testWidgets('folder screen (${grid ? 'grid' : 'list'}) renders without overflow at text scale 2.0 on 360x640', (
      WidgetTester t,
    ) async {
      late FakeLibrary lib;
      final ValueNotifier<bool> on = ValueNotifier<bool>(true);
      await pumpFolder(
        t,
        (db) => lib = FakeLibrary(db),
        on,
        size: const Size(360, 640),
        textScale: 2,
        grid: grid,
        first: <(Entry, Document?)>[
          (entryRow(100, name: 'Sub folder with a long name', dir: true), null),
          ...rows(8),
        ],
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(lib.watches, 1);
    });
  }

  testWidgets('Folders renders without overflow at text scale 2.0 on 360x640', (WidgetTester t) async {
    await pumpScreen(
      t,
      const FoldersScreen(),
      size: const Size(360, 640),
      textScale: 2,
      overrides: <Override>[
        foldersProvider.overrideWith((Ref ref) => Stream<List<Folder>>.value(<Folder>[folderRow(), folderRow(id: 2)])),
        readableCountsProvider.overrideWith((Ref ref) => Stream<Map<int, int>>.value(const <int, int>{1: 12, 2: 1})),
      ],
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Add folder'), findsOneWidget);
  });
}
