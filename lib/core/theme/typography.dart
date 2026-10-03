import 'package:flutter/material.dart';

/// Chrome type: Mull's scale unchanged. One variable typeface, Instrument
/// Sans, and the platform monospace for counts, metadata and section
/// headers. Reading fonts live on the page only (Phase 3).
///
/// Instrument Sans is variable, so every weight sets `fontVariations`
/// alongside `fontWeight`. The axis is what actually moves the glyphs.
abstract final class UnfurlType {
  static const String sans = 'Instrument Sans';

  /// The platform's own monospace, `ui-monospace` on the boards.
  static const String mono = 'monospace';

  static FontWeight _fw(int weight) => FontWeight.values[weight ~/ 100 - 1];

  static TextStyle _sans(double size, double height, int weight, {double? letterSpacing}) => TextStyle(
    fontFamily: sans,
    fontSize: size,
    height: height,
    fontWeight: _fw(weight),
    fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
    letterSpacing: letterSpacing,
  );

  static TextStyle _mono(double size, int weight, {double? letterSpacing}) => TextStyle(
    fontFamily: mono,
    fontSize: size,
    height: 1.3,
    fontWeight: _fw(weight),
    letterSpacing: letterSpacing,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Display: 600 with `letter-spacing: -0.022em`. Welcome, empty states.
  static TextStyle get display => _sans(40, 1.05, 600, letterSpacing: 40 * -0.022);

  /// The smaller display step, on a folder's empty state.
  static TextStyle get displaySmall => _sans(30, 1.1, 600, letterSpacing: 30 * -0.022);

  static TextStyle get sheetTitle => _sans(22, 1.1, 400);

  /// Screen title on a tab root or pushed page.
  static TextStyle get headerTitle => _sans(22, 1.25, 600, letterSpacing: -0.2);

  /// Collapsed header.
  static TextStyle get screenTitle => _sans(19, 1.25, 600, letterSpacing: -0.19);

  static TextStyle get title => _sans(20, 1.25, 600, letterSpacing: -0.2);
  static TextStyle get body => _sans(15, 1.55, 400);

  /// Settings row, button, list row.
  static TextStyle get titleMedium => _sans(14.5, 1.3, 600);

  /// Nav label.
  static TextStyle get titleSmall => _sans(13.5, 1.3, 600);

  /// Notes, secondary body.
  static TextStyle get note => _sans(13.5, 1.65, 400);
  static TextStyle get tableCell => _sans(12.5, 1.45, 400);
  static TextStyle get bodySmall => _sans(12, 1.5, 400);
  static TextStyle get label => _sans(12, 1.3, 500);

  /// Counts, page numbers, stat figures.
  static TextStyle get monoTabular => _mono(13, 500);

  /// Metadata under a name.
  static TextStyle get monoLabel => _mono(11, 500);

  /// ALL-CAPS section headers: 600 11 · letter-spacing .08em.
  static TextStyle get sectionHeader => _mono(11, 600, letterSpacing: 0.88);

  static TextTheme textTheme(Color onSurface, Color onSurfaceVariant) => TextTheme(
    displayLarge: display.copyWith(color: onSurface),
    headlineSmall: screenTitle.copyWith(color: onSurface),
    titleLarge: title.copyWith(color: onSurface),
    titleMedium: titleMedium.copyWith(color: onSurface),
    titleSmall: titleSmall.copyWith(color: onSurface),
    bodyLarge: body.copyWith(color: onSurface),
    bodyMedium: note.copyWith(color: onSurface),
    bodySmall: bodySmall.copyWith(color: onSurfaceVariant),
    labelLarge: titleMedium.copyWith(color: onSurface),
    labelMedium: label.copyWith(color: onSurfaceVariant),
    labelSmall: monoLabel.copyWith(color: onSurfaceVariant),
  );
}

extension UnfurlTextStyle on TextStyle {
  /// Sets the weight on a variable-font style. Plain `copyWith(fontWeight:)`
  /// does nothing for Instrument Sans; the `wght` axis has to move too.
  TextStyle weight(int w) => copyWith(
    fontWeight: UnfurlType._fw(w),
    fontVariations: fontFamily == UnfurlType.sans ? <FontVariation>[FontVariation('wght', w.toDouble())] : null,
  );
}
