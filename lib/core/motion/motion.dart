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

  /// Page-turn styles (v2 · V2-03): Curl settles in 420, Cover slides over
  /// in 300, Fade cross-fades in 150. Slide uses [pageTurn].
  static const Duration pageCurl = Duration(milliseconds: 420);
  static const Duration pageCover = Duration(milliseconds: 300);
  static const Duration pageFade = Duration(milliseconds: 150);

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

  /// V3-COMFORT (`unfurl-v3-tokens.js`): a volume-key scroll of 90% of a
  /// screen, a held key's repeat, auto-scroll easing up to speed, its control
  /// hiding, and the sleep timer's fade.
  static const Duration volumeScroll = Duration(milliseconds: 280);
  static const Duration volumeRepeat = Duration(milliseconds: 400);
  static const Duration autoScrollRamp = Duration(milliseconds: 300);
  static const Duration autoControlHide = Duration(milliseconds: 2500);
  static const Duration sleepFade = Duration(seconds: 10);

  /// How long things stay before they go on their own (boards 3, 4 and 6):
  /// the page chip, a zoom % chip, the text-size chip, the scrubber's "Back to
  /// p." chip, a link's "Back" chip, the chrome while read aloud plays, and
  /// toasts (with an action or an error, longer: the undo window).
  static const Duration chipPage = Duration(milliseconds: 1500);
  static const Duration chipZoom = Duration(seconds: 1);
  static const Duration chipSize = Duration(milliseconds: 900);
  static const Duration chipScrubBack = Duration(seconds: 4);
  static const Duration chipLinkBack = Duration(seconds: 6);
  static const Duration chromeAutoHide = Duration(seconds: 4);
  static const Duration toast = Duration(seconds: 4);
  static const Duration toastLong = Duration(seconds: 5);

  /// Not animation: how long a position waits before it is written, and how
  /// long a zoomed PDF waits before sharper tiles are drawn.
  static const Duration saveDelay = Duration(milliseconds: 600);
  static const Duration sharpenDelay = Duration(milliseconds: 160);

  /// Anything the finger caused.
  static const Curve spring = Curves.easeOutBack;

  /// Anything the system caused.
  static const Curve decelerate = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOut;

  /// Back to the top of a tab (its nav item tapped again, as in Kuber): every
  /// row on the way is laid out, so never a jump; longer trips get more time
  /// and an even-speed curve keeps the rows per frame low.
  static Duration scrollTopFor(double screens) => Duration(milliseconds: (250 + screens * 40).clamp(250, 800).round());
  static const Curve scrollTop = Curves.easeInOutSine;

  /// The header search pill stays opaque for most of its grow and shrink
  /// (Kuber's), fading only in the first 30% of the open.
  static const Curve searchPillFade = Interval(0, 0.3);

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

/// A control that comes and goes with a setting (Page turn under Paged):
/// the space opens or closes on `containerTransform`, the content fades.
class ShowHide extends StatelessWidget {
  const ShowHide({required this.visible, required this.child, super.key});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: Motion.of(context, Motion.containerTransform),
    curve: Motion.curveOf(context, Motion.decelerate),
    alignment: Alignment.topCenter,
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: Motion.of(context, Motion.fast),
      child: visible ? child : const SizedBox(width: double.infinity),
    ),
  );
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
