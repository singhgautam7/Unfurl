import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';

/// Back, open file, overflow, search, view toggle: every round icon action
/// is this, at Mull's sizes: a 40dp `surfaceContainerHigh` disc, a 20dp
/// glyph, a 48dp target, and Mull's tooltip on long-press. Reader bars use
/// the bare variant (24dp glyph, no disc).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.filled = true,
    this.active = false,
    this.tint,
    this.fill = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Required: an icon-only control is invisible to a screen reader without it.
  final String semanticLabel;

  /// False for reader bars and in-field actions: no disc, a 24dp glyph.
  final bool filled;

  /// A toggled state (crop on, bookmarked): `primaryContainer`.
  final bool active;
  final Color? tint;

  /// The filled glyph variant.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final Color fg = tint ?? (active ? c.onPrimaryContainer : c.icon);
    final Color bg = active ? c.primaryContainer : (filled ? c.surfaceContainerHigh : Colors.transparent);
    final double disc = filled ? 40 : IconSpec.tapTarget;
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: AppTooltip(
        message: semanticLabel,
        child: SizedBox.square(
          dimension: IconSpec.tapTarget,
          child: Center(
            child: Material(
              color: bg,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: disc,
                  child: Center(
                    child: AppIcon(icon, size: filled ? 20 : IconSpec.size, color: fg, fill: fill),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mull's one tooltip: a `surfaceContainer` chip with a hairline, holding
/// the label a screen reader announces.
class AppTooltip extends StatelessWidget {
  const AppTooltip({required this.message, required this.child, super.key});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return child;
    final UnfurlColors c = context.colors;
    return Tooltip(
      message: message,
      excludeFromSemantics: true,
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.chipR,
        border: Border.all(color: c.outline),
        boxShadow: <BoxShadow>[BoxShadow(color: c.shadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      textStyle: UnfurlType.label.copyWith(color: c.onSurface),
      child: child,
    );
  }
}

enum AppButtonType {
  /// Accent fill. One per screen.
  primary,

  /// `surfaceContainerHigh`, beside or under a primary.
  secondary,

  /// No fill: a sheet's Cancel.
  text,

  /// No fill, accent label: the welcome flow's "Go to Home".
  accent,
}

/// The one pill button. A minimum height, not a fixed one: it grows with its
/// text at a large font scale.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.icon,
    this.height = 52,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final IconData? icon;

  /// 52 for a screen's pinned actions, 48 inside a card.
  final double height;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final (Color bg, Color fg) = switch (type) {
      AppButtonType.primary => (c.primary, c.onPrimary),
      AppButtonType.secondary => (c.surfaceContainerHigh, c.onSurface),
      AppButtonType.text => (Colors.transparent, c.onSurface),
      AppButtonType.accent => (Colors.transparent, c.accent),
    };
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Material(
          color: bg,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xs),
              // Min-sized: a stretched parent (pinned actions) still centres
              // it, and it sits naturally in a row.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: Space.sm,
                children: <Widget>[
                  if (icon != null) AppIcon(icon!, size: 20, color: fg),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UnfurlType.titleMedium.copyWith(color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
