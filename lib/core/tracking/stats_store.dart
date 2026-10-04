import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../db/database.dart';
import 'session.dart';

/// Reading speeds for estimates: words per minute in Reader mode, pages per
/// hour in Page view (and comics). Null until there is enough reading.
class Speeds {
  const Speeds({this.wpm, this.pagesPerHour});

  final double? wpm;
  final double? pagesPerHour;
}

/// Writes sessions and keeps the aggregates Insights reads ([DailyStats],
/// [BookStats], [BookDays]) up to date incrementally, one transaction per
/// finished session. Nothing here scans `reading_sessions` to answer a read.
class StatsStore {
  StatsStore(this.db);

  final AppDatabase db;

  /// Enough of a book read in Reader mode for its own speed to stand.
  static const int bookSpeedMinMs = 10 * 60 * 1000;

  /// Enough reading in a mode for a global speed (the spec's 30 minutes).
  static const int speedMinMs = 30 * 60 * 1000;

  ReadingSessionsCompanion _row(LiveSession s, DateTime now, {required bool open}) => ReadingSessionsCompanion(
    fingerprint: Value<String>(s.fingerprint),
    format: Value<String>(s.format),
    mode: Value<String>(s.mode),
    startedAt: Value<DateTime>(s.startedAt),
    endedAt: Value<DateTime>(now.toUtc()),
    day: Value<int>(s.startDay),
    hour: Value<int>(s.startHour),
    activeMs: Value<int>(s.activeMs),
    listeningMs: Value<int>(s.listeningMs),
    fromLocator: Value<String?>(s.fromLocator),
    toLocator: Value<String?>(s.toLocator),
    words: Value<int>(s.words),
    pages: Value<int>(s.pages.length),
    open: Value<bool>(open),
  );

  /// Every 60 s and on pause: a crash loses at most a minute.
  Future<void> checkpoint(LiveSession s, DateTime now) async {
    if (s.rowId == null) {
      s.rowId = await db.into(db.readingSessions).insert(_row(s, now, open: true));
    } else {
      await (db.update(db.readingSessions)..where((r) => r.id.equals(s.rowId!))).write(_row(s, now, open: true));
    }
  }

  /// The session is over: dropped if under 30 s, else closed and folded into
  /// the day, book and book-day aggregates together.
  Future<void> finish(LiveSession s, DateTime now) => db.transaction(() async {
    if (!s.counts) {
      if (s.rowId != null) await (db.delete(db.readingSessions)..where((r) => r.id.equals(s.rowId!))).go();
      return;
    }
    if (s.rowId == null) {
      s.rowId = await db.into(db.readingSessions).insert(_row(s, now, open: false));
    } else {
      await (db.update(db.readingSessions)..where((r) => r.id.equals(s.rowId!))).write(_row(s, now, open: false));
    }
    await _fold(
      _Fold(
        fingerprint: s.fingerprint,
        format: s.format,
        mode: s.mode,
        startDay: s.startDay,
        endedAt: now.toUtc(),
        startedAt: s.startedAt,
        activeMs: s.activeMs,
        listeningMs: s.listeningMs,
        words: s.words,
        pages: s.pages.length,
        dayMs: s.dayMs,
        dayListenMs: s.dayListenMs,
        dayHourMs: s.dayHourMs,
        medianDwell: s.medianDwell,
      ),
    );
  });

  /// At launch: sessions a crash or a kill left open are folded in from their
  /// last checkpoint (their time all on the day and hour they started).
  Future<int> recover() async {
    final List<ReadingSession> open = await (db.select(db.readingSessions)..where((r) => r.open.equals(true))).get();
    for (final ReadingSession r in open) {
      await db.transaction(() async {
        if (r.activeMs + r.listeningMs < TrackingRules.minSession.inMilliseconds) {
          await (db.delete(db.readingSessions)..where((x) => x.id.equals(r.id))).go();
          return;
        }
        await (db.update(
          db.readingSessions,
        )..where((x) => x.id.equals(r.id))).write(const ReadingSessionsCompanion(open: Value<bool>(false)));
        await _fold(
          _Fold(
            fingerprint: r.fingerprint,
            format: r.format,
            mode: r.mode,
            startDay: r.day,
            startedAt: r.startedAt,
            endedAt: r.endedAt,
            activeMs: r.activeMs,
            listeningMs: r.listeningMs,
            words: r.words,
            pages: r.pages,
            dayMs: <int, int>{r.day: r.activeMs},
            dayListenMs: <int, int>{r.day: r.listeningMs},
            dayHourMs: <int, List<int>>{r.day: List<int>.filled(24, 0)..[r.hour] = r.activeMs},
          ),
        );
      });
    }
    return open.length;
  }

  Future<void> _fold(_Fold f) async {
    final Set<int> days = <int>{...f.dayMs.keys, ...f.dayListenMs.keys, f.startDay};
    for (final int day in days) {
      final DailyStat? old = await (db.select(db.dailyStats)..where((d) => d.day.equals(day))).getSingleOrNull();
      final int reading = f.dayMs[day] ?? 0;
      final int listening = f.dayListenMs[day] ?? 0;
      final bool start = day == f.startDay;
      final Map<String, Object?> formats = old == null
          ? <String, Object?>{}
          : jsonDecode(old.formatMs) as Map<String, Object?>;
      if (reading + listening > 0) formats[f.format] = ((formats[f.format] as int?) ?? 0) + reading + listening;
      final List<int> hours = old == null || old.hourMs.isEmpty
          ? List<int>.filled(24, 0)
          : old.hourMs.split(',').map(int.parse).toList();
      final List<int>? add = f.dayHourMs[day];
      if (add != null) {
        for (int h = 0; h < 24; h++) {
          hours[h] += add[h];
        }
      }
      final bool longest = start && f.total > (old?.longestMs ?? 0);
      final bool reader = f.mode == 'reader';
      final bool page = f.mode == 'page';
      await db
          .into(db.dailyStats)
          .insertOnConflictUpdate(
            DailyStatsCompanion(
              day: Value<int>(day),
              readingMs: Value<int>((old?.readingMs ?? 0) + reading),
              listeningMs: Value<int>((old?.listeningMs ?? 0) + listening),
              words: Value<int>((old?.words ?? 0) + (start ? f.words : 0)),
              pages: Value<int>((old?.pages ?? 0) + (start ? f.pages : 0)),
              sessions: Value<int>((old?.sessions ?? 0) + (start ? 1 : 0)),
              readerMs: Value<int>((old?.readerMs ?? 0) + (reader ? reading : 0)),
              readerWords: Value<int>((old?.readerWords ?? 0) + (reader && start ? f.words : 0)),
              pageMs: Value<int>((old?.pageMs ?? 0) + (page ? reading : 0)),
              pagePages: Value<int>((old?.pagePages ?? 0) + (page && start ? f.pages : 0)),
              longestMs: Value<int>(longest ? f.total : (old?.longestMs ?? 0)),
              longestFp: Value<String?>(longest ? f.fingerprint : old?.longestFp),
              formatMs: Value<String>(jsonEncode(formats)),
              hourMs: Value<String>(hours.join(',')),
            ),
          );
      final int bookMs = reading + listening;
      if (bookMs > 0) {
        await db.customStatement(
          'INSERT INTO book_days (fingerprint, day, ms) VALUES (?, ?, ?) '
          'ON CONFLICT(fingerprint, day) DO UPDATE SET ms = ms + excluded.ms',
          <Object?>[f.fingerprint, day, bookMs],
        );
      }
    }
    final BookStat? b = await (db.select(
      db.bookStats,
    )..where((x) => x.fingerprint.equals(f.fingerprint))).getSingleOrNull();
    final bool reader = f.mode == 'reader';
    await db
        .into(db.bookStats)
        .insertOnConflictUpdate(
          BookStatsCompanion(
            fingerprint: Value<String>(f.fingerprint),
            readingMs: Value<int>((b?.readingMs ?? 0) + f.activeMs),
            listeningMs: Value<int>((b?.listeningMs ?? 0) + f.listeningMs),
            sessions: Value<int>((b?.sessions ?? 0) + 1),
            words: Value<int>((b?.words ?? 0) + f.words),
            pages: Value<int>((b?.pages ?? 0) + f.pages),
            readerMs: Value<int>((b?.readerMs ?? 0) + (reader ? f.activeMs : 0)),
            readerWords: Value<int>((b?.readerWords ?? 0) + (reader ? f.words : 0)),
            pageMs: Value<int>((b?.pageMs ?? 0) + (reader ? 0 : f.activeMs)),
            pagePages: Value<int>((b?.pagePages ?? 0) + (reader ? 0 : f.pages)),
            longestMs: Value<int>(math.max(b?.longestMs ?? 0, f.total)),
            medianPageMs: Value<int>(nudgeMedian(b?.medianPageMs ?? 0, f.medianDwell)),
            firstRead: Value<DateTime?>(b?.firstRead ?? f.startedAt),
            lastRead: Value<DateTime?>(f.endedAt),
            finishedAt: Value<DateTime?>(b?.finishedAt),
            totalWords: Value<int?>(b?.totalWords),
            wordsLeft: Value<int?>(b?.wordsLeft),
          ),
        );
  }

  /// A book reached its end (or was marked finished, or unfinished).
  Future<void> setFinished(String fingerprint, {required bool finished}) => finished
      ? db.customStatement(
          'INSERT INTO book_stats (fingerprint, finished_at) VALUES (?, ?) '
          'ON CONFLICT(fingerprint) DO UPDATE SET finished_at = COALESCE(finished_at, excluded.finished_at)',
          <Object?>[fingerprint, DateTime.now().millisecondsSinceEpoch ~/ 1000],
        )
      : db.customStatement('UPDATE book_stats SET finished_at = NULL WHERE fingerprint = ?', <Object?>[fingerprint]);

  Future<BookStat?> book(String fingerprint) =>
      (db.select(db.bookStats)..where((x) => x.fingerprint.equals(fingerprint))).getSingleOrNull();

  /// Reader mode closed: how much of the book is left, for time-left estimates.
  Future<void> setWords(String fingerprint, {required int total, required int left}) => db.customStatement(
    'INSERT INTO book_stats (fingerprint, total_words, words_left) VALUES (?, ?, ?) '
    'ON CONFLICT(fingerprint) DO UPDATE SET total_words = excluded.total_words, words_left = excluded.words_left',
    <Object?>[fingerprint, total, left],
  );

  /// The idle threshold's input for a document.
  Future<int> medianPageMs(String fingerprint) async => (await book(fingerprint))?.medianPageMs ?? 0;

  /// This book's speed when it has enough reading, else the reader's own
  /// over the last 30 days (at least 30 minutes in that mode), else null.
  Future<Speeds> speeds(String fingerprint, {DateTime? now}) async {
    final BookStat? b = await book(fingerprint);
    final int from = dayKey((now ?? DateTime.now()).subtract(const Duration(days: 30)));
    final List<DailyStat> days = await (db.select(db.dailyStats)..where((d) => d.day.isBiggerOrEqualValue(from))).get();
    int rMs = 0, rWords = 0, pMs = 0, pPages = 0;
    for (final DailyStat d in days) {
      rMs += d.readerMs;
      rWords += d.readerWords;
      pMs += d.pageMs;
      pPages += d.pagePages;
    }
    double? wpm = rMs >= speedMinMs && rWords > 0 ? rWords / (rMs / 60000) : null;
    double? pph = pMs >= speedMinMs && pPages > 0 ? pPages / (pMs / 3600000) : null;
    if (b != null && b.readerMs >= bookSpeedMinMs && b.readerWords > 0) wpm = b.readerWords / (b.readerMs / 60000);
    if (b != null && b.pageMs >= bookSpeedMinMs && b.pagePages > 0) pph = b.pagePages / (b.pageMs / 3600000);
    return Speeds(wpm: wpm, pagesPerHour: pph);
  }
}

class _Fold {
  _Fold({
    required this.fingerprint,
    required this.format,
    required this.mode,
    required this.startDay,
    required this.startedAt,
    required this.endedAt,
    required this.activeMs,
    required this.listeningMs,
    required this.words,
    required this.pages,
    required this.dayMs,
    required this.dayListenMs,
    required this.dayHourMs,
    this.medianDwell,
  });

  final String fingerprint;
  final String format;
  final String mode;
  final int startDay;
  final DateTime startedAt;
  final DateTime endedAt;
  final int activeMs;
  final int listeningMs;
  final int words;
  final int pages;
  final Map<int, int> dayMs;
  final Map<int, int> dayListenMs;
  final Map<int, List<int>> dayHourMs;
  final int? medianDwell;

  int get total => activeMs + listeningMs;
}
