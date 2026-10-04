import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/db/database.dart';
import '../../core/files.dart';
import '../../core/library/library.dart';
import '../../core/locator.dart';
import '../../core/motion/motion.dart';
import '../../core/platform/platform.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/reading_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/tracking/tracker.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/app_menu.dart';
import '../../design_system/app_snackbar.dart';
import '../../design_system/buttons.dart';
import '../../design_system/covers.dart';
import '../../design_system/search_field.dart';
import '../../formats/format_registry.dart';
import '../../formats/reading_document.dart';
import '../settings/settings_controller.dart';
import '../cards/card_editor.dart';
import '../cards/share_card.dart';
import '../insights/book_insights.dart';
import '../viewer/document_screen.dart';
import 'chrome.dart';
import 'comfort.dart';
import 'engine/reader_style.dart';
import 'engine/reader_view.dart';
import 'read_aloud.dart';
import 'reading_prefs.dart';
import 'sheets.dart';

/// Reader mode, for every format that has it. One implementation of the
/// chrome, selection, highlights, notes, bookmarks, search, read aloud and
/// position, whichever file the [ReadingDocument] came from.
class ReaderScaffold extends ConsumerStatefulWidget {
  const ReaderScaffold({
    required this.doc,
    required this.reading,
    this.start,
    this.onPageMode,
    this.contents,
    this.pageIcon = AppIcons.article,
    this.pageLabel,
    this.overlay,
    this.approximate = false,
    super.key,
  });

  final OpenedDoc doc;
  final ReadingDocument reading;

  /// Where to open; else the saved position.
  final Locator? start;

  /// Back to Page view (PDF, DOCX, slides), with the current place. Null
  /// hides the mode toggle (EPUB, Markdown, TXT have no other mode).
  final void Function(Locator at)? onPageMode;

  /// The document's own contents (a PDF's outline, as Page mode shows it),
  /// as (title, level, locator). Null: the reflow's headings.
  final List<(String, int, Locator)>? contents;
  final IconData pageIcon;

  /// "p. 62" for a block's source, where the original has pages.
  final String? Function(SourceRef src)? pageLabel;

  /// A note over the page ("Some layout may be simplified").
  final Widget? overlay;

  /// Office files: "Rendered approximately" in the overflow menu.
  final bool approximate;

  @override
  ConsumerState<ReaderScaffold> createState() => ReaderScaffoldState();
}

class ReaderScaffoldState extends ConsumerState<ReaderScaffold> with WidgetsBindingObserver, TickerProviderStateMixin {
  late final ReaderController controller;
  ReadAloud? _tts;
  bool _chrome = false;
  List<Rect> _selectionRects = const <Rect>[];
  List<Annotation> _annotations = const <Annotation>[];
  StreamSubscription<List<Annotation>>? _annotationSub;
  StreamSubscription<int>? _volumeSub;
  Timer? _saveTimer;

  /// Held so the position can still be saved from dispose().
  late final Library _library;
  Timer? _hideTimer;
  (int, int, int)? _lastSaved;

  /// Held so the session can be closed from dispose().
  late final ReadingSessionTracker _tracker;

  /// The next position change is a jump (contents, link, scrubber, search),
  /// not reading.
  bool _jumping = false;

  /// This book's or the reader's own speed, for time left (null: 230 wpm).
  double? _wpm;

  // V3-COMFORT.
  late final SleepTimer _sleep = SleepTimer(onExpire: _sleepExpired)..addListener(_onSleep);
  late final AutoAdvance _auto;

  /// The section End of chapter was set in.
  int? _sleepSection;
  String? _backChip;
  (int, int, int)? _backTo;
  int? _sizeChip;
  // Search.
  bool _searching = false;
  String _query = '';
  List<int> _hits = const <int>[];
  int _hit = 0;
  bool _resultsOpen = true;

  OpenedDoc get doc => widget.doc;
  ReadingDocument get reading => widget.reading;
  FormatModule get format => doc.format;

  @override
  void initState() {
    super.initState();
    _library = ref.read(libraryProvider);
    WidgetsBinding.instance.addObserver(this);
    final Locator? at = widget.start ?? doc.resume;
    controller = ReaderController(reading, start: at?.resolveIn(reading));
    controller.addListener(_onPosition);
    _tracker = ref.read(trackerProvider);
    unawaited(
      _tracker.open(
        owner: this,
        fingerprint: doc.fingerprint,
        format: format.id,
        mode: 'reader',
        wordsBetween: reading.wordsBetween,
        startIndex: controller.globalIndex,
        fromLocator: at?.toJson(),
      ),
    );
    unawaited(
      _tracker.speeds(doc.fingerprint).then((Speeds s) {
        if (mounted) setState(() => _wpm = s.wpm);
      }),
    );
    _annotationSub = ref.read(libraryProvider).watchAnnotations(doc.fingerprint).listen((List<Annotation> a) {
      _annotations = a;
      _refreshMarks();
    });
    final ReadingPrefs prefs = ref.read(readingPrefsProvider);
    if (prefs.keepScreenOn) unawaited(Platform.keepScreenOn(on: true));
    if (prefs.volumeKeys) unawaited(Platform.volumeKeys(on: true));
    if (prefs.brightness != null) {
      unawaited(Platform.setBrightness(prefs.brightness));
    }
    _volumeSub = Platform.volumeKeyPresses.listen(_onVolumeKey);
    _auto = AutoAdvance(
      vsync: this,
      paged: prefs.layout == ReaderLayout.paged,
      scrollBy: controller.scrollBy,
      turn: () {
        if (controller.atEnd) return false;
        controller.turn(1);
        return true;
      },
      level: ComfortPrefs.level(ref.read(prefsProvider), 'reader'),
      seconds: ComfortPrefs.seconds(ref.read(prefsProvider)),
      onTick: _tracker.activity,
    )..addListener(_onAuto);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_save(force: true));
    unawaited(_tracker.close(this));
    unawaited(_saveWords());
    _saveTimer?.cancel();
    _hideTimer?.cancel();
    unawaited(_annotationSub?.cancel());
    unawaited(_volumeSub?.cancel());
    controller.removeListener(_onPosition);
    controller.dispose();
    _tts?.dispose();
    _auto.dispose();
    _sleep.dispose();
    unawaited(Platform.keepScreenOn(on: false));
    unawaited(Platform.volumeKeys(on: false));
    unawaited(Platform.setBrightness(null));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      unawaited(_save(force: true));
    }
  }

  // ------------------------------------------------------------ position

  /// The current place as a [Locator], for the toggle and for saving.
  Locator get here {
    final (int s, int b, int o) = controller.position;
    return Locator.inDocument(reading, s, b, o, length: math.min(24, reading.sections[s].blocks[b].text.length - o));
  }

  void _onPosition() {
    if (controller.position != _lastSaved) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 600), _save);
      _tracker.readerAt(controller.globalIndex, jump: _jumping);
      _jumping = false;
      final int? sleepSection = _sleepSection;
      if (sleepSection != null && controller.position.$1 > sleepSection && !(_tts?.playing ?? false)) {
        _sleep.chapterEnded();
      }
    }
    if (mounted) setState(() {});
  }

  /// For book insights' "Estimated time left". Static work on plain data in
  /// an isolate: counting a long book's words is not trivial.
  Future<void> _saveWords() async {
    final String text = reading.plainText;
    final int at = controller.globalIndex;
    final (int total, int left) = await Isolate.run(() => _countWords(text, at));
    await _tracker.words(doc.fingerprint, total: total, left: left);
  }

  static (int, int) _countWords(String text, int at) {
    final RegExp word = RegExp(r'\S+');
    final int total = word.allMatches(text).length;
    final int before = word.allMatches(text.substring(0, at.clamp(0, text.length))).length;
    return (total, total - before);
  }

  /// Moves somewhere not reached by reading.
  void _jump((int, int, int) to) {
    _jumping = true;
    controller.goTo(to);
  }

  String get _where {
    final (int s, int b, int _) = controller.position;
    final SourceRef? src = reading.sections[s].blocks[b].source;
    final String? page = src == null ? null : widget.pageLabel?.call(src);
    if (page != null) return page;
    final String title = reading.sections[s].title;
    return title.isNotEmpty ? title : '${reading.unitLabel} ${s + 1}';
  }

  Future<void> _save({bool force = false}) async {
    if (!mounted && !force) return;
    final (int, int, int) at = controller.position;
    if (at == _lastSaved) return;
    _lastSaved = at;
    final double progress = controller.progress;
    await _library.savePosition(
      doc.fingerprint,
      locator: here.toJson(),
      progress: progress >= 0.995 ? 1 : progress,
      where: _where,
      mode: 'reader',
    );
  }

  /// "6 min left in chapter", at this book's measured speed, else the
  /// reader's own (Insights), else v2's saved pace, else 230 wpm.
  String _timeLeft((int, int, int) at) {
    final Document d = doc.record;
    final double wpm = _wpm ?? ((d.readMs > 60000 && d.readWords > 50) ? d.readWords / (d.readMs / 60000) : 230);
    final Section s = reading.sections[at.$1];
    final int end = s.blocks.isEmpty ? s.start : s.blocks.last.start + s.blocks.last.text.length;
    final int from = reading.sections[at.$1].blocks[at.$2].start + at.$3;
    final int words = reading.wordsBetween(from, end);
    final int min = (words / math.max(60, wpm)).ceil();
    final String unit = reading.unitLabel.toLowerCase();
    if (words < 30) return 'End of $unit';
    return '$min min left in $unit';
  }

  // ------------------------------------------------------------ marks

  ReadingTheme get _theme => readingThemeOf(context, ref.read(readingPrefsProvider), ref.read(settingsProvider));

  (int, int)? _range(Annotation a) {
    final Locator l = Locator.fromJson(a.locator);
    final (int s, int b, int o) = l.resolveIn(reading);
    final int from = reading.sections[s].blocks[b].start + o;
    final int len = l.length > 0 ? l.length : math.max(1, l.exact.length);
    return (from, math.min(from + len, reading.plainText.length));
  }

  void _refreshMarks() {
    if (!mounted) return;
    final ReadingTheme theme = _theme;
    final List<Mark> marks = <Mark>[
      for (final Annotation a in _annotations)
        if (a.kind == 'highlight')
          if (_range(a) case final (int, int) r)
            Mark(
              id: a.id,
              from: r.$1,
              to: r.$2,
              color: theme.highlights[(a.color ?? 0).clamp(0, 3)],
              note: a.note != null,
            ),
      if (_searching)
        for (int i = 0; i < _hits.length; i++)
          Mark(
            id: -1 - i,
            from: _hits[i],
            to: _hits[i] + _query.length,
            color: theme.handle.withValues(alpha: i == _hit ? 0.55 : 0.25),
          ),
    ];
    controller.setMarks(marks);
    setState(() {});
  }

  Annotation? _highlightOver((int, int) sel) {
    for (final Annotation a in _annotations.where((Annotation a) => a.kind == 'highlight')) {
      final (int, int)? r = _range(a);
      if (r != null && r.$1 < sel.$2 && r.$2 > sel.$1) return a;
    }
    return null;
  }

  String _labelFor(int global) {
    final (int s, int b, int _) = reading.positionOfIndex(global);
    final SourceRef? src = reading.sections[s].blocks[b].source;
    final String pct = '${(reading.progressAt(s, b, 0) * 100).round()}%';
    final String? page = src == null ? null : widget.pageLabel?.call(src);
    if (page != null) return page;
    final String title = reading.sections[s].title;
    final String short = title.replaceFirst(RegExp('^${reading.unitLabel} ', caseSensitive: false), '');
    return '${title.isEmpty ? '${reading.unitLabel.substring(0, math.min(3, reading.unitLabel.length))}. ${s + 1}' : (short.length < 6 ? 'Ch. $short' : title)} · $pct';
  }

  Future<int> _addHighlight((int, int) sel, int color) async {
    final (int s, int b, int o) = reading.positionOfIndex(sel.$1);
    final Locator l = Locator.inDocument(reading, s, b, o, length: sel.$2 - sel.$1);
    return ref
        .read(libraryProvider)
        .addAnnotation(
          AnnotationsCompanion.insert(
            fingerprint: doc.fingerprint,
            kind: 'highlight',
            color: Value<int?>(color),
            locator: l.toJson(),
            quote: Value<String>(reading.plainText.substring(sel.$1, sel.$2).trim()),
            label: Value<String>(_labelFor(sel.$1)),
            progress: Value<double>(l.progress),
            mode: const Value<String>('reader'),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> _highlight(int color) async {
    final (int, int)? sel = controller.selection;
    if (sel == null) return;
    final Annotation? over = _highlightOver(sel);
    if (over != null) {
      await ref.read(libraryProvider).updateAnnotation(over.id, color: color);
    } else {
      await _addHighlight(sel, color);
    }
    setState(() {});
  }

  Future<void> _note() async {
    final (int, int)? sel = controller.selection;
    if (sel == null) return;
    final Annotation? over = _highlightOver(sel);
    final int id = over?.id ?? await _addHighlight(sel, 0);
    _clearSelection();
    if (!mounted) return;
    await _editNote(id);
  }

  Future<void> _editNote(int id) async {
    final Annotation? a = (await ref.read(databaseProvider).select(ref.read(databaseProvider).annotations).get())
        .where((Annotation x) => x.id == id)
        .firstOrNull;
    if (a == null || !mounted) return;
    final String? text = await showNoteSheet(
      context,
      quote: a.quote,
      color: _theme.highlights[(a.color ?? 0).clamp(0, 3)],
      initial: a.note,
      onDelete: () async {
        await ref.read(libraryProvider).deleteAnnotation(a.id);
        if (mounted) {
          AppSnackbar.undo(context, 'Highlight removed', () => ref.read(libraryProvider).restoreAnnotation(a));
        }
      },
    );
    if (text == null) return;
    await ref.read(libraryProvider).updateAnnotation(a.id, note: text.isEmpty ? null : text, clearNote: text.isEmpty);
  }

  /// Board 6, V5: a highlight tapped. Note, colour, copy, share as card, delete.
  Future<void> _highlightMenu(int id, Offset at) async {
    final Annotation? a = _annotations.where((Annotation x) => x.id == id).firstOrNull;
    if (a == null) return;
    final String? v = await showAppMenu<String>(
      context: context,
      at: at,
      entries: <AppMenuEntry<String>>[
        AppMenuEntry<String>(value: 'note', label: a.note == null ? 'Add note' : 'Edit note', icon: AppIcons.editNote),
        const AppMenuEntry<String>(value: 'colour', label: 'Change colour', icon: AppIcons.palette),
        const AppMenuEntry<String>(value: 'copy', label: 'Copy', icon: AppIcons.copy),
        const AppMenuEntry<String>(value: 'card', label: 'Share as card', icon: AppIcons.image),
        const AppMenuEntry<String>.divider(),
        const AppMenuEntry<String>(value: 'delete', label: 'Delete highlight', icon: AppIcons.delete, danger: true),
      ],
    );
    if (!mounted) return;
    switch (v) {
      case 'note':
        await _editNote(a.id);
      case 'colour':
        final int? colour = await showAppMenu<int>(
          context: context,
          at: at,
          entries: <AppMenuEntry<int>>[
            for (final HighlightColor h in HighlightColor.values)
              AppMenuEntry<int>(value: h.index, label: h.label, icon: AppIcons.palette, selected: a.color == h.index),
          ],
        );
        if (colour != null) await ref.read(libraryProvider).updateAnnotation(a.id, color: colour);
      case 'copy':
        await copyText(a.quote);
        if (mounted) AppSnackbar.info(context, 'Copied');
      case 'card':
        await _shareCard(a.quote, a.label);
      case 'delete':
        await ref.read(libraryProvider).deleteAnnotation(a.id);
        if (mounted) {
          AppSnackbar.undo(context, 'Highlight removed', () => ref.read(libraryProvider).restoreAnnotation(a));
        }
    }
  }

  Future<void> _shareCard(String quote, String location) => showCardEditor(
    context,
    CardContent(
      quote: quote.trim(),
      title: reading.title.isEmpty ? doc.ref.name : reading.title,
      author: reading.author,
      location: location,
      fingerprint: doc.fingerprint,
      format: format,
    ),
  );

  /// The selection toolbar's More: Share as card, Read aloud from here,
  /// Search in book.
  Future<void> _selectionMore(BuildContext anchor, (int, int) sel) async {
    final String text = controller.selectedText;
    final String? v = await showAppMenu<String>(
      context: context,
      anchorContext: anchor,
      entries: <AppMenuEntry<String>>[
        const AppMenuEntry<String>(value: 'card', label: 'Share as card', icon: AppIcons.image),
        if (format.tts)
          const AppMenuEntry<String>(value: 'aloud', label: 'Read aloud from here', icon: AppIcons.readAloud),
        if (format.search) const AppMenuEntry<String>(value: 'search', label: 'Search in book', icon: AppIcons.search),
      ],
    );
    if (!mounted) return;
    switch (v) {
      case 'card':
        _clearSelection();
        await _shareCard(text, _labelFor(sel.$1));
      case 'aloud':
        await _readAloud(from: sel.$1);
      case 'search':
        _clearSelection();
        setState(() => _searching = true);
        _search(text);
    }
  }

  void _clearSelection() {
    controller.clearSelection();
    setState(() => _selectionRects = const <Rect>[]);
  }

  // ------------------------------------------------------------ bookmarks

  Annotation? get _bookmarkHere {
    final int a = controller.globalIndex;
    final (int, int, int) l = controller.lastVisible;
    final int b = l.$1 < reading.sections.length && l.$2 < reading.sections[l.$1].blocks.length
        ? reading.sections[l.$1].blocks[l.$2].start + l.$3
        : a;
    for (final Annotation x in _annotations.where((Annotation x) => x.kind == 'bookmark')) {
      final (int, int)? r = _range(x);
      if (r != null && r.$1 >= a && r.$1 <= math.max(a, b)) return x;
    }
    return null;
  }

  Future<void> _toggleBookmark() async {
    final Annotation? existing = _bookmarkHere;
    if (existing != null) {
      await ref.read(libraryProvider).deleteAnnotation(existing.id);
      if (mounted) {
        AppSnackbar.undo(context, 'Bookmark removed', () => ref.read(libraryProvider).restoreAnnotation(existing));
      }
      return;
    }
    final Locator l = here;
    await ref
        .read(libraryProvider)
        .addAnnotation(
          AnnotationsCompanion.insert(
            fingerprint: doc.fingerprint,
            kind: 'bookmark',
            locator: l.toJson(),
            quote: Value<String>(_snippet(controller.globalIndex)),
            label: Value<String>(_where),
            progress: Value<double>(l.progress),
            mode: const Value<String>('reader'),
            createdAt: DateTime.now(),
          ),
        );
    if (mounted) AppSnackbar.info(context, 'Bookmarked $_where');
  }

  String _snippet(int global) {
    final String t = reading.plainText;
    final int end = math.min(t.length, global + 60);
    return '${t.substring(global.clamp(0, t.length), end).replaceAll('\n', ' ').trim()}…';
  }

  // ------------------------------------------------------------ chrome

  void _toggleChrome() {
    if (_searching) return;
    setState(() => _chrome = !_chrome);
    unawaited(SystemChrome.setEnabledSystemUIMode(_chrome ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky));
    _armAutoHide();
  }

  /// Chrome auto-hides after 4s only while read aloud plays.
  void _armAutoHide() {
    _hideTimer?.cancel();
    if (_chrome && (_tts?.playing ?? false)) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _chrome) _toggleChrome();
      });
    }
  }

  void _onLink(String href) {
    if (RegExp(r'^[a-z]+:', caseSensitive: false).hasMatch(href)) {
      unawaited(Platform.openUrl(href));
      return;
    }
    final (int, int)? target = reading.anchors[href] ?? reading.anchors[href.split('#').first];
    if (target == null) return;
    final (int, int, int) from = controller.position;
    _jump((target.$1, target.$2, 0));
    setState(() {
      _backTo = from;
      _backChip = 'Back';
    });
  }

  void _jumpWithBack((int, int, int) to) {
    final (int, int, int) from = controller.position;
    _jump(to);
    setState(() {
      _backTo = from;
      _backChip = 'Back to ${_labelFor(reading.sections[from.$1].blocks[from.$2].start + from.$3).split(' · ').first}';
    });
  }

  void _fontStep(int step) {
    final ReadingPrefs p = ref.read(readingPrefsProvider);
    final int i = (ReadingPrefs.sizes.indexOf(p.size) + step).clamp(0, ReadingPrefs.sizes.length - 1);
    ref.read(readingPrefsProvider.notifier).update((ReadingPrefs x) => x.copyWith(size: ReadingPrefs.sizes[i]));
    setState(() => _sizeChip = ReadingPrefs.sizes[i].round());
  }

  // ------------------------------------------------------------ read aloud

  // ------------------------------------------------------------ comfort

  /// Paged: a page turn. Scrolling: 90% of a screen over 280 ms. Inverted
  /// in Settings › Controls.
  void _onVolumeKey(int d) {
    final ReadingPrefs p = ref.read(readingPrefsProvider);
    final int dir = p.volumeInvert ? -d : d;
    p.layout == ReaderLayout.scroll
        ? controller.scrollScreen(ComfortSpec.volumeScrollFraction * dir)
        : controller.turn(dir);
    _tracker.activity();
  }

  void _sleepExpired() {
    if (_tts?.playing ?? false) unawaited(_tts!.toggle());
    if (_auto.running) _auto.pause();
  }

  void _onSleep() {
    if (!_sleep.chapter) {
      _sleepSection = null;
    } else {
      final (int, int)? spoken = _tts?.current;
      _sleepSection ??= spoken == null ? controller.position.$1 : reading.positionOfIndex(spoken.$1).$1;
    }
  }

  void _onAuto() {
    final SharedPreferences p = ref.read(prefsProvider);
    unawaited(ComfortPrefs.setLevel(p, 'reader', _auto.level));
    unawaited(ComfortPrefs.setSeconds(p, _auto.seconds));
    // The screen stays on while it runs, even with Keep screen on off.
    if (!ref.read(readingPrefsProvider).keepScreenOn) unawaited(Platform.keepScreenOn(on: _auto.running));
    if (mounted) setState(() {});
  }

  /// "Chapter 3 · about 6 min left", at read-aloud pace if it is playing.
  String _chapterLeft() {
    final (int s, int b, int o) = controller.position;
    final Section sec = reading.sections[s];
    final int end = sec.blocks.isEmpty ? sec.start : sec.blocks.last.start + sec.blocks.last.text.length;
    final int words = reading.wordsBetween(sec.blocks[b].start + o, end);
    final double wpm = (_tts?.active ?? false) ? 160 * (_tts?.rate ?? 1) : (_wpm ?? 230);
    final String name = sec.title.isEmpty ? '${reading.unitLabel} ${s + 1}' : sec.title;
    return '$name · about ${math.max(1, (words / wpm).ceil())} min left';
  }

  Future<void> _openSleep() => showSleepTimerSheet(
    context,
    _sleep,
    chapterLeft: _chapterLeft(),
    readAloud: !_auto.enabled || (_tts?.active ?? false),
  );

  Future<void> _openComfort() =>
      showComfortSheet(context, auto: _auto, timer: _sleep, onSleep: () => unawaited(_openSleep()));

  Future<void> _readAloud({int? from}) async {
    final ReadAloud tts = _tts ??= ReadAloud(reading, volume: () => _sleep.volume)..addListener(_onTts);
    final ReadingPrefs p = ref.read(readingPrefsProvider);
    if (p.ttsVoice != null) await Platform.setVoice(p.ttsVoice);
    await tts.start(from ?? controller.globalIndex, speed: p.ttsRate);
    _clearSelection();
    _armAutoHide();
  }

  void _onTts() {
    final ReadAloud? t = _tts;
    if (t == null) return;
    controller.setSpoken(t.active ? t.current : null);
    _tracker.listening(on: t.playing);
    // While read aloud plays, the volume keys set the volume.
    unawaited(Platform.volumeKeys(on: ref.read(readingPrefsProvider).volumeKeys && !t.playing));
    final (int, int)? spoken = t.current;
    final int? sleepSection = _sleepSection;
    if (sleepSection != null && spoken != null && reading.positionOfIndex(spoken.$1).$1 > sleepSection) {
      _sleep.chapterEnded();
    }
    if (t.error != null && mounted) {
      AppSnackbar.error(context, t.error!);
      t.error = null;
    }
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------ search

  void _search(String q) {
    final String needle = q.trim().toLowerCase();
    final String hay = reading.plainText.toLowerCase();
    final List<int> hits = <int>[];
    if (needle.length >= 2) {
      int from = 0;
      while (hits.length < 500) {
        final int at = hay.indexOf(needle, from);
        if (at < 0) break;
        hits.add(at);
        from = at + needle.length;
      }
    }
    final int here0 = controller.globalIndex;
    setState(() {
      _query = needle;
      _hits = hits;
      _hit = hits.isEmpty ? 0 : math.max(0, hits.indexWhere((int h) => h >= here0));
    });
    _refreshMarks();
    if (hits.isNotEmpty) {
      _jumping = true;
      controller.goToIndex(hits[_hit]);
    }
  }

  void _step(int d) {
    if (_hits.isEmpty) return;
    setState(() => _hit = (_hit + d) % _hits.length);
    _refreshMarks();
    _jumping = true;
    controller.goToIndex(_hits[_hit]);
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _hits = const <int>[];
      _query = '';
    });
    _refreshMarks();
  }

  // ------------------------------------------------------------ sheets

  Future<void> _contents({int tab = 0}) async {
    final List<Annotation> marks = _annotations;
    final (int, int, int) at = controller.position;
    // One contents for the document, whichever mode shows it.
    final List<(String, int, (int, int, int))> entries = <(String, int, (int, int, int))>[
      if (widget.contents != null)
        for (final (String t, int level, Locator l) in widget.contents!) (t, level, l.resolveIn(reading))
      else
        for (final TocEntry t in reading.toc) (t.title, t.level, (t.section, t.block, 0)),
    ];
    int current = -1;
    for (int i = 0; i < entries.length; i++) {
      final (int s, int b, int _) = entries[i].$3;
      if (s < at.$1 || (s == at.$1 && b <= at.$2)) current = i;
    }
    await showReaderSheet<void>(context, heightFactor: 0.9, (BuildContext ctx) {
      void go((int, int, int) to) {
        Navigator.of(ctx).pop();
        _jump(to);
      }

      MarkRow row(Annotation a) => MarkRow(
        annotation: a,
        label: a.label.split(' · ').first,
        where: a.kind == 'bookmark' ? '${(a.progress * 100).round()}%' : a.label,
        onTap: () {
          final Locator l = Locator.fromJson(a.locator);
          go(l.resolveIn(reading));
        },
      );
      return ContentsSheet(
        title: reading.title.isEmpty ? doc.ref.name : reading.title,
        theme: _theme,
        initialTab: tab,
        toc: <TocRow>[
          for (int i = 0; i < entries.length; i++)
            TocRow(
              title: entries[i].$1,
              level: entries[i].$2,
              where: _whereOf(entries[i].$3),
              current: i == current,
              onTap: () => go(entries[i].$3),
            ),
        ],
        bookmarks: <MarkRow>[for (final Annotation a in marks.where((Annotation a) => a.kind == 'bookmark')) row(a)],
        highlights: <MarkRow>[for (final Annotation a in marks.where((Annotation a) => a.kind == 'highlight')) row(a)],
      );
    });
  }

  /// "p. 12" where the document has pages, else "34%".
  String _whereOf((int, int, int) at) {
    final SourceRef? src = reading.sections[at.$1].blocks[at.$2].source;
    final String? page = src == null ? null : widget.pageLabel?.call(src);
    return page ?? '${(reading.progressAt(at.$1, at.$2, at.$3) * 100).round()}%';
  }

  Future<void> exportHighlights() async {
    final List<Annotation> hl = _annotations.where((Annotation a) => a.kind == 'highlight').toList()
      ..sort((Annotation a, Annotation b) => a.progress.compareTo(b.progress));
    final String title = reading.title.isEmpty ? doc.ref.name : reading.title;
    final StringBuffer md = StringBuffer('# $title\n');
    if (reading.author != null) md.write('\n*${reading.author}*\n');
    for (final Annotation a in hl) {
      md.write('\n> ${a.quote.replaceAll('\n', '\n> ')}\n\n${a.label}\n');
      if (a.note != null) md.write('\n${a.note}\n');
    }
    await Platform.shareText(md.toString(), subject: 'Highlights from $title');
  }

  Future<void> bookInfo() async {
    final List<Annotation> hl = _annotations.where((Annotation a) => a.kind == 'highlight').toList();
    final int notes = hl.where((Annotation a) => a.note != null).length;
    final String title = reading.title.isEmpty ? doc.ref.name : reading.title;
    await showBookInfo(
      context,
      cover: CoverArt(
        title: title,
        author: reading.author,
        fingerprint: doc.fingerprint,
        format: format,
        width: 64,
        height: 92,
      ),
      title: title,
      author: reading.author,
      facts: <(String, String)>[
        ('Location', doc.ref.name),
        ('Size', '${Files.size(doc.ref.size)} · ${Formats.labelOf(doc.ref.name)}'),
        ('${reading.unitLabel}s', '${reading.sections.length}'),
        ('Progress', '${(controller.progress * 100).round()}% · $_where'),
        ('Highlights', '${hl.length}${notes > 0 ? ' · $notes ${notes == 1 ? 'note' : 'notes'}' : ''}'),
        ('Added', Files.when(doc.record.addedAt.millisecondsSinceEpoch)),
      ],
      highlights: hl.length,
      onExport: exportHighlights,
    );
  }

  Future<void> _overflow(BuildContext anchor) async {
    final String? choice = await showAppMenu<String>(
      context: context,
      anchorContext: anchor,
      entries: <AppMenuEntry<String>>[
        const AppMenuEntry<String>(value: 'info', label: 'Book info', icon: AppIcons.info),
        if (format.annotations)
          const AppMenuEntry<String>(value: 'export', label: 'Export highlights', icon: AppIcons.share),
        kInsightsEntry,
        const AppMenuEntry<String>(value: 'sleep', label: 'Sleep timer', icon: AppIcons.bedtime),
        AppMenuEntry<String>(
          value: 'auto',
          label: ref.read(readingPrefsProvider).layout == ReaderLayout.paged ? 'Auto page turn' : 'Auto-scroll',
          icon: AppIcons.schedule,
          switchValue: _auto.enabled,
        ),
        const AppMenuEntry<String>(value: 'share', label: 'Share file', icon: AppIcons.share),
        const AppMenuEntry<String>.divider(),
        AppMenuEntry<String>(
          value: 'other',
          label: 'Open in another app',
          icon: AppIcons.openInNew,
          subtitle: widget.approximate ? 'Rendered approximately' : null,
        ),
      ],
    );
    switch (choice) {
      case 'info':
        await bookInfo();
      case 'export':
        await exportHighlights();
      case 'insights':
        if (mounted) await showDocInsights(context, doc);
      case 'sleep':
        await _openSleep();
      case 'auto':
        await _openComfort();
      case 'share':
        await Platform.shareFile(doc.ref.uri, doc.ref.mime);
      case 'other':
        await Platform.openWith(doc.ref.uri, doc.ref.mime);
    }
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final ReadingPrefs prefs = ref.watch(readingPrefsProvider);
    final AppSettings settings = ref.watch(settingsProvider);
    final ReadingTheme theme = readingThemeOf(context, prefs, settings);
    ref.listen<ReadingPrefs>(readingPrefsProvider, (ReadingPrefs? a, ReadingPrefs b) {
      if (a?.theme != b.theme) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _refreshMarks());
      }
      if (a?.volumeKeys != b.volumeKeys) {
        unawaited(Platform.volumeKeys(on: b.volumeKeys));
      }
      if (a?.keepScreenOn != b.keepScreenOn) {
        unawaited(Platform.keepScreenOn(on: b.keepScreenOn));
      }
      if (a?.layout != b.layout) {
        // Paged turns on a timer; scrolling moves continuously.
        _auto
          ..pause()
          ..paged = b.layout == ReaderLayout.paged;
        if (_auto.enabled) _auto.play();
      }
    });
    final bool wide = MediaQuery.sizeOf(context).width >= 840;
    final ReaderStyle style = ReaderStyle.of(
      prefs,
      theme,
      book: format == Formats.epub || format == Formats.pdf,
      mono: reading.mono,
    );
    final (int s, int _, int _) = controller.position;
    final ReadAloud? tts = _tts;
    final Annotation? bookmark = _bookmarkHere;
    final bool selecting = controller.selection != null && _selectionRects.isNotEmpty;

    return PopScope(
      // Back closes a selection or search first, then leaves the book.
      canPop: !selecting && !_searching,
      onPopInvokedWithResult: (bool did, Object? _) {
        if (did) return;
        if (selecting) return _clearSelection();
        if (_searching) return _closeSearch();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: theme.paper.computeLuminance() > 0.4 && !_chrome || (!c.isDark && _chrome)
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: theme.paper,
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: AnimatedContainer(
                  duration: Motion.of(context, Motion.background),
                  color: theme.paper,
                  child: RepaintBoundary(
                    child: Listener(
                      // A touch on the page pauses auto-scroll (with a hint)
                      // and restarts a fading sleep timer.
                      onPointerDown: (_) {
                        if (_auto.running) _auto.pause(byTouch: true);
                        _sleep.touched();
                      },
                      child: TrackActivity(
                        child: ReaderView(
                          controller: controller,
                          style: style,
                          layoutMode: prefs.layout,
                          pageTurn: prefs.pageTurn.effective(reduced: Motion.reduced(context)),
                          columns: wide && prefs.layout == ReaderLayout.paged ? 2 : 1,
                          onCentreTap: _toggleChrome,
                          onLink: _onLink,
                          onMarkTap: (int id, Offset at) => id >= 0 ? _highlightMenu(id, at) : null,
                          onSelection: (List<Rect> r) => setState(() => _selectionRects = r),
                          onFontStep: _fontStep,
                          runningHead: ((int, int, int) at) => reading.sections[at.$1].title.isEmpty
                              ? (reading.title.isEmpty ? doc.ref.name : reading.title)
                              : reading.sections[at.$1].title,
                          footer: ((int, int, int) at) {
                            final SourceRef? src = reading.sections[at.$1].blocks[at.$2].source;
                            final String? page = src == null ? null : widget.pageLabel?.call(src);
                            final String pct = '${(reading.progressAt(at.$1, at.$2, at.$3) * 100).round()}%';
                            return (page == null ? pct : '$page · $pct', _timeLeft(controller.position));
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // A note rides with the chrome, under the top bar, so it never
              // sits on the text while reading.
              if (widget.overlay != null)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 64 + Space.sm,
                  left: Space.screen,
                  right: Space.screen,
                  child: IgnorePointer(
                    ignoring: !_chrome,
                    child: AnimatedSlide(
                      offset: _chrome ? Offset.zero : const Offset(0, -0.25),
                      duration: Motion.of(context, Motion.chromeToggle),
                      curve: Motion.decelerate,
                      child: AnimatedOpacity(
                        opacity: _chrome ? 1 : 0,
                        duration: Motion.of(context, Motion.chromeToggle),
                        curve: Motion.decelerate,
                        child: widget.overlay,
                      ),
                    ),
                  ),
                ),
              // Top chrome, or the search bar.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _searching
                    ? _searchBar(c)
                    : ChromeSlide(
                        visible: _chrome,
                        child: ReaderTopBar(
                          title: reading.title.isEmpty ? doc.ref.name : reading.title,
                          subtitle: _where,
                          onBack: () => Navigator.of(context).maybePop(),
                          toggle: widget.onPageMode == null
                              ? null
                              : ModeToggle(
                                  reader: true,
                                  pageIcon: widget.pageIcon,
                                  onChanged: (bool r) => r ? null : widget.onPageMode!(here),
                                ),
                          actions: <Widget>[
                            if (format.search)
                              AppIconButton(
                                icon: AppIcons.search,
                                filled: false,
                                semanticLabel: 'Search in book',
                                onPressed: () => setState(() => _searching = true),
                              ),
                            if (format.annotations && widget.onPageMode == null)
                              AppIconButton(
                                icon: bookmark != null ? AppIcons.bookmark : AppIcons.bookmarkAdd,
                                fill: bookmark != null,
                                tint: bookmark != null ? c.primary : null,
                                filled: false,
                                semanticLabel: bookmark != null ? 'Remove bookmark' : 'Bookmark this page',
                                onPressed: _toggleBookmark,
                              ),
                            Builder(
                              builder: (BuildContext b) => AppIconButton(
                                icon: AppIcons.moreVert,
                                filled: false,
                                semanticLabel: 'More options',
                                onPressed: () => _overflow(b),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              // Bottom chrome.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _searching
                    ? _results(c)
                    : ChromeSlide(
                        visible: _chrome && !(tts?.active ?? false),
                        fromTop: false,
                        child: ReaderBottomBar(
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  '${reading.unitLabel} ${s + 1} of ${reading.sections.length}',
                                  style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                                ),
                                Text(
                                  '${(controller.progress * 100).round()}%',
                                  style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                                ),
                              ],
                            ),
                            PageScrubber(
                              value: controller.progress,
                              tick: controller.progress,
                              label: (double v) {
                                final (int ss, int _, int _) = reading.positionAt(v);
                                final String t = reading.sections[ss].title;
                                return t.isEmpty ? '${reading.unitLabel} ${ss + 1}' : t;
                              },
                              onChanged: (double v) => _jumpWithBack(reading.positionAt(v)),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: <Widget>[
                                AppIconButton(
                                  icon: AppIcons.toc,
                                  filled: false,
                                  semanticLabel: 'Contents',
                                  onPressed: _contents,
                                ),
                                AppIconButton(
                                  icon: AppIcons.textFields,
                                  filled: false,
                                  semanticLabel: 'Reading settings',
                                  onPressed: () => showReadingSettings(context),
                                ),
                                if (format.tts)
                                  AppIconButton(
                                    icon: AppIcons.headphones,
                                    filled: false,
                                    semanticLabel: 'Read aloud',
                                    onPressed: _readAloud,
                                  ),
                                if (format.annotations && widget.onPageMode != null)
                                  AppIconButton(
                                    icon: bookmark != null ? AppIcons.bookmark : AppIcons.bookmarkAdd,
                                    fill: bookmark != null,
                                    tint: bookmark != null ? c.primary : null,
                                    filled: false,
                                    semanticLabel: bookmark != null ? 'Remove bookmark' : 'Bookmark this page',
                                    onPressed: _toggleBookmark,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
              // Read aloud.
              if (tts != null)
                AnimatedPositioned(
                  duration: Motion.of(context, Motion.sheet),
                  curve: Motion.decelerate,
                  left: 12,
                  right: 12,
                  bottom: tts.active ? MediaQuery.paddingOf(context).bottom + 16 : -120,
                  child: MiniPlayer(
                    playing: tts.playing,
                    rate: tts.rate,
                    onToggle: () => unawaited(tts.toggle()),
                    onPrevious: () => unawaited(tts.skip(-1)),
                    onNext: () => unawaited(tts.skip(1)),
                    onClose: () => unawaited(tts.stop()),
                    onSpeed: () =>
                        showVoiceSheet(context, rate: tts.rate, onRate: (double r) => unawaited(tts.setRate(r))),
                    sleep: SleepChip(timer: _sleep, onTap: () => unawaited(_openSleep())),
                  ),
                ),
              // Auto-scroll or auto page turn (board 6, V6).
              if (_auto.enabled)
                Positioned(
                  right: Space.lg,
                  bottom: MediaQuery.paddingOf(context).bottom + ((tts?.active ?? false) ? 100 : 28),
                  child: AutoControl(auto: _auto),
                ),
              // Back chip and size chip.
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + (_chrome ? 168 : 72),
                child: Center(
                  child: _sizeChip != null
                      ? TimedChip(
                          key: ValueKey<int>(_sizeChip!),
                          text: '${_sizeChip}px',
                          duration: const Duration(milliseconds: 900),
                        )
                      : _backChip != null
                      ? TimedChip(
                          key: ValueKey<String>(_backChip!),
                          text: _backChip!,
                          icon: AppIcons.back,
                          duration: const Duration(seconds: 6),
                          onTap: () {
                            final (int, int, int)? to = _backTo;
                            setState(() => _backChip = null);
                            if (to != null) _jump(to);
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              if (selecting) _toolbar(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar(ReadingTheme theme) {
    final Rect first = _selectionRects.first;
    final Rect last = _selectionRects.last;
    final double h = MediaQuery.sizeOf(context).height;
    final bool above = first.top > SelectionToolbar.clearance;
    final (int, int) sel = controller.selection!;
    // Above: pinned by its bottom edge, whatever its height at this text size.
    return Positioned(
      left: 14,
      right: 14,
      top: above ? null : math.min(h - SelectionToolbar.clearance, last.bottom + 28),
      bottom: above ? h - first.top + 8 : null,
      child: Reveal(
        child: SelectionToolbar(
          theme: theme,
          selectedColor: _highlightOver(sel)?.color,
          onCopy: () {
            unawaited(copyText(controller.selectedText));
            _clearSelection();
            AppSnackbar.info(context, 'Copied');
          },
          onHighlight: (int i) => unawaited(_highlight(i)),
          onNote: () => unawaited(_note()),
          onReadAloud: format.tts ? () => unawaited(_readAloud(from: sel.$1)) : null,
          onMore: (BuildContext anchor) => unawaited(_selectionMore(anchor, sel)),
          onDefine: () {
            final String word = controller.selectedText;
            _clearSelection();
            unawaited(defineInMull(context, word));
          },
        ),
      ),
    );
  }

  Widget _searchBar(UnfurlColors c) => Container(
    decoration: BoxDecoration(
      color: c.surface,
      border: Border(bottom: BorderSide(color: c.outline)),
    ),
    padding: EdgeInsets.fromLTRB(Space.md, MediaQuery.paddingOf(context).top + Space.xs, Space.sm, 10),
    child: Row(
      spacing: Space.xs,
      children: <Widget>[
        Expanded(
          child: SearchField(
            hint: 'Search in book',
            autofocus: true,
            height: 48,
            onChanged: _search,
            trailing: _query.isEmpty
                ? null
                : Text(
                    _hits.isEmpty ? 'No results' : '${_hit + 1} of ${_hits.length}',
                    style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                  ),
          ),
        ),
        AppIconButton(
          icon: AppIcons.arrowUp,
          filled: false,
          semanticLabel: 'Previous result',
          onPressed: _hits.isEmpty ? null : () => _step(-1),
        ),
        AppIconButton(
          icon: AppIcons.arrowDown,
          filled: false,
          semanticLabel: 'Next result',
          onPressed: _hits.isEmpty ? null : () => _step(1),
        ),
        AppIconButton(icon: AppIcons.close, filled: false, semanticLabel: 'Close search', onPressed: _closeSearch),
      ],
    ),
  );

  Widget _results(UnfurlColors c) {
    if (_hits.isEmpty) return const SizedBox.shrink();
    final int sections = _hits.map((int h) => reading.positionOfIndex(h).$1).toSet().length;
    final String t = reading.plainText;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.outline)),
      ),
      padding: EdgeInsets.only(top: 10, bottom: MediaQuery.paddingOf(context).bottom + Space.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _resultsOpen = !_resultsOpen),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.sm),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${_hits.length} ${_hits.length == 1 ? 'RESULT' : 'RESULTS'} · $sections ${reading.unitLabel.toUpperCase()}${sections == 1 ? '' : 'S'}',
                      style: UnfurlType.sectionHeader.copyWith(color: c.onSurfaceVariant),
                    ),
                  ),
                  AppIcon(
                    _resultsOpen ? AppIcons.expandMore : AppIcons.expandLess,
                    size: 18,
                    color: c.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.fast),
            curve: Motion.decelerate,
            child: !_resultsOpen
                ? const SizedBox(width: double.infinity)
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _hits.length,
                      itemBuilder: (BuildContext context, int i) {
                        final int h = _hits[i];
                        final int a = math.max(0, h - 28), b = math.min(t.length, h + _query.length + 40);
                        return Material(
                          color: i == _hit ? c.primaryContainer : Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() => _hit = i);
                              _refreshMarks();
                              _jumping = true;
                              controller.goToIndex(h);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Space.screen, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: Space.md,
                                children: <Widget>[
                                  SizedBox(
                                    width: 64,
                                    child: Text(
                                      _labelFor(h).split(' · ').first,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: UnfurlType.monoLabel.copyWith(
                                        color: i == _hit ? c.onPrimaryContainer : c.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: <TextSpan>[
                                          TextSpan(text: '…${t.substring(a, h).replaceAll('\n', ' ')}'),
                                          TextSpan(
                                            text: t.substring(h, math.min(t.length, h + _query.length)),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontVariations: <FontVariation>[FontVariation('wght', 700)],
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                '${t.substring(math.min(t.length, h + _query.length), b).replaceAll('\n', ' ')}…',
                                          ),
                                        ],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: UnfurlType.note.copyWith(
                                        height: 1.4,
                                        color: i == _hit ? c.onPrimaryContainer : c.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
