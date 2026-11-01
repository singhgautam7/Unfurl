import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import '../formats/format_registry.dart';
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

/// The type chips of Library and every folder: All, then each family
/// present in the registry's order (none when only one is), then [trailing]
/// ("Other", "Include subfolders"). The selected chip carries how many files
/// are on screen; tapping it again goes back to All.
class FormatChips extends StatelessWidget {
  const FormatChips({
    required this.present,
    required this.selected,
    required this.onSelected,
    this.shown,
    this.allSelected,
    this.trailing = const <Widget>[],
    super.key,
  });

  final Set<FormatGroup> present;
  final FormatGroup? selected;
  final ValueChanged<FormatGroup?> onSelected;

  /// Files on screen; null while they are still loading.
  final int? shown;

  /// Overrides "nothing selected means All" (a trailing chip is selected).
  final bool? allSelected;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final bool all = allSelected ?? selected == null;
    return ChipRow(
      children: <Widget>[
        PillChip(label: 'All', selected: all, count: shown, onTap: () => onSelected(null)),
        for (final FormatGroup g in FormatGroup.values)
          if (present.contains(g))
            PillChip(
              label: g.label,
              selected: selected == g,
              count: shown,
              onTap: () => onSelected(selected == g ? null : g),
            ),
        ...trailing,
      ],
    );
  }
}

/// Mull's segmented control at Unfurl's size: a `surfaceContainerHigh`
/// track, 4dp padding, 40dp segments; the selected one is `surface` with a
/// 1px outline, a thumb that slides to the option picked. Page turn (Slide,
/// Fade, None), PDFs open in (Page, Reader). When a label won't fit its
/// share of the width (large system text) the options wrap onto more rows
/// at their own widths instead of being cut off.
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({required this.options, required this.selected, required this.onChanged, super.key});

  /// Value, label, optional icon.
  final List<(T, String, IconData?)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  static const double _iconSize = 18;
  static const double _gap = 6;

  TextStyle _label(bool on) => UnfurlType.titleMedium.copyWith(fontSize: 14).weight(on ? 600 : 500);

  /// A segment's content at its own width: icon, gap, label (bold, the wider).
  double _contentWidth(BuildContext context, (T, String, IconData?) o) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: o.$2, style: _label(true)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final double w = tp.width + (o.$3 == null ? 0 : _iconSize + _gap);
    tp.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final int at = math.max(0, options.indexWhere(((T, String, IconData?) o) => o.$1 == selected));
    Widget content((T, String, IconData?) o, {required bool fit}) {
      final bool on = o.$1 == selected;
      final Color fg = on ? c.onSurface : c.onSurfaceVariant;
      final Widget label = AnimatedDefaultTextStyle(
        duration: Motion.of(context, Motion.fast),
        curve: Motion.curveOf(context, Motion.decelerate),
        style: _label(on).copyWith(color: fg),
        child: Text(o.$2, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: _gap,
        children: <Widget>[
          if (o.$3 != null) AppIcon(o.$3!, size: _iconSize, color: fg),
          if (fit) Flexible(child: label) else label,
        ],
      );
    }

    Widget tappable((T, String, IconData?) o, Widget child) => Semantics(
      button: true,
      selected: o.$1 == selected,
      label: o.$2,
      onTap: () => onChanged(o.$1),
      excludeSemantics: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onChanged(o.$1), child: child),
    );

    final Decoration thumb = ShapeDecoration(
      color: c.surface,
      shape: StadiumBorder(side: BorderSide(color: c.outline)),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double share = (box.maxWidth - Space.xs * 2) / options.length;
        final bool fits =
            box.maxWidth.isFinite &&
            options.every(((T, String, IconData?) o) => _contentWidth(context, o) + Space.sm * 2 <= share);
        if (!fits) {
          // Large text: each option at its own width, wrapping onto rows.
          // 40 to the eye, 48 to the finger, as below.
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.xs),
            decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: Radii.cardR),
            child: Wrap(
              spacing: Space.xs,
              children: <Widget>[
                for (final (T, String, IconData?) o in options)
                  tappable(
                    o,
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.xs),
                      child: AnimatedContainer(
                        duration: Motion.of(context, Motion.fast),
                        curve: Motion.curveOf(context, Motion.decelerate),
                        constraints: const BoxConstraints(minHeight: 40, minWidth: IconSpec.tapTarget),
                        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
                        decoration: ShapeDecoration(
                          color: o.$1 == selected ? c.surface : c.surface.withValues(alpha: 0),
                          shape: StadiumBorder(
                            side: BorderSide(color: o.$1 == selected ? c.outline : c.outline.withValues(alpha: 0)),
                          ),
                        ),
                        child: content(o, fit: false),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
        // The track's vertical padding belongs to the segments: 40dp to the
        // eye, 48dp to the finger.
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
          decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: Radii.fullR),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: AnimatedAlign(
                  duration: Motion.of(context, Motion.navIndicator),
                  curve: Motion.curveOf(context, Motion.decelerate),
                  alignment: Alignment(options.length == 1 ? 0 : -1 + 2 * at / (options.length - 1), 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / options.length,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.xs),
                      child: DecoratedBox(decoration: thumb),
                    ),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  for (final (T, String, IconData?) o in options)
                    Expanded(
                      child: tappable(
                        o,
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: IconSpec.tapTarget),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                              child: content(o, fit: true),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
