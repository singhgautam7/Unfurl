// ignore_for_file: discarded_futures, unawaited_futures (animation futures are fire-and-forget)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../motion/kit.dart';
import '../theme/app_theme.dart';

/// The tabs as pages side by side, switched as Kuber's tab pager does: a tap
/// slides the whole page over in 300 ms, ease in and out (a far tab slides in
/// from next door), a sideways drag follows the finger, and a new tap
/// mid-slide carries on from where the pages are. The same at Subtle (a slide
/// has no overshoot and costs less than a fade); Off switches at once.
///
/// Mull's `BranchStack`, not a `PageView`: that lays out a third page in the
/// frame of a far jump and can't build or paint a page ahead of its visit.
/// Every built tab keeps its layout, a slide moves finished layers (the
/// repaint boundary is inside the moving part), and a tab being warmed
/// ([WarmTab]) is painted for two frames at an opacity nobody can see.
class BranchStack extends StatefulWidget {
  const BranchStack({
    required this.index,
    required this.onSelect,
    required this.children,
    this.draggable = true,
    super.key,
  });

  /// The active page among [children] (tabs shown, in order).
  final int index;
  final ValueChanged<int> onSelect;
  final List<Widget> children;

  /// False inside a tab (a folder): a sideways drag there is the folder's own.
  final bool draggable;

  /// The page being painted ahead of its first visit, if any.
  static final ValueNotifier<int?> warming = ValueNotifier<int?>(null);

  @override
  State<BranchStack> createState() => _BranchStackState();
}

class _BranchStackState extends State<BranchStack> with SingleTickerProviderStateMixin {
  /// One step of 8-bit alpha: painted, and not visible.
  static const double _unseen = 1 / 255;

  /// A fling this fast switches, however short.
  static const double _fling = 240;

  /// Where the view is on the strip, in pages.
  late final AnimationController _cam = AnimationController.unbounded(vsync: this, value: widget.index.toDouble());

  /// Pages on the strip now, and where. At rest only the active one.
  late Map<int, int> _strip = <int, int>{widget.index: widget.index};

  bool _dragging = false;

  @override
  void didUpdateWidget(BranchStack old) {
    super.didUpdateWidget(old);
    if (widget.index == old.index) return;
    if (Motion.isOff(context)) {
      _rest();
      return;
    }
    if (!_strip.containsKey(widget.index)) {
      // Whatever was mid-slide there gives up its place.
      _place(widget.index, _strip[old.index]! + (widget.index > old.index ? 1 : -1));
    }
    // After this frame: a first visit builds the page in it, and the slide
    // must not spend its start on that.
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted && !_dragging) _settle(duration: Motion.tabSlide);
    });
  }

  /// Slides to the active page and then leaves only it on the strip.
  void _settle({Duration? duration}) {
    final double to = _strip[widget.index]!.toDouble();
    if (duration != null) {
      _cam.animateTo(to, duration: duration, curve: Motion.tabSlideCurve).whenComplete(_trim);
    } else {
      _cam.springTo(to, Motion.springStandard).whenComplete(_trim);
    }
  }

  void _trim() {
    if (!mounted || _dragging || _cam.isAnimating) return;
    setState(_rest);
  }

  void _rest() {
    _strip = <int, int>{widget.index: widget.index};
    _cam.value = widget.index.toDouble();
  }

  // ---- The finger. Vertical drags and the rows that scroll sideways win
  // ---- the arena before this does.

  void _dragStart(DragStartDetails d) {
    if (Motion.isOff(context)) return;
    _cam.stop();
    final int at = _strip[widget.index]!;
    setState(() {
      _dragging = true;
      if (widget.index > 0) _place(widget.index - 1, at - 1);
      if (widget.index < widget.children.length - 1) _place(widget.index + 1, at + 1);
    });
  }

  void _place(int page, int at) {
    _strip
      ..remove(page)
      ..removeWhere((int _, int p) => p == at)
      ..[page] = at;
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final int at = _strip[widget.index]!;
    final double lo = at - (widget.index > 0 ? 1.0 : 0.0);
    final double hi = at + (widget.index < widget.children.length - 1 ? 1.0 : 0.0);
    _cam.value = (_cam.value - d.primaryDelta! / context.size!.width).clamp(lo, hi);
  }

  void _dragEnd(DragEndDetails d) {
    final double v = d.primaryVelocity ?? 0;
    final int step = !_dragging
        ? (v.abs() < _fling ? 0 : (v < 0 ? 1 : -1))
        : v.abs() >= _fling
        ? (v < 0 ? 1 : -1)
        : (_cam.value - _strip[widget.index]!).round().clamp(-1, 1);
    _dragging = false;
    final int next = widget.index + step;
    if (step != 0 && next >= 0 && next < widget.children.length) {
      widget.onSelect(next); // didUpdateWidget slides the rest of the way
    } else {
      _settle();
    }
  }

  @override
  void dispose() {
    _cam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: widget.draggable ? _dragStart : null,
    onHorizontalDragUpdate: widget.draggable ? _dragUpdate : null,
    onHorizontalDragEnd: widget.draggable ? _dragEnd : null,
    onHorizontalDragCancel: widget.draggable
        ? () {
            if (!_dragging) return;
            _dragging = false;
            _settle();
          }
        : null,
    child: ClipRect(
      child: ValueListenableBuilder<int?>(
        valueListenable: BranchStack.warming,
        builder: (BuildContext context, int? warm, Widget? _) => Stack(
          fit: StackFit.expand,
          children: <Widget>[for (int i = 0; i < widget.children.length; i++) _page(i, warm)],
        ),
      ),
    ),
  );

  Widget _page(int i, int? warm) {
    final bool active = i == widget.index;
    final int? at = _strip[i];
    return Offstage(
      offstage: at == null && i != warm,
      child: IgnorePointer(
        ignoring: !active,
        child: ExcludeSemantics(
          excluding: !active,
          child: ExcludeFocus(
            excluding: !active,
            child: AnimatedBuilder(
              animation: _cam,
              builder: (BuildContext _, Widget? child) =>
                  FractionalTranslation(translation: Offset(at == null ? 0 : at - _cam.value, 0), child: child),
              child: Opacity(
                opacity: at == null ? _unseen : 1,
                child: RepaintBoundary(
                  // A tab not visited yet is empty: its page still has a ground.
                  child: ColoredBox(
                    color: context.colors.surface,
                    child: TickerMode(enabled: active, child: widget.children[i]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds, lays out and paints a tab while the app idles on another one, so
/// its first visit is a repaint. The router preloads the branch; its [child]
/// waits here until it is visited, or until [order]'s turn after start-up with
/// no animation or scroll under way. Once built it stays.
///
/// [needs] are the streams the tab shows: a paused (offstage) subscription
/// would build it empty, so they are listened to until each has a value.
class WarmTab extends ConsumerStatefulWidget {
  const WarmTab({
    required this.page,
    required this.order,
    required this.child,
    this.needs = const <Never>[],
    super.key,
  });

  /// Its place among the tabs shown ([BranchStack.children]).
  final int page;

  /// 0 warms first.
  final int order;
  final List<ProviderListenable<AsyncValue<Object?>>> needs;
  final Widget child;

  @override
  ConsumerState<WarmTab> createState() => _WarmTabState();
}

class _WarmTabState extends ConsumerState<WarmTab> {
  bool _built = false;
  Timer? _timer;

  /// Tries left: a launch that never goes quiet is left alone.
  int _tries = 100;
  final List<ProviderSubscription<AsyncValue<Object?>>> _subs = <ProviderSubscription<AsyncValue<Object?>>>[];

  @override
  void initState() {
    super.initState();
    _timer = Timer(Motion.warmDelay + Motion.warmStep * widget.order, _tryWarm);
  }

  Future<void> _tryWarm() async {
    if (!mounted || _built) return;
    if (_subs.isEmpty) {
      for (final ProviderListenable<AsyncValue<Object?>> p in widget.needs) {
        _subs.add(ref.listenManual(p, (_, _) {}));
      }
    }
    final bool busy = Haptics.scrolling || SchedulerBinding.instance.transientCallbackCount > 0;
    if (busy || _subs.any((ProviderSubscription<AsyncValue<Object?>> s) => s.read().isLoading)) {
      if (--_tries == 0) return _close();
      _timer = Timer(Motion.warmRetry, _tryWarm);
      return;
    }
    setState(() => _built = true);
    await WidgetsBinding.instance.endOfFrame;
    _close();
    BranchStack.warming.value = widget.page;
    await WidgetsBinding.instance.endOfFrame;
    if (BranchStack.warming.value == widget.page) BranchStack.warming.value = null;
  }

  void _close() {
    for (final ProviderSubscription<AsyncValue<Object?>> s in _subs) {
      s.close();
    }
    _subs.clear();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (TickerMode.valuesOf(context).enabled) _built = true;
    return _built ? widget.child : const SizedBox.expand();
  }
}
