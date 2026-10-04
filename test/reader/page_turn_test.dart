import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/features/reader/engine/page_turn.dart';
import 'package:unfurl/features/reader/reading_prefs.dart';

void main() {
  test('reduced motion: Curl and Cover fade, Slide stops', () {
    expect(PageTurn.curl.effective(reduced: true), PageTurn.fade);
    expect(PageTurn.cover.effective(reduced: true), PageTurn.fade);
    expect(PageTurn.slide.effective(reduced: true), PageTurn.none);
    expect(PageTurn.curl.effective(reduced: false), PageTurn.curl);
  });

  for (final PageTurn style in <PageTurn>[PageTurn.curl, PageTurn.cover]) {
    testWidgets('${style.label}: a drag turns forward and back, a short one springs back', (WidgetTester t) async {
      int index = 1;
      final List<int> turned = <int>[];
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
          home: StatefulBuilder(
            builder: (BuildContext context, StateSetter set) => TurnPager(
              style: style,
              index: index,
              count: 3,
              backFace: Colors.white,
              builder: (int i) => ColoredBox(
                color: Colors.white,
                child: Center(child: Text('page $i')),
              ),
              onTurned: (int i) => set(() {
                turned.add(i);
                index = i;
              }),
            ),
          ),
        ),
      );
      await t.drag(find.text('page 1'), const Offset(-500, 0));
      await t.pumpAndSettle();
      expect(turned, <int>[2]);
      expect(find.text('page 2'), findsOneWidget);
      expect(find.text('page 1'), findsNothing);

      await t.drag(find.text('page 2'), const Offset(30, 0));
      await t.pumpAndSettle();
      expect(turned, <int>[2], reason: 'a short slow drag settles back');

      await t.drag(find.text('page 2'), const Offset(500, 0));
      await t.pumpAndSettle();
      expect(turned, <int>[2, 1]);

      await t.drag(find.text('page 1'), const Offset(500, 0));
      await t.drag(find.text('page 1'), const Offset(500, 0));
      await t.pumpAndSettle();
      expect(turned.last, 0);
      await t.drag(find.text('page 0'), const Offset(500, 0));
      await t.pumpAndSettle();
      expect(turned.last, 0, reason: 'nothing before the first page');
    });
  }
}
