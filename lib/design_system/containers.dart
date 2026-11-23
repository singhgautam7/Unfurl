import 'package:flutter/material.dart';

import '../core/motion/kit.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';
import 'buttons.dart' show pressedLayer;

/// `CONTINUE READING` in `sectionHeader`, with an optional accent link on
/// the right ("Library", "Export"). The link is a 48dp target whose text
/// ends on the content's right edge; it scales on press (Kuber's "See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.label, this.action, this.onAction, this.accent = false, super.key});

  final String label;
  final String? action;
  final VoidCallback? onAction;

  /// The hero card's label sits in `accent`.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            label.toUpperCase(),
            style: UnfurlType.sectionHeader.copyWith(color: accent ? c.accent : c.onSurfaceVariant),
          ),
        ),
        if (action != null)
          Semantics(
            button: true,
            label: action,
            onTap: onAction,
            excludeSemantics: true,
            child: Pressable(
              kind: PressKind.chip,
              morphCorners: false,
              enabled: onAction != null,
              onTap: onAction,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: IconSpec.tapTarget, minWidth: IconSpec.tapTarget),
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: Text(action!, style: UnfurlType.monoLabel.copyWith(color: c.accent)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A card: `surfaceContainer`, 1px `outline`. Radius 20; 28 for the
/// Continue reading hero. With [onTap] or [onLongPress] it presses like a
/// card (scale, 10% state layer, no ink); [semanticLabel] makes it one node.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.hero = false,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool hero;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final BorderRadius radius = hero ? Radii.wordCardR : Radii.cardR;
    if (onTap == null && onLongPress == null) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: radius,
          border: Border.all(color: c.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }
    final Widget card = Pressable(
      kind: PressKind.card,
      child: Material(
        color: c.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: c.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashFactory: NoSplash.splashFactory,
          enableFeedback: onLongPress == null,
          overlayColor: pressedLayer(c),
          onTap: onTap,
          onLongPress: _longPress(onLongPress),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return semanticLabel == null
        ? card
        : Semantics(
            button: true,
            label: semanticLabel,
            onTap: onTap,
            onLongPress: onLongPress,
            excludeSemantics: true,
            child: card,
          );
  }
}

/// An InkWell long press with its haptic.
VoidCallback? _longPress(VoidCallback? f) => f == null
    ? null
    : () {
        Haptics.longPress();
        f();
      };

/// Press feel for a row that draws itself: scale, a 10% state layer, no ink,
/// one tick per tap. [semanticLabel] makes it one button node.
class PressableRow extends StatelessWidget {
  const PressableRow({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.borderRadius,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    if (onTap == null && onLongPress == null) return child;
    final Widget row = Pressable(
      kind: PressKind.row,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: borderRadius,
          splashFactory: NoSplash.splashFactory,
          enableFeedback: onLongPress == null,
          overlayColor: pressedLayer(context.colors),
          onTap: onTap,
          onLongPress: _longPress(onLongPress),
          child: child,
        ),
      ),
    );
    return semanticLabel == null
        ? row
        : Semantics(
            button: true,
            label: semanticLabel,
            onTap: onTap,
            onLongPress: onLongPress,
            excludeSemantics: true,
            child: row,
          );
  }
}

/// A list container: one card of rows with `divider` hairlines between them
/// (More, Settings, recent files).
class ListContainer extends StatelessWidget {
  const ListContainer({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[if (i > 0) Divider(color: c.divider), children[i]],
        ],
      ),
    );
  }
}

/// One row of a [ListContainer] built lazily (a `SliverList.builder`): each
/// row draws its own slice of the card, so long lists stay lazy. The border
/// is one colour (a rounded border can't mix colours); the divider between
/// rows is drawn inside.
class ListGroupRow extends StatelessWidget {
  const ListGroupRow({required this.first, required this.last, required this.child, super.key});

  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final BorderRadius radius = BorderRadius.vertical(
      top: first ? const Radius.circular(Radii.card) : Radius.zero,
      bottom: last ? const Radius.circular(Radii.card) : Radius.zero,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        border: Border(
          left: BorderSide(color: c.outline),
          right: BorderSide(color: c.outline),
          top: first ? BorderSide(color: c.outline) : BorderSide.none,
          bottom: last ? BorderSide(color: c.outline) : BorderSide.none,
        ),
        borderRadius: radius,
      ),
      // Only the ends have corners to clip; a clip on every row of a long list
      // costs raster time on every frame it scrolls.
      child: first || last ? ClipRRect(borderRadius: radius, child: _row(c)) : _row(c),
    );
  }

  Widget _row(UnfurlColors c) => last
      ? child
      : Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            child,
            Divider(height: 1, color: c.divider),
          ],
        );
}

/// A row in a [ListContainer]: an optional [icon] in a 40dp tile, the label
/// with a line under it ([subtitle]), its current value in mono on the right,
/// and a chevron if it leads somewhere. [trailing] replaces value and chevron.
/// [switchValue] with [onChanged] makes a switch row: the whole row toggles,
/// once, and reads as one toggle node. No ink: a 10% state layer and a press
/// scale.
class ListRow extends StatelessWidget {
  const ListRow({
    required this.label,
    this.icon,
    this.subtitle,
    this.value,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.switchValue,
    this.onChanged,
    this.selected = false,
    this.enabled = true,
    this.danger = false,
    this.minHeight,
    super.key,
  });

  final String label;
  final IconData? icon;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  /// A switch row: the switch's state, flipped through [onChanged].
  final bool? switchValue;
  final ValueChanged<bool>? onChanged;

  /// The row fills with `primaryContainer`.
  final bool selected;

  /// False: 38% and no press.
  final bool enabled;

  /// "Clear recents": danger text in a normal row.
  final bool danger;

  /// 56; 72 with an icon and a subtitle; 60 on More.
  final double? minHeight;

  static const double _inset = 4;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final bool isSwitch = switchValue != null;
    final VoidCallback? tap = !enabled
        ? null
        : isSwitch
        ? (onChanged == null ? null : () => onChanged!(!switchValue!))
        : onTap;
    final VoidCallback? hold = enabled ? onLongPress : null;
    final bool tappable = tap != null || hold != null;
    final double h = minHeight ?? (icon != null && subtitle != null ? 72 : 56);
    // At large text (1.5x and up, Kuber's threshold) the value goes under the
    // label, so neither is squeezed into a word per line.
    final bool hasTrail = trailing != null || isSwitch;
    final bool stacked = !hasTrail && value != null && MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final Color titleColor = selected ? c.onPrimaryContainer : (danger ? c.danger : c.onSurface);
    final Color subColor = selected ? c.onPrimaryContainer : c.onSurfaceVariant;
    final TextStyle valueStyle = UnfurlType.monoLabel.copyWith(color: subColor);
    final double inset = tappable ? _inset : 0;
    final Widget body = Padding(
      padding: EdgeInsets.symmetric(horizontal: Space.lg - inset, vertical: Space.sm - inset),
      child: Row(
        spacing: icon != null ? Space.lg : Space.md,
        children: <Widget>[
          if (icon != null)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: danger ? c.dangerContainer : c.surfaceContainerHigh,
                borderRadius: Radii.boxR,
              ),
              child: Center(child: AppIcon(icon!, size: 20, color: danger ? c.onDangerContainer : c.icon)),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: UnfurlType.titleMedium.copyWith(color: titleColor)),
                if (subtitle != null) Text(subtitle!, style: UnfurlType.bodySmall.copyWith(color: subColor)),
                if (stacked) Text(value!, style: valueStyle),
              ],
            ),
          ),
          if (isSwitch)
            // The row takes the tap; the switch only shows the state.
            ExcludeSemantics(
              child: IgnorePointer(
                child: Switch(value: switchValue!, onChanged: enabled ? (_) {} : null),
              ),
            ),
          ?trailing,
          if (!hasTrail && value != null && !stacked)
            // Its own width, up to half the row: the label takes the rest,
            // so the value and chevron sit on the right edge.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width / 2),
              child: Text(
                value!,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: valueStyle,
              ),
            ),
          if (!hasTrail && onTap != null && !danger) AppIcon(AppIcons.chevronRight, color: c.iconMuted),
        ],
      ),
    );
    Widget row = Container(
      constraints: BoxConstraints(minHeight: h),
      color: selected ? c.primaryContainer : null,
      padding: EdgeInsets.all(inset),
      child: PressableRow(
        borderRadius: BorderRadius.circular(Radii.card - _inset),
        onTap: tap,
        onLongPress: hold,
        child: body,
      ),
    );
    if (!enabled) row = Opacity(opacity: Opacities.disabled, child: row);
    if (isSwitch) {
      return Semantics(
        toggled: switchValue,
        enabled: enabled,
        label: <String>[label, ?subtitle].join(', '),
        onTap: tap,
        excludeSemantics: true,
        child: row,
      );
    }
    // A row with a control reads as one: its title, then the control.
    if (!tappable) return trailing != null ? MergeSemantics(child: row) : row;
    return Semantics(
      button: true,
      enabled: enabled,
      label: <String>[label, ?subtitle, ?value].join(', '),
      onTap: tap,
      onLongPress: hold,
      excludeSemantics: true,
      child: row,
    );
  }
}
