import 'package:flutter/material.dart';

import 'oklch.dart';

/// How dark the chrome is. AMOLED is not a mode: it is a true-black toggle
/// that only applies while dark is in effect.
enum Tone { light, dark, amoled }

/// The chrome role tokens (board 1, section 2). Nothing in a screen names a
/// raw colour, so a theme swap is one map replacement. Chrome roles never
/// paint a reading page; that is [ReadingTheme]'s job.
@immutable
class UnfurlColors extends ThemeExtension<UnfurlColors> {
  const UnfurlColors({
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.outline,
    required this.divider,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onSurfaceMuted,
    required this.icon,
    required this.iconMuted,
    required this.primary,
    required this.primaryPressed,
    required this.primaryContainer,
    required this.onPrimary,
    required this.onPrimaryContainer,
    required this.accent,
    required this.success,
    required this.danger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.shadow,
    required this.scrim,
    required this.tone,
  });

  /// Page background.
  final Color surface;

  /// Cards, rows, sheets.
  final Color surfaceContainer;

  /// Chips, fields, round icon buttons.
  final Color surfaceContainerHigh;

  /// 1px borders. Depth lives here.
  final Color outline;

  /// Hairline between rows inside one container.
  final Color divider;
  final Color onSurface;

  /// Secondary labels, counts.
  final Color onSurfaceVariant;

  /// Disabled labels.
  final Color onSurfaceMuted;

  /// Top-bar icon actions.
  final Color icon;

  /// Inactive nav glyphs, a step lighter than [icon].
  final Color iconMuted;

  /// Progress, the active indicator, handles.
  final Color primary;
  final Color primaryPressed;

  /// Selected tab, selected chip.
  final Color primaryContainer;
  final Color onPrimary;
  final Color onPrimaryContainer;

  /// Accent-coloured text and icons sitting directly on a surface.
  final Color accent;
  final Color success;
  final Color danger;

  /// The tinted well behind a destructive row.
  final Color dangerContainer;
  final Color onDangerContainer;

  /// The undo strip and the scrubber bubble.
  final Color inverseSurface;
  final Color onInverseSurface;

  /// Only the nav pill casts one.
  final Color shadow;

  /// Behind a sheet or dialog.
  final Color scrim;
  final Tone tone;

  bool get isDark => tone != Tone.light;

  @override
  UnfurlColors copyWith() => this;

  @override
  UnfurlColors lerp(ThemeExtension<UnfurlColors>? other, double t) {
    if (other is! UnfurlColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return UnfurlColors(
      surface: l(surface, other.surface),
      surfaceContainer: l(surfaceContainer, other.surfaceContainer),
      surfaceContainerHigh: l(surfaceContainerHigh, other.surfaceContainerHigh),
      outline: l(outline, other.outline),
      divider: l(divider, other.divider),
      onSurface: l(onSurface, other.onSurface),
      onSurfaceVariant: l(onSurfaceVariant, other.onSurfaceVariant),
      onSurfaceMuted: l(onSurfaceMuted, other.onSurfaceMuted),
      icon: l(icon, other.icon),
      iconMuted: l(iconMuted, other.iconMuted),
      primary: l(primary, other.primary),
      primaryPressed: l(primaryPressed, other.primaryPressed),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimary: l(onPrimary, other.onPrimary),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      accent: l(accent, other.accent),
      success: l(success, other.success),
      danger: l(danger, other.danger),
      dangerContainer: l(dangerContainer, other.dangerContainer),
      onDangerContainer: l(onDangerContainer, other.onDangerContainer),
      inverseSurface: l(inverseSurface, other.inverseSurface),
      onInverseSurface: l(onInverseSurface, other.onInverseSurface),
      shadow: l(shadow, other.shadow),
      scrim: l(scrim, other.scrim),
      tone: t < 0.5 ? tone : other.tone,
    );
  }
}

/// One accent family, derived in OKLCH with Mull's role formulas unchanged
/// (`unfurl-tokens.js` `chrome()`). Only the parameters are stored. Saffron
/// is Unfurl's; the rest are Mull's families, picked in Settings › Theme.
@immutable
class ThemeFamily {
  const ThemeFamily({
    required this.id,
    required this.name,
    required this.blurb,
    required this.neutralHue,
    required this.primaryHue,
    required this.primaryLightness,
    required this.primaryChroma,
    required this.primaryContainerChroma,
    this.neutralChroma = 1,
    this.hasAmoled = true,
    this.lightSurfaceSink = 0,
    double? darkNeutralChroma,
  }) : darkNeutralChroma = darkNeutralChroma ?? neutralChroma;

  final String id;
  final String name;
  final String blurb;

  /// Multiplier on the reference neutral chromas (1 for Saffron).
  final double neutralChroma;

  /// The neutral multiplier in dark (Mull's Clay).
  final double darkNeutralChroma;

  /// How far below the shared construction the light surfaces sit (Clay).
  final double lightSurfaceSink;

  /// Shown as "true black" on the family card, as in Mull.
  final bool hasAmoled;

  final double neutralHue;
  final double primaryHue;
  final double primaryLightness;
  final double primaryChroma;
  final double primaryContainerChroma;

  /// The design decision: warm orange-gold, light #A15800, dark #DB9B63.
  static const ThemeFamily saffron = ThemeFamily(
    id: 'saffron',
    name: 'Saffron',
    blurb: 'default',
    neutralHue: 70,
    primaryHue: 62,
    primaryLightness: 0.535,
    primaryChroma: 0.13,
    primaryContainerChroma: 0.055,
  );

  /// Dynamic colour: only the wallpaper hue replaces [primaryHue], with
  /// chroma pinned at 0.11, exactly as Mull does. The neutrals stay warm.
  static ThemeFamily fromSeed(Color seed) => ThemeFamily(
    id: 'dynamic',
    name: 'Dynamic',
    blurb: 'wallpaper',
    neutralHue: saffron.neutralHue,
    primaryHue: Oklch.hueOf(seed),
    primaryLightness: saffron.primaryLightness,
    primaryChroma: 0.11,
    primaryContainerChroma: saffron.primaryContainerChroma,
  );

  // Mull's families, as Mull defines them.
  static const ThemeFamily mull = ThemeFamily(
    id: 'mull',
    name: 'Mull',
    blurb: 'from Mull',
    neutralHue: 215,
    neutralChroma: 1,
    primaryHue: 215,
    primaryLightness: 0.52,
    primaryChroma: 0.11,
    primaryContainerChroma: 0.04,
    hasAmoled: true,
  );

  static const ThemeFamily vellum = ThemeFamily(
    id: 'vellum',
    name: 'Vellum',
    blurb: 'warm',
    neutralHue: 80,
    neutralChroma: 1.3,
    primaryHue: 70,
    primaryLightness: 0.58,
    primaryChroma: 0.10,
    primaryContainerChroma: 0.04,
    hasAmoled: false,
  );

  static const ThemeFamily foxglove = ThemeFamily(
    id: 'foxglove',
    name: 'Foxglove',
    blurb: 'soft',
    neutralHue: 330,
    neutralChroma: 1.05,
    primaryHue: 325,
    primaryLightness: 0.55,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.04,
    hasAmoled: false,
  );

  static const ThemeFamily slate = ThemeFamily(
    id: 'slate',
    name: 'Slate',
    blurb: 'mono',
    neutralHue: 215,
    neutralChroma: 0.4,
    primaryHue: 215,
    primaryLightness: 0.42,
    primaryChroma: 0.012,
    primaryContainerChroma: 0.006,
    hasAmoled: true,
  );

  /// The warm greige behind the pass 02 widget mock-ups. Neutral-led: the
  /// accent stays low chroma so the surfaces carry the character.
  static const ThemeFamily clay = ThemeFamily(
    id: 'clay',
    name: 'Clay',
    blurb: 'greige',
    neutralHue: 75,
    neutralChroma: 2.2,
    primaryHue: 45,
    primaryLightness: 0.50,
    primaryChroma: 0.055,
    primaryContainerChroma: 0.02,
    hasAmoled: false,
    lightSurfaceSink: 0.025,
    darkNeutralChroma: 1.2,
  );

  // Perch's families, at Mull's chroma so they sit in the same register.
  static const ThemeFamily perch = ThemeFamily(
    id: 'perch',
    name: 'Perch',
    blurb: 'violet',
    neutralHue: 265,
    neutralChroma: 1,
    primaryHue: 265,
    primaryLightness: 0.52,
    primaryChroma: 0.11,
    primaryContainerChroma: 0.04,
    hasAmoled: true,
  );

  static const ThemeFamily ember = ThemeFamily(
    id: 'ember',
    name: 'Ember',
    blurb: 'amber',
    neutralHue: 55,
    neutralChroma: 1.35,
    primaryHue: 45,
    primaryLightness: 0.58,
    primaryChroma: 0.11,
    primaryContainerChroma: 0.04,
    hasAmoled: false,
  );

  static const ThemeFamily fern = ThemeFamily(
    id: 'fern',
    name: 'Fern',
    blurb: 'cool green',
    neutralHue: 160,
    neutralChroma: 1.15,
    primaryHue: 162,
    primaryLightness: 0.54,
    primaryChroma: 0.10,
    primaryContainerChroma: 0.04,
    hasAmoled: false,
  );

  // Dally's accents as families, each keyed by the oklch hue of its light
  // accent. Ink, Paper and Void are Azure in dark, light and true black,
  // which in Mull are tones, not families.
  static const ThemeFamily azure = ThemeFamily(
    id: 'azure',
    name: 'Azure',
    blurb: 'blue',
    neutralHue: 259,
    neutralChroma: 1,
    primaryHue: 259,
    primaryLightness: 0.52,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.04,
    hasAmoled: true,
  );

  static const ThemeFamily tide = ThemeFamily(
    id: 'tide',
    name: 'Tide',
    blurb: 'teal',
    neutralHue: 189,
    neutralChroma: 1,
    primaryHue: 189,
    primaryLightness: 0.50,
    primaryChroma: 0.09,
    primaryContainerChroma: 0.04,
    hasAmoled: true,
  );

  static const ThemeFamily meadow = ThemeFamily(
    id: 'meadow',
    name: 'Meadow',
    blurb: 'green',
    neutralHue: 145,
    neutralChroma: 1.1,
    primaryHue: 145,
    primaryLightness: 0.52,
    primaryChroma: 0.10,
    primaryContainerChroma: 0.04,
    hasAmoled: false,
  );

  static const ThemeFamily blush = ThemeFamily(
    id: 'blush',
    name: 'Blush',
    blurb: 'rose',
    neutralHue: 359,
    neutralChroma: 1.05,
    primaryHue: 359,
    primaryLightness: 0.55,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.04,
    hasAmoled: false,
  );

  static const ThemeFamily iris = ThemeFamily(
    id: 'iris',
    name: 'Iris',
    blurb: 'purple',
    neutralHue: 290,
    neutralChroma: 1,
    primaryHue: 290,
    primaryLightness: 0.55,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.04,
    hasAmoled: true,
  );

  static const ThemeFamily coral = ThemeFamily(
    id: 'coral',
    name: 'Coral',
    blurb: 'red orange',
    neutralHue: 30,
    neutralChroma: 1.2,
    primaryHue: 30,
    primaryLightness: 0.56,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.04,
    hasAmoled: false,
  );

  static const ThemeFamily citron = ThemeFamily(
    id: 'citron',
    name: 'Citron',
    blurb: 'yellow green',
    neutralHue: 113,
    neutralChroma: 1.2,
    primaryHue: 113,
    primaryLightness: 0.55,
    primaryChroma: 0.10,
    primaryContainerChroma: 0.04,
    hasAmoled: false,
  );

  static const ThemeFamily neon = ThemeFamily(
    id: 'neon',
    name: 'Neon',
    blurb: 'vivid green',
    neutralHue: 147,
    neutralChroma: 0.8,
    primaryHue: 147,
    primaryLightness: 0.60,
    primaryChroma: 0.14,
    primaryContainerChroma: 0.05,
    hasAmoled: true,
  );

  static const List<ThemeFamily> all = <ThemeFamily>[
    saffron,
    mull,
    vellum,
    foxglove,
    slate,
    clay,
    perch,
    ember,
    fern,
    azure,
    tide,
    meadow,
    blush,
    iris,
    coral,
    citron,
    neon,
  ];

  static ThemeFamily byId(String? id) => all.firstWhere((ThemeFamily f) => f.id == id, orElse: () => saffron);

  UnfurlColors colors(Tone tone) => tone == Tone.light ? _light() : _dark(amoled: tone == Tone.amoled);

  Color _n(double l, double c) => Oklch(l, c * neutralChroma, neutralHue).toColor();
  Color _nd(double l, double c) => Oklch(l, c * darkNeutralChroma, neutralHue).toColor();
  Color _p(double l, double c) => Oklch(l, c, primaryHue).toColor();

  UnfurlColors _light() {
    final double pc = primaryChroma;
    return UnfurlColors(
      surface: _n(0.99 - lightSurfaceSink, 0.004),
      surfaceContainer: _n(0.965 - 1.6 * lightSurfaceSink, 0.008),
      surfaceContainerHigh: _n(0.935 - 2.2 * lightSurfaceSink, 0.011),
      outline: _n(0.885 - 2.2 * lightSurfaceSink, 0.012),
      divider: _n(0.92 - 1.6 * lightSurfaceSink, 0.008),
      onSurface: _n(0.20, 0.02),
      onSurfaceVariant: _n(0.52, 0.02),
      onSurfaceMuted: _n(0.62, 0.02),
      icon: _n(0.30, 0.02),
      iconMuted: _n(0.45, 0.02),
      primary: _p(primaryLightness, pc),
      primaryPressed: _p(primaryLightness - 0.07, pc - 0.01),
      primaryContainer: _p(0.92, primaryContainerChroma),
      onPrimary: const Oklch(1, 0, 0).toColor(),
      onPrimaryContainer: _p(0.38, pc),
      accent: _p(0.45, pc),
      success: const Oklch(0.55, 0.10, 145).toColor(),
      danger: const Oklch(0.55, 0.16, 25).toColor(),
      dangerContainer: const Oklch(0.97, 0.02, 25).toColor(),
      onDangerContainer: const Oklch(0.48, 0.17, 25).toColor(),
      inverseSurface: _n(0.22, 0.02),
      onInverseSurface: _n(0.97, 0.004),
      shadow: const Oklch(0.35, 0.06, 265, 0.09).toColor(),
      scrim: Oklch(0.2, 0.01, neutralHue, 0.32).toColor(),
      tone: Tone.light,
    );
  }

  UnfurlColors _dark({required bool amoled}) {
    final double pcd = primaryChroma * 0.81;
    return UnfurlColors(
      surface: amoled ? const Oklch(0, 0, 0).toColor() : _nd(0.205, 0.012),
      surfaceContainer: amoled ? _nd(0.13, 0.012) : _nd(0.255, 0.014),
      surfaceContainerHigh: amoled ? _nd(0.15, 0.012) : _nd(0.30, 0.016),
      outline: amoled ? _nd(0.30, 0.014) : _nd(0.36, 0.016),
      divider: amoled ? _nd(0.24, 0.014) : _nd(0.30, 0.014),
      onSurface: _nd(0.96, 0.005),
      onSurfaceVariant: _nd(0.72, 0.012),
      onSurfaceMuted: _nd(0.60, 0.012),
      icon: _nd(0.90, 0.008),
      iconMuted: _nd(0.72, 0.012),
      primary: _p(0.74, pcd),
      primaryPressed: _p(0.68, pcd),
      primaryContainer: _p(0.28, pcd * 0.46),
      onPrimary: _nd(0.14, 0.01),
      onPrimaryContainer: _p(0.90, pcd * 0.46),
      accent: _p(0.85, pcd * 0.69),
      success: const Oklch(0.72, 0.11, 145).toColor(),
      danger: const Oklch(0.72, 0.14, 25).toColor(),
      dangerContainer: Oklch(amoled ? 0.20 : 0.26, 0.05, 25).toColor(),
      onDangerContainer: const Oklch(0.82, 0.11, 25).toColor(),
      inverseSurface: _nd(0.93, 0.008),
      onInverseSurface: _nd(0.20, 0.02),
      shadow: const Oklch(0, 0, 0, 0.5).toColor(),
      scrim: const Oklch(0, 0, 0, 0.5).toColor(),
      tone: amoled ? Tone.amoled : Tone.dark,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeFamily &&
      other.id == id &&
      other.neutralHue == neutralHue &&
      other.primaryHue == primaryHue &&
      other.primaryLightness == primaryLightness &&
      other.primaryChroma == primaryChroma &&
      other.primaryContainerChroma == primaryContainerChroma;

  @override
  int get hashCode => Object.hash(id, neutralHue, primaryHue, primaryLightness, primaryChroma, primaryContainerChroma);
}
