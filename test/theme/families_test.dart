import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/theme/palette.dart';

void main() {
  test('family ids are unique', () {
    final List<String> ids = ThemeFamily.all.map((ThemeFamily f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('existing ids keep their order at the start of the list', () {
    const List<String> original = <String>[
      'saffron', 'mull', 'kuber', 'vellum', 'foxglove', 'slate', 'clay', 'perch', 'ember', //
      'fern', 'azure', 'tide', 'meadow', 'blush', 'iris', 'coral', 'citron', 'neon',
    ];
    expect(ThemeFamily.all.take(original.length).map((ThemeFamily f) => f.id).toList(), original);
    expect(ThemeFamily.all.skip(original.length).map((ThemeFamily f) => f.id).toList(), <String>[
      'sky',
      'ruby',
      'signature',
    ]);
  });

  test('new families build every tone', () {
    for (final ThemeFamily f in <ThemeFamily>[ThemeFamily.sky, ThemeFamily.ruby, ThemeFamily.signature]) {
      for (final Tone tone in Tone.values) {
        for (final bool expressive in <bool>[true, false]) {
          expect(() => f.colors(tone, expressive: expressive), returnsNormally, reason: '${f.id} ${tone.name}');
        }
      }
    }
    expect(Tone.values.map((Tone t) => t.name), containsAll(<String>['light', 'dark']));
  });
}
