import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'motion.dart';
import 'motion_level.dart';

/// Global bounds of the widget behind [key] (the tapped row or card), or null
/// when it is not on screen. Read it at tap time, before pushing.
Rect? globalRectOf(GlobalKey key) {
  final o = key.currentContext?.findRenderObject();
  if (o is! RenderBox || !o.attached || !o.hasSize) return null;
  return o.localToGlobal(Offset.zero) & o.size;
}

/// Row or card to page (motion.md "Container transform").
///
/// Expressive: the page grows out of [sourceRect] with corners 16 to 0 on
/// springSlow (a clip over a full-size page: the page is never relaid out).
/// Fade-through: the container colour shows over the first 30 %, then the
/// page fades in over fx.fast. Back reverses into the row on springStandard.
/// Subtle: fade-through + 4 dp shift. Off: 90 ms cross-fade. Without a
/// [sourceRect] it falls back to the Subtle look.
Widget containerTransformTransition(
  BuildContext context,
  Animation<double> animation,
  Widget child, {
  required MotionLevel level,
  Rect? sourceRect,
  Color? color,
}) {
  final cs = Theme.of(context).colorScheme;
  final container = color ?? cs.surfaceContainer;
  final fwd = level == MotionLevel.subtle ? Motion.subtleCurve : Motion.slowCurve;
  final rev = level == MotionLevel.subtle ? Motion.subtleCurve.flipped : Motion.standardCurve.flipped;
  final fade = Interval(
    0.3,
    math.min(1.0, 0.3 + Motion.fxFast.inMilliseconds / fwd.settle.inMilliseconds),
    curve: Motion.curveEffects,
  );

  if (level == MotionLevel.off) {
    return FadeTransition(opacity: animation, child: child);
  }
  final bounds = level == MotionLevel.expressive ? sourceRect : null;
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final reversing = animation.status == AnimationStatus.reverse;
      final t = (reversing ? rev : fwd).transform(animation.value);
      if (bounds == null) {
        // Fade-through with a 4 dp shift.
        final o = reversing ? animation.value : fade.transform(animation.value);
        return Opacity(
          opacity: o.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 4 * (1 - t.clamp(0.0, 1.0))), child: child),
        );
      }
      final full = Offset.zero & MediaQuery.sizeOf(context);
      final rect = Rect.lerp(bounds, full, t)!;
      final r = math.max(0.0, 16 * (1 - t));
      return Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              clipper: _RectClipper(rect, r),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: container),
                  Opacity(
                    opacity: (reversing ? animation.value : fade.transform(animation.value)).clamp(0.0, 1.0),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _RectClipper extends CustomClipper<RRect> {
  _RectClipper(this.rect, this.radius);
  final Rect rect;
  final double radius;
  @override
  RRect getClip(Size size) => RRect.fromRectAndRadius(rect, Radius.circular(radius));
  @override
  bool shouldReclip(_RectClipper o) => o.rect != rect || o.radius != radius;
}

Duration _forward(MotionLevel l) => switch (l) {
  MotionLevel.expressive => Motion.slowCurve.settle,
  MotionLevel.subtle => Motion.subtleCurve.settle,
  MotionLevel.off => Motion.fxInstant,
};
Duration _reverse(MotionLevel l) => switch (l) {
  MotionLevel.expressive => Motion.standardCurve.settle,
  MotionLevel.subtle => Motion.subtleCurve.settle,
  MotionLevel.off => Motion.fxInstant,
};

/// A `Navigator.push` route with the container transform. Read the level
/// with `Motion.levelOf(context)` at push time.
class ContainerTransformRoute<T> extends PageRouteBuilder<T> {
  ContainerTransformRoute({
    required MotionLevel level,
    required WidgetBuilder builder,
    Rect? sourceRect,
    Color? color,
    super.settings,
  }) : super(
         pageBuilder: (context, _, _) => builder(context),
         transitionDuration: _forward(level),
         reverseTransitionDuration: _reverse(level),
         transitionsBuilder: (context, animation, _, child) => containerTransformTransition(
           context,
           animation,
           child,
           level: level,
           sourceRect: sourceRect,
           color: color,
         ),
       );
}

/// GoRouter page with the container transform, e.g. in `pageBuilder:`:
/// `containerTransformPage(context: context, state: state, child: ..., sourceRect: globalRectOf(key))`.
CustomTransitionPage<T> containerTransformPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  Rect? sourceRect,
  Color? color,
}) {
  final level = Motion.levelOf(context);
  return CustomTransitionPage<T>(
    key: state.pageKey,
    name: state.name,
    arguments: state.extra,
    child: child,
    transitionDuration: _forward(level),
    reverseTransitionDuration: _reverse(level),
    transitionsBuilder: (context, animation, _, child) =>
        containerTransformTransition(context, animation, child, level: level, sourceRect: sourceRect, color: color),
  );
}
