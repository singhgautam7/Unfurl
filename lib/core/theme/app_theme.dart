import 'package:flutter/material.dart';

import 'palette.dart';
import 'tokens.dart';
import 'typography.dart';

/// Builds, and caches, one [ThemeData] per (family, tone). A theme is stable
/// for the life of a setting, so it is built once and handed out after that.
abstract final class AppTheme {
  static final Map<(ThemeFamily, Tone), ThemeData> _cache = <(ThemeFamily, Tone), ThemeData>{};

  static ThemeData of(ThemeFamily family, Tone tone) =>
      _cache.putIfAbsent((family, tone), () => _build(family.colors(tone)));

  static ThemeData _build(UnfurlColors c) {
    final Brightness brightness = c.isDark ? Brightness.dark : Brightness.light;
    final TextTheme text = UnfurlType.textTheme(c.onSurface, c.onSurfaceVariant);
    // Material roles are filled from the token map so any stock widget that
    // reads the ColorScheme lands on the same colours as the rest of the app.
    final ColorScheme scheme = ColorScheme.fromSeed(seedColor: c.primary, brightness: brightness).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      surface: c.surface,
      onSurface: c.onSurface,
      surfaceContainer: c.surfaceContainer,
      surfaceContainerHigh: c.surfaceContainerHigh,
      onSurfaceVariant: c.onSurfaceVariant,
      outline: c.outline,
      outlineVariant: c.divider,
      error: c.danger,
      errorContainer: c.dangerContainer,
      onErrorContainer: c.onDangerContainer,
      inverseSurface: c.inverseSurface,
      onInverseSurface: c.onInverseSurface,
      shadow: c.shadow,
      scrim: c.scrim,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surface,
      textTheme: text,
      fontFamily: UnfurlType.sans,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[c],
      // Depth lives in 1px outlines. Material's tonal elevation is off.
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: Radii.sheetR),
        showDragHandle: false,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.primaryContainer,
        selectionHandleColor: c.primary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected) ? c.onPrimary : c.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceContainerHigh,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected) ? c.primary : c.outline,
        ),
      ),
    );
  }
}

extension UnfurlThemeContext on BuildContext {
  /// The chrome role map for the active theme.
  UnfurlColors get colors => Theme.of(this).extension<UnfurlColors>()!;
}
