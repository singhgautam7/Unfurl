import 'dart:async';

import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'app_icon.dart';

enum EmptyTone {
  /// `primaryContainer` tile: Notes, the welcome flow.
  accent,

  /// `surfaceContainerHigh` tile: an empty or unreadable folder.
  neutral,

  /// `dangerContainer` tile: access lost.
  danger,
}

/// One layout for every blocking state (board 4, "States"): an icon tile, a
/// display line, a plain explanation, then one primary action and at most
/// one secondary, pinned to the bottom. Left-aligned, as on the boards.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.tone = EmptyTone.accent,
    this.small = false,
    this.actions = const <Widget>[],
    this.aboveNav = false,
    this.detail,
    this.top,
    super.key,
  });

  /// Space above the icon, where a bar sits over the state (v3 error states).
  final double? top;

  final IconData icon;
  final String title;
  final String message;

  /// The mono detail box under the message: file name, format and cause
  /// (board 6, V3 error states).
  final String? detail;
  final EmptyTone tone;

  /// The 30dp title a folder's states use; 40 otherwise.
  final bool small;
  final List<Widget> actions;

  /// On a tab's root, where the actions must clear the floating nav pill.
  final bool aboveNav;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final (Color tileBg, Color tileFg) = switch (tone) {
      EmptyTone.accent => (c.primaryContainer, c.onPrimaryContainer),
      EmptyTone.neutral => (c.surfaceContainerHigh, c.icon),
      EmptyTone.danger => (c.dangerContainer, c.onDangerContainer),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(28, top ?? (small ? 110 : 150), 28, Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.lg,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: tileBg, borderRadius: Radii.cardR),
                  child: AppIcon(icon, size: 32, color: tileFg),
                ),
                Text(title, style: (small ? UnfurlType.displaySmall : UnfurlType.display).copyWith(color: c.onSurface)),
                Text(message, style: UnfurlType.body.copyWith(color: c.onSurfaceVariant)),
                if (detail != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 10),
                    decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: Radii.boxR),
                    child: Text(detail!, style: UnfurlType.monoLabel.copyWith(height: 1.5, color: c.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, aboveNav ? Space.bottomSafe : 36),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: actions),
          ),
      ],
    );
  }
}

/// Nothing at all until [after] has passed, then [child]. A loader that
/// flashes is worse than no loader: work that finishes inside the threshold
/// shows [placeholder] and the screen arrives whole.
class Delayed extends StatefulWidget {
  const Delayed({required this.child, this.after = threshold, this.placeholder = const SizedBox.shrink(), super.key});

  /// Screen-level states (and the viewer's loading card) wait this long.
  static const Duration threshold = Duration(milliseconds: 250);

  final Widget child;
  final Duration after;
  final Widget placeholder;

  @override
  State<Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<Delayed> {
  late final Timer _timer;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.after, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedSwitcher(duration: Motion.of(context, Motion.fast), child: _shown ? widget.child : widget.placeholder);
}

/// A 2dp `primary` hairline at 60% opacity, shown only if work exceeds
/// 120 ms. Pass [visible] for the whole load; it holds back on its own.
class LoadingHairline extends StatefulWidget {
  const LoadingHairline({required this.visible, super.key});

  final bool visible;

  static const Duration grace = Duration(milliseconds: 120);

  @override
  State<LoadingHairline> createState() => _LoadingHairlineState();
}

class _LoadingHairlineState extends State<LoadingHairline> {
  Timer? _grace;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(LoadingHairline old) {
    super.didUpdateWidget(old);
    if (old.visible != widget.visible) _sync();
  }

  void _sync() {
    _grace?.cancel();
    if (widget.visible) {
      _grace = Timer(LoadingHairline.grace, () {
        if (mounted) setState(() => _shown = true);
      });
    } else {
      _shown = false;
    }
  }

  @override
  void dispose() {
    _grace?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: Motion.of(context, Motion.fast),
    opacity: _shown && widget.visible ? 0.6 : 0,
    child: Container(height: 2, color: context.colors.primary),
  );
}
