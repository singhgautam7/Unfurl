import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/theme/insights_theme.dart';
import '../../core/tracking/session.dart';
import '../../core/tracking/stats_store.dart';
import '../../core/tracking/tracker.dart';
import '../../formats/format_registry.dart';

/// "42 min", "5 h 18 min", "312 h": the boards' durations.
String formatMinutes(int ms) {
  final int min = (ms / 60000).round();
  if (min < 60) return '$min min';
  final int h = min ~/ 60, m = min % 60;
  if (h >= 100) return '$h h';
  return m == 0 ? '$h h' : '$h h $m min';
}

const List<String> kMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const List<String> kMonthsLong = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "4 Oct", "4 Oct 2025" outside this year.
String formatDay(DateTime d, {DateTime? now}) => d.year == (now ?? DateTime.now()).year
    ? '${d.day} ${kMonths[d.month - 1]}'
    : '${d.day} ${kMonths[d.month - 1]} ${d.year}';

/// "1–4 Oct", "28 Sep – 4 Oct".
String formatRange(DateTime a, DateTime b) => a.month == b.month && a.year == b.year
    ? '${a.day}–${b.day} ${kMonths[b.month - 1]}'
    : '${formatDay(a)} – ${formatDay(b)}';

DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime mondayOf(DateTime d) => _date(d).subtract(Duration(days: d.weekday - 1));

/// A most-read row: the book's totals and what the library knows of it.
@immutable
class BookTime {
  const BookTime({required this.fingerprint, required this.ms, this.title, this.name, this.format});

  final String fingerprint;
  final int ms;
  final String? title;
  final String? name;
  final String? format;

  String get label => title ?? (name == null ? 'Unknown' : name!.replaceAll(RegExp(r'\.[^.]+$'), ''));
}

/// Everything the Insights screen draws, built from the aggregates only: at
/// most 371 `daily_stats` rows, one sum over them, the top books and the
/// finished dates. Derived figures are getters, so each module computes only
/// what it shows.
@immutable
class InsightsData {
  InsightsData({
    required this.today,
    required List<DailyStat> days,
    required this.allTimeMs,
    required this.allListenMs,
    required this.firstDay,
    required this.top,
    required this.finished,
    required this.longestTitle,
  }) : _days = <int, DailyStat>{for (final DailyStat d in days) d.day: d};

  final DateTime today;
  final Map<int, DailyStat> _days;
  final int allTimeMs;
  final int allListenMs;

  /// The first day with reading, or null.
  final int? firstDay;
  final List<BookTime> top;
  final List<DateTime> finished;

  /// The title of the book behind the longest session.
  final String? longestTitle;

  bool get empty => allTimeMs + allListenMs == 0;

  DailyStat? on(DateTime d) => _days[dayKey(d)];
  int msOn(DateTime d) => on(d)?.readingMs ?? 0;

  int _sum(DateTime from, DateTime to, int Function(DailyStat) f) {
    int total = 0;
    for (DateTime d = _date(from); !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
      final DailyStat? s = on(d);
      if (s != null) total += f(s);
    }
    return total;
  }

  int get todayMs => msOn(today);
  int get weekMs => _sum(mondayOf(today), today, (DailyStat s) => s.readingMs);
  int get monthMs => _sum(DateTime(today.year, today.month), today, (DailyStat s) => s.readingMs);

  /// Monday to Sunday of this week, minutes.
  List<int> get weekMinutes => <int>[
    for (int i = 0; i < 7; i++) (msOn(mondayOf(today).add(Duration(days: i))) / 60000).round(),
  ];

  int get daysWithReading => _days.values.where((DailyStat d) => d.readingMs >= 60000).length;

  /// The heatmap: 53 Monday-first weeks ending this week; null for days to come.
  List<int?> get heatmapMinutes {
    final DateTime start = mondayOf(today).subtract(const Duration(days: 52 * 7));
    return <int?>[
      for (int i = 0; i < 53 * 7; i++)
        start.add(Duration(days: i)).isAfter(today) ? null : (msOn(start.add(Duration(days: i))) / 60000).round(),
    ];
  }

  /// The heatmap's month labels, oldest first.
  List<String> get heatmapMonths => <String>[for (int k = 11; k >= 0; k--) kMonths[(today.month - 1 - k) % 12]];

  Iterable<DailyStat> _window(int days) {
    final int from = dayKey(today.subtract(Duration(days: days - 1)));
    return _days.values.where((DailyStat d) => d.day >= from);
  }

  /// Words per minute in Reader mode: the median of the last 30 days' daily
  /// speeds, once there are 30 minutes in that mode.
  double? get readerWpm => _median(
    _window(InsightsSpec.speedWindowDays),
    (DailyStat d) => d.readerMs,
    (DailyStat d) => d.readerWords / (d.readerMs / 60000),
  );

  double? get pagesPerHour => _median(
    _window(InsightsSpec.speedWindowDays),
    (DailyStat d) => d.pageMs,
    (DailyStat d) => d.pagePages / (d.pageMs / 3600000),
  );

  static double? _median(Iterable<DailyStat> days, int Function(DailyStat) ms, double Function(DailyStat) speed) {
    final List<DailyStat> used = days.where((DailyStat d) => ms(d) >= 60000).toList();
    final int total = used.fold<int>(0, (int a, DailyStat d) => a + ms(d));
    if (total < InsightsSpec.speedMinMinutes * 60000) return null;
    final List<double> v = used.map(speed).where((double x) => x > 0).toList()..sort();
    return v.isEmpty ? null : v[v.length ~/ 2];
  }

  /// Patterns need 7 days with reading.
  bool get hasPatterns => daysWithReading >= InsightsSpec.patternsMinDays;

  /// Reading by hour of day over the last 90 days, minutes.
  List<int> get hourMinutes {
    final List<int> h = List<int>.filled(24, 0);
    for (final DailyStat d in _window(InsightsSpec.patternWindowDays)) {
      if (d.hourMs.isEmpty) continue;
      final List<String> parts = d.hourMs.split(',');
      for (int i = 0; i < 24 && i < parts.length; i++) {
        h[i] += int.parse(parts[i]);
      }
    }
    return <int>[for (final int ms in h) (ms / 60000).round()];
  }

  /// "Mostly 21:00–23:00": the busiest hour and the busier of its neighbours.
  String get peakHours {
    final List<int> h = hourMinutes;
    int top = 0;
    for (int i = 1; i < 24; i++) {
      if (h[i] > h[top]) top = i;
    }
    final int start = h[(top + 1) % 24] >= h[(top + 23) % 24] ? top : top - 1;
    String hh(int x) => '${(x % 24).toString().padLeft(2, '0')}:00';
    return 'Mostly ${hh(start)}–${hh(start + 2)}';
  }

  /// The longest session ever (as far as the window reaches), with its day.
  (int, DateTime, String?)? get longest {
    DailyStat? best;
    for (final DailyStat d in _days.values) {
      if (best == null || d.longestMs > best.longestMs) best = d;
    }
    return best == null || best.longestMs == 0 ? null : (best.longestMs, dayOfKey(best.day), best.longestFp);
  }

  int? get averageSessionMs {
    int ms = 0, n = 0;
    for (final DailyStat d in _window(InsightsSpec.patternWindowDays)) {
      ms += d.readingMs + d.listeningMs;
      n += d.sessions;
    }
    return n == 0 ? null : ms ~/ n;
  }

  int get listenMonthMs => _sum(DateTime(today.year, today.month), today, (DailyStat s) => s.listeningMs);

  /// Books finished in each month of [year].
  List<int> finishedByMonth(int year) {
    final List<int> m = List<int>.filled(12, 0);
    for (final DateTime d in finished) {
      if (d.year == year) m[d.month - 1]++;
    }
    return m;
  }

  /// Reading time by format family over the last 12 months, biggest first,
  /// the sixth onwards as "Other". (label, share 0..1).
  List<(String, double)> get formats {
    final Map<String, int> ms = <String, int>{};
    for (final DailyStat d in _days.values) {
      final Map<String, Object?> f = jsonDecode(d.formatMs) as Map<String, Object?>;
      for (final MapEntry<String, Object?> e in f.entries) {
        final FormatModule? m = Formats.all.where((FormatModule x) => x.id == e.key).firstOrNull;
        final String label = m == null || !m.book ? 'Other' : m.group.label;
        ms[label] = (ms[label] ?? 0) + ((e.value as num?)?.toInt() ?? 0);
      }
    }
    final int total = ms.values.fold<int>(0, (int a, int b) => a + b);
    if (total == 0) return const <(String, double)>[];
    final List<MapEntry<String, int>> sorted = ms.entries.where((MapEntry<String, int> e) => e.key != 'Other').toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
    final List<(String, double)> out = <(String, double)>[
      for (final MapEntry<String, int> e in sorted.take(5)) (e.key, e.value / total),
    ];
    final int rest = total - sorted.take(5).fold<int>(0, (int a, MapEntry<String, int> e) => a + e.value);
    if (rest > 0) out.add(('Other', rest / total));
    return out;
  }
}

/// The chart's range (Week, Month, Year) and how far back it is stepped.
enum ChartRange { week, month, year }

@immutable
class ChartState {
  const ChartState({this.range = ChartRange.week, this.back = 0});

  final ChartRange range;

  /// 0 is the current week, month or year; 1 the one before.
  final int back;
}

class ChartController extends Notifier<ChartState> {
  @override
  ChartState build() => const ChartState();

  void range(ChartRange r) => state = ChartState(range: r);
  void step(int delta) => state = ChartState(range: state.range, back: math.max(0, state.back + delta));
}

/// One bar chart's figures: bar values (minutes, or hours for a year),
/// labels, the highlighted bar, the total, the range line and the caption.
@immutable
class ChartData {
  const ChartData({
    required this.values,
    required this.labels,
    required this.total,
    required this.range,
    this.highlight,
    this.caption,
  });

  final List<int> values;
  final List<String> labels;
  final int? highlight;
  final String total;
  final String range;
  final String? caption;
}

final NotifierProvider<ChartController, ChartState> chartStateProvider = NotifierProvider<ChartController, ChartState>(
  ChartController.new,
);

/// Refreshes when the tracker folds a session in.
final Provider<int> _foldedProvider = Provider<int>((Ref ref) {
  final ReadingSessionTracker t = ref.watch(trackerProvider);
  void bump() => ref.invalidateSelf();
  t.folded.addListener(bump);
  ref.onDispose(() => t.folded.removeListener(bump));
  return t.folded.value;
});

/// Today, for tests to pin.
final Provider<DateTime Function()> insightsClockProvider = Provider<DateTime Function()>((Ref ref) => DateTime.now);

final FutureProvider<InsightsData> insightsProvider = FutureProvider<InsightsData>((Ref ref) async {
  ref.watch(_foldedProvider);
  final AppDatabase db = ref.watch(databaseProvider);
  final DateTime today = _date(ref.watch(insightsClockProvider)());
  final int from = dayKey(today.subtract(const Duration(days: InsightsSpec.heatmapDays)));
  final List<DailyStat> days = await (db.select(db.dailyStats)..where((d) => d.day.isBiggerOrEqualValue(from))).get();
  final QueryRow all = await db
      .customSelect(
        'SELECT COALESCE(SUM(reading_ms), 0) AS r, COALESCE(SUM(listening_ms), 0) AS l, '
        'MIN(CASE WHEN reading_ms + listening_ms > 0 THEN day END) AS d FROM daily_stats',
        readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{db.dailyStats},
      )
      .getSingle();
  final List<QueryRow> top = await db
      .customSelect(
        'SELECT b.fingerprint AS fp, b.reading_ms + b.listening_ms AS ms, d.title AS title, d.name AS name, '
        'd.format AS format FROM book_stats b LEFT JOIN documents d ON d.fingerprint = b.fingerprint '
        'WHERE b.reading_ms + b.listening_ms > 0 ORDER BY ms DESC LIMIT ?',
        variables: <Variable<Object>>[const Variable<int>(InsightsSpec.topBooks)],
        readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{db.bookStats, db.documents},
      )
      .get();
  final List<BookStat> finished = await (db.select(db.bookStats)..where((b) => b.finishedAt.isNotNull())).get();
  final DailyStat? longestDay = days.isEmpty
      ? null
      : days.reduce((DailyStat a, DailyStat b) => b.longestMs > a.longestMs ? b : a);
  final Document? longestDoc = longestDay?.longestFp == null
      ? null
      : await (db.select(db.documents)..where((d) => d.fingerprint.equals(longestDay!.longestFp!))).getSingleOrNull();
  return InsightsData(
    today: today,
    days: days,
    allTimeMs: all.read<int>('r'),
    allListenMs: all.read<int>('l'),
    firstDay: all.readNullable<int>('d'),
    top: <BookTime>[
      for (final QueryRow r in top)
        BookTime(
          fingerprint: r.read<String>('fp'),
          ms: r.read<int>('ms'),
          title: r.readNullable<String>('title'),
          name: r.readNullable<String>('name'),
          format: r.readNullable<String>('format'),
        ),
    ],
    finished: <DateTime>[for (final BookStat b in finished) b.finishedAt!],
    longestTitle: longestDoc?.title ?? longestDoc?.name,
  );
});

/// The bar chart for the current [ChartState]: this week, month or year from
/// the loaded rows; stepped further back, its own query (at most 366 rows).
/// Watching only this keeps a toggle to the chart.
final FutureProvider<ChartData> chartProvider = FutureProvider<ChartData>((Ref ref) async {
  ref.watch(_foldedProvider);
  final ChartState s = ref.watch(chartStateProvider);
  final DateTime today = _date(ref.watch(insightsClockProvider)());
  final AppDatabase db = ref.watch(databaseProvider);
  final (DateTime from, DateTime to) = switch (s.range) {
    ChartRange.week => (
      mondayOf(today).subtract(Duration(days: 7 * s.back)),
      mondayOf(today).subtract(Duration(days: 7 * s.back - 6)),
    ),
    ChartRange.month => (DateTime(today.year, today.month - s.back), DateTime(today.year, today.month - s.back + 1, 0)),
    ChartRange.year => (DateTime(today.year - s.back), DateTime(today.year - s.back, 12, 31)),
  };
  final List<DailyStat> rows = await (db.select(
    db.dailyStats,
  )..where((d) => d.day.isBetweenValues(dayKey(from), dayKey(to)) & d.readingMs.isBiggerThanValue(0))).get();
  final Map<int, int> ms = <int, int>{for (final DailyStat d in rows) d.day: d.readingMs};
  int msOn(DateTime d) => ms[dayKey(d)] ?? 0;
  final int total = ms.values.fold<int>(0, (int a, int b) => a + b);
  final int dayCount = to.difference(from).inDays + 1;
  final int elapsed = !to.isAfter(today) ? dayCount : today.difference(from).inDays + 1;
  final int perDay = elapsed == 0 ? 0 : total ~/ elapsed;
  final String average = 'Average ${perDay < 60000 ? 'under 1 min' : formatMinutes(perDay)} a day';
  switch (s.range) {
    case ChartRange.week:
      return ChartData(
        values: <int>[for (int i = 0; i < 7; i++) (msOn(from.add(Duration(days: i))) / 60000).round()],
        labels: const <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'],
        highlight: s.back == 0 ? today.weekday - 1 : null,
        total: formatMinutes(total),
        range: formatRange(from, to),
        caption: total == 0 ? null : average,
      );
    case ChartRange.month:
      return ChartData(
        values: <int>[for (int i = 0; i < dayCount; i++) (msOn(from.add(Duration(days: i))) / 60000).round()],
        labels: <String>[for (int i = 0; i < dayCount; i++) i % 7 == 0 ? '${i + 1}' : ''],
        highlight: s.back == 0 ? today.day - 1 : null,
        total: formatMinutes(total),
        range: '${kMonths[from.month - 1]} ${from.year}',
        caption: total == 0 ? null : average,
      );
    case ChartRange.year:
      final List<int> hours = List<int>.filled(12, 0);
      final List<int> byMonth = List<int>.filled(12, 0);
      for (final MapEntry<int, int> e in ms.entries) {
        byMonth[e.key ~/ 100 % 100 - 1] += e.value;
      }
      for (int m = 0; m < 12; m++) {
        hours[m] = (byMonth[m] / 3600000).round();
      }
      final int most = byMonth.indexOf(byMonth.reduce(math.max));
      return ChartData(
        values: hours,
        labels: const <String>['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'],
        highlight: s.back == 0 ? today.month - 1 : null,
        total: '${(total / 3600000).round()} h',
        range: '${from.year}',
        caption: total == 0 ? null : 'Hours per month. Most in ${kMonthsLong[most]}.',
      );
  }
});

/// Book insights (V3-BOOK-INSIGHTS): a handful of small queries by key.
@immutable
class BookInsights {
  const BookInsights({
    required this.stats,
    required this.doc,
    required this.last30,
    required this.highlights,
    required this.bookmarks,
    required this.speeds,
    required this.today,
  });

  final BookStat? stats;
  final Document? doc;

  /// Minutes per day, oldest first, ending today.
  final List<int> last30;
  final int highlights;
  final int bookmarks;

  /// This book's speed, else the reader's own (for "Estimated time left").
  final Speeds speeds;
  final DateTime today;

  int get timeMs => (stats?.readingMs ?? 0) + (stats?.listeningMs ?? 0);
  int get sessions => stats?.sessions ?? 0;
  int get readOn => last30.where((int m) => m > 0).length;
}

final FutureProviderFamily<BookInsights, String>
bookInsightsProvider = FutureProvider.autoDispose.family<BookInsights, String>((Ref ref, String fingerprint) async {
  ref.watch(_foldedProvider);
  final AppDatabase db = ref.watch(databaseProvider);
  final DateTime today = _date(ref.watch(insightsClockProvider)());
  final int from = dayKey(today.subtract(const Duration(days: 29)));
  final (BookStat? stats, Document? doc, List<BookDay> days, List<QueryRow> counts, Speeds speeds) = await (
    (db.select(db.bookStats)..where((b) => b.fingerprint.equals(fingerprint))).getSingleOrNull(),
    (db.select(db.documents)..where((d) => d.fingerprint.equals(fingerprint))).getSingleOrNull(),
    (db.select(db.bookDays)..where((d) => d.fingerprint.equals(fingerprint) & d.day.isBiggerOrEqualValue(from))).get(),
    db
        .customSelect(
          'SELECT kind, COUNT(*) AS n FROM annotations WHERE fingerprint = ? GROUP BY kind',
          variables: <Variable<Object>>[Variable<String>(fingerprint)],
          readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{db.annotations},
        )
        .get(),
    StatsStore(db).speeds(fingerprint, now: today),
  ).wait;
  final Map<int, int> ms = <int, int>{for (final BookDay d in days) d.day: d.ms};
  int count(String kind) =>
      counts.where((QueryRow r) => r.read<String>('kind') == kind).firstOrNull?.read<int>('n') ?? 0;
  return BookInsights(
    stats: stats,
    doc: doc,
    last30: <int>[for (int i = 29; i >= 0; i--) ((ms[dayKey(today.subtract(Duration(days: i)))] ?? 0) / 60000).round()],
    highlights: count('highlight'),
    bookmarks: count('bookmark'),
    speeds: speeds,
    today: today,
  );
});
