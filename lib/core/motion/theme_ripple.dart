// ignore_for_file: discarded_futures, unawaited_futures (animation futures are fire-and-forget)

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';

import 'motion.dart';
import 'motion_level.dart';

/// Theme change reveal (handoff decision 15). Wrap the app once; every theme
/// control calls `ThemeRipple.of(context).run(tapPosition, () => change())`.
///
/// run() snapshots the current frame (one GPU image, no await), applies the
/// change underneath, then draws the snapshot on top with a circular hole
/// growing from the tap to the farthest corner: 800 ms ease-in-out at
/// Expressive, 500 ms at Subtle, a 90 ms cross-fade of
/// the snapshot at Off (`Motion.themeReveal*`). Only a
/// clip and one image draw per frame. A second change mid-way snapshots the
/// frame as it is (ripple included) and replaces the first, so nothing jumps.
/// The overlay ignores pointers. If the snapshot fails (no layer yet, web),
/// the change is applied with no ripple.
class ThemeRipple extends StatefulWidget {
  const ThemeRipple({super.key, required this.child});
  final Widget child;

  /// Null when there is no [ThemeRipple] above (tests): callers then just apply.
  static ThemeRippleHandle? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_RippleScope>()?.handle;

  static ThemeRippleHandle of(BuildContext context) => maybeOf(context) ?? const _NoRipple();

  @override
  State<ThemeRipple> createState() => _ThemeRippleState();
}

abstract interface class ThemeRippleHandle {
  /// [globalPosition] is where the control was tapped (pointer-down); null
  /// grows the circle from the centre of the screen.
  Future<void> run(Offset? globalPosition, FutureOr<void> Function() apply);
}

class _NoRipple implements ThemeRippleHandle {
  const _NoRipple();
  @override
  Future<void> run(Offset? globalPosition, FutureOr<void> Function() apply) async => apply();
}

class _RippleScope extends InheritedWidget {
  const _RippleScope({required this.handle, required super.child});
  final ThemeRippleHandle handle;
  @override
  bool updateShouldNotify(_RippleScope old) => false;
}

class _Ripple {
  _Ripple(this.image, this.center, this.controller);
  final ui.Image image;
  final Offset center;
  final AnimationController controller;
}

class _ThemeRippleState extends State<ThemeRipple> with TickerProviderStateMixin implements ThemeRippleHandle {
  final GlobalKey _boundary = GlobalKey();
  final List<_Ripple> _ripples = [];
  MotionLevel _level = MotionLevel.expressive;

  /// Ripples currently drawn (tests).
  @visibleForTesting
  int get active => _ripples.length;

  @override
  Future<void> run(Offset? globalPosition, FutureOr<void> Function() apply) async {
    ui.Image? image;
    try {
      final box = _boundary.currentContext?.findRenderObject();
      if (box is RenderRepaintBoundary) {
        image = box.toImageSync(pixelRatio: View.of(context).devicePixelRatio);
      }
    } catch (e) {
      debugPrint('Unfurl: theme snapshot failed, no ripple: $e');
    }
    if (image == null || !mounted) {
      image?.dispose();
      await apply();
      return;
    }
    // Everything before this is baked into the new snapshot.
    for (final r in _ripples) {
      r.controller.dispose();
      r.image.dispose();
    }
    _ripples.clear();

    final off = _level == MotionLevel.off;
    final c = AnimationController(
      vsync: this,
      duration: off ? Motion.fxInstant : (_level == MotionLevel.subtle ? Motion.themeRevealSubtle : Motion.themeReveal),
    );
    final box = context.findRenderObject() as RenderBox;
    final ripple = _Ripple(
      image,
      box.globalToLocal(globalPosition ?? box.localToGlobal(box.size.center(Offset.zero))),
      c,
    );
    // The snapshot covers the app at t = 0, so the switch below is hidden.
    setState(() => _ripples.add(ripple));

    // Apply the change and let the app rebuild and render in the new theme
    // before revealing it. Starting the clock first spent most of the reveal
    // behind the preference write and the heavy rebuild frame, so the sweep
    // looked like a flash. Capped so a slow write can't hold the cover.
    try {
      final f = apply();
      if (f is Future) {
        await Future.any<void>([f, Future<void>.delayed(Motion.themeReveal)]);
      }
    } catch (e) {
      debugPrint('Unfurl: theme change failed: $e');
    }
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted || !_ripples.contains(ripple)) return;
    c.forward().whenComplete(() {
      if (!mounted || !_ripples.remove(ripple)) return;
      c.dispose();
      image!.dispose();
      setState(() {});
    });
  }

  @override
  void dispose() {
    for (final r in _ripples) {
      r.controller.dispose();
      r.image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _level = Motion.levelOf(context);
    const Curve curve = Motion.themeRevealCurve;
    return _RippleScope(
      handle: this,
      child: RepaintBoundary(
        key: _boundary,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            for (final r in _ripples)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _RipplePainter(r, off: _level == MotionLevel.off, curve: curve),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.r, {required this.off, required this.curve}) : super(repaint: r.controller);
  final _Ripple r;
  final bool off;
  final Curve curve;

  @override
  void paint(Canvas canvas, Size size) {
    final t = r.controller.value;
    final src = Rect.fromLTWH(0, 0, r.image.width.toDouble(), r.image.height.toDouble());
    final dst = Offset.zero & size;
    if (off) {
      canvas.drawImageRect(r.image, src, dst, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - t));
      return;
    }
    final c = r.center;
    final far = math.max(
      math.max((c - dst.topLeft).distance, (c - dst.topRight).distance),
      math.max((c - dst.bottomLeft).distance, (c - dst.bottomRight).distance),
    );
    final radius = far * curve.transform(t);
    final hole = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(dst)
      ..addOval(Rect.fromCircle(center: c, radius: radius));
    canvas.save();
    canvas.clipPath(hole);
    canvas.drawImageRect(r.image, src, dst, Paint());
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RipplePainter o) => o.r != r || o.off != off;
}
