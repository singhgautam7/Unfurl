import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/palette.dart';
import 'motion.dart';
import 'motion_level.dart';

/// M3 Expressive loading indicator: 7 shapes, one morph every 650 ms on
/// springDefault, turning 360 degrees per 1.6 s. Replaces circular spinners
/// (linear progress stays). Subtle: rotation only, one shape (Cookie 9).
/// Off: a still shape. The ticker only runs at Expressive / Subtle and stops
/// while the widget is not visible (TickerMode).
///
/// [contained]: [onPrimaryContainer] shape (30/48 of [size]) on a
/// primaryContainer circle. Otherwise [color] (default primary), 38/48.
class ShapeLoader extends StatefulWidget {
  const ShapeLoader({super.key, this.size = 48, this.contained = false, this.color});

  final double size;
  final bool contained;
  final Color? color;

  @override
  State<ShapeLoader> createState() => _ShapeLoaderState();
}

const _n = 72;
const _morphMs = 650;
const _turnMs = 1600;
const _staticShape = 1; // Cookie 9

final List<Float32List> _radii = () {
  double pent(double th) {
    const s = 2 * math.pi / 5;
    final m = ((th + math.pi / 2) % s + s) % s - s / 2;
    return .72 * math.cos(math.pi / 5) / math.cos(m) + .28;
  }

  double ell(double th, double a, double b, double rot) {
    final q = th + rot;
    return 1 / math.sqrt(math.pow(math.cos(q), 2) + math.pow(math.sin(q) / b, 2));
  }

  final fs = <double Function(double)>[
    (th) => 1 + .07 * math.cos(10 * th), // Soft burst
    (th) => 1 + .09 * math.cos(9 * th), // Cookie 9
    pent, // Pentagon
    (th) => ell(th, 1, .6, -math.pi / 4), // Pill
    (th) => 1 + .05 * math.cos(8 * th), // Sunny
    (th) => 1 + .13 * math.cos(4 * th), // Cookie 4
    (th) => ell(th, 1, .78, math.pi / 4), // Oval
  ];
  return [
    for (final f in fs)
      () {
        final r = Float32List(_n);
        var mx = 0.0;
        for (var i = 0; i < _n; i++) {
          r[i] = f(i / _n * 2 * math.pi);
          mx = math.max(mx, r[i]);
        }
        for (var i = 0; i < _n; i++) {
          r[i] /= mx;
        }
        return r;
      }(),
  ];
}();

final Float32List _cos = Float32List.fromList([for (var i = 0; i < _n; i++) math.cos(i / _n * 2 * math.pi)]);
final Float32List _sin = Float32List.fromList([for (var i = 0; i < _n; i++) math.sin(i / _n * 2 * math.pi)]);

class _ShapeLoaderState extends State<ShapeLoader> with SingleTickerProviderStateMixin {
  final ValueNotifier<Duration> _t = ValueNotifier(Duration.zero);
  late final Ticker _ticker = createTicker((d) => _t.value = d);
  MotionLevel _level = MotionLevel.off;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _level = Motion.levelOf(context);
    if (_level == MotionLevel.off) {
      if (_ticker.isActive) _ticker.stop();
      _t.value = Duration.zero;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final UnfurlColors? u = theme.extension<UnfurlColors>();
    final Color primary = u?.primary ?? theme.colorScheme.primary;
    final Color primaryContainer = u?.primaryContainer ?? theme.colorScheme.primaryContainer;
    final Color onContainer = u?.onPrimaryContainer ?? theme.colorScheme.onPrimaryContainer;
    final contained = widget.contained;
    final fg = contained ? onContainer : (widget.color ?? primary);
    final s = widget.size;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: s,
        child: CustomPaint(
          painter: _ShapePainter(
            t: _t,
            level: _level,
            color: fg,
            circle: contained ? primaryContainer : null,
            shapeSize: s * (contained ? 30 / 48 : 38 / 48),
          ),
        ),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter({
    required this.t,
    required this.level,
    required this.color,
    required this.circle,
    required this.shapeSize,
  }) : super(repaint: t);

  final ValueNotifier<Duration> t;
  final MotionLevel level;
  final Color color;
  final Color? circle;
  final double shapeSize;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (circle != null) {
      canvas.drawCircle(c, size.width / 2, Paint()..color = circle!);
    }
    final ms = t.value.inMicroseconds / 1000;
    final Float32List from, to;
    var p = 0.0;
    var rot = 0.0;
    if (level == MotionLevel.expressive) {
      final k = ms ~/ _morphMs;
      from = _radii[k % 7];
      to = _radii[(k + 1) % 7];
      final local = (ms - k * _morphMs) / 1000;
      p = _morph.x(local);
    } else {
      from = to = _radii[_staticShape];
    }
    if (level != MotionLevel.off) rot = 2 * math.pi * (ms % _turnMs) / _turnMs;
    // The design draws the shape in a viewBox of +-1.05.
    final r = shapeSize / 2.1;
    final path = Path();
    final cr = math.cos(rot), sr = math.sin(rot);
    for (var i = 0; i < _n; i++) {
      final rad = (from[i] + (to[i] - from[i]) * p) * r;
      final x = _cos[i] * rad, y = _sin[i] * rad;
      final px = c.dx + x * cr - y * sr, py = c.dy + x * sr + y * cr;
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_ShapePainter o) =>
      o.level != level || o.color != color || o.circle != circle || o.shapeSize != shapeSize;
}

/// Morph progress within one 650 ms step: springDefault.
final _morph = _MorphSim();

class _MorphSim {
  final _s = Motion.defaultCurve;
  double x(double seconds) => _s.transform((seconds * 1000 / _s.settle.inMilliseconds).clamp(0.0, 1.0));
}
