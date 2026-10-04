import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/insights_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_icon.dart';
import '../reader/sheets.dart' show ReaderSheet;

/// Board 6, V1 components: StatTile, BarChart, Heatmap, KeyValueCard,
/// StackedBar and the More tab's InsightsCard. Charts are painters over
/// theme colours, grown in once with the reveal motion.

/// A module's fill: `surfaceContainer`, one step up inside a reader sheet
/// (itself `surfaceContainer`), so tiles still read on it.
Color insightsFill(BuildContext context) => context.findAncestorWidgetOfExactType<ReaderSheet>() != null
    ? context.colors.surfaceContainerHigh
    : context.colors.surfaceContainer;

/// The card every module sits in: `surfaceContainer`, radius 20.
class InsightsBox extends StatelessWidget {
  const InsightsBox({required this.child, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 12), super.key});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: insightsFill(context), borderRadius: Radii.cardR),
    child: child,
  );
}

/// A label, a figure and an optional mono line.
class StatTile extends StatelessWidget {
  const StatTile({required this.label, required this.value, this.sub, super.key});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Semantics(
      container: true,
      label: '$label: $value${sub == null ? '' : ', $sub'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.md),
        decoration: BoxDecoration(color: insightsFill(context), borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.xs,
          children: <Widget>[
            Text(label, style: UnfurlType.label.copyWith(color: c.onSurfaceVariant)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, maxLines: 1, style: UnfurlType.statValue.copyWith(color: c.onSurface)),
            ),
            if (sub != null) Text(sub!, style: UnfurlType.monoSmall.copyWith(color: c.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Stat tiles in [columns] columns, 8dp apart.
class StatGrid extends StatelessWidget {
  const StatGrid({required this.tiles, this.columns = 2, super.key});

  final List<StatTile> tiles;
  final int columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) {
      final double w = (box.maxWidth - Space.sm * (columns - 1)) / columns;
      return Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: <Widget>[for (final StatTile t in tiles) SizedBox(width: w, child: t)],
      );
    },
  );
}

/// The header row inside a chart card: total and range, with optional
/// ‹ › steps around the range.
class ChartHeader extends StatelessWidget {
  const ChartHeader({required this.total, required this.range, this.onBack, this.onForward, super.key});

  final String total;
  final String range;
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final TextStyle mono = UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant);
    Widget step(String glyph, String label, VoidCallback? onTap) => Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: SizedBox(
          width: 32,
          height: IconSpec.tapTarget,
          child: Center(
            child: Text(glyph, style: mono.copyWith(color: onTap == null ? c.onSurfaceMuted : c.onSurface)),
          ),
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(total, style: UnfurlType.chartTotal.copyWith(color: c.onSurface)),
        ),
        if (onBack != null || onForward != null) step('‹', 'Earlier', onBack),
        Text(range, style: mono),
        if (onBack != null || onForward != null) step('›', 'Later', onForward),
      ],
    );
  }
}

/// Bars with labels under them: a zero is a 2dp outline stub so it still
/// reads as a day; the highlighted bar (today) is in accent. [showValues]
/// prints each non-zero value above its bar (finished books).
class BarChart extends StatelessWidget {
  const BarChart({
    required this.values,
    required this.labels,
    this.highlight,
    this.height = 110,
    this.barMaxWidth = 28,
    this.gap = 6,
    this.radius = 5,
    this.showValues = false,
    this.semanticLabel,
    super.key,
  });

  final List<int> values;
  final List<String> labels;
  final int? highlight;
  final double height;
  final double barMaxWidth;
  final double gap;
  final double radius;
  final bool showValues;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final double valueSpace = showValues ? 16 : 0;
    return Semantics(
      container: semanticLabel != null,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Motion.of(context, Motion.reveal),
        curve: Motion.decelerate,
        builder: (BuildContext context, double t, Widget? _) => SizedBox(
          height: height + valueSpace + 16,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BarsPainter(
              values: values,
              labels: labels,
              highlight: highlight,
              plot: height,
              valueSpace: valueSpace,
              barMaxWidth: barMaxWidth,
              gap: gap,
              radius: radius,
              grow: t,
              bar: c.primary,
              hi: c.accent,
              stub: c.outline,
              label: UnfurlType.monoSmall.copyWith(height: 1, color: c.onSurfaceVariant),
              labelHi: UnfurlType.monoSmall.copyWith(height: 1, fontWeight: FontWeight.w600, color: c.onSurface),
              valueStyle: UnfurlType.monoSmall.copyWith(height: 1, fontWeight: FontWeight.w600, color: c.onSurface),
              direction: Directionality.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.labels,
    required this.highlight,
    required this.plot,
    required this.valueSpace,
    required this.barMaxWidth,
    required this.gap,
    required this.radius,
    required this.grow,
    required this.bar,
    required this.hi,
    required this.stub,
    required this.label,
    required this.labelHi,
    required this.valueStyle,
    required this.direction,
  });

  final List<int> values;
  final List<String> labels;
  final int? highlight;
  final double plot;
  final double valueSpace;
  final double barMaxWidth;
  final double gap;
  final double radius;
  final double grow;
  final Color bar;
  final Color hi;
  final Color stub;
  final TextStyle label;
  final TextStyle labelHi;
  final TextStyle valueStyle;
  final TextDirection direction;

  /// Centred on its bar, kept inside the chart ("5 Sep" under the first bar).
  void _text(Canvas canvas, String s, TextStyle style, Offset centre, double width) {
    if (s.isEmpty) return;
    final TextPainter tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: direction,
    )..layout();
    tp.paint(canvas, Offset((centre.dx - tp.width / 2).clamp(0, math.max(0, width - tp.width)), centre.dy));
    tp.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final int n = values.length;
    if (n == 0) return;
    final int max = values.fold<int>(1, math.max);
    final double slot = (size.width - gap * (n - 1)) / n;
    final double w = math.min(slot, barMaxWidth);
    final double base = valueSpace + plot;
    final Paint p = Paint();
    for (int i = 0; i < n; i++) {
      final double cx = i * (slot + gap) + slot / 2;
      final int v = values[i];
      final double h = v == 0 ? 2 : math.max(3, v / max * plot) * grow;
      p.color = v == 0 ? stub : (i == highlight ? hi : bar);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - w / 2, base - h, w, h),
          topLeft: Radius.circular(math.min(radius, w / 2)),
          topRight: Radius.circular(math.min(radius, w / 2)),
          bottomLeft: Radius.circular(math.min(radius, w / 2)),
          bottomRight: Radius.circular(math.min(radius, w / 2)),
        ),
        p,
      );
      if (valueSpace > 0 && v > 0) _text(canvas, '$v', valueStyle, Offset(cx, base - h - 14), size.width);
      if (i < labels.length) {
        _text(canvas, labels[i], i == highlight ? labelHi : label, Offset(cx, base + 5), size.width);
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.grow != grow || old.values != values || old.bar != bar || old.highlight != highlight;
}

/// 53 weeks × 7 days, Monday on top; five levels from the seed's primary.
class Heatmap extends StatelessWidget {
  const Heatmap({required this.minutes, required this.months, required this.family, this.gap = 1.5, super.key});

  /// Monday-first, column by column; null is a day still to come.
  final List<int?> minutes;
  final List<String> months;
  final ThemeFamily family;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final List<Color> levels = InsightsColors.heatLevels(family, c.tone);
    final TextStyle mono = UnfurlType.monoSmall.copyWith(fontSize: 10, color: c.onSurfaceVariant);
    final int read = minutes.where((int? m) => m != null && m >= 1).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: <Widget>[
        Semantics(
          container: true,
          label: '$read days with reading in the last 12 months',
          excludeSemantics: true,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final double cell = (box.maxWidth - gap * 52) / 53;
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Motion.of(context, Motion.reveal),
                curve: Motion.decelerate,
                builder: (BuildContext context, double t, Widget? _) => CustomPaint(
                  size: Size(box.maxWidth, cell * 7 + gap * 6),
                  painter: _HeatPainter(minutes: minutes, levels: levels, cell: cell, gap: gap, fade: t),
                ),
              );
            },
          ),
        ),
        // Equal slots, so twelve names fit any width and font scale.
        ExcludeSemantics(
          child: Row(
            children: <Widget>[
              for (final String m in months)
                Expanded(
                  child: Text(
                    m,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    textAlign: TextAlign.center,
                    style: mono,
                  ),
                ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 3,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Text('Less', style: mono),
            ),
            for (final Color l in levels)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: l, borderRadius: BorderRadius.circular(2)),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Text('More', style: mono),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeatPainter extends CustomPainter {
  _HeatPainter({
    required this.minutes,
    required this.levels,
    required this.cell,
    required this.gap,
    required this.fade,
  });

  final List<int?> minutes;
  final List<Color> levels;
  final double cell;
  final double gap;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint();
    for (int i = 0; i < minutes.length; i++) {
      final int? m = minutes[i];
      if (m == null) continue;
      final int col = i ~/ 7, row = i % 7;
      // Columns fill in left to right as it appears.
      final double a = ((fade * 1.4) - col / 53).clamp(0, 1);
      p.color = levels[InsightsSpec.heatLevel(m)].withValues(alpha: a);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(col * (cell + gap), row * (cell + gap), cell, cell),
          const Radius.circular(1.5),
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) => old.fade != fade || old.minutes != minutes || old.levels != levels;
}

/// Pairs of a label, a figure and an optional mono line, in a grid.
class KeyValueCard extends StatelessWidget {
  const KeyValueCard({required this.items, this.columns = 2, super.key});

  final List<(String, String, String?)> items;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return InsightsBox(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double w = (box.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 14,
            children: <Widget>[
              for (final (String k, String v, String? sub) in items)
                SizedBox(
                  width: w,
                  child: Semantics(
                    container: true,
                    label: '$k: $v${sub == null ? '' : ', $sub'}',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 3,
                      children: <Widget>[
                        Text(k, style: UnfurlType.label.copyWith(color: c.onSurfaceVariant)),
                        Text(v, style: UnfurlType.kvValue.copyWith(color: c.onSurface)),
                        if (sub != null) Text(sub, style: UnfurlType.monoSmall.copyWith(color: c.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Shares of a whole, as one rounded bar with a two-column legend.
class StackedBar extends StatelessWidget {
  const StackedBar({required this.parts, required this.family, super.key});

  /// (label, share 0..1).
  final List<(String, double)> parts;
  final ThemeFamily family;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    String pct(double v) => '${(v * 100).round()}%';
    return InsightsBox(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                spacing: 2,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int i = 0; i < parts.length; i++)
                    Expanded(
                      flex: math.max(1, (parts[i].$2 * 1000).round()),
                      child: ColoredBox(color: InsightsColors.stack(family, i)),
                    ),
                ],
              ),
            ),
          ),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) => Wrap(
              spacing: 14,
              runSpacing: Space.sm,
              children: <Widget>[
                for (int i = 0; i < parts.length; i++)
                  SizedBox(
                    width: (box.maxWidth - 14) / 2,
                    child: Semantics(
                      container: true,
                      label: '${parts[i].$1}: ${pct(parts[i].$2)}',
                      excludeSemantics: true,
                      child: Row(
                        spacing: Space.sm,
                        children: <Widget>[
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: InsightsColors.stack(family, i),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              parts[i].$1,
                              style: UnfurlType.tableCell.copyWith(height: 1.2, color: c.onSurface).weight(500),
                            ),
                          ),
                          Text(pct(parts[i].$2), style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The More tab's card (board 6, V1): this week's time and a 7-day mini
/// chart on `primaryContainer`, opening Insights.
class InsightsCard extends StatelessWidget {
  const InsightsCard({
    required this.value,
    required this.sub,
    required this.week,
    required this.onTap,
    this.today,
    super.key,
  });

  final String value;
  final String sub;

  /// Minutes, Monday to Sunday; the last day drawn is today.
  final List<int> week;
  final int? today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final int max = week.fold<int>(1, math.max);
    return Semantics(
      button: true,
      label: 'Insights. $value. $sub',
      excludeSemantics: true,
      child: Material(
        color: c.primaryContainer,
        borderRadius: Radii.cardR,
        child: InkWell(
          borderRadius: Radii.cardR,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
            child: Row(
              spacing: 14,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: <Widget>[
                      Row(
                        spacing: 6,
                        children: <Widget>[
                          AppIcon(AppIcons.insights, size: 18, color: c.onPrimaryContainer),
                          Text(
                            'Insights',
                            style: UnfurlType.label.copyWith(fontSize: 13, color: c.onPrimaryContainer).weight(600),
                          ),
                        ],
                      ),
                      Text(value, style: UnfurlType.cardValue.copyWith(color: c.onPrimaryContainer)),
                      Text(sub, style: UnfurlType.tableCell.copyWith(height: 1.35, color: c.onPrimaryContainer)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 4,
                    children: <Widget>[
                      for (int i = 0; i < week.length; i++)
                        Container(
                          width: 8,
                          height: week[i] == 0 ? 3 : math.max(4, week[i] / max * 52),
                          decoration: BoxDecoration(
                            color: week[i] == 0 ? c.outline : (i == today ? c.onPrimaryContainer : c.primary),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
                AppIcon(AppIcons.chevronRight, color: c.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A grey block standing in for a module while it loads.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({required this.height, this.width, this.radius = 8, super.key});

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: context.colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(radius)),
  );
}
