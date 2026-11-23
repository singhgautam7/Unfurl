// What rebuilds on a tab switch and on a scroll: a broad watch or a setState
// on scroll shows up here as a screen's own widget in the list.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/providers.dart';
import 'package:unfurl/features/home/home_screen.dart';
import 'package:unfurl/features/library/library_screen.dart';
import 'package:unfurl/features/notes/notes_screen.dart';
import 'package:unfurl/features/settings/more_screen.dart';

import '../ui/shell_test.dart' show pumpApp;

Future<Map<String, int>> counted(Future<void> Function() action) async {
  final Map<String, int> counts = <String, int>{};
  debugOnRebuildDirtyWidget = (Element e, bool _) {
    counts.update('${e.widget.runtimeType}', (int n) => n + 1, ifAbsent: () => 1);
  };
  await action();
  debugOnRebuildDirtyWidget = null;
  return counts;
}

void main() {
  testWidgets('tab switches and scrolls rebuild no screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await pumpApp(tester);
    final AppDatabase db = container.read(databaseProvider);
    final int folder = await db
        .into(db.folders)
        .insert(FoldersCompanion.insert(uri: 'content://tree/Books', name: 'Books', addedAt: DateTime(2026)));
    await db.batch((b) {
      for (int i = 0; i < 300; i++) {
        b.insert(
          db.entries,
          EntriesCompanion.insert(
            folderId: folder,
            docId: 'd$i',
            uri: 'content://tree/Books/d$i',
            parent: '',
            name: 'Book $i.pdf',
            ext: 'pdf',
            isDir: false,
          ),
        );
      }
    });
    // Every tab is warm.
    for (final String tab in <String>['Library', 'Notes', 'More', 'Home']) {
      await tester.tap(find.bySemanticsLabel(tab));
      await tester.pumpAndSettle();
    }
    const List<Type> screens = <Type>[HomeScreen, LibraryScreen, NotesScreen, MoreScreen];
    final Map<String, int> tabs = await counted(() async {
      for (final String tab in <String>['Library', 'Notes', 'More', 'Home']) {
        await tester.tap(find.bySemanticsLabel(tab));
        await tester.pumpAndSettle();
      }
    });
    // ignore: avoid_print
    print('rebuilds, 4 tab switches: $tabs');
    for (final Type t in screens) {
      expect(tabs['$t'] ?? 0, 0, reason: '$t rebuilt on a tab switch');
    }

    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pumpAndSettle();
    final Map<String, int> scroll = await counted(() async {
      for (int i = 0; i < 4; i++) {
        await tester.fling(find.byType(CustomScrollView).first, const Offset(0, -600), 2500);
        await tester.pumpAndSettle();
      }
    });
    // ignore: avoid_print
    print('rebuilds, 4 Library flings: $scroll');
    for (final Type t in screens) {
      expect(scroll['$t'] ?? 0, 0, reason: '$t rebuilt while scrolling');
    }
  });
}
