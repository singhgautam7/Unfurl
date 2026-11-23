import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/motion/kit.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';

/// One row of [showAppMenu], or, with [AppMenuEntry.divider], the rule
/// between groups. Every row has an icon.
class AppMenuEntry<T> {
  const AppMenuEntry({
    required this.value,
    required this.label,
    required IconData this.icon,
    this.subtitle,
    this.selected = false,
    this.switchValue,
    this.accentIcon = false,
    this.danger = false,
    this.enabled = true,
  }) : divider = false;

  const AppMenuEntry.divider()
    : value = null,
      label = '',
      icon = null,
      subtitle = null,
      selected = false,
      switchValue = null,
      accentIcon = false,
      danger = false,
      enabled = true,
      divider = true;

  final T? value;
  final String label;
  final IconData? icon;

  /// A `monoLabel` line under the label ("read-only access").
  final String? subtitle;

  /// The current sort or view: a `primaryContainer` pill.
  final bool selected;
  final bool divider;

  /// A trailing switch showing this setting's state (tapping the row flips it).
  final bool? switchValue;

  /// The icon filled and in `accent` (a pinned folder's star).
  final bool accentIcon;

  /// A destructive action ("Delete highlight"), in `danger`.
  final bool danger;

  /// A disabled row stays visible, muted and inert; its [subtitle] can say why.
  final bool enabled;
}

/// Every overflow and context menu is this wide (the owner's call), but never
/// wider than the screen less 8 dp each side.
const double _menuWidth = 280;

/// The overflow menu: one panel (`surfaceContainer`, card radius, 1 dp
/// outline, no shadow) on its own route, opened below the anchor or above it
/// when there is no room, scrolling when taller than the screen. Pass
/// [anchorContext] for a menu off a button, or [at] for a point (a tap on a
/// highlight).
///
/// Not `showMenu`: that fades every row in by itself (one offscreen layer per
/// row per frame). Here one panel fades, and at Expressive drops 8 dp.
Future<T?> showAppMenu<T>({
  required BuildContext context,
  required List<AppMenuEntry<T>> entries,
  BuildContext? anchorContext,
  Offset? at,
}) {
  assert(anchorContext != null || at != null, 'Anchor a menu to a widget or a point');
  final NavigatorState nav = Navigator.of(context, rootNavigator: true);
  final RenderBox overlay = nav.overlay!.context.findRenderObject()! as RenderBox;
  final RenderObject? box = anchorContext?.findRenderObject();
  final Rect anchor = box is RenderBox
      ? Rect.fromPoints(
          box.localToGlobal(Offset.zero, ancestor: overlay),
          box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
        )
      : overlay.globalToLocal(at ?? Offset.zero) & Size.zero;
  return nav.push(
    _AppMenuRoute<T>(
      entries: entries,
      anchor: anchor,
      level: Motion.levelOf(context),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      themes: InheritedTheme.capture(from: context, to: nav.context),
    ),
  );
}

class _AppMenuRoute<T> extends PopupRoute<T> {
  _AppMenuRoute({
    required this.entries,
    required this.anchor,
    required this.level,
    required this.barrierLabel,
    required this.themes,
  });

  final List<AppMenuEntry<T>> entries;
  final Rect anchor;
  final MotionLevel level;
  final CapturedThemes themes;

  @override
  final String barrierLabel;
  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => true;
  @override
  Duration get transitionDuration => level == MotionLevel.off ? Motion.fxInstant : Motion.fxFast;
  @override
  Duration get reverseTransitionDuration => Motion.fxInstant;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondary) {
    final UnfurlColors c = context.colors;
    return CustomSingleChildLayout(
      delegate: _MenuLayout(anchor, MediaQuery.paddingOf(context)),
      child: themes.wrap(
        Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: MaterialLocalizations.of(context).popupMenuLabel,
          child: RepaintBoundary(
            child: Material(
              color: c.surfaceContainer,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: Radii.cardR,
                side: BorderSide(color: c.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Space.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final AppMenuEntry<T> e in entries)
                      if (e.divider)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                          child: Divider(color: c.divider, height: 1),
                        )
                      else
                        _MenuRow<T>(entry: e, onTap: e.enabled ? () => Navigator.of(context).pop(e.value) : null),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
    Widget child,
  ) {
    final Widget faded = FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Motion.curveEffects, reverseCurve: Curves.linear),
      child: child,
    );
    if (level != MotionLevel.expressive) return faded;
    return AnimatedBuilder(
      animation: animation,
      child: faded,
      // A short drop, no scale: scaled text is re-rasterised every frame.
      builder: (BuildContext _, Widget? child) => Transform.translate(
        offset: Offset(0, -Space.sm * (1 - Motion.decelerate.transform(animation.value))),
        child: child,
      ),
    );
  }
}

/// Below [anchor], or above when it does not fit below; clamped to the safe
/// area. Aligned to whichever edge of the anchor is nearer its screen edge.
class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout(this.anchor, this.safe);

  final Rect anchor;
  final EdgeInsets safe;

  static const double _edge = Space.sm;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final Size room = constraints.biggest;
    final double w = math.min(_menuWidth, math.max(0, room.width - safe.horizontal - 2 * _edge));
    return BoxConstraints(minWidth: w, maxWidth: w, maxHeight: math.max(0, room.height - safe.vertical - 2 * _edge));
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    final double minY = safe.top + _edge;
    final double maxY = math.max(minY, size.height - safe.bottom - _edge - child.height);
    final double minX = safe.left + _edge;
    final double maxX = math.max(minX, size.width - safe.right - _edge - child.width);
    final double below = anchor.bottom + Space.xs;
    final double above = anchor.top - Space.xs - child.height;
    final double y = below > maxY && above >= minY ? above : below;
    final double x = anchor.center.dx > size.width / 2 && !anchor.isEmpty ? anchor.right - child.width : anchor.left;
    return Offset(x.clamp(minX, maxX), y.clamp(minY, maxY));
  }

  @override
  bool shouldRelayout(_MenuLayout old) => anchor != old.anchor || safe != old.safe;
}

/// One row: min 48, 12 dp corners, icon 20, gap 12, label and an optional
/// subtitle. Selected: `primaryContainer` fill, 600 weight, trailing check.
/// Press is a 10% state layer, no splash. A null [onTap] is a disabled row.
class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({required this.entry, required this.onTap});

  final AppMenuEntry<T> entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final bool on = onTap != null;
    final Color fg = !on
        ? c.onSurfaceMuted
        : entry.danger
        ? c.danger
        : (entry.selected ? c.onPrimaryContainer : c.onSurface);
    final Color iconColor = !on
        ? c.onSurfaceMuted
        : entry.accentIcon
        ? c.accent
        : (entry.selected || entry.danger ? fg : c.icon);
    final String? sub = entry.subtitle;
    return Semantics(
      button: true,
      enabled: on,
      selected: entry.selected,
      toggled: entry.switchValue,
      label: sub == null ? entry.label : '${entry.label}, $sub',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: entry.selected ? c.primaryContainer : Colors.transparent,
        borderRadius: Radii.boxR,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          overlayColor: WidgetStateProperty.resolveWith(
            (Set<WidgetState> s) => s.contains(WidgetState.pressed) ? fg.withValues(alpha: 0.1) : Colors.transparent,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: IconSpec.tapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Row(
                spacing: Space.md,
                children: <Widget>[
                  AppIcon(entry.icon!, size: 20, fill: entry.accentIcon, color: iconColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.sm),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            entry.label,
                            style: UnfurlType.titleMedium
                                .copyWith(fontSize: 14, color: fg)
                                .weight(entry.selected ? 600 : 500),
                          ),
                          if (sub != null)
                            Text(
                              sub,
                              style: UnfurlType.bodySmall.copyWith(color: on ? c.onSurfaceVariant : c.onSurfaceMuted),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (entry.switchValue != null)
                    IgnorePointer(
                      child: Switch(value: entry.switchValue!, onChanged: (_) {}),
                    ),
                  if (entry.selected) AppIcon(AppIcons.check, size: 20, color: c.onPrimaryContainer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
