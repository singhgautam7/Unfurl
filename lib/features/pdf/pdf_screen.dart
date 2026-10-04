import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:vector_math/vector_math_64.dart' show Quad;

import '../../core/db/database.dart';
import '../../core/files.dart';
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
import '../../core/theme/typography.dart';
import '../../core/tracking/tracker.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/app_menu.dart';
import '../../design_system/app_snackbar.dart';
import '../../design_system/buttons.dart';
import '../../design_system/chips.dart';
import '../../design_system/covers.dart';
import '../../design_system/search_field.dart';
import '../../design_system/sheets.dart';
import '../../design_system/states.dart';
import '../../formats/pdf/pdf_reflow.dart';
import '../../formats/reading_document.dart';
import '../reader/chrome.dart';
import '../reader/reader_scaffold.dart';
import '../reader/reading_prefs.dart';
import '../reader/sheets.dart';
import '../reader/unfurl_transition.dart';
import '../settings/settings_controller.dart';
import '../insights/book_insights.dart';
import '../viewer/document_screen.dart';
import 'pdf_render.dart';
import 'pdf_text.dart';

/// Reflowed PDFs, by fingerprint, for the session.
final Map<String, ReadingDocument> _reflowCache = <String, ReadingDocument>{};

/// PDF: faithful Page view by default (or Reader, per Settings), with the
/// Page ⇄ Reader toggle (R1 to R6).
class PdfScreen extends ConsumerStatefulWidget {
  const PdfScreen({required this.doc, super.key});

  final OpenedDoc doc;

  @override
  ConsumerState<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends ConsumerState<PdfScreen> with WidgetsBindingObserver {
  int? _fd;
  PdfDocument? _pdf;
  PageRenderer? _renderer;
  bool _failed = false;
  bool _cancelled = false;
  List<PdfOutlineNode> _outline = const <PdfOutlineNode>[];
  final Map<int, PageText> _texts = <int, PageText>{};
  final Map<int, List<PdfLink>> _links = <int, List<PdfLink>>{};
  final Map<int, Rect> _crops = <int, Rect>{};

  bool _reader = false;
  ReadingDocument? _reflow;
  bool _reflowing = false;

  /// Reader mode's preparation, 0..1: reading each page's text, then laying it out.
  final ValueNotifier<double> _reflowProgress = ValueNotifier<double>(0);
  Locator? _readerStart;
  bool _simplifiedSeen = false;
  final GlobalKey<ReaderScaffoldState> _readerKey = GlobalKey<ReaderScaffoldState>();

  final GlobalKey<_PagesState> _pagesKey = GlobalKey<_PagesState>();
  bool _chrome = false;
  int _page = 1;
  double _pageOffset = 0;
  int? _lastPage;
  String? _backChip;
  int? _backTo;
  List<Annotation> _annotations = const <Annotation>[];
  StreamSubscription<List<Annotation>>? _annSub;
  StreamSubscription<int>? _volSub;
  Timer? _saveTimer;

  /// Held so the position can still be saved from dispose().
  late final Library _library;

  // Selection: page and character range.
  (int, int, int)? _selection;
  Rect? _selectionRect;

  // Search.
  bool _searching = false;
  String _query = '';
  List<(int, int)> _hits = const <(int, int)>[];
  int _hit = 0;
  int _indexed = 0;
  bool _resultsOpen = true;

  OpenedDoc get doc => widget.doc;
  int get _pages => _pdf?.pages.length ?? 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final Locator? at = doc.resume;
    final String mode =
        doc.mode ?? doc.record.mode ?? (ref.read(readingPrefsProvider).pdfOpensReader ? 'reader' : 'page');
    _reader = mode == 'reader';
    _readerStart = at;
    _page = at?.page ?? 1;
    _library = ref.read(libraryProvider);
    _simplifiedSeen = ref.read(prefsProvider).getBool('pdf.simplified.${doc.fingerprint}') ?? false;
    _annSub = ref.read(libraryProvider).watchAnnotations(doc.fingerprint).listen((List<Annotation> a) {
      if (mounted) setState(() => _annotations = a);
    });
    _volSub = Platform.volumeKeyPresses.listen((int d) {
      if (!_reader) _goToPage(_page + d, animate: true);
    });
    final ReadingPrefs prefs = ref.read(readingPrefsProvider);
    if (prefs.keepScreenOn) unawaited(Platform.keepScreenOn(on: true));
    if (prefs.volumeKeys) unawaited(Platform.volumeKeys(on: true));
    if (prefs.brightness != null) {
      unawaited(Platform.setBrightness(prefs.brightness));
    }
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    unawaited(_open());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The document closes below, so the last position is taken from text
    // already read for this page, or the page alone.
    if (!_reader && _pdf != null) unawaited(_save(locator: _pageLocatorNow()));
    _saveTimer?.cancel();
    unawaited(_annSub?.cancel());
    unawaited(_volSub?.cancel());
    _renderer?.dispose();
    _reflowProgress.dispose();
    unawaited(_pdf?.dispose());
    if (_fd != null) unawaited(Platform.closeFd(_fd!));
    unawaited(Platform.keepScreenOn(on: false));
    unawaited(Platform.volumeKeys(on: false));
    unawaited(Platform.setBrightness(null));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_reader) unawaited(_save());
  }

  // ------------------------------------------------------------ open

  Future<void> _open() async {
    await pdfrxFlutterInitialize();
    _fd = await Platform.openFd(doc.ref.uri);
    if (_fd == null) return setState(() => _failed = true);
    int attempts = 0;
    try {
      final PdfDocument pdf = await Files.openPdf(
        Fd(_fd!),
        name: doc.ref.name,
        passwordProvider: () async {
          if (!mounted) return null;
          final String? pw = await _askPassword(wrong: attempts++ > 0);
          if (pw == null) _cancelled = true;
          return pw;
        },
      );
      if (!mounted) return;
      final int dpr = (MediaQuery.devicePixelRatioOf(context) * 10).round();
      _pdf = pdf;
      // A file opened from outside the library gets its cover here.
      if (!Covers.tried(doc.fingerprint)) {
        unawaited(
          Covers.renderFirstPage(pdf).then((Uint8List? png) => Covers.write(doc.fingerprint, png ?? Uint8List(0))),
        );
      }
      _renderer = PageRenderer(pdf, budgetBytes: dpr > 30 ? 128 * 1024 * 1024 : 80 * 1024 * 1024);
      _page = _page.clamp(1, pdf.pages.length);
      await ref.read(libraryProvider).touch(doc.fingerprint, doc.ref, units: pdf.pages.length);
      if (!mounted) return;
      setState(() {});
      unawaited(
        pdf.loadOutline().then((List<PdfOutlineNode> o) {
          if (mounted) setState(() => _outline = o);
        }),
      );
      if (_reader) {
        unawaited(_ensureReflow());
      } else if (_readerStart?.page != null) {
        unawaited(_restorePagePosition(_readerStart!));
      }
    } catch (_) {
      if (!mounted) return;
      if (_cancelled) {
        Navigator.of(context).maybePop();
      } else {
        setState(() => _failed = true);
      }
    }
  }

  Future<void> _restorePagePosition(Locator at) async {
    final int p = (at.page ?? 1).clamp(1, _pages);
    final PageText t = await _text(p);
    final int index =
        at.pageStart != null &&
            at.exact.isNotEmpty &&
            at.pageStart! + at.exact.length <= t.text.length &&
            t.text.substring(at.pageStart!, at.pageStart! + at.exact.length) == at.exact
        ? at.pageStart!
        : (at.quoteSearch(t.text) ?? at.pageStart ?? 0);
    final double y = index < t.rects.length ? t.rects[index].top : 0;
    if (mounted) _pagesKey.currentState?.goTo(p, fraction: y, animate: false);
  }

  Future<String?> _askPassword({required bool wrong}) {
    final TextEditingController field = TextEditingController();
    bool hidden = true;
    return showAppBottomSheet<String>(
      context: context,
      icon: AppIcons.lock,
      title: 'This PDF is locked',
      description: wrong
          ? 'That password didn’t work. Try again.'
          : 'Enter its password to open it. Unfurl does not save it.',
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter set) {
          final UnfurlColors c = ctx.colors;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Space.lg,
            children: <Widget>[
              Container(
                height: 56,
                padding: const EdgeInsets.only(left: 18, right: 6),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Space.lg),
                  border: Border.all(color: c.primary, width: 1.5),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: field,
                        autofocus: true,
                        obscureText: hidden,
                        onSubmitted: (String v) => Navigator.of(ctx).pop(v),
                        style: UnfurlType.monoTabular.copyWith(
                          fontSize: 16,
                          letterSpacing: hidden ? 3.2 : 0,
                          color: c.onSurface,
                        ),
                        decoration: const InputDecoration.collapsed(hintText: ''),
                      ),
                    ),
                    AppIconButton(
                      icon: hidden ? AppIcons.visibility : AppIcons.visibilityOff,
                      filled: false,
                      semanticLabel: hidden ? 'Show password' : 'Hide password',
                      onPressed: () => set(() => hidden = !hidden),
                    ),
                  ],
                ),
              ),
              Row(
                spacing: 10,
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      label: 'Cancel',
                      type: AppButtonType.secondary,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  Expanded(
                    child: AppButton(label: 'Open', onPressed: () => Navigator.of(ctx).pop(field.text)),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<PageText> _text(int page) async {
    final PageText? t = _texts[page];
    if (t != null) return t;
    final PageText loaded = await PageText.load(_pdf!.pages[page - 1]);
    _texts[page] = loaded;
    if (mounted) setState(() {});
    return loaded;
  }

  Future<List<PdfLink>> _linksOf(int page) async =>
      _links[page] ??= await _pdf!.pages[page - 1].loadLinks(compact: true);

  // ------------------------------------------------------------ reader mode

  Future<void> _ensureReflow() async {
    final ReadingDocument? cached = _reflowCache[doc.fingerprint];
    if (cached != null) return setState(() => _reflow = cached);
    if (_reflowing || _pdf == null) return;
    setState(() => _reflowing = true);
    final List<PdfPageInput> inputs = <PdfPageInput>[];
    final Map<String, Uint8List> images = <String, Uint8List>{};
    final List<PdfPage> pages = _pdf!.pages;
    _reflowProgress.value = 0;
    for (final PdfPage p in pages) {
      if (!mounted) return;
      final PdfPageRawText? raw = await p.loadText();
      final PdfPageInput text = PdfPageInput(
        text: raw?.fullText ?? '',
        rects: <double>[
          for (final PdfRect r in raw?.charRects ?? const <PdfRect>[]) ...<double>[r.left, r.top, r.right, r.bottom],
        ],
        width: p.width,
        height: p.height,
      );
      // Tables become text; figures stay pictures, kept as sharp crops.
      final (List<double> regions, List<PdfTable> tables) = await _regions(p, text);
      for (int k = 0; k + 3 < regions.length; k += 4) {
        final Uint8List? png = await _crop(p, regions.sublist(k, k + 4));
        if (png != null) images[PdfReflow.regionKey(p.pageNumber, k ~/ 4)] = png;
      }
      if (!mounted) return;
      _reflowProgress.value = 0.9 * (inputs.length + 1) / pages.length;
      inputs.add(
        PdfPageInput(
          text: text.text,
          rects: text.rects,
          width: text.width,
          height: text.height,
          regions: regions,
          tables: tables,
        ),
      );
    }
    final ReadingDocument r;
    try {
      r = await _analyse(inputs, doc.record.title ?? _stem(doc.ref.name), images);
    } catch (_) {
      if (mounted) setState(() => _reflowing = false);
      rethrow;
    }
    _reflowCache[doc.fingerprint] = r;
    if (mounted) {
      setState(() {
        _reflow = r;
        _reflowing = false;
      });
    }
  }

  /// Static, so the isolate's closure carries only the page text.
  static Future<ReadingDocument> _analyse(List<PdfPageInput> inputs, String title, Map<String, Uint8List> images) =>
      Isolate.run(() => PdfReflow.analyse(inputs, title: title, images: images));

  /// The page drawn 720px wide (rules a point thick still show), searched
  /// off the UI isolate: figures (l, t, r, b each) and tables.
  static Future<(List<double>, List<PdfTable>)> _regions(PdfPage page, PdfPageInput text) async {
    const int w = 720;
    final PdfImage? img = await page.render(
      fullWidth: w.toDouble(),
      fullHeight: w * page.height / page.width,
      backgroundColor: 0xFFFFFFFF,
    );
    if (img == null) return Isolate.run(() => _split(text, null, 0, 0));
    final TransferableTypedData px = TransferableTypedData.fromList(<Uint8List>[Uint8List.fromList(img.pixels)]);
    final int iw = img.width, ih = img.height;
    img.dispose();
    return Isolate.run(() => _split(text, px.materialize().asUint8List(), iw, ih));
  }

  static (List<double>, List<PdfTable>) _split(PdfPageInput text, Uint8List? px, int w, int h) {
    final List<double> found = PdfReflow.findRegions(text, px, w, h);
    final List<double> pictures = <double>[];
    final List<PdfTable> tables = <PdfTable>[];
    for (int k = 0; k + 3 < found.length; k += 4) {
      final List<double> box = found.sublist(k, k + 4);
      final PdfTable? t = PdfReflow.tableGrid(text, box, px, w, h);
      t == null ? pictures.addAll(box) : tables.add(t);
    }
    return (pictures, tables);
  }

  /// One region (l, t, r, b in PDF units) as a PNG, at one scale per page
  /// (the page about 1100px wide), so regions keep their relative sizes.
  static Future<Uint8List?> _crop(PdfPage page, List<double> r) async {
    final double k = (1100 / math.max(1, page.width)).clamp(1.5, 3.0);
    final PdfImage? img = await page.render(
      x: (r[0] * k).round(),
      y: ((page.height - r[1]) * k).round(),
      width: ((r[2] - r[0]) * k).round(),
      height: ((r[1] - r[3]) * k).round(),
      fullWidth: page.width * k,
      fullHeight: page.height * k,
      backgroundColor: 0xFFFFFFFF,
    );
    if (img == null) return null;
    try {
      final ui.Image image = await img.createImage();
      final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return png?.buffer.asUint8List();
    } finally {
      img.dispose();
    }
  }

  static String _stem(String n) => n.contains('.') ? n.substring(0, n.lastIndexOf('.')) : n;

  Future<void> _toReader() async {
    // First time: switch at once; the loading card covers the reflow, and
    // the position is known long before the reader is.
    if (_reflow == null) setState(() => _reader = true);
    // Where the eye is, not the top line: a table mid-screen opens on the
    // reader page that holds it. No quote, so the page hints decide (a
    // table's own words aren't in the reflow).
    final (int page, double y) = _pagesKey.currentState?.focus() ?? (_page, _pageOffset);
    final PageText t = await _text(page);
    final Locator here = Locator(page: page, pageStart: t.firstAtOrBelow(y), progress: (page - 1 + y) / _pages);
    if (!mounted) return;
    setState(() {
      _readerStart = here;
      _reader = true;
      _selection = null;
      _searching = false;
    });
    await _ensureReflow();
  }

  void _toPage(Locator at) {
    // The page view isn't mounted while Reader mode fills the screen: it
    // comes back on the right page, then settles on the exact line once it
    // exists (next frame).
    setState(() {
      _reader = false;
      _readerStart = at;
      _page = (at.page ?? _page).clamp(1, _pages);
      _pageOffset = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_restorePagePosition(at));
    });
    unawaited(_save(locator: at));
  }

  // ------------------------------------------------------------ position

  Locator _pageLocatorNow() {
    final PageText? t = _texts[_page];
    return t == null ? Locator.inPage(_page, '', 0, progress: (_page - 1 + _pageOffset) / _pages) : _locatorIn(t);
  }

  Locator _locatorIn(PageText t) {
    final int i = t.firstAtOrBelow(_pageOffset);
    return Locator.inPage(
      _page,
      t.text,
      i,
      length: math.min(24, math.max(0, t.text.length - i)),
      progress: (_page - 1 + _pageOffset) / _pages,
    );
  }

  Future<Locator> _pageLocator() async {
    final PageText t = await _text(_page);
    final int i = t.firstAtOrBelow(_pageOffset);
    return Locator.inPage(
      _page,
      t.text,
      i,
      length: math.min(24, math.max(0, t.text.length - i)),
      progress: (_page - 1 + _pageOffset) / _pages,
    );
  }

  void _onPageChanged(int page, double offset) {
    final bool changed = page != _page;
    _page = page;
    _pageOffset = offset;
    if (changed) {
      setState(() {});
      unawaited(_text(page));
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _save);
  }

  Future<void> _save({Locator? locator}) async {
    if (_pdf == null) return;
    final Locator l = locator ?? await _pageLocator();
    await _library.savePosition(
      doc.fingerprint,
      locator: l.toJson(),
      progress: _page >= _pages && _pageOffset > 0.5 ? 1 : (_page - 1 + _pageOffset) / _pages,
      where: 'Page ${l.page ?? _page} of $_pages',
      mode: _reader ? 'reader' : 'page',
    );
  }

  void _goToPage(int page, {bool animate = false, double fraction = 0}) {
    final int p = page.clamp(1, _pages);
    _pagesKey.currentState?.goTo(p, fraction: fraction, animate: animate);
  }

  void _jumpWithBack(int page) {
    final int from = _page;
    _goToPage(page);
    setState(() {
      _backTo = from;
      _backChip = 'Back to p. $from';
    });
  }

  // ------------------------------------------------------------ annotations

  ReadingTheme get _theme => readingThemeOf(context, ref.read(readingPrefsProvider), ref.read(settingsProvider));

  /// Highlights, search hits and the selection to draw on a page, as page
  /// fractions.
  List<(Rect, Color)> _paintFor(int page) {
    final PageText? t = _texts[page];
    if (t == null) return const <(Rect, Color)>[];
    final ReadingTheme theme = _theme;
    final List<(Rect, Color)> out = <(Rect, Color)>[];
    for (final Annotation a in _annotations.where((Annotation a) => a.kind == 'highlight')) {
      final Locator l = Locator.fromJson(a.locator);
      if (l.page != page) continue;
      final int start =
          (l.pageStart != null &&
              l.pageStart! + l.exact.length <= t.text.length &&
              t.text.substring(l.pageStart!, l.pageStart! + l.exact.length) == l.exact)
          ? l.pageStart!
          : (l.quoteSearch(t.text) ?? -1);
      if (start < 0) continue;
      for (final Rect r in t.boxes(start, start + math.max(l.length, l.exact.length))) {
        out.add((r, theme.highlights[(a.color ?? 0).clamp(0, 3)]));
      }
    }
    for (int i = 0; i < _hits.length; i++) {
      if (_hits[i].$1 != page) continue;
      for (final Rect r in t.boxes(_hits[i].$2, _hits[i].$2 + _query.length)) {
        out.add((r, theme.handle.withValues(alpha: i == _hit ? 0.55 : 0.28)));
      }
    }
    final (int, int, int)? s = _selection;
    if (s != null && s.$1 == page) {
      for (final Rect r in t.boxes(s.$2, s.$3)) {
        out.add((r, theme.handle.withValues(alpha: 0.30)));
      }
    }
    return out;
  }

  void _onLongPress(int page, Offset fraction, Rect Function(Rect) toGlobal) {
    final PageText? t = _texts[page];
    if (t == null) return;
    final int? i = t.indexAt(fraction);
    if (i == null) return;
    final (int a, int b) = t.wordAt(i);
    setState(() {
      _selection = (page, a, b);
      final List<Rect> boxes = t.boxes(a, b);
      _selectionRect = boxes.isEmpty ? null : toGlobal(boxes.reduce((Rect x, Rect y) => x.expandToInclude(y)));
    });
  }

  void _extendSelection(int page, Offset fraction, Rect Function(Rect) toGlobal) {
    final (int, int, int)? s = _selection;
    final PageText? t = _texts[page];
    if (s == null || s.$1 != page || t == null) return;
    final int? i = t.indexAt(fraction);
    if (i == null) return;
    setState(() {
      _selection = i < s.$2 ? (page, i, s.$3) : (page, s.$2, i + 1);
      final List<Rect> boxes = t.boxes(_selection!.$2, _selection!.$3);
      _selectionRect = boxes.isEmpty ? null : toGlobal(boxes.reduce((Rect x, Rect y) => x.expandToInclude(y)));
    });
  }

  void _clearSelection() => setState(() {
    _selection = null;
    _selectionRect = null;
  });

  String get _selectedText {
    final (int, int, int)? s = _selection;
    final PageText? t = s == null ? null : _texts[s.$1];
    return t == null ? '' : t.text.substring(s!.$2, math.min(s.$3, t.text.length));
  }

  Annotation? _highlightOver((int, int, int) s) {
    for (final Annotation a in _annotations.where((Annotation a) => a.kind == 'highlight')) {
      final Locator l = Locator.fromJson(a.locator);
      if (l.page == s.$1 && l.pageStart != null && l.pageStart! < s.$3 && l.pageStart! + l.length > s.$2) {
        return a;
      }
    }
    return null;
  }

  Future<int> _addHighlight((int, int, int) s, int color) async {
    final PageText t = await _text(s.$1);
    final Locator l = Locator.inPage(s.$1, t.text, s.$2, length: s.$3 - s.$2, progress: (s.$1 - 1) / _pages);
    return ref
        .read(libraryProvider)
        .addAnnotation(
          AnnotationsCompanion.insert(
            fingerprint: doc.fingerprint,
            kind: 'highlight',
            color: Value<int?>(color),
            locator: l.toJson(),
            quote: Value<String>(_selectedText.replaceAll('\r\n', ' ').replaceAll('\n', ' ').trim()),
            label: Value<String>('p. ${s.$1}'),
            progress: Value<double>(l.progress),
            mode: const Value<String>('page'),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> _highlight(int color) async {
    final (int, int, int)? s = _selection;
    if (s == null) return;
    final Annotation? over = _highlightOver(s);
    if (over != null) {
      await ref.read(libraryProvider).updateAnnotation(over.id, color: color);
    } else {
      await _addHighlight(s, color);
    }
  }

  Future<void> _note() async {
    final (int, int, int)? s = _selection;
    if (s == null) return;
    final String quote = _selectedText;
    final Annotation? over = _highlightOver(s);
    final int id = over?.id ?? await _addHighlight(s, 0);
    _clearSelection();
    if (!mounted) return;
    final String? text = await showNoteSheet(
      context,
      quote: quote,
      color: _theme.highlights[over?.color ?? 0],
      initial: over?.note,
    );
    if (text != null) {
      await ref.read(libraryProvider).updateAnnotation(id, note: text.isEmpty ? null : text, clearNote: text.isEmpty);
    }
  }

  Future<void> _tapHighlight(int page, Offset fraction) async {
    final PageText? t = _texts[page];
    if (t == null) return;
    final int? i = t.indexAt(fraction);
    if (i == null) return;
    for (final Annotation a in _annotations.where((Annotation a) => a.kind == 'highlight')) {
      final Locator l = Locator.fromJson(a.locator);
      if (l.page == page && l.pageStart != null && i >= l.pageStart! && i < l.pageStart! + l.length) {
        final String? text = await showNoteSheet(
          context,
          quote: a.quote,
          color: _theme.highlights[a.color ?? 0],
          initial: a.note,
          onDelete: () async {
            await ref.read(libraryProvider).deleteAnnotation(a.id);
            if (mounted) {
              AppSnackbar.undo(context, 'Highlight removed', () => ref.read(libraryProvider).restoreAnnotation(a));
            }
          },
        );
        if (text != null) {
          await ref
              .read(libraryProvider)
              .updateAnnotation(a.id, note: text.isEmpty ? null : text, clearNote: text.isEmpty);
        }
        return;
      }
    }
  }

  Annotation? get _bookmarkHere => _annotations
      .where((Annotation a) => a.kind == 'bookmark' && Locator.fromJson(a.locator).page == _page)
      .firstOrNull;

  Future<void> _toggleBookmark() async {
    final Annotation? b = _bookmarkHere;
    if (b != null) {
      await ref.read(libraryProvider).deleteAnnotation(b.id);
      if (mounted) {
        AppSnackbar.undo(context, 'Bookmark removed', () => ref.read(libraryProvider).restoreAnnotation(b));
      }
      return;
    }
    final PageText t = await _text(_page);
    final Locator l = Locator.inPage(
      _page,
      t.text,
      0,
      length: math.min(24, t.text.length),
      progress: (_page - 1) / _pages,
    );
    await ref
        .read(libraryProvider)
        .addAnnotation(
          AnnotationsCompanion.insert(
            fingerprint: doc.fingerprint,
            kind: 'bookmark',
            locator: l.toJson(),
            quote: Value<String>(
              '${t.text.replaceAll(RegExp(r'\s+'), ' ').trim().substring(0, math.min(60, t.text.trim().length))}…',
            ),
            label: Value<String>('Page $_page'),
            progress: Value<double>(l.progress),
            mode: const Value<String>('page'),
            createdAt: DateTime.now(),
          ),
        );
    if (mounted) AppSnackbar.info(context, 'Bookmarked page $_page');
  }

  // ------------------------------------------------------------ search

  Future<void> _search(String q) async {
    final String needle = q.trim().toLowerCase();
    setState(() {
      _query = needle;
      _hits = const <(int, int)>[];
      _hit = 0;
      _indexed = 0;
    });
    if (needle.length < 2) return;
    final List<(int, int)> hits = <(int, int)>[];
    for (int p = 1; p <= _pages; p++) {
      if (_query != needle || !mounted) return;
      final String hay = (await _text(p)).text.toLowerCase();
      int from = 0;
      while (true) {
        final int at = hay.indexOf(needle, from);
        if (at < 0) break;
        hits.add((p, at));
        from = at + needle.length;
      }
      // The count updates as the index builds.
      setState(() {
        _hits = List<(int, int)>.of(hits);
        _indexed = p;
      });
      if (hits.isNotEmpty && hits.length == hits.where(((int, int) h) => h.$1 == p).length && p == hits.first.$1) {
        _goToHit(0);
      }
    }
  }

  void _goToHit(int i) {
    if (_hits.isEmpty) return;
    setState(() => _hit = i % _hits.length);
    final (int p, int idx) = _hits[_hit];
    final PageText? t = _texts[p];
    _goToPage(p, fraction: t != null && idx < t.rects.length ? math.max(0, t.rects[idx].top - 0.1) : 0);
  }

  // ------------------------------------------------------------ chrome

  void _toggleChrome() {
    if (_searching) return;
    setState(() => _chrome = !_chrome);
    unawaited(SystemChrome.setEnabledSystemUIMode(_chrome ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky));
  }

  /// The PDF's contents as (title, page, level): its own outline when it has
  /// one, else the headings Reader mode found. Page and Reader mode show the
  /// same list.
  List<(String, int, int)> get _toc {
    final List<(String, int, int)> toc = <(String, int, int)>[];
    void walk(List<PdfOutlineNode> nodes, int level) {
      for (final PdfOutlineNode n in nodes) {
        if (n.dest != null) toc.add((n.title, n.dest!.pageNumber, level));
        walk(n.children, level + 1);
      }
    }

    walk(_outline, 0);
    final ReadingDocument? r = _reflow;
    if (toc.isEmpty && r != null) {
      for (final TocEntry t in r.toc) {
        final SourceRef? src = r.sections[t.section].blocks[t.block].source;
        if (src != null) toc.add((t.title, src.locate(0).$1, t.level));
      }
    }
    return toc;
  }

  Future<void> _contents() async {
    // Headings come from the reflow; prepare it if the PDF has no outline.
    if (_outline.isEmpty && _reflow == null) await _ensureReflow();
    if (!mounted) return;
    final List<(String, int, int)> toc = _toc;
    int current = -1;
    for (int i = 0; i < toc.length; i++) {
      if (toc[i].$2 <= _page) current = i;
    }
    await showReaderSheet<void>(context, heightFactor: 0.9, (BuildContext ctx) {
      void go(int page) {
        Navigator.of(ctx).pop();
        _goToPage(page);
      }

      MarkRow row(Annotation a) {
        final Locator l = Locator.fromJson(a.locator);
        return MarkRow(annotation: a, label: a.label, where: 'p. ${l.page ?? 1}', onTap: () => go(l.page ?? 1));
      }

      return ContentsSheet(
        title: doc.record.title ?? _stem(doc.ref.name),
        theme: _theme,
        toc: <TocRow>[
          for (int i = 0; i < toc.length; i++)
            TocRow(
              title: toc[i].$1,
              level: toc[i].$3,
              where: 'p. ${toc[i].$2}',
              current: i == current,
              onTap: () => go(toc[i].$2),
            ),
        ],
        bookmarks: <MarkRow>[
          for (final Annotation a in _annotations.where((Annotation a) => a.kind == 'bookmark')) row(a),
        ],
        highlights: <MarkRow>[
          for (final Annotation a in _annotations.where((Annotation a) => a.kind == 'highlight')) row(a),
        ],
      );
    });
  }

  Future<void> _thumbnails() async {
    final int? page = await Navigator.of(context).push<int>(
      PageRouteBuilder<int>(
        transitionDuration: Motion.of(context, Motion.containerTransform),
        reverseTransitionDuration: Motion.of(context, Motion.containerTransform),
        pageBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b) => _Thumbnails(
          renderer: _renderer!,
          pages: _pages,
          current: _page,
          bookmarked: <int>{
            for (final Annotation a in _annotations.where((Annotation a) => a.kind == 'bookmark'))
              Locator.fromJson(a.locator).page ?? 0,
          },
          look: _look(),
          aspect: (int p) => _pdf!.pages[p - 1].width / _pdf!.pages[p - 1].height,
        ),
        transitionsBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b, Widget child) =>
            FadeTransition(
              opacity: CurvedAnimation(parent: a, curve: Motion.decelerate),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(CurvedAnimation(parent: a, curve: Motion.spring)),
                child: child,
              ),
            ),
      ),
    );
    if (page != null) _jumpWithBack(page);
  }

  Future<void> _toggleCrop() async {
    final ReadingPrefsController ctl = ref.read(readingPrefsProvider.notifier);
    final bool on = !ref.read(readingPrefsProvider).pdfCrop;
    ctl.update((ReadingPrefs p) => p.copyWith(pdfCrop: on));
    if (on && mounted) {
      AppSnackbar.undo(context, 'Margins cropped', () => ctl.update((ReadingPrefs p) => p.copyWith(pdfCrop: false)));
    }
  }

  PageLook _look({int? page}) {
    final ReadingPrefs prefs = ref.read(readingPrefsProvider);
    final ReadingTheme t = _theme;
    final bool recolour = prefs.pdfRecolour && t.id != ReadingThemeId.light;
    return PageLook(
      paper: recolour ? t.paper.toARGB32() : null,
      ink: recolour ? t.ink.toARGB32() : null,
      crop: page != null && prefs.pdfCrop ? _crops[page] : null,
    );
  }

  Future<void> _bookInfo() async {
    final List<Annotation> hl = _annotations.where((Annotation a) => a.kind == 'highlight').toList();
    final int notes = hl.where((Annotation a) => a.note != null).length;
    final String title = doc.record.title ?? _stem(doc.ref.name);
    await showBookInfo(
      context,
      cover: CoverArt(
        title: title,
        author: doc.record.author,
        fingerprint: doc.fingerprint,
        format: doc.format,
        width: 64,
        height: 92,
      ),
      title: title,
      author: doc.record.author,
      facts: <(String, String)>[
        ('Location', doc.ref.name),
        ('Size', '${Files.size(doc.ref.size)} · PDF'),
        ('Pages', '$_pages'),
        ('Progress', '${((_page - 1) / math.max(1, _pages - 1) * 100).round()}% · Page $_page'),
        ('Highlights', '${hl.length}${notes > 0 ? ' · $notes ${notes == 1 ? 'note' : 'notes'}' : ''}'),
        ('Added', Files.when(doc.record.addedAt.millisecondsSinceEpoch)),
      ],
      highlights: hl.length,
      onExport: () async {
        final StringBuffer md = StringBuffer('# $title\n');
        for (final Annotation a in hl..sort((Annotation a, Annotation b) => a.progress.compareTo(b.progress))) {
          md.write('\n> ${a.quote}\n\n${a.label}\n');
          if (a.note != null) md.write('\n${a.note}\n');
        }
        await Platform.shareText(md.toString(), subject: 'Highlights from $title');
      },
    );
  }

  Future<void> _overflow(BuildContext anchor) async {
    final String? choice = await showAppMenu<String>(
      context: context,
      anchorContext: anchor,
      entries: const <AppMenuEntry<String>>[
        AppMenuEntry<String>(value: 'info', label: 'Book info', icon: AppIcons.info),
        kInsightsEntry,
        AppMenuEntry<String>(value: 'share', label: 'Share file', icon: AppIcons.share),
        AppMenuEntry<String>.divider(),
        AppMenuEntry<String>(value: 'other', label: 'Open in another app', icon: AppIcons.openInNew),
      ],
    );
    switch (choice) {
      case 'info':
        await _bookInfo();
      case 'insights':
        if (mounted) await showDocInsights(context, doc);
      case 'share':
        await Platform.shareFile(doc.ref.uri, doc.ref.mime);
      case 'other':
        await Platform.openWith(doc.ref.uri, doc.ref.mime);
    }
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    if (_failed) return corruptState(context, doc.ref);
    final UnfurlColors c = context.colors;
    final PdfDocument? pdf = _pdf;
    if (pdf == null) return OpeningCard(ref: doc.ref);
    final ReadingPrefs prefs = ref.watch(readingPrefsProvider);
    ref.watch(settingsProvider);
    if (prefs.pdfCrop) _ensureCrops();
    final Widget page = _pageView(c, prefs);
    final Widget? reader = !_reader && _reflow == null
        ? null
        : AnimatedSwitcher(
            duration: Motion.of(context, Motion.fast),
            child: KeyedSubtree(
              key: ValueKey<bool>(_reflow == null),
              child: _reflow == null
                  ? OpeningCard(
                      ref: doc.ref,
                      label: 'Preparing Reader mode',
                      immediate: true,
                      progress: _reflowProgress,
                      onClose: () => _toPage(_readerStart ?? Locator(page: _page)),
                    )
                  : _readerView(),
            ),
          );
    return UnfurlSwitcher(
      reader: _reader,
      anchorY: MediaQuery.paddingOf(context).top + 64,
      page: page,
      readerChild: reader,
    );
  }

  void _ensureCrops() {
    for (int p = math.max(1, _page - 2); p <= math.min(_pages, _page + 3); p++) {
      if (_crops.containsKey(p)) continue;
      _crops[p] = const Rect.fromLTRB(0, 0, 1, 1);
      unawaited(
        _renderer!.contentBox(p).then((Rect r) {
          if (mounted) setState(() => _crops[p] = r);
        }),
      );
    }
  }

  Widget _readerView() {
    final ReadingDocument r = _reflow!;
    final String title = doc.record.title ?? _stem(doc.ref.name);
    if (r.scanned) {
      return DocStateScaffoldWithToggle(
        title: title,
        onPage: () => _toPage(_readerStart ?? Locator(page: _page)),
        state: EmptyState(
          icon: AppIcons.documentScanner,
          tone: EmptyTone.neutral,
          small: true,
          title: 'Reader mode isn’t available for this file yet',
          message: 'Its pages are scanned images with no text to reflow. Page view shows them exactly as they are.',
          actions: <Widget>[
            AppButton(
              label: 'Back to Page view',
              icon: AppIcons.article,
              onPressed: () => _toPage(_readerStart ?? Locator(page: _page)),
            ),
          ],
        ),
      );
    }
    return ReaderScaffold(
      key: _readerKey,
      doc: doc,
      reading: r,
      start: _readerStart,
      onPageMode: _toPage,
      contents: _outline.isEmpty
          ? null
          : <(String, int, Locator)>[
              for (final (String t, int page, int level) in _toc) (t, level, Locator(page: page, pageStart: 0)),
            ],
      pageLabel: (SourceRef src) => 'p. ${src.page}',
      overlay: r.simplified && !_simplifiedSeen
          ? _Note(
              text: 'Some layout may be simplified',
              onClose: () {
                setState(() => _simplifiedSeen = true);
                unawaited(ref.read(prefsProvider).setBool('pdf.simplified.${doc.fingerprint}', true));
              },
            )
          : null,
    );
  }

  Widget _pageView(UnfurlColors c, ReadingPrefs prefs) {
    final Annotation? bookmark = _bookmarkHere;
    final bool selecting = _selection != null && _selectionRect != null;
    final String title = doc.record.title ?? _stem(doc.ref.name);
    return PopScope(
      // Back closes a selection or search first, then leaves the book.
      canPop: !selecting && !_searching,
      onPopInvokedWithResult: (bool did, Object? _) {
        if (did) return;
        if (selecting) return _clearSelection();
        if (_searching) {
          setState(() {
            _searching = false;
            _hits = const <(int, int)>[];
            _query = '';
          });
          return;
        }
      },
      child: Scaffold(
        backgroundColor: c.surfaceContainer,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: TrackedPages(
                fingerprint: doc.fingerprint,
                format: doc.format.id,
                page: _page - 1,
                child: _Pages(
                  key: _pagesKey,
                  pdf: _pdf!,
                  renderer: _renderer!,
                  initialPage: _page,
                  paged: prefs.pdfLayout == PdfLayout.paged,
                  topInset: MediaQuery.paddingOf(context).top + (_chrome ? 64 : 0) + Space.md,
                  lookFor: (int p) => _look(page: p),
                  paintFor: _paintFor,
                  pageAspect: (int p) {
                    final PdfPage pg = _pdf!.pages[p - 1];
                    final Rect crop = (prefs.pdfCrop ? _crops[p] : null) ?? const Rect.fromLTRB(0, 0, 1, 1);
                    return (pg.width * crop.width) / (pg.height * crop.height);
                  },
                  cropFor: (int p) => prefs.pdfCrop ? _crops[p] : null,
                  needText: (int p) => unawaited(_text(p)),
                  onPage: _onPageChanged,
                  onTap: (int page, Offset fraction, double x) async {
                    if (_selection != null) return _clearSelection();
                    for (final PdfLink l in await _linksOf(page)) {
                      final PdfPage pg = _pdf!.pages[page - 1];
                      for (final PdfRect r in l.rects) {
                        final Rect f = Rect.fromLTRB(
                          r.left / pg.width,
                          1 - r.top / pg.height,
                          r.right / pg.width,
                          1 - r.bottom / pg.height,
                        );
                        if (f.contains(fraction)) {
                          if (l.dest != null) {
                            return _jumpWithBack(l.dest!.pageNumber);
                          }
                          if (l.url != null) {
                            return Platform.openUrl(l.url.toString());
                          }
                        }
                      }
                    }
                    final PageText? t = _texts[page];
                    if (t != null) {
                      final int? i = t.indexAt(fraction);
                      if (i != null &&
                          _annotations.any((Annotation a) {
                            final Locator l = Locator.fromJson(a.locator);
                            return a.kind == 'highlight' &&
                                l.page == page &&
                                l.pageStart != null &&
                                i >= l.pageStart! &&
                                i < l.pageStart! + l.length;
                          })) {
                        return _tapHighlight(page, fraction);
                      }
                    }
                    if (prefs.pdfLayout == PdfLayout.paged && x < 0.25) {
                      return _goToPage(_page - 1, animate: true);
                    }
                    if (prefs.pdfLayout == PdfLayout.paged && x > 0.75) {
                      return _goToPage(_page + 1, animate: true);
                    }
                    _toggleChrome();
                  },
                  onLongPress: _onLongPress,
                  onDragSelect: _extendSelection,
                ),
              ),
            ),
            // The page chip in immersive.
            if (!_chrome && !_searching)
              Positioned(
                bottom: MediaQuery.paddingOf(context).bottom + 28,
                left: 0,
                right: 0,
                child: Center(
                  child: TimedChip(
                    key: ValueKey<int>(_page),
                    text: '$_page / $_pages',
                    duration: const Duration(milliseconds: 1500),
                  ),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _searching
                  ? _searchBar(c)
                  : ChromeSlide(
                      visible: _chrome,
                      child: ReaderTopBar(
                        title: title,
                        subtitle: 'p. $_page of $_pages',
                        onBack: () => Navigator.of(context).maybePop(),
                        toggle: ModeToggle(reader: false, onChanged: (bool r) => r ? _toReader() : null),
                        actions: <Widget>[
                          AppIconButton(
                            icon: AppIcons.search,
                            filled: false,
                            semanticLabel: 'Search in PDF',
                            onPressed: () => setState(() => _searching = true),
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
              child: _searching
                  ? _results(c)
                  : ChromeSlide(
                      visible: _chrome,
                      fromTop: false,
                      child: ReaderBottomBar(
                        children: <Widget>[
                          PageScrubber(
                            value: _pages <= 1 ? 0 : (_page - 1) / (_pages - 1),
                            tick: _lastPage == null ? null : (_lastPage! - 1) / math.max(1, _pages - 1),
                            startLabel: (double v) => '${(v * (_pages - 1)).round() + 1}',
                            endLabel: '$_pages',
                            label: (double v) {
                              final int p = (v * (_pages - 1)).round() + 1;
                              final String? section = _sectionTitle(p);
                              return section == null ? 'p. $p' : 'p. $p · $section';
                            },
                            preview: (double v) {
                              final int p = (v * (_pages - 1)).round() + 1;
                              return _Thumb(renderer: _renderer!, page: p, look: _look(), width: 96);
                            },
                            onDragging: (bool d) {
                              if (d) _lastPage = _page;
                              setState(() {});
                            },
                            onChanged: (double v) => _jumpWithBack((v * (_pages - 1)).round() + 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              AppIconButton(
                                icon: AppIcons.toc,
                                filled: false,
                                semanticLabel: 'Contents',
                                onPressed: _contents,
                              ),
                              AppIconButton(
                                icon: AppIcons.gridView,
                                filled: false,
                                semanticLabel: 'Pages',
                                onPressed: _thumbnails,
                              ),
                              AppIconButton(
                                icon: AppIcons.crop,
                                filled: false,
                                active: prefs.pdfCrop,
                                semanticLabel: prefs.pdfCrop ? 'Show margins' : 'Crop margins',
                                onPressed: _toggleCrop,
                              ),
                              AppIconButton(
                                icon: AppIcons.tune,
                                filled: false,
                                semanticLabel: 'Page settings',
                                onPressed: () => showReadingSettings(context, pdf: true),
                              ),
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
            if (_backChip != null)
              Positioned(
                bottom: MediaQuery.paddingOf(context).bottom + (_chrome ? 168 : 72),
                left: 0,
                right: 0,
                child: Center(
                  child: TimedChip(
                    key: ValueKey<String>(_backChip!),
                    text: _backChip!,
                    icon: AppIcons.back,
                    duration: const Duration(seconds: 4),
                    onTap: () {
                      final int? to = _backTo;
                      setState(() => _backChip = null);
                      if (to != null) _goToPage(to);
                    },
                  ),
                ),
              ),
            if (selecting) _toolbar(),
          ],
        ),
      ),
    );
  }

  String? _sectionTitle(int page) {
    String? best;
    void walk(List<PdfOutlineNode> nodes) {
      for (final PdfOutlineNode n in nodes) {
        if (n.dest != null && n.dest!.pageNumber <= page) best = n.title;
        walk(n.children);
      }
    }

    walk(_outline);
    if (best == null) return null;
    final RegExpMatch? m = RegExp(r'^CHAPTER ([IVXLC\d]+)', caseSensitive: false).firstMatch(best!);
    return m == null ? (best!.length > 18 ? '${best!.substring(0, 18)}…' : best) : 'Ch. ${m[1]}';
  }

  Widget _toolbar() {
    final Rect r = _selectionRect!;
    final double h = MediaQuery.sizeOf(context).height;
    final bool above = r.top > SelectionToolbar.clearance;
    final (int, int, int) s = _selection!;
    // Above: pinned by its bottom edge, whatever its height at this text size.
    return Positioned(
      left: 14,
      right: 14,
      top: above ? null : math.min(h - SelectionToolbar.clearance, r.bottom + 28),
      bottom: above ? h - r.top + 8 : null,
      child: Reveal(
        child: SelectionToolbar(
          theme: _theme,
          selectedColor: _highlightOver(s)?.color,
          onCopy: () {
            unawaited(copyText(_selectedText));
            _clearSelection();
            AppSnackbar.info(context, 'Copied');
          },
          onHighlight: (int i) => unawaited(_highlight(i)),
          onNote: () => unawaited(_note()),
          onReadAloud: null,
          onDefine: () {
            final String w = _selectedText;
            _clearSelection();
            unawaited(defineInMull(context, w));
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
            hint: 'Search in PDF',
            autofocus: true,
            height: 48,
            onChanged: (String q) => unawaited(_search(q)),
            trailing: _query.length < 2
                ? null
                : Text(
                    _hits.isEmpty
                        ? (_indexed < _pages ? '…' : 'No results')
                        : '${_hit + 1} of ${_hits.length}${_indexed < _pages ? '…' : ''}',
                    style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                  ),
          ),
        ),
        AppIconButton(
          icon: AppIcons.arrowUp,
          filled: false,
          semanticLabel: 'Previous result',
          onPressed: _hits.isEmpty ? null : () => _goToHit(_hit - 1),
        ),
        AppIconButton(
          icon: AppIcons.arrowDown,
          filled: false,
          semanticLabel: 'Next result',
          onPressed: _hits.isEmpty ? null : () => _goToHit(_hit + 1),
        ),
      ],
    ),
  );

  Widget _results(UnfurlColors c) {
    if (_hits.isEmpty) return const SizedBox.shrink();
    final int pages = _hits.map(((int, int) h) => h.$1).toSet().length;
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
                      '${_hits.length} ${_hits.length == 1 ? 'RESULT' : 'RESULTS'} · $pages ${pages == 1 ? 'PAGE' : 'PAGES'}',
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
            child: !_resultsOpen
                ? const SizedBox(width: double.infinity)
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _hits.length,
                      itemBuilder: (BuildContext context, int i) {
                        final (int p, int at) = _hits[i];
                        final String t = (_texts[p]?.text ?? '').replaceAll(RegExp(r'\s'), ' ');
                        final int a = math.max(0, at - 24), b = math.min(t.length, at + _query.length + 36);
                        final bool cur = i == _hit;
                        return Material(
                          color: cur ? c.primaryContainer : Colors.transparent,
                          child: InkWell(
                            onTap: () => _goToHit(i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Space.screen, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: Space.md,
                                children: <Widget>[
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      'p. $p',
                                      style: UnfurlType.monoLabel.copyWith(
                                        color: cur ? c.onPrimaryContainer : c.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: <TextSpan>[
                                          TextSpan(text: '…${t.substring(a, at)}'),
                                          TextSpan(
                                            text: t.substring(at, math.min(t.length, at + _query.length)),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontVariations: <FontVariation>[FontVariation('wght', 700)],
                                            ),
                                          ),
                                          TextSpan(text: '${t.substring(math.min(t.length, at + _query.length), b)}…'),
                                        ],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: UnfurlType.note.copyWith(
                                        height: 1.4,
                                        color: cur ? c.onPrimaryContainer : c.onSurface,
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

/// A blocking state with the reader's top bar and the mode toggle (the
/// scanned PDF, R5).
class DocStateScaffoldWithToggle extends StatelessWidget {
  const DocStateScaffoldWithToggle({required this.title, required this.onPage, required this.state, super.key});

  final String title;
  final VoidCallback onPage;
  final Widget state;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: <Widget>[
        ReaderTopBar(
          title: title,
          onBack: () => Navigator.of(context).maybePop(),
          toggle: ModeToggle(reader: true, onChanged: (bool r) => r ? null : onPage()),
        ),
        Expanded(child: state),
      ],
    ),
  );
}

/// "Some layout may be simplified": a quiet card with a close button.
class _Note extends StatelessWidget {
  const _Note({required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(Space.lg),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        spacing: 10,
        children: <Widget>[
          AppIcon(AppIcons.info, size: 20, color: c.icon),
          Expanded(
            child: Text(text, style: UnfurlType.note.copyWith(height: 1.4, color: c.onSurface)),
          ),
          AppIconButton(icon: AppIcons.close, filled: false, semanticLabel: 'Dismiss', onPressed: onClose),
        ],
      ),
    );
  }
}

/// A rendered page thumbnail.
class _Thumb extends StatefulWidget {
  const _Thumb({required this.renderer, required this.page, required this.look, required this.width});

  final PageRenderer renderer;
  final int page;
  final PageLook look;
  final double width;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  @override
  Widget build(BuildContext context) {
    final int px = (widget.width * MediaQuery.devicePixelRatioOf(context)).round();
    final ui.Image? img = widget.renderer.cached(widget.page, px, widget.look);
    if (img == null || img.width < px) {
      unawaited(
        widget.renderer.render(widget.page, px, widget.look).then((_) {
          if (mounted) setState(() {});
        }),
      );
    }
    return Container(
      color: widget.look.paper == null ? Colors.white : Color(widget.look.paper!),
      child: img == null ? null : RawImage(image: img, fit: BoxFit.contain),
    );
  }
}

/// Thumbnails (R3): "Pages", All or Bookmarked, a three-column grid with
/// the current page ringed.
class _Thumbnails extends StatefulWidget {
  const _Thumbnails({
    required this.renderer,
    required this.pages,
    required this.current,
    required this.bookmarked,
    required this.look,
    required this.aspect,
  });

  final PageRenderer renderer;
  final int pages;
  final int current;
  final Set<int> bookmarked;
  final PageLook look;
  final double Function(int page) aspect;

  @override
  State<_Thumbnails> createState() => _ThumbnailsState();
}

class _ThumbnailsState extends State<_Thumbnails> {
  bool _bookmarkedOnly = false;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final List<int> pages = <int>[
      for (int p = 1; p <= widget.pages; p++)
        if (!_bookmarkedOnly || widget.bookmarked.contains(p)) p,
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.screen, Space.sm),
              child: Row(
                spacing: Space.sm,
                children: <Widget>[
                  AppIconButton(
                    icon: AppIcons.close,
                    semanticLabel: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text('Pages', style: UnfurlType.headerTitle.copyWith(color: c.onSurface)),
                  ),
                  Text('${widget.pages}', style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, Space.xs, Space.screen, Space.lg),
              child: Row(
                spacing: Space.sm,
                children: <Widget>[
                  PillChip(
                    label: 'All',
                    selected: !_bookmarkedOnly,
                    onTap: () => setState(() => _bookmarkedOnly = false),
                  ),
                  PillChip(
                    label: 'Bookmarked',
                    selected: _bookmarkedOnly,
                    leading: const AppIcon(AppIcons.bookmark, size: 18),
                    onTap: () => setState(() => _bookmarkedOnly = true),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.bottomSafe),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: Space.lg,
                  crossAxisSpacing: 14,
                  childAspectRatio: widget.aspect(1) / (1 + 0.16 / widget.aspect(1) * 0.71),
                ),
                itemCount: pages.length,
                itemBuilder: (BuildContext context, int i) {
                  final int p = pages[i];
                  final bool cur = p == widget.current;
                  return Semantics(
                    button: true,
                    label: 'Page $p${cur ? ', current' : ''}',
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(p),
                      child: Column(
                        spacing: 6,
                        children: <Widget>[
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: widget.aspect(p),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: cur ? c.primary : c.outline, width: cur ? 3 : 1),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: <Widget>[
                                    _Thumb(renderer: widget.renderer, page: p, look: widget.look, width: 110),
                                    if (widget.bookmarked.contains(p))
                                      Positioned(
                                        top: -2,
                                        right: 4,
                                        child: AppIcon(AppIcons.bookmark, fill: true, size: 20, color: c.primary),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Text(
                            '$p',
                            style: UnfurlType.monoLabel
                                .copyWith(color: cur ? c.accent : c.onSurfaceVariant)
                                .copyWith(fontWeight: cur ? FontWeight.w700 : FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ pages

/// The page surface: continuous vertical (zoom 1x to 5x, panning, lazy
/// pages, sharp tiles when zoomed) or paged horizontal (one page per swipe,
/// neighbours peeking).
class _Pages extends StatefulWidget {
  const _Pages({
    required this.pdf,
    required this.renderer,
    required this.initialPage,
    required this.paged,
    required this.topInset,
    required this.lookFor,
    required this.paintFor,
    required this.pageAspect,
    required this.cropFor,
    required this.needText,
    required this.onPage,
    required this.onTap,
    required this.onLongPress,
    required this.onDragSelect,
    super.key,
  });

  final PdfDocument pdf;
  final PageRenderer renderer;
  final int initialPage;
  final bool paged;
  final double topInset;
  final PageLook Function(int page) lookFor;
  final List<(Rect, Color)> Function(int page) paintFor;
  final double Function(int page) pageAspect;
  final Rect? Function(int page) cropFor;
  final void Function(int page) needText;
  final void Function(int page, double offset) onPage;
  final void Function(int page, Offset fraction, double screenX) onTap;
  final void Function(int page, Offset fraction, Rect Function(Rect) toGlobal) onLongPress;
  final void Function(int page, Offset fraction, Rect Function(Rect) toGlobal) onDragSelect;

  @override
  State<_Pages> createState() => _PagesState();
}

class _PagesState extends State<_Pages> {
  final TransformationController _tx = TransformationController();
  late PageController _pager = PageController(initialPage: widget.initialPage - 1, viewportFraction: 0.92);
  int _page = 1;
  List<double> _tops = const <double>[];
  List<double> _heights = const <double>[];
  double _width = 0;
  double _total = 0;
  Timer? _sharpen;
  bool _restored = false;
  static const double _gap = 12, _side = 12;

  int get _count => widget.pdf.pages.length;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _tx.addListener(_onTransform);
    widget.renderer.ready.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(_Pages old) {
    super.didUpdateWidget(old);
    if (old.paged != widget.paged) {
      final int keep = _page;
      _pager.dispose();
      _pager = PageController(initialPage: keep - 1, viewportFraction: 0.92);
      _restored = false;
    }
  }

  @override
  void dispose() {
    _sharpen?.cancel();
    _tx.dispose();
    _pager.dispose();
    widget.renderer.ready.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  double get _scale => _tx.value.getMaxScaleOnAxis();

  void _layout(double width) {
    _width = width - _side * 2;
    double y = widget.topInset;
    final List<double> tops = <double>[], heights = <double>[];
    for (int p = 1; p <= _count; p++) {
      tops.add(y);
      final double h = _width / widget.pageAspect(p);
      heights.add(h);
      y += h + _gap;
    }
    _tops = tops;
    _heights = heights;
    _total = y + 200;
  }

  void _onTransform() {
    if (widget.paged || _tops.isEmpty) return;
    final double s = _scale;
    final double ty = -_tx.value.getTranslation().y / s;
    // The page under a line a third of the way down the view is the one
    // you're on.
    final double view = context.size?.height ?? 800;
    final double probe = ty + (widget.topInset + (view - widget.topInset) / 3) / s;
    int page = 1;
    for (int i = 0; i < _tops.length; i++) {
      if (_tops[i] <= probe) page = i + 1;
    }
    // The position saved is the line at the top, as the reader sees it.
    final double offset = ((ty + widget.topInset / s - _tops[page - 1]) / _heights[page - 1]).clamp(0, 1);
    if (page != _page) setState(() => _page = page);
    widget.onPage(page, offset);
    _sharpen?.cancel();
    _sharpen = Timer(const Duration(milliseconds: 160), _rebuild);
  }

  /// What the reader is looking at: the page and the fraction down it of a
  /// line a third of the way down the view (paged: the page's top).
  (int, double) focus() {
    if (widget.paged || _tops.isEmpty) return (_page, 0);
    final double s = _scale;
    final double view = context.size?.height ?? 800;
    final double y = -_tx.value.getTranslation().y / s + (widget.topInset + (view - widget.topInset) / 3) / s;
    int page = 1;
    for (int i = 0; i < _tops.length; i++) {
      if (_tops[i] <= y) page = i + 1;
    }
    return (page, ((y - _tops[page - 1]) / _heights[page - 1]).clamp(0.0, 1.0));
  }

  /// Scrolls (or turns) to page [page], [fraction] down it.
  void goTo(int page, {double fraction = 0, bool animate = false}) {
    if (widget.paged) {
      if (!_pager.hasClients) return;
      if (animate && !Motion.reduced(context)) {
        unawaited(_pager.animateToPage(page - 1, duration: Motion.pageTurn, curve: Motion.spring));
      } else {
        _pager.jumpToPage(page - 1);
      }
      return;
    }
    if (_tops.isEmpty) {
      _page = page;
      return;
    }
    final double s = _scale;
    final double y = (_tops[page - 1] + _heights[page - 1] * fraction - widget.topInset).clamp(
      0,
      math.max(0, _total - 100),
    );
    final Matrix4 target = Matrix4.identity()
      ..translateByDouble(_tx.value.getTranslation().x, -y * s, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
    _tx.value = target;
  }

  @override
  Widget build(BuildContext context) => widget.paged ? _pagedView() : _continuous();

  Widget _continuous() => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) {
      if (_width != box.maxWidth - _side * 2 || _tops.length != _count) {
        _layout(box.maxWidth);
      }
      if (!_restored) {
        _restored = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => goTo(_page));
      }
      return GestureDetector(
        onDoubleTapDown: (TapDownDetails d) {
          final double s = _scale;
          if (s > 1.05) {
            final double ty = _tx.value.getTranslation().y / s;
            _tx.value = Matrix4.identity()..translateByDouble(0, ty, 0, 1);
          } else {
            // Fit the column: zoom to the page's content width.
            final Rect crop = widget.cropFor(_page) ?? const Rect.fromLTRB(0.08, 0, 0.92, 1);
            final double z = (1 / crop.width).clamp(1.0, 5.0);
            final Offset f = d.localPosition;
            _tx.value = Matrix4.identity()
              ..translateByDouble(f.dx, f.dy, 0, 1)
              ..scaleByDouble(z, z, 1, 1)
              ..translateByDouble(-f.dx, -f.dy, 0, 1)
              ..multiply(_tx.value);
          }
        },
        child: InteractiveViewer.builder(
          transformationController: _tx,
          minScale: 1,
          maxScale: 5,
          boundaryMargin: EdgeInsets.zero,
          interactionEndFrictionCoefficient: 0.00006,
          builder: (BuildContext context, Quad viewport) {
            final Rect view = Rect.fromPoints(
              Offset(viewport.point0.x, viewport.point0.y),
              Offset(viewport.point2.x, viewport.point2.y),
            );
            final Rect buffer = view.inflate(view.height);
            final Set<int> visible = <int>{};
            final List<Widget> children = <Widget>[];
            for (int i = 0; i < _count; i++) {
              final Rect r = Rect.fromLTWH(_side, _tops[i], _width, _heights[i]);
              if (!r.overlaps(buffer)) continue;
              visible.add(i + 1);
              children.add(
                Positioned.fromRect(
                  rect: r,
                  child: _tile(i + 1, r.size, view.overlaps(r) ? view.intersect(r).shift(-r.topLeft) : null),
                ),
              );
            }
            widget.renderer.cancelExcept(visible);
            return SizedBox(
              width: box.maxWidth,
              height: _total,
              child: Stack(children: children),
            );
          },
        ),
      );
    },
  );

  Widget _tile(int page, Size size, Rect? visibleRegion) {
    widget.needText(page);
    return _PageTile(
      key: ValueKey<int>(page),
      page: page,
      renderer: widget.renderer,
      look: widget.lookFor(page),
      size: size,
      zoom: _scale,
      visibleRegion: _scale > 1.4 ? visibleRegion : null,
      marks: widget.paintFor(page),
      onTap: (Offset f, double x) => widget.onTap(page, f, x),
      onLongPress: (Offset f, Rect Function(Rect) g) => widget.onLongPress(page, f, g),
      onDrag: (Offset f, Rect Function(Rect) g) => widget.onDragSelect(page, f, g),
    );
  }

  Widget _pagedView() => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) => PageView.builder(
      controller: _pager,
      itemCount: _count,
      onPageChanged: (int i) {
        setState(() => _page = i + 1);
        widget.onPage(i + 1, 0);
      },
      itemBuilder: (BuildContext context, int i) {
        final int page = i + 1;
        final double aspect = widget.pageAspect(page);
        final double maxW = box.maxWidth * 0.92 - 8, maxH = box.maxHeight - widget.topInset - 120;
        final double w = math.min(maxW, maxH * aspect);
        widget.needText(page);
        return Padding(
          padding: EdgeInsets.only(top: widget.topInset, bottom: 120, left: 4, right: 4),
          child: Center(
            child: SizedBox(
              width: w,
              height: w / aspect,
              child: _PageTile(
                key: ValueKey<int>(page),
                page: page,
                renderer: widget.renderer,
                look: widget.lookFor(page),
                size: Size(w, w / aspect),
                zoom: 1,
                marks: widget.paintFor(page),
                onTap: (Offset f, double x) => widget.onTap(page, f, x),
                onLongPress: (Offset f, Rect Function(Rect) g) => widget.onLongPress(page, f, g),
                onDrag: (Offset f, Rect Function(Rect) g) => widget.onDragSelect(page, f, g),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// One page: the best image to hand (a sharper one is requested for the
/// current zoom), a crisp tile over the visible region when zoomed, the
/// marks, and a 1px outline. No shadow.
class _PageTile extends StatefulWidget {
  const _PageTile({
    required this.page,
    required this.renderer,
    required this.look,
    required this.size,
    required this.zoom,
    required this.marks,
    required this.onTap,
    required this.onLongPress,
    required this.onDrag,
    this.visibleRegion,
    super.key,
  });

  final int page;
  final PageRenderer renderer;
  final PageLook look;
  final Size size;
  final double zoom;
  final Rect? visibleRegion;
  final List<(Rect, Color)> marks;
  final void Function(Offset fraction, double screenX) onTap;
  final void Function(Offset fraction, Rect Function(Rect) toGlobal) onLongPress;
  final void Function(Offset fraction, Rect Function(Rect) toGlobal) onDrag;

  @override
  State<_PageTile> createState() => _PageTileState();
}

class _PageTileState extends State<_PageTile> {
  ui.Image? _tile;
  Rect? _tileRegion;

  int _targetWidth(BuildContext context) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final double z = math.pow(1.5, (math.log(math.max(1, widget.zoom)) / math.log(1.5)).ceil()).toDouble();
    return math.min(2600, (widget.size.width * dpr * math.min(z, 2.0)).round());
  }

  Offset _fraction(Offset local) => Offset(local.dx / widget.size.width, local.dy / widget.size.height);

  Rect Function(Rect) _toGlobal() {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    return (Rect f) {
      final Rect local = Rect.fromLTRB(
        f.left * widget.size.width,
        f.top * widget.size.height,
        f.right * widget.size.width,
        f.bottom * widget.size.height,
      );
      return Rect.fromPoints(box.localToGlobal(local.topLeft), box.localToGlobal(local.bottomRight));
    };
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final int w = _targetWidth(context);
    final ui.Image? img = widget.renderer.cached(widget.page, w, widget.look);
    if (img == null || img.width < w) {
      unawaited(widget.renderer.render(widget.page, w, widget.look));
    }
    final Rect? region = widget.visibleRegion;
    if (region != null && region != _tileRegion) {
      // A sharp render of just what is on screen at this zoom.
      _tileRegion = region;
      final Rect crop = widget.look.crop ?? const Rect.fromLTRB(0, 0, 1, 1);
      final Rect frac = Rect.fromLTRB(
        region.left / widget.size.width,
        region.top / widget.size.height,
        region.right / widget.size.width,
        region.bottom / widget.size.height,
      );
      final Rect sub = Rect.fromLTRB(
        crop.left + frac.left * crop.width,
        crop.top + frac.top * crop.height,
        crop.left + frac.right * crop.width,
        crop.top + frac.bottom * crop.height,
      );
      final int px = math.min(2400, (region.width * widget.zoom * MediaQuery.devicePixelRatioOf(context)).round());
      unawaited(
        widget.renderer
            .render(widget.page, px, PageLook(paper: widget.look.paper, ink: widget.look.ink, crop: sub))
            .then((ui.Image? t) {
              if (mounted && _tileRegion == region) setState(() => _tile = t);
            }),
      );
    }
    final Color paper = widget.look.paper == null ? Colors.white : Color(widget.look.paper!);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (TapUpDetails d) =>
          widget.onTap(_fraction(d.localPosition), d.globalPosition.dx / MediaQuery.sizeOf(context).width),
      onLongPressStart: (LongPressStartDetails d) => widget.onLongPress(_fraction(d.localPosition), _toGlobal()),
      onLongPressMoveUpdate: (LongPressMoveUpdateDetails d) => widget.onDrag(_fraction(d.localPosition), _toGlobal()),
      child: Container(
        decoration: BoxDecoration(
          color: paper,
          border: Border.all(color: c.outline, width: 0.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // The page fades in once drawn; until then a hairline says so.
            AnimatedOpacity(
              opacity: img == null ? 0 : 1,
              duration: Motion.of(context, Motion.fast),
              curve: Motion.decelerate,
              child: img == null
                  ? const SizedBox.expand()
                  : RawImage(image: img, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: LoadingHairline(visible: img == null),
            ),
            if (region != null && _tile != null && _tileRegion == region)
              Positioned.fromRect(
                rect: region,
                child: RawImage(image: _tile, fit: BoxFit.fill),
              ),
            if (widget.marks.isNotEmpty) CustomPaint(painter: _MarksPainter(widget.marks, widget.look.crop)),
          ],
        ),
      ),
    );
  }
}

class _MarksPainter extends CustomPainter {
  _MarksPainter(this.marks, this.crop);

  final List<(Rect, Color)> marks;
  final Rect? crop;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect c = crop ?? const Rect.fromLTRB(0, 0, 1, 1);
    for (final (Rect r, Color colour) in marks) {
      final Rect onPage = Rect.fromLTRB(
        (r.left - c.left) / c.width * size.width,
        (r.top - c.top) / c.height * size.height,
        (r.right - c.left) / c.width * size.width,
        (r.bottom - c.top) / c.height * size.height,
      );
      canvas.drawRect(
        onPage.inflate(1),
        Paint()
          ..color = colour
          ..blendMode = BlendMode.multiply,
      );
    }
  }

  @override
  bool shouldRepaint(_MarksPainter old) => old.marks != marks || old.crop != crop;
}
