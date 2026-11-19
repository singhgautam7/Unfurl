import 'package:flutter/material.dart';

import 'motion_level.dart';
import 'spring.dart';

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
  static const Duration stagger = Duration(milliseconds: 30);
  static const int staggerCap = 6;

  /// Delay of item [index]: 30 ms steps, items past the 6th share the 6th's.
  static Duration staggerDelay(int index) => stagger * (index < 0 ? 0 : (index < staggerCap ? index : staggerCap - 1));

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

  /// Under Subtle and Off: transforms become cross-fades, springs go linear.
  static const Duration reducedFade = Duration(milliseconds: 90);

  // ---- Effects (opacity, colour: never springs), from Kuber. ----
  static const Duration fxInstant = instant;
  static const Duration fxFast = fast;
  static const Duration fxDefault = Duration(milliseconds: 200);

  /// Every opacity and colour change.
  static const Curve curveEffects = Cubic(0.33, 1, 0.68, 1);

  static const Duration reflow = Duration(milliseconds: 230);

  /// Kit internals: the content of an expanding section waits this long
  /// before it fades in; rolling digits start this far apart (right to left);
  /// a chart draws in over [chartDraw] (bars: [chartBar] each, staggered);
  /// haptics are at least [hapticGap] apart.
  static const Duration expandFadeDelay = Duration(milliseconds: 40);
  static const Duration digitStep = Duration(milliseconds: 20);
  static const Duration chartDraw = Duration(milliseconds: 400);
  static const Duration chartBar = Duration(milliseconds: 300);
  static const Duration hapticGap = Duration(milliseconds: 50);
  static const Duration digitRoll = Duration(milliseconds: 300);

  /// Theme change ripple: a timed reveal on an even ease-in-out. Subtle is
  /// shorter; Off cross-fades the snapshot over [fxInstant].
  static const Duration themeReveal = Duration(milliseconds: 800);
  static const Duration themeRevealSubtle = Duration(milliseconds: 500);
  static const Curve themeRevealCurve = Curves.easeInOutSine;

  // ---- Springs (mass 1). Interruptible: retarget with `springTo`. ----
  /// Small things: press, chips, radios, switch thumb, chevrons, menus.
  static final SpringDescription springFast = SpringDescription.withDampingRatio(mass: 1, stiffness: 800, ratio: 0.6);

  /// Medium things: enter, expand, list insert, dialogs, release of cards.
  static final SpringDescription springDefault = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: 0.8,
  );

  /// Large surfaces: sheets opening, container transform.
  static final SpringDescription springSlow = SpringDescription.withDampingRatio(mass: 1, stiffness: 200, ratio: 0.8);

  /// Reflow with no visible bounce: heights, widths, closing.
  static final SpringDescription springStandard = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 700,
    ratio: 0.9,
  );

  /// Every spatial motion at the Subtle level (critically damped).
  static final SpringDescription springSubtle = SpringDescription.withDampingRatio(mass: 1, stiffness: 600, ratio: 1);

  /// Cached spring curves for implicit animations (`.settle` as the duration,
  /// `.clamped` for sizes).
  static final SpringCurve fastCurve = SpringCurve(springFast);
  static final SpringCurve defaultCurve = SpringCurve(springDefault);
  static final SpringCurve slowCurve = SpringCurve(springSlow);
  static final SpringCurve standardCurve = SpringCurve(springStandard);
  static final SpringCurve subtleCurve = SpringCurve(springSubtle);

  /// [expressive] at Expressive, [springSubtle] at Subtle. (Off: callers skip.)
  static SpringDescription spatial(MotionLevel l, SpringDescription expressive) =>
      l == MotionLevel.subtle ? springSubtle : expressive;

  /// Curve counterpart of [spatial].
  static SpringCurve spatialCurve(MotionLevel l, SpringCurve expressive) =>
      l == MotionLevel.subtle ? subtleCurve : expressive;

  // ---- Press amounts ----
  static const double pressScaleCard = 0.98; // cards and list rows
  static const double pressScaleSubtle = 0.99;
  static const double pressScaleFab = 0.96;
  static const double pressScaleChip = 0.96;
  static const double buttonGroupWiden = 0.15;

  /// Press corner radii (dp): buttons and icon buttons rest at 20, FAB 16,
  /// chips 8, everything else 20 with no change.
  static const double radiusRest = 20;
  static const double radiusRestFab = 16;
  static const double radiusRestChip = 8;
  static const double radiusPressedButton = 8;
  static const double radiusPressedIconButton = 12;
  static const double radiusPressedFab = 12;
  static const double radiusPressedChip = 6;

  /// Effective level here: preference + device, and the phone's Remove
  /// animations wins (Off). Cheap: reads one InheritedWidget. Without a
  /// [MotionScope] (tests, startup) it is Expressive unless the phone asks
  /// for no animations.
  static MotionLevel levelOf(BuildContext context) {
    final MotionScope? s = MotionScope.maybeOf(context);
    if (s != null) return s.level;
    final MediaQueryData? mq = MediaQuery.maybeOf(context);
    return mq != null && (mq.disableAnimations || mq.accessibleNavigation) ? MotionLevel.off : MotionLevel.expressive;
  }

  static bool isOff(BuildContext context) => levelOf(context) == MotionLevel.off;

  /// Not Expressive: callers that only know "reduced" keep working.
  static bool reduced(BuildContext context) => levelOf(context) != MotionLevel.expressive;

  /// Duration to actually use: [reducedFade] at Subtle and Off (Kuber's `of`).
  static Duration of(BuildContext context, Duration full) => reduced(context) ? reducedFade : full;

  static Curve curveOf(BuildContext context, Curve full) => reduced(context) ? Curves.linear : full;

  /// [base] at variable weight [wght] (`wght` axis; a static font snaps to
  /// the nearest [FontWeight]).
  static TextStyle weightStyle(TextStyle base, double wght) => base.copyWith(
    fontWeight: FontWeight.lerp(FontWeight.w100, FontWeight.w900, ((wght - 100) / 800).clamp(0.0, 1.0)),
    fontVariations: <FontVariation>[FontVariation('wght', wght)],
  );
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
/// grid, 30 ms steps, 6 at most). Subtle: a plain fade. Off: instant.
class Reveal extends StatefulWidget {
  const Reveal({required this.child, this.index = 0, super.key});

  final Widget child;
  final int index;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final MotionLevel level = Motion.levelOf(context);
    if (level == MotionLevel.off) {
      _t.value = 1;
      return;
    }
    _t.duration = level == MotionLevel.subtle ? Motion.fast : Motion.reveal;
    final Duration wait = level == MotionLevel.subtle ? Duration.zero : Motion.staggerDelay(widget.index);
    if (wait == Duration.zero) {
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
    final bool plain = Motion.levelOf(context) != MotionLevel.expressive;
    final Animation<double> a = CurvedAnimation(parent: _t, curve: Motion.decelerate);
    return AnimatedBuilder(
      animation: a,
      child: widget.child,
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: a.value,
        child: plain
            ? child
            : Transform.translate(
                offset: Offset(0, 8 * (1 - a.value)),
                child: Transform.scale(scale: 0.98 + 0.02 * a.value, child: child),
              ),
      ),
    );
  }
}
