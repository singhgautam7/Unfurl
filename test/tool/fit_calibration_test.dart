// Calibrates the quote's share of the card against board 6's fitted examples
// (run on demand with --dart-define=CALIBRATE=true).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/features/cards/share_card.dart';

const bool run = bool.fromEnvironment('CALIBRATE');
const String mid =
    'It is a truth universally acknowledged, that a single man in possession of a good fortune, must be in want of a wife.';
const String long =
    'But the effect of her being on those around her was incalculably diffusive: for the growing good of the world is partly dependent on unhistoric acts; and that things are not so ill with you and me as they might have been, is half owing to the number who lived faithfully a hidden life, and rest in unvisited tombs.';

void main() {
  testWidgets('calibrate', (WidgetTester tester) async {
    if (!run) return;
    for (final (String f, String a) in <(String, String)>[
      ('Literata', 'assets/fonts/literata/Literata-Italic.ttf'),
      ('LiterataR', 'assets/fonts/literata/Literata.ttf'),
      ('Instrument Sans', 'assets/fonts/instrument_sans/InstrumentSans-Variable.ttf'),
    ]) {
      await (FontLoader(f)..addFont(rootBundle.load(a))).load();
    }
    TextStyle lit({bool italic = false}) => TextStyle(fontFamily: italic ? 'Literata' : 'LiterataR', height: 1.45);
    const TextStyle sans = TextStyle(fontFamily: 'Instrument Sans', height: 1.22, fontWeight: FontWeight.w600);
    // (case, text, style, width, card height, max, spec size)
    final List<(String, String, TextStyle, double, double, double, double)> cases =
        <(String, String, TextStyle, double, double, double, double)>[
          ('classic 1:1', mid, lit(italic: true), 888, 1080, 64, 56),
          ('bold 4:5', mid, sans, 888, 1350, 72, 60),
          ('cover 1:1', mid, lit(), 888, 1080, 64, 48),
          ('long classic 4:5', long, lit(italic: true), 888, 1350, 72, 34),
          ('long margin 9:16', long, lit(), 821, 1920, 84, 40),
          ('long margin 1:1', long, lit(), 821, 1080, 64, 30),
          ('short bold 9:16', 'Simplify, simplify.', sans, 888, 1920, 84, 84),
        ];
    for (final double frac in <double>[0.2, 0.22, 0.24, 0.26, 0.28, 0.3, 0.32]) {
      final StringBuffer b = StringBuffer('frac $frac:');
      double err = 0;
      for (final (String name, String q, TextStyle s, double w, double h, double max, double spec) in cases) {
        final double target = h * frac;
        final ({double size, bool fits}) r = fitQuote(q, s, Size(w, target), maxPx: max);
        err += (r.size - spec).abs();
        b.write(' $name=${r.size.round()}${r.fits ? '' : '!'}(${spec.round()})');
      }
      debugPrint('$b  err=${err.round()}');
    }
  });
}
