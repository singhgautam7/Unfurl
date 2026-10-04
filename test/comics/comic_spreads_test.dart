import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/features/comics/comic_prefs.dart';

void main() {
  test('spreads: the cover alone, pages in pairs, a wide page alone', () {
    expect(comicSpreads(6, coverAlone: true, wide: (_) => false), <List<int>>[
      <int>[0],
      <int>[1, 2],
      <int>[3, 4],
      <int>[5],
    ]);
    expect(comicSpreads(4, coverAlone: false, wide: (_) => false), <List<int>>[
      <int>[0, 1],
      <int>[2, 3],
    ]);
    // Page 2 is a double-page scan: it stands alone and pairing resumes after it.
    expect(comicSpreads(6, coverAlone: true, wide: (int i) => i == 2), <List<int>>[
      <int>[0],
      <int>[1],
      <int>[2],
      <int>[3, 4],
      <int>[5],
    ]);
    expect(comicSpreads(0, coverAlone: true, wide: (_) => false), isEmpty);
  });
}
