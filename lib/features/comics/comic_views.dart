import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_icon.dart';
import 'comic_pages.dart';
import 'comic_prefs.dart';

/// Board 6, V4 zoom: double-tap to 250%, pinch to 500%.
const double kComicDoubleTapZoom = 2.5;
const double kComicMaxZoom = 5;

/// One page, decoded at the size it is drawn. A page that can't be read is
/// a broken-image tile, never an error.
class ComicPageImage extends StatefulWidget {
  const ComicPageImage({required this.pages, required this.index, required this.size, super.key});

  final ComicPages pages;
  final int index;

  /// Logical size it is drawn at.
  final Size size;

  @override
  State<ComicPageImage> createState() => _ComicPageImageState();
}

class _ComicPageImageState extends State<ComicPageImage> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ComicPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ComicPageImage old = oldWidget;
    if (old.index != widget.index || old.pages != widget.pages) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  void _load({bool retried = false}) {
    final int i = widget.index;
    _bytes = widget.pages.cached(i);
    if (_bytes != null) return;
    unawaited(
      widget.pages.bytes(i).then((Uint8List? b) {
        if (!mounted || widget.index != i) return;
        // A prefetch dropped under us: ask once more for real.
        if (b == null && !retried) return _load(retried: true);
        setState(() {
          _bytes = b;
          _failed = b == null;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final Uint8List? b = _bytes;
    if (_failed) {
      return SizedBox.fromSize(
        size: widget.size,
        child: Center(child: AppIcon(AppIcons.brokenImage, size: 32, color: c.iconMuted)),
      );
    }
    if (b == null) return SizedBox.fromSize(size: widget.size);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return Image(
      image: ComicPages.providerFor(b, widget.size * dpr),
      width: widget.size.width,
      height: widget.size.height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      frameBuilder: (BuildContext context, Widget child, int? frame, bool sync) => sync
          ? child
          : AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: Motion.of(context, Motion.fast),
              curve: Motion.decelerate,
              child: child,
            ),
      errorBuilder: (BuildContext context, Object e, StackTrace? s) =>
          Center(child: AppIcon(AppIcons.brokenImage, size: 32, color: c.iconMuted)),
    );
  }
}

/// Where a tap landed, as seen on screen.
enum TapZone { left, centre, right }

/// Single page or two-page spreads, swiped sideways (mirrored right to
/// left), with pinch and double-tap zoom. While zoomed a swipe pans; at the
/// page's edge a swipe turns the page.
class PagedComic extends StatefulWidget {
  const PagedComic({
    required this.pages,
    required this.spreads,
    required this.page,
    required this.rtl,
    required this.fit,
    required this.onPage,
    required this.onTap,
    required this.onZoom,
    super.key,
  });

  final ComicPages pages;
  final List<List<int>> spreads;

  /// The page to show (reading order index).
  final int page;
  final bool rtl;
  final ComicFit fit;
  final ValueChanged<int> onPage;
  final ValueChanged<TapZone> onTap;

  /// The zoom changed (1 = fitted), for the % chip.
  final ValueChanged<double> onZoom;

  @override
  State<PagedComic> createState() => PagedComicState();
}

class PagedComicState extends State<PagedComic> {
  late PageController _pager = PageController(initialPage: _spreadOf(widget.page));
  bool _zoomed = false;

  int _spreadOf(int page) {
    final int i = widget.spreads.indexWhere((List<int> s) => s.contains(page));
    return i < 0 ? 0 : i;
  }

  @override
  void didUpdateWidget(PagedComic oldWidget) {
    super.didUpdateWidget(oldWidget);
    final PagedComic old = oldWidget;
    final int target = _spreadOf(widget.page);
    if (!_pager.hasClients) return;
    final int now = _pager.page?.round() ?? 0;
    if (old.spreads.length != widget.spreads.length || old.rtl != widget.rtl) {
      // Re-paired (rotation, a wide page found) or mirrored: same page, no animation.
      _pager.dispose();
      _pager = PageController(initialPage: target);
      _zoomed = false;
    } else if (target != now && !_pager.position.isScrollingNotifier.value) {
      _pager.jumpToPage(target);
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  /// Next (+1) or previous (-1) in reading order, animated.
  void turn(int delta) {
    if (!_pager.hasClients) return;
    final int to = ((_pager.page?.round() ?? 0) + delta).clamp(0, widget.spreads.length - 1);
    unawaited(_pager.animateToPage(to, duration: Motion.of(context, Motion.pageTurn), curve: Motion.decelerate));
  }

  /// A page chosen on the scrubber.
  void jumpTo(int page) {
    if (_pager.hasClients) _pager.jumpToPage(_spreadOf(page));
  }

  void _visualTurn({required bool towardLeft}) => turn((towardLeft ? -1 : 1) * (widget.rtl ? -1 : 1));

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) {
      final Size vp = box.biggest;
      return PageView.builder(
        controller: _pager,
        reverse: widget.rtl,
        physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
        itemCount: widget.spreads.length,
        onPageChanged: (int i) {
          widget.onPage(widget.spreads[i].first);
          unawaited(widget.pages.around(widget.spreads[i].first));
        },
        itemBuilder: (BuildContext context, int i) => _ZoomableSpread(
          key: ValueKey<String>('${widget.spreads[i].join('-')}:${widget.fit.name}'),
          pages: widget.pages,
          spread: widget.spreads[i],
          viewport: vp,
          fit: widget.fit,
          rtl: widget.rtl,
          onZoomed: (bool z, double scale) {
            if (z != _zoomed) setState(() => _zoomed = z);
            widget.onZoom(scale);
          },
          onTap: (TapZone zone) {
            if (zone == TapZone.centre) return widget.onTap(zone);
            _visualTurn(towardLeft: zone == TapZone.left);
            widget.onTap(zone);
          },
          onEdgeSwipe: (bool towardLeft) => _visualTurn(towardLeft: towardLeft),
        ),
      );
    },
  );
}

class _ZoomableSpread extends StatefulWidget {
  const _ZoomableSpread({
    required this.pages,
    required this.spread,
    required this.viewport,
    required this.fit,
    required this.rtl,
    required this.onZoomed,
    required this.onTap,
    required this.onEdgeSwipe,
    super.key,
  });

  final ComicPages pages;
  final List<int> spread;
  final Size viewport;
  final ComicFit fit;
  final bool rtl;
  final void Function(bool zoomed, double scale) onZoomed;
  final ValueChanged<TapZone> onTap;
  final ValueChanged<bool> onEdgeSwipe;

  @override
  State<_ZoomableSpread> createState() => _ZoomableSpreadState();
}

class _ZoomableSpreadState extends State<_ZoomableSpread> with SingleTickerProviderStateMixin {
  final TransformationController _t = TransformationController();
  late final AnimationController _anim = AnimationController(vsync: this);
  Animation<Matrix4>? _tween;
  Offset _doubleTapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() => _t.value = _tween!.value);
    widget.pages.measured.addListener(_remeasure);
  }

  void _remeasure() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.pages.measured.removeListener(_remeasure);
    _anim.dispose();
    _t.dispose();
    super.dispose();
  }

  double get _scale => _t.value.getMaxScaleOnAxis();

  /// Each page's drawn size for the fit, side by side in a spread.
  List<Size> _sizes() {
    final Size vp = widget.viewport;
    final double slot = widget.spread.length == 2 ? vp.width / 2 : vp.width;
    return <Size>[
      for (final int i in widget.spread)
        switch (widget.fit) {
          ComicFit.width => Size(slot, slot * widget.pages.aspect(i)),
          ComicFit.height => Size(vp.height / widget.pages.aspect(i), vp.height),
          ComicFit.screen => _contain(widget.pages.aspect(i), Size(slot, vp.height)),
        },
    ];
  }

  static Size _contain(double aspect, Size box) =>
      box.height / box.width > aspect ? Size(box.width, box.width * aspect) : Size(box.height / aspect, box.height);

  void _animateTo(Matrix4 to) {
    _anim.duration = Motion.of(context, Motion.containerTransform);
    _tween = Matrix4Tween(begin: _t.value, end: to).animate(CurvedAnimation(parent: _anim, curve: Motion.decelerate));
    unawaited(_anim.forward(from: 0).then((_) => _report()));
  }

  void _report() => widget.onZoomed(_scale > 1.01, _scale);

  void _doubleTap(Size canvas) {
    if (_scale > 1.01) return _animateTo(Matrix4.identity());
    const double s = kComicDoubleTapZoom;
    final Offset p = _t.toScene(_doubleTapAt);
    final Size vp = widget.viewport;
    final double tx = (-p.dx * (s - 1)).clamp(vp.width - canvas.width * s, 0);
    final double ty = (-p.dy * (s - 1)).clamp(vp.height - canvas.height * s, 0);
    _animateTo(
      Matrix4.identity()
        ..translateByDouble(tx, ty, 0, 1)
        ..scaleByDouble(s, s, 1, 1),
    );
  }

  void _end(ScaleEndDetails d, Size canvas) {
    _report();
    if (_scale <= 1.01) return;
    final double tx = _t.value.getTranslation().x;
    final double v = d.velocity.pixelsPerSecond.dx;
    final bool atLeft = tx >= -1;
    final bool atRight = tx <= widget.viewport.width - canvas.width * _scale + 1;
    if (atLeft && v > 400) {
      _t.value = Matrix4.identity();
      _report();
      widget.onEdgeSwipe(true);
    } else if (atRight && v < -400) {
      _t.value = Matrix4.identity();
      _report();
      widget.onEdgeSwipe(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size vp = widget.viewport;
    final List<Size> sizes = _sizes();
    final Size content = Size(
      sizes.fold<double>(0, (double a, Size s) => a + s.width),
      sizes.fold<double>(0, (double a, Size s) => math.max(a, s.height)),
    );
    final Size canvas = Size(math.max(vp.width, content.width), math.max(vp.height, content.height));
    // In a right-to-left spread, page n+1 sits on the left.
    final List<int> order = widget.rtl ? widget.spread.reversed.toList() : widget.spread;
    final List<Size> ordered = widget.rtl ? sizes.reversed.toList() : sizes;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (TapUpDetails e) {
        final double x = e.localPosition.dx / vp.width;
        widget.onTap(x < 1 / 3 ? TapZone.left : (x > 2 / 3 ? TapZone.right : TapZone.centre));
      },
      onDoubleTapDown: (TapDownDetails e) => _doubleTapAt = e.localPosition,
      onDoubleTap: () => _doubleTap(canvas),
      child: InteractiveViewer(
        transformationController: _t,
        constrained: false,
        minScale: 1,
        maxScale: kComicMaxZoom,
        panEnabled: _scale > 1.01 || canvas != vp,
        onInteractionUpdate: (_) => widget.onZoomed(_scale > 1.01, _scale),
        onInteractionEnd: (ScaleEndDetails d) => _end(d, canvas),
        child: SizedBox.fromSize(
          size: canvas,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int k = 0; k < order.length; k++)
                  ComicPageImage(pages: widget.pages, index: order[k], size: ordered[k]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Webtoon: every page fitted to the width, one continuous column.
class WebtoonComic extends StatefulWidget {
  const WebtoonComic({
    required this.pages,
    required this.page,
    required this.onPage,
    required this.onTap,
    this.controller,
    super.key,
  });

  final ComicPages pages;
  final int page;
  final ValueChanged<int> onPage;
  final VoidCallback onTap;
  final ScrollController? controller;

  @override
  State<WebtoonComic> createState() => WebtoonComicState();
}

class WebtoonComicState extends State<WebtoonComic> {
  late final ScrollController _scroll = widget.controller ?? ScrollController();
  double _width = 0;
  List<double> _tops = const <double>[];
  int _current = 0;

  ScrollController get scroll => _scroll;

  @override
  void initState() {
    super.initState();
    _current = widget.page;
    widget.pages.measured.addListener(_remeasure);
  }

  @override
  void dispose() {
    widget.pages.measured.removeListener(_remeasure);
    if (widget.controller == null) _scroll.dispose();
    super.dispose();
  }

  List<double> _layout(double width) {
    final List<double> tops = List<double>.filled(widget.pages.count + 1, 0);
    for (int i = 0; i < widget.pages.count; i++) {
      tops[i + 1] = tops[i] + width * widget.pages.aspect(i);
    }
    return tops;
  }

  /// A page's real height arrived: keep the page being read where it is.
  void _remeasure() {
    if (!mounted || _width == 0) return;
    final List<double> next = _layout(_width);
    if (_scroll.hasClients && _tops.length == next.length) {
      final double shift = next[_current] - _tops[_current];
      if (shift != 0) _scroll.jumpTo(_scroll.offset + shift);
    }
    setState(() => _tops = next);
  }

  void jumpTo(int page) {
    if (_scroll.hasClients && page < _tops.length) _scroll.jumpTo(_tops[page]);
  }

  /// Auto-scroll: moves by [pixels]; false at the end.
  bool scrollByPixels(double pixels) {
    if (!_scroll.hasClients) return false;
    final ScrollPosition p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent) return false;
    _scroll.jumpTo((p.pixels + pixels).clamp(p.minScrollExtent, p.maxScrollExtent));
    return true;
  }

  /// Volume keys: the next or previous page's top, animated.
  void pageBy(int delta) {
    if (!_scroll.hasClients || _tops.isEmpty) return;
    final int to = (_current + delta).clamp(0, widget.pages.count - 1);
    unawaited(
      _scroll.animateTo(
        _tops[to].clamp(0, _scroll.position.maxScrollExtent),
        duration: Motion.of(context, Motion.volumeScroll),
        curve: Motion.decelerate,
      ),
    );
  }

  /// Volume keys and paging: about a screen, animated.
  void scrollBy(double fraction, Duration duration) {
    if (!_scroll.hasClients) return;
    final ScrollPosition p = _scroll.position;
    final double to = (p.pixels + p.viewportDimension * fraction).clamp(p.minScrollExtent, p.maxScrollExtent);
    unawaited(_scroll.animateTo(to, duration: duration, curve: Motion.decelerate));
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || _tops.isEmpty) return false;
    final double mid = n.metrics.pixels + n.metrics.viewportDimension / 2;
    int i = _current.clamp(0, widget.pages.count - 1);
    while (i > 0 && _tops[i] > mid) {
      i--;
    }
    while (i < widget.pages.count - 1 && _tops[i + 1] <= mid) {
      i++;
    }
    if (i != _current) {
      _current = i;
      widget.onPage(i);
      unawaited(widget.pages.around(i));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) {
      if (box.maxWidth != _width) {
        final bool first = _width == 0;
        _width = box.maxWidth;
        _tops = _layout(_width);
        if (first && widget.page > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) => jumpTo(widget.page));
        }
      }
      return NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: GestureDetector(
          onTap: widget.onTap,
          child: ListView.builder(
            controller: _scroll,
            scrollCacheExtent: const ScrollCacheExtent.viewport(2),
            itemCount: widget.pages.count,
            itemBuilder: (BuildContext context, int i) =>
                ComicPageImage(pages: widget.pages, index: i, size: Size(_width, _tops[i + 1] - _tops[i])),
          ),
        ),
      );
    },
  );
}

/// Board 6, V4 PageScrubber: a thumbnail strip around the current page
/// (current larger, primary ring), a track with its fill, and page labels.
/// Right to left mirrors the strip, the fill and the end numbers.
class ComicScrubber extends StatefulWidget {
  const ComicScrubber({required this.pages, required this.page, required this.rtl, required this.onJump, super.key});

  final ComicPages pages;
  final int page;
  final bool rtl;
  final ValueChanged<int> onJump;

  @override
  State<ComicScrubber> createState() => _ComicScrubberState();
}

class _ComicScrubberState extends State<ComicScrubber> {
  int? _drag;

  int get _shown => _drag ?? widget.page;

  int _pageAt(double dx, double width) {
    final double f = (dx / width).clamp(0, 1);
    return ((widget.rtl ? 1 - f : f) * (widget.pages.count - 1)).round();
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final int n = widget.pages.count;
    final int cur = _shown;
    final int first = (cur - 4).clamp(0, math.max(0, n - 9));
    final List<int> strip = <int>[for (int i = first; i < math.min(n, first + 9); i++) i];
    final double fill = n <= 1 ? 1 : cur / (n - 1);
    final TextStyle mono = UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.sm,
      children: <Widget>[
        SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            textDirection: widget.rtl ? TextDirection.rtl : TextDirection.ltr,
            spacing: 6,
            children: <Widget>[
              for (final int i in strip)
                _Thumb(pages: widget.pages, index: i, current: i == cur, onTap: () => widget.onJump(i)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Row(
            spacing: Space.md,
            children: <Widget>[
              Text(widget.rtl ? '$n' : '1', style: mono),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) {
                    final double w = box.maxWidth;
                    return Semantics(
                      slider: true,
                      label: 'Page',
                      value: 'Page ${cur + 1} of $n',
                      onIncrease: () => widget.onJump(math.min(n - 1, cur + 1)),
                      onDecrease: () => widget.onJump(math.max(0, cur - 1)),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: (DragStartDetails e) =>
                            setState(() => _drag = _pageAt(e.localPosition.dx, w)),
                        onHorizontalDragUpdate: (DragUpdateDetails e) =>
                            setState(() => _drag = _pageAt(e.localPosition.dx, w)),
                        onHorizontalDragEnd: (_) {
                          final int to = _shown;
                          setState(() => _drag = null);
                          widget.onJump(to);
                        },
                        onTapUp: (TapUpDetails e) => widget.onJump(_pageAt(e.localPosition.dx, w)),
                        child: SizedBox(
                          height: IconSpec.tapTarget,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Container(
                                height: 4,
                                decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: Radii.fullR),
                              ),
                              Align(
                                alignment: widget.rtl ? Alignment.centerRight : Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: fill,
                                  child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(color: c.primary, borderRadius: Radii.fullR),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment((widget.rtl ? 1 - fill : fill) * 2 - 1, 0),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Text(widget.rtl ? '1' : '$n', style: mono),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Page ${cur + 1} of $n', style: mono),
              Text(widget.rtl ? 'Right to left' : 'Left to right', style: mono),
            ],
          ),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.pages, required this.index, required this.current, required this.onTap});

  final ComicPages pages;
  final int index;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final double w = current ? 34 : 28, h = current ? 50 : 41;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        curve: Motion.decelerate,
        width: w,
        height: h,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: current ? c.primary : c.outline, width: current ? 2 : 1),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            FutureBuilder<File?>(
              initialData: pages.thumbNow(index),
              future: pages.thumb(index),
              builder: (BuildContext context, AsyncSnapshot<File?> s) => s.data == null
                  ? const SizedBox.shrink()
                  : Image(
                      image: ResizeImage(FileImage(s.data!), width: ComicPages.thumbWidth),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 2,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: UnfurlType.badge.copyWith(fontSize: 8, color: c.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
