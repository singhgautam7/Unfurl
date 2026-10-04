import 'dart:math' as math;

/// The spec's rules (board 6, V1; `unfurl-v3-tokens.js` › `insights`) and the
/// adaptive idle threshold (docs/v3-decisions.md 7).
abstract final class TrackingRules {
  /// Shorter visits aren't sessions and add no time.
  static const Duration minSession = Duration(seconds: 30);

  /// No touch, scroll or page change for this long stops the clock, before a
  /// document has a median page time.
  static const Duration defaultIdle = Duration(seconds: 120);
  static const Duration minIdle = Duration(seconds: 60);
  static const Duration maxIdle = Duration(minutes: 5);

  /// Paused this long (idle or away), the session ends; the next touch starts
  /// a new one.
  static const Duration sessionGap = Duration(minutes: 10);

  /// A page or screen counts (and feeds the median) after this long on it.
  static const Duration minDwell = Duration(seconds: 2);
  static const Duration maxDwell = Duration(minutes: 10);

  /// Forward progress faster than this is a jump, not reading.
  static const int maxWordsPerMinute = 1500;

  /// 3x the median time per page or screen, within [minIdle, maxIdle].
  static Duration idleFor(int medianPageMs) {
    if (medianPageMs <= 0) return defaultIdle;
    final int ms = (medianPageMs * 3).clamp(minIdle.inMilliseconds, maxIdle.inMilliseconds);
    return Duration(milliseconds: ms);
  }
}

/// yyyymmdd for a local date.
int dayKey(DateTime local) => local.year * 10000 + local.month * 100 + local.day;

DateTime dayOfKey(int key) => DateTime(key ~/ 10000, key ~/ 100 % 100, key % 100);

/// One reading session in memory: time credited in segments, split at local
/// hour boundaries (so days and time of day are exact, across midnight and a
/// timezone change), forward-only progress, and page dwell samples. Pure:
/// every method takes the time, so tests drive it without waiting.
class LiveSession {
  LiveSession({
    required this.fingerprint,
    required this.format,
    required this.mode,
    required DateTime now,
    this.idle = TrackingRules.defaultIdle,
    this.wordsBetween,
    this.startIndex,
    this.startPage,
    this.fromLocator,
    DateTime Function(DateTime utc)? toLocal,
  }) : startedAt = now.toUtc(),
       _toLocal = toLocal ?? ((DateTime d) => d.toLocal()),
       _lastActivity = now.toUtc(),
       _lastMove = now.toUtc() {
    _runFrom = startedAt;
    _maxIndex = startIndex;
    _page = startPage;
    startDay = dayKey(_toLocal(startedAt));
    startHour = _toLocal(startedAt).hour;
  }

  final String fingerprint;

  /// Registry id, for the formats breakdown.
  final String format;

  /// 'reader', 'page' or 'comics'.
  final String mode;
  final DateTime startedAt;
  late final int startDay;
  late final int startHour;
  final Duration idle;

  /// Words between two global character indexes (Reader mode).
  final int Function(int from, int to)? wordsBetween;
  final int? startIndex;
  final int? startPage;
  final String? fromLocator;
  final DateTime Function(DateTime utc) _toLocal;

  /// Database row once checkpointed.
  int? rowId;

  DateTime? _runFrom;
  DateTime? _listenFrom;
  DateTime _lastActivity;
  DateTime _lastMove;
  bool _foreground = true;

  int activeMs = 0;
  int listeningMs = 0;

  /// Reading ms by local day, and by local day and hour.
  final Map<int, int> dayMs = <int, int>{};
  final Map<int, int> dayListenMs = <int, int>{};
  final Map<int, List<int>> dayHourMs = <int, List<int>>{};

  int words = 0;
  final Set<int> pages = <int>{};
  final List<int> dwellSamples = <int>[];
  int? _maxIndex;
  int? _page;
  String? toLocator;

  bool get reading => _runFrom != null;
  bool get listening => _listenFrom != null;
  DateTime get lastActivity => _lastActivity;
  int get totalMs => activeMs + listeningMs;

  void _credit(DateTime from, DateTime to, {required bool listen}) {
    DateTime cursor = from;
    while (cursor.isBefore(to)) {
      final DateTime local = _toLocal(cursor);
      // A test's shifted UTC clock stands in for a timezone: stay in its frame.
      final DateTime nextHour = local.isUtc
          ? DateTime.utc(local.year, local.month, local.day, local.hour + 1)
          : DateTime(local.year, local.month, local.day, local.hour + 1);
      final DateTime segEnd = cursor.add(nextHour.difference(local));
      final DateTime end = segEnd.isBefore(to) && segEnd.isAfter(cursor) ? segEnd : to;
      final int ms = end.difference(cursor).inMilliseconds;
      final int day = dayKey(local);
      if (listen) {
        listeningMs += ms;
        dayListenMs[day] = (dayListenMs[day] ?? 0) + ms;
      } else {
        activeMs += ms;
        dayMs[day] = (dayMs[day] ?? 0) + ms;
        (dayHourMs[day] ??= List<int>.filled(24, 0))[local.hour] += ms;
      }
      cursor = end;
    }
  }

  /// Reading time stops a third of the threshold (about one median page)
  /// after the last activity, not when the idle is noticed.
  DateTime _idleEnd() => _lastActivity.add(idle ~/ 3);

  /// Credits what is running up to [now] and keeps it running: before a
  /// checkpoint, and when the idle check finds the reader gone.
  void flush(DateTime now) {
    final DateTime t = now.toUtc();
    if (_runFrom != null) {
      final bool idled = t.difference(_lastActivity) > idle;
      final DateTime end = idled ? _idleEnd() : t;
      if (end.isAfter(_runFrom!)) _credit(_runFrom!, end, listen: false);
      _runFrom = idled ? null : t;
    }
    if (_listenFrom != null) {
      _credit(_listenFrom!, t, listen: true);
      _listenFrom = t;
    }
  }

  /// A touch, scroll, zoom, selection, page change or auto-scroll tick.
  void activity(DateTime now) {
    final DateTime t = now.toUtc();
    if (_runFrom != null && t.difference(_lastActivity) > idle) flush(t);
    _lastActivity = t;
    if (_runFrom == null && _foreground && _listenFrom == null) _runFrom = t;
  }

  /// The app went to the background or the screen turned off.
  void background(DateTime now) {
    flush(now);
    if (_runFrom != null) {
      _runFrom = null;
    }
    _foreground = false;
  }

  void foreground(DateTime now) {
    _foreground = true;
    activity(now);
  }

  /// Read aloud started or stopped: listening is counted apart from reading,
  /// never both at once. It goes on in the background.
  void setListening(DateTime now, {required bool on}) {
    final DateTime t = now.toUtc();
    flush(t);
    if (on && _listenFrom == null) {
      _runFrom = null;
      _listenFrom = t;
    } else if (!on && _listenFrom != null) {
      _listenFrom = null;
      _lastActivity = t;
      if (_foreground) _runFrom = t;
    }
  }

  void _sample(DateTime t) {
    final int dwell = t.difference(_lastMove).inMilliseconds;
    if (dwell >= TrackingRules.minDwell.inMilliseconds && dwell <= TrackingRules.maxDwell.inMilliseconds) {
      dwellSamples.add(dwell);
    }
    _lastMove = t;
  }

  /// Reader mode moved to global character [index]. Only reading past the
  /// furthest point counts; a [jump] (scrubber, contents, link) moves the
  /// furthest point without counting, and so does anything faster than
  /// [TrackingRules.maxWordsPerMinute].
  void readerAt(DateTime now, int index, {bool jump = false}) {
    final DateTime t = now.toUtc();
    final int elapsed = t.difference(_lastMove).inMilliseconds;
    if (!jump) _sample(t);
    _lastMove = t;
    activity(t);
    final int? max = _maxIndex;
    if (max == null || index <= max) {
      _maxIndex ??= index;
      return;
    }
    final int w = jump || wordsBetween == null ? 0 : wordsBetween!(max, index);
    // A screenful may be read before the first turn; beyond that, a cap.
    final int plausible = (elapsed / 60000 * TrackingRules.maxWordsPerMinute).ceil() + 400;
    if (!jump && w <= plausible) words += w;
    _maxIndex = index;
  }

  /// Page view or comics moved to [page]. The page left counts once read for
  /// [TrackingRules.minDwell]; a [jump] doesn't count the page jumped from.
  void pageAt(DateTime now, int page, {bool jump = false}) {
    final DateTime t = now.toUtc();
    final int dwell = t.difference(_lastMove).inMilliseconds;
    final int? left = _page;
    if (left != null && left != page && !jump && dwell >= TrackingRules.minDwell.inMilliseconds) pages.add(left);
    if (!jump) _sample(t);
    _lastMove = t;
    _page = page;
    activity(t);
  }

  /// Ends the session at [now]: the page on screen counts if it was read.
  void end(DateTime now) {
    final DateTime t = now.toUtc();
    if (_page != null && t.difference(_lastMove) >= TrackingRules.minDwell && reading) pages.add(_page!);
    flush(t);
    _runFrom = null;
    _listenFrom = null;
  }

  /// Under [TrackingRules.minSession] it isn't a session.
  bool get counts => totalMs >= TrackingRules.minSession.inMilliseconds;

  /// Time per page or screen for this session, as a median of its samples.
  int? get medianDwell {
    if (dwellSamples.isEmpty) return null;
    final List<int> s = List<int>.of(dwellSamples)..sort();
    return s[s.length ~/ 2];
  }
}

/// A running median nudged by each session's median: moves 1/8 of the way,
/// so one odd session doesn't swing the idle threshold.
int nudgeMedian(int current, int? sample) {
  if (sample == null) return current;
  if (current <= 0) return sample;
  return current + ((sample - current) / 8).round().clamp(-math.max(1, current ~/ 2), current);
}
