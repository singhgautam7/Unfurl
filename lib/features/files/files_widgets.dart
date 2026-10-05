import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/buttons.dart';
import '../../design_system/covers.dart' show DashedOutline, FormatBadge;

/// Board 5's components for the Files tab: rows, the privacy card, quick
/// access cards, skeletons, the loading row and the picker bar.

/// How a row's 40dp leading tile is drawn.
enum TileKind {
  /// A bare 28dp-wide glyph (folders, history).
  plain,

  /// `surfaceContainerHigh` square (documents).
  box,

  /// `primaryContainer` square (PDF and EPUB).
  accent,

  /// Dashed outline, muted glyph (files Unfurl can't open).
  muted,
}

class RowTile extends StatelessWidget {
  const RowTile({required this.icon, this.kind = TileKind.box, this.size = 40, super.key});

  final IconData icon;
  final TileKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final double radius = size >= 48 ? 14 : 12;
    final Color glyph = switch (kind) {
      TileKind.muted => c.onSurfaceMuted,
      TileKind.accent => c.onPrimaryContainer,
      _ => c.icon,
    };
    final Widget icon = AppIcon(this.icon, size: size >= 48 ? 24 : 22, color: glyph);
    return switch (kind) {
      TileKind.plain => SizedBox(
        width: 28,
        height: size,
        child: Center(child: icon),
      ),
      TileKind.muted => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: DashedOutline(color: c.outline, radius: radius),
          child: Center(child: icon),
        ),
      ),
      _ => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: kind == TileKind.accent ? c.primaryContainer : c.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Center(child: icon),
      ),
    };
  }
}

/// A row in a Files list (60dp): tile, name, meta, then an optional usage
/// bar, status, switch or trailing icon.
class ExplorerRow extends StatelessWidget {
  const ExplorerRow({
    required this.name,
    this.icon,
    this.tile = TileKind.box,
    this.meta,
    this.sansMeta = false,
    this.muted = false,
    this.accent = false,
    this.usage,
    this.status,
    this.statusOn = false,
    this.switchValue,
    this.onSwitch,
    this.badge,
    this.trailing,
    this.trailingAccent = false,
    this.trailingFilled = false,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.minHeight = 60,
    super.key,
  });

  /// 60 for Files rows; 48 or 56 in v3 sheets (board 6 `rows`).
  final double minHeight;

  final String name;
  final IconData? icon;
  final TileKind tile;
  final String? meta;

  /// Meta in the body sans (settings rows) instead of mono.
  final bool sansMeta;
  final bool muted;

  /// Name in `accent` ("Add folder").
  final bool accent;

  /// 0..1 used; turns danger above 85%.
  final double? usage;
  final String? status;
  final bool statusOn;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;

  /// The real extension, trailing (board 6, V3 badges).
  final String? badge;
  final IconData? trailing;
  final bool trailingAccent;
  final bool trailingFilled;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final Widget body = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, 10, Space.md, 10),
        child: Row(
          spacing: 14,
          children: <Widget>[
            if (icon != null) RowTile(icon: icon!, kind: tile),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UnfurlType.titleMedium
                        .copyWith(color: accent ? c.accent : (muted ? c.onSurfaceMuted : c.onSurface))
                        .weight(muted ? 500 : 600),
                  ),
                  if (meta != null)
                    Text(
                      meta!,
                      maxLines: sansMeta ? 3 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: (sansMeta ? UnfurlType.bodySmall : UnfurlType.monoLabel.copyWith(height: 1.5)).copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  if (usage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          height: 4,
                          width: double.infinity,
                          child: Stack(
                            children: <Widget>[
                              Positioned.fill(child: ColoredBox(color: c.surfaceContainerHigh)),
                              FractionallySizedBox(
                                heightFactor: 1,
                                widthFactor: usage!.clamp(0, 1),
                                child: ColoredBox(color: usage! > 0.85 ? c.danger : c.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (badge != null) FormatBadge(badge!),
            if (status != null)
              Text(
                status!,
                style: UnfurlType.monoLabel.copyWith(color: statusOn ? c.accent : c.onSurfaceVariant).weight(600),
              ),
            if (switchValue != null) Switch(value: switchValue!, onChanged: onSwitch),
            if (trailing != null)
              SizedBox.square(
                dimension: IconSpec.tapTarget,
                child: Center(
                  child: AppIcon(trailing!, fill: trailingFilled, color: trailingAccent ? c.accent : c.iconMuted),
                ),
              ),
          ],
        ),
      ),
    );
    // A switch row reads as one control: the name, then the switch's state.
    if (onTap == null && onLongPress == null) return switchValue != null ? MergeSemantics(child: body) : body;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(onTap: onTap, onLongPress: onLongPress, child: body),
    );
  }
}

/// Rows in one rounded container, divided.
class RowGroup extends StatelessWidget {
  const RowGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.cardR,
        border: Border.all(color: c.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: c.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// "Browse every file on your phone." The Files root without all-files
/// access; [eyebrow] marks "ACCESS IS STILL OFF" / "ACCESS WAS TURNED OFF".
class PrivacyCard extends StatelessWidget {
  const PrivacyCard({required this.onAllow, required this.onNotNow, this.eyebrow, super.key});

  final VoidCallback onAllow;
  final VoidCallback onNotNow;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.cardR,
        border: Border.all(color: c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: <Widget>[
          if (eyebrow != null)
            Row(
              spacing: 6,
              children: <Widget>[
                AppIcon(AppIcons.block, size: 16, color: c.accent),
                Flexible(
                  child: Text(eyebrow!, style: UnfurlType.sectionHeader.copyWith(color: c.accent).weight(600)),
                ),
              ],
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.primaryContainer, borderRadius: Radii.thumbR),
                child: Center(child: AppIcon(AppIcons.shieldLock, color: c.onPrimaryContainer)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: <Widget>[
                    Text(
                      'Browse every file on your phone.',
                      style: UnfurlType.title.copyWith(fontSize: 16, height: 1.3, color: c.onSurface),
                    ),
                    Text(
                      'Unfurl has no internet access, so nothing can leave your device.',
                      style: UnfurlType.body.copyWith(fontSize: 14, color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: <Widget>[
              AppButton(label: 'Not now', type: AppButtonType.accent, height: 44, onPressed: onNotNow),
              AppButton(label: 'Allow access', height: 44, onPressed: onAllow),
            ],
          ),
        ],
      ),
    );
  }
}

/// A quick-access place: a 128dp card in the scrolling row.
class QuickAccessCard extends StatelessWidget {
  const QuickAccessCard({required this.icon, required this.name, required this.meta, required this.onTap, super.key});

  final IconData icon;
  final String name;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Material(
      color: c.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.cardR,
        side: BorderSide(color: c.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 128,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.sm,
              children: <Widget>[
                AppIcon(icon, color: c.icon),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: UnfurlType.titleSmall.copyWith(height: 1.25, color: c.onSurface).weight(600),
                    ),
                    Text(meta, style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Unloaded space in a folder: `surfaceContainerHigh`, no shimmer.
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    final Color fill = context.colors.surfaceContainerHigh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: <Widget>[
        Container(
          width: 96,
          height: 136,
          decoration: BoxDecoration(color: fill, borderRadius: Radii.coverR),
        ),
        Container(
          width: 70,
          height: 10,
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(5)),
        ),
      ],
    );
  }
}

class SkeletonRow extends StatelessWidget {
  const SkeletonRow({required this.index, super.key});

  final int index;

  static const List<double> _widths = <double>[0.70, 0.54, 0.82, 0.60, 0.76, 0.48, 0.66, 0.58];

  @override
  Widget build(BuildContext context) {
    final Color fill = context.colors.surfaceContainerHigh;
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        child: Row(
          spacing: 14,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(12)),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: <Widget>[
                  FractionallySizedBox(
                    widthFactor: _widths[index % _widths.length],
                    child: Container(
                      height: 11,
                      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: 0.34,
                    child: Container(
                      height: 9,
                      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Loading more · 60 of 2,318": a thin bar after the last loaded item.
class LoadingRow extends StatelessWidget {
  const LoadingRow({required this.loaded, required this.total, super.key});

  final int loaded;
  final int total;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, Space.xs, 2, 0),
      child: Row(
        spacing: Space.md,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 3,
                width: double.infinity,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(child: ColoredBox(color: c.surfaceContainerHigh)),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: total <= 0 ? 0 : loaded / total),
                      duration: Motion.of(context, Motion.fast),
                      builder: (BuildContext context, double v, _) => FractionallySizedBox(
                        heightFactor: 1,
                        widthFactor: v.clamp(0, 1),
                        child: ColoredBox(color: c.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            'Loading more · ${grouped(loaded)} of ${grouped(total)}',
            style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// "Choose this folder": the picker's fixed bottom bar with the path and
/// readable count, or "Already in your Library".
class FolderPickerBar extends StatelessWidget {
  const FolderPickerBar({
    required this.note,
    required this.label,
    required this.onPressed,
    this.noteIcon = AppIcons.folder,
    this.icon = AppIcons.check,
    super.key,
  });

  final String note;
  final IconData noteIcon;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.outline)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, MediaQuery.paddingOf(context).bottom + 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: <Widget>[
            Row(
              spacing: Space.sm,
              children: <Widget>[
                AppIcon(noteIcon, size: 16, color: c.onSurfaceVariant),
                Expanded(
                  child: Text(note, style: UnfurlType.monoLabel.copyWith(height: 1.4, color: c.onSurfaceVariant)),
                ),
              ],
            ),
            AppButton(label: label, icon: icon, onPressed: onPressed),
          ],
        ),
      ),
    );
  }
}

/// "2,318".
String grouped(int n) {
  final String s = n.toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}
