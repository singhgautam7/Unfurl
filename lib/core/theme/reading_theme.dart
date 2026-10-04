import 'package:flutter/material.dart';

import 'oklch.dart';
import 'palette.dart';

/// The second token layer (board 1, section 3). It only ever paints the page;
/// bars, sheets and the scrubber keep the chrome tone.
///
/// Declared in picker order (v2 · V2-02); stored by name, so order is free.
enum ReadingThemeId { light, sepia, stone, sage, dusk, dark, amoled }

@immutable
class ReadingTheme {
  const ReadingTheme._({
    required this.id,
    required this.paper,
    required this.ink,
    required this.inkMuted,
    required this.rule,
    required this.handle,
    required this.accentText,
    required this.highlights,
  });

  final ReadingThemeId id;
  final Color paper;
  final Color ink;
  final Color inkMuted;
  final Color rule;

  /// Selection handles and progress on the page: the chrome primary of the
  /// tone that sits on this paper (light for Light, Sepia, Stone and Sage;
  /// dark for Dusk, Dark and AMOLED).
  final Color handle;

  /// Accent text on the page, from the same tone.
  final Color accentText;

  /// Indexed by [HighlightColor.index], re-derived per theme so ink on a
  /// highlight stays at 6:1 or better.
  final List<Color> highlights;

  static const List<String> names = <String>['Light', 'Sepia', 'Stone', 'Sage', 'Dusk', 'Dark', 'AMOLED'];

  String get name => names[id.index];

  /// One theme per (family, reading theme), built once.
  static ReadingTheme of(ThemeFamily family, ReadingThemeId id) =>
      _cache.putIfAbsent((family, id), () => _build(family, id));

  static final Map<(ThemeFamily, ReadingThemeId), ReadingTheme> _cache =
      <(ThemeFamily, ReadingThemeId), ReadingTheme>{};

  static ReadingTheme _build(ThemeFamily family, ReadingThemeId id) {
    final (Oklch paper, Oklch ink, Oklch muted, Oklch rule, Tone tone, double hlL, double hlC) = switch (id) {
      ReadingThemeId.light => (
        const Oklch(0.985, 0.004, 85),
        const Oklch(0.24, 0.012, 75),
        const Oklch(0.50, 0.012, 75),
        const Oklch(0.90, 0.008, 80),
        Tone.light,
        0.90,
        0.095,
      ),
      ReadingThemeId.sepia => (
        const Oklch(0.935, 0.032, 82),
        const Oklch(0.33, 0.035, 60),
        const Oklch(0.49, 0.035, 65),
        const Oklch(0.86, 0.035, 80),
        Tone.light,
        0.855,
        0.095,
      ),
      ReadingThemeId.stone => (
        const Oklch(0.915, 0.005, 85),
        const Oklch(0.25, 0.010, 75),
        const Oklch(0.47, 0.010, 75),
        const Oklch(0.84, 0.006, 80),
        Tone.light,
        0.86,
        0.095,
      ),
      ReadingThemeId.sage => (
        const Oklch(0.935, 0.028, 140),
        const Oklch(0.30, 0.030, 150),
        const Oklch(0.46, 0.030, 150),
        const Oklch(0.86, 0.030, 145),
        Tone.light,
        0.86,
        0.09,
      ),
      ReadingThemeId.dusk => (
        const Oklch(0.27, 0.022, 250),
        const Oklch(0.90, 0.012, 240),
        const Oklch(0.72, 0.015, 240),
        const Oklch(0.35, 0.020, 250),
        Tone.dark,
        0.415,
        0.075,
      ),
      ReadingThemeId.dark => (
        const Oklch(0.235, 0.006, 75),
        const Oklch(0.88, 0.012, 80),
        const Oklch(0.68, 0.010, 80),
        const Oklch(0.32, 0.008, 75),
        Tone.dark,
        0.40,
        0.075,
      ),
      ReadingThemeId.amoled => (
        const Oklch(0, 0, 0),
        const Oklch(0.80, 0.008, 80),
        const Oklch(0.62, 0.008, 80),
        const Oklch(0.22, 0.006, 75),
        Tone.amoled,
        0.34,
        0.075,
      ),
    };
    final UnfurlColors chrome = family.colors(tone);
    return ReadingTheme._(
      id: id,
      paper: paper.toColor(),
      ink: ink.toColor(),
      inkMuted: muted.toColor(),
      rule: rule.toColor(),
      handle: chrome.primary,
      accentText: chrome.accent,
      highlights: <Color>[for (final HighlightColor h in HighlightColor.values) Oklch(hlL, hlC, h.hue).toColor()],
    );
  }
}

/// Highlights are stored as this index, never as a colour.
enum HighlightColor {
  yellow(98, 'Yellow'),
  green(150, 'Green'),
  blue(240, 'Blue'),
  pink(352, 'Pink');

  const HighlightColor(this.hue, this.label);

  final double hue;
  final String label;
}

/// A typographic fallback cover, coloured by Mull's category hue. A book
/// stores the index, never the colour.
@immutable
class CoverColors {
  const CoverColors._(this.background, this.ink, this.rule);

  final Color background;
  final Color ink;
  final Color rule;

  static const List<double> hues = <double>[265, 200, 150, 55, 25, 340, 300];

  static final List<CoverColors> all = <CoverColors>[
    for (final double h in hues)
      CoverColors._(Oklch(0.40, 0.065, h).toColor(), Oklch(0.95, 0.025, h).toColor(), Oklch(0.72, 0.07, h).toColor()),
  ];

  static CoverColors at(int index) => all[index.abs() % all.length];
}
