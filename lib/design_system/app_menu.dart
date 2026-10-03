import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';

/// One row of [showAppMenu], or, with [AppMenuEntry.divider], the rule
/// between groups.
class AppMenuEntry<T> {
  const AppMenuEntry({
    required this.value,
    required this.label,
    required this.icon,
    this.subtitle,
    this.selected = false,
  }) : divider = false;

  const AppMenuEntry.divider()
    : value = null,
      label = '',
      icon = null,
      subtitle = null,
      selected = false,
      divider = true;

  final T? value;
  final String label;
  final IconData? icon;

  /// A `monoLabel` line under the label ("read-only access").
  final String? subtitle;

  /// The current sort or view: a `primaryContainer` pill.
  final bool selected;
  final bool divider;
}

/// The overflow menu (board 2, A3 and A6): a `surface` card with a 1px
/// outline and radius 20, opened under the button that raised it. Rows are
/// 52dp pills; no shadow, since the nav pill owns the only one.
Future<T?> showAppMenu<T>({
  required BuildContext context,
  required BuildContext anchorContext,
  required List<AppMenuEntry<T>> entries,
}) {
  final UnfurlColors c = context.colors;
  final RenderBox overlay =
      Navigator.of(context, rootNavigator: true).overlay!.context.findRenderObject()! as RenderBox;
  final RenderBox anchor = anchorContext.findRenderObject()! as RenderBox;
  final Offset topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
  return showMenu<T>(
    context: context,
    useRootNavigator: true,
    position: RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy + anchor.size.height,
      overlay.size.width - topLeft.dx - anchor.size.width,
      0,
    ),
    color: c.surface,
    elevation: 0,
    constraints: const BoxConstraints(minWidth: 262),
    shape: RoundedRectangleBorder(
      borderRadius: Radii.cardR,
      side: BorderSide(color: c.outline),
    ),
    menuPadding: const EdgeInsets.symmetric(vertical: Space.sm),
    items: <PopupMenuEntry<T>>[
      for (final AppMenuEntry<T> e in entries)
        if (e.divider)
          PopupMenuItem<T>(
            enabled: false,
            height: 13,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Divider(color: c.divider),
          )
        else
          PopupMenuItem<T>(
            value: e.value,
            height: 0,
            padding: EdgeInsets.zero,
            child: _MenuRow<T>(entry: e),
          ),
    ],
  );
}

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({required this.entry});

  final AppMenuEntry<T> entry;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final Color fg = entry.selected ? c.onPrimaryContainer : c.onSurface;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      margin: const EdgeInsets.symmetric(horizontal: Space.sm),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: entry.selected ? c.primaryContainer : c.primaryContainer.withValues(alpha: 0),
        borderRadius: Radii.fullR,
      ),
      child: Row(
        spacing: Space.lg,
        children: <Widget>[
          if (entry.icon != null) AppIcon(entry.icon!, color: entry.selected ? fg : c.icon),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.label,
                  style: UnfurlType.body.copyWith(height: 1.3, color: fg).weight(entry.selected ? 600 : 400),
                ),
                if (entry.subtitle != null)
                  Text(entry.subtitle!, style: UnfurlType.monoLabel.copyWith(height: 1.5, color: c.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
