import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';

/// A filter chip (board 2): 40dp stadium, `surfaceContainerHigh`; selected,
/// `primaryContainer` with its count in a `surface` badge. A toggle chip
/// ("Include subfolders") is outlined on `surface` while off.
class PillChip extends StatelessWidget {
  const PillChip({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.count,
    this.leading,
    this.toggle = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;

  /// Shown only while selected.
  final int? count;

  /// A colour dot or an icon before the label.
  final Widget? leading;
  final bool toggle;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final Color fg = selected ? c.onPrimaryContainer : c.onSurface;
    final bool showCount = selected && count != null;
    final Color bg = selected
        ? c.primaryContainer
        : toggle
        ? c.surface
        : c.surfaceContainerHigh;
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        curve: Motion.curveOf(context, Motion.decelerate),
        constraints: const BoxConstraints(minHeight: 40),
        decoration: ShapeDecoration(
          color: bg,
          shape: StadiumBorder(side: toggle && !selected ? BorderSide(color: c.outline) : BorderSide.none),
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.only(
                left: leading != null ? Space.md : Space.lg,
                right: showCount ? Space.sm : Space.lg,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: Space.sm,
                children: <Widget>[
                  if (leading != null)
                    IconTheme.merge(
                      data: IconThemeData(color: fg, size: 18),
                      child: leading!,
                    ),
                  Text(label, style: UnfurlType.titleMedium.copyWith(color: fg).weight(selected ? 600 : 500)),
                  if (showCount)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
                      decoration: BoxDecoration(color: c.surface, borderRadius: Radii.fullR),
                      child: Text('$count', style: UnfurlType.monoLabel.copyWith(fontSize: 12, color: fg)),
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

/// A row of chips that scrolls sideways off the right edge, as on the boards.
class ChipRow extends StatelessWidget {
  const ChipRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: Space.screen),
    child: Row(spacing: Space.sm, children: children),
  );
}

/// Mull's segmented control at Unfurl's size: a `surfaceContainerHigh`
/// track, 4dp padding, 40dp segments; the selected one is `surface` with a
/// 1px outline. Page turn (Slide, Fade, None), PDFs open in (Page, Reader).
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({required this.options, required this.selected, required this.onChanged, super.key});

  /// Value, label, optional icon.
  final List<(T, String, IconData?)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    // The track's vertical padding belongs to the segments: 40dp to the eye,
    // 48dp to the finger.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.xs),
      decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: Radii.fullR),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (T value, String label, IconData? icon) in options)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: value == selected,
                  label: label,
                  onTap: () => onChanged(value),
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.xs),
                      child: InkWell(
                        onTap: () => onChanged(value),
                        customBorder: const StadiumBorder(),
                        child: AnimatedContainer(
                          duration: Motion.of(context, Motion.fast),
                          curve: Motion.curveOf(context, Motion.spring),
                          constraints: const BoxConstraints(minHeight: 40),
                          decoration: ShapeDecoration(
                            color: value == selected ? c.surface : c.surface.withValues(alpha: 0),
                            shape: StadiumBorder(
                              side: BorderSide(color: value == selected ? c.outline : c.outline.withValues(alpha: 0)),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 6,
                            children: <Widget>[
                              if (icon != null)
                                AppIcon(icon, size: 18, color: value == selected ? c.onSurface : c.onSurfaceVariant),
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: UnfurlType.titleMedium
                                      .copyWith(
                                        fontSize: 14,
                                        color: value == selected ? c.onSurface : c.onSurfaceVariant,
                                      )
                                      .weight(value == selected ? 600 : 500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
