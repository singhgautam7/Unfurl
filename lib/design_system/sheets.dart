import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';

/// The one sheet shell (boards 2 and 3): `surfaceContainer`, 28dp top
/// radius, a 1px `outline` top edge, the 36x4 handle, then an optional icon
/// tile, title and body, the content, and pinned actions.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    required this.child,
    this.icon,
    this.title,
    this.description,
    this.actions = const <Widget>[],
    super.key,
  });

  final Widget child;

  /// A 48dp `primaryContainer` tile over the title (the add-folder sheet).
  final IconData? icon;
  final String? title;
  final String? description;

  /// Pinned under the body, outside the scroll area, 10dp apart.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.sheetR,
        border: Border(top: BorderSide(color: c.outline)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, 10, Space.screen, Space.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(color: c.outline, borderRadius: Radii.fullR),
                ),
              ),
              if (icon != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(Space.lg)),
                    child: AppIcon(icon!, color: c.onPrimaryContainer),
                  ),
                ),
              if (title != null) Text(title!, style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
              if (description != null) Text(description!, style: UnfurlType.body.copyWith(color: c.onSurfaceVariant)),
              Flexible(child: SingleChildScrollView(child: child)),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: actions),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens [builder] in the shared sheet shell on the root navigator, so a
/// sheet covers the floating nav. Slides up on `sheet`, decelerating, over
/// the `scrim`.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  IconData? icon,
  String? title,
  String? description,
  List<Widget> actions = const <Widget>[],
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: context.colors.scrim,
    sheetAnimationStyle: AnimationStyle(
      duration: Motion.of(context, Motion.sheet),
      curve: Motion.curveOf(context, Motion.decelerate),
    ),
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AppBottomSheet(
        icon: icon,
        title: title,
        description: description,
        actions: actions,
        child: Builder(builder: builder),
      ),
    ),
  );
}
