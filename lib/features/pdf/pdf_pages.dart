import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/layout.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../design_system/states.dart';
import 'pdf_render.dart';

/// The page surface: continuous vertical (zoom 1x to 5x, panning, lazy pages,
/// sharp tiles when zoomed) or paged horizontal (one page per swipe,
/// neighbours peeking).
///
/// Continuous scrolling is built to feel like an Android list: it starts at
/// the device's touch slop, flings with Android's own deceleration
/// ([ClampingScrollSimulation]), and a touch stops a fling. A frame of
/// scrolling only moves one transform: pages are rebuilt when one comes into
/// or leaves range, never per frame, each paints behind its own
/// [RepaintBoundary], and sharper renders wait until the view is still.
///
/// Every page fraction this reports or takes is of the whole page (0..1, top
/// down), whatever the crop.
class PdfPages extends StatefulWidget {
  const PdfPages({
    required this.pdf,
    required this.renderer,
    required this.initialPage,
    required this.paged,
    required this.topInset,
    required this.lookFor,
    required this.paintFor,
    required this.pageAspect,
    required this.cropFor,
    required this.needText,
    required this.onPage,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMove,
    required this.onLongPressEnd,
    super.key,
  });

  final PdfDocument pdf;
  final PageRenderer renderer;
  final int initialPage;
  final bool paged;
  final double topInset;
  final PageLook Function(int page) lookFor;
  final List<(Rect, Color)> Function(int page) paintFor;
  final double Function(int page) pageAspect;
  final Rect? Function(int page) cropFor;
  final void Function(int page) needText;
  final void Function(int page, double offset) onPage;
  final void Function(int page, Offset fraction, double screenX) onTap;
  final void Function(int page, Offset fraction) onLongPressStart;

  /// The finger, as a fraction of the page the press started on (it can run
  /// past 0..1 when the finger leaves that page).
  final void Function(int page, Offset fraction) onLongPressMove;
  final VoidCallback onLongPressEnd;

  @override
  State<PdfPages> createState() => PdfPagesState();
}

class PdfPagesState extends State<PdfPages> with TickerProviderStateMixin {
  final TransformationController _tx = TransformationController();
  late PageController _pager = _newPager(widget.initialPage - 1, 0.92);
  int _page = 1;

  // Continuous layout, in unscaled content pixels.
  List<double> _tops = const <double>[];
  List<double> _heights = const <double>[];
  double _width = 0;
  double _total = 0;
  Size _view = Size.zero;
  bool _restored = false;
  static const double _gap = 12, _side = 12;

  /// Pages built (in or near the view) and pages on screen, 1-based, inclusive.
  (int, int) _range = (1, 0);
  (int, int) _visible = (1, 0);

  /// The zoom pages are rendered for, and each page's region worth a sharp
  /// tile: both settle once the view stops moving, so a pinch or a pan never
  /// asks PDFium for a render per frame.
  double _renderZoom = 1;
  Map<int, Rect> _regions = const <int, Rect>{};
  Timer? _sharpen;

  /// Ticks whenever pages move on screen, for what is drawn over them (the
  /// selection's handles and toolbar).
  final ValueNotifier<int> _geometry = ValueNotifier<int>(0);
  Listenable get geometry => _geometry;

  // Gestures.
  double _s0 = 1;
  Offset _p0 = Offset.zero;
  Offset? _doubleTapAt;
  int? _pressPage;
  bool _swallow = false;

  // Fling (Android's deceleration) and animated moves (volume keys, double
  // tap zoom).
  late final Ticker _fling = createTicker(_onFling);
  ClampingScrollSimulation? _flingX, _flingY;
  late final AnimationController _glide = AnimationController(vsync: this)..addListener(_onGlide);
  (double, Offset)? _glideFrom, _glideTo;
  Curve _glideCurve = Motion.decelerate;

  /// Paged: each page tile's context, to find where it is on screen.
  final Map<int, BuildContext> _tiles = <int, BuildContext>{};

  int get _count => widget.pdf.pages.length;

  /// Two pages side by side (tablets in landscape, board 6, V7).
  bool _spread = false;
  bool get spread => _spread;

  PageController _newPager(int initial, double fraction) =>
      PageController(initialPage: initial, viewportFraction: fraction)..addListener(_onPagerScroll);

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _tx.addListener(_onTransform);
    widget.renderer.ready.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(PdfPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paged != widget.paged) {
      final int keep = _page;
      _stopMotion();
      _pager.dispose();
      _pager = _newPager(keep - 1, 0.92);
      _spread = false;
      _restored = false;
    }
  }

  @override
  void dispose() {
    _sharpen?.cancel();
    _fling.dispose();
    _glide.dispose();
    _tx.dispose();
    _pager.dispose();
    _geometry.dispose();
    widget.renderer.ready.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------ transform

  double get _scale => _tx.value.getMaxScaleOnAxis();

  Offset get _t {
    final Float64List m = _tx.value.storage;
    return Offset(m[12], m[13]);
  }

  void _set(double s, Offset t) {
    _tx.value = Matrix4.identity()
      ..translateByDouble(t.dx, t.dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  /// Keeps the pages on screen: no gap above the first, below the last, or
  /// beside a zoomed page.
  Offset _clamp(Offset t, double s) {
    final double minX = math.min(0, _view.width - _view.width * s);
    final double minY = math.min(0, _view.height - _total * s);
    return Offset(t.dx.clamp(minX, 0), t.dy.clamp(minY, 0));
  }

  double get _maxY => math.max(0, _total * _scale - _view.height);

  void _setY(double y) {
    final double s = _scale;
    _set(s, _clamp(Offset(_t.dx, -y), s));
  }

  /// The page whose top is at or above content y [y] (1-based).
  int _pageAtY(double y) {
    int lo = 0, hi = _tops.length - 1, at = 0;
    while (lo <= hi) {
      final int mid = (lo + hi) >> 1;
      if (_tops[mid] <= y) {
        at = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return at + 1;
  }

  (int, int) _pagesBetween(double top, double bottom) {
    final int first = _pageAtY(top);
    int last = _pageAtY(bottom);
    if (_tops.isNotEmpty && first == 1 && bottom < _tops[0]) last = 0;
    return (first, last);
  }

  void _onTransform() {
    _geometry.value++;
    if (widget.paged || _tops.isEmpty || _view.isEmpty) return;
    final double s = _scale;
    final double ty = -_t.dy / s;
    final double viewH = _view.height / s;
    // The page under a line a third of the way down the view is the one
    // you're on.
    final int page = _pageAtY(ty + (widget.topInset + (_view.height - widget.topInset) / 3) / s);
    // The position saved is the line at the top, as the reader sees it.
    final double offset = ((ty + widget.topInset / s - _tops[page - 1]) / _heights[page - 1]).clamp(0, 1);
    final (int, int) range = _pagesBetween(ty - viewH, ty + viewH * 2);
    final (int, int) visible = _pagesBetween(ty, ty + viewH);
    if (page != _page || range != _range || visible != _visible) {
      if (range != _range) {
        widget.renderer.cancelExcept(<int>{for (int p = range.$1; p <= range.$2; p++) p});
      }
      setState(() {
        _page = page;
        _range = range;
        _visible = visible;
      });
    }
    widget.onPage(page, offset);
    _sharpen?.cancel();
    _sharpen = Timer(Motion.sharpenDelay, _settle);
  }

  /// The view is still: render for this zoom, and sharp tiles for what is on
  /// screen when zoomed.
  void _settle() {
    if (!mounted || widget.paged || _tops.isEmpty) return;
    final double s = _scale;
    final Map<int, Rect> regions = <int, Rect>{};
    if (s > 1.4) {
      final Rect view = Rect.fromLTWH(-_t.dx / s, -_t.dy / s, _view.width / s, _view.height / s);
      for (int p = _visible.$1; p <= _visible.$2; p++) {
        final Rect r = Rect.fromLTWH(_side, _tops[p - 1], _width, _heights[p - 1]);
        if (view.overlaps(r)) regions[p] = view.intersect(r).shift(-r.topLeft);
      }
    }
    if (s == _renderZoom && mapEquals(regions, _regions)) return;
    setState(() {
      _renderZoom = s;
      _regions = regions;
    });
  }

  void _onPagerScroll() {
    // Tiles have moved once this frame is laid out.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _geometry.value++;
    });
  }

  // ------------------------------------------------------------ gestures

  void _stopMotion() {
    _fling.stop();
    _flingX = _flingY = null;
    _glide.stop();
    _glideFrom = _glideTo = null;
  }

  void _onPointerDown(PointerDownEvent e) {
    // A touch stops a fling, and that touch is not also a tap (as in a list).
    _swallow = _fling.isActive || _glide.isAnimating;
    _stopMotion();
  }

  void _onScaleStart(ScaleStartDetails d) {
    _stopMotion();
    _s0 = _scale;
    _p0 = (d.localFocalPoint - _t) / _s0;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final double s = d.pointerCount >= 2 ? (_s0 * d.scale).clamp(1.0, 5.0) : _scale;
    final Offset t = _clamp(d.localFocalPoint - _p0 * s, s);
    _set(s, t);
    // Re-anchored each move, so a pan held against an edge moves again as
    // soon as the finger turns back.
    _p0 = (d.localFocalPoint - t) / s;
    if (d.pointerCount >= 2 && d.scale > 0) _s0 = s / d.scale;
  }

  void _onScaleEnd(ScaleEndDetails d) {
    // A finger lifted from a pinch ends one gesture and starts another.
    if (d.pointerCount > 0) return;
    final Offset v = d.velocity.pixelsPerSecond;
    if (v.distance < kMinFlingVelocity) return;
    final double s = _scale;
    final Offset t = _t;
    _flingX = s > 1.01 && v.dx.abs() > kMinFlingVelocity
        ? ClampingScrollSimulation(position: -t.dx, velocity: -v.dx)
        : null;
    _flingY = v.dy.abs() > kMinFlingVelocity ? ClampingScrollSimulation(position: -t.dy, velocity: -v.dy) : null;
    if (_flingX != null || _flingY != null) unawaited(_fling.start());
  }

  void _onFling(Duration elapsed) {
    final double time = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final double s = _scale;
    final Offset t = _t;
    double x = -t.dx, y = -t.dy;
    bool running = false;
    if (_flingX != null) {
      x = _flingX!.x(time);
      running |= !_flingX!.isDone(time);
    }
    if (_flingY != null) {
      y = _flingY!.x(time);
      running |= !_flingY!.isDone(time);
    }
    final Offset to = _clamp(Offset(-x, -y), s);
    // An edge stops that axis, as a list stops at its end.
    if (to.dx != -x) _flingX = null;
    if (to.dy != -y) _flingY = null;
    _set(s, to);
    if (!running || (_flingX == null && _flingY == null)) _fling.stop();
  }

  void _animateTo(double s, Offset t, {required Duration duration, Curve curve = Motion.decelerate}) {
    _stopMotion();
    if (Motion.reduced(context) || duration == Duration.zero) return _set(s, t);
    _glideFrom = (_scale, _t);
    _glideTo = (s, t);
    _glideCurve = curve;
    _glide.duration = duration;
    unawaited(_glide.forward(from: 0));
  }

  void _onGlide() {
    final (double, Offset)? from = _glideFrom, to = _glideTo;
    if (from == null || to == null) return;
    // Scale and translation move together, so the point zoomed about holds
    // still.
    final double k = _glideCurve.transform(_glide.value);
    _set(ui.lerpDouble(from.$1, to.$1, k)!, Offset.lerp(from.$2, to.$2, k)!);
  }

  void _onDoubleTap() {
    final Offset f = _doubleTapAt ?? _view.center(Offset.zero);
    final double s = _scale;
    final Offset t = _t;
    if (s > 1.05) {
      // Back to the page width, keeping the tapped line where it is.
      final double contentY = (f.dy - t.dy) / s;
      _animateTo(1, _clamp(Offset(0, f.dy - contentY), 1), duration: Motion.of(context, Motion.pageTurn));
      return;
    }
    // Fit the column: zoom to the page's content width.
    final int page = _hitPage(f)?.$1 ?? _page;
    final Rect crop = widget.cropFor(page) ?? const Rect.fromLTRB(0.08, 0, 0.92, 1);
    final double z = (1 / crop.width).clamp(1.0, 5.0);
    _animateTo(z, _clamp(f - (f - t) * (z / s), z), duration: Motion.of(context, Motion.pageTurn));
  }

  /// The page under a point in this widget, and the point as a fraction of
  /// the whole page.
  (int, Offset)? _hitPage(Offset local) {
    if (_tops.isEmpty) return null;
    final Offset c = (local - _t) / _scale;
    final int page = _pageAtY(c.dy);
    final Rect r = Rect.fromLTWH(_side, _tops[page - 1], _width, _heights[page - 1]);
    return (page, _toFull(page, Offset((c.dx - r.left) / r.width, (c.dy - r.top) / r.height)));
  }

  /// A fraction of the page as shown (cropped) to a fraction of the whole.
  Offset _toFull(int page, Offset shown) {
    final Rect crop = widget.cropFor(page) ?? const Rect.fromLTRB(0, 0, 1, 1);
    return Offset(crop.left + shown.dx * crop.width, crop.top + shown.dy * crop.height);
  }

  void _onTapUp(TapUpDetails d) {
    if (_swallow) return;
    final (int, Offset)? hit = _hitPage(d.localPosition);
    if (hit != null) widget.onTap(hit.$1, hit.$2, d.globalPosition.dx / MediaQuery.sizeOf(context).width);
  }

  void _onLongPressStart(LongPressStartDetails d) {
    if (_swallow) return;
    final (int, Offset)? hit = _hitPage(d.localPosition);
    if (hit == null) return;
    _pressPage = hit.$1;
    widget.onLongPressStart(hit.$1, hit.$2);
  }

  void _onLongPressMove(LongPressMoveUpdateDetails d) {
    final int? page = _pressPage;
    if (page == null) return;
    final Offset? f = fractionAt(page, d.globalPosition);
    if (f != null) widget.onLongPressMove(page, f);
  }

  void _onLongPressEnd() {
    if (_pressPage == null) return;
    _pressPage = null;
    widget.onLongPressEnd();
  }

  Map<Type, GestureRecognizerFactory> _gestures(BuildContext context) {
    final DeviceGestureSettings? device = MediaQuery.maybeGestureSettingsOf(context);
    // A pan starts at the device's touch slop, as a list's scroll does; the
    // scale recogniser's own default is twice that.
    final DeviceGestureSettings pan = DeviceGestureSettings(touchSlop: (device?.touchSlop ?? kTouchSlop) / 2);
    return <Type, GestureRecognizerFactory>{
      ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
        () => ScaleGestureRecognizer(debugOwner: this),
        (ScaleGestureRecognizer r) => r
          ..gestureSettings = pan
          ..dragStartBehavior = DragStartBehavior.start
          ..onStart = _onScaleStart
          ..onUpdate = _onScaleUpdate
          ..onEnd = _onScaleEnd,
      ),
      TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(debugOwner: this),
        (TapGestureRecognizer r) => r
          ..gestureSettings = device
          ..onTapUp = _onTapUp,
      ),
      DoubleTapGestureRecognizer: GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
        () => DoubleTapGestureRecognizer(debugOwner: this),
        (DoubleTapGestureRecognizer r) => r
          ..gestureSettings = device
          ..onDoubleTapDown = ((TapDownDetails d) => _doubleTapAt = d.localPosition)
          ..onDoubleTap = _onDoubleTap,
      ),
      LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
        () => LongPressGestureRecognizer(debugOwner: this),
        (LongPressGestureRecognizer r) => r
          ..gestureSettings = device
          ..onLongPressStart = _onLongPressStart
          ..onLongPressMoveUpdate = _onLongPressMove
          ..onLongPressEnd = ((_) => _onLongPressEnd())
          ..onLongPressCancel = _onLongPressEnd,
      ),
    };
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (PointerSignalEvent e) {
      final double s = _scale;
      _set(s, _clamp(_t - (e as PointerScrollEvent).scrollDelta, s));
    });
  }

  // ------------------------------------------------------------ commands

  /// What the reader is looking at: the page and the fraction down it of a
  /// line a third of the way down the view (paged: the page's top).
  (int, double) focus() {
    if (widget.paged || _tops.isEmpty) return (_page, 0);
    final double s = _scale;
    final double y = -_t.dy / s + (widget.topInset + (_view.height - widget.topInset) / 3) / s;
    final int page = _pageAtY(y);
    return (page, ((y - _tops[page - 1]) / _heights[page - 1]).clamp(0.0, 1.0));
  }

  /// Auto-scroll (continuous): moves by [px]; false at the end.
  bool scrollByPixels(double px) {
    if (widget.paged || _tops.isEmpty) return false;
    final double y = -_t.dy;
    if (y >= _maxY) return false;
    _setY(y + px);
    return true;
  }

  /// Volume keys (continuous): [fraction] of a screen.
  void scrollScreen(double fraction) {
    if (widget.paged || _tops.isEmpty) return;
    final double s = _scale;
    final Offset t = _t;
    _animateTo(
      s,
      _clamp(Offset(t.dx, t.dy - _view.height * fraction), s),
      duration: Motion.of(context, Motion.volumeScroll),
    );
  }

  /// Scrolls (or turns) to page [page], [fraction] down it.
  void goTo(int page, {double fraction = 0, bool animate = false}) {
    if (widget.paged) {
      if (!_pager.hasClients) return;
      final int index = _spread ? (page - 1) ~/ 2 : page - 1;
      if (animate && !Motion.reduced(context)) {
        unawaited(_pager.animateToPage(index, duration: Motion.pageTurn, curve: Motion.spring));
      } else {
        _pager.jumpToPage(index);
      }
      return;
    }
    if (_tops.isEmpty) {
      _page = page;
      return;
    }
    _stopMotion();
    final double s = _scale;
    final int p = page.clamp(1, _count);
    final double y = _tops[p - 1] + _heights[p - 1] * fraction - widget.topInset;
    _set(s, _clamp(Offset(_t.dx, -y * s), s));
  }

  /// Where page [page] is drawn, in global coordinates, if it is laid out.
  Rect? pageRect(int page) {
    if (widget.paged) {
      final BuildContext? tile = _tiles[page];
      final RenderObject? box = tile != null && tile.mounted ? tile.findRenderObject() : null;
      if (box is! RenderBox || !box.attached || !box.hasSize) return null;
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final RenderObject? self = context.findRenderObject();
    if (_tops.isEmpty || page < 1 || page > _count || self is! RenderBox || !self.attached) return null;
    final Rect local = MatrixUtils.transformRect(
      _tx.value,
      Rect.fromLTWH(_side, _tops[page - 1], _width, _heights[page - 1]),
    );
    return local.shift(self.localToGlobal(Offset.zero));
  }

  /// A global point as a fraction of the whole of page [page] (it can lie
  /// past 0..1).
  Offset? fractionAt(int page, Offset global) {
    final Rect? r = pageRect(page);
    if (r == null || r.isEmpty) return null;
    return _toFull(page, Offset((global.dx - r.left) / r.width, (global.dy - r.top) / r.height));
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) => widget.paged ? _pagedView() : _continuous();

  void _layout(double width) {
    _width = width - _side * 2;
    double y = widget.topInset;
    final List<double> tops = <double>[], heights = <double>[];
    for (int p = 1; p <= _count; p++) {
      tops.add(y);
      final double h = _width / widget.pageAspect(p);
      heights.add(h);
      y += h + _gap;
    }
    _tops = tops;
    _heights = heights;
    _total = y + 200;
  }

  Widget _continuous() => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) {
      final Size view = box.biggest;
      final bool relayout =
          _tops.isEmpty || _width != box.maxWidth - _side * 2 || _tops.length != _count || !_aspectsMatch();
      if (relayout || view != _view) {
        // A rotation or a crop keeps the reader on the same line.
        final (int, double)? keep = _tops.isEmpty || !_restored ? null : focus();
        _view = view;
        if (relayout) _layout(box.maxWidth);
        if (keep != null) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) goTo(keep.$1, fraction: keep.$2);
          });
        }
        _measureRange();
      }
      if (!_restored) {
        _restored = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) goTo(_page);
        });
      }
      return Listener(
        onPointerDown: _onPointerDown,
        onPointerSignal: _onPointerSignal,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: _gestures(context),
          child: ClipRect(
            child: ValueListenableBuilder<Matrix4>(
              valueListenable: _tx,
              // Built only when pages come into range or change; a scroll
              // frame just moves them.
              child: _pagesInRange(box.maxWidth),
              builder: (BuildContext context, Matrix4 m, Widget? pages) => Transform(transform: m, child: pages),
            ),
          ),
        ),
      );
    },
  );

  /// Whether each page still has the height its aspect gives (crops land
  /// late, page by page).
  bool _aspectsMatch() {
    for (int p = _range.$1; p <= _range.$2 && p <= _heights.length; p++) {
      if ((_heights[p - 1] - _width / widget.pageAspect(p)).abs() > 0.5) return false;
    }
    return true;
  }

  /// The range for the current transform, without a rebuild (inside build).
  void _measureRange() {
    if (_tops.isEmpty || _view.isEmpty) return;
    final double s = _scale;
    final double ty = -_t.dy / s, viewH = _view.height / s;
    _range = _pagesBetween(ty - viewH, ty + viewH * 2);
    _visible = _pagesBetween(ty, ty + viewH);
  }

  Widget _pagesInRange(double width) {
    final (int first, int last) = _range;
    final (int vFirst, int vLast) = _visible;
    // Pages on screen first: their renders queue ahead of the ones near.
    final List<int> order = <int>[
      for (int p = math.max(1, vFirst); p <= math.min(_count, vLast); p++) p,
      for (int p = math.min(_count, vFirst - 1); p >= first && p >= 1; p--) p,
      for (int p = math.max(1, vLast + 1); p <= math.min(_count, last); p++) p,
    ];
    return OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: width,
      maxWidth: width,
      minHeight: _total,
      maxHeight: _total,
      child: Stack(
        children: <Widget>[
          for (final int p in order)
            Positioned(
              key: ValueKey<int>(p),
              left: _side,
              top: _tops[p - 1],
              width: _width,
              height: _heights[p - 1],
              child: _tile(
                p,
                Size(_width, _heights[p - 1]),
                visible: p >= vFirst && p <= vLast,
                zoom: _renderZoom,
                region: _renderZoom > 1.4 ? _regions[p] : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(int page, Size size, {required bool visible, required double zoom, Rect? region}) {
    // Text (selection, highlights, the saved place) only for pages on
    // screen: each load holds PDFium like a render does.
    if (visible) widget.needText(page);
    final Widget tile = RepaintBoundary(
      child: _PageTile(
        key: ValueKey<int>(page),
        page: page,
        renderer: widget.renderer,
        look: widget.lookFor(page),
        size: size,
        zoom: zoom,
        visible: visible,
        visibleRegion: region,
        marks: widget.paintFor(page),
      ),
    );
    return widget.paged ? _Probe(page: page, tiles: _tiles, child: tile) : tile;
  }

  Widget _pagedView() => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) {
      final bool spread = SizeClass.of(context) == SizeClass.expanded && MediaQuery.sizeOf(context).shortestSide >= 600;
      if (spread != _spread) {
        // Rotation or a resize: the same page, paired or alone.
        final PageController old = _pager;
        _spread = spread;
        _pager = _newPager(spread ? (_page - 1) ~/ 2 : _page - 1, spread ? 1 : 0.92);
        SchedulerBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
      final double maxH = box.maxHeight - widget.topInset - 120;
      Widget tile(int page, double maxW) {
        final double aspect = widget.pageAspect(page);
        final double w = math.min(maxW, maxH * aspect);
        final Size size = Size(w, w / aspect);
        Offset full(Offset local) => _toFull(page, Offset(local.dx / size.width, local.dy / size.height));
        return SizedBox.fromSize(
          size: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (TapUpDetails d) =>
                widget.onTap(page, full(d.localPosition), d.globalPosition.dx / MediaQuery.sizeOf(context).width),
            onLongPressStart: (LongPressStartDetails d) => widget.onLongPressStart(page, full(d.localPosition)),
            onLongPressMoveUpdate: (LongPressMoveUpdateDetails d) =>
                widget.onLongPressMove(page, full(d.localPosition)),
            onLongPressEnd: (_) => widget.onLongPressEnd(),
            child: _tile(page, size, visible: page == _page || (spread && page == _page + 1), zoom: 1),
          ),
        );
      }

      return PageView.builder(
        controller: _pager,
        // The next page is built (and rendered) before it is swiped to.
        allowImplicitScrolling: true,
        itemCount: spread ? (_count + 1) ~/ 2 : _count,
        onPageChanged: (int i) {
          final int page = spread ? i * 2 + 1 : i + 1;
          widget.renderer.cancelExcept(<int>{for (int p = page - 2; p <= page + 3; p++) p});
          setState(() => _page = page);
          widget.onPage(page, 0);
        },
        itemBuilder: (BuildContext context, int i) => Padding(
          padding: EdgeInsets.only(top: widget.topInset, bottom: 120, left: 4, right: 4),
          child: Center(
            child: spread
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: Space.xs,
                    children: <Widget>[
                      tile(i * 2 + 1, (box.maxWidth - 24) / 2),
                      if (i * 2 + 2 <= _count) tile(i * 2 + 2, (box.maxWidth - 24) / 2),
                    ],
                  )
                : tile(i + 1, box.maxWidth * 0.92 - 8),
          ),
        ),
      );
    },
  );
}

/// Puts a paged tile's context in [tiles] while it is mounted.
class _Probe extends StatefulWidget {
  const _Probe({required this.page, required this.tiles, required this.child});

  final int page;
  final Map<int, BuildContext> tiles;
  final Widget child;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void dispose() {
    if (identical(widget.tiles[widget.page], context)) widget.tiles.remove(widget.page);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.tiles[widget.page] = context;
    return widget.child;
  }
}

/// One page: the best image to hand (a quick preview first, then one sharp
/// for the current zoom), a crisp tile over the visible region when zoomed,
/// the marks, and a 1px outline. No shadow.
class _PageTile extends StatefulWidget {
  const _PageTile({
    required this.page,
    required this.renderer,
    required this.look,
    required this.size,
    required this.zoom,
    required this.visible,
    required this.marks,
    this.visibleRegion,
    super.key,
  });

  final int page;
  final PageRenderer renderer;
  final PageLook look;
  final Size size;
  final double zoom;
  final bool visible;
  final Rect? visibleRegion;
  final List<(Rect, Color)> marks;

  @override
  State<_PageTile> createState() => _PageTileState();
}

class _PageTileState extends State<_PageTile> {
  ui.Image? _tile;
  Rect? _tileRegion;
  Rect? _asked;

  int _targetWidth(double dpr) {
    final double z = math.pow(1.5, (math.log(math.max(1, widget.zoom)) / math.log(1.5)).ceil()).toDouble();
    return math.min(2600, (widget.size.width * dpr * math.min(z, 2.0)).round());
  }

  @override
  void didUpdateWidget(_PageTile old) {
    super.didUpdateWidget(old);
    // Zoomed back out, or a new look: the sharp tile no longer applies.
    if (widget.visibleRegion == null || old.look != widget.look || old.size != widget.size) {
      _tile = null;
      _tileRegion = null;
      _asked = null;
    }
  }

  void _askSharp(Rect region, double dpr) {
    // A sharp render of just what is on screen at this zoom. The tile shown
    // stays until the new one lands: it is in page coordinates, so it moves
    // with the page.
    _asked = region;
    final Rect crop = widget.look.crop ?? const Rect.fromLTRB(0, 0, 1, 1);
    final Size size = widget.size;
    final Rect sub = Rect.fromLTRB(
      crop.left + region.left / size.width * crop.width,
      crop.top + region.top / size.height * crop.height,
      crop.left + region.right / size.width * crop.width,
      crop.top + region.bottom / size.height * crop.height,
    );
    final int px = math.min(2400, (region.width * widget.zoom * dpr).round());
    unawaited(
      widget.renderer.render(widget.page, px, PageLook(paper: widget.look.paper, ink: widget.look.ink, crop: sub)).then(
        (ui.Image? t) {
          if (!mounted || t == null || _asked != region) return;
          setState(() {
            _tile = t;
            _tileRegion = region;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int w = _targetWidth(dpr);
    final ui.Image? img = widget.renderer.cached(widget.page, w, widget.look);
    if (img == null || img.width < w) {
      // Nothing yet: a quarter-size preview first, so a page scrolled to
      // quickly shows its content at once, then the sharp one.
      if (img == null) {
        unawaited(
          widget.renderer.render(
            widget.page,
            math.max(160, w ~/ 4),
            widget.look,
            priority: widget.visible ? RenderPriority.visiblePreview : RenderPriority.nearPreview,
          ),
        );
      }
      unawaited(
        widget.renderer.render(
          widget.page,
          w,
          widget.look,
          priority: widget.visible ? RenderPriority.visible : RenderPriority.near,
        ),
      );
    }
    final Rect? region = widget.visibleRegion;
    if (region != null && region != _asked) _askSharp(region, dpr);
    final Color paper = widget.look.paper == null ? Colors.white : Color(widget.look.paper!);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: paper,
        border: Border.all(color: c.outline, width: 0.5),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // The page fades in once drawn; until then a hairline says so.
          AnimatedOpacity(
            opacity: img == null ? 0 : 1,
            duration: Motion.of(context, Motion.fast),
            curve: Motion.decelerate,
            child: img == null
                ? const SizedBox.expand()
                // Drawn at its own size, so bilinear sampling is enough.
                : RawImage(image: img, fit: BoxFit.fill, filterQuality: FilterQuality.low),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: LoadingHairline(visible: img == null),
          ),
          if (_tile != null && _tileRegion != null)
            Positioned.fromRect(
              rect: _tileRegion!,
              child: RawImage(image: _tile, fit: BoxFit.fill, filterQuality: FilterQuality.low),
            ),
          if (widget.marks.isNotEmpty) CustomPaint(painter: _MarksPainter(widget.marks, widget.look.crop)),
        ],
      ),
    );
  }
}

class _MarksPainter extends CustomPainter {
  _MarksPainter(this.marks, this.crop);

  final List<(Rect, Color)> marks;
  final Rect? crop;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect c = crop ?? const Rect.fromLTRB(0, 0, 1, 1);
    for (final (Rect r, Color colour) in marks) {
      final Rect onPage = Rect.fromLTRB(
        (r.left - c.left) / c.width * size.width,
        (r.top - c.top) / c.height * size.height,
        (r.right - c.left) / c.width * size.width,
        (r.bottom - c.top) / c.height * size.height,
      );
      canvas.drawRect(
        onPage.inflate(1),
        Paint()
          ..color = colour
          ..blendMode = BlendMode.multiply,
      );
    }
  }

  @override
  bool shouldRepaint(_MarksPainter old) => !listEquals(old.marks, marks) || old.crop != crop;
}
