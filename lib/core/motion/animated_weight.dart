import 'package:flutter/material.dart';

import 'motion.dart';
import 'motion_level.dart';

/// Text whose variable weight (`wght`) eases between [rest] and [active] over
/// fx.default on curve.effects (Instrument Sans is variable; same axis as
/// `UnfurlTextStyle.weight`, but tweened as a double). The width of the active weight is reserved, so
/// nothing around it shifts. Off: the weight snaps.
class AnimatedWeight extends StatelessWidget {
  const AnimatedWeight(
    this.text, {
    super.key,
    required this.isActive,
    this.style,
    this.rest = 500,
    this.active = 700,
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final bool isActive;
  final TextStyle? style;
  final double rest;
  final double active;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = style ?? DefaultTextStyle.of(context).style;
    final bool off = Motion.levelOf(context) == MotionLevel.off;
    // Width of the heavier weight, measured once per build (not per frame).
    final double heavy = active > rest ? active : rest;
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: Motion.weightStyle(base, heavy)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
    )..layout();
    final double reserve = tp.width;
    tp.dispose();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isActive ? active : rest),
      duration: off ? Duration.zero : Motion.fxDefault,
      curve: Motion.curveEffects,
      builder: (BuildContext context, double w, Widget? _) => ConstrainedBox(
        constraints: BoxConstraints(minWidth: reserve),
        child: Text(
          text,
          style: Motion.weightStyle(base, w),
          textAlign: textAlign ?? TextAlign.start,
          maxLines: maxLines,
          overflow: overflow,
        ),
      ),
    );
  }
}
