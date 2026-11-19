import 'package:flutter/material.dart';

import 'motion.dart';
import 'motion_level.dart';
import 'spring.dart';

/// A plain integer (no currency logic) with rolling digits.
///
/// - Expressive: each changed digit rolls 100 % up (value grew) or down in
///   300 ms on curve.effects, 20 ms apart from right to left; the width eases
///   on springStandard when the length changes; tabular figures. With
///   [animateIn] the digits roll in from the formatted zero on first build.
/// - Subtle: the whole text cross-fades in fx.fast. Off: it swaps.
/// - Settled, it is one plain [Text].
/// - [format] turns the value into the display string (grouping, units).
///
/// In the rolling state a too-wide number scales down (FittedBox) while it
/// animates.
class RollingNumber extends StatefulWidget {
  const RollingNumber({
    super.key,
    required this.value,
    required this.style,
    this.format,
    this.textAlign,
    this.animateIn = false,
  });

  final int value;
  final TextStyle? style;
  final String Function(int)? format;
  final TextAlign? textAlign;

  /// Roll in from zero on first appearance. False starts at [value] and only
  /// animates when it changes later.
  final bool animateIn;

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber> {
  late String _text; // what is shown (target of the current roll)
  String _from = '';
  bool _up = true;
  bool _rolling = false;
  int _gen = 0;
  bool _started = false;

  String _fmt(int v) => widget.format?.call(v) ?? '$v';

  Text _plain(String t) => Text(t, style: widget.style, textAlign: widget.textAlign);

  @override
  void initState() {
    super.initState();
    _text = _fmt(widget.value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animateIn && Motion.levelOf(context) == MotionLevel.expressive) {
      final String zero = _fmt(0);
      if (zero != _text) {
        _from = zero;
        _rolling = true;
        _up = widget.value >= 0;
      }
    }
  }

  @override
  void didUpdateWidget(RollingNumber old) {
    super.didUpdateWidget(old);
    final String next = _fmt(widget.value);
    if (next == _text) return;
    _from = _text;
    _text = next;
    _up = widget.value >= old.value;
    _rolling = Motion.levelOf(context) == MotionLevel.expressive;
    _gen++;
  }

  @override
  Widget build(BuildContext context) {
    final MotionLevel level = Motion.levelOf(context);
    if (level == MotionLevel.expressive && _rolling) {
      final TextStyle base = (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );
      final Alignment align = switch (widget.textAlign) {
        TextAlign.right || TextAlign.end => Alignment.centerRight,
        TextAlign.center => Alignment.center,
        _ => Alignment.centerLeft,
      };
      return RepaintBoundary(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align,
          child: RollingText(
            key: ValueKey<int>(_gen),
            from: _from,
            to: _text,
            up: _up,
            style: base,
            onDone: () {
              if (mounted) setState(() => _rolling = false);
            },
          ),
        ),
      );
    }
    if (level == MotionLevel.subtle) {
      return AnimatedSwitcher(
        duration: Motion.fxFast,
        switchInCurve: Motion.curveEffects,
        switchOutCurve: Motion.curveEffects,
        layoutBuilder: (Widget? cur, List<Widget> prev) =>
            Stack(alignment: AlignmentDirectional.centerStart, children: <Widget>[...prev, ?cur]),
        child: KeyedSubtree(key: ValueKey<String>(_text), child: _plain(_text)),
      );
    }
    return _plain(_text);
  }
}

/// Rolls [from] into [to]: aligned from the right, each changed character
/// slides out (up if [up]) while the new one slides in, 300 ms on
/// curve.effects, 20 ms apart right to left. Lengths differ: the extra
/// characters grow or shrink in width on springStandard. Calls [onDone] when
/// everything has settled. Use through [RollingNumber].
class RollingText extends StatefulWidget {
  const RollingText({
    super.key,
    required this.from,
    required this.to,
    required this.up,
    required this.style,
    this.onDone,
  });

  final String from, to;
  final bool up;
  final TextStyle style;
  final VoidCallback? onDone;

  @override
  State<RollingText> createState() => _RollingTextState();
}

class _RollingTextState extends State<RollingText> with TickerProviderStateMixin {
  late final AnimationController _roll;
  late final AnimationController _w = AnimationController.unbounded(vsync: this);
  late final List<(String?, String?)> _pairs; // left to right
  late final bool _widthChanges;
  bool _measured = false;
  List<double> _w0 = const [], _w1 = const [];

  @override
  void initState() {
    super.initState();
    final a = widget.from.characters.toList();
    final b = widget.to.characters.toList();
    final n = a.length > b.length ? a.length : b.length;
    final pairs = <(String?, String?)>[];
    var changed = 0;
    for (var j = n - 1; j >= 0; j--) {
      final o = j < a.length ? a[a.length - 1 - j] : null;
      final c = j < b.length ? b[b.length - 1 - j] : null;
      pairs.add((o, c));
      if (o != c) changed++;
    }
    _pairs = pairs;
    _widthChanges = a.length != b.length;
    final total = Motion.digitRoll + Motion.digitStep * (changed > 0 ? changed - 1 : 0);
    _roll = AnimationController(vsync: this, duration: total);
    _roll.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_w.isAnimating) widget.onDone?.call();
    });
    _w.value = 0;
    _roll.forward();
    if (_widthChanges) {
      _w.springTo(1, Motion.springStandard).whenCompleteOrCancel(() {
        if (_roll.isCompleted) widget.onDone?.call();
      });
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    _w.dispose();
    super.dispose();
  }

  double _measure(String? ch) {
    if (ch == null) return 0;
    final p = TextPainter(
      text: TextSpan(text: ch, style: widget.style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    if (!_measured) {
      _measured = true;
      _w0 = [for (final p in _pairs) _measure(p.$1)];
      _w1 = [for (final p in _pairs) _measure(p.$2)];
    }
    final total = _roll.duration!.inMicroseconds;
    return AnimatedBuilder(
      animation: Listenable.merge([_roll, _w]),
      builder: (context, _) {
        final children = <Widget>[];
        var rank = 0; // changed chars counted from the right
        final ranks = List<int>.filled(_pairs.length, 0);
        for (var i = _pairs.length - 1; i >= 0; i--) {
          if (_pairs[i].$1 != _pairs[i].$2) ranks[i] = rank++;
        }
        for (var i = 0; i < _pairs.length; i++) {
          final (o, c) = _pairs[i];
          final delay = Motion.digitStep.inMicroseconds * ranks[i];
          final r = Motion.curveEffects.transform(
            ((_roll.value * total - delay) / Motion.digitRoll.inMicroseconds).clamp(0.0, 1.0),
          );
          final width = o == c ? _w1[i] : _w0[i] + (_w1[i] - _w0[i]) * _w.value.clamp(0.0, 1.0);
          children.add(_Slot(width: width, from: o, to: c, t: r, up: widget.up, style: widget.style));
        }
        return Row(mainAxisSize: MainAxisSize.min, children: children);
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.width,
    required this.from,
    required this.to,
    required this.t,
    required this.up,
    required this.style,
  });

  final double width;
  final String? from, to;
  final double t;
  final bool up;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (from == to) return Text(to ?? '', style: style);
    final dir = up ? 1.0 : -1.0;
    // Size follows the taller of the two; each glyph moves +-100 % of it.
    return SizedBox(
      width: width,
      child: ClipRect(
        child: Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [
            // Reserves the line height.
            Opacity(opacity: 0, child: Text(to ?? from ?? '', style: style)),
            if (from != null)
              Positioned.fill(
                child: FractionalTranslation(
                  translation: Offset(0, -dir * t),
                  child: Opacity(
                    opacity: 1 - t,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(from!, style: style, softWrap: false),
                    ),
                  ),
                ),
              ),
            if (to != null)
              Positioned.fill(
                child: FractionalTranslation(
                  translation: Offset(0, dir * (1 - t)),
                  child: Opacity(
                    opacity: t,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(to!, style: style, softWrap: false),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
