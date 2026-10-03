import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/features/reader/read_aloud.dart';

void main() {
  test('sentences skip titles and initials', () {
    const String t = 'Mr. Bennet was among the earliest of those who waited on Mr. Bingley. J. Austen wrote it. Done!';
    final List<String> s = <String>[for (final (int a, int b) in ReadAloud.segment(t)) t.substring(a, b)];
    expect(s, <String>[
      'Mr. Bennet was among the earliest of those who waited on Mr. Bingley.',
      'J. Austen wrote it.',
      'Done!',
    ]);
  });
}
