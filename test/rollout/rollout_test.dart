import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unfurl/core/motion/kit.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/core/theme/reading_theme.dart';
import 'package:unfurl/features/insights/insights_data.dart';
import 'package:unfurl/features/insights/insights_widgets.dart';
import 'package:unfurl/features/reader/reading_prefs.dart';
import 'package:unfurl/features/reader/sheets.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

Widget host(Widget child, MotionLevel level, {List<Override> overrides = const <Override>[]}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
    home: MotionScope(
      level: level,
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ),
);

void main() {
  for (final MotionLevel level in MotionLevel.values) {
    group(level.name, () {
      testWidgets('stat numbers render today\'s text', (WidgetTester t) async {
        await t.pumpWidget(
          host(
            Column(
              children: <Widget>[
                StatTile(
                  label: 'Today',
                  value: formatMinutes(46 * 60000),
                  number: const InsightNumber(46 * 60000, formatMinutes),
                ),
                KeyValueCard(
                  items: const <(String, String, String?)>[('Reader mode', '230 wpm', null)],
                  numbers: <InsightNumber?>[InsightNumber(230, (int n) => '$n wpm')],
                ),
              ],
            ),
            level,
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('46 min'), findsOneWidget);
        expect(find.text('230 wpm'), findsOneWidget);
        expect(t.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('charts settle, schedule no frames, and a data change does not replay the draw-in', (
        WidgetTester t,
      ) async {
        Widget chart(List<int> v) => host(
          Column(
            children: <Widget>[
              BarChart(values: v, labels: const <String>[]),
              Heatmap(minutes: List<int?>.filled(53 * 7, 5), months: const <String>['J'], family: ThemeFamily.saffron),
            ],
          ),
          level,
        );
        await t.pumpWidget(chart(<int>[1, 2, 3]));
        await t.pumpAndSettle();
        expect(t.binding.hasScheduledFrame, isFalse);
        await t.pumpWidget(chart(<int>[3, 2, 1]));
        await t.pumpAndSettle();
        await t.pumpWidget(chart(<int>[1, 2, 3, 4, 5]));
        await t.pumpAndSettle();
        expect(t.binding.hasScheduledFrame, isFalse);
        expect(t.takeException(), isNull);
      });

      testWidgets('ChartHeader step taps', (WidgetTester t) async {
        int n = 0;
        await t.pumpWidget(
          host(ChartHeader(total: 'x', range: 'y', onBack: () => n++, onForward: () => n += 10), level),
        );
        await t.tap(find.text('‹'));
        await t.tap(find.text('›'));
        await t.pumpAndSettle();
        expect(n, 11);
      });

      testWidgets('reader sheet rows: ThemeSwatch and AlignControl taps', (WidgetTester t) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences p = await SharedPreferences.getInstance();
        int swatch = 0;
        await t.pumpWidget(
          host(
            Column(
              children: <Widget>[
                ThemeSwatch(
                  theme: ReadingTheme.of(ThemeFamily.saffron, ReadingThemeId.sepia),
                  selected: false,
                  onTap: () => swatch++,
                  semantic: 'Sepia',
                ),
                const AlignControl(),
              ],
            ),
            level,
            overrides: <Override>[prefsProvider.overrideWithValue(p)],
          ),
        );
        await t.tap(find.bySemanticsLabel('Sepia'));
        expect(swatch, 1);
        final ProviderContainer c = ProviderScope.containerOf(t.element(find.byType(AlignControl)));
        final bool before = c.read(readingPrefsProvider).justify;
        await t.tap(find.bySemanticsLabel(before ? 'Left aligned' : 'Justified'));
        await t.pumpAndSettle();
        expect(c.read(readingPrefsProvider).justify, !before);
      });
    });
  }
}
