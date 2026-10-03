import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/nav_pill.dart';
import '../../features/settings/settings_controller.dart';
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

/// Hosts the four tabs and the floating pill, as Mull's NavShell does.
///
/// A tab switch slides the incoming page in from the side it lies on
/// (`containerTransform`, decelerate). The pill translates down 72 and fades
/// on scroll-down past 24px and returns on any scroll-up (`navHide`).
class NavShell extends ConsumerStatefulWidget {
  const NavShell({required this.child, required this.index, required this.onSelect, super.key});

  final Widget child;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  ConsumerState<NavShell> createState() => _NavShellState();
}

class _NavShellState extends ConsumerState<NavShell> with TickerProviderStateMixin {
  late final AnimationController _hide = AnimationController(vsync: this, duration: Motion.navHide);
  late final AnimationController _page = AnimationController(
    vsync: this,
    duration: Motion.containerTransform,
    value: 1,
  );
  late bool _hideNow = _shouldHide();
  late final AnimationController _hidden = AnimationController(
    vsync: this,
    duration: Motion.navHide,
    value: _hideNow ? 1 : 0,
  );

  /// Hidden on request, and on first launch until there is somewhere to go:
  /// a file has been opened or a folder added (see docs/design-gaps.md).
  bool _shouldHide() =>
      ref.read(navHiddenProvider) ||
      !(ref.read(settingsProvider).openedFile || (ref.read(foldersProvider).value?.isNotEmpty ?? false));
  double _lastOffset = 0;
  bool _forward = true;

  @override
  void didUpdateWidget(NavShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _forward = widget.index > oldWidget.index;
      _page.forward(from: 0);
      _hide.reverse();
    }
  }

  @override
  void dispose() {
    _hide.dispose();
    _page.dispose();
    _hidden.dispose();
    super.dispose();
  }

  /// A decisive horizontal fling anywhere on a tab moves to the next one.
  /// Horizontal lists inside a tab win the gesture where they start.
  void _onHorizontalFling(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 240) return;
    final int next = velocity < 0 ? widget.index + 1 : widget.index - 1;
    if (next < 0 || next >= kDestinations.length) return;
    widget.onSelect(next);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n is! ScrollUpdateNotification) return false;
    final double offset = n.metrics.pixels;
    final double delta = offset - _lastOffset;
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
    ref.watch(foldersProvider);
    final bool shouldHide = _shouldHide();
    if (shouldHide != _hideNow) {
      _hideNow = shouldHide;
      shouldHide ? _hidden.forward() : _hidden.reverse();
    }
    final bool reduced = Motion.reduced(context);
    final Animation<double> pageCurved = CurvedAnimation(
      parent: _page,
      curve: Motion.curveOf(context, Motion.decelerate),
    );
    final Animation<double> hide = _MaxAnimation(_hide, _hidden);
    // The board puts the pill 22 above the frame's edge, where the gesture
    // bar sits; with three-button navigation it clears the buttons instead.
    final double bottom = math.max(22, MediaQuery.viewPaddingOf(context).bottom);

    return PopScope(
      // Back from any other tab lands on Home; on Home it leaves the app.
      canPop: widget.index == 0,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) widget.onSelect(0);
      },
      child: Scaffold(
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  onHorizontalDragEnd: _onHorizontalFling,
                  behavior: HitTestBehavior.translucent,
                  child: ClipRect(
                    // The translation stays in the tree at rest (offset zero)
                    // rather than being added for the animation, so a switch
                    // never re-parents the branches (Headshorts). The
                    // boundary sits inside it: the page rasterises once and
                    // only moves.
                    child: AnimatedBuilder(
                      animation: pageCurved,
                      builder: (BuildContext context, Widget? child) {
                        final double t = reduced ? 1 : pageCurved.value;
                        return FractionalTranslation(translation: Offset(_forward ? 1 - t : t - 1, 0), child: child);
                      },
                      child: RepaintBoundary(child: widget.child),
                    ),
                  ),
                ),
              ),
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
