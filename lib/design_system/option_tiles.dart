import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';
import 'buttons.dart';

/// Board 6's option group: a label (and its current value) over a row of
/// tiles. The Comic settings sheet and the card editor share it.
class OptionGroup extends StatelessWidget {
  const OptionGroup({
    required this.label,
    required this.children,
    this.value,
    this.gap = Space.sm,
    this.scroll = false,
    super.key,
  });

  final String label;
  final String? value;
  final List<Widget> children;
  final double gap;

  /// Fixed-width tiles (swatches) that may not fit: the row scrolls.
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(label, style: UnfurlType.titleSmall.copyWith(color: c.onSurface)),
              if (value != null) Text(value!, style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant)),
            ],
          ),
          if (scroll)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(spacing: gap, children: children),
            )
          else
            Row(spacing: gap, children: children),
        ],
      ),
    );
  }
}

/// One choice: text and/or an icon on a 14-radius tile (round for colour
/// swatches); selected is `primaryContainer` with a 2dp primary ring. A tile
/// with its own [background] (a reading theme, a card colour) keeps it and
/// carries a 1dp outline.
class OptionTile extends StatelessWidget {
  const OptionTile({
    required this.selected,
    required this.onTap,
    this.label,
    this.icon,
    this.height = 52,
    this.width,
    this.round = false,
    this.background,
    this.foreground,
    this.style,
    this.semanticLabel,
    super.key,
  });

  final bool selected;
  final VoidCallback onTap;
  final String? label;
  final IconData? icon;
  final double height;

  /// Fixed width (swatches); null shares the row.
  final double? width;
  final bool round;
  final Color? background;
  final Color? foreground;

  /// The label's style: a reading font's "Aa", say.
  final TextStyle? style;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    // Reader sheets sit on surfaceContainer, so an unselected tile steps up one tone.
    final Color bg = background ?? (selected ? c.primaryContainer : c.surfaceContainerHigh);
    final Color fg = foreground ?? (selected ? c.onPrimaryContainer : c.onSurface);
    final Widget tile = Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          curve: Motion.decelerate,
          width: width,
          constraints: BoxConstraints(minHeight: height < IconSpec.tapTarget ? IconSpec.tapTarget : height),
          height: height < IconSpec.tapTarget ? IconSpec.tapTarget : height,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: round ? Radii.fullR : BorderRadius.circular(14),
            border: Border.all(
              color: selected ? c.primary : (background != null ? c.outline : bg),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: Space.xs,
            children: <Widget>[
              if (icon != null) AppIcon(icon!, size: 20, color: fg),
              if (label != null)
                Text(
                  label!,
                  maxLines: 1,
                  style: (style ?? UnfurlType.label.copyWith(fontSize: 13).weight(selected ? 600 : 500)).copyWith(
                    color: fg,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return width == null ? Expanded(child: tile) : tile;
  }
}

/// A v3 sheet's title (600 20), an optional line under it and an optional
/// close button (board 6 `sheetHead`).
class SheetHead extends StatelessWidget {
  const SheetHead({required this.title, this.subtitle, this.onClose, super.key});

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.xs, Space.sm, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.xs,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(title, style: UnfurlType.title.copyWith(letterSpacing: 0, color: c.onSurface)),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: UnfurlType.note.copyWith(height: 1.45, color: c.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          if (onClose != null)
            AppIconButton(icon: AppIcons.close, filled: false, semanticLabel: 'Close', onPressed: onClose),
        ],
      ),
    );
  }
}
