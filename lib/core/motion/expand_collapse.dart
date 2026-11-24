// ignore_for_file: discarded_futures, unawaited_futures (animation futures are fire-and-forget)

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'motion_level.dart';
import 'spring.dart';

/// Animated show / hide of [child] (sections, accordions, tree rows).
///
/// Height: springDefault expanding, springStandard collapsing (springSubtle at
/// Subtle, instant at Off). The content fades in fx.fast after 40 ms, out in
/// fx.instant (Off: 90 ms both ways). One clipped box (ClipRect + Align
/// heightFactor): the child is laid out at full height and only the clip
/// moves. Collapsed and settled, the child is offstage (no layout or paint).
class ExpandCollapse extends StatefulWidget {
  const ExpandCollapse({super.key, required this.expanded, required this.child, this.alignment = Alignment.topCenter});

  final bool expanded;
  final Widget child;
  final Alignment alignment;

  @override
  State<ExpandCollapse> createState() => _ExpandCollapseState();
}

class _ExpandCollapseState extends State<ExpandCollapse> with TickerProviderStateMixin {
  late final AnimationController _h = AnimationController.unbounded(vsync: this, value: widget.expanded ? 1 : 0);
  late final AnimationController _f = AnimationController(vsync: this, value: widget.expanded ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _hidden = !widget.expanded;
    _h.addListener(_rebuildIfEdge);
  }

  bool _hidden = false;
  void _rebuildIfEdge() {
    final hidden = !widget.expanded && _h.value <= 0.001;
    if (hidden != _hidden) setState(() => _hidden = hidden);
  }

  @override
  void didUpdateWidget(ExpandCollapse old) {
    super.didUpdateWidget(old);
    if (old.expanded == widget.expanded) return;
    final l = Motion.levelOf(context);
    final open = widget.expanded;
    setState(() => _hidden = false);
    if (l == MotionLevel.off) {
      _h.value = open ? 1 : 0;
      _f.animateTo(open ? 1 : 0, duration: Motion.fxInstant, curve: Motion.curveEffects);
    } else {
      _h.springTo(open ? 1 : 0, Motion.spatial(l, open ? Motion.springDefault : Motion.springStandard));
      if (open) {
        const Duration delay = Motion.expandFadeDelay;
        final total = delay + Motion.fxFast;
        _f.animateTo(
          1,
          duration: total,
          curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1, curve: Motion.curveEffects),
        );
      } else {
        _f.animateTo(0, duration: Motion.fxInstant, curve: Motion.curveEffects);
      }
    }
  }

  @override
  void dispose() {
    _h.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = !widget.expanded && _h.value <= 0.001;
    return ClipRect(
      child: AnimatedBuilder(
        animation: _h,
        child: Offstage(
          offstage: hidden,
          child: FadeTransition(opacity: _f, child: widget.child),
        ),
        builder: (context, child) =>
            Align(heightFactor: math.max(0.0, _h.value), alignment: widget.alignment, child: child),
      ),
    );
  }
}

/// A chevron that turns when [expanded]: 0 to [openDegrees] (90 for tree
/// rows, 180 for accordions). springFast opening, springStandard closing,
/// springSubtle at Subtle, instant at Off. Default child: chevron_right for
/// 90, expand_more for 180.
class ChevronTurn extends StatefulWidget {
  const ChevronTurn({super.key, required this.expanded, this.openDegrees = 90, this.child, this.size = 24, this.color});

  final bool expanded;
  final double openDegrees;
  final Widget? child;
  final double size;
  final Color? color;

  @override
  State<ChevronTurn> createState() => _ChevronTurnState();
}

class _ChevronTurnState extends State<ChevronTurn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: widget.expanded ? 1 : 0);

  @override
  void didUpdateWidget(ChevronTurn old) {
    super.didUpdateWidget(old);
    if (old.expanded == widget.expanded) return;
    final l = Motion.levelOf(context);
    final open = widget.expanded;
    if (l == MotionLevel.off) {
      _c.value = open ? 1 : 0;
    } else {
      _c.springTo(open ? 1 : 0, Motion.spatial(l, open ? Motion.springFast : Motion.springStandard));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon =
        widget.child ??
        Icon(
          widget.openDegrees > 90 ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
          size: widget.size,
          color: widget.color,
        );
    return AnimatedBuilder(
      animation: _c,
      child: icon,
      builder: (context, child) => Transform.rotate(angle: _c.value * widget.openDegrees * math.pi / 180, child: child),
    );
  }
}
