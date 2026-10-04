import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_theme.dart';
import '../reading_prefs.dart';

/// Paged reading with the Curl or Cover turn (v2 · V2-03).
///
/// A turn is always between a pair of neighbours (lo, lo + 1) at progress
/// 0 (lo shows) to 1 (lo + 1 shows), so going back is going forward played
/// in reverse. Curl: lo peels from the touched corner, following the finger,
/// over lo + 1; its back face is paper with ink at 8%. Cover: lo + 1 slides
/// over lo, which stays put.
class TurnPager extends StatefulWidget {
  const TurnPager({
    required this.style,
    required this.index,
    required this.count,
    required this.builder,
    required this.onTurned,
    required this.backFace,
    super.key,
  }) : assert(style == PageTurn.curl || style == PageTurn.cover);

  final PageTurn style;
  final int index;
  final int count;
  final Widget Function(int) builder;
  final ValueChanged<int> onTurned;

  /// Curl's back face.
  final Color backFace;

  @override
  State<TurnPager> createState() => TurnPagerState();
}

class TurnPagerState extends State<TurnPager> with SingleTickerProviderStateMixin {
  late final AnimationController _p = AnimationController(vsync: this)..addListener(() => setState(() {}));

  /// The pair being turned; null at rest.
  int? _lo;
  bool _forward = true;

  /// Curl's corner: the bottom one unless the finger started in the top half.
  bool _top = false;

  /// How far the finger has moved the corner up or down.
  double _lift = 0;
  Offset? _start;
  Size _size = Size.zero;

  bool get _curl => widget.style == PageTurn.curl;
  Duration get _full => _curl ? Motion.pageCurl : Motion.pageCover;

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  /// A tap or key turn: from the bottom corner, the whole way.
  void turn(int delta) {
    if (_lo != null) return;
    if (!_begin(forward: delta > 0)) return;
    _top = false;
    _lift = 0;
    _settle(delta > 0 ? 1 : 0);
  }

  bool _begin({required bool forward}) {
    final int i = widget.index;
    if (forward ? i + 1 >= widget.count : i == 0) return false;
    _lo = forward ? i : i - 1;
    _forward = forward;
    _p.value = forward ? 0 : 1;
    return true;
  }

  void _onStart(DragStartDetails d) {
    if (_p.isAnimating) return;
    _start = d.localPosition;
  }

  void _onUpdate(DragUpdateDetails d) {
    final Offset? start = _start;
    if (start == null || _size.isEmpty) return;
    if (_lo == null) {
      if (d.delta.dx == 0 || !_begin(forward: d.delta.dx < 0)) return;
      _top = start.dy < _size.height / 2;
    }
    // The curl's corner travels two page widths; the cover's edge one.
    _p.value -= d.delta.dx / (_size.width * (_curl ? 2 : 1));
    _lift = (d.localPosition.dy - start.dy).clamp(-_size.height / 3, _size.height / 3);
  }

  void _onEnd(DragEndDetails d) {
    // A drag that began mid-settle has no start; the settle carries on.
    if (_start == null || _lo == null) return;
    _start = null;
    final double v = d.primaryVelocity ?? 0;
    // Past half a page width of finger travel the turn completes; the curl's
    // corner moves twice as far, so its line is a quarter.
    final double past = _curl ? 0.25 : 0.5;
    final double travelled = _forward ? _p.value : 1 - _p.value;
    final bool done = v.abs() > 300 ? (v < 0) == _forward : travelled > past;
    _settle(done == _forward ? 1 : 0);
  }

  void _settle(double target) {
    final double from = _p.value;
    final double lift = _lift;
    final double span = (target - from).abs();
    void follow() => _lift = span == 0 ? 0 : lift * (target - _p.value).abs() / span;
    _p.addListener(follow);
    _p.animateTo(target, duration: _full * math.max(span, 0.25), curve: Motion.decelerate).whenCompleteOrCancel(() {
      _p.removeListener(follow);
      if (!mounted) return;
      final int now = _lo! + target.round();
      setState(() => _lo = null);
      if (now != widget.index) widget.onTurned(now);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) {
      _size = box.biggest;
      return GestureDetector(
        onHorizontalDragStart: _onStart,
        onHorizontalDragUpdate: _onUpdate,
        onHorizontalDragEnd: _onEnd,
        child: _lo == null ? widget.builder(widget.index) : _pair(context, _lo!),
      );
    },
  );

  Widget _pair(BuildContext context, int lo) {
    final double p = _p.value;
    final Widget under = KeyedSubtree(key: ValueKey<int>(lo), child: widget.builder(lo));
    final Widget over = KeyedSubtree(key: ValueKey<int>(lo + 1), child: widget.builder(lo + 1));
    if (!_curl) {
      return Stack(
        children: <Widget>[
          under,
          Transform.translate(
            offset: Offset(_size.width * (1 - p), 0),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                boxShadow: <BoxShadow>[
                  BoxShadow(color: context.colors.shadow, blurRadius: 10, offset: const Offset(-6, 0)),
                ],
              ),
              child: over,
            ),
          ),
        ],
      );
    }
    final _Fold fold = _Fold(_size, p, _lift, top: _top);
    return Stack(
      children: <Widget>[
        over,
        ClipPath(clipper: _Clip(fold.remaining), child: under),
        IgnorePointer(
          child: CustomPaint(size: _size, painter: _FlapPainter(fold.flap, widget.backFace, context.colors.shadow)),
        ),
      ],
    );
  }
}

/// A straight fold: the corner has moved from its rest point C to P, so the
/// fold is the perpendicular bisector of CP. What lies past it on the corner
/// side is turned over and drawn reflected (the flap).
class _Fold {
  _Fold(Size s, double p, double lift, {required bool top}) {
    final List<Offset> page = <Offset>[Offset.zero, Offset(s.width, 0), Offset(s.width, s.height), Offset(0, s.height)];
    final Offset c = Offset(s.width, top ? 0 : s.height);
    final Offset at = Offset(s.width - 2 * s.width * p, c.dy + lift);
    final Offset d = c - at;
    if (p <= 0 || d.distance < 0.5) {
      remaining = page;
      flap = const <Offset>[];
      return;
    }
    final Offset m = (c + at) / 2;
    final Offset n = d / d.distance;
    double side(Offset x) => (x.dx - m.dx) * n.dx + (x.dy - m.dy) * n.dy;
    remaining = _cut(page, (Offset x) => -side(x));
    flap = <Offset>[for (final Offset x in _cut(page, side)) x - n * (2 * side(x))];
  }

  late final List<Offset> remaining;
  late final List<Offset> flap;

  /// The part of [poly] where [f] >= 0 (one Sutherland-Hodgman pass).
  static List<Offset> _cut(List<Offset> poly, double Function(Offset) f) {
    final List<Offset> out = <Offset>[];
    for (int i = 0; i < poly.length; i++) {
      final Offset a = poly[i], b = poly[(i + 1) % poly.length];
      final double fa = f(a), fb = f(b);
      if (fa >= 0) out.add(a);
      if ((fa >= 0) != (fb >= 0)) out.add(Offset.lerp(a, b, fa / (fa - fb))!);
    }
    return out;
  }
}

Path _path(List<Offset> points) => Path()..addPolygon(points, true);

class _Clip extends CustomClipper<Path> {
  _Clip(this.points);

  final List<Offset> points;

  @override
  Path getClip(Size size) => _path(points);

  @override
  bool shouldReclip(_Clip old) => true;
}

class _FlapPainter extends CustomPainter {
  _FlapPainter(this.points, this.back, this.shadow);

  final List<Offset> points;
  final Color back;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 3) return;
    canvas.clipRect(Offset.zero & size);
    final Path flap = _path(points);
    canvas.drawShadow(flap, shadow, 6, false);
    canvas.drawPath(flap, Paint()..color = back);
  }

  @override
  bool shouldRepaint(_FlapPainter old) => true;
}
