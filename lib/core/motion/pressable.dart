// ignore_for_file: discarded_futures, unawaited_futures (animation futures are fire-and-forget)

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'haptics.dart';
import 'motion.dart';
import 'motion_level.dart';
import 'spring.dart';

/// What is being pressed. Sets the scale and the corner morph.
enum PressKind { card, row, button, iconButton, fab, chip }

/// Press response: scale (card / row .98, fab / chip .96; Subtle .99 for
/// card / row / button; none at Off) and, for buttons, a corner morph.
///
/// Listener-based, so an InkWell / GestureDetector inside keeps its own tap
/// and state layer. Pass [onTap] / [onLongPress] only when there is no inner
/// tap handler. Down on springFast, up on springDefault (card / row) or
/// springFast (buttons); Subtle uses springSubtle; Off does nothing. Retargets
/// from the current value and velocity; no ticker runs at rest.
///
/// Use [child] for scale only. For the corner morph use [builder], which gets
/// the current corner radius (dp) and the press progress (0 at rest, 1
/// pressed, can overshoot).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    this.child,
    this.builder,
    this.onTap,
    this.onLongPress,
    this.kind = PressKind.card,
    this.restRadius,
    this.pressedRadius,
    this.morphCorners,
    this.enabled = true,
    this.semanticLabel,
  }) : assert((child == null) != (builder == null), 'Pass a child or a builder');

  final Widget? child;

  /// Gets the animated corner radius (dp). Only buttons / icon buttons / fab /
  /// chips morph, and only at Expressive; otherwise it stays [restRadius].
  final Widget Function(BuildContext context, double radius, double pressed)? builder;
  final VoidCallback? onTap;

  /// Fires with the long-press haptic.
  final VoidCallback? onLongPress;
  final PressKind kind;

  /// Corner radius at rest (a circle: half its size). Defaults by [kind].
  final double? restRadius;

  /// Corner radius while pressed. Defaults by [kind].
  final double? pressedRadius;

  /// Morph the corners on press. Null: buttons, icon buttons, fab and chips
  /// do; cards and rows do not.
  final bool? morphCorners;
  final bool enabled;

  /// Announced as a button when [onTap] is set.
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _v = ValueNotifier<double>(0);
  AnimationController? _c;
  Offset? _down;

  AnimationController get _ctrl =>
      _c ??= AnimationController.unbounded(vsync: this)..addListener(() => _v.value = _c!.value);

  @override
  void dispose() {
    _c?.dispose();
    _v.dispose();
    super.dispose();
  }

  bool get _morphs =>
      widget.morphCorners ??
      switch (widget.kind) {
        PressKind.card || PressKind.row => false,
        _ => true,
      };

  double _scale(MotionLevel l) {
    if (l == MotionLevel.off) return 1;
    if (l == MotionLevel.subtle) {
      return switch (widget.kind) {
        PressKind.card || PressKind.row || PressKind.button => Motion.pressScaleSubtle,
        _ => 1,
      };
    }
    return switch (widget.kind) {
      PressKind.card || PressKind.row => Motion.pressScaleCard,
      PressKind.fab => Motion.pressScaleFab,
      PressKind.chip => Motion.pressScaleChip,
      _ => 1,
    };
  }

  double get _rest =>
      widget.restRadius ??
      switch (widget.kind) {
        PressKind.fab => Motion.radiusRestFab,
        PressKind.chip => Motion.radiusRestChip,
        _ => Motion.radiusRest,
      };

  double get _pressed =>
      widget.pressedRadius ??
      switch (widget.kind) {
        PressKind.button => Motion.radiusPressedButton,
        PressKind.iconButton => Motion.radiusPressedIconButton,
        PressKind.fab => Motion.radiusPressedFab,
        PressKind.chip => Motion.radiusPressedChip,
        _ => _rest,
      };

  void _press(PointerDownEvent e) {
    if (!widget.enabled) return;
    final MotionLevel l = Motion.levelOf(context);
    if (l == MotionLevel.off) return;
    _down = e.position;
    _ctrl.springTo(1, Motion.spatial(l, Motion.springFast));
  }

  void _release([PointerEvent? e]) {
    if (_down == null) return;
    _down = null;
    final MotionLevel l = Motion.levelOf(context);
    _ctrl.springTo(0, Motion.spatial(l, _morphs ? Motion.springFast : Motion.springDefault));
  }

  void _move(PointerMoveEvent e) {
    final Offset? d = _down;
    // A drag (scroll) is not a press: let go once it passes the touch slop.
    if (d != null && (e.position - d).distance > kTouchSlop) _release();
  }

  @override
  Widget build(BuildContext context) {
    final MotionLevel level = Motion.levelOf(context);
    final double scale = _scale(level);
    final bool morph = _morphs && level == MotionLevel.expressive;
    final double rest = _rest;
    final double pressed = _pressed;

    Widget body = AnimatedBuilder(
      animation: _v,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double v = _v.value;
        final Widget inner =
            widget.builder?.call(context, morph ? math.max(0.0, rest + (pressed - rest) * v) : rest, v) ?? child!;
        return Transform.scale(scale: 1 + (scale - 1) * v, child: inner);
      },
    );
    if (widget.onTap != null || widget.onLongPress != null) {
      body = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled && widget.onTap != null
            ? () {
                Haptics.tick();
                widget.onTap!();
              }
            : null,
        onLongPress: widget.enabled && widget.onLongPress != null
            ? () {
                Haptics.longPress();
                widget.onLongPress!();
              }
            : null,
        child: body,
      );
      if (widget.semanticLabel != null) {
        body = Semantics(button: true, enabled: widget.enabled, label: widget.semanticLabel, child: body);
      }
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _press,
      onPointerMove: _move,
      onPointerUp: _release,
      onPointerCancel: _release,
      child: body,
    );
  }
}
