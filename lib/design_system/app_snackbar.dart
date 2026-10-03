import 'dart:async';

import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';

/// The toast message specification.
class SnackMessage {
  const SnackMessage({required this.text, this.actionLabel, this.onAction, this.isError = false, this.duration});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;
  final Duration? duration;

  Duration get effectiveDuration =>
      duration ?? (actionLabel != null || isError ? const Duration(seconds: 5) : const Duration(seconds: 4));
}

/// Mull's snackbar, ported: a top-positioned, timed snackbar with a countdown progress indicator,
/// circular card radius, dismiss close button, and swipe-to-dismiss gestures.
abstract final class AppSnackbar {
  static OverlayEntry? _currentEntry;
  static _AppSnackBarController? _currentController;
  static Timer? _currentTimer;

  static void dismiss() {
    _currentTimer?.cancel();
    _currentTimer = null;

    final _AppSnackBarController? controller = _currentController;
    final OverlayEntry? entry = _currentEntry;
    _currentController = null;
    _currentEntry = null;

    if (controller != null && entry != null) {
      controller.animateOut().then((_) {
        if (entry.mounted) entry.remove();
      });
    } else {
      entry?.remove();
    }
  }

  static void show(BuildContext context, SnackMessage message) {
    dismiss();

    final OverlayState? overlay =
        Overlay.maybeOf(context, rootOverlay: true) ?? Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (overlay == null) return;

    final _AppSnackBarController controller = _AppSnackBarController();
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext _) =>
          _TimedSnackBarWidget(controller: controller, message: message, onRequestClose: dismiss),
    );

    _currentController = controller;
    _currentEntry = entry;
    overlay.insert(entry);

    _currentTimer = Timer(message.effectiveDuration, dismiss);
  }

  static void info(BuildContext context, String text) => show(context, SnackMessage(text: text));

  static void error(BuildContext context, String text) => show(context, SnackMessage(text: text, isError: true));

  static void undo(BuildContext context, String text, VoidCallback onUndo) =>
      show(context, SnackMessage(text: text, actionLabel: 'Undo', onAction: onUndo));
}

class _AppSnackBarController {
  _TimedSnackBarWidgetState? _state;

  void _attach(_TimedSnackBarWidgetState state) => _state = state;

  Future<void> animateOut() async {
    final _TimedSnackBarWidgetState? state = _state;
    if (state == null) return;
    await state._animateOut();
  }
}

class _TimedSnackBarWidget extends StatefulWidget {
  const _TimedSnackBarWidget({required this.controller, required this.message, required this.onRequestClose});

  final _AppSnackBarController controller;
  final SnackMessage message;
  final VoidCallback onRequestClose;

  @override
  State<_TimedSnackBarWidget> createState() => _TimedSnackBarWidgetState();
}

class _TimedSnackBarWidgetState extends State<_TimedSnackBarWidget> with TickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<double> _slideAnim;
  late final AnimationController _progressCtrl;
  bool _actionFired = false;

  Offset _dragOffset = Offset.zero;

  static const double _kSwipeDistanceThreshold = 80.0;
  static const double _kSwipeVelocityThreshold = 600.0;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: Motion.snackEnter, reverseDuration: Motion.snackExit);
    _slideAnim = CurvedAnimation(parent: _slideCtrl, curve: Motion.decelerate);
    _progressCtrl = AnimationController(vsync: this, duration: widget.message.effectiveDuration);
    widget.controller._attach(this);
    _slideCtrl.forward();
    _progressCtrl.forward();
  }

  Future<void> _animateOut() async {
    if (!mounted) return;
    _progressCtrl.stop();
    await _slideCtrl.reverse();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  void _handleAction(VoidCallback? cb) {
    if (_actionFired) return;
    _actionFired = true;
    widget.onRequestClose();
    cb?.call();
  }

  void _onDragStart(DragStartDetails _) {
    _progressCtrl.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      final double dx = _dragOffset.dx + details.delta.dx;
      final double dy = (_dragOffset.dy + details.delta.dy).clamp(-200.0, 0.0);
      _dragOffset = Offset(dx, dy);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final Offset v = details.velocity.pixelsPerSecond;
    final bool distanceMet =
        _dragOffset.dx.abs() >= _kSwipeDistanceThreshold || _dragOffset.dy <= -_kSwipeDistanceThreshold;
    final bool velocityMet = v.dx.abs() >= _kSwipeVelocityThreshold || v.dy <= -_kSwipeVelocityThreshold;

    if (distanceMet || velocityMet) {
      widget.onRequestClose();
      return;
    }

    setState(() => _dragOffset = Offset.zero);
    _progressCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final SnackMessage m = widget.message;
    final Color barColor = m.isError ? c.danger : c.primary;
    final double topPadding = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: topPadding + Space.sm,
      left: Space.screen,
      right: Space.screen,
      child: AnimatedBuilder(
        animation: _slideAnim,
        builder: (BuildContext context, Widget? child) {
          final double t = _slideAnim.value;
          final Offset entryOffset = Offset(0, (1 - t) * -80);
          final Offset totalOffset = entryOffset + _dragOffset;
          final double dragDistance = _dragOffset.distance;
          final double dragFade = (dragDistance / 200).clamp(0.0, 0.5);
          return Transform.translate(
            offset: totalOffset,
            child: Opacity(opacity: (t * (1 - dragFade)).clamp(0.0, 1.0), child: child),
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              liveRegion: true,
              child: Container(
                decoration: BoxDecoration(
                  color: c.surfaceContainer,
                  borderRadius: Radii.cardR,
                  border: Border.all(color: m.isError ? c.danger : c.outline),
                  boxShadow: <BoxShadow>[BoxShadow(color: c.shadow, blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: <Widget>[
                    // Left bar indicator
                    Container(
                      width: 4,
                      height: 44,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: Space.md),
                    AppIcon(m.isError ? AppIcons.error : AppIcons.checkCircle, color: barColor, size: 20),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              m.text,
                              style: UnfurlType.titleMedium.copyWith(
                                fontSize: 13.5,
                                color: c.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: Space.sm),
                            AnimatedBuilder(
                              animation: _progressCtrl,
                              builder: (BuildContext context, _) {
                                return LinearProgressIndicator(
                                  value: 1.0 - _progressCtrl.value,
                                  minHeight: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(c.primary),
                                  backgroundColor: c.outline,
                                  borderRadius: BorderRadius.circular(1),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (m.actionLabel != null)
                      TextButton(
                        onPressed: () => _handleAction(m.onAction),
                        child: Text(
                          m.actionLabel!.toUpperCase(),
                          style: UnfurlType.label.copyWith(color: c.primary, letterSpacing: 0.24).weight(700),
                        ),
                      ),
                    IconButton(
                      icon: AppIcon(AppIcons.close, size: 18, color: c.onSurfaceVariant),
                      tooltip: 'Dismiss',
                      onPressed: widget.onRequestClose,
                    ),
                    const SizedBox(width: Space.xs),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
