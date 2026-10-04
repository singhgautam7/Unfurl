import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/option_tiles.dart';
import '../files/files_widgets.dart';
import 'sheets.dart';

/// Board 6, V6: the sleep timer. A length (15 to 60 min) or the end of the
/// chapter; the last 10 s fade the volume to 0, then [onExpire] pauses read
/// aloud or auto-scroll. A touch during the fade restarts it. Dart timers
/// keep running while the app is in the background, as read aloud does.
class SleepTimer extends ChangeNotifier {
  SleepTimer({required this.onExpire, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final VoidCallback onExpire;
  final DateTime Function() _clock;

  /// Minutes, or null for the end of the chapter; [active] says whether set.
  int? minutes;
  bool active = false;
  bool get chapter => active && minutes == null;
  DateTime? _endsAt;
  Timer? _tick;

  Duration get remaining {
    final DateTime? e = _endsAt;
    if (e == null) return Duration.zero;
    final Duration d = e.difference(_clock());
    return d.isNegative ? Duration.zero : d;
  }

  /// In the last 10 s.
  bool get fading => active && !chapter && remaining <= Motion.sleepFade;

  /// 1 until the fade, then down to 0.
  double get volume => fading ? (remaining.inMilliseconds / Motion.sleepFade.inMilliseconds).clamp(0, 1).toDouble() : 1;

  /// "12:40", "0:08"; "Chapter" for the end of the chapter.
  String get label {
    if (chapter) return 'Chapter';
    final Duration r = remaining;
    return '${r.inMinutes}:${(r.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  void set(int? minutes) {
    this.minutes = minutes;
    active = true;
    _tick?.cancel();
    if (minutes == null) {
      _endsAt = null;
    } else {
      _endsAt = _clock().add(Duration(minutes: minutes));
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    }
    notifyListeners();
  }

  void cancel() {
    active = false;
    minutes = null;
    _endsAt = null;
    _tick?.cancel();
    notifyListeners();
  }

  /// The reader touched the page during the fade: start over.
  void touched() {
    if (fading) set(minutes);
  }

  /// End of chapter: called when reading passes the chapter's end.
  void chapterEnded() {
    if (!chapter) return;
    cancel();
    onExpire();
  }

  void _onTick() {
    if (remaining == Duration.zero) {
      cancel();
      onExpire();
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

/// Board 6, V6: auto-scroll (continuous modes: a frame-synced scroll at one
/// of nine speeds) and auto page turn (paged modes: a turn every interval).
/// Touching the page pauses it. Each tick is activity for the tracker.
class AutoAdvance extends ChangeNotifier {
  AutoAdvance({
    required TickerProvider vsync,
    required this.paged,
    required this.scrollBy,
    required this.turn,
    this.level = ComfortSpec.defaultLevel,
    this.seconds = ComfortSpec.defaultTurn,
    this.onTick,
  }) {
    _ticker = vsync.createTicker(_frame);
  }

  /// Paged (auto page turn) or continuous (auto-scroll).
  bool paged;

  /// Scrolls by logical pixels; false at the end.
  final bool Function(double pixels) scrollBy;

  /// Turns one page forward; false at the end.
  final bool Function() turn;
  final VoidCallback? onTick;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Duration _since = Duration.zero;

  /// The speed level, 1 to 9.
  int level;

  /// Auto page turn's interval.
  int seconds;

  /// On at all (the control shows), and moving.
  bool enabled = false;
  bool running = false;

  /// Paused by a touch: the control shows "Paused. Tap play to go on."
  bool pausedByTouch = false;

  /// The control is in view (it hides 2.5 s after the last change).
  bool shown = false;
  Timer? _hide;

  /// "4" (a speed level) or "30s".
  String get readout => paged ? '${seconds}s' : '$level';

  double get _speed => ComfortSpec.scrollSpeeds[(level - 1).clamp(0, ComfortSpec.scrollSpeeds.length - 1)];

  void enable({required bool on}) {
    enabled = on;
    on ? play() : pause();
    if (!on) shown = false;
    notifyListeners();
  }

  void play() {
    if (!enabled) return;
    running = true;
    pausedByTouch = false;
    _last = Duration.zero;
    _since = Duration.zero;
    if (!_ticker.isActive) unawaited(_ticker.start());
    show();
  }

  void pause({bool byTouch = false}) {
    running = false;
    pausedByTouch = byTouch && enabled;
    if (_ticker.isActive) _ticker.stop();
    if (enabled) show(hide: false);
    notifyListeners();
  }

  void toggle() => running ? pause() : play();

  /// One step slower (−) or faster (+): a speed level, or the interval.
  void step(int delta) {
    if (paged) {
      const List<int> t = ComfortSpec.turnSeconds;
      final int i = (t.indexOf(seconds) - delta).clamp(0, t.length - 1);
      seconds = t[i];
    } else {
      level = (level + delta).clamp(1, ComfortSpec.scrollSpeeds.length);
    }
    show();
  }

  void setSeconds(int s) {
    seconds = s;
    notifyListeners();
  }

  /// Shows the control; it hides again after 2.5 s while running.
  void show({bool hide = true}) {
    shown = true;
    _hide?.cancel();
    if (hide && running) {
      _hide = Timer(Motion.autoControlHide, () {
        shown = false;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void _frame(Duration elapsed) {
    final Duration dt = _last == Duration.zero ? Duration.zero : elapsed - _last;
    _last = elapsed;
    _since += dt;
    if (paged) {
      if (_since >= Duration(seconds: seconds)) {
        _since = Duration.zero;
        onTick?.call();
        if (!turn()) pause();
      }
      return;
    }
    // Eases up to speed over the ramp, so starting never jerks.
    final double ramp = (_since.inMicroseconds / Motion.autoScrollRamp.inMicroseconds).clamp(0, 1);
    final double px = _speed * ramp * dt.inMicroseconds / 1e6;
    if (px > 0 && !scrollBy(px)) pause();
    if (_since.inSeconds != (_since - dt).inSeconds) onTick?.call();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _ticker.dispose();
    super.dispose();
  }
}

/// The floating auto-scroll control (board 6, V6 `float`): play/pause, − and
/// +, and the readout, with a hint above it when a touch paused it.
class AutoControl extends StatelessWidget {
  const AutoControl({required this.auto, super.key});

  final AutoAdvance auto;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return ListenableBuilder(
      listenable: auto,
      builder: (BuildContext context, Widget? _) => IgnorePointer(
        ignoring: !auto.shown,
        child: AnimatedOpacity(
          opacity: auto.shown ? 1 : 0,
          duration: Motion.of(context, Motion.fast),
          curve: Motion.decelerate,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: Space.sm,
            children: <Widget>[
              if (auto.pausedByTouch)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                  decoration: BoxDecoration(color: c.inverseSurface, borderRadius: BorderRadius.circular(Space.md)),
                  child: Text(
                    'Paused. Tap play to go on.',
                    style: UnfurlType.label.copyWith(fontSize: 12.5, color: c.onInverseSurface),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(Space.xs),
                decoration: BoxDecoration(
                  color: c.surfaceContainer,
                  borderRadius: Radii.fullR,
                  border: Border.all(color: c.outline),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: c.shadow,
                      blurRadius: Elevations.navPillBlur,
                      offset: const Offset(0, Elevations.navPill),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Semantics(
                      button: true,
                      label: auto.running ? 'Pause' : (auto.paged ? 'Start auto page turn' : 'Start auto-scroll'),
                      excludeSemantics: true,
                      child: Material(
                        color: c.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: auto.toggle,
                          child: SizedBox.square(
                            dimension: IconSpec.button,
                            child: AppIcon(
                              auto.running ? AppIcons.pause : AppIcons.play,
                              fill: true,
                              color: c.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _Step(
                      icon: AppIcons.remove,
                      label: auto.paged ? 'Turn less often' : 'Slower',
                      onTap: () => auto.step(-1),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 30),
                      child: Text(
                        auto.readout,
                        textAlign: TextAlign.center,
                        semanticsLabel: auto.paged ? 'Every ${auto.seconds} seconds' : 'Speed ${auto.level} of 9',
                        style: UnfurlType.monoLabel
                            .copyWith(fontSize: 12, color: c.onSurface)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _Step(
                      icon: AppIcons.add,
                      label: auto.paged ? 'Turn more often' : 'Faster',
                      onTap: () => auto.step(1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkResponse(
      onTap: onTap,
      radius: 22,
      child: SizedBox(
        width: 40,
        height: IconSpec.tapTarget,
        child: AppIcon(icon, color: context.colors.icon),
      ),
    ),
  );
}

/// The mini player's time-left chip (board 6, V6 `mini`): the bedtime glyph
/// and m:ss; in the fade, `primary` with the volume glyph.
class SleepChip extends StatelessWidget {
  const SleepChip({required this.timer, required this.onTap, super.key});

  final SleepTimer timer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return ListenableBuilder(
      listenable: timer,
      builder: (BuildContext context, Widget? _) {
        final bool fading = timer.fading;
        return Semantics(
          button: true,
          label: timer.active
              ? 'Sleep timer, ${timer.chapter ? 'end of chapter' : '${timer.label} left'}'
              : 'Sleep timer',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.fast),
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: fading ? c.primary : c.surfaceContainerHigh, borderRadius: Radii.fullR),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: Space.xs,
                children: <Widget>[
                  AppIcon(
                    fading ? AppIcons.volumeDown : AppIcons.bedtime,
                    size: 16,
                    color: fading ? c.onPrimary : c.onSurface,
                  ),
                  if (timer.active)
                    Text(
                      timer.label,
                      style: UnfurlType.monoLabel
                          .copyWith(fontSize: 12, color: fading ? c.onPrimary : c.onSurface)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Board 6, V6: "Sleep timer". [chapterLeft] is the meta under End of
/// chapter ("Chapter 1 · about 6 min left").
Future<void> showSleepTimerSheet(
  BuildContext context,
  SleepTimer timer, {
  String? chapterLeft,
  bool readAloud = true,
}) => showReaderSheet<void>(
  context,
  surface: true,
  (BuildContext ctx) => ListenableBuilder(
    listenable: timer,
    builder: (BuildContext ctx, Widget? _) {
      final UnfurlColors c = ctx.colors;
      Widget radio(String label, {required bool on, required VoidCallback onTap, String? meta}) => Semantics(
        inMutuallyExclusiveGroup: true,
        checked: on,
        button: true,
        label: label,
        child: InkWell(
          onTap: () {
            onTap();
            Navigator.of(ctx).pop();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.lg, Space.sm),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(label, style: UnfurlType.titleMedium.copyWith(color: c.onSurface).weight(on ? 600 : 500)),
                        if (meta != null) Text(meta, style: UnfurlType.bodySmall.copyWith(color: c.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  AppIcon(on ? AppIcons.radioOn : AppIcons.radioOff, fill: on, color: on ? c.primary : c.iconMuted),
                ],
              ),
            ),
          ),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SheetHead(
            title: 'Sleep timer',
            subtitle: readAloud
                ? 'Read aloud stops when the timer ends. The last 10 seconds fade out.'
                : 'Auto-scroll stops when the timer ends.',
          ),
          radio('Off', on: !timer.active, onTap: timer.cancel),
          for (final int m in ComfortSpec.sleepMinutes)
            radio('$m min', on: timer.active && timer.minutes == m, onTap: () => timer.set(m)),
          radio('End of chapter', on: timer.chapter, meta: chapterLeft, onTap: () => timer.set(null)),
        ],
      );
    },
  ),
);

/// Board 6, V6 "Reading": auto page turn (paged) or auto-scroll
/// (continuous), its interval, and the sleep timer.
Future<void> showComfortSheet(
  BuildContext context, {
  required AutoAdvance auto,
  required SleepTimer timer,
  required VoidCallback onSleep,
}) => showReaderSheet<void>(
  context,
  surface: true,
  (BuildContext ctx) => ListenableBuilder(
    listenable: Listenable.merge(<Listenable>[auto, timer]),
    builder: (BuildContext ctx, Widget? _) {
      final UnfurlColors c = ctx.colors;
      const List<int> t = ComfortSpec.turnSeconds;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SheetHead(title: 'Reading'),
          ExplorerRow(
            name: auto.paged ? 'Auto page turn' : 'Auto-scroll',
            meta: auto.paged
                ? 'Turns the page on a timer. Touch the page to pause.'
                : 'Scrolls at a steady speed. Touch the page to pause.',
            sansMeta: true,
            switchValue: auto.enabled,
            onSwitch: (bool v) => auto.enable(on: v),
          ),
          if (auto.paged)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 10, Space.screen, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('Turn every', style: UnfurlType.titleMedium.copyWith(fontSize: 14, color: c.onSurface)),
                      Text(
                        '${auto.seconds} s',
                        style: UnfurlType.monoLabel.copyWith(fontSize: 12, color: c.onSurfaceVariant),
                      ),
                    ],
                  ),
                  Slider(
                    value: t.indexOf(auto.seconds).clamp(0, t.length - 1).toDouble(),
                    max: (t.length - 1).toDouble(),
                    divisions: t.length - 1,
                    semanticFormatterCallback: (double v) => 'Every ${t[v.round()]} seconds',
                    onChanged: (double v) => auto.setSeconds(t[v.round()]),
                  ),
                ],
              ),
            ),
          ExplorerRow(
            name: 'Sleep timer',
            status: timer.active ? (timer.chapter ? 'Chapter' : '${timer.minutes} min') : 'Off',
            trailing: AppIcons.chevronRight,
            onTap: () {
              Navigator.of(ctx).pop();
              onSleep();
            },
          ),
        ],
      );
    },
  ),
);
