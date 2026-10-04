import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files.dart';
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
import '../../design_system/search_field.dart';
import '../../formats/format_registry.dart';
import '../../formats/office/docx.dart';
import '../../formats/office/pptx.dart';
import '../../formats/reading_document.dart';
import '../reader/chrome.dart';
import '../reader/reader_scaffold.dart';
import '../reader/reading_prefs.dart';
import '../reader/sheets.dart';
import '../reader/unfurl_transition.dart';
import '../settings/settings_controller.dart';
import '../viewer/document_screen.dart';

/// The overflow every Office viewer shares (board 4, V1): copy, share, file
/// info, and "Open in another app" with "Rendered approximately" under it.
Future<void> officeOverflow(
  BuildContext context,
  BuildContext anchor,
  OpenedDoc doc, {
  required String text,
  required List<(String, String)> facts,
}) async {
  final String? choice = await showAppMenu<String>(
    context: context,
    anchorContext: anchor,
    entries: const <AppMenuEntry<String>>[
      AppMenuEntry<String>(value: 'copy', label: 'Copy all text', icon: AppIcons.copy),
      AppMenuEntry<String>(value: 'share', label: 'Share file', icon: AppIcons.share),
      AppMenuEntry<String>(value: 'info', label: 'File info', icon: AppIcons.info),
      AppMenuEntry<String>.divider(),
      AppMenuEntry<String>(
        value: 'other',
        label: 'Open in another app',
        icon: AppIcons.openInNew,
        subtitle: 'Rendered approximately',
      ),
    ],
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'copy':
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) AppSnackbar.info(context, 'Copied all text');
    case 'share':
      await Platform.shareFile(doc.ref.uri, doc.ref.mime);
    case 'info':
      await showBookInfo(
        context,
        cover: const SizedBox.shrink(),
        title: doc.ref.name,
        author: null,
        facts: facts,
        highlights: 0,
        onExport: null,
      );
    case 'other':
      await Platform.openWith(doc.ref.uri, doc.ref.mime);
  }
}

// ------------------------------------------------------------ DOCX

/// DOCX (V1): Page view by default, the document's own sizes and alignment
/// on paper-sized pages; Reader mode reflows it into the reader, where it
/// gains highlights, notes and read aloud.
class DocxScreen extends ConsumerStatefulWidget {
  const DocxScreen({required this.doc, super.key});

  final OpenedDoc doc;

  @override
  ConsumerState<DocxScreen> createState() => _DocxScreenState();
}

class _DocxScreenState extends ConsumerState<DocxScreen> {
  Docx? _docx;
  ReadingDocument? _reading;
  bool _failed = false;
  bool _reader = false;
  bool _chrome = true;
  Locator? _readerStart;
  List<List<int>> _pages = const <List<int>>[];
  double _laidWidth = 0;
  ReadingThemeId? _laidTheme;
  final ScrollController _scroll = ScrollController();
  int _page = 0;
  bool _searching = false;
  List<int> _hits = const <int>[];
  int _hit = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reader = (widget.doc.mode ?? widget.doc.record.mode) == 'reader';
    _readerStart = widget.doc.resume;
    _scroll.addListener(_onScroll);
    unawaited(_load());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final Uint8List? bytes = await Files.readAll(widget.doc.ref.uri);
      if (bytes == null) throw const FormatException();
      final Docx d = await _parseDocx(bytes);
      final String name = widget.doc.ref.name;
      final ReadingDocument r = d.toReading(name);
      if (mounted) {
        setState(() {
          _docx = d;
          _reading = r;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onScroll() {
    if (_pages.isEmpty || !_scroll.hasClients) return;
    final double pageH = _pageHeight + 16;
    final int p = (_scroll.offset / pageH).floor().clamp(0, _pages.length - 1);
    if (p != _page) {
      setState(() => _page = p);
      unawaited(
        ref
            .read(libraryProvider)
            .savePosition(
              widget.doc.fingerprint,
              locator: Locator(
                page: (_pages[p].firstOrNull ?? 0) + 1,
                progress: p / math.max(1, _pages.length),
              ).toJson(),
              progress: _pages.length <= 1 ? 1 : p / (_pages.length - 1),
              where: 'Page ${p + 1} of ${_pages.length}',
              mode: 'page',
            ),
      );
    }
  }

  double _scale = 1;
  double get _pageHeight => (_docx?.pageHeight ?? 842) * _scale;

  /// Lays the body out on pages: whole paragraphs, measured at the page's
  /// text width in the document's own sizes.
  void _paginate(double width, ReadingTheme theme) {
    final Docx d = _docx!;
    _scale = width / d.pageWidth;
    final double textW = (d.pageWidth - d.margin * 2) * _scale;
    final double textH = (d.pageHeight - d.margin * 2) * _scale;
    final List<List<int>> pages = <List<int>>[<int>[]];
    double y = 0;
    for (int i = 0; i < d.items.length; i++) {
      final DocxItem it = d.items[i];
      final double h = _measure(it, textW, theme) + (it.spaceBefore + it.spaceAfter) * _scale;
      if ((y + h > textH || it.pageBreakBefore) && pages.last.isNotEmpty) {
        pages.add(<int>[]);
        y = 0;
      }
      pages.last.add(i);
      y += h;
    }
    _pages = pages;
    _laidWidth = width;
    _laidTheme = theme.id;
  }

  /// Heights as `_DocxPage` draws them: the page is the document's own
  /// layout, so neither side applies the system font scale.
  double _measure(DocxItem it, double width, ReadingTheme theme) {
    if (it.rows != null) return _tableHeight(it.rows!, width - it.indent * _scale, theme);
    if (it.image != null) return 160 * _scale;
    final TextPainter tp = TextPainter(text: _span(it, theme), textDirection: TextDirection.ltr)
      ..layout(maxWidth: math.max(1, width - it.indent * _scale));
    final double h = tp.height;
    tp.dispose();
    return h;
  }

  double _tableHeight(List<List<String>> rows, double width, ReadingTheme theme) {
    final int cols = rows.fold<int>(1, (int m, List<String> r) => math.max(m, r.length));
    final double cellW = math.max(1, width / cols - 4 * _scale);
    double h = 2; // the top and bottom rules
    for (int r = 0; r < rows.length; r++) {
      double row = 0;
      for (final String cell in rows[r]) {
        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: cell,
            style: _DocxPage.cellStyle(_scale, theme, header: r == 0),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: cellW);
        row = math.max(row, tp.height);
        tp.dispose();
      }
      h += row + 6 * _scale + (r > 0 ? 1 : 0);
    }
    return h;
  }

  InlineSpan _span(DocxItem it, ReadingTheme theme) {
    final double base =
        (it.heading == 1 && it.size <= 12 ? 20 : (it.heading == 2 && it.size <= 12 ? 15 : it.size)) * _scale;
    final String? bullet = it.listLevel == null ? null : (it.ordinal != null ? '${it.ordinal}.  ' : '•  ');
    return TextSpan(
      style: TextStyle(
        fontFamily: UnfurlType.sans,
        fontSize: base,
        height: 1.5,
        color: theme.ink,
        fontWeight: it.heading > 0 ? FontWeight.w600 : FontWeight.w400,
        fontVariations: <FontVariation>[FontVariation('wght', it.heading > 0 ? 600 : 400)],
      ),
      children: <InlineSpan>[
        if (bullet != null) TextSpan(text: bullet),
        for (final DocxRun r in it.runs)
          TextSpan(
            text: r.text,
            style: TextStyle(
              fontSize: r.size == null ? null : r.size! * _scale,
              fontWeight: r.bold ? FontWeight.w700 : null,
              fontVariations: r.bold ? const <FontVariation>[FontVariation('wght', 700)] : null,
              fontStyle: r.italic ? FontStyle.italic : null,
              decoration: r.underline || r.href != null ? TextDecoration.underline : null,
              color: r.href != null ? theme.accentText : null,
            ),
          ),
      ],
    );
  }

  void _toReader() {
    final int item = _pages.isEmpty ? 0 : (_pages[_page].firstOrNull ?? 0);
    setState(() {
      _readerStart = Locator(page: item + 1, pageStart: 0);
      _reader = true;
    });
  }

  void _toPage(Locator at) {
    setState(() {
      _reader = false;
      _readerStart = at;
    });
    final int item = (at.page ?? 1) - 1;
    final int p = math.max(0, _pages.indexWhere((List<int> ids) => ids.contains(item)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(p * (_pageHeight + 16));
    });
  }

  void _search(String q) {
    final String n = q.trim().toLowerCase();
    final List<int> hits = <int>[
      if (n.length >= 2)
        for (int i = 0; i < _docx!.items.length; i++)
          if (_docx!.items[i].text.toLowerCase().contains(n)) i,
    ];
    setState(() {
      _query = n;
      _hits = hits;
      _hit = 0;
    });
    if (hits.isNotEmpty) _goToItem(hits.first);
  }

  void _goToItem(int item) {
    final int p = math.max(0, _pages.indexWhere((List<int> ids) => ids.contains(item)));
    unawaited(
      _scroll.animateTo(
        p * (_pageHeight + 16),
        duration: Motion.of(context, Motion.pageTurn),
        curve: Motion.decelerate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return corruptState(context, widget.doc.ref);
    final UnfurlColors c = context.colors;
    final Docx? d = _docx;
    if (d == null) return OpeningCard(ref: widget.doc.ref);
    final ReadingTheme theme = readingThemeOf(context, ref.watch(readingPrefsProvider), ref.watch(settingsProvider));
    return UnfurlSwitcher(
      reader: _reader,
      anchorY: MediaQuery.paddingOf(context).top + 64,
      page: TrackedPages(
        fingerprint: widget.doc.fingerprint,
        format: widget.doc.format.id,
        page: _page,
        child: _pageView(c, d, theme),
      ),
      readerChild: _reading == null
          ? null
          : ReaderScaffold(
              doc: widget.doc,
              reading: _reading!,
              start: _readerStart,
              onPageMode: _toPage,
              approximate: true,
              pageLabel: (SourceRef s) => null,
            ),
    );
  }

  Widget _pageView(UnfurlColors c, Docx d, ReadingTheme theme) => PopScope(
    canPop: !_searching,
    onPopInvokedWithResult: (bool did, Object? _) {
      if (!did) setState(() => _searching = false);
    },
    child: Scaffold(
      backgroundColor: c.surfaceContainer,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double w = box.maxWidth - 24;
          if (_laidWidth != w || _laidTheme != theme.id) _paginate(w, theme);
          final double top = MediaQuery.paddingOf(context).top + 64 + Space.lg;
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _chrome = !_chrome),
                  child: ListView.builder(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(12, top, 12, Space.bottomSafe),
                    itemCount: _pages.length,
                    itemExtent: _pageHeight + 16,
                    itemBuilder: (BuildContext context, int p) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _DocxPage(
                        docx: d,
                        items: _pages[p],
                        number: p + 1,
                        scale: _scale,
                        theme: theme,
                        span: (DocxItem it) => _span(it, theme),
                        hits: _hits.toSet(),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _searching
                    ? Container(
                        color: c.surface,
                        padding: EdgeInsets.fromLTRB(
                          Space.md,
                          MediaQuery.paddingOf(context).top + Space.xs,
                          Space.sm,
                          10,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: SearchField(
                                hint: 'Search in document',
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
                              onPressed: _hits.isEmpty
                                  ? null
                                  : () {
                                      setState(() => _hit = (_hit - 1) % _hits.length);
                                      _goToItem(_hits[_hit]);
                                    },
                            ),
                            AppIconButton(
                              icon: AppIcons.arrowDown,
                              filled: false,
                              semanticLabel: 'Next result',
                              onPressed: _hits.isEmpty
                                  ? null
                                  : () {
                                      setState(() => _hit = (_hit + 1) % _hits.length);
                                      _goToItem(_hits[_hit]);
                                    },
                            ),
                            AppIconButton(
                              icon: AppIcons.close,
                              filled: false,
                              semanticLabel: 'Close search',
                              onPressed: () => setState(() {
                                _searching = false;
                                _hits = const <int>[];
                                _query = '';
                              }),
                            ),
                          ],
                        ),
                      )
                    : ChromeSlide(
                        visible: _chrome,
                        child: ReaderTopBar(
                          title: widget.doc.ref.name,
                          subtitle: 'p. ${_page + 1} of ${_pages.length}',
                          onBack: () => Navigator.of(context).maybePop(),
                          toggle: ModeToggle(reader: false, onChanged: (bool r) => r ? _toReader() : null),
                          actions: <Widget>[
                            AppIconButton(
                              icon: AppIcons.search,
                              filled: false,
                              semanticLabel: 'Search in document',
                              onPressed: () => setState(() => _searching = true),
                            ),
                            Builder(
                              builder: (BuildContext b) => AppIconButton(
                                icon: AppIcons.moreVert,
                                filled: false,
                                semanticLabel: 'More options',
                                onPressed: () => officeOverflow(
                                  context,
                                  b,
                                  widget.doc,
                                  text: d.items.map((DocxItem i) => i.text).join('\n'),
                                  facts: <(String, String)>[
                                    ('Name', widget.doc.ref.name),
                                    ('Size', '${Files.size(widget.doc.ref.size)} · DOCX'),
                                    ('Pages', '${_pages.length}'),
                                    if (d.author != null) ('Author', d.author!),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _DocxPage extends StatelessWidget {
  const _DocxPage({
    required this.docx,
    required this.items,
    required this.number,
    required this.scale,
    required this.theme,
    required this.span,
    required this.hits,
  });

  final Docx docx;
  final List<int> items;
  final int number;
  final double scale;
  final ReadingTheme theme;
  final InlineSpan Function(DocxItem) span;
  final Set<int> hits;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final double m = docx.margin * scale;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.paper,
        border: Border.all(color: c.outline, width: 0.5),
      ),
      // The page is the document's own layout, at its own sizes.
      child: Padding(
        padding: EdgeInsets.fromLTRB(m, m, m, m * 0.5),
        // Nothing inherited (the theme's tracking, height or features): the
        // page draws exactly what `_measure` measured.
        child: DefaultTextStyle(
          style: const TextStyle(),
          child: MediaQuery.withNoTextScaling(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  // ponytail: a single paragraph taller than a page is clipped at
                  // the page foot; split items across pages if real files need it.
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      maxHeight: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[for (final int i in items) _item(docx.items[i], hits.contains(i))],
                      ),
                    ),
                  ),
                ),
                Text(
                  '$number',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: UnfurlType.sans, fontSize: 7.5 * scale * 1.3, color: theme.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static TextStyle cellStyle(double scale, ReadingTheme theme, {required bool header}) => TextStyle(
    fontFamily: UnfurlType.sans,
    fontSize: 7.5 * scale * 1.2,
    height: 1.3,
    color: theme.ink,
    fontWeight: header ? FontWeight.w600 : null,
  );

  Widget _item(DocxItem it, bool hit) {
    final EdgeInsets pad = EdgeInsets.only(
      top: it.spaceBefore * scale,
      bottom: it.spaceAfter * scale,
      left: it.indent * scale,
    );
    if (it.image != null && docx.images[it.image] != null) {
      return Padding(
        padding: pad,
        child: SizedBox(
          height: 160 * scale,
          child: Image.memory(docx.images[it.image]!, fit: BoxFit.contain, cacheWidth: 600),
        ),
      );
    }
    if (it.rows != null) {
      return Padding(
        padding: pad,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.ink),
              bottom: BorderSide(color: theme.ink),
            ),
          ),
          child: Table(
            border: TableBorder(horizontalInside: BorderSide(color: theme.rule)),
            children: <TableRow>[
              for (int r = 0; r < it.rows!.length; r++)
                TableRow(
                  children: <Widget>[
                    for (final String cell in it.rows![r])
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 3 * scale, horizontal: 2 * scale),
                        child: Text(cell, style: cellStyle(scale, theme, header: r == 0)),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    }
    final TextAlign align = switch (it.align) {
      DocxAlign.center => TextAlign.center,
      DocxAlign.end => TextAlign.end,
      DocxAlign.justify => TextAlign.justify,
      DocxAlign.start => TextAlign.start,
    };
    return Padding(
      padding: pad,
      child: DecoratedBox(
        decoration: BoxDecoration(color: hit ? theme.handle.withValues(alpha: 0.18) : null),
        child: Text.rich(span(it), textAlign: align),
      ),
    );
  }
}

// ------------------------------------------------------------ PPTX

/// PPTX (V2): slides, landscape-first with a filmstrip, portrait stacked
/// with speaker notes; Reader mode is the outline.
class PptxScreen extends ConsumerStatefulWidget {
  const PptxScreen({required this.doc, super.key});

  final OpenedDoc doc;

  @override
  ConsumerState<PptxScreen> createState() => _PptxScreenState();
}

class _PptxScreenState extends ConsumerState<PptxScreen> {
  Pptx? _deck;
  ReadingDocument? _outline;
  bool _failed = false;
  bool _reader = false;
  bool _chrome = true;
  int _slide = 0;
  Locator? _readerStart;
  final PageController _pages = PageController();
  final ScrollController _list = ScrollController();

  @override
  void initState() {
    super.initState();
    _reader = (widget.doc.mode ?? widget.doc.record.mode) == 'reader';
    _readerStart = widget.doc.resume;
    _slide = ((widget.doc.resume?.page ?? 1) - 1).clamp(0, 9999);
    unawaited(_load());
  }

  @override
  void dispose() {
    _pages.dispose();
    _list.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final Uint8List? bytes = await Files.readAll(widget.doc.ref.uri);
      if (bytes == null) throw const FormatException();
      final Pptx p = await _parsePptx(bytes);
      if (mounted) {
        setState(() {
          _deck = p;
          if (Formats.pptx.hasModeToggle) _outline = p.toReading(widget.doc.ref.name);
          _slide = _slide.clamp(0, math.max(0, p.slides.length - 1));
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _goTo(_slide, animate: false));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _goTo(int i, {bool animate = true}) {
    final Pptx? d = _deck;
    if (d == null) return;
    final int s = i.clamp(0, d.slides.length - 1);
    setState(() => _slide = s);
    if (_pages.hasClients) {
      animate
          ? unawaited(_pages.animateToPage(s, duration: Motion.of(context, Motion.pageTurn), curve: Motion.spring))
          : _pages.jumpToPage(s);
    }
    unawaited(
      ref
          .read(libraryProvider)
          .savePosition(
            widget.doc.fingerprint,
            locator: Locator(page: s + 1, progress: s / math.max(1, d.slides.length)).toJson(),
            progress: d.slides.length <= 1 ? 1 : s / (d.slides.length - 1),
            where: 'Slide ${s + 1} of ${d.slides.length}',
            mode: 'page',
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return corruptState(context, widget.doc.ref);
    final UnfurlColors c = context.colors;
    final Pptx? d = _deck;
    if (d == null) return OpeningCard(ref: widget.doc.ref);
    return UnfurlSwitcher(
      reader: _reader,
      anchorY: MediaQuery.paddingOf(context).top + 64,
      page: TrackedPages(
        fingerprint: widget.doc.fingerprint,
        format: widget.doc.format.id,
        page: _slide,
        child: _slides(c, d),
      ),
      readerChild: _outline == null
          ? null
          : ReaderScaffold(
              doc: widget.doc,
              reading: _outline!,
              start: _readerStart ?? Locator(page: _slide + 1),
              pageIcon: AppIcons.slideshow,
              approximate: true,
              pageLabel: (SourceRef s) => 'Slide ${s.page}',
              onPageMode: (Locator at) {
                setState(() => _reader = false);
                WidgetsBinding.instance.addPostFrameCallback((_) => _goTo((at.page ?? 1) - 1, animate: false));
              },
            ),
    );
  }

  Widget _slides(UnfurlColors c, Pptx d) {
    final bool landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final String all = d.slides
        .expand((Slide s) => s.shapes)
        .expand((SlideShape s) => s.paragraphs)
        .map((SlideParagraph p) => p.text)
        .join('\n');
    final Widget bar = ReaderTopBar(
      title: widget.doc.ref.name,
      subtitle: landscape ? null : 'slide ${_slide + 1} of ${d.slides.length}',
      onBack: () => Navigator.of(context).maybePop(),
      // Slides only unless the registry gives PPTX a Reader mode again.
      toggle: Formats.pptx.hasModeToggle
          ? ModeToggle(
              reader: false,
              pageIcon: AppIcons.slideshow,
              onChanged: (bool r) {
                if (r) {
                  setState(() {
                    _readerStart = Locator(page: _slide + 1);
                    _reader = true;
                  });
                }
              },
            )
          : null,
      actions: <Widget>[
        if (landscape)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: Text(
                '${_slide + 1} / ${d.slides.length}',
                style: UnfurlType.monoLabel.copyWith(fontSize: 12, color: c.onSurfaceVariant),
              ),
            ),
          ),
        Builder(
          builder: (BuildContext b) => AppIconButton(
            icon: AppIcons.moreVert,
            filled: false,
            semanticLabel: 'More options',
            onPressed: () => officeOverflow(
              context,
              b,
              widget.doc,
              text: all,
              facts: <(String, String)>[
                ('Name', widget.doc.ref.name),
                ('Size', '${Files.size(widget.doc.ref.size)} · PPTX'),
                ('Slides', '${d.slides.length}'),
              ],
            ),
          ),
        ),
      ],
    );
    if (!landscape) {
      return Scaffold(
        backgroundColor: c.surfaceContainer,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification n) {
                  final double item = (MediaQuery.sizeOf(context).width - 24) / d.aspect + 60;
                  final int s = (n.metrics.pixels / item).round().clamp(0, d.slides.length - 1);
                  if (s != _slide) setState(() => _slide = s);
                  return false;
                },
                child: ListView.builder(
                  controller: _list,
                  padding: EdgeInsets.fromLTRB(
                    12,
                    MediaQuery.paddingOf(context).top + 64 + Space.lg,
                    12,
                    Space.bottomSafe,
                  ),
                  itemCount: d.slides.length,
                  itemBuilder: (BuildContext context, int i) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: Space.sm,
                      children: <Widget>[
                        SlideView(deck: d, slide: d.slides[i]),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 10,
                            children: <Widget>[
                              Text('${i + 1}', style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                              Expanded(
                                child: Text(
                                  d.slides[i].notes,
                                  style: UnfurlType.bodySmall.copyWith(color: c.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(top: 0, left: 0, right: 0, child: bar),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: c.surfaceContainer,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _chrome = !_chrome),
              child: PageView.builder(
                controller: _pages,
                itemCount: d.slides.length,
                onPageChanged: (int i) => _goTo(i, animate: false),
                itemBuilder: (BuildContext context, int i) => Padding(
                  padding: const EdgeInsets.fromLTRB(Space.xxl, 60, Space.xxl, 64),
                  child: Center(
                    child: SlideView(deck: d, slide: d.slides[i]),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ChromeSlide(visible: _chrome, child: bar),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ChromeSlide(
              visible: _chrome,
              fromTop: false,
              child: Container(
                height: 56 + MediaQuery.paddingOf(context).bottom,
                padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.outline)),
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.screen, vertical: 10),
                  itemCount: d.slides.length,
                  separatorBuilder: (BuildContext context, int i) => const SizedBox(width: Space.sm),
                  itemBuilder: (BuildContext context, int i) => GestureDetector(
                    onTap: () => _goTo(i),
                    child: Container(
                      width: 64,
                      decoration: BoxDecoration(
                        border: Border.all(color: i == _slide ? c.primary : c.outline, width: i == _slide ? 2 : 1),
                      ),
                      child: SlideView(deck: d, slide: d.slides[i]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A slide drawn from its shapes on a 960-wide canvas, scaled to fit. The
/// slide keeps its own colours (white unless it says otherwise).
class SlideView extends StatelessWidget {
  const SlideView({required this.deck, required this.slide, super.key});

  final Pptx deck;
  final Slide slide;

  static const double _w = 960;

  @override
  Widget build(BuildContext context) {
    final double h = _w / deck.aspect;
    // Points to canvas units: the slide is cx EMU wide, 12700 EMU a point.
    final double pt = _w / (deck.aspect * 7.5 * 72);
    const Color ink = Color(0xFF22252B);
    return AspectRatio(
      aspectRatio: deck.aspect,
      child: Container(
        decoration: BoxDecoration(
          color: slide.background == null ? const Color(0xFFFCFBF9) : Color(slide.background!),
          border: Border.all(color: context.colors.outline, width: 0.5),
        ),
        child: FittedBox(
          child: SizedBox(
            width: _w,
            height: h,
            child: Stack(
              children: <Widget>[
                for (final SlideShape s in slide.shapes)
                  Positioned(
                    left: s.x * _w,
                    top: s.y * h,
                    width: math.max(1, s.w * _w),
                    height: math.max(1, s.h * h),
                    child: s.image != null && deck.images[s.image] != null
                        ? Image.memory(deck.images[s.image]!, fit: BoxFit.contain, cacheWidth: 800)
                        : Container(
                            color: s.fill == null ? null : Color(s.fill!),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: s.kind == 'title' ? MainAxisAlignment.center : MainAxisAlignment.start,
                              children: <Widget>[
                                for (final SlideParagraph p in s.paragraphs)
                                  Padding(
                                    padding: EdgeInsets.only(left: p.level * 28.0 + (p.bullet ? 4 : 0), bottom: 6),
                                    child: Text.rich(
                                      TextSpan(
                                        children: <InlineSpan>[
                                          if (p.bullet) const TextSpan(text: '•  '),
                                          for (final SlideRun r in p.runs)
                                            TextSpan(
                                              text: r.text,
                                              style: TextStyle(
                                                fontSize: (r.size ?? 20) * pt,
                                                fontWeight: r.bold || s.kind == 'title'
                                                    ? FontWeight.w700
                                                    : FontWeight.w400,
                                                fontVariations: <FontVariation>[
                                                  FontVariation('wght', r.bold || s.kind == 'title' ? 700 : 400),
                                                ],
                                                fontStyle: r.italic ? FontStyle.italic : FontStyle.normal,
                                                color: r.color == null ? ink : Color(r.color!),
                                              ),
                                            ),
                                        ],
                                      ),
                                      textAlign: p.align == 'ctr'
                                          ? TextAlign.center
                                          : (p.align == 'r' ? TextAlign.end : TextAlign.start),
                                      style: const TextStyle(fontFamily: UnfurlType.sans, height: 1.2, color: ink),
                                      overflow: TextOverflow.clip,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Top-level, so the isolate's closure carries only the bytes.
Future<Docx> _parseDocx(Uint8List bytes) => Isolate.run(() => Docx.parse(bytes));
Future<Pptx> _parsePptx(Uint8List bytes) => Isolate.run(() => Pptx.parse(bytes));
