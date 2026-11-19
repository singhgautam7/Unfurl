import 'package:flutter/material.dart';

import '../core/layout.dart';
import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';
import 'buttons.dart';
import 'floating_header.dart';
import 'search_field.dart';

export 'floating_header.dart' show FloatingHeaderSpec, HeaderFloat, HeaderPage;

/// The one top bar. Every tab root and pushed page uses this, inside a
/// [HeaderPage] (which paints its surface and morphs it into the floating
/// pill; [AppScaffold] is the common case).
///
/// A tab root is the title at the 20dp margin with round actions on the
/// right (`8 14 8 20`, a 48 row). A pushed page leads with the back button
/// (`8 14 8 16`, 8dp gap). [crumb] is the parent folder's name above the title
/// (Folder pages); pressing the title area then calls [onCrumb].
class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    this.onBack,
    this.actions = const <Widget>[],
    this.backIcon = AppIcons.back,
    this.crumb,
    this.onCrumb,
    super.key,
  });

  final String title;

  /// Null on a tab root, which has nowhere to go back to.
  final VoidCallback? onBack;

  /// close instead of back where the button leaves a flow (the folder picker).
  final IconData backIcon;
  final List<Widget> actions;
  final String? crumb;
  final VoidCallback? onCrumb;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final HeaderFloat? float = HeaderFloat.maybeOf(context);
    final TextStyle style = UnfurlType.headerTitle.copyWith(color: c.onSurface);
    Widget slot = crumb == null
        ? Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
          )
        : Semantics(
            button: onCrumb != null,
            label: '$title, in $crumb',
            onTap: onCrumb,
            excludeSemantics: true,
            child: InkWell(
              onTap: onCrumb,
              borderRadius: Radii.chipR,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: IconSpec.tapTarget),
                child: Padding(
                  padding: const EdgeInsets.only(left: Space.xs),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              crumb!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                            ),
                          ),
                          AppIcon(AppIcons.expandMore, size: 16, color: c.onSurfaceVariant),
                        ],
                      ),
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
                    ],
                  ),
                ),
              ),
            ),
          );
    if (float != null && float.floating) {
      slot = PillTitle(
        progress: float.progress,
        leadShift: onBack != null ? 0 : FloatingHeaderSpec.noButtonShift,
        trailShift: actions.isEmpty ? FloatingHeaderSpec.noButtonShift : 0,
        // Largest text, or no room: the pill drops the title (its semantics stay).
        dropBelow: MediaQuery.textScalerOf(context).scale(1) >= FloatingHeaderSpec.dropAtScale
            ? double.infinity
            : FloatingHeaderSpec.minTitle,
        child: slot,
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(onBack != null ? Space.lg : Space.screen, Space.sm, 14, Space.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: IconSpec.tapTarget),
        child: Row(
          spacing: onBack != null ? Space.sm : 0,
          children: <Widget>[
            if (onBack != null)
              AppIconButton(
                icon: backIcon,
                onPressed: onBack,
                semanticLabel: backIcon == AppIcons.close ? 'Close' : 'Back',
              ),
            Expanded(child: slot),
            ...actions,
          ],
        ),
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
    this.height = FloatingHeaderSpec.rest,
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
    HeaderFloat.maybeOf(context, listen: false)?.onSearch(false);
  }

  void _openSearch() {
    setState(() => _open = true);
    HeaderFloat.maybeOf(context, listen: false)?.onSearch(true);
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
                    ? AppIconButton(icon: AppIcons.search, semanticLabel: widget.hint, onPressed: _openSearch)
                    : null,
              ),
            ),
    );
  }
}

/// A screen: the header over a scrolling body that clears the floating nav.
/// Tab roots and pushed pages both use it; the header floats as a pill when
/// the setting is on.
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
    body: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        // Expanded windows: header and body centred at 720dp, unless [wide].
        final double side =
            !wide &&
                SizeClass.ofWidth(box.maxWidth + (SizeClass.of(context).rail ? AdaptiveSpec.railWidth : 0)) ==
                    SizeClass.expanded
            ? ((box.maxWidth - AdaptiveSpec.centred) / 2).clamp(Space.screen, double.infinity)
            : Space.screen;
        return HeaderPage(
          gutter: side - Space.screen,
          header: AppHeader(title: title, onBack: onBack, actions: actions, backIcon: backIcon),
          body: (BuildContext context, double inset) => ListView(
            clipBehavior: Clip.none,
            padding: EdgeInsets.fromLTRB(side, inset + _topGap, side, Space.bottomSafe),
            children: children,
          ),
        );
      },
    ),
  );
}

/// Between the header at rest and the first item of a page.
const double _topGap = 6;
