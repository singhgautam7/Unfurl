import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/library/enrich.dart';
import '../../core/library/library.dart';
import '../../core/locator.dart';
import '../../core/motion/motion.dart';
import '../../core/platform/platform.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/reading_theme.dart';
import '../../core/theme/tokens.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/app_menu.dart';
import '../../design_system/app_snackbar.dart';
import '../../design_system/buttons.dart';
import '../../formats/comics/comic_archive.dart';
import '../../formats/format_problem.dart';
import '../reader/chrome.dart';
import '../reader/reading_prefs.dart';
import '../reader/sheets.dart';
import '../settings/settings_controller.dart';
import '../viewer/document_screen.dart';
import 'comic_pages.dart';
import 'comic_prefs.dart';
import 'comic_sheets.dart';
import 'comic_views.dart';

/// CBZ, CBR, CB7 and CBT (board 6, V4): single page, two-page spreads
/// (automatic in landscape, the cover alone) and webtoon; fit width, height
/// or screen; right to left; zoom; a scrubber with thumbnails; bookmarks.
/// No highlights, Reader mode or read aloud, so none of their controls. The
/// reading theme sets only the surround.
class ComicsScreen extends ConsumerStatefulWidget {
  const ComicsScreen({required this.doc, super.key});

  final OpenedDoc doc;

  @override
  ConsumerState<ComicsScreen> createState() => _ComicsScreenState();
}

class _ComicsScreenState extends ConsumerState<ComicsScreen> with WidgetsBindingObserver {
  ComicArchive? _archive;
  ComicPages? _pages;
  FormatProblem? _problem;
  bool _damagedAccepted = false;
  int _page = 0;
  bool _chrome = false;
  bool _rtl = false;
  double? _zoomChip;
  List<Annotation> _bookmarks = const <Annotation>[];
  StreamSubscription<List<Annotation>>? _marksSub;
  Timer? _saveTimer;
  int? _lastSaved;
  final GlobalKey<PagedComicState> _paged = GlobalKey<PagedComicState>();
  final GlobalKey<WebtoonComicState> _webtoon = GlobalKey<WebtoonComicState>();

  /// Held so the position can be saved from dispose().
  late final Library _library = ref.read(libraryProvider);

  OpenedDoc get doc => widget.doc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_sizeImageCache());
    unawaited(_open());
    _marksSub = _library.watchAnnotations(doc.fingerprint).listen((List<Annotation> a) {
      if (mounted) setState(() => _bookmarks = a.where((Annotation x) => x.kind == 'bookmark').toList());
    });
    if (ref.read(readingPrefsProvider).keepScreenOn) unawaited(Platform.keepScreenOn(on: true));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
  }

  /// Decoded pages live in Flutter's image cache, sized from the device's
  /// memory class: a quarter of it, between 64 and 256 MB.
  static Future<void> _sizeImageCache() async {
    final int mb = await Platform.memoryClass();
    PaintingBinding.instance.imageCache.maximumSizeBytes = (mb ~/ 4).clamp(64, 256) << 20;
  }

  Future<void> _open() async {
    try {
      final ComicArchive c = await ComicArchive.open(doc.ref.uri);
      if (!mounted) return unawaited(c.close());
      final ComicPages pages = ComicPages(c, doc.fingerprint);
      final int? saved = doc.resume?.page;
      _page = ((saved ?? 1) - 1).clamp(0, c.pages.length - 1);
      _rtl = ref.read(comicPrefsProvider.notifier).rtlFor(doc.fingerprint, fallback: c.info?.rtl ?? false);
      setState(() {
        _archive = c;
        _pages = pages;
      });
      unawaited(pages.around(_page));
      // A comic opened from outside the library still gets its title and cover.
      if (doc.record.title == null && c.info?.displayTitle != null) {
        unawaited(
          _library.touch(
            doc.fingerprint,
            doc.ref,
            title: c.info!.displayTitle,
            author: c.info!.writer,
            issue: c.info!.issue,
            units: c.pages.length,
          ),
        );
      }
      if (!Covers.tried(doc.fingerprint)) {
        unawaited(
          pages.bytes(0).then((Uint8List? b) async {
            await Covers.write(doc.fingerprint, (b == null ? null : await Covers.comicCover(b)) ?? Uint8List(0));
          }),
        );
      }
    } on FormatProblem catch (p) {
      if (mounted) setState(() => _problem = p);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_save(force: true));
    _saveTimer?.cancel();
    unawaited(_marksSub?.cancel());
    _pages?.dispose();
    unawaited(_archive?.close());
    unawaited(Platform.keepScreenOn(on: false));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) unawaited(_save(force: true));
  }

  int get _count => _pages?.count ?? 0;

  Locator _locator(int page) => Locator(page: page + 1, progress: _count == 0 ? 0 : (page + 1) / _count);

  Future<void> _save({bool force = false}) async {
    if ((!mounted && !force) || _count == 0 || _page == _lastSaved) return;
    _lastSaved = _page;
    final double progress = (_page + 1) / _count;
    await _library.savePosition(
      doc.fingerprint,
      locator: _locator(_page).toJson(),
      progress: progress >= 0.995 ? 1 : progress,
      where: 'Page ${_page + 1} of $_count',
      mode: 'comics',
    );
  }

  void _onPage(int page) {
    if (page == _page) return;
    setState(() => _page = page);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  void _jump(int page) {
    _paged.currentState?.jumpTo(page);
    _webtoon.currentState?.jumpTo(page);
    _onPage(page);
    unawaited(_pages?.around(page));
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    unawaited(SystemChrome.setEnabledSystemUIMode(_chrome ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky));
  }

  // ------------------------------------------------------------ bookmarks

  Annotation? get _bookmarkHere =>
      _bookmarks.where((Annotation a) => ((a.progress * _count).round() - 1) == _page).firstOrNull;

  Future<void> _addBookmark() async {
    await _library.addAnnotation(
      AnnotationsCompanion.insert(
        fingerprint: doc.fingerprint,
        kind: 'bookmark',
        locator: _locator(_page).toJson(),
        label: Value<String>('Page ${_page + 1}'),
        progress: Value<double>((_page + 1) / _count),
        mode: const Value<String>('comics'),
        createdAt: DateTime.now(),
      ),
    );
    if (mounted) AppSnackbar.info(context, 'Bookmarked page ${_page + 1}');
  }

  Future<void> _removeBookmark(Annotation a) async {
    await _library.deleteAnnotation(a.id);
    if (mounted) AppSnackbar.undo(context, 'Bookmark removed', () => _library.restoreAnnotation(a));
  }

  Future<void> _toggleBookmark() async {
    final Annotation? here = _bookmarkHere;
    here == null ? await _addBookmark() : await _removeBookmark(here);
  }

  Future<void> _showBookmarks() => showComicBookmarks(
    context,
    pages: _pages!,
    bookmarks: _bookmarks,
    current: _page,
    onOpen: _jump,
    onDelete: _removeBookmark,
    onAdd: _addBookmark,
  );

  Future<void> _overflow(BuildContext anchor) async {
    final String? choice = await showAppMenu<String>(
      context: context,
      anchorContext: anchor,
      entries: const <AppMenuEntry<String>>[
        AppMenuEntry<String>(value: 'bookmarks', label: 'Bookmarks', icon: AppIcons.bookmark),
        AppMenuEntry<String>(value: 'share', label: 'Share file', icon: AppIcons.share),
        AppMenuEntry<String>.divider(),
        AppMenuEntry<String>(value: 'other', label: 'Open in another app', icon: AppIcons.openInNew),
      ],
    );
    switch (choice) {
      case 'bookmarks':
        await _showBookmarks();
      case 'share':
        await Platform.shareFile(doc.ref.uri, doc.ref.mime);
      case 'other':
        await Platform.openWith(doc.ref.uri, doc.ref.mime);
    }
  }

  void _setRtl(bool rtl) {
    setState(() => _rtl = rtl);
    unawaited(ref.read(comicPrefsProvider.notifier).setRtl(doc.fingerprint, rtl: rtl));
  }

  String get _title {
    final ComicInfo? i = _archive?.info;
    final String? t = i?.displayTitle;
    if (t == null) return doc.ref.name;
    return i?.issue == null ? t : '$t · ${i!.issue}';
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final FormatProblem? problem = _problem;
    if (problem != null) return problemState(context, doc.ref, problem);
    final ComicArchive? archive = _archive;
    final ComicPages? pages = _pages;
    if (archive == null || pages == null) return OpeningCard(ref: doc.ref);
    if (archive.damaged && !_damagedAccepted) {
      final int total = archive.info?.pageCount ?? archive.total ?? archive.pages.length;
      return problemState(
        context,
        doc.ref,
        FormatProblem(ProblemKind.damaged, 'Damaged archive', readable: (archive.pages.length, total)),
        onOpenReadable: () => setState(() => _damagedAccepted = true),
      );
    }
    final UnfurlColors c = context.colors;
    final ComicPrefs prefs = ref.watch(comicPrefsProvider);
    final ThemeFamily family = ref.watch(settingsProvider.select((AppSettings s) => s.family));
    final ReadingTheme surround = ReadingTheme.of(family, prefs.surround ?? _defaultSurround(context));
    final Size size = MediaQuery.sizeOf(context);
    final bool landscape = size.width > size.height;
    final bool spreads =
        prefs.mode == ComicMode.spread || (prefs.mode == ComicMode.single && prefs.spreadInLandscape && landscape);
    final Annotation? bookmark = _bookmarkHere;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: surround.paper.computeLuminance() > 0.4 && !_chrome || (!c.isDark && _chrome)
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: surround.paper,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.background),
                color: surround.paper,
                child: RepaintBoundary(
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.fast),
                    switchInCurve: Motion.decelerate,
                    child: prefs.mode == ComicMode.webtoon
                        ? WebtoonComic(key: _webtoon, pages: pages, page: _page, onPage: _onPage, onTap: _toggleChrome)
                        : ValueListenableBuilder<int>(
                            key: const ValueKey<String>('paged'),
                            valueListenable: pages.measured,
                            builder: (BuildContext context, int _, Widget? _) => PagedComic(
                              key: _paged,
                              pages: pages,
                              spreads: spreads
                                  ? comicSpreads(pages.count, coverAlone: prefs.coverAlone, wide: pages.wide)
                                  : <List<int>>[
                                      for (int i = 0; i < pages.count; i++) <int>[i],
                                    ],
                              page: _page,
                              rtl: _rtl,
                              fit: prefs.fit,
                              onPage: _onPage,
                              onTap: (TapZone z) => z == TapZone.centre ? _toggleChrome() : null,
                              onZoom: (double s) {
                                final double rounded = (s * 20).round() / 20;
                                if (rounded != _zoomChip && (s > 1.01 || _zoomChip != null)) {
                                  setState(() => _zoomChip = s > 1.01 ? rounded : null);
                                }
                              },
                            ),
                          ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ChromeSlide(
                visible: _chrome,
                child: ReaderTopBar(
                  title: _title,
                  onBack: () => Navigator.of(context).maybePop(),
                  actions: <Widget>[
                    AppIconButton(
                      icon: bookmark != null ? AppIcons.bookmark : AppIcons.bookmarkAdd,
                      fill: bookmark != null,
                      tint: bookmark != null ? c.primary : null,
                      filled: false,
                      semanticLabel: bookmark != null ? 'Remove bookmark' : 'Bookmark this page',
                      onPressed: _toggleBookmark,
                    ),
                    AppIconButton(
                      icon: AppIcons.tune,
                      filled: false,
                      semanticLabel: 'Comic settings',
                      onPressed: () => showComicSettings(context, rtl: _rtl, onRtl: _setRtl),
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ChromeSlide(
                visible: _chrome,
                fromTop: false,
                child: ReaderBottomBar(
                  padding: const EdgeInsets.only(top: Space.md),
                  children: <Widget>[ComicScrubber(pages: pages, page: _page, rtl: _rtl, onJump: _jump)],
                ),
              ),
            ),
            // "250%" for a second after a zoom (board 6, V4).
            if (_zoomChip != null)
              Positioned(
                top: MediaQuery.paddingOf(context).top + Space.xl,
                left: 0,
                right: 0,
                child: Center(
                  child: TimedChip(
                    key: ValueKey<double>(_zoomChip!),
                    text: '${(_zoomChip! * 100).round()}%',
                    duration: const Duration(seconds: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The reading theme, mapped onto the four surrounds comics offer.
  ReadingThemeId _defaultSurround(BuildContext context) {
    final ReadingThemeId id = readingThemeOf(context, ref.read(readingPrefsProvider), ref.read(settingsProvider)).id;
    return switch (id) {
      ReadingThemeId.sepia => ReadingThemeId.sepia,
      ReadingThemeId.dark || ReadingThemeId.dusk => ReadingThemeId.dark,
      ReadingThemeId.amoled => ReadingThemeId.amoled,
      _ => ReadingThemeId.light,
    };
  }
}
