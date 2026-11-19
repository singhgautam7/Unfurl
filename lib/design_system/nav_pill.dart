// ignore_for_file: discarded_futures, unawaited_futures (spring futures are fire-and-forget)

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../core/explorer.dart' show kAllFilesAccess;
import '../core/motion/kit.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';
import 'buttons.dart';

class NavDestination {
  const NavDestination(this.icon, this.label, this.branch);

  final IconData icon;
  final String label;

  /// The shell branch it opens (branches stay put when a tab is hidden).
  final int branch;
}

/// Home · Library · Files · Notes · More (board 5, N1). Files is hidden while
/// all-files access is off ([kAllFilesAccess]).
const List<NavDestination> kDestinations = <NavDestination>[
  NavDestination(AppIcons.home, 'Home', 0),
  NavDestination(AppIcons.library, 'Library', 1),
  if (kAllFilesAccess) NavDestination(AppIcons.folderOpen, 'Files', 2),
  NavDestination(AppIcons.notes, 'Notes', 3),
  NavDestination(AppIcons.more, 'More', 4),
];

/// The tab showing [branch], or Home's for a hidden one.
int tabOfBranch(int branch) => math.max(0, kDestinations.indexWhere((NavDestination d) => d.branch == branch));

/// Mull's floating pill at Unfurl's five-tab measurements (board 5, N1):
/// 6dp padding, 44dp items, 48dp inactive tabs, 2dp between them, the
/// selected tab a `primaryContainer` indicator with icon and label (10/14
/// padding, 6dp apart), `surface`, 1px outline and the one shadow. If the
/// pill would be wider than the screen minus 32dp (the largest font sizes),
/// the selected tab drops its label for a 64dp indicator; the label moves to
/// its content description and a long-press tooltip.
///
/// One indicator slides behind the items (Kuber's `NavIndicator`): its two
/// edges follow springs, the leading one fast, so it stretches in flight.
class NavPill extends StatelessWidget {
  const NavPill({required this.index, required this.onSelect, super.key});

  final int index;
  final ValueChanged<int> onSelect;

  static const double padding = 6, inactive = 48, gap = 2, iconSize = 24, iconGap = 6;
  static const double activeLeft = 10, activeRight = 14, iconOnlyWidth = 64;

  /// The selected label's weight range: AnimatedWeight reserves the heavier.
  static const double weightRest = 500, weightActive = 700;

  static TextStyle labelStyle(UnfurlColors c) => UnfurlType.titleSmall.copyWith(height: 1, color: c.onPrimaryContainer);

  /// Width of [label] at the selected (heavier) weight, which is what the
  /// label slot reserves.
  static double _labelWidth(BuildContext context, String label) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: label, style: Motion.weightStyle(labelStyle(context.colors), weightActive)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final double w = tp.width;
    tp.dispose();
    return w;
  }

  /// The pill's width with [label] shown on the selected tab.
  static double widthWith(BuildContext context, String label) {
    final int n = kDestinations.length;
    return padding * 2 +
        2 +
        inactive * (n - 1) +
        gap * (n - 1) +
        activeLeft +
        iconSize +
        iconGap +
        _labelWidth(context, label) +
        activeRight;
  }

  /// Whether the selected tab can show its label at this width and font size.
  static bool labelFits(BuildContext context, String label) =>
      widthWith(context, label) <= MediaQuery.sizeOf(context).width - 32;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final String label = kDestinations[index].label;
    final bool labelled = labelFits(context, label);
    // The indicator's edges around tab [index] at rest, in the row's own
    // coordinates (the pill's border and padding are outside it).
    final double left = index * (inactive + gap);
    final double right =
        left + (labelled ? activeLeft + iconSize + iconGap + _labelWidth(context, label) + activeRight : iconOnlyWidth);
    return RepaintBoundary(
      child: Container(
        // The vertical padding belongs to the tabs, so each is 56dp tall to the
        // finger (48dp minimum) while its indicator stays 44.
        padding: const EdgeInsets.symmetric(horizontal: padding),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: Radii.fullR,
          border: Border.all(color: c.outline),
          boxShadow: <BoxShadow>[
            BoxShadow(color: c.shadow, blurRadius: Elevations.navPillBlur, offset: const Offset(0, Elevations.navPill)),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              top: padding,
              bottom: padding,
              child: NavIndicator(left: left, right: right, color: c.primaryContainer, destination: index),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: gap,
              children: <Widget>[
                for (int i = 0; i < kDestinations.length; i++)
                  _NavItem(
                    destination: kDestinations[i],
                    selected: i == index,
                    labelled: labelled,
                    onTap: () {
                      if (i != index) Haptics.tick();
                      onSelect(i);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The selection pill behind the nav items. Moving: the edge on the side it
/// moves toward (leading) follows springFast, the other (trailing)
/// springDefault, so it stretches mid-way (up to about 1.3x). Subtle: both
/// edges on springSubtle. Off: the old pill cross-fades into the new one.
/// Nothing runs at rest: each ticker stops when its spring settles.
class NavIndicator extends StatefulWidget {
  const NavIndicator({
    required this.left,
    required this.right,
    required this.color,
    required this.destination,
    super.key,
  });

  final double left;
  final double right;
  final Color color;

  /// Which destination it sits on (keys the Off cross-fade).
  final int destination;

  @override
  State<NavIndicator> createState() => _NavIndicatorState();
}

class _NavIndicatorState extends State<NavIndicator> with TickerProviderStateMixin {
  late final AnimationController _l = AnimationController.unbounded(vsync: this, value: widget.left);
  late final AnimationController _r = AnimationController.unbounded(vsync: this, value: widget.right);

  @override
  void didUpdateWidget(NavIndicator old) {
    super.didUpdateWidget(old);
    if (old.left == widget.left && old.right == widget.right) return;
    final MotionLevel level = Motion.levelOf(context);
    if (level == MotionLevel.off) {
      _l.value = widget.left;
      _r.value = widget.right;
      return;
    }
    final bool movingRight = widget.left > old.left;
    final SpringDescription fast = Motion.spatial(level, Motion.springFast);
    final SpringDescription slow = Motion.spatial(level, Motion.springDefault);
    _l.springTo(widget.left, movingRight ? slow : fast);
    _r.springTo(widget.right, movingRight ? fast : slow);
  }

  @override
  void dispose() {
    _l.dispose();
    _r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.levelOf(context) == MotionLevel.off) {
      return AnimatedSwitcher(
        duration: Motion.fxInstant,
        child: SizedBox.expand(
          key: ValueKey<int>(widget.destination),
          child: CustomPaint(
            painter: _IndicatorPainter(
              ValueNotifier<double>(widget.left),
              ValueNotifier<double>(widget.right),
              widget.color,
            ),
          ),
        ),
      );
    }
    return RepaintBoundary(child: CustomPaint(painter: _IndicatorPainter(_l, _r, widget.color)));
  }
}

class _IndicatorPainter extends CustomPainter {
  _IndicatorPainter(this.l, this.r, this.color) : super(repaint: Listenable.merge(<Listenable>[l, r]));

  final ValueListenable<double> l;
  final ValueListenable<double> r;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double left = l.value, right = r.value;
    if (right <= left) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(left, 0, right, size.height), Radius.circular(size.height / 2)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_IndicatorPainter o) => o.color != color || o.l != l || o.r != r;
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.selected, required this.labelled, required this.onTap});

  final NavDestination destination;
  final bool selected;

  /// The selected tab shows its label (false only at the largest fonts).
  final bool labelled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final MotionLevel level = Motion.levelOf(context);
    final bool off = level == MotionLevel.off;
    final SpringCurve curve = Motion.spatialCurve(level, Motion.defaultCurve);
    final bool showLabel = selected && labelled;
    const double side = (NavPill.inactive - NavPill.iconSize) / 2;
    const double iconOnly = (NavPill.iconOnlyWidth - NavPill.iconSize) / 2;
    final double activeL = labelled ? NavPill.activeLeft : iconOnly;
    final double activeR = labelled ? NavPill.activeRight : iconOnly;

    Widget item = Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: NavPill.padding),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: SizedBox(
              height: 44,
              // Label width 0 to its own on springDefault (clamped: never
              // negative); the padding and icon grow with it.
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: selected ? 1 : 0),
                duration: off ? Duration.zero : curve.clamped.settle,
                curve: curve.clamped,
                builder: (BuildContext context, double t, _) => TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: selected ? c.onPrimaryContainer : c.iconMuted),
                  duration: off ? Duration.zero : Motion.fxFast,
                  curve: Motion.curveEffects,
                  builder: (BuildContext context, Color? color, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(width: side + (activeL - side) * t),
                      AppIcon(destination.icon, color: color),
                      if (labelled && (showLabel || t > 0.001))
                        ClipRect(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: t,
                            child: Opacity(
                              opacity: t,
                              child: Padding(
                                padding: const EdgeInsets.only(left: NavPill.iconGap),
                                child: AnimatedWeight(
                                  destination.label,
                                  isActive: selected,
                                  rest: NavPill.weightRest,
                                  active: NavPill.weightActive,
                                  style: NavPill.labelStyle(c).copyWith(color: color),
                                ),
                              ),
                            ),
                          ),
                        ),
                      SizedBox(width: side + (activeR - side) * t),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Without a visible label the selected tab names itself on long-press.
    if (selected && !labelled) item = AppTooltip(message: destination.label, child: item);
    return item;
  }
}

/// Board 6, V7: the nav rail on expanded widths (≥840dp). The same five tabs
/// and icons; the selected one in a 56 × 32 `primaryContainer` indicator,
/// labels below. 80dp wide on the left, a hairline on its right.
class NavRail extends StatelessWidget {
  const NavRail({required this.index, required this.onSelect, super.key});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.divider)),
      ),
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + Space.xl),
      child: Column(
        spacing: Space.lg,
        children: <Widget>[
          for (int i = 0; i < kDestinations.length; i++)
            Semantics(
              button: true,
              selected: i == index,
              label: kDestinations[i].label,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (i != index) Haptics.tick();
                  onSelect(i);
                },
                child: SizedBox(
                  width: 80,
                  child: Column(
                    spacing: Space.xs,
                    children: <Widget>[
                      AnimatedContainer(
                        duration: Motion.of(context, Motion.navIndicator),
                        curve: Motion.curveOf(context, Motion.spring),
                        width: 56,
                        height: 32,
                        decoration: BoxDecoration(
                          color: i == index ? c.primaryContainer : c.primaryContainer.withValues(alpha: 0),
                          borderRadius: Radii.fullR,
                        ),
                        child: AppIcon(
                          kDestinations[i].icon,
                          fill: i == index,
                          color: i == index ? c.onPrimaryContainer : c.iconMuted,
                        ),
                      ),
                      AnimatedWeight(
                        kDestinations[i].label,
                        isActive: i == index,
                        rest: 500,
                        active: 600,
                        style: UnfurlType.label.copyWith(color: i == index ? c.onSurface : c.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
