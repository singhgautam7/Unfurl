// ignore_for_file: discarded_futures, unawaited_futures (animation futures are fire-and-forget)

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/motion/motion.dart';
import '../core/motion/motion_level.dart';
import '../core/motion/spring.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../features/settings/settings_controller.dart';

/// Geometry and scroll thresholds of the floating header, copied from Kuber
/// (`kuber_app_bar.dart`, `_Fh`, :542-575) except where a line says otherwise.
abstract final class FloatingHeaderSpec {
  /// The header becomes the pill at this scroll offset (Kuber :546)...
  static const double toPill = 32;

  /// ...and the header again at or below this one (:550). Between them it
  /// keeps its state, so stopping on a line never flickers.
  static const double toHeader = 8;

  /// Pill margin, top gap, height, radius (Kuber :551-554).
  static const double margin = 12;
  static const double top = 8;
  static const double pillHeight = 56;
  static const double radius = 28;

  /// A hidden pill goes this far up (Kuber :555).
  static const double hideDistance = 72;

  /// When scrolling up: hide after this much continuous downward scroll,
  /// show after [showAfter] upward. When scrolling stops: hide after this
  /// much movement (Kuber :561-563).
  static const double hideAfter = 16;
  static const double showAfter = 8;

  /// Show this long after the page stops (Kuber :564, 300 ms = 2 x fast).
  static final Duration stopDelay = Motion.fast * 2;

  /// Title 22 to 16 dp in the pill (Kuber :570); the pill drops a title with
  /// less than [minTitle] dp, or at text scale [dropAtScale] and up.
  static const double titleScale = 16 / 22;
  static const double minTitle = 96;
  static const double dropAtScale = 1.5;

  /// Title x 20 to 28 (and the right edge) when there is no button (:574).
  static const double noButtonShift = 8;

  /// A dropped title fades over the first 60 % of the morph (Kuber :578).
  static const double titleDropEnd = 0.6;

  /// Expressive hide fades 1.25x faster than it travels; Subtle only settles
  /// 4 dp (Kuber `_HideTransform`).
  static const double expressiveFade = 1.25;
  static const double subtleShift = 4;

  /// The rest header: 8 + a 48 row + 8 (measured once built, so large text
  /// and a crumb line are covered).
  static const double rest = Space.sm * 2 + IconSpec.tapTarget;

  /// Scrim under the status bar reaches this far below it, at this alpha
  /// (Kuber `fh-scrim`).
  static const double scrimBelow = 16;
  static const double scrimAlpha = 0.94;
}

/// What the page tells its header: the morph's progress (0 header, 1 pill, may
/// overshoot at Expressive), whether it floats, and the search hook.
class HeaderFloat extends InheritedWidget {
  const HeaderFloat({
    required this.progress,
    required this.floating,
    required this.inset,
    required this.onSearch,
    required super.child,
    super.key,
  });

  final Animation<double> progress;

  /// The header morphs (the setting is on).
  final bool floating;

  /// The gap a body's first item leads with (see [HeaderPage.insetOf]).
  final double inset;

  /// Header search opened (true) or closed (false).
  final ValueChanged<bool> onSearch;

  static HeaderFloat? maybeOf(BuildContext context, {bool listen = true}) => listen
      ? context.dependOnInheritedWidgetOfExactType<HeaderFloat>()
      : context.getInheritedWidgetOfExactType<HeaderFloat>();

  @override
  bool updateShouldNotify(HeaderFloat old) => floating != old.floating || inset != old.inset;
}

/// A page under the common header. The [header] sits over the [body] as an
/// overlay; past 32 dp of scroll it morphs into the floating pill and back
/// within 8 dp of the top, following the Floating header setting, the pill
/// mode and the Motion level. With the setting off it scrolls away with the
/// content. One scroll listener lives here; it updates state only when a
/// threshold is crossed or the direction changes, and the body never rebuilds
/// because of it.
///
/// The [body]'s scrollable starts [inset] dp down, so its first item sits
/// below the header at rest. Only the header is sticky: chips and filters
/// scroll with the body.
class HeaderPage extends ConsumerStatefulWidget {
  const HeaderPage({
    required this.header,
    required this.body,
    this.floating,
    this.pillMode,
    this.gutter = 0,
    super.key,
  });

  final Widget header;
  final Widget Function(BuildContext context, double inset) body;

  /// Overrides the settings (the Look previews).
  final bool? floating;
  final PillMode? pillMode;

  /// Header and pill stay this far in from both edges (centred wide pages).
  final double gutter;

  /// The gap a body leads with: the header at rest when it scrolls away with
  /// the content (Floating header off), else 0 (the host pads the viewport).
  static double insetOf(BuildContext context) => HeaderFloat.maybeOf(context)?.inset ?? 0;

  /// A body that is not a scrollable (an empty state) starts below the header.
  static Widget below(Widget child) => Builder(
    builder: (BuildContext c) => Padding(
      padding: EdgeInsets.only(top: insetOf(c)),
      child: child,
    ),
  );

  /// The first sliver of a CustomScrollView body: [insetOf] tall.
  static Widget sliverGap() => Builder(
    builder: (BuildContext c) => SliverToBoxAdapter(child: SizedBox(height: insetOf(c))),
  );

  @override
  ConsumerState<HeaderPage> createState() => _HeaderPageState();
}

class _HeaderPageState extends ConsumerState<HeaderPage> with TickerProviderStateMixin {
  late final AnimationController _p = AnimationController.unbounded(vsync: this);
  late final AnimationController _a0 = AnimationController(vsync: this, value: 1);
  late final AnimationController _a1 = AnimationController(vsync: this);
  late final AnimationController _shift = AnimationController.unbounded(vsync: this);
  late final AnimationController _h = AnimationController.unbounded(vsync: this);
  late final AnimationController _scrim = AnimationController(vsync: this);
  final ProxyAnimation _contentAlpha = ProxyAnimation(kAlwaysCompleteAnimation);
  final ValueNotifier<double> _away = ValueNotifier<double>(0);
  final ValueNotifier<bool> _hiddenN = ValueNotifier<bool>(false);
  final ValueNotifier<double> _rest = ValueNotifier<double>(FloatingHeaderSpec.rest);
  final GlobalKey _headerKey = GlobalKey();

  bool _pill = false;
  bool _scrolled = false;
  bool _searching = false;
  bool _measureQueued = false;
  double _pixels = 0;
  double _down = 0;
  double _up = 0;
  double _moved = 0;
  Timer? _showTimer;
  MotionLevel _level = MotionLevel.expressive;
  PillMode _mode = PillMode.always;
  bool _floating = true;
  double _statusBar = -1;

  double get _extent => _statusBar + _rest.value;

  @override
  void initState() {
    super.initState();
    _queueMeasure();
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    for (final AnimationController c in <AnimationController>[_p, _a0, _a1, _shift, _h, _scrim]) {
      c.dispose();
    }
    _away.dispose();
    _hiddenN.dispose();
    _rest.dispose();
    super.dispose();
  }

  // ---- The header's real height (large text, a crumb line) ----

  void _queueMeasure() {
    if (_measureQueued) return;
    _measureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureQueued = false;
      if (!mounted || _searching) return;
      final RenderObject? box = _headerKey.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      if ((box.size.height - _rest.value).abs() > 0.5) _rest.value = box.size.height;
    });
  }

  // ---- State changes (only on thresholds and direction) ----

  void _setPill(bool pill, {bool slow = false}) {
    if (pill == _pill) return;
    _pill = pill;
    final double t = pill ? 1.0 : 0.0;
    switch (_level) {
      case MotionLevel.expressive:
        _p.springTo(t, pill ? Motion.springDefault : (slow ? Motion.springSlow : Motion.springStandard));
      case MotionLevel.subtle:
        // Two layers at their exact bounds: the outgoing one fades out
        // quickly, the incoming one fades in and settles 4 dp down.
        _p.value = t;
        _a0.animateTo(1 - t, duration: pill ? Motion.fxInstant : Motion.fxFast, curve: Motion.curveEffects);
        _a1.animateTo(t, duration: pill ? Motion.fxFast : Motion.fxInstant, curve: Motion.curveEffects);
        _contentAlpha.parent = pill ? _a1 : _a0;
        if (pill) {
          _shift.value = FloatingHeaderSpec.subtleShift;
          _shift.springTo(0, Motion.springSubtle);
        } else {
          _shift.value = 0;
        }
        _scrim.animateTo(t, duration: pill ? Motion.fxDefault : Motion.fxFast, curve: Motion.curveEffects);
      case MotionLevel.off:
        _p.value = t;
        _scrim.value = t;
    }
  }

  void _setHidden(bool hidden) {
    if (hidden == _hiddenN.value) return;
    _hiddenN.value = hidden;
    final double t = hidden ? 1.0 : 0.0;
    switch (_level) {
      case MotionLevel.expressive:
        _h.springTo(t, hidden ? Motion.springStandard : Motion.springDefault);
      case MotionLevel.subtle:
        _h.animateTo(t, duration: Motion.fxFast, curve: Motion.curveEffects);
      case MotionLevel.off:
        _h.animateTo(t, duration: Motion.fxInstant);
    }
  }

  void _setScrolled(bool scrolled) {
    if (scrolled == _scrolled) return;
    _scrolled = scrolled;
    if (_level == MotionLevel.off) {
      _scrim.value = scrolled ? 1 : 0;
    } else {
      _scrim.animateTo(scrolled ? 1 : 0, duration: Motion.fxDefault, curve: Motion.curveEffects);
    }
  }

  /// Snap every value to the current state (level or setting changed).
  void _snap() {
    _showTimer?.cancel();
    _down = _up = _moved = 0;
    _pill = _floating && _pixels >= FloatingHeaderSpec.toPill;
    final double t = _pill ? 1.0 : 0.0;
    _p.value = t;
    _a0.value = 1 - t;
    _a1.value = t;
    _shift.value = 0;
    _contentAlpha.parent = _level == MotionLevel.subtle ? (_pill ? _a1 : _a0) : kAlwaysCompleteAnimation;
    _hiddenN.value = false;
    _h.value = 0;
    _scrolled = _pixels > 0;
    _scrim.value = _floating ? t : (_scrolled ? 1 : 0);
    _away.value = _floating ? 0 : _pixels.clamp(0.0, _extent);
  }

  /// Search opened or closed. The open search bar is the header's content, so
  /// it morphs into the pill like any header: nothing else changes.
  void _onSearch(bool open) {
    _searching = open;
    if (open) {
      _showTimer?.cancel();
      _setHidden(false);
    } else {
      _queueMeasure();
    }
  }

  bool _keyboardOpen() => View.of(context).viewInsets.bottom > 0;

  bool _onScroll(ScrollNotification n) {
    // Only this page's own list: a preview or sheet inside it is deeper.
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final double px = n.metrics.pixels - n.metrics.minScrollExtent;
    _pixels = px;
    if (!_floating) {
      final double a = px.clamp(0.0, _extent);
      if (a != _away.value) _away.value = a;
      _setScrolled(px > 0);
      return false;
    }
    if (!_pill && px >= FloatingHeaderSpec.toPill) {
      _setPill(true);
    } else if (_pill && px <= FloatingHeaderSpec.toHeader) {
      _setPill(false);
      _setHidden(false);
      _showTimer?.cancel();
      _down = _up = _moved = 0;
    }
    if (!_pill) return false;
    final double delta = n is ScrollUpdateNotification ? (n.scrollDelta ?? 0) : 0.0;
    switch (_mode) {
      case PillMode.scrollUp:
        if (delta > 0) {
          _down += delta;
          _up = 0;
          if (_down > FloatingHeaderSpec.hideAfter && !_keyboardOpen()) _setHidden(true);
        } else if (delta < 0) {
          _up -= delta;
          _down = 0;
          if (_up > FloatingHeaderSpec.showAfter) _setHidden(false);
        }
      case PillMode.scrollStop:
        if (delta != 0) {
          _showTimer?.cancel();
          _moved += delta.abs();
          if (_moved > FloatingHeaderSpec.hideAfter && !_keyboardOpen()) _setHidden(true);
        } else if (n is ScrollEndNotification) {
          _moved = 0;
          _showTimer?.cancel();
          _showTimer = Timer(FloatingHeaderSpec.stopDelay, () {
            if (mounted) _setHidden(false);
          });
        }
      case PillMode.always:
        break;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool floating = widget.floating ?? ref.watch(settingsProvider.select((AppSettings s) => s.floatingHeader));
    final PillMode mode = widget.pillMode ?? ref.watch(settingsProvider.select((AppSettings s) => s.pillMode));
    final MotionLevel level = Motion.levelOf(context);
    final double sb = MediaQuery.paddingOf(context).top;
    if (_statusBar < 0 || floating != _floating || mode != _mode || level != _level || sb != _statusBar) {
      _statusBar = sb;
      _floating = floating;
      _mode = mode;
      _level = level;
      _snap();
    }
    final Color bg = Theme.of(context).scaffoldBackgroundColor;
    final UnfurlColors c = context.colors;

    final Widget scrim = Positioned(
      key: const ValueKey<String>('header-scrim'),
      top: 0,
      left: 0,
      right: 0,
      height: sb + FloatingHeaderSpec.scrimBelow,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: floating && level == MotionLevel.expressive ? _ClampedAnimation(_p) : _scrim,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: <double>[0, sb * 0.5 / (sb + FloatingHeaderSpec.scrimBelow), 1],
                colors: <Color>[
                  bg.withValues(alpha: FloatingHeaderSpec.scrimAlpha),
                  bg.withValues(alpha: FloatingHeaderSpec.scrimAlpha),
                  bg.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // The header, its surface and its hide/away transform: transform, opacity
    // and paint only, inside one RepaintBoundary.
    Widget header = NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (SizeChangedLayoutNotification _) {
        _queueMeasure();
        return true;
      },
      child: SizeChangedLayoutNotifier(key: _headerKey, child: widget.header),
    );
    header = _Surface(
      progress: _p,
      restAlpha: _a0,
      pillAlpha: _a1,
      contentAlpha: _contentAlpha,
      rest: _rest,
      statusBar: sb,
      subtle: level == MotionLevel.subtle,
      floating: floating,
      restColor: bg,
      pillColor: c.surfaceContainer,
      borderColor: c.outline,
      shadows: <BoxShadow>[
        BoxShadow(color: c.shadow, blurRadius: Elevations.navPillBlur, offset: const Offset(0, Elevations.navPill)),
      ],
      child: header,
    );
    header = ValueListenableBuilder<bool>(
      valueListenable: _hiddenN,
      child: header,
      // A hidden pill is not focusable and takes no taps.
      builder: (BuildContext _, bool hidden, Widget? child) => IgnorePointer(
        ignoring: hidden,
        child: ExcludeSemantics(excluding: hidden, child: child),
      ),
    );
    header = _HideTransform(
      hide: _h,
      shift: _shift,
      away: floating ? null : _away,
      rest: _rest,
      statusBar: sb,
      level: level,
      child: header,
    );

    return ValueListenableBuilder<double>(
      valueListenable: _rest,
      builder: (BuildContext context, double rest, Widget? _) => HeaderFloat(
        progress: floating ? _p : kAlwaysDismissedAnimation,
        floating: floating,
        inset: floating ? 0 : sb + rest,
        onSearch: _onSearch,
        child: Stack(
          children: <Widget>[
            NotificationListener<ScrollNotification>(
              key: const ValueKey<String>('header-body'),
              onNotification: _onScroll,
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                // Floating: the body's viewport starts below the header and draws
                // past its top edge (clipBehavior none), so a reveal aligns below
                // the header. Off: the header scrolls away with a gap sliver.
                child: Padding(
                  padding: EdgeInsets.only(top: floating ? sb + rest : 0),
                  child: Builder(builder: (BuildContext b) => widget.body(b, floating ? 0 : sb + rest)),
                ),
              ),
            ),
            if (floating) scrim,
            Positioned(
              key: const ValueKey<String>('header-overlay'),
              top: 0,
              left: widget.gutter,
              right: widget.gutter,
              child: RepaintBoundary(child: Semantics(container: true, explicitChildNodes: true, child: header)),
            ),
            if (!floating) scrim,
          ],
        ),
      ),
    );
  }
}

/// Hidden (pill modes) and the Subtle settle, or Floating header off's
/// scroll-away: transform and opacity only.
class _HideTransform extends StatelessWidget {
  const _HideTransform({
    required this.hide,
    required this.shift,
    required this.away,
    required this.rest,
    required this.statusBar,
    required this.level,
    required this.child,
  });

  final Animation<double> hide;
  final Animation<double> shift;
  final ValueListenable<double>? away;
  final ValueListenable<double> rest;
  final double statusBar;
  final MotionLevel level;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ValueListenable<double>? a = away;
    if (a != null) {
      return ValueListenableBuilder<double>(
        valueListenable: a,
        child: child,
        builder: (BuildContext _, double v, Widget? c) =>
            Transform.translate(offset: Offset(0, -math.min(v, statusBar + rest.value)), child: c),
      );
    }
    final double dist = switch (level) {
      MotionLevel.expressive => FloatingHeaderSpec.hideDistance,
      MotionLevel.subtle => FloatingHeaderSpec.subtleShift,
      MotionLevel.off => 0.0,
    };
    final double fade = level == MotionLevel.expressive ? FloatingHeaderSpec.expressiveFade : 1.0;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[hide, shift]),
      child: child,
      builder: (BuildContext _, Widget? c) {
        final double h = hide.value;
        final double o = (1 - h * fade).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, shift.value - h * dist),
          child: Opacity(opacity: o, alwaysIncludeSemantics: true, child: c),
        );
      },
    );
  }
}

/// The header's surface: the full-width rest header (opaque page colour, over
/// the status bar) lerped into the pill (12 dp margins, 8 dp under the status
/// bar, 56 dp, r28, raised surface, hairline, shadow), with the content kept
/// centred in whichever it is. Paint and transform only.
class _Surface extends StatelessWidget {
  const _Surface({
    required this.progress,
    required this.restAlpha,
    required this.pillAlpha,
    required this.contentAlpha,
    required this.rest,
    required this.statusBar,
    required this.subtle,
    required this.floating,
    required this.restColor,
    required this.pillColor,
    required this.borderColor,
    required this.shadows,
    required this.child,
  });

  final Animation<double> progress;
  final Animation<double> restAlpha;
  final Animation<double> pillAlpha;
  final Animation<double> contentAlpha;
  final ValueListenable<double> rest;
  final double statusBar;
  final bool subtle;
  final bool floating;
  final Color restColor;
  final Color pillColor;
  final Color borderColor;
  final List<BoxShadow> shadows;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: rest,
    child: child,
    builder: (BuildContext _, double restH, Widget? c) => CustomPaint(
      painter: _SurfacePainter(
        progress: progress,
        restAlpha: restAlpha,
        pillAlpha: pillAlpha,
        subtle: subtle,
        restBottom: statusBar + restH,
        pillTop: statusBar + FloatingHeaderSpec.top,
        pillBottom: statusBar + FloatingHeaderSpec.top + FloatingHeaderSpec.pillHeight,
        rest: restColor,
        pill: pillColor,
        border: borderColor,
        shadows: shadows,
        floating: floating,
      ),
      child: Padding(
        padding: EdgeInsets.only(top: statusBar),
        child: FadeTransition(
          opacity: contentAlpha,
          child: AnimatedBuilder(
            animation: progress,
            child: c,
            // The row stays centred: in the pill it sits (56 - row) / 2 below
            // its top, 4 dp lower than at rest for a 64 dp header.
            builder: (BuildContext _, Widget? row) => Transform.translate(
              offset: Offset(
                0,
                floating
                    ? (FloatingHeaderSpec.top + FloatingHeaderSpec.pillHeight / 2 - restH / 2) *
                          progress.value.clamp(0.0, 1.0)
                    : 0,
              ),
              child: row,
            ),
          ),
        ),
      ),
    ),
  );
}

class _SurfacePainter extends CustomPainter {
  _SurfacePainter({
    required this.progress,
    required this.restAlpha,
    required this.pillAlpha,
    required this.subtle,
    required this.restBottom,
    required this.pillTop,
    required this.pillBottom,
    required this.rest,
    required this.pill,
    required this.border,
    required this.shadows,
    required this.floating,
  }) : super(repaint: Listenable.merge(<Listenable>[progress, restAlpha, pillAlpha]));

  final Animation<double> progress;
  final Animation<double> restAlpha;
  final Animation<double> pillAlpha;
  final bool subtle;
  final double restBottom;
  final double pillTop;
  final double pillBottom;
  final Color rest;
  final Color pill;
  final Color border;
  final List<BoxShadow> shadows;
  final bool floating;
  Size _lastSize = Size.zero;

  double get _geometryP => floating ? progress.value : 0;

  /// Margins and radius clamp at 0 so an overshoot never leaves a gap.
  RRect _rrectAt(Size size, double p) {
    final double pp = math.max(0.0, p);
    final double cq = p.clamp(0.0, 1.0);
    final double m = FloatingHeaderSpec.margin * pp;
    final double top = pillTop * pp;
    final double bottom = restBottom + (pillBottom - restBottom) * p;
    return RRect.fromLTRBR(
      m,
      top,
      size.width - m,
      math.max(top, bottom),
      Radius.circular(FloatingHeaderSpec.radius * cq),
    );
  }

  void _paintAt(Canvas canvas, Size size, double p, double alpha) {
    if (alpha <= 0) return;
    final double cq = p.clamp(0.0, 1.0);
    final RRect r = _rrectAt(size, p);
    final double a = cq * alpha;
    if (a > 0) {
      for (final BoxShadow s in shadows) {
        canvas.drawRRect(
          r.shift(s.offset).inflate(s.spreadRadius),
          Paint()
            ..color = s.color.withValues(alpha: s.color.a * a)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blurSigma),
        );
      }
    }
    final Color fill = Color.lerp(rest, pill, cq)!;
    canvas.drawRRect(r, Paint()..color = fill.withValues(alpha: fill.a * alpha));
    if (a > 0) {
      canvas.drawRRect(
        r.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = border.withValues(alpha: border.a * a),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _lastSize = size;
    if (!floating) {
      _paintAt(canvas, size, 0, 1);
    } else if (subtle) {
      _paintAt(canvas, size, 0, restAlpha.value);
      _paintAt(canvas, size, 1, pillAlpha.value);
    } else {
      _paintAt(canvas, size, progress.value, 1);
    }
  }

  /// Only inside the surface, so the page around the pill stays tappable.
  @override
  bool? hitTest(Offset position) => _rrectAt(_lastSize, _geometryP).contains(position);

  @override
  bool shouldRepaint(_SurfacePainter old) =>
      old.rest != rest ||
      old.pill != pill ||
      old.border != border ||
      old.subtle != subtle ||
      old.floating != floating ||
      old.restBottom != restBottom ||
      old.pillTop != pillTop ||
      old.pillBottom != pillBottom ||
      old.progress != progress;
}

/// The title in the pill: scaled to 16 dp from its left edge, x 20 to 28 with
/// no leading button, and the clip width growing as it scales so more of a
/// long title fits. Fades out when the pill has no room for it (largest
/// font), keeping its semantics.
class PillTitle extends StatelessWidget {
  const PillTitle({
    required this.progress,
    required this.leadShift,
    required this.trailShift,
    required this.dropBelow,
    required this.child,
    super.key,
  });

  final Animation<double> progress;
  final double leadShift;
  final double trailShift;
  final double dropBelow;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext _, BoxConstraints box) => AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (BuildContext _, Widget? c) {
        final double cq = progress.value.clamp(0.0, 1.0);
        final double s = 1 - (1 - FloatingHeaderSpec.titleScale) * cq;
        final double lead = leadShift * cq;
        final double visual = math.max(0.0, box.maxWidth - lead - trailShift * cq);
        final bool drop = visual < dropBelow;
        // FittedBox(none) lets the child be wider than the slot (so more of a long
        // title fits as it scales) while the slot keeps the child's own height,
        // also when the header is laid out with an unbounded height.
        Widget t = FittedBox(
          fit: BoxFit.none,
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(width: visual / s, child: c),
        );
        t = Transform(
          alignment: AlignmentDirectional.centerStart,
          transform: Matrix4.translationValues(lead, 0, 0)..scaleByDouble(s, s, 1, 1),
          child: t,
        );
        // Always present, so the title's element never remounts mid-morph.
        return Opacity(
          opacity: drop ? (1 - cq / FloatingHeaderSpec.titleDropEnd).clamp(0.0, 1.0) : 1,
          alwaysIncludeSemantics: true,
          child: t,
        );
      },
    ),
  );
}

/// [parent] clamped to 0..1 (the status scrim follows the morph).
class _ClampedAnimation extends Animation<double> with AnimationWithParentMixin<double> {
  _ClampedAnimation(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value.clamp(0.0, 1.0);
}
