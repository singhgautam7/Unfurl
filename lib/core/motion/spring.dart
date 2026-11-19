// ignore_for_file: discarded_futures, unawaited_futures (animation futures are fire-and-forget)

import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// A [Curve] that follows [spring] from 0 to 1 and settles by t = 1, for use
/// with implicit animations. Pair it with [settle] as the duration. Build one
/// per spring (static final), never per frame.
class SpringCurve extends Curve {
  SpringCurve(this.spring) : _sim = SpringSimulation(spring, 0, 1, 0);
  final SpringDescription spring;
  final SpringSimulation _sim;

  /// Time for the spring to settle within 0.1 %.
  late final Duration settle = () {
    double t = 0;
    while (t < 2 && !_sim.isDone(t)) {
      t += 0.005;
    }
    return Duration(milliseconds: (t * 1000).round());
  }();

  /// The same spring clamped to 0..1, for sizes and width factors that must
  /// never go negative or overshoot.
  late final ClampedSpringCurve clamped = ClampedSpringCurve(this);

  @override
  double transformInternal(double t) => _sim.x(t * settle.inMilliseconds / 1000);
}

/// [inner] clamped to 0..1.
class ClampedSpringCurve extends Curve {
  const ClampedSpringCurve(this.inner);
  final SpringCurve inner;
  Duration get settle => inner.settle;
  @override
  double transformInternal(double t) => inner.transform(t).clamp(0.0, 1.0);
}

/// Retarget a running spring from its current value AND velocity (never
/// restarts). Use on an [AnimationController.unbounded]: a bounded one would
/// clamp the overshoot. The ticker stops by itself when the spring settles,
/// and the value then snaps to exactly [target].
extension SpringTo on AnimationController {
  TickerFuture springTo(double target, SpringDescription spring) {
    final TickerFuture f = animateWith(SpringSimulation(spring, value, target, velocity));
    f.then((_) {
      if (!isAnimating) value = target;
    });
    return f;
  }
}
