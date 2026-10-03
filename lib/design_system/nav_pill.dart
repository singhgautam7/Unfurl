import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';

class NavDestination {
  const NavDestination(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Home · Library · Notes · More (board 2).
const List<NavDestination> kDestinations = <NavDestination>[
  NavDestination(AppIcons.home, 'Home'),
  NavDestination(AppIcons.library, 'Library'),
  NavDestination(AppIcons.notes, 'Notes'),
  NavDestination(AppIcons.more, 'More'),
];

/// Mull's floating pill at Unfurl's measurements: 6dp padding, 44dp items,
/// radius full, `surface`, 1px outline and the one shadow. Only the selected
/// destination shows its label, inside a `primaryContainer` indicator that
/// grows into icon plus label on `navIndicator`, springing.
class NavPill extends StatelessWidget {
  const NavPill({required this.index, required this.onSelect, super.key});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      padding: const EdgeInsets.all(6),
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
        spacing: Space.xs,
        children: <Widget>[
          for (int i = 0; i < kDestinations.length; i++)
            _NavItem(destination: kDestinations[i], selected: i == index, onTap: () => onSelect(i)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.selected, required this.onTap});

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  /// An unselected item is 60 wide: the 24dp glyph with 18 either side.
  static const double _inset = 18;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final Duration d = Motion.of(context, Motion.navIndicator);
    final Curve curve = Motion.curveOf(context, Motion.spring);
    // Under a large OS text scale the label drops and the glyph stays.
    final bool showLabel = selected && MediaQuery.textScalerOf(context).scale(13.5) <= 20;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: d,
          curve: curve,
          height: 44,
          padding: EdgeInsets.only(left: showLabel ? 14 : _inset, right: _inset),
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
                        padding: const EdgeInsets.only(left: Space.sm),
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          style: UnfurlType.titleSmall.copyWith(height: 1, color: c.onPrimaryContainer),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
