import 'package:flutter/material.dart';

/// The one motion set: Mull's durations and curves, plus Unfurl's four.
///
/// Spring for anything the finger caused, decelerate for anything the system
/// caused. No widget names its own `Duration` or `Curve`.
abstract final class Motion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration navIndicator = Duration(milliseconds: 220);
  static const Duration containerTransform = Duration(milliseconds: 240);
  static const Duration sheet = Duration(milliseconds: 260);
  static const Duration navHide = Duration(milliseconds: 160);
  static const Duration snackEnter = Duration(milliseconds: 180);
  static const Duration snackExit = Duration(milliseconds: 140);

  /// A page or chrome background cross-fading between surfaces (Headshorts'
  /// and Mull's `cardBackground`).
  static const Duration background = Duration(milliseconds: 240);

  /// Reader bars on a centre tap: slide 12dp and fade.
  static const Duration chromeToggle = Duration(milliseconds: 160);
  static const Duration pageTurn = Duration(milliseconds: 260);

  /// Page to Reader, three phases. Reader to Page plays it back at
  /// [unfurlReverse].
  static const Duration unfurl = Duration(milliseconds: 520);
  static const Duration unfurlReverse = Duration(milliseconds: 440);

  /// The unfurl under reduced motion: a plain cross-fade.
  static const Duration unfurlReduced = Duration(milliseconds: 90);

  /// Content arriving on screen (tiles, toolbars, cards): fade and rise.
  static const Duration reveal = Duration(milliseconds: 220);

  /// The step between neighbours revealed together, capped so long lists
  /// never wait.
  static const Duration stagger = Duration(milliseconds: 28);
  static const int staggerCap = 8;

  /// Anything the finger caused.
  static const Curve spring = Curves.easeOutBack;

  /// Anything the system caused.
  static const Curve decelerate = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOut;

  /// Under OS reduced motion: transforms become cross-fades, springs go linear.
  static const Duration reducedFade = Duration(milliseconds: 90);

  static bool reduced(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    return mq.disableAnimations || mq.accessibleNavigation;
  }

  /// Duration to actually use, honouring reduced motion.
  static Duration of(BuildContext context, Duration full) => reduced(context) ? reducedFade : full;

  static Curve curveOf(BuildContext context, Curve full) => reduced(context) ? Curves.linear : full;
}

/// Content arriving: fades in while rising 8dp and settling from 0.98
/// scale, once, on first build. [index] staggers neighbours (tiles in a
/// grid). Under reduced motion it is a plain fade.
class Reveal extends StatefulWidget {
  const Reveal({required this.child, this.index = 0, super.key});

  final Widget child;
  final int index;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_t.duration != null) return;
    _t.duration = Motion.of(context, Motion.reveal);
    final Duration wait = Motion.stagger * widget.index.clamp(0, Motion.staggerCap);
    if (wait == Duration.zero || Motion.reduced(context)) {
      _t.forward();
    } else {
      Future<void>.delayed(wait, () {
        if (mounted) _t.forward();
      });
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = Motion.reduced(context);
    final Animation<double> a = CurvedAnimation(parent: _t, curve: Motion.decelerate);
    return AnimatedBuilder(
      animation: a,
      child: widget.child,
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: a.value,
        child: reduced
            ? child
            : Transform.translate(
                offset: Offset(0, 8 * (1 - a.value)),
                child: Transform.scale(scale: 0.98 + 0.02 * a.value, child: child),
              ),
      ),
    );
  }
}
