import 'package:flutter/material.dart';

import '../core/layout.dart';
import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';
import 'buttons.dart';
import 'search_field.dart';

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

/// Kuber's header search: [builder] draws the header row with the search
/// button it is handed (null while [enabled] is false). The button turns the
/// row into a search pill that grows out of the trailing edge, where the
/// button sat, and collapses back into it. The pill's back button, or the
/// system back, closes it and clears the query.
class HeaderSearch extends StatefulWidget {
  const HeaderSearch({
    required this.hint,
    required this.onChanged,
    required this.builder,
    this.enabled = true,
    this.height = 60,
    super.key,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final Widget Function(BuildContext context, Widget? searchButton) builder;
  final bool enabled;

  /// The header row's height, so opening the pill moves nothing below it.
  final double height;

  @override
  State<HeaderSearch> createState() => _HeaderSearchState();
}

class _HeaderSearchState extends State<HeaderSearch> {
  static const ValueKey<String> _pill = ValueKey<String>('search');

  /// The pill's transition, kept above the row so closing uncovers the row.
  static const ValueKey<String> _pillTransition = ValueKey<String>('search-transition');
  final TextEditingController _controller = TextEditingController();
  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    FocusScope.of(context).unfocus();
    if (_controller.text.isNotEmpty) {
      _controller.clear();
      widget.onChanged('');
    }
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = Motion.reduced(context);
    final Curve curve = Motion.curveOf(context, Motion.decelerate);
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.containerTransform),
      // The same curve both ways: closing plays the opening backwards.
      switchInCurve: curve,
      switchOutCurve: curve,
      layoutBuilder: (Widget? current, List<Widget> previous) {
        final List<Widget> all = <Widget>[...previous, ?current];
        bool pill(Widget w) => w.key == _pillTransition;
        return Stack(
          alignment: AlignmentDirectional.centerEnd,
          children: <Widget>[...all.where((Widget w) => !pill(w)), ...all.where(pill)],
        );
      },
      transitionBuilder: (Widget child, Animation<double> a) {
        if (reduced || child.key != _pill) return FadeTransition(opacity: a, child: child);
        return SizeTransition(
          key: _pillTransition,
          sizeFactor: a,
          axis: Axis.horizontal,
          alignment: AlignmentDirectional.centerEnd,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Motion.searchPillFade),
            child: child,
          ),
        );
      },
      child: _open && widget.enabled
          ? PopScope(
              key: _pill,
              canPop: false,
              onPopInvokedWithResult: (bool didPop, Object? _) {
                if (!didPop) _close();
              },
              child: SizedBox(
                height: widget.height,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, 0, 14, 0),
                  child: Center(
                    child: SearchField(
                      hint: widget.hint,
                      controller: _controller,
                      autofocus: true,
                      height: IconSpec.tapTarget,
                      onBack: _close,
                      onChanged: widget.onChanged,
                    ),
                  ),
                ),
              ),
            )
          : KeyedSubtree(
              key: const ValueKey<String>('bar'),
              child: widget.builder(
                context,
                widget.enabled
                    ? AppIconButton(
                        icon: AppIcons.search,
                        semanticLabel: widget.hint,
                        onPressed: () => setState(() => _open = true),
                      )
                    : null,
              ),
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
    this.wide = false,
    super.key,
  });

  final String title;
  final VoidCallback? onBack;
  final IconData backIcon;

  /// Uses the full width on expanded windows (Insights' two columns); other
  /// pages centre at 720dp there (board 6, V7).
  final bool wide;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          // Expanded windows: header and body centred at 720dp, unless [wide].
          final double side =
              !wide &&
                  SizeClass.ofWidth(box.maxWidth + (SizeClass.of(context).rail ? AdaptiveSpec.railWidth : 0)) ==
                      SizeClass.expanded
              ? ((box.maxWidth - AdaptiveSpec.centred) / 2).clamp(Space.screen, double.infinity)
              : Space.screen;
          return CollapseOnScroll(
            builder: (BuildContext context, bool collapsed) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: side - Space.screen),
                  child: AppHeader(
                    title: title,
                    onBack: onBack,
                    actions: actions,
                    collapsed: collapsed,
                    backIcon: backIcon,
                  ),
                ),
                Expanded(
                  child: ListView(padding: EdgeInsets.fromLTRB(side, 6, side, Space.bottomSafe), children: children),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
