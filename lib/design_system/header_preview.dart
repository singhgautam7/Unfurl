import 'dart:async';

import 'package:flutter/material.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import '../features/settings/settings_controller.dart' show PillMode;
import 'app_header.dart';
import 'app_icon.dart';
import 'buttons.dart';

/// The mini page's geometry, after Kuber's `_MiniPage`
/// (`floating_header_sheet.dart`): a 360 x 553 page drawn at 300 / 360 and
/// clipped to its top 300 x 72.
abstract final class _Mini {
  static const double shownWidth = 300;
  static const double shownHeight = 72;
  static const double pageWidth = 360;
  static const double pageHeight = 553;
  static const double statusBar = 16;
  static const int rows = 12;
  static const double rowHeight = 64;
  static const double iconBox = 40;
  static const double line = 12;
  static const double subline = 10;
  static const double lineFraction = 0.4;
  static const double toneAlpha = 0.24;
  static const double lineAlpha = 0.7;
  static const double sublineAlpha = 0.5;
  static const int widthSteps = 8;

  /// The scripted scroll (Kuber's `_script`, in steps of `Motion.fast`): wait,
  /// down to 300, pause, up to 220, pause, back to the top, pause. A null
  /// offset is a pause.
  static final List<(Duration, double?)> script = <(Duration, double?)>[
    (Motion.fast * 3, null),
    (Motion.fast * 7, 300),
    (Motion.fast * 6, null),
    (Motion.fast * 3, 220),
    (Motion.fast * 6, null),
    (Motion.fast * 7, 0),
    (Motion.fast * 5, null),
  ];
}

/// One choice of "Show the pill": a radio, its name, and a live mini page
/// running the real floating header over a scripted scroll. Disabled (the
/// Floating header switch is off), it previews the header scrolling away.
class HeaderPreviewCard extends StatelessWidget {
  const HeaderPreviewCard({
    required this.label,
    required this.pillMode,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String label;
  final PillMode pillMode;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final ShapeBorder shape = RoundedRectangleBorder(
      borderRadius: Radii.cardR,
      side: BorderSide(color: selected ? c.primary : c.outline, width: selected ? 2 : 1),
    );
    return AnimatedOpacity(
      opacity: enabled ? 1 : Opacities.disabled,
      duration: Motion.of(context, Motion.fast),
      child: Semantics(
        container: true,
        excludeSemantics: true,
        button: true,
        enabled: enabled,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: '$label. Preview of the pill',
        onTap: enabled ? onTap : null,
        child: Material(
          color: selected ? c.primaryContainer : c.surfaceContainer,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            customBorder: shape,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: IconSpec.tapTarget),
                    child: Row(
                      spacing: Space.md,
                      children: <Widget>[
                        AppIcon(
                          selected ? AppIcons.radioOn : AppIcons.radioOff,
                          color: selected ? c.primary : c.onSurfaceVariant,
                        ),
                        Expanded(
                          child: Text(
                            label,
                            style: UnfurlType.titleMedium.copyWith(
                              color: selected ? c.onPrimaryContainer : c.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    // Floating header off previews the header scrolling away.
                    child: HeaderMiniPage(floating: enabled, pillMode: pillMode),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The real [HeaderPage] on a scaled mini page, scrolled by a script. It
/// follows the Motion level, and runs only while it is on screen and its
/// route is showing (it waits otherwise, and holds no timer when disposed).
class HeaderMiniPage extends StatefulWidget {
  const HeaderMiniPage({required this.floating, required this.pillMode, super.key});

  final bool floating;
  final PillMode pillMode;

  @override
  State<HeaderMiniPage> createState() => _HeaderMiniPageState();
}

class _HeaderMiniPageState extends State<HeaderMiniPage> {
  final ScrollController _sc = ScrollController();
  Timer? _timer;
  int _step = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // After the first frame, so the list has a position to scroll.
    WidgetsBinding.instance.addPostFrameCallback((_) => _next());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sc.dispose();
    super.dispose();
  }

  /// Mounted, shown (not under another route) and inside the window.
  bool get _active {
    if (!mounted || !_sc.hasClients || !TickerMode.valuesOf(context).enabled) return false;
    final RenderObject? ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return false;
    return (ro.localToGlobal(Offset.zero) & ro.size).overlaps(Offset.zero & MediaQuery.sizeOf(context));
  }

  void _next() {
    _timer?.cancel();
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Remove animations: the page rests where the first scroll ends.
      if (_sc.hasClients) _sc.jumpTo(_Mini.script[1].$2!);
      return;
    }
    if (!_active) {
      _timer = Timer(Motion.chipZoom, _next);
      return;
    }
    final (Duration d, double? y) = _Mini.script[_step];
    _step = (_step + 1) % _Mini.script.length;
    if (y == null) {
      _timer = Timer(d, _next);
    } else {
      // A real scroll activity, so the header sees continuous updates.
      unawaited(_sc.animateTo(y, duration: d, curve: Motion.standard).whenComplete(_next));
    }
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final MediaQueryData mq = MediaQuery.of(context);
    const EdgeInsets top = EdgeInsets.only(top: _Mini.statusBar);
    final List<Color> tones = <Color>[c.primary, c.accent, c.success, c.danger];
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          width: _Mini.shownWidth,
          height: _Mini.shownHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: Radii.boxR,
            border: Border.all(color: c.outline),
          ),
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: _Mini.pageWidth,
            maxWidth: _Mini.pageWidth,
            minHeight: _Mini.pageHeight,
            maxHeight: _Mini.pageHeight,
            child: Transform.scale(
              scale: _Mini.shownWidth / _Mini.pageWidth,
              alignment: Alignment.topLeft,
              child: MediaQuery(
                data: mq.copyWith(
                  size: const Size(_Mini.pageWidth, _Mini.pageHeight),
                  padding: top,
                  viewPadding: top,
                  viewInsets: EdgeInsets.zero,
                  textScaler: TextScaler.noScaling,
                ),
                child: Material(
                  color: c.surface,
                  child: HeaderPage(
                    floating: widget.floating,
                    pillMode: widget.pillMode,
                    header: AppHeader(
                      title: 'Library',
                      onBack: () {},
                      actions: <Widget>[
                        AppIconButton(icon: AppIcons.search, semanticLabel: 'Search', onPressed: () {}),
                        AppIconButton(icon: AppIcons.moreHoriz, semanticLabel: 'More options', onPressed: () {}),
                      ],
                    ),
                    body: (BuildContext context, double inset) => ListView(
                      clipBehavior: Clip.none,
                      controller: _sc,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(Space.screen, inset, Space.screen, 0),
                      children: <Widget>[for (int i = 0; i < _Mini.rows; i++) _row(c, i, tones[i % tones.length])],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _row(UnfurlColors c, int i, Color tone) => Container(
    height: _Mini.rowHeight,
    margin: const EdgeInsets.only(bottom: Space.xs),
    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
    decoration: BoxDecoration(
      color: c.surfaceContainer,
      borderRadius: Radii.thumbR,
      border: Border.all(color: c.outline),
    ),
    child: Row(
      spacing: Space.lg,
      children: <Widget>[
        Container(
          width: _Mini.iconBox,
          height: _Mini.iconBox,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: _Mini.toneAlpha),
            borderRadius: Radii.boxR,
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Space.sm,
            children: <Widget>[
              FractionallySizedBox(
                widthFactor: (i % 5 + 3) / _Mini.widthSteps,
                child: Container(
                  height: _Mini.line,
                  decoration: BoxDecoration(
                    color: c.onSurface.withValues(alpha: _Mini.lineAlpha),
                    borderRadius: Radii.fullR,
                  ),
                ),
              ),
              FractionallySizedBox(
                widthFactor: _Mini.lineFraction,
                child: Container(
                  height: _Mini.subline,
                  decoration: BoxDecoration(
                    color: c.onSurfaceVariant.withValues(alpha: _Mini.sublineAlpha),
                    borderRadius: Radii.fullR,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
