import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'session.dart';
import 'stats_store.dart';

export 'stats_store.dart' show Speeds;

/// Counts reading, independent of any screen (board 6, V1 rules). A reader
/// or viewer [open]s when it comes to the front and [close]s when it goes;
/// between, it reports activity, progress and read aloud. The tracker keeps
/// the clock (idle, background, screen off), checkpoints the open session
/// every 60 s and on pause, and folds each finished session into the
/// aggregates once. Images and spreadsheets never open a session.
class ReadingSessionTracker with WidgetsBindingObserver {
  ReadingSessionTracker(this.store, {DateTime Function()? clock, this.toLocal}) : _clock = clock ?? DateTime.now;

  final StatsStore store;
  final DateTime Function() _clock;
  final DateTime Function(DateTime utc)? toLocal;

  static const Duration checkpointEvery = Duration(seconds: 60);
  static const Duration _tickEvery = Duration(seconds: 15);

  LiveSession? _session;
  _Context? _context;
  Object? _owner;
  Timer? _tick;
  DateTime? _checkpointed;
  bool _observing = false;
  bool _listening = false;

  /// Bumped when a session is folded in, so Insights can refresh.
  final ValueNotifier<int> folded = ValueNotifier<int>(0);

  @visibleForTesting
  LiveSession? get session => _session;

  DateTime get _now => _clock();

  /// A reader came to the front with [fingerprint] open.
  ///
  /// [owner] (the reader's State) is the only one that can close it, so a
  /// reader leaving after the next one opened can't end the new session.
  Future<void> open({
    required Object owner,
    required String fingerprint,
    required String format,
    required String mode,
    int Function(int from, int to)? wordsBetween,
    int? startIndex,
    int? startPage,
    String? fromLocator,
  }) async {
    await close();
    _owner = owner;
    final int median = await store.medianPageMs(fingerprint);
    if (_owner != owner) return;
    _context = _Context(
      fingerprint: fingerprint,
      format: format,
      mode: mode,
      idle: TrackingRules.idleFor(median),
      wordsBetween: wordsBetween,
      index: startIndex,
      page: startPage,
      locator: fromLocator,
    );
    _start();
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _tick ??= Timer.periodic(_tickEvery, (_) => unawaited(_onTick()));
  }

  void _start() {
    final _Context c = _context!;
    _session = LiveSession(
      fingerprint: c.fingerprint,
      format: c.format,
      mode: c.mode,
      now: _now,
      idle: c.idle,
      wordsBetween: c.wordsBetween,
      startIndex: c.index,
      startPage: c.page,
      fromLocator: c.locator,
      toLocal: toLocal,
    );
    if (_listening) _session!.setListening(_now, on: true);
    _checkpointed = _now;
  }

  /// The session for the open document, restarted after a long gap.
  LiveSession? get _live {
    if (_context == null) return null;
    if (_session == null) _start();
    return _session;
  }

  /// A touch, scroll, zoom, selection or auto-scroll tick.
  void activity() => _live?.activity(_now);

  /// Reader mode moved to a global character index.
  void readerAt(int index, {bool jump = false, String? locator, Object? owner}) {
    if (owner != null && owner != _owner) return;
    final LiveSession? s = _live;
    if (s == null) return;
    s.readerAt(_now, index, jump: jump);
    _context!.index = index;
    if (locator != null) s.toLocator = _context!.locator = locator;
  }

  /// Page view or comics moved to a page (0-based).
  void pageAt(int page, {bool jump = false, String? locator, Object? owner}) {
    if (owner != null && owner != _owner) return;
    final LiveSession? s = _live;
    if (s == null) return;
    s.pageAt(_now, page, jump: jump);
    _context!.page = page;
    if (locator != null) s.toLocator = _context!.locator = locator;
  }

  /// Read aloud started or stopped.
  void listening({required bool on}) {
    _listening = on;
    _live?.setListening(_now, on: on);
  }

  /// The reader closed: the session ends and is folded in (or dropped).
  /// With an [owner], only that reader's session closes.
  Future<void> close([Object? owner]) async {
    if (owner != null && owner != _owner) return;
    _owner = null;
    final LiveSession? s = _session;
    _session = null;
    _context = null;
    _listening = false;
    _tick?.cancel();
    _tick = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    if (s == null) return;
    s.end(_now);
    await _finish(s);
  }

  Future<void> _finish(LiveSession s) async {
    await store.finish(s, _now);
    if (s.counts) folded.value++;
  }

  Future<void> _onTick() async {
    final LiveSession? s = _session;
    if (s == null) return;
    final DateTime now = _now;
    // Paused long enough: this session is over; the next touch starts another.
    if (!s.listening && now.difference(s.lastActivity) > s.idle + TrackingRules.sessionGap) {
      _session = null;
      s.end(now);
      await _finish(s);
      return;
    }
    if (now.difference(_checkpointed!) >= checkpointEvery) await checkpoint();
  }

  @visibleForTesting
  Future<void> checkpoint() async {
    final LiveSession? s = _session;
    if (s == null) return;
    s.flush(_now);
    _checkpointed = _now;
    await store.checkpoint(s, _now);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final LiveSession? s = _session;
    if (s == null) return;
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        s.background(_now);
        unawaited(checkpoint());
      case AppLifecycleState.resumed:
        s.foreground(_now);
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  /// Speeds for time-left estimates (this book's, else the reader's own).
  Future<Speeds> speeds(String fingerprint) => store.speeds(fingerprint);

  /// At launch: sessions a crash left open are folded in.
  Future<void> recover() async {
    if (await store.recover() > 0) folded.value++;
  }
}

class _Context {
  _Context({
    required this.fingerprint,
    required this.format,
    required this.mode,
    required this.idle,
    this.wordsBetween,
    this.index,
    this.page,
    this.locator,
  });

  final String fingerprint;
  final String format;
  final String mode;
  final Duration idle;
  final int Function(int from, int to)? wordsBetween;
  int? index;
  int? page;
  String? locator;
}

final Provider<ReadingSessionTracker> trackerProvider = Provider<ReadingSessionTracker>(
  (Ref ref) => ReadingSessionTracker(StatsStore(ref.watch(databaseProvider))),
);

/// Any touch or scroll inside counts as activity for the open session.
class TrackActivity extends ConsumerWidget {
  const TrackActivity({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReadingSessionTracker t = ref.read(trackerProvider);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => t.activity(),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (_) {
          t.activity();
          return false;
        },
        child: child,
      ),
    );
  }
}

/// A page-based view (PDF Page view, DOCX pages, slides, comics) that counts
/// while it is on screen: a session opens when it mounts and closes when it
/// goes (Reader mode replacing it opens its own), and each [page] change is
/// reported. Touches and scrolls inside are activity.
class TrackedPages extends ConsumerStatefulWidget {
  const TrackedPages({
    required this.fingerprint,
    required this.format,
    required this.page,
    required this.child,
    this.mode = 'page',
    super.key,
  });

  final String fingerprint;
  final String format;

  /// 'page' or 'comics'.
  final String mode;

  /// 0-based.
  final int page;
  final Widget child;

  @override
  ConsumerState<TrackedPages> createState() => _TrackedPagesState();
}

class _TrackedPagesState extends ConsumerState<TrackedPages> {
  late final ReadingSessionTracker _tracker = ref.read(trackerProvider);

  @override
  void initState() {
    super.initState();
    unawaited(
      _tracker.open(
        owner: this,
        fingerprint: widget.fingerprint,
        format: widget.format,
        mode: widget.mode,
        startPage: widget.page,
      ),
    );
  }

  @override
  void didUpdateWidget(TrackedPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) _tracker.pageAt(widget.page, owner: this);
  }

  @override
  void dispose() {
    unawaited(_tracker.close(this));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TrackActivity(child: widget.child);
}
