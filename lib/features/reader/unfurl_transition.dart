import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';

/// The Page ⇄ Reader "unfurl" (R6), the app's hero motion, in three phases
/// with the anchor line held where it is:
///
/// - Lift, 0 to 140ms, decelerate: the page grows toward the screen edges
///   around the anchor and starts to let go.
/// - Unroll, 140 to 380ms, spring (overshoot 1.04): the reflowed text rolls
///   open from the anchor line outward, above and below at once.
/// - Set, 380 to 520ms, decelerate: the reader settles from the overshoot
///   while the page beneath finishes fading.
///
/// Reader to Page plays it backwards at 440ms. Under reduced motion it is a
/// 90ms cross-fade.
class UnfurlSwitcher extends StatefulWidget {
  const UnfurlSwitcher({
    required this.reader,
    required this.page,
    required this.readerChild,
    required this.anchorY,
    super.key,
  });

  /// Which side is showing.
  final bool reader;
  final Widget page;
  final Widget? readerChild;

  /// The anchor line's y in this widget, for the page and the reader alike.
  final double anchorY;

  @override
  State<UnfurlSwitcher> createState() => _UnfurlSwitcherState();
}

class _UnfurlSwitcherState extends State<UnfurlSwitcher> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: Motion.unfurl,
    reverseDuration: Motion.unfurlReverse,
    value: widget.reader ? 1 : 0,
  );

  // The two sides move between the resting tree and the animating Stack;
  // global keys carry their state (scroll position, zoom, layout) along.
  final GlobalKey _pageKey = GlobalKey(debugLabel: 'unfurl page');
  final GlobalKey _readerKey = GlobalKey(debugLabel: 'unfurl reader');

  Widget get _page => KeyedSubtree(key: _pageKey, child: widget.page);
  Widget? get _reader => widget.readerChild == null ? null : KeyedSubtree(key: _readerKey, child: widget.readerChild!);

  @override
  void didUpdateWidget(UnfurlSwitcher old) {
    super.didUpdateWidget(old);
    if (old.reader != widget.reader) {
      final bool reduced = Motion.reduced(context);
      _t.duration = reduced ? Motion.unfurlReduced : Motion.unfurl;
      _t.reverseDuration = reduced ? Motion.unfurlReduced : Motion.unfurlReverse;
      widget.reader ? _t.forward() : _t.reverse();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  static double _phase(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final bool reduced = Motion.reduced(context);
    return AnimatedBuilder(
      animation: _t,
      builder: (BuildContext context, Widget? _) {
        final double t = _t.value;
        final Widget page = _page;
        final Widget? reader = _reader;
        if (t <= 0) return page;
        if (t >= 1 && reader != null) return reader;
        if (reduced) {
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: Opacity(opacity: 1 - t, child: page),
              ),
              if (reader != null)
                Positioned.fill(
                  child: Opacity(opacity: t, child: reader),
                ),
            ],
          );
        }
        final double lift = Motion.decelerate.transform(_phase(t, 0, 140 / 520));
        final double unroll = Curves.easeOutBack.transform(_phase(t, 140 / 520, 380 / 520));
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double h = box.maxHeight;
            final double a = widget.anchorY.clamp(0, h);
            // The reveal opens from the anchor: up by `above`, down by `below`.
            final double above = a * math.min(1.04, unroll);
            final double below = (h - a) * math.min(1.04, unroll);
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Opacity(
                    opacity: (1 - _phase(t, 0.2, 0.75)).clamp(0, 1),
                    child: Transform(
                      alignment: Alignment(0, (a / h) * 2 - 1),
                      transform: Matrix4.diagonal3Values(1 + 0.07 * lift, 1 + 0.07 * lift, 1),
                      child: page,
                    ),
                  ),
                ),
                if (reader != null)
                  Positioned.fill(
                    child: ClipRect(
                      clipper: _Reveal(top: a - above, bottom: a + below),
                      // Opaque paper as it unrolls, so the two never show
                      // through each other; a brief fade as the roll starts.
                      child: Opacity(
                        opacity: _phase(t, 140 / 520, 200 / 520),
                        child: Transform.translate(offset: Offset(0, 6 * (1 - unroll.clamp(0, 1))), child: reader),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Reveal extends CustomClipper<Rect> {
  const _Reveal({required this.top, required this.bottom});

  final double top;
  final double bottom;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, top.clamp(0, size.height), size.width, bottom.clamp(0, size.height));

  @override
  bool shouldReclip(_Reveal old) => old.top != top || old.bottom != bottom;
}
