import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/db/database.dart';
import 'package:unfurl/core/providers.dart';
import 'package:unfurl/design_system/chips.dart';
import 'package:unfurl/design_system/containers.dart';
import 'package:unfurl/features/notes/notes_screen.dart';

import 'lists_harness.dart';

Override notesFrom(Stream<List<(Annotation, Document?)>> s) => allAnnotationsProvider.overrideWith((Ref ref) => s);

List<(Annotation, Document?)> marks(int n, {String kind = 'highlight'}) => <(Annotation, Document?)>[
  for (int i = 0; i < n; i++) (annotationRow(i, kind: kind), null),
];

void main() {
  testWidgets('no empty state until the first value, then it appears for an empty library', (WidgetTester t) async {
    final StreamController<List<(Annotation, Document?)>> c = StreamController<List<(Annotation, Document?)>>();
    addTearDown(c.close);
    await pumpScreen(t, const NotesScreen(), overrides: <Override>[notesFrom(c.stream)]);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Nothing marked yet'), findsNothing);
    c.add(const <(Annotation, Document?)>[]);
    await t.pumpAndSettle();
    expect(find.text('Nothing marked yet'), findsOneWidget);
  });

  testWidgets('a filter keeps the rows that stay and the chips mounted', (WidgetTester t) async {
    await pumpScreen(
      t,
      const NotesScreen(),
      size: const Size(400, 3000),
      overrides: <Override>[notesFrom(Stream<List<(Annotation, Document?)>>.value(marks(20)))],
    );
    await t.pumpAndSettle();
    final Element row = t.element(find.byKey(const ValueKey<int>(4)));
    final Element yellow = t.element(find.widgetWithText(PillChip, 'Yellow'));
    final Element green = t.element(find.widgetWithText(PillChip, 'Green'));
    expect(find.byKey(const ValueKey<int>(5)), findsOneWidget);

    await t.tap(find.widgetWithText(PillChip, 'Yellow'));
    await t.pump();
    // Never blank: the surviving rows are on screen in the very next frame.
    expect(find.byType(ListGroupRow), findsWidgets);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey<int>(5)), findsNothing, reason: 'a green-less row left');
    expect(identical(t.element(find.byKey(const ValueKey<int>(4))), row), isTrue, reason: 'same row element');
    expect(identical(t.element(find.widgetWithText(PillChip, 'Yellow')), yellow), isTrue);
    expect(identical(t.element(find.widgetWithText(PillChip, 'Green')), green), isTrue);
  });

  testWidgets('400 highlights of one book build lazily', (WidgetTester t) async {
    await pumpScreen(
      t,
      const NotesScreen(),
      size: const Size(360, 640),
      overrides: <Override>[notesFrom(Stream<List<(Annotation, Document?)>>.value(marks(400)))],
    );
    await t.pumpAndSettle();
    final int built = t.widgetList(find.byType(ListGroupRow)).length;
    expect(built, greaterThan(0));
    expect(built, lessThan(60));
  });

  testWidgets('renders without overflow at text scale 2.0 on 360x640', (WidgetTester t) async {
    await pumpScreen(
      t,
      const NotesScreen(),
      size: const Size(360, 640),
      textScale: 2,
      overrides: <Override>[notesFrom(Stream<List<(Annotation, Document?)>>.value(marks(6)))],
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byType(ListGroupRow), findsWidgets);
  });
}
