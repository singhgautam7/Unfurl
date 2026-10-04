import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unfurl/core/theme/app_theme.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/core/theme/reading_theme.dart';
import 'package:unfurl/features/cards/card_editor.dart';
import 'package:unfurl/features/cards/share_card.dart';
import 'package:unfurl/features/settings/settings_controller.dart';

const String longQuote =
    'But the effect of her being on those around her was incalculably diffusive: for the growing good of the world is '
    'partly dependent on unhistoric acts; and that things are not so ill with you and me as they might have been, is '
    'half owing to the number who lived faithfully a hidden life, and rest in unvisited tombs.';

void main() {
  group('auto-fit', () {
    const TextStyle style = TextStyle(fontSize: 10, height: 1.45);

    test('a short quote stays at the ratio\'s maximum', () {
      final ({double size, bool fits}) f = fitQuote('Simplify, simplify.', style, const Size(888, 600), maxPx: 84);
      expect(f, (size: 84.0, fits: true));
    });

    test('a long quote steps down in 2 px steps to the largest size that fits', () {
      const Size box = Size(888, 700);
      final ({double size, bool fits}) f = fitQuote(longQuote, style, box, maxPx: 72);
      expect(f.fits, isTrue);
      expect(f.size, lessThan(72));
      expect((f.size - 30) % 2, 0);
      // The next step up would not fit.
      final TextPainter up = TextPainter(
        text: TextSpan(
          text: longQuote,
          style: style.copyWith(fontSize: f.size + 2),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: box.width);
      expect(up.height, greaterThan(box.height));
    });

    test('past the 30 px minimum it reports that the quote must be shortened', () {
      final ({double size, bool fits}) f = fitQuote(longQuote * 3, style, const Size(888, 400), maxPx: 64);
      expect(f, (size: 30.0, fits: false));
    });
  });

  group('contrast', () {
    test('ink reads on every background in every family: 4.5:1 for the quote, 3:1 for the muted line', () {
      for (final ThemeFamily f in ThemeFamily.all) {
        final List<CardPalette> all = <CardPalette>[
          for (final ReadingThemeId id in CardSpec.themes) CardSpec.theme(f, id),
          for (int k = 0; k < 4; k++) CardSpec.accent(f, k),
          for (final int seed in <int>[0xFF8B1E2D, 0xFF1E5A8B, 0xFFE8C547, 0xFF2E7D32, 0xFF101010, 0xFFF5F5F5])
            for (int k = 0; k < 3; k++) CardSpec.cover(seed, k),
        ];
        for (final CardPalette p in all) {
          expect(contrast(p.ink, p.background), greaterThanOrEqualTo(4.5), reason: '${f.id} ink ${p.background}');
          expect(contrast(p.muted, p.background), greaterThanOrEqualTo(3.0), reason: '${f.id} muted ${p.background}');
        }
      }
    });
  });

  testWidgets('the editor: a live preview that follows the ratio, and the shortened-quote warning', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences p = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[prefsProvider.overrideWithValue(p)],
        child: MaterialApp(
          theme: AppTheme.of(ThemeFamily.saffron, Tone.light),
          home: Scaffold(
            body: CardEditor(
              content: const CardContent(
                quote: longQuote,
                title: 'Middlemarch',
                author: 'George Eliot',
                location: 'Finale',
              ),
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Size square = tester.getSize(find.byType(FittedBox));
    expect(square.width, closeTo(square.height, 1));
    await tester.tap(find.text('9:16'));
    await tester.pumpAndSettle();
    final Size story = tester.getSize(find.byType(FittedBox));
    expect(story.height / story.width, closeTo(16 / 9, 0.02));
    expect(p.getString('card.ratio'), 'story');
    expect(find.text('Middlemarch'), findsOneWidget);
    await tester.tap(find.text('Bold'));
    await tester.pumpAndSettle();
    expect(find.text('“'), findsOneWidget);
  });
}
