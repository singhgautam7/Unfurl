import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/nav_pill.dart';
import '../../features/settings/settings_controller.dart';
import '../db/database.dart' show Folder;
import '../explorer.dart';
import '../layout.dart';
import '../motion/motion.dart';
import '../providers.dart';

/// True while the pill should be gone: the first launch before any file has
/// opened (HANDOFF "Deviations from Mull"). Readers and pushed screens sit on
/// the root navigator above the shell, so they cover it without this.
final NotifierProvider<NavHidden, bool> navHiddenProvider = NotifierProvider<NavHidden, bool>(NavHidden.new);

class NavHidden extends Notifier<bool> {
  @override
  bool build() => false;

  void set({required bool hidden}) => state = hidden;
}

/// The active tab tapped again: its outermost vertical scroll view goes back
/// to the top (Kuber's). Runs only on the tap; the walk stops at the first
/// vertical scrollable, which is the page's own.
void scrollTabToTop(BuildContext? tab) {
  if (tab == null) return;
  ScrollPosition? found;
  void visit(Element e) {
    if (found != null) return;
    if (e is StatefulElement && e.state is ScrollableState) {
      final ScrollableState s = e.state as ScrollableState;
      if (axisDirectionToAxis(s.axisDirection) == Axis.vertical) {
        found = s.position;
        return;
      }
    }
    e.visitChildren(visit);
  }

  tab.visitChildElements(visit);
  final ScrollPosition? p = found;
  if (p == null || p.pixels <= p.minScrollExtent) return;
  final double screens = (p.pixels - p.minScrollExtent) / p.viewportDimension;
  unawaited(
    p.animateTo(
      p.minScrollExtent,
      duration: Motion.of(tab, Motion.scrollTopFor(screens)),
      curve: Motion.curveOf(tab, Motion.scrollTop),
    ),
  );
}

/// Hosts the tabs (a [BranchStack], the router's container) and the floating
/// pill, as Mull's NavShell does. The pill translates down 72 and fades on
/// scroll-down past 24px and returns on any scroll-up (`navHide`).
class NavShell extends ConsumerStatefulWidget {
  const NavShell({required this.child, required this.index, required this.onSelect, this.nested = false, super.key});

  final Widget child;
  final int index;
  final ValueChanged<int> onSelect;

  /// A screen inside the tab (a folder) is showing: the pill steps away, as
  /// pushed screens cover it.
  final bool nested;

  @override
  ConsumerState<NavShell> createState() => _NavShellState();
}

class _NavShellState extends ConsumerState<NavShell> with TickerProviderStateMixin {
  late final AnimationController _hide = AnimationController(vsync: this, duration: Motion.navHide);
  late bool _hideNow = _shouldHide();
  late final AnimationController _hidden = AnimationController(
    vsync: this,
    duration: Motion.navHide,
    value: _hideNow ? 1 : 0,
  );

  /// Hidden on request, and on first launch until there is somewhere to go:
  /// a file has been opened, a folder added or all-files access granted
  /// (Files then has the whole phone to show; see docs/design-gaps.md).
  bool _shouldHide() =>
      widget.nested ||
      ref.read(navHiddenProvider) ||
      !(ref.read(settingsProvider).openedFile ||
          (ref.read(foldersProvider).value?.isNotEmpty ?? false) ||
          ref.read(filesAccessProvider).granted);
  double? _lastOffset;

  @override
  void didUpdateWidget(NavShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _lastOffset = null;
      _hide.reverse();
    }
    // Back at a tab's root, the pill returns whatever the folder scrolled.
    if (widget.nested != oldWidget.nested) {
      _lastOffset = null;
      _hide.reverse();
    }
  }

  @override
  void dispose() {
    _hide.dispose();
    _hidden.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (widget.nested || n.metrics.axis != Axis.vertical || n is! ScrollUpdateNotification) return false;
    final double offset = n.metrics.pixels;
    // The first move on a tab that kept its place: where it was is the base.
    _lastOffset ??= offset - (n.scrollDelta ?? 0);
    final double delta = offset - _lastOffset!;
    if (delta.abs() < 2) return false;
    _lastOffset = offset;
    if (delta > 0 && offset > 24) {
      _hide.forward();
    } else if (delta < 0) {
      _hide.reverse();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(navHiddenProvider);
    ref.watch(settingsProvider.select((AppSettings s) => s.openedFile));
    ref.watch(foldersProvider.select((AsyncValue<List<Folder>> f) => f.value?.isNotEmpty ?? false));
    ref.watch(filesAccessProvider.select((FilesAccess a) => a.granted));
    final bool shouldHide = _shouldHide();
    if (shouldHide != _hideNow) {
      _hideNow = shouldHide;
      unawaited(shouldHide ? _hidden.forward() : _hidden.reverse());
    }
    final bool reduced = Motion.reduced(context);
    final Animation<double> hide = _MaxAnimation(_hide, _hidden);
    // The board puts the pill 22 above the frame's edge, where the gesture
    // bar sits; with three-button navigation it clears the buttons instead.
    final double bottom = math.max(22, MediaQuery.viewPaddingOf(context).bottom);
    final bool rail = SizeClass.of(context).rail;

    return PopScope(
      // Back from any other tab's root lands on Home; on Home it leaves the
      // app. Inside a tab, back pops that tab's own stack first.
      canPop: widget.index == 0 || widget.nested,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) widget.onSelect(0);
      },
      child: Scaffold(
        body: rail
            ? Row(
                children: <Widget>[
                  // Board 6, V7: a rail on expanded widths, out of the way of
                  // a landscape tablet's height; it leaves only on first launch.
                  AnimatedBuilder(
                    animation: _hidden,
                    builder: (BuildContext context, Widget? child) => Align(
                      alignment: Alignment.centerRight,
                      widthFactor: 1 - Motion.decelerate.transform(_hidden.value),
                      child: child,
                    ),
                    child: NavRail(index: widget.index, onSelect: widget.onSelect),
                  ),
                  Expanded(child: widget.child),
                ],
              )
            : NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: Stack(
                  children: <Widget>[
                    widget.child,
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: bottom,
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: hide,
                          builder: (BuildContext context, Widget? child) {
                            final double t = Motion.decelerate.transform(hide.value);
                            return IgnorePointer(
                              ignoring: t > 0.5,
                              child: Opacity(
                                opacity: 1 - t,
                                child: Transform.translate(offset: Offset(0, reduced ? 0 : 72 * t), child: child),
                              ),
                            );
                          },
                          child: Center(
                            child: NavPill(index: widget.index, onSelect: widget.onSelect),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// The further-hidden of the two reasons the pill leaves: scroll or state.
class _MaxAnimation extends CompoundAnimation<double> {
  _MaxAnimation(Animation<double> a, Animation<double> b) : super(first: a, next: b);

  @override
  double get value => math.max(first.value, next.value);
}
