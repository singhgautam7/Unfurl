// ignore_for_file: discarded_futures, unawaited_futures (spring futures are fire-and-forget)

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../core/motion/kit.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import '../formats/format_registry.dart';
import 'app_icon.dart';

/// Corner radius of a selected chip or segment (Kuber decision 26: unselected
/// is a full pill, selected a 12dp squircle).
const double kSelectedRadius = 12;

/// A filter chip (board 2): 40dp stadium, `surfaceContainerHigh`; selected,
/// `primaryContainer` with its count in a `surface` badge and 12dp corners
/// (the shape morphs on `fastCurve`; Subtle `subtleCurve`; Off snaps). A
/// toggle chip ("Include subfolders") is outlined on `surface` while off.
/// Every chip follows the rule, as Kuber's do.
class PillChip extends StatelessWidget {
  const PillChip({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.count,
    this.leading,
    this.toggle = false,
    super.key,
  });

  static const double minHeight = 40;

  final String label;
  final VoidCallback? onTap;
  final bool selected;

  /// Shown only while selected.
  final int? count;

  /// A colour dot or an icon before the label.
  final Widget? leading;
  final bool toggle;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final MotionLevel level = Motion.levelOf(context);
    final bool off = level == MotionLevel.off;
    final SpringCurve shape = Motion.spatialCurve(level, Motion.fastCurve);
    final Color fg = selected ? c.onPrimaryContainer : c.onSurface;
    final bool showCount = selected && count != null;
    final Color bg = selected
        ? c.primaryContainer
        : toggle
        ? c.surface
        : c.surfaceContainerHigh;
    final BorderSide side = toggle && !selected ? BorderSide(color: c.outline) : BorderSide.none;
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        kind: PressKind.chip,
        morphCorners: false,
        enabled: onTap != null,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: selected ? 1 : 0),
          duration: off ? Duration.zero : shape.settle,
          curve: shape.clamped,
          builder: (BuildContext context, double sq, Widget? child) => TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: bg),
            duration: off ? Motion.fxInstant : Motion.fxFast,
            curve: Motion.curveEffects,
            builder: (BuildContext context, Color? fill, Widget? child) {
              final ShapeBorder border = RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(minHeight / 2 + (kSelectedRadius - minHeight / 2) * sq),
                side: side,
              );
              return ConstrainedBox(
                constraints: const BoxConstraints(minHeight: minHeight),
                child: Material(
                  color: fill,
                  animationDuration: Duration.zero,
                  shape: border,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap == null
                        ? null
                        : () {
                            Haptics.tick();
                            onTap!();
                          },
                    child: child,
                  ),
                ),
              );
            },
            child: child,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: leading != null ? Space.md : Space.lg,
              right: showCount ? Space.sm : Space.lg,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: Space.sm,
              children: <Widget>[
                if (leading != null)
                  IconTheme.merge(
                    data: IconThemeData(color: fg, size: 18),
                    child: leading!,
                  ),
                AnimatedWeight(
                  label,
                  isActive: selected,
                  rest: 500,
                  active: 650,
                  style: UnfurlType.titleMedium.copyWith(color: fg),
                ),
                if (showCount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
                    decoration: BoxDecoration(color: c.surface, borderRadius: Radii.fullR),
                    child: Text('$count', style: UnfurlType.monoLabel.copyWith(fontSize: 12, color: fg)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of chips that scrolls sideways off the right edge, as on the boards.
class ChipRow extends StatelessWidget {
  const ChipRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: Space.screen),
    child: Row(spacing: Space.sm, children: children),
  );
}

/// The type chips of Library and every folder: All, then each family
/// present in the registry's order (none when only one is), then [trailing]
/// ("Other", "Include subfolders"). The selected chip carries how many files
/// are on screen; tapping it again goes back to All.
class FormatChips extends StatelessWidget {
  const FormatChips({
    required this.present,
    required this.selected,
    required this.onSelected,
    this.shown,
    this.allSelected,
    this.trailing = const <Widget>[],
    super.key,
  });

  final Set<FormatGroup> present;
  final FormatGroup? selected;
  final ValueChanged<FormatGroup?> onSelected;

  /// Files on screen; null while they are still loading.
  final int? shown;

  /// Overrides "nothing selected means All" (a trailing chip is selected).
  final bool? allSelected;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final bool all = allSelected ?? selected == null;
    return ChipRow(
      children: <Widget>[
        PillChip(label: 'All', selected: all, count: shown, onTap: () => onSelected(null)),
        for (final FormatGroup g in FormatGroup.values)
          if (present.contains(g))
            PillChip(
              label: g.label,
              selected: selected == g,
              count: shown,
              onTap: () => onSelected(selected == g ? null : g),
            ),
        ...trailing,
      ],
    );
  }
}

/// Single-select tab row in Kuber's button-group behaviour: separate 40dp
/// pills, 8dp apart; the selected one is `primary` with 12dp corners, the
/// others `surfaceContainerHigh` full pills, and the shape morphs on
/// selection (fx.fast). Expressive: the pressed pill widens 15% while its
/// neighbours squeeze, corners going to 8dp (springFast down, springDefault
/// up). Subtle: fill and weight only. Off: snaps. Page turn (Slide, Fade,
/// None), PDFs open in (Page, Reader). When a label won't fit its share of
/// the width (large system text) the options wrap onto more rows at their
/// own widths instead of being cut off.
class SegmentedToggle<T> extends StatefulWidget {
  const SegmentedToggle({required this.options, required this.selected, required this.onChanged, super.key});

  /// Value, label, optional icon.
  final List<(T, String, IconData?)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  State<SegmentedToggle<T>> createState() => _SegmentedToggleState<T>();
}

class _SegmentedToggleState<T> extends State<SegmentedToggle<T>> with SingleTickerProviderStateMixin {
  static const double _iconSize = 18;
  static const double _gap = 6;
  static const double _pillHeight = 40;
  static const double _pressedRadius = 8;

  final ValueNotifier<double> _v = ValueNotifier<double>(0);
  AnimationController? _c;
  int _pressed = -1; // stays set during the release so widths ease back
  bool _down = false;
  Offset? _downAt;

  AnimationController get _ctrl =>
      _c ??= AnimationController.unbounded(vsync: this)..addListener(() => _v.value = _c!.value);

  @override
  void dispose() {
    _c?.dispose();
    _v.dispose();
    super.dispose();
  }

  void _press(int i, PointerDownEvent e) {
    setState(() {
      _pressed = i;
      _down = true;
    });
    _downAt = e.position;
    if (Motion.levelOf(context) == MotionLevel.expressive) _ctrl.springTo(1, Motion.springFast);
  }

  void _release([PointerEvent? e]) {
    if (!_down) return;
    setState(() => _down = false);
    _downAt = null;
    if (Motion.levelOf(context) == MotionLevel.expressive) _ctrl.springTo(0, Motion.springDefault);
  }

  void _select(T v) {
    if (v == widget.selected) return;
    Haptics.tick();
    widget.onChanged(v);
  }

  TextStyle get _label => UnfurlType.titleMedium.copyWith(fontSize: 14);

  /// A segment's content at its own width: icon, gap, label (bold, the wider).
  double _contentWidth(BuildContext context, (T, String, IconData?) o) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: o.$2, style: Motion.weightStyle(_label, 700)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final double w = tp.width + (o.$3 == null ? 0 : _iconSize + _gap);
    tp.dispose();
    return w;
  }

  /// One pill, 40dp to the eye and 48dp to the finger.
  Widget _pill(BuildContext context, int i, {required bool fit}) {
    final UnfurlColors c = context.colors;
    final MotionLevel level = Motion.levelOf(context);
    final bool off = level == MotionLevel.off;
    final (T, String, IconData?) o = widget.options[i];
    final bool sel = o.$1 == widget.selected;
    final Color fill = sel ? c.primary : c.surfaceContainerHigh;
    final Color fg = sel ? c.onPrimary : c.onSurface;
    final double restR = sel ? kSelectedRadius : _pillHeight / 2;
    final Widget label = AnimatedWeight(
      o.$2,
      isActive: sel || (_down && _pressed == i),
      rest: 600,
      active: 700,
      textAlign: TextAlign.center,
      style: _label.copyWith(color: fg),
    );
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent e) => _press(i, e),
      onPointerMove: (PointerMoveEvent e) {
        final Offset? d = _downAt;
        if (d != null && (e.position - d).distance > kTouchSlop) _release();
      },
      onPointerUp: _release,
      onPointerCancel: _release,
      child: Semantics(
        button: true,
        selected: sel,
        inMutuallyExclusiveGroup: true,
        label: o.$2,
        onTap: () => _select(o.$1),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _select(o.$1),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: IconSpec.tapTarget, minWidth: IconSpec.tapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: (IconSpec.tapTarget - _pillHeight) / 2),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: restR),
                duration: off ? Duration.zero : Motion.fxFast,
                curve: Motion.curveEffects,
                builder: (BuildContext context, double rest, _) => AnimatedBuilder(
                  animation: _v,
                  builder: (BuildContext context, _) {
                    final double pr = level == MotionLevel.expressive && _pressed == i ? _v.value : 0;
                    final double r = (rest + (_pressedRadius - rest) * pr).clamp(0.0, 999.0);
                    return TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: fill),
                      duration: off ? Motion.fxInstant : Motion.fxFast,
                      curve: Motion.curveEffects,
                      builder: (BuildContext context, Color? color, _) => Material(
                        color: color,
                        animationDuration: Duration.zero,
                        borderRadius: BorderRadius.circular(r),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _select(o.$1),
                          child: SizedBox(
                            height: _pillHeight,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: fit ? Space.md : Space.lg),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                spacing: _gap,
                                children: <Widget>[
                                  if (o.$3 != null) AppIcon(o.$3!, size: _iconSize, color: fg),
                                  if (fit) Flexible(child: label) else label,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int n = widget.options.length;
    final bool expressive = Motion.levelOf(context) == MotionLevel.expressive;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double share = (box.maxWidth - Space.sm * (n - 1)) / n;
        final bool fits =
            box.maxWidth.isFinite &&
            widget.options.every(((T, String, IconData?) o) => _contentWidth(context, o) + Space.md * 2 <= share);
        if (!fits) {
          // Large text: each option at its own width, wrapping onto rows.
          return Wrap(spacing: Space.sm, children: <Widget>[for (int i = 0; i < n; i++) _pill(context, i, fit: false)]);
        }
        return AnimatedBuilder(
          animation: _v,
          builder: (BuildContext context, _) {
            // Pressed pill: 1 + .15v of its share; the rest split what is left.
            final double grow = expressive && _pressed >= 0 && n > 1 ? 1 + Motion.buttonGroupWiden * _v.value : 1;
            final double other = n > 1 ? (n - grow) / (n - 1) : 1;
            return Row(
              spacing: Space.sm,
              children: <Widget>[
                for (int i = 0; i < n; i++)
                  Flexible(
                    fit: FlexFit.tight,
                    flex: ((i == _pressed ? grow : other) * 1000).round().clamp(1, 1 << 30),
                    child: _pill(context, i, fit: true),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
