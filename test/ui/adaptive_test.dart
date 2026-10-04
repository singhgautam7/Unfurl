import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unfurl/app.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/providers.dart';
import 'package:unfurl/design_system/nav_pill.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

/// The app at a window size, with a folder of eight books and two highlights.
Future<void> pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{AppSettings.kOnboarded: true, AppSettings.kOpenedFile: true});
  final SharedPreferences p = await SharedPreferences.getInstance();
  final AppDatabase db = AppDatabase(NativeDatabase.memory());
  final int folder = await db
      .into(db.folders)
      .insert(FoldersCompanion.insert(uri: 'content://tree/Books', name: 'Books', addedAt: DateTime(2026)));
  for (int i = 0; i < 8; i++) {
    await db
        .into(db.entries)
        .insert(
          EntriesCompanion.insert(
            folderId: folder,
            docId: 'd$i',
            uri: 'content://tree/Books/d$i',
            parent: '',
            name: 'book-$i.epub',
            ext: 'epub',
            isDir: false,
            enriched: const Value<int>(1),
          ),
        );
  }
  await db
      .into(db.documents)
      .insert(
        DocumentsCompanion.insert(
          fingerprint: 'fp',
          uri: 'content://x',
          name: 'book-0.epub',
          format: 'epub',
          addedAt: DateTime(2026),
          title: const Value<String?>('Walden'),
        ),
      );
  for (final String q in <String>[
    'Simplify, simplify.',
    'I went to the woods because I wished to live deliberately.',
  ]) {
    await db
        .into(db.annotations)
        .insert(
          AnnotationsCompanion.insert(
            fingerprint: 'fp',
            kind: 'highlight',
            locator: '{}',
            quote: Value<String>(q),
            label: const Value<String>('Ch. 2'),
            createdAt: DateTime(2026),
          ),
        );
  }
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[prefsProvider.overrideWithValue(p), databaseProvider.overrideWithValue(db)],
  );
  addTearDown(() async {
    container.dispose();
    await db.close();
  });
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const UnfurlApp()));
  await tester.pumpAndSettle();
}

int gridColumns(WidgetTester tester) =>
    (tester.widget<SliverGrid>(find.byType(SliverGrid).first).gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
        .crossAxisCount;

void main() {
  for (final (String name, Size size, bool rail, int columns) in <(String, Size, bool, int)>[
    ('compact phone', const Size(400, 860), false, 3),
    ('medium tablet portrait', const Size(800, 1280), false, 5),
    ('expanded tablet landscape', const Size(1280, 800), true, 7),
  ]) {
    testWidgets('$name: ${rail ? 'nav rail' : 'pill'}, Library at $columns columns', (WidgetTester tester) async {
      await pumpAt(tester, size);
      expect(find.byType(NavRail), rail ? findsOneWidget : findsNothing);
      expect(find.byType(NavPill), rail ? findsNothing : findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Library').first);
      await tester.pumpAndSettle();
      expect(gridColumns(tester), columns);
    });
  }

  testWidgets('expanded: More is centred at 720dp; Notes is list and detail', (WidgetTester tester) async {
    await pumpAt(tester, const Size(1280, 800));
    await tester.tap(find.bySemanticsLabel('More').first);
    await tester.pumpAndSettle();
    final Rect settings = tester.getRect(find.text('Settings').first);
    // Content column: 720 wide, centred in the space right of the 80dp rail.
    expect(settings.left, greaterThan(80 + (1200 - 720) / 2 - 1));
    await tester.tap(find.bySemanticsLabel('Notes').first);
    await tester.pumpAndSettle();
    // The first note is open beside the list, large.
    expect(find.text('“Simplify, simplify.”'), findsOneWidget);
    await tester.tap(find.textContaining('I went to the woods').first);
    await tester.pumpAndSettle();
    expect(find.text('“I went to the woods because I wished to live deliberately.”'), findsOneWidget);
  });
}
