import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/core/theme/reading_theme.dart';

import 'tokens_expected.dart';

/// The token layer ports `unfurl-tokens.js`' formulas; these pin it to the
/// spec's generated `tokens.json` so a formula drift is a test failure.
void main() {
  String hex(Color c) => c.toARGB32().toRadixString(16).toUpperCase();

  test('chrome roles match tokens.json in every tone', () {
    for (final Tone tone in Tone.values) {
      final UnfurlColors c = ThemeFamily.saffron.colors(tone);
      final Map<String, Color> actual = <String, Color>{
        'surface': c.surface,
        'surfaceContainer': c.surfaceContainer,
        'surfaceContainerHigh': c.surfaceContainerHigh,
        'outline': c.outline,
        'divider': c.divider,
        'onSurface': c.onSurface,
        'onSurfaceVariant': c.onSurfaceVariant,
        'onSurfaceMuted': c.onSurfaceMuted,
        'icon': c.icon,
        'iconMuted': c.iconMuted,
        'primary': c.primary,
        'primaryPressed': c.primaryPressed,
        'primaryContainer': c.primaryContainer,
        'onPrimary': c.onPrimary,
        'onPrimaryContainer': c.onPrimaryContainer,
        'accent': c.accent,
        'success': c.success,
        'danger': c.danger,
        'dangerContainer': c.dangerContainer,
        'onDangerContainer': c.onDangerContainer,
        'inverseSurface': c.inverseSurface,
        'onInverseSurface': c.onInverseSurface,
      };
      chromeHex[tone.name]!.forEach((String role, int expected) {
        expect(hex(actual[role]!), expected.toRadixString(16).toUpperCase(), reason: '${tone.name}.$role');
      });
    }
  });

  test('reading surfaces and highlights match tokens.json', () {
    for (final ReadingThemeId id in ReadingThemeId.values) {
      final ReadingTheme r = ReadingTheme.of(ThemeFamily.saffron, id);
      final Map<String, int> e = readingHex[id.name]!;
      expect(hex(r.paper), e['paper']!.toRadixString(16).toUpperCase(), reason: '${id.name}.paper');
      expect(hex(r.ink), e['ink']!.toRadixString(16).toUpperCase(), reason: '${id.name}.ink');
      expect(hex(r.inkMuted), e['inkMuted']!.toRadixString(16).toUpperCase(), reason: '${id.name}.inkMuted');
      expect(hex(r.rule), e['rule']!.toRadixString(16).toUpperCase(), reason: '${id.name}.rule');
      expect(hex(r.handle), e['handle']!.toRadixString(16).toUpperCase(), reason: '${id.name}.handle');
      expect(hex(r.accentText), e['accentText']!.toRadixString(16).toUpperCase(), reason: '${id.name}.accentText');
      expect(
        r.highlights.map(hex).toList(),
        highlightHex[id.name]!.map((int v) => v.toRadixString(16).toUpperCase()).toList(),
        reason: '${id.name} highlights',
      );
    }
  });

  test('typographic cover backgrounds match tokens.json', () {
    expect(
      CoverColors.all.map((CoverColors c) => hex(c.background)).toList(),
      coverBgHex.map((int v) => v.toRadixString(16).toUpperCase()).toList(),
    );
  });

  test('dynamic colour replaces only the primary hue', () {
    final ThemeFamily f = ThemeFamily.fromSeed(const Color(0xFF3367D6));
    expect(f.neutralHue, ThemeFamily.saffron.neutralHue);
    expect(f.primaryChroma, 0.11);
    expect(f.primaryHue, isNot(ThemeFamily.saffron.primaryHue));
  });
}
