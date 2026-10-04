import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/design_system/chips.dart';
import 'package:unfurl/design_system/nav_pill.dart';

/// TalkBack activates a control through its semantics tap action; a
/// Semantics that excludes its children must carry that action itself.
void main() {
  testWidgets('nav tabs and segments answer TalkBack taps, one node each', (WidgetTester t) async {
    final SemanticsHandle h = t.ensureSemantics();
    int? tab;
    String? seg;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
        home: Scaffold(
          body: Column(
            children: <Widget>[
              SegmentedToggle<String>(
                options: const <(String, String, IconData?)>[('a', 'Paged', null), ('b', 'Scroll', null)],
                selected: 'a',
                onChanged: (String v) => seg = v,
              ),
              NavPill(index: 0, onSelect: (int i) => tab = i),
            ],
          ),
        ),
      ),
    );
    for (final (String label, VoidCallback check) in <(String, VoidCallback)>[
      ('Scroll', () => expect(seg, 'b')),
      ('Library', () => expect(tab, 1)),
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
      final SemanticsNode n = t.getSemantics(find.bySemanticsLabel(label));
      expect(n.getSemanticsData().hasAction(SemanticsAction.tap), isTrue, reason: label);
      t.semantics.tap(find.semantics.byLabel(label));
      await t.pump();
      check();
      expect(n.rect.height, greaterThanOrEqualTo(48), reason: '$label is a 48dp target');
    }
    h.dispose();
  });
}
