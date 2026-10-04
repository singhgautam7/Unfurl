import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';
import 'buttons.dart';

class NavDestination {
  const NavDestination(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Home · Library · Files · Notes · More (board 5, N1).
const List<NavDestination> kDestinations = <NavDestination>[
  NavDestination(AppIcons.home, 'Home'),
  NavDestination(AppIcons.library, 'Library'),
  NavDestination(AppIcons.folderOpen, 'Files'),
  NavDestination(AppIcons.notes, 'Notes'),
  NavDestination(AppIcons.more, 'More'),
];

/// Mull's floating pill at Unfurl's five-tab measurements (board 5, N1):
/// 6dp padding, 44dp items, 48dp inactive tabs, 2dp between them, the
/// selected tab a `primaryContainer` indicator with icon and label (10/14
/// padding, 6dp apart), `surface`, 1px outline and the one shadow. If the
/// pill would be wider than the screen minus 32dp (the largest font sizes),
/// the selected tab drops its label for a 64dp indicator; the label moves to
/// its content description and a long-press tooltip.
class NavPill extends StatelessWidget {
  const NavPill({required this.index, required this.onSelect, super.key});

  final int index;
  final ValueChanged<int> onSelect;

  static const double padding = 6, inactive = 48, gap = 2, iconSize = 24, iconGap = 6;
  static const double activeLeft = 10, activeRight = 14, iconOnlyWidth = 64;

  static TextStyle labelStyle(UnfurlColors c) => UnfurlType.titleSmall.copyWith(height: 1, color: c.onPrimaryContainer);

  /// The pill's width with [label] shown on the selected tab.
  static double widthWith(BuildContext context, String label) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: label, style: labelStyle(context.colors)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final double w = tp.width;
    tp.dispose();
    final int n = kDestinations.length;
    return padding * 2 + 2 + inactive * (n - 1) + gap * (n - 1) + activeLeft + iconSize + iconGap + w + activeRight;
  }

  /// Whether the selected tab can show its label at this width and font size.
  static bool labelFits(BuildContext context, String label) =>
      widthWith(context, label) <= MediaQuery.sizeOf(context).width - 32;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final bool labelled = labelFits(context, kDestinations[index].label);
    return Container(
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: gap,
        children: <Widget>[
          for (int i = 0; i < kDestinations.length; i++)
            _NavItem(destination: kDestinations[i], selected: i == index, labelled: labelled, onTap: () => onSelect(i)),
        ],
      ),
    );
  }
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
    final Duration d = Motion.of(context, Motion.navIndicator);
    final Curve curve = Motion.curveOf(context, Motion.spring);
    final bool showLabel = selected && labelled;
    const double side = (NavPill.inactive - NavPill.iconSize) / 2;
    const double iconOnly = (NavPill.iconOnlyWidth - NavPill.iconSize) / 2;
    final EdgeInsets pad = !selected
        ? const EdgeInsets.symmetric(horizontal: side)
        : showLabel
        ? const EdgeInsets.only(left: NavPill.activeLeft, right: NavPill.activeRight)
        : const EdgeInsets.symmetric(horizontal: iconOnly);

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
            child: AnimatedContainer(
              duration: d,
              curve: curve,
              height: 44,
              padding: pad,
              decoration: BoxDecoration(
                color: selected ? c.primaryContainer : c.primaryContainer.withValues(alpha: 0),
                borderRadius: Radii.fullR,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: selected ? c.onPrimaryContainer : c.iconMuted),
                    duration: d,
                    builder: (BuildContext context, Color? color, _) => AppIcon(destination.icon, color: color),
                  ),
                  AnimatedSize(
                    duration: d,
                    curve: curve,
                    alignment: Alignment.centerLeft,
                    child: showLabel
                        ? Padding(
                            padding: const EdgeInsets.only(left: NavPill.iconGap),
                            child: Text(destination.label, maxLines: 1, style: NavPill.labelStyle(c)),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
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
                onTap: () => onSelect(i),
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
                      Text(
                        kDestinations[i].label,
                        style: UnfurlType.label
                            .copyWith(color: i == index ? c.onSurface : c.onSurfaceVariant)
                            .weight(i == index ? 600 : 500),
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
