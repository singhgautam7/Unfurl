import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../design_system/app_icon.dart';
import '../../../formats/reading_document.dart';
import 'page_turn.dart';
import '../reading_prefs.dart';
import 'layout.dart';
import 'reader_style.dart';

/// A highlight (or note) on the page, by global character range.
@immutable
class Mark {
  const Mark({required this.id, required this.from, required this.to, required this.color, this.note = false});

  final int id;
  final int from;
  final int to;
  final Color color;
  final bool note;
}

/// Drives a [ReaderView] and hears back from it: where the reader is, what
/// is selected, what is being read aloud.
class ReaderController extends ChangeNotifier {
  ReaderController(this.doc, {(int, int, int)? start}) : position = start ?? (0, 0, 0);

  final ReadingDocument doc;

  /// The first position on screen.
  (int, int, int) position;

  /// The last position on screen (for "is this page bookmarked").
  (int, int, int) lastVisible = (0, 0, 0);
  List<Mark> marks = const <Mark>[];

  /// Global [from, to) of the current selection.
  (int, int)? selection;

  /// Global [from, to) of the sentence being read aloud.
  (int, int)? spoken;

  /// Page within the section and pages in it, once laid out.
  int pageInSection = 0;
  int pagesInSection = 1;
  int globalPage = 0;
  int totalPages = 1;
  bool layoutComplete = false;

  _ReaderViewState? _view;

  int get globalIndex => doc.sections[position.$1].blocks[position.$2].start + position.$3;
  double get progress => doc.progressAt(position.$1, position.$2, position.$3);

  void goTo((int, int, int) at, {bool animate = false}) {
    position = at;
    _view?._goTo(at, animate: animate);
    notifyListeners();
  }

  void goToIndex(int global, {bool animate = false}) => goTo(doc.positionOfIndex(global), animate: animate);

  /// +1 next page, -1 previous (or a screenful in scroll layout).
  void turn(int delta) => _view?._turn(delta);

  /// Auto-scroll (scroll layout): moves by [pixels]; false at the end.
  bool scrollBy(double pixels) => _view?._scrollBy(pixels) ?? false;

  /// Volume keys (scroll layout): a [fraction] of the viewport, animated.
  void scrollScreen(double fraction) => _view?._scrollScreen(fraction);

  /// Auto page turn: past the last page there is nothing to turn to.
  bool get atEnd => progress >= 0.999;

  void setMarks(List<Mark> m) {
    marks = m;
    notifyListeners();
  }

  void setSpoken((int, int)? range) {
    spoken = range;
    if (range != null) _view?._follow(range.$1);
    notifyListeners();
  }

  void clearSelection() {
    if (selection == null) return;
    selection = null;
    notifyListeners();
  }

  /// The selected text.
  String get selectedText {
    final (int, int)? s = selection;
    if (s == null) return '';
    return doc.plainText.substring(s.$1.clamp(0, doc.plainText.length), s.$2.clamp(0, doc.plainText.length));
  }

  /// The y of the first fully visible line on screen, for the unfurl anchor.
  double? anchorLineY() => _view?._anchorY();

  void _report() => notifyListeners();
}

/// The reader surface: pages (or a scroll) of a [ReadingDocument] in a
/// [ReaderStyle], with every gesture the boards define (R12).
class ReaderView extends StatefulWidget {
  const ReaderView({
    required this.controller,
    required this.style,
    required this.layoutMode,
    required this.pageTurn,
    required this.onCentreTap,
    required this.onLink,
    required this.onMarkTap,
    required this.onSelection,
    required this.onFontStep,
    this.runningHead,
    this.footer,
    this.columns = 1,
    super.key,
  });

  final ReaderController controller;
  final ReaderStyle style;
  final ReaderLayout layoutMode;
  final PageTurn pageTurn;
  final VoidCallback onCentreTap;
  final void Function(String href) onLink;

  /// A highlight was tapped, at a global position.
  final void Function(int markId, Offset at) onMarkTap;

  /// The selection's rectangles in view coordinates (empty when cleared).
  final void Function(List<Rect> rects) onSelection;

  /// Pinch: +1 or -1 font step.
  final void Function(int step) onFontStep;

  /// Running head and footer for a page (paged layout).
  final String Function((int, int, int) at)? runningHead;
  final (String, String) Function((int, int, int) at)? footer;

  /// Two columns on a wide screen.
  final int columns;

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  Layout? _layout;
  final ImageSizes _images = ImageSizes();
  PageController? _pages;
  final GlobalKey<TurnPagerState> _turner = GlobalKey<TurnPagerState>();
  final ScrollController _scroll = ScrollController();
  int _index = 0;
  bool _imagesReady = false;
  Size? _laidFor;
  ReaderStyle? _styleFor;
  int _columnsFor = 1;
  Timer? _background;
  final GlobalKey _surface = GlobalKey();

  // Selection drag state.
  bool _dragging = false;
  bool _dragStart = false;

  // Pinch state (two pointers, tracked by hand so it never fights the pager).
  final Map<int, Offset> _pointers = <int, Offset>{};
  double? _pinchStart;
  int _pinchSteps = 0;

  @override
  void initState() {
    super.initState();
    widget.controller._view = this;
    widget.controller.addListener(_onController);
    unawaited(_loadImages());
  }

  Future<void> _loadImages() async {
    final List<String> keys = <String>[
      for (final Section s in widget.controller.doc.sections)
        for (final Block b in s.blocks)
          if (b.image != null) b.image!,
    ];
    await _images.load(widget.controller.doc.resources, keys);
    if (mounted) setState(() => _imagesReady = true);
  }

  @override
  void didUpdateWidget(ReaderView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onController);
      widget.controller._view = this;
      widget.controller.addListener(_onController);
    }
  }

  @override
  void dispose() {
    _background?.cancel();
    widget.controller.removeListener(_onController);
    if (widget.controller._view == this) widget.controller._view = null;
    _layout?.dispose();
    _pages?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  ReaderController get _c => widget.controller;
  ReadingDocument get _doc => _c.doc;

  // ------------------------------------------------------------ layout

  static const double _headH = 64, _footH = 66;

  void _ensureLayout(Size view) {
    final double w = view.width - widget.style.margin * 2;
    const double colGap = 64;
    final double colW = widget.columns == 2 ? (w - colGap) / 2 : w;
    final Size page = Size(colW, view.height - _headH - _footH);
    if (_layout != null && _laidFor == page && _styleFor == widget.style && _columnsFor == widget.columns) return;
    final (int, int, int) keep = _c.position;
    _layout?.dispose();
    _layout = Layout(doc: _doc, style: widget.style, pageSize: page, images: _images);
    _laidFor = page;
    _styleFor = widget.style;
    _columnsFor = widget.columns;
    _layout!.ensure(keep.$1);
    _index = _spreadOf(_layout!.pageOf(keep.$1, keep.$2, keep.$3));
    _pages?.dispose();
    _pages = PageController(initialPage: _index);
    _scheduleBackground();
    _reportFor(_index, notify: false);
  }

  int _spreadOf(int page) => widget.columns == 2 ? page ~/ 2 : page;
  int _pageOfSpread(int spread) => widget.columns == 2 ? spread * 2 : spread;

  /// Lays out the other sections between frames, keeping the reader on the
  /// same words as page numbers settle.
  void _scheduleBackground() {
    _background?.cancel();
    _background = Timer.periodic(const Duration(milliseconds: 16), (Timer t) {
      final Layout? l = _layout;
      if (l == null || !mounted) return t.cancel();
      final (int, int, int) keep = _c.position;
      final bool more = l.layoutNext(keep.$1);
      if (!more) {
        t.cancel();
        _c.layoutComplete = true;
      }
      final int now = _spreadOf(l.pageOf(keep.$1, keep.$2, keep.$3));
      if (now != _index && _pages != null && _pages!.hasClients) {
        _index = now;
        _pages!.jumpToPage(now);
      }
      setState(() {});
      _reportFor(_index, notify: true);
    });
  }

  void _reportFor(int spread, {required bool notify}) {
    final Layout l = _layout!;
    final ReaderPage? p = l.page(_pageOfSpread(spread));
    if (p == null || p.fragments.isEmpty) return;
    _c.position = p.first;
    final ReaderPage lastPage = widget.columns == 2 ? (l.page(_pageOfSpread(spread) + 1) ?? p) : p;
    _c.lastVisible = lastPage.last;
    final (int s, int ps) = l.sectionPageOf(_pageOfSpread(spread));
    _c.pageInSection = ps;
    _c.pagesInSection = l.sections[s]?.length ?? 1;
    _c.globalPage = _pageOfSpread(spread);
    _c.totalPages = l.knownPages;
    if (notify) _c._report();
  }

  // ------------------------------------------------------------ commands

  void _goTo((int, int, int) at, {required bool animate}) {
    if (widget.layoutMode == ReaderLayout.scroll) {
      final int i = _flatIndex(at.$1, at.$2);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _jumpToFlat(i, at.$3);
      });
      return;
    }
    final Layout? l = _layout;
    if (l == null) return;
    final int target = _spreadOf(l.pageOf(at.$1, at.$2, at.$3));
    _setIndex(target, animate: animate);
  }

  bool _scrollBy(double pixels) {
    if (!_scroll.hasClients) return false;
    final ScrollPosition p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent) return false;
    _scroll.jumpTo((p.pixels + pixels).clamp(p.minScrollExtent, p.maxScrollExtent));
    return true;
  }

  void _scrollScreen(double fraction) {
    if (!_scroll.hasClients) return;
    final ScrollPosition p = _scroll.position;
    unawaited(
      _scroll.animateTo(
        (p.pixels + p.viewportDimension * fraction).clamp(p.minScrollExtent, p.maxScrollExtent),
        duration: Motion.of(context, Motion.volumeScroll),
        curve: Motion.decelerate,
      ),
    );
  }

  void _turn(int delta) {
    if (widget.layoutMode == ReaderLayout.scroll) {
      if (!_scroll.hasClients) return;
      final double step = _scroll.position.viewportDimension * 0.85 * delta;
      unawaited(
        _scroll.animateTo(
          (_scroll.offset + step).clamp(0, _scroll.position.maxScrollExtent),
          duration: Motion.of(context, Motion.pageTurn),
          curve: Motion.decelerate,
        ),
      );
      return;
    }
    final Layout? l = _layout;
    if (l == null) return;
    final int max = _spreadOf(l.knownPages - 1);
    _setIndex((_index + delta).clamp(0, max), animate: true);
  }

  void _setIndex(int target, {required bool animate}) {
    if (target == _index && _pages?.hasClients == true && _pages!.page?.round() == target) return;
    final bool reduced = Motion.reduced(context);
    final TurnPagerState? turner = _turner.currentState;
    if (turner != null && animate && (target - _index).abs() == 1) {
      _c.clearSelection();
      widget.onSelection(const <Rect>[]);
      turner.turn(target - _index);
      return;
    }
    if (widget.pageTurn == PageTurn.slide &&
        animate &&
        !reduced &&
        _pages?.hasClients == true &&
        (target - _index).abs() == 1) {
      unawaited(_pages!.animateToPage(target, duration: Motion.pageTurn, curve: Motion.spring));
    } else {
      setState(() => _index = target);
      if (_pages?.hasClients == true) _pages!.jumpToPage(target);
    }
    _c.clearSelection();
    widget.onSelection(const <Rect>[]);
    _reportFor(target, notify: true);
  }

  /// Read aloud: turn to the page the sentence starts on.
  void _follow(int global) {
    final (int, int, int) at = _doc.positionOfIndex(global);
    if (widget.layoutMode == ReaderLayout.scroll) {
      _goTo(at, animate: true);
      return;
    }
    final Layout? l = _layout;
    if (l == null) return;
    final int target = _spreadOf(l.pageOf(at.$1, at.$2, at.$3));
    if (target != _index) _setIndex(target, animate: true);
  }

  double? _anchorY() {
    final ReaderPage? p = _layout?.page(_pageOfSpread(_index));
    final Fragment? f = p?.firstText;
    if (f == null) return null;
    return _headH + f.rect.top;
  }

  // ------------------------------------------------------------ gestures

  Offset _toPage(Offset local, int column) {
    final double colW = _laidFor!.width;
    return local - Offset(widget.style.margin + column * (colW + 64), _headH);
  }

  (Fragment, int)? _hit(ReaderPage page, Offset p, {bool clamp = false}) {
    for (final Fragment f in page.fragments) {
      final int? o = f.offsetAt(p);
      if (o != null) return (f, o);
    }
    if (!clamp) return null;
    // Nearest text fragment by vertical distance.
    Fragment? best;
    double d = double.infinity;
    for (final Fragment f in page.fragments.where((Fragment f) => f.isText)) {
      final double dist = p.dy < f.rect.top ? f.rect.top - p.dy : (p.dy > f.rect.bottom ? p.dy - f.rect.bottom : 0);
      if (dist < d) {
        d = dist;
        best = f;
      }
    }
    if (best == null) return null;
    return (best, best.offsetAt(p, clamp: true)!);
  }

  (ReaderPage, int)? _pageAt(Offset local) {
    final Layout? l = _layout;
    if (l == null) return null;
    final int column = widget.columns == 2 && local.dx > (_laidFor!.width + widget.style.margin + 32) ? 1 : 0;
    final ReaderPage? page = l.page(_pageOfSpread(_index) + column);
    return page == null ? null : (page, column);
  }

  int _global(Fragment f, int o) => f.block.start + o;

  void _onTapUp(TapUpDetails d, Size size) {
    if (_c.selection != null) {
      _c.clearSelection();
      widget.onSelection(const <Rect>[]);
      return;
    }
    final (ReaderPage, int)? at = _pageAt(d.localPosition);
    if (at != null) {
      final Offset p = _toPage(d.localPosition, at.$2);
      for (final Fragment f in at.$1.fragments) {
        final String? href = f.linkAt(p);
        if (href != null) return widget.onLink(href);
        final int? o = f.offsetAt(p);
        if (o != null) {
          final int g = _global(f, o);
          for (final Mark m in _c.marks) {
            if (g >= m.from && g < m.to) return widget.onMarkTap(m.id, d.globalPosition);
          }
        }
      }
    }
    final double x = d.localPosition.dx / size.width;
    if (widget.layoutMode == ReaderLayout.paged && x < 0.25) return _turn(-1);
    if (widget.layoutMode == ReaderLayout.paged && x > 0.75) return _turn(1);
    widget.onCentreTap();
  }

  void _onLongPress(LongPressStartDetails d) {
    final (ReaderPage, int)? at = _pageAt(d.localPosition);
    if (at == null) return;
    final (Fragment, int)? hit = _hit(at.$1, _toPage(d.localPosition, at.$2));
    if (hit == null) return;
    final (Fragment f, int o) = hit;
    final String text = f.block.text;
    int a = o, b = o;
    final RegExp word = RegExp(r"[\p{L}\p{N}’'-]", unicode: true);
    while (a > 0 && word.hasMatch(text[a - 1])) {
      a--;
    }
    while (b < text.length && word.hasMatch(text[b])) {
      b++;
    }
    if (a == b) return;
    _c.selection = (_global(f, a), _global(f, b));
    _c._report();
    _emitSelection();
  }

  void _emitSelection() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onSelection(_selectionRects());
    });
  }

  /// Selection rectangles in view coordinates.
  List<Rect> _selectionRects() {
    final (int, int)? s = _c.selection;
    final Layout? l = _layout;
    if (s == null || l == null) return const <Rect>[];
    final List<Rect> out = <Rect>[];
    for (int col = 0; col < widget.columns; col++) {
      final ReaderPage? page = l.page(_pageOfSpread(_index) + col);
      if (page == null) continue;
      final Offset origin = Offset(widget.style.margin + col * (_laidFor!.width + 64), _headH);
      for (final Rect r in _boxes(page, s.$1, s.$2)) {
        out.add(r.shift(origin));
      }
    }
    return out;
  }

  List<Rect> _boxes(ReaderPage page, int a, int b) {
    final List<Rect> out = <Rect>[];
    for (final Fragment f in page.fragments) {
      final int base = f.block.start;
      if (base + f.end <= a || base + f.start >= b) continue;
      out.addAll(f.boxes((a - base).clamp(0, f.block.text.length), (b - base).clamp(0, f.block.text.length)));
    }
    return out;
  }

  void _dragHandle(Offset local, {required bool start}) {
    final (ReaderPage, int)? at = _pageAt(local);
    if (at == null || _c.selection == null) return;
    final (Fragment, int)? hit = _hit(at.$1, _toPage(local, at.$2) - const Offset(0, 24), clamp: true);
    if (hit == null) return;
    final int g = _global(hit.$1, hit.$2);
    final (int a, int b) = _c.selection!;
    _c.selection = start ? (math.min(g, b - 1), b) : (a, math.max(g, a + 1));
    _c._report();
    _emitSelection();
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2) {
      _pinchStart = (_pointers.values.first - _pointers.values.last).distance;
      _pinchSteps = 0;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    final double? start = _pinchStart;
    if (_pointers.length == 2 && start != null && start > 0) {
      final double ratio = (_pointers.values.first - _pointers.values.last).distance / start;
      final int steps = (math.log(ratio) / math.log(1.18)).truncate();
      if (steps != _pinchSteps) {
        widget.onFontStep(steps - _pinchSteps);
        _pinchSteps = steps;
      }
    }
  }

  void _onPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchStart = null;
  }

  // ------------------------------------------------------------ scroll

  late List<(int, int)> _flat = _flatten();

  List<(int, int)> _flatten() => <(int, int)>[
    for (int s = 0; s < _doc.sections.length; s++)
      for (int b = 0; b < _doc.sections[s].blocks.length; b++) (s, b),
  ];

  int _flatIndex(int s, int b) {
    final int i = _flat.indexOf((s, b));
    return i < 0 ? 0 : i;
  }

  final Map<int, GlobalKey> _itemKeys = <int, GlobalKey>{};

  void _jumpToFlat(int i, int offset) {
    // Estimate, then correct once the item is built.
    final double est = _scroll.position.maxScrollExtent * (i / math.max(1, _flat.length));
    _scroll.jumpTo(est.clamp(0, _scroll.position.maxScrollExtent));
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final BuildContext? ctx = _itemKeys[i]?.currentContext;
      if (ctx != null && ctx.mounted) Scrollable.ensureVisible(ctx, alignment: 0.05);
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollEndNotification || n is ScrollUpdateNotification) {
      // The first block whose box crosses the top of the viewport.
      for (final MapEntry<int, GlobalKey> e
          in _itemKeys.entries.toList()
            ..sort((MapEntry<int, GlobalKey> a, MapEntry<int, GlobalKey> b) => a.key.compareTo(b.key))) {
        final RenderObject? r = e.value.currentContext?.findRenderObject();
        if (r is! RenderBox || !r.attached) continue;
        final Offset o = r.localToGlobal(Offset.zero);
        if (o.dy + r.size.height > MediaQuery.paddingOf(context).top + 8) {
          final (int s, int b) = _flat[e.key];
          if (_c.position.$1 != s || _c.position.$2 != b) {
            _c.position = (s, b, 0);
            _c.lastVisible = (s, b, 0);
            _c._report();
          }
          break;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_imagesReady) return const SizedBox.expand();
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: widget.layoutMode == ReaderLayout.scroll ? _buildScroll(context) : _buildPaged(context),
    );
  }

  Widget _buildPaged(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) {
      final Size size = box.biggest;
      _ensureLayout(size);
      final Layout l = _layout!;
      final int spreads = _spreadOf(math.max(0, l.knownPages - 1)) + 1;
      Widget spread(int i) => _Spread(
        key: ValueKey<int>(i),
        layout: l,
        first: _pageOfSpread(i),
        columns: widget.columns,
        style: widget.style,
        marks: _c.marks,
        selection: _c.selection,
        spoken: _c.spoken,
        resources: _doc.resources,
        head: widget.runningHead,
        foot: widget.footer,
        headH: _headH,
        footH: _footH,
      );
      final Widget pages = switch (widget.pageTurn) {
        PageTurn.slide when !Motion.reduced(context) => PageView.builder(
          controller: _pages,
          itemCount: spreads,
          onPageChanged: (int i) {
            _index = i;
            _c.clearSelection();
            widget.onSelection(const <Rect>[]);
            _reportFor(i, notify: true);
          },
          itemBuilder: (BuildContext context, int i) => spread(i),
        ),
        PageTurn.curl || PageTurn.cover => TurnPager(
          key: _turner,
          style: widget.pageTurn,
          index: _index,
          count: spreads,
          builder: spread,
          backFace: Color.alphaBlend(widget.style.theme.ink.withValues(alpha: 0.08), widget.style.theme.paper),
          onTurned: (int i) {
            setState(() => _index = i);
            _c.clearSelection();
            widget.onSelection(const <Rect>[]);
            _reportFor(i, notify: true);
          },
        ),
        PageTurn.fade => GestureDetector(
          onHorizontalDragEnd: (DragEndDetails d) => _turn((d.primaryVelocity ?? 0) < 0 ? 1 : -1),
          child: AnimatedSwitcher(duration: Motion.pageFade, child: spread(_index)),
        ),
        _ => GestureDetector(
          onHorizontalDragEnd: (DragEndDetails d) => _turn((d.primaryVelocity ?? 0) < 0 ? 1 : -1),
          child: spread(_index),
        ),
      };
      return Stack(
        key: _surface,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (TapUpDetails d) => _onTapUp(d, size),
            onLongPressStart: _onLongPress,
            onLongPressMoveUpdate: (LongPressMoveUpdateDetails d) {
              // A held finger jitters; extend only once it really moves.
              if (!_dragging && d.offsetFromOrigin.distance < kTouchSlop) return;
              _dragging = true;
              _dragHandle(d.localPosition + const Offset(0, 24), start: false);
            },
            onLongPressEnd: (_) => _dragging = false,
            child: pages,
          ),
          if (_c.selection != null && !_dragging) ..._handles(),
        ],
      );
    },
  );

  List<Widget> _handles() {
    final List<Rect> rects = _selectionRects();
    if (rects.isEmpty) return const <Widget>[];
    final Rect first = rects.first, last = rects.last;
    final Color colour = widget.style.theme.handle;
    Widget handle({required bool start}) {
      final Rect r = start ? first : last;
      return Positioned(
        left: (start ? r.left - 18 : r.right) - 14,
        top: r.bottom - 14,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => setState(() => _dragStart = start),
          onPanUpdate: (DragUpdateDetails d) {
            final RenderBox box = _surface.currentContext!.findRenderObject()! as RenderBox;
            _dragHandle(box.globalToLocal(d.globalPosition), start: _dragStart);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: colour,
                borderRadius: start
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(9),
                        bottomLeft: Radius.circular(9),
                        bottomRight: Radius.circular(9),
                      )
                    : const BorderRadius.only(
                        topRight: Radius.circular(9),
                        bottomLeft: Radius.circular(9),
                        bottomRight: Radius.circular(9),
                      ),
              ),
            ),
          ),
        ),
      );
    }

    return <Widget>[handle(start: true), handle(start: false)];
  }

  Widget _buildScroll(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) {
      final double width = math.min(box.maxWidth - widget.style.margin * 2, widget.style.size * 38);
      if (_flat.isEmpty) _flat = _flatten();
      return NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ListView.builder(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            (box.maxWidth - width) / 2,
            MediaQuery.paddingOf(context).top + 24,
            (box.maxWidth - width) / 2,
            120,
          ),
          itemCount: _flat.length,
          itemBuilder: (BuildContext context, int i) {
            final (int s, int b) = _flat[i];
            final GlobalKey key = _itemKeys.putIfAbsent(i, GlobalKey.new);
            return _ScrollBlock(
              key: key,
              doc: _doc,
              section: s,
              block: b,
              width: width,
              style: widget.style,
              marks: _c.marks,
              spoken: _c.spoken,
              selection: _c.selection,
              images: _images,
              onTap: (int? global, String? href, Offset at) {
                if (_c.selection != null) {
                  _c.clearSelection();
                  widget.onSelection(const <Rect>[]);
                  return;
                }
                if (href != null) return widget.onLink(href);
                if (global != null) {
                  for (final Mark m in _c.marks) {
                    if (global >= m.from && global < m.to) return widget.onMarkTap(m.id, at);
                  }
                }
                widget.onCentreTap();
              },
              onSelect: ((int, int) range, List<Rect> rects) {
                _c.selection = range;
                _c._report();
                widget.onSelection(rects);
              },
            );
          },
        ),
      );
    },
  );
}

/// One spread: one page, or two side by side on a wide screen, with the
/// running head and footer.
class _Spread extends StatelessWidget {
  const _Spread({
    required this.layout,
    required this.first,
    required this.columns,
    required this.style,
    required this.marks,
    required this.selection,
    required this.spoken,
    required this.resources,
    required this.head,
    required this.foot,
    required this.headH,
    required this.footH,
    super.key,
  });

  final Layout layout;
  final int first;
  final int columns;
  final ReaderStyle style;
  final List<Mark> marks;
  final (int, int)? selection;
  final (int, int)? spoken;
  final Map<String, dynamic> resources;
  final String Function((int, int, int))? head;
  final (String, String) Function((int, int, int))? foot;
  final double headH;
  final double footH;

  @override
  Widget build(BuildContext context) {
    final ReaderPage? page = layout.page(first);
    final (int, int, int) at = page?.first ?? (0, 0, 0);
    final TextStyle meta = TextStyle(
      fontFamily: UnfurlType.mono,
      fontSize: 11,
      color: style.theme.inkMuted,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.44,
    );
    final (String, String)? f = foot?.call(at);
    return RepaintBoundary(
      child: ColoredBox(
        color: style.theme.paper,
        child: Stack(
          children: <Widget>[
            if (head != null)
              Positioned(
                top: 28,
                left: style.margin,
                right: style.margin,
                child: Text(
                  head!(at),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: meta,
                ),
              ),
            // A spread's gutter: a 1dp rule in muted ink (board 6, V7).
            if (columns == 2)
              Positioned(
                left: style.margin + layout.pageSize.width + 32,
                top: headH,
                width: 1,
                height: layout.pageSize.height,
                child: ColoredBox(color: style.theme.inkMuted.withValues(alpha: 0.25)),
              ),
            for (int col = 0; col < columns; col++)
              if (layout.page(first + col) != null)
                Positioned(
                  left: style.margin + col * (layout.pageSize.width + 64),
                  top: headH,
                  width: layout.pageSize.width,
                  height: layout.pageSize.height,
                  child: _PageContent(
                    page: layout.page(first + col)!,
                    style: style,
                    marks: marks,
                    selection: selection,
                    spoken: spoken,
                    doc: layout.doc,
                  ),
                ),
            if (f != null)
              Positioned(
                bottom: 28,
                left: style.margin,
                right: style.margin,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(f.$1, style: meta),
                    Flexible(
                      child: Text(
                        f.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: meta,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A page's text, images and tables, with highlights under the text.
class _PageContent extends StatelessWidget {
  const _PageContent({
    required this.page,
    required this.style,
    required this.marks,
    required this.selection,
    required this.spoken,
    required this.doc,
  });

  final ReaderPage page;
  final ReaderStyle style;
  final List<Mark> marks;
  final (int, int)? selection;
  final (int, int)? spoken;
  final ReadingDocument doc;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: <Widget>[
      Positioned.fill(
        child: CustomPaint(
          painter: _PagePainter(page: page, style: style, marks: marks, selection: selection, spoken: spoken),
        ),
      ),
      // A table wider than the page: an invisible sideways scroller over it;
      // the page painter draws it at the scrolled offset.
      for (final Fragment f in page.fragments)
        if (f.scroll != null)
          Positioned(
            key: ObjectKey(f),
            left: 0,
            right: 0,
            top: f.rect.top,
            height: f.rect.height,
            child: _TableScroller(fragment: f),
          ),
      for (final Fragment f in page.fragments)
        if (f.block.kind == BlockKind.image && doc.resources[f.block.image] != null)
          Positioned.fromRect(
            rect: f.rect,
            child: ClipRRect(
              borderRadius: Radii.pageR,
              child: Image.memory(
                doc.resources[f.block.image]!,
                fit: BoxFit.contain,
                cacheWidth: (f.rect.width * MediaQuery.devicePixelRatioOf(context)).round(),
                gaplessPlayback: true,
                semanticLabel: f.block.text,
              ),
            ),
          ),
    ],
  );
}

/// Paints one page: under-text marks (highlights, the spoken sentence, the
/// selection), then each fragment.
class _PagePainter extends CustomPainter {
  _PagePainter({
    required this.page,
    required this.style,
    required this.marks,
    required this.selection,
    required this.spoken,
  }) : super(repaint: Listenable.merge(<Listenable?>[for (final Fragment f in page.fragments) f.scroll]));

  final ReaderPage page;
  final ReaderStyle style;
  final List<Mark> marks;
  final (int, int)? selection;
  final (int, int)? spoken;

  List<Rect> _boxes(int a, int b) {
    final List<Rect> out = <Rect>[];
    for (final Fragment f in page.fragments) {
      final int base = f.block.start;
      if (base + f.end <= a || base + f.start >= b) continue;
      out.addAll(f.boxes((a - base).clamp(0, f.block.text.length), (b - base).clamp(0, f.block.text.length)));
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ReaderStyle s = style;
    void fill(List<Rect> rects, Color c) {
      final Paint p = Paint()..color = c;
      for (final Rect r in rects) {
        canvas.drawRRect(RRect.fromRectAndRadius(r.inflate(1), const Radius.circular(2)), p);
      }
    }

    // Clipped to the page: a scrolled table's marks run past its edges.
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    for (final Mark m in marks) {
      fill(_boxes(m.from, m.to), m.color);
    }
    if (spoken != null) fill(_boxes(spoken!.$1, spoken!.$2), s.theme.handle.withValues(alpha: 0.16));
    if (selection != null) fill(_boxes(selection!.$1, selection!.$2), s.theme.handle.withValues(alpha: 0.30));
    canvas.restore();

    for (final Fragment f in page.fragments) {
      final Block b = f.block;
      switch (b.kind) {
        case BlockKind.rule:
          canvas.drawLine(
            Offset(f.rect.left + f.rect.width * 0.3, f.rect.center.dy),
            Offset(f.rect.right - f.rect.width * 0.3, f.rect.center.dy),
            Paint()
              ..color = s.theme.rule
              ..strokeWidth = 1,
          );
        case BlockKind.table when f.scroll != null:
          canvas
            ..save()
            ..clipRect(Rect.fromLTWH(0, f.rect.top - 1, size.width, f.rect.height + 2))
            ..translate(f.scroll!.value * -1, 0);
          _paintTable(canvas, f, s);
          canvas.restore();
        case BlockKind.table:
          _paintTable(canvas, f, s);
        case BlockKind.image:
          break;
        default:
          if (b.kind == BlockKind.code) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTRB(0, f.rect.top - 10, size.width, f.rect.bottom + 10),
                const Radius.circular(8),
              ),
              Paint()..color = s.theme.rule,
            );
          }
          if (b.kind == BlockKind.quote) {
            canvas.drawRect(Rect.fromLTWH(0, f.rect.top + 2, 3, f.rect.height - 4), Paint()..color = s.theme.rule);
          }
          if (f.bulletPainter != null) {
            f.bulletPainter!.paint(canvas, Offset(f.rect.left - f.bulletPainter!.width - s.size * 0.5, f.rect.top));
          }
          if (b.checked != null && f.start == 0) {
            final TextPainter box = TextPainter(
              text: TextSpan(
                text: String.fromCharCode((b.checked! ? AppIcons.checkBox : AppIcons.checkBoxBlank).codePoint),
                style: TextStyle(
                  fontFamily: 'Material Symbols Rounded',
                  fontSize: 20,
                  color: b.checked! ? s.theme.handle : s.theme.inkMuted,
                  fontVariations: const <FontVariation>[FontVariation('wght', 350)],
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            box.paint(canvas, Offset(f.rect.left - 28, f.rect.top + (s.size * s.lineHeight - 20) / 2));
            box.dispose();
          }
          f.paintText(canvas);
      }
    }
  }

  /// The rules; the cells' text is painted with the rest of the text.
  void _paintTable(Canvas canvas, Fragment f, ReaderStyle s) {
    final List<List<String>> rows = f.block.rows!;
    final Paint ink = Paint()
      ..color = s.theme.ink
      ..strokeWidth = 1;
    final Paint rule = Paint()
      ..color = s.theme.rule
      ..strokeWidth = 1;
    double y = f.rect.top;
    if (f.rowStart == 0) canvas.drawLine(Offset(f.rect.left, y), Offset(f.rect.right, y), ink);
    for (int r = f.rowStart; r < f.rowEnd; r++) {
      y += f.rowHeights![r - f.rowStart];
      canvas.drawLine(Offset(f.rect.left, y), Offset(f.rect.right, y), r == rows.length - 1 ? ink : rule);
    }
    f.paintText(canvas);
  }

  @override
  bool shouldRepaint(_PagePainter old) =>
      old.page != page ||
      old.style != style ||
      old.marks != marks ||
      old.selection != selection ||
      old.spoken != spoken;
}

/// Scrolls a wide table sideways by moving its fragment's offset. It draws
/// nothing; taps and long presses fall through to the page.
class _TableScroller extends StatefulWidget {
  const _TableScroller({required this.fragment});

  final Fragment fragment;

  @override
  State<_TableScroller> createState() => _TableScrollerState();
}

class _TableScrollerState extends State<_TableScroller> {
  late final ScrollController _c = ScrollController(initialScrollOffset: widget.fragment.scroll!.value)
    ..addListener(() => widget.fragment.scroll!.value = _c.offset);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    controller: _c,
    child: SizedBox(width: widget.fragment.rect.width, height: widget.fragment.rect.height),
  );
}

/// One block in scroll layout, laid out at the column width, with a
/// chapter divider before a section's first block.
class _ScrollBlock extends StatefulWidget {
  const _ScrollBlock({
    required this.doc,
    required this.section,
    required this.block,
    required this.width,
    required this.style,
    required this.marks,
    required this.spoken,
    required this.selection,
    required this.images,
    required this.onTap,
    required this.onSelect,
    super.key,
  });

  final ReadingDocument doc;
  final int section;
  final int block;
  final double width;
  final ReaderStyle style;
  final List<Mark> marks;
  final (int, int)? spoken;
  final (int, int)? selection;
  final ImageSizes images;
  final void Function(int? global, String? href, Offset at) onTap;
  final void Function((int, int) range, List<Rect> rects) onSelect;

  @override
  State<_ScrollBlock> createState() => _ScrollBlockState();
}

class _ScrollBlockState extends State<_ScrollBlock> {
  Layout? _layout;
  double? _w;
  ReaderStyle? _s;

  ReaderPage _page() {
    if (_layout == null || _w != widget.width || _s != widget.style) {
      _layout?.dispose();
      final Section one = Section(title: '', blocks: <Block>[widget.doc.sections[widget.section].blocks[widget.block]]);
      final ReadingDocument single = ReadingDocument.view(widget.doc, <Section>[one]);
      _layout = Layout(doc: single, style: widget.style, pageSize: Size(widget.width, 100000), images: widget.images);
      _w = widget.width;
      _s = widget.style;
    }
    _layout!.ensure(0);
    return _layout!.sections[0]!.first;
  }

  @override
  void dispose() {
    _layout?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ReaderPage page = _page();
    final Block b = widget.doc.sections[widget.section].blocks[widget.block];
    final Block? prev = widget.block > 0 ? widget.doc.sections[widget.section].blocks[widget.block - 1] : null;
    final double height = page.fragments.isEmpty
        ? 0
        : page.fragments.map((Fragment f) => f.rect.bottom).reduce(math.max) + (b.kind == BlockKind.code ? 10 : 0);
    final ReaderStyle s = widget.style;
    final TextStyle divider = TextStyle(
      fontFamily: UnfurlType.sans,
      fontSize: 13,
      letterSpacing: 13 * 0.08,
      fontWeight: FontWeight.w600,
      color: s.theme.inkMuted,
    );
    final int base = b.start;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.block == 0 && widget.section > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              spacing: 12,
              children: <Widget>[
                Expanded(child: Container(height: 1, color: s.theme.rule)),
                Text(widget.doc.sections[widget.section].title.toUpperCase(), style: divider),
                Expanded(child: Container(height: 1, color: s.theme.rule)),
              ],
            ),
          ),
        SizedBox(height: s.spaceBefore(b, prev)),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (TapUpDetails d) {
            for (final Fragment f in page.fragments) {
              final String? href = f.linkAt(d.localPosition);
              if (href != null) return widget.onTap(null, href, d.globalPosition);
              final int? o = f.offsetAt(d.localPosition);
              if (o != null) return widget.onTap(base + o, null, d.globalPosition);
            }
            widget.onTap(null, null, d.globalPosition);
          },
          onLongPressStart: (LongPressStartDetails d) {
            for (final Fragment f in page.fragments) {
              final int? o = f.offsetAt(d.localPosition);
              if (o == null) continue;
              final String text = b.text;
              int a = o, e = o;
              final RegExp word = RegExp(r"[\p{L}\p{N}’'-]", unicode: true);
              while (a > 0 && word.hasMatch(text[a - 1])) {
                a--;
              }
              while (e < text.length && word.hasMatch(text[e])) {
                e++;
              }
              if (a == e) return;
              final RenderBox box = context.findRenderObject()! as RenderBox;
              final List<Rect> rects = f
                  .boxes(a, e)
                  .map((Rect r) => Rect.fromPoints(box.localToGlobal(r.topLeft), box.localToGlobal(r.bottomRight)))
                  .toList();
              widget.onSelect((base + a, base + e), rects);
              return;
            }
          },
          child: SizedBox(
            height: height,
            child: _PageContent(
              page: page,
              style: s,
              marks: widget.marks,
              selection: widget.selection,
              spoken: widget.spoken,
              doc: _layout!.doc,
            ),
          ),
        ),
      ],
    );
  }
}
