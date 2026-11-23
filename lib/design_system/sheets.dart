import 'package:flutter/material.dart';

import '../core/motion/kit.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';
import 'buttons.dart';

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
              // Icon, title and description scroll with the body, so a long
              // description at the largest text size never pushes the actions off.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 14,
                    children: <Widget>[
                      if (icon != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: c.primaryContainer,
                              borderRadius: BorderRadius.circular(Space.lg),
                            ),
                            child: AppIcon(icon!, color: c.onPrimaryContainer),
                          ),
                        ),
                      if (title != null) Text(title!, style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
                      if (description != null)
                        Text(description!, style: UnfurlType.body.copyWith(color: c.onSurfaceVariant)),
                      child,
                    ],
                  ),
                ),
              ),
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

/// A sheet's title with a close button at the end (Kuber's sheet header):
/// Reading settings, Page settings, Contents.
class SheetTitleBar extends StatelessWidget {
  const SheetTitleBar({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Row(
      spacing: Space.sm,
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: UnfurlType.sheetTitle.copyWith(color: c.onSurface),
            ),
          ),
        ),
        AppIconButton(icon: AppIcons.close, semanticLabel: 'Close', onPressed: () => Navigator.of(context).maybePop()),
      ],
    );
  }
}

/// The rest of a long sheet, built once the sheet has slid up: its first frame
/// builds only what shows. The sheet's height doesn't depend on it.
class AfterSlide extends StatefulWidget {
  const AfterSlide({required this.child, super.key});

  final Widget child;

  @override
  State<AfterSlide> createState() => _AfterSlideState();
}

class _AfterSlideState extends State<AfterSlide> {
  Animation<double>? _slide;
  bool _built = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Animation<double>? a = ModalRoute.of(context)?.animation;
    if (_built || identical(a, _slide)) return;
    _slide?.removeStatusListener(_onStatus);
    _slide = a;
    if (a == null || a.isCompleted) {
      _built = true;
    } else {
      a.addStatusListener(_onStatus);
    }
  }

  void _onStatus(AnimationStatus s) {
    if (s != AnimationStatus.completed || _built) return;
    _slide?.removeStatusListener(_onStatus);
    setState(() => _built = true);
  }

  @override
  void dispose() {
    _slide?.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _built ? widget.child : const SizedBox.shrink();
}

/// Kuber's sheet motion. Expressive: in on springSlow, out on springStandard
/// (both clamped, so no gap shows at the overshoot). Subtle: springSubtle
/// both ways. Off: 90 ms.
AnimationStyle sheetStyle(BuildContext context) {
  final MotionLevel level = Motion.levelOf(context);
  if (level == MotionLevel.off) {
    final Curve linear = Motion.curveOf(context, Motion.decelerate);
    return AnimationStyle(
      curve: linear,
      duration: Motion.fxInstant,
      reverseCurve: linear,
      reverseDuration: Motion.fxInstant,
    );
  }
  final SpringCurve open = Motion.spatialCurve(level, Motion.slowCurve);
  final SpringCurve close = level == MotionLevel.subtle ? Motion.subtleCurve : Motion.standardCurve;
  return AnimationStyle(
    curve: open.clamped,
    duration: open.settle,
    reverseCurve: close.clamped,
    reverseDuration: close.settle,
  );
}

/// Starts its slide once the sheet's first frame is built. Flutter starts the
/// clock on push, so a heavy first frame spent the fastest part of the slide
/// before anything showed, and the sheet popped instead of sliding.
class HeldSheetRoute<T> extends ModalBottomSheetRoute<T> {
  HeldSheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.backgroundColor,
    super.modalBarrierColor,
    super.sheetAnimationStyle,
  });

  @override
  TickerFuture didPush() {
    final TickerFuture future = super.didPush();
    if (controller case final AnimationController c when c.isAnimating) {
      c.stop();
      // ignore: discarded_futures
      WidgetsBinding.instance.endOfFrame.then((_) {
        // Popped or moved meanwhile: leave it.
        if (isActive && !c.isAnimating && c.value == 0 && c.status == AnimationStatus.forward) c.forward();
      });
    }
    return future;
  }
}

/// Pushes [builder] as a held sheet on the root navigator (over the nav
/// pill), on Kuber's sheet springs, as one repaint layer. [barrierColor]
/// defaults to `scrim`; pass [Colors.transparent] for none. The builder
/// draws its own shell (reader settings use a draggable one).
Future<T?> pushHeldSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? barrierColor,
  bool isScrollControlled = true,
}) {
  final NavigatorState nav = Navigator.of(context, rootNavigator: true);
  return nav.push(
    HeldSheetRoute<T>(
      capturedThemes: InheritedTheme.capture(from: context, to: nav.context),
      barrierLabel: MaterialLocalizations.of(context).scrimLabel,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      modalBarrierColor: barrierColor ?? context.colors.scrim,
      sheetAnimationStyle: sheetStyle(context),
      builder: (BuildContext context) => RepaintBoundary(child: builder(context)),
    ),
  );
}

/// Opens [builder] in the shared sheet shell on the root navigator, so a
/// sheet covers the floating nav. Slides up on a spring (see [sheetStyle])
/// over the `scrim`, held until its first frame is built.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  IconData? icon,
  String? title,
  String? description,
  List<Widget> actions = const <Widget>[],
}) {
  return pushHeldSheet<T>(
    context: context,
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
