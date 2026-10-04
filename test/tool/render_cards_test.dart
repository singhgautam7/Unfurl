// Renders each card template to PNG for a side-by-side check against board 6
// (run on demand: `flutter test test/tool/render_cards_test.dart --dart-define=CARDS_OUT=<dir>`).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/core/theme/reading_theme.dart';
import 'package:unfurl/features/cards/share_card.dart';
import 'package:unfurl/features/reader/reading_prefs.dart';

const String out = String.fromEnvironment('CARDS_OUT');
const String mid =
    'It is a truth universally acknowledged, that a single man in possession of a good fortune, must be in want of a wife.';
const String long =
    'But the effect of her being on those around her was incalculably diffusive: for the growing good of the world is partly dependent on unhistoric acts; and that things are not so ill with you and me as they might have been, is half owing to the number who lived faithfully a hidden life, and rest in unvisited tombs.';

Future<void> load(String family, List<String> files) async {
  final FontLoader l = FontLoader(family);
  for (final String f in files) {
    l.addFont(rootBundle.load(f));
  }
  await l.load();
}

void main() {
  testWidgets('render templates', (WidgetTester tester) async {
    if (out.isEmpty) return;
    await load('Literata', <String>['assets/fonts/literata/Literata.ttf', 'assets/fonts/literata/Literata-Italic.ttf']);
    await load('Instrument Sans', <String>['assets/fonts/instrument_sans/InstrumentSans-Variable.ttf']);
    await load('Atkinson Hyperlegible Next', <String>['assets/fonts/atkinson/AtkinsonHyperlegibleNext.ttf']);
    const ThemeFamily f = ThemeFamily.saffron;
    const CardContent pride = CardContent(
      quote: mid,
      title: 'Pride and Prejudice',
      author: 'Jane Austen',
      location: 'Ch. 1 · p. 3',
    );
    final List<(String, CardContent, CardStyle, CardPalette)> cards = <(String, CardContent, CardStyle, CardPalette)>[
      ('classic', pride, const CardStyle(), CardSpec.theme(f, ReadingThemeId.sepia)),
      ('bold', pride, const CardStyle(template: CardTemplate.bold, font: ReaderFont.instrument), CardSpec.accent(f, 2)),
      (
        'margin',
        pride,
        const CardStyle(template: CardTemplate.margin, font: ReaderFont.atkinson),
        CardSpec.theme(f, ReadingThemeId.dark),
      ),
      ('cover', pride, const CardStyle(template: CardTemplate.cover), CardSpec.cover(0xFF7A3B2E, 0)),
      (
        'long45',
        const CardContent(quote: long, title: 'Middlemarch', author: 'George Eliot', location: 'Finale · p. 838'),
        const CardStyle(ratio: CardRatio.portrait),
        CardSpec.theme(f, ReadingThemeId.light),
      ),
    ];
    for (final (String name, CardContent content, CardStyle style, CardPalette palette) in cards) {
      final GlobalKey key = GlobalKey();
      tester.view.physicalSize = style.ratio.size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: ShareCard(content: content, style: style, palette: palette),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final RenderRepaintBoundary b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final ui.Image img = await b.toImage();
        final ByteData? png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/card-$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    tester.view.reset();
  });
}
