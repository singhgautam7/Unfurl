import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';

/// `CONTINUE READING` in `sectionHeader`, with an optional accent link on
/// the right ("Library", "Export").
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
            child: InkWell(
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
/// Continue reading hero.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({required this.child, this.padding = const EdgeInsets.all(Space.lg), this.hero = false, super.key});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: hero ? Radii.wordCardR : Radii.cardR,
        border: Border.all(color: c.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
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

/// A row in a [ListContainer]: optional icon, label (and a line under it),
/// its current value in mono on the right, and a chevron if it leads
/// somewhere. [trailing] replaces value and chevron (a switch).
class ListRow extends StatelessWidget {
  const ListRow({
    required this.label,
    this.icon,
    this.subtitle,
    this.value,
    this.onTap,
    this.trailing,
    this.danger = false,
    this.minHeight = 56,
    super.key,
  });

  final String label;
  final IconData? icon;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// "Clear recents": danger text in a normal row.
  final bool danger;

  /// 56; 60 on More.
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final Widget content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
        child: Row(
          spacing: icon != null ? Space.lg : Space.md,
          children: <Widget>[
            if (icon != null) AppIcon(icon!, color: c.icon),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: UnfurlType.titleMedium.copyWith(color: danger ? c.danger : c.onSurface)),
                  if (subtitle != null)
                    Text(subtitle!, style: UnfurlType.bodySmall.copyWith(color: c.onSurfaceVariant)),
                ],
              ),
            ),
            ?trailing,
            if (trailing == null && value != null)
              // Its own width, up to half the row: the label takes the rest,
              // so the value and chevron sit on the right edge.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width / 2),
                child: Text(
                  value!,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                ),
              ),
            if (trailing == null && onTap != null && !danger) AppIcon(AppIcons.chevronRight, color: c.iconMuted),
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
