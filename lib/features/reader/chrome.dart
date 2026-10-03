import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/reading_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/buttons.dart';

/// Reader bars appear and leave together: slide 12dp and fade on
/// `chromeToggle`, decelerating (R12).
class ChromeSlide extends StatelessWidget {
  const ChromeSlide({required this.visible, required this.child, this.fromTop = true, super.key});

  final bool visible;
  final bool fromTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Duration d = Motion.of(context, Motion.chromeToggle);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: d,
        curve: Motion.decelerate,
        child: AnimatedSlide(
          offset: visible || Motion.reduced(context) ? Offset.zero : Offset(0, fromTop ? -0.12 : 0.12),
          duration: d,
          curve: Motion.decelerate,
          child: child,
        ),
      ),
    );
  }
}

/// The reader's top bar: back, title and where you are, the optional mode
/// toggle, then actions. `surface` with a 1px outline under it.
class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    required this.title,
    required this.onBack,
    this.subtitle,
    this.toggle,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final Widget? toggle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.outline)),
      ),
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.xs, 6, Space.xs, Space.sm),
          child: Row(
            spacing: 2,
            children: <Widget>[
              AppIconButton(icon: AppIcons.back, filled: false, semanticLabel: 'Back', onPressed: onBack),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UnfurlType.titleMedium.copyWith(color: c.onSurface),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: UnfurlType.monoLabel.copyWith(height: 1.4, color: c.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              ?toggle,
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// The bottom bar's frame: `surface`, a 1px outline above, the gesture
/// inset below.
class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(Space.lg, 14, Space.lg, 10),
    super.key,
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.outline)),
      ),
      padding: padding + EdgeInsets.only(bottom: math.max(16, MediaQuery.paddingOf(context).bottom)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.sm,
        children: children,
      ),
    );
  }
}

/// Page ⇄ Reader (or Slides ⇄ Reader). Page selected: `surface` thumb with
/// an outline; Reader selected: `primaryContainer`. Omitted, never
/// disabled, when a format has no Reader mode.
class ModeToggle extends StatelessWidget {
  const ModeToggle({required this.reader, required this.onChanged, this.pageIcon = AppIcons.article, super.key});

  final bool reader;
  final ValueChanged<bool> onChanged;
  final IconData pageIcon;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final Duration d = Motion.of(context, Motion.navIndicator);
    Widget item({required bool isReader}) {
      final bool on = reader == isReader;
      return Semantics(
        button: true,
        selected: on,
        label: isReader ? 'Reader mode' : 'Page view',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => onChanged(isReader),
          child: AnimatedContainer(
            duration: d,
            curve: Motion.curveOf(context, Motion.spring),
            width: 40,
            height: 38,
            decoration: BoxDecoration(
              color: on ? (isReader ? c.primaryContainer : c.surface) : c.surface.withValues(alpha: 0),
              borderRadius: Radii.fullR,
              border: Border.all(color: on && !isReader ? c.outline : c.outline.withValues(alpha: 0)),
            ),
            child: AppIcon(
              isReader ? AppIcons.wrapText : pageIcon,
              size: 20,
              color: on ? (isReader ? c.onPrimaryContainer : c.onSurface) : c.iconMuted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: Radii.fullR),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: <Widget>[item(isReader: false), item(isReader: true)],
      ),
    );
  }
}

/// The page or chapter scrubber (board 1, PageScrubber): a 4dp track with a
/// 4x20 thumb; dragging thickens it to 8 and 6x28 and floats a bubble with
/// a live label and preview. A tick marks where you were.
class PageScrubber extends StatefulWidget {
  const PageScrubber({
    required this.value,
    required this.onChanged,
    required this.label,
    this.startLabel,
    this.endLabel,
    this.tick,
    this.preview,
    this.onDragging,
    super.key,
  });

  /// 0..1.
  final double value;
  final ValueChanged<double> onChanged;

  /// The bubble's text for a value ("p. 298 · Ch. IX").
  final String Function(double v) label;
  final String Function(double v)? startLabel;
  final String? endLabel;

  /// The last position, 0..1, marked while dragging.
  final double? tick;
  final Widget Function(double v)? preview;
  final ValueChanged<bool>? onDragging;

  @override
  State<PageScrubber> createState() => _PageScrubberState();
}

class _PageScrubberState extends State<PageScrubber> {
  double? _drag;
  final LayerLink _link = LayerLink();
  OverlayEntry? _bubble;

  double get _v => _drag ?? widget.value;

  @override
  void dispose() {
    _bubble?.remove();
    super.dispose();
  }

  void _update(Offset local, double width) {
    setState(() => _drag = (local.dx / width).clamp(0, 1));
    _bubble?.markNeedsBuild();
  }

  void _start(Offset local, double width) {
    widget.onDragging?.call(true);
    _update(local, width);
    _bubble = OverlayEntry(builder: (BuildContext context) => _buildBubble(width));
    Overlay.of(context).insert(_bubble!);
  }

  void _end() {
    final double v = _v;
    _bubble?.remove();
    _bubble = null;
    setState(() => _drag = null);
    widget.onDragging?.call(false);
    widget.onChanged(v);
  }

  Widget _buildBubble(double width) {
    final UnfurlColors c = context.colors;
    return CompositedTransformFollower(
      link: _link,
      showWhenUnlinked: false,
      offset: Offset(width * _v - 60, widget.preview == null ? -52 : -196),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.sm,
            children: <Widget>[
              if (widget.preview != null)
                Container(
                  width: 96,
                  height: 136,
                  decoration: BoxDecoration(
                    border: Border.all(color: c.surface, width: 4),
                    boxShadow: <BoxShadow>[BoxShadow(color: c.outline, spreadRadius: 1)],
                  ),
                  child: widget.preview!(_v),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 7),
                decoration: BoxDecoration(color: c.inverseSurface, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  widget.label(_v),
                  maxLines: 1,
                  style: UnfurlType.monoLabel.copyWith(fontSize: 12, color: c.onInverseSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final bool dragging = _drag != null;
    final Duration d = Motion.of(context, Motion.fast);
    final TextStyle num = UnfurlType.monoLabel.copyWith(fontSize: 12, color: c.onSurfaceVariant);
    final Widget track = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double w = box.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (DragStartDetails e) => _start(e.localPosition, w),
          onHorizontalDragUpdate: (DragUpdateDetails e) => _update(e.localPosition, w),
          onHorizontalDragEnd: (_) => _end(),
          onTapUp: (TapUpDetails e) => widget.onChanged((e.localPosition.dx / w).clamp(0, 1)),
          child: CompositedTransformTarget(
            link: _link,
            child: SizedBox(
              height: IconSpec.tapTarget,
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: <Widget>[
                  AnimatedContainer(
                    duration: d,
                    height: dragging ? 8 : 4,
                    decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: Radii.fullR),
                  ),
                  AnimatedContainer(
                    duration: d,
                    height: dragging ? 8 : 4,
                    width: w * _v,
                    decoration: BoxDecoration(color: c.primary, borderRadius: Radii.fullR),
                  ),
                  if (dragging && widget.tick != null)
                    Positioned(
                      left: w * widget.tick! - 1,
                      top: 10,
                      child: Container(width: 2, height: 6, color: c.onSurfaceVariant),
                    ),
                  AnimatedPositioned(
                    duration: dragging ? Duration.zero : d,
                    left: w * _v - (dragging ? 3 : 2),
                    child: AnimatedContainer(
                      duration: d,
                      width: dragging ? 6 : 4,
                      height: dragging ? 28 : 20,
                      decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return Semantics(
      slider: true,
      value: widget.label(_v),
      child: Row(
        spacing: Space.md,
        children: <Widget>[
          if (widget.startLabel != null) Text(widget.startLabel!(_v), style: num),
          Expanded(child: track),
          if (widget.endLabel != null) Text(widget.endLabel!, style: num),
        ],
      ),
    );
  }
}

/// The small inverse chip: page numbers in immersive PDF, "Back to p. 62",
/// the font size while pinching.
class FloatingChip extends StatelessWidget {
  const FloatingChip({required this.text, this.onTap, this.icon, super.key});

  final String text;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Semantics(
      button: onTap != null,
      label: text,
      child: Material(
        color: c.inverseSurface,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: onTap == null ? 0 : 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: <Widget>[
                  if (icon != null) AppIcon(icon!, size: 16, color: c.onInverseSurface),
                  Text(text, style: UnfurlType.monoLabel.copyWith(fontSize: 12, color: c.onInverseSurface)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A chip that shows for a while, then fades (the page chip, "Back to").
class TimedChip extends StatefulWidget {
  const TimedChip({required this.text, required this.duration, this.onTap, this.icon, super.key});

  final String text;
  final Duration duration;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  State<TimedChip> createState() => _TimedChipState();
}

class _TimedChipState extends State<TimedChip> {
  bool _shown = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) setState(() => _shown = false);
    });
  }

  @override
  void didUpdateWidget(TimedChip old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _timer?.cancel();
      _shown = true;
      _timer = Timer(widget.duration, () {
        if (mounted) setState(() => _shown = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !_shown,
    child: AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: Motion.of(context, Motion.fast),
      child: FloatingChip(text: widget.text, onTap: widget.onTap, icon: widget.icon),
    ),
  );
}

/// Read aloud's docked player (board 1 MiniPlayer, R10): speed, previous
/// sentence, play or pause, next, close. 16dp above the gesture bar.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    required this.playing,
    required this.rate,
    required this.onToggle,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
    required this.onSpeed,
    super.key,
  });

  final bool playing;
  final double rate;
  final VoidCallback onToggle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;
  final VoidCallback onSpeed;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.sm, 6, 6, 6),
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: Radii.fullR,
        border: Border.all(color: c.outline),
        boxShadow: <BoxShadow>[
          BoxShadow(color: c.shadow, blurRadius: Elevations.navPillBlur, offset: const Offset(0, Elevations.navPill)),
        ],
      ),
      child: Row(
        spacing: 2,
        children: <Widget>[
          Semantics(
            button: true,
            label: 'Voice and speed, ${_rate(rate)}',
            excludeSemantics: true,
            child: InkWell(
              onTap: onSpeed,
              customBorder: const StadiumBorder(),
              child: Container(
                constraints: const BoxConstraints(minHeight: IconSpec.tapTarget, minWidth: IconSpec.tapTarget),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                child: Text(_rate(rate), style: UnfurlType.monoLabel.copyWith(fontSize: 12, color: c.onSurfaceVariant)),
              ),
            ),
          ),
          const Spacer(),
          AppIconButton(
            icon: AppIcons.skipPrevious,
            filled: false,
            semanticLabel: 'Previous sentence',
            onPressed: onPrevious,
          ),
          Semantics(
            button: true,
            label: playing ? 'Pause' : 'Play',
            excludeSemantics: true,
            child: Material(
              color: playing ? c.primary : c.primaryContainer,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onToggle,
                child: SizedBox.square(
                  dimension: 52,
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.fast),
                    child: AppIcon(
                      playing ? AppIcons.pause : AppIcons.play,
                      key: ValueKey<bool>(playing),
                      fill: true,
                      color: playing ? c.onPrimary : c.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
          AppIconButton(icon: AppIcons.skipNext, filled: false, semanticLabel: 'Next sentence', onPressed: onNext),
          const Spacer(),
          AppIconButton(icon: AppIcons.close, filled: false, semanticLabel: 'Stop reading aloud', onPressed: onClose),
        ],
      ),
    );
  }

  static String _rate(double r) => '${r == r.roundToDouble() ? r.toStringAsFixed(1) : r.toString()}x';
}

/// The selection toolbar (board 1, R9): Copy, the four highlight colours,
/// Note, Read aloud from here, Define in Mull. Floats above the selection,
/// or below it when there is no room.
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    required this.theme,
    required this.selectedColor,
    required this.onCopy,
    required this.onHighlight,
    required this.onNote,
    required this.onReadAloud,
    required this.onDefine,
    super.key,
  });

  final ReadingTheme theme;

  /// The colour of the highlight under the selection, if any.
  final int? selectedColor;
  final VoidCallback onCopy;
  final ValueChanged<int> onHighlight;
  final VoidCallback onNote;
  final VoidCallback? onReadAloud;
  final VoidCallback onDefine;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(Space.xs),
        decoration: BoxDecoration(
          color: c.surfaceContainerHigh,
          borderRadius: Radii.cardR,
          border: Border.all(color: c.outline),
          boxShadow: <BoxShadow>[
            BoxShadow(color: c.shadow, blurRadius: Elevations.navPillBlur, offset: const Offset(0, Elevations.navPill)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _Tool(icon: AppIcons.copy, label: 'Copy', onTap: onCopy),
            Row(
              spacing: 4,
              children: <Widget>[
                for (final HighlightColor h in HighlightColor.values)
                  Semantics(
                    button: true,
                    selected: selectedColor == h.index,
                    label: '${h.label} highlight',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => onHighlight(h.index),
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 30,
                        height: IconSpec.tapTarget,
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: theme.highlights[h.index],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == h.index ? c.primary : c.outline,
                                width: selectedColor == h.index ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            _Tool(icon: AppIcons.editNote, label: 'Note', onTap: onNote),
            if (onReadAloud != null)
              _Tool(icon: AppIcons.readAloud, label: 'Read aloud from here', onTap: onReadAloud!),
            Semantics(
              button: true,
              label: 'Define in Mull',
              excludeSemantics: true,
              child: AppTooltip(
                message: 'Define in Mull',
                child: InkWell(
                  onTap: onDefine,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 44,
                    height: IconSpec.tapTarget,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset('assets/images/mull.png', width: 24, height: 24, cacheWidth: 72),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: AppTooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: IconSpec.tapTarget,
          child: Center(child: AppIcon(icon, size: 22, color: context.colors.icon)),
        ),
      ),
    ),
  );
}
