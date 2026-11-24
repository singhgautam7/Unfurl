// ignore_for_file: discarded_futures, unawaited_futures (animation futures are fire-and-forget)

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'motion_level.dart';
import 'spring.dart';

/// Which chart is drawing in (sets the duration, motion.md "Charts").
enum ChartKind { donut, bars, line }

/// Progress handed to the chart builder.
class ChartProgress {
  const ChartProgress(this.linear, this.kind, this.count);

  /// Raw 0..1 over the whole draw-in.
  final double linear;
  final ChartKind kind;

  /// Number of bars (bars only).
  final int count;

  /// Total draw-in time: donut 400, line 400, bars 300 + 30 ms stagger
  /// (at most 6 steps: bars past the 6th rise with the 6th).
  Duration get total => kind == ChartKind.bars
      ? Motion.chartBar + Motion.stagger * (math.min(math.max(count, 1), Motion.staggerCap) - 1)
      : Motion.chartDraw;

  /// Whole-chart progress on curve.effects (donut sweep, line draw).
  double get t => Motion.curveEffects.transform(linear);

  /// Progress of bar [i] (0..1, curve.effects, staggered).
  double item(int i) {
    final ms = linear * total.inMilliseconds - Motion.staggerDelay(i).inMilliseconds;
    return Motion.curveEffects.transform((ms / Motion.chartBar.inMilliseconds).clamp(0.0, 1.0));
  }
}

/// Draws a chart in once per page visit. Expressive: [builder] gets a 0..1
/// progress ([ChartProgress]); Subtle: progress is 1 and the chart fades in
/// fx.default; Off: it just appears. The animation starts when this first
/// builds and never replays on rebuilds (pass [animate] false to skip, e.g.
/// when returning to a tab). Data changes: wrap values in [SpringValue].
class ChartDrawIn extends StatefulWidget {
  const ChartDrawIn({super.key, required this.kind, required this.builder, this.count = 1, this.animate = true});

  final ChartKind kind;
  final int count;
  final bool animate;
  final Widget Function(BuildContext context, ChartProgress progress) builder;

  @override
  State<ChartDrawIn> createState() => _ChartDrawInState();
}

class _ChartDrawInState extends State<ChartDrawIn> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate) return;
    final l = Motion.levelOf(context);
    if (l == MotionLevel.off) return;
    final total = ChartProgress(0, widget.kind, widget.count).total;
    _c = AnimationController(vsync: this, duration: l == MotionLevel.subtle ? Motion.fxDefault : total)..forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return widget.builder(context, ChartProgress(1, widget.kind, widget.count));
    }
    final subtle = Motion.levelOf(context) == MotionLevel.subtle;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        if (subtle) {
          return Opacity(
            opacity: Motion.curveEffects.transform(c.value),
            child: widget.builder(context, ChartProgress(1, widget.kind, widget.count)),
          );
        }
        return widget.builder(context, ChartProgress(c.value, widget.kind, widget.count));
      },
    );
  }
}

/// Follows [target] on a spring (springStandard by default; springSubtle at
/// Subtle; jumps at Off), retargeting from its current value and velocity.
/// For data changes: drive a chart's bar heights, slice angles or line points
/// from a version number, or lerp from the previous value yourself. The ticker
/// only runs while moving.
class SpringValue extends StatefulWidget {
  const SpringValue({super.key, required this.target, required this.builder, this.spring});

  final double target;
  final SpringDescription? spring;
  final Widget Function(BuildContext context, double value) builder;

  @override
  State<SpringValue> createState() => _SpringValueState();
}

class _SpringValueState extends State<SpringValue> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: widget.target);

  @override
  void didUpdateWidget(SpringValue old) {
    super.didUpdateWidget(old);
    if (old.target == widget.target) return;
    final l = Motion.levelOf(context);
    if (l == MotionLevel.off) {
      _c.value = widget.target;
    } else {
      _c.springTo(widget.target, Motion.spatial(l, widget.spring ?? Motion.springStandard));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _c, builder: (context, _) => widget.builder(context, _c.value));
}
