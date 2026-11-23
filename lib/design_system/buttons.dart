import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../core/motion/kit.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';

/// Weight of an [AppIconButton] (Kuber's kinds).
enum AppIconButtonKind {
  /// `surfaceContainerHigh` disc, `icon` glyph: the default header button.
  standard,

  /// `primaryContainer` disc: an active toggle (crop on, bookmarked).
  tonal,

  /// `primary` disc, `onPrimary` glyph.
  filled,

  /// No disc, a 24dp glyph: reader bars and in-field actions.
  plain,

  /// `dangerContainer` disc: Delete.
  danger,
}

/// Kuber's `kuberPressedLayer`: a 10% state layer while pressed, no ink.
WidgetStateProperty<Color?> pressedLayer(UnfurlColors c) => WidgetStateProperty.resolveWith(
  (Set<WidgetState> s) => s.contains(WidgetState.pressed) ? c.onSurface.withValues(alpha: 0.1) : null,
);

/// Back, open file, overflow, search, view toggle: every round icon action
/// is this, at Mull's sizes: a 40dp `surfaceContainerHigh` disc, a 20dp
/// glyph, a 48dp target, and Mull's tooltip on long-press. Reader bars use
/// the plain variant (24dp glyph, no disc). The disc is a circle at rest and
/// a 12dp squircle while held. A new [icon] scales and fades in; disabled
/// ([onPressed] null) is the glyph at 38% and no press.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.filled = true,
    this.active = false,
    this.kind,
    this.tint,
    this.fill = false,
    this.onLongPress,
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

  /// Overrides what [filled] and [active] say.
  final AppIconButtonKind? kind;
  final Color? tint;

  /// The filled glyph variant.
  final bool fill;

  /// A second action on a hold; the tooltip gives way to it.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final AppIconButtonKind k =
        kind ??
        (active
            ? AppIconButtonKind.tonal
            : filled
            ? AppIconButtonKind.standard
            : AppIconButtonKind.plain);
    final bool plain = k == AppIconButtonKind.plain;
    final bool disabled = onPressed == null;
    final (Color bg, Color fg) = switch (k) {
      AppIconButtonKind.standard => (c.surfaceContainerHigh, c.icon),
      AppIconButtonKind.tonal => (c.primaryContainer, c.onPrimaryContainer),
      AppIconButtonKind.filled => (c.primary, c.onPrimary),
      AppIconButtonKind.plain => (c.onSurface.withValues(alpha: 0), c.icon),
      AppIconButtonKind.danger => (c.dangerContainer, c.onDangerContainer),
    };
    final double disc = plain ? IconSpec.tapTarget : 40;
    final double glyph = plain ? IconSpec.size : 20;
    final MotionLevel level = Motion.levelOf(context);
    Widget button = SizedBox.square(
      dimension: IconSpec.tapTarget,
      child: Center(
        child: Opacity(
          opacity: disabled ? Opacities.disabled : 1,
          child: Pressable(
            kind: PressKind.iconButton,
            restRadius: disc / 2,
            enabled: !disabled,
            onLongPress: onLongPress,
            builder: (BuildContext context, double radius, double pressed) => Material(
              color: k == AppIconButtonKind.standard && level == MotionLevel.expressive
                  ? Color.lerp(bg, c.onSurface, 0.08 * pressed.clamp(0.0, 1.0))
                  : bg,
              animationDuration: Duration.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                overlayColor: pressedLayer(c),
                splashFactory: NoSplash.splashFactory,
                enableFeedback: onLongPress == null,
                child: SizedBox.square(
                  dimension: disc,
                  child: _IconSwap(icon: icon, size: glyph, color: tint ?? fg, fill: fill),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (onLongPress == null) button = AppTooltip(message: semanticLabel, child: button);
    return Semantics(
      button: true,
      enabled: !disabled,
      label: semanticLabel,
      onTap: onPressed,
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: button,
    );
  }
}

/// A new glyph scales 0.6 to 1 on springFast and fades in; the old one fades
/// out on fxInstant. Subtle and Off: a cross-fade (Kuber's `_IconSwap`).
class _IconSwap extends StatefulWidget {
  const _IconSwap({required this.icon, required this.size, required this.color, required this.fill});

  final IconData icon;
  final double size;
  final Color color;
  final bool fill;

  @override
  State<_IconSwap> createState() => _IconSwapState();
}

class _IconSwapState extends State<_IconSwap> {
  /// What it swapped from; null until it first does, so a button that never
  /// changes (hundreds of them in a list) is one icon and nothing more.
  IconData? _from;

  @override
  void didUpdateWidget(_IconSwap old) {
    super.didUpdateWidget(old);
    if (old.icon != widget.icon) _from = old.icon;
  }

  AppIcon _icon(IconData i) => AppIcon(i, size: widget.size, color: widget.color, fill: widget.fill);

  @override
  Widget build(BuildContext context) {
    final IconData? from = _from;
    if (from == null) return Center(child: _icon(widget.icon));
    final MotionLevel level = Motion.levelOf(context);
    final bool expressive = level == MotionLevel.expressive;
    return TweenAnimationBuilder<double>(
      key: ValueKey<IconData>(widget.icon),
      tween: Tween<double>(begin: 0, end: 1),
      duration: expressive ? Motion.fastCurve.settle : (level == MotionLevel.off ? Motion.fxInstant : Motion.fxFast),
      curve: expressive ? Motion.fastCurve : Curves.linear,
      builder: (BuildContext context, double t, Widget? child) {
        final double o = t.clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            if (o < 1) Opacity(opacity: 1 - o, child: _icon(from)),
            Opacity(
              opacity: o,
              child: expressive ? Transform.scale(scale: 0.6 + 0.4 * t, child: child) : child,
            ),
          ],
        );
      },
      child: _icon(widget.icon),
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

  /// 1dp outline, no fill.
  outline,

  /// No fill: a sheet's Cancel.
  text,

  /// No fill, accent label: the welcome flow's "Go to Home".
  accent,

  /// `dangerContainer`; [AppButton.filled] makes it a solid `danger`.
  danger,

  /// A dashed outline, low emphasis ("Add folder").
  dotted,
}

/// The one pill button, Kuber's: 56dp (a [height] of 48 or more) or 40dp
/// (inside a 48dp hit region), icon 20 with an 8 gap. A minimum height, not
/// a fixed one: it grows with its text at a large font scale. Rest radius is
/// half the height; held, 12dp at 56 and 8dp at 40. The fill fades on
/// `fxFast`. Disabled is `onSurface` 12% fill and 38% label.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.tight = false,
    this.type = AppButtonType.primary,
    this.icon,
    this.iconAfterLabel = false,
    this.height = 56,
    this.isLoading = false,
    this.filled = false,
    super.key,
  });

  /// Side by side in a row of two (the card editor's Save and Share): 12dp
  /// side padding so the label fits a half-width pill.
  final bool tight;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final IconData? icon;
  final bool iconAfterLabel;

  /// Snaps to the two sizes: 48 or more is 56, less is 40.
  final double height;

  /// A [ShapeLoader] in place of the icon; the button does nothing meanwhile.
  final bool isLoading;

  /// For [AppButtonType.danger]: a solid `danger` fill.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final bool large = height >= IconSpec.tapTarget;
    final double h = large ? 56 : 40;
    final bool disabled = onPressed == null || isLoading;
    final Color clear = c.onSurface.withValues(alpha: 0);
    var (Color bg, Color fg, Color edge) = switch (type) {
      AppButtonType.primary => (c.primary, c.onPrimary, clear),
      AppButtonType.secondary => (c.surfaceContainerHigh, c.onSurface, clear),
      AppButtonType.outline => (clear, c.onSurface, c.outline),
      AppButtonType.text => (clear, c.onSurface, clear),
      AppButtonType.accent => (clear, c.accent, clear),
      AppButtonType.danger => filled ? (c.danger, c.surface, clear) : (c.dangerContainer, c.onDangerContainer, clear),
      AppButtonType.dotted => (clear, c.onSurfaceVariant, clear),
    };
    if (disabled && !isLoading) {
      final bool bare = bg.a == 0;
      bg = bare ? clear : c.onSurface.withValues(alpha: 0.12);
      fg = c.onSurface.withValues(alpha: Opacities.disabled);
      if (type == AppButtonType.outline) edge = c.onSurface.withValues(alpha: 0.12);
    }
    final MotionLevel level = Motion.levelOf(context);
    final TextStyle style = (large ? UnfurlType.titleMedium : UnfurlType.titleSmall).copyWith(
      fontSize: large ? null : 14,
    );
    final Widget? glyph = isLoading
        ? ShapeLoader(size: 20, color: fg)
        : icon == null
        ? null
        : AppIcon(icon!, size: 20, color: fg);
    final Widget text = Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style.copyWith(color: fg),
      ),
    );
    final Widget button = Pressable(
      kind: PressKind.button,
      enabled: !disabled,
      restRadius: h / 2,
      pressedRadius: large ? Radii.box : Radii.chip,
      onTap: onPressed,
      builder: (BuildContext context, double radius, double pressed) {
        Widget b = ConstrainedBox(
          constraints: BoxConstraints(minHeight: h),
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: bg),
            duration: level == MotionLevel.off ? Motion.fxInstant : Motion.fxFast,
            curve: Motion.curveEffects,
            builder: (BuildContext context, Color? color, Widget? child) => Material(
              color: color,
              animationDuration: Duration.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
                side: type == AppButtonType.outline ? BorderSide(color: edge) : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: disabled ? null : onPressed,
                overlayColor: pressedLayer(c),
                splashFactory: NoSplash.splashFactory,
                child: child,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tight ? Space.md : (large ? Space.xl : Space.lg),
                vertical: Space.xs,
              ),
              // Min-sized: a stretched parent (pinned actions) still centres
              // it, and it sits naturally in a row.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: Space.sm,
                children: <Widget>[
                  if (glyph != null && !iconAfterLabel) glyph,
                  text,
                  if (glyph != null && iconAfterLabel) glyph,
                ],
              ),
            ),
          ),
        );
        if (type == AppButtonType.dotted) {
          b = CustomPaint(
            foregroundPainter: _DashedBorderPainter(color: disabled ? fg : c.onSurfaceMuted, radius: radius),
            child: b,
          );
        }
        // The 40dp pill sits in a 48dp hit region.
        return large
            ? b
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: b,
              );
      },
    );
    return Semantics(
      // Its own node: in a card it would read as one run with the card's text.
      container: true,
      button: true,
      enabled: !disabled,
      label: label,
      onTap: disabled ? null : onPressed,
      excludeSemantics: true,
      child: button,
    );
  }
}

/// Paints a dashed stadium border, used by [AppButtonType.dotted].
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 4;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
          Radius.circular(radius.clamp(0.0, size.height / 2)),
        ),
      );
    for (final PathMetric m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        final double next = (d + _dash).clamp(0, m.length);
        canvas.drawPath(m.extractPath(d, next), paint);
        d = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color || old.radius != radius;
}
