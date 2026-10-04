import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';
import 'buttons.dart';

/// The one top bar. Every tab root and pushed page uses this.
///
/// A tab root is the title at the 20dp margin with round actions on the
/// right (`8 14 8 20`, min height 60). A pushed page leads with the back
/// button (`8 14 8 16`, 8dp gap). Scrolled, the title steps to
/// `screenTitle` and the bar takes `surface` over a `divider` hairline, as in
/// Mull.
class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    this.onBack,
    this.actions = const <Widget>[],
    this.collapsed = false,
    this.backIcon = AppIcons.back,
    super.key,
  });

  final String title;

  /// Null on a tab root, which has nowhere to go back to.
  final VoidCallback? onBack;

  /// close instead of back where the button leaves a flow (the folder picker).
  final IconData backIcon;
  final List<Widget> actions;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final Duration d = Motion.of(context, Motion.fast);
    return AnimatedContainer(
      duration: d,
      decoration: BoxDecoration(
        color: collapsed ? c.surface : c.surface.withValues(alpha: 0),
        border: Border(bottom: BorderSide(color: collapsed ? c.divider : c.divider.withValues(alpha: 0))),
      ),
      constraints: const BoxConstraints(minHeight: 60),
      padding: EdgeInsets.fromLTRB(onBack != null ? Space.lg : Space.screen, Space.sm, 14, Space.sm),
      child: Row(
        spacing: onBack != null ? Space.sm : 0,
        children: <Widget>[
          if (onBack != null)
            AppIconButton(
              icon: backIcon,
              onPressed: onBack,
              semanticLabel: backIcon == AppIcons.close ? 'Close' : 'Back',
            ),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: d,
              style: (collapsed ? UnfurlType.screenTitle : UnfurlType.headerTitle).copyWith(color: c.onSurface),
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Reports whether a scroll view has moved past its first 24px, so the
/// header above it can collapse.
class CollapseOnScroll extends StatefulWidget {
  const CollapseOnScroll({required this.builder, super.key});

  final Widget Function(BuildContext context, bool collapsed) builder;

  @override
  State<CollapseOnScroll> createState() => _CollapseOnScrollState();
}

class _CollapseOnScrollState extends State<CollapseOnScroll> {
  bool _collapsed = false;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final bool next = n.metrics.pixels > 24;
    if (next != _collapsed) setState(() => _collapsed = next);
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.builder(context, _collapsed));
}

/// A screen: safe area at the top, the header, then a scrolling body that
/// clears the floating nav. Tab roots and pushed pages both use it.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.children,
    this.onBack,
    this.actions = const <Widget>[],
    this.backIcon = AppIcons.back,
    super.key,
  });

  final String title;
  final VoidCallback? onBack;
  final IconData backIcon;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: CollapseOnScroll(
        builder: (BuildContext context, bool collapsed) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppHeader(title: title, onBack: onBack, actions: actions, collapsed: collapsed, backIcon: backIcon),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, Space.bottomSafe),
                children: children,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
