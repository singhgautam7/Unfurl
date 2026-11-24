// ignore_for_file: discarded_futures (the route's own future is returned)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'motion.dart';

/// Mull's `page.push`: a container-transform-shaped push, 240 ms. The
/// incoming page fades and scales up from 96%; under reduced motion it
/// cross-fades at 90 ms. An Android 14+ predictive back gesture drives the
/// same transition backwards under the finger, so back never snaps.
///
/// The clock starts once the page's first frame is built ([_UnfurlRoute]): a
/// heavy first frame used to eat the fastest part of the push.
UnfurlPage<T> unfurlPage<T>({required Widget child, required GoRouterState state}) => UnfurlPage<T>(
  key: state.pageKey,
  // Named by location, so a flow (the folder picker) can be closed whole.
  name: state.uri.toString(),
  child: child,
);

class UnfurlPage<T> extends Page<T> {
  const UnfurlPage({required this.child, super.key, super.name});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => _UnfurlRoute<T>(this);
}

class _UnfurlRoute<T> extends PageRoute<T> {
  _UnfurlRoute(UnfurlPage<T> page) : super(settings: page);

  @override
  Duration get transitionDuration => Motion.containerTransform;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  TickerFuture didPush() {
    final TickerFuture future = super.didPush();
    if (controller case final AnimationController c when c.isAnimating) {
      c.stop();
      WidgetsBinding.instance.endOfFrame.then((_) {
        // Popped or moved meanwhile: leave it.
        if (isActive && !c.isAnimating && c.value == 0) c.forward();
      });
    }
    return future;
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Semantics(scopesRoute: true, explicitChildNodes: true, child: (settings as UnfurlPage<T>).child);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _PredictiveBack(
    animation: animation,
    builder: (bool linear) {
      final bool reduced = Motion.reduced(context);
      // Under the finger, and while a released gesture settles, the
      // page tracks progress linearly; a curve there would lag or
      // overshoot the thumb, and swapping curves mid-flight would jump.
      final Animation<double> fade = linear
          ? animation
          : CurvedAnimation(
              parent: animation,
              curve: reduced ? Curves.linear : Motion.decelerate,
              reverseCurve: Curves.easeInCubic,
            );
      return FadeTransition(
        opacity: fade,
        child: reduced
            ? child
            : ScaleTransition(
                scale: Tween<double>(
                  begin: 0.96,
                  end: 1,
                ).animate(linear ? animation : CurvedAnimation(parent: animation, curve: Motion.spring)),
                child: child,
              ),
      );
    },
  );
}

/// Hands Android's back-gesture events to the enclosing route, which then
/// drives its own transition with the gesture's progress.
class _PredictiveBack extends StatefulWidget {
  const _PredictiveBack({required this.animation, required this.builder});

  final Animation<double> animation;
  final Widget Function(bool linear) builder;

  @override
  State<_PredictiveBack> createState() => _PredictiveBackState();
}

class _PredictiveBackState extends State<_PredictiveBack> with WidgetsBindingObserver {
  PageRoute<dynamic>? get _route => ModalRoute.of(context) as PageRoute<dynamic>?;

  /// From a gesture's start until the route is back at rest (a cancelled
  /// gesture) or gone (a committed one).
  bool _linear = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.animation.addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (_linear && status == AnimationStatus.completed && !(_route?.popGestureInProgress ?? false)) {
      setState(() => _linear = false);
    }
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    final PageRoute<dynamic>? route = _route;
    if (backEvent.isButtonEvent || route == null || !_onTop(route) || !route.popGestureEnabled) return false;
    route.handleStartBackGesture(progress: 1 - backEvent.progress);
    setState(() => _linear = true);
    return true;
  }

  /// Current in its own navigator and in every navigator around it: a page
  /// in a tab is "current" in the tab's navigator even while a sheet on the
  /// root navigator covers it, and the sheet must get the gesture.
  static bool _onTop(ModalRoute<dynamic> route) {
    for (ModalRoute<dynamic>? r = route; r != null;) {
      if (!r.isCurrent) return false;
      final BuildContext? outer = r.navigator?.context;
      r = outer == null ? null : ModalRoute.of(outer);
    }
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) =>
      _route?.handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);

  @override
  void handleCancelBackGesture() => _route?.handleCancelBackGesture();

  @override
  void handleCommitBackGesture() => _route?.handleCommitBackGesture();

  @override
  Widget build(BuildContext context) => widget.builder(_linear);
}
