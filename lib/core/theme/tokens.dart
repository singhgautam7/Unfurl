import 'package:flutter/material.dart';

/// Space, shape, icon and elevation tokens from `specs/design/unfurl-tokens.js`
/// (Mull's values plus Unfurl's `cover` and `page` radii).
///
/// Nothing in a feature names a raw size, radius or duration. It comes from
/// here, from [Motion], or from [UnfurlColors].

/// 4 · 8 · 12 · 16 · 24 · 32, plus the screen-level values.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Screen margin.
  static const double screen = 20;

  /// Gap between rows in a list.
  static const double row = 10;

  /// Gap between sections on a screen.
  static const double section = 28;

  /// Bottom padding on every scrollable so content clears the floating nav.
  static const double bottomSafe = 108;
}

/// chip 8 · thumb 14 · card 20 · sheet 28 · cover 6 · page 2 · full.
abstract final class Radii {
  static const double chip = 8;
  static const double thumb = 14;
  static const double card = 20;
  static const double sheet = 28;

  /// The full-height content card; on Unfurl, the Continue reading hero.
  static const double wordCard = 28;

  /// A book cover tile.
  static const double cover = 6;

  /// A rendered PDF page.
  static const double page = 2;
  static const double full = 999;

  static const BorderRadius chipR = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius thumbR = BorderRadius.all(Radius.circular(thumb));
  static const BorderRadius cardR = BorderRadius.all(Radius.circular(card));
  static const BorderRadius wordCardR = BorderRadius.all(Radius.circular(wordCard));
  static const BorderRadius coverR = BorderRadius.all(Radius.circular(cover));
  static const BorderRadius pageR = BorderRadius.all(Radius.circular(page));
  static const BorderRadius sheetR = BorderRadius.vertical(top: Radius.circular(sheet));
  static const BorderRadius fullR = BorderRadius.all(Radius.circular(full));
}

/// Material Symbols Rounded at weight 350, 24dp, 48dp tap target.
abstract final class IconSpec {
  static const double size = 24;

  /// The `wght` axis the boards draw every symbol at, standing in for Mull's
  /// 1.75 stroke.
  static const double weight = 350;
  static const double tapTarget = 48;

  /// The round icon button's visible disc inside its 48dp target.
  static const double button = 44;
}

/// Depth lives in 1px outlines; a shadow exists on exactly one object, the
/// nav pill. Readers add no shadows.
abstract final class Elevations {
  static const double navPill = 6;
  static const double navPillBlur = 18;
}
