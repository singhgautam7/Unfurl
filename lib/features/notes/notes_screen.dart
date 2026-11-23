import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/files.dart';
import '../../core/layout.dart';
import '../../core/library/library.dart';
import '../../core/locator.dart';
import '../../core/motion/kit.dart';
import '../../core/open.dart';
import '../../core/platform/platform.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/reading_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_header.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/app_menu.dart';
import '../../design_system/app_snackbar.dart';
import '../../design_system/buttons.dart';
import '../../design_system/chips.dart';
import '../../design_system/containers.dart';
import '../../design_system/covers.dart' show kLiterata;
import '../../design_system/states.dart';
import '../../formats/format_registry.dart';
import '../cards/card_editor.dart';
import '../cards/share_card.dart';
import '../reader/reading_prefs.dart';
import '../reader/sheets.dart';
import '../settings/settings_controller.dart';

/// Board 2, A4: every highlight, note and bookmark, grouped by document,
/// newest group first. A tap opens the document at that passage, in the mode
/// it was made in.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

/// One annotation with its search text lowercased once, not per keystroke.
class _Mark {
  _Mark(this.a, this.doc) : quote = a.quote.toLowerCase(), note = a.note?.toLowerCase();

  final Annotation a;
  final Document? doc;
  final String quote;
  final String? note;
}

/// Everything derived from the annotations alone: marks and chip counts.
class _Index {
  _Index(List<(Annotation, Document?)> all)
    : marks = <_Mark>[for (final (Annotation a, Document? d) in all) _Mark(a, d)] {
    for (final _Mark m in marks) {
      if (m.a.kind == 'bookmark') {
        bookmarks++;
      } else if (m.a.kind == 'highlight' && m.a.color != null) {
        colors[m.a.color!] = (colors[m.a.color!] ?? 0) + 1;
      }
    }
  }

  final List<_Mark> marks;
  final Map<int, int> colors = <int, int>{};
  int bookmarks = 0;
}

/// One line of the flat list: a document's header or one of its notes.
sealed class _Line {
  const _Line(this.key);

  final Key key;
}

final class _Head extends _Line {
  _Head(this.fingerprint, this.title, this.marks) : super(ValueKey<String>('head $fingerprint'));

  final String fingerprint;
  final String title;
  final List<_Mark> marks;
}

final class _Entry extends _Line {
  _Entry(this.mark, {required this.last, required this.first}) : super(ValueKey<int>(mark.a.id));

  final _Mark mark;
  final bool first;
  final bool last;
}

/// The filtered, grouped list as one flat run of lines, so a book with
/// hundreds of highlights stays lazy.
class _View {
  _View(this.lines, this.shown) {
    for (int i = 0; i < lines.length; i++) {
      indexOfKey[lines[i].key] = i;
    }
    for (final _Mark m in shown) {
      byId[m.a.id] = m;
    }
  }

  final List<_Line> lines;
  final List<_Mark> shown;
  final Map<Key, int> indexOfKey = <Key, int>{};
  final Map<int, _Mark> byId = <int, _Mark>{};
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  /// A highlight colour index, -1 for bookmarks, null for all.
  int? _filter;

  /// Expanded windows: the note shown beside the list (board 6, V7).
  int? _selected;
  String _query = '';
  Timer? _debounce;

  // Memo: the index on the data, the view on (index, filter, query).
  List<(Annotation, Document?)>? _indexOf;
  late _Index _index;
  Object? _viewKey;
  late _View _view;

  /// Rows already built once: only a row new to the list eases in.
  final Set<Key> _seen = <Key>{};

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    final String t = q.trim();
    if (t.isEmpty) {
      setState(() => _query = '');
      return;
    }
    _debounce = Timer(Motion.searchDelay, () {
      if (mounted) setState(() => _query = t);
    });
  }

  bool _keep(_Mark m, String q) {
    final Annotation a = m.a;
    if (_filter == -1 && a.kind != 'bookmark') return false;
    if (_filter != null && _filter! >= 0 && (a.kind != 'highlight' || a.color != _filter)) return false;
    if (q.isNotEmpty && !m.quote.contains(q) && !(m.note?.contains(q) ?? false)) return false;
    return true;
  }

  _View _viewOf(List<(Annotation, Document?)> all) {
    if (!identical(_indexOf, all)) {
      _indexOf = all;
      _index = _Index(all);
      _viewKey = null;
    }
    final Object key = (_index, _filter, _query);
    if (key == _viewKey) return _view;
    _viewKey = key;
    final String q = _query.toLowerCase();
    final List<_Mark> shown = <_Mark>[
      for (final _Mark m in _index.marks)
        if (_keep(m, q)) m,
    ];
    // Groups by document, newest group first (the list is newest first).
    final Map<String, List<_Mark>> groups = <String, List<_Mark>>{};
    for (final _Mark m in shown) {
      groups.putIfAbsent(m.a.fingerprint, () => <_Mark>[]).add(m);
    }
    final List<_Line> lines = <_Line>[];
    for (final MapEntry<String, List<_Mark>> g in groups.entries) {
      final Document? d = g.value.first.doc;
      lines.add(_Head(g.key, d?.title ?? d?.name ?? 'Document', g.value));
      for (int i = 0; i < g.value.length; i++) {
        lines.add(_Entry(g.value[i], first: i == 0, last: i == g.value.length - 1));
      }
    }
    _view = _View(lines, shown);
    // A row that left the list eases in again if it comes back.
    _seen.retainAll(_view.indexOfKey.keys);
    return _view;
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final AsyncValue<List<(Annotation, Document?)>> data = ref.watch(allAnnotationsProvider);
    // The reading theme needs the colour family and the chosen theme only.
    ref.watch(
      settingsProvider.select(
        (AppSettings s) => s.dynamicColor && s.wallpaperSeed != null ? s.wallpaperSeed : s.familyId,
      ),
    );
    final ReadingThemeId? picked = ref.watch(readingPrefsProvider.select((ReadingPrefs p) => p.theme));
    final ReadingTheme theme = ReadingTheme.of(
      ref.read(settingsProvider).family,
      picked ??
          (c.isDark ? (c.tone == Tone.amoled ? ReadingThemeId.amoled : ReadingThemeId.dark) : ReadingThemeId.light),
    );
    // Until the first value arrives there is nothing to say: just the header.
    final List<(Annotation, Document?)>? all = data.value;
    if (all == null) {
      return const Scaffold(
        body: HeaderPage(
          header: AppHeader(title: 'Notes'),
          body: _noBody,
        ),
      );
    }
    if (all.isEmpty) {
      return Scaffold(
        body: HeaderPage(
          header: const AppHeader(title: 'Notes'),
          body: (BuildContext context, double inset) => HeaderPage.below(
            const EmptyState(
              icon: AppIcons.notes,
              title: 'Nothing marked yet',
              message: 'Highlights, notes and bookmarks from every book collect here. Press and hold any passage while reading to start.',
            ),
          ),
        ),
      );
    }

    final _View view = _viewOf(all);
    final _Index index = _index;
    final bool split = SizeClass.of(context) == SizeClass.expanded;
    final _Mark? current = !split || view.shown.isEmpty ? null : view.byId[_selected] ?? view.shown.first;
    final Widget list = HeaderPage(
      header: HeaderSearch(
        hint: 'Search notes',
        onChanged: _search,
        builder: (BuildContext context, Widget? search) => AppHeader(title: 'Notes', actions: <Widget>[?search]),
      ),
      body: (BuildContext context, double inset) => CustomScrollView(
        clipBehavior: Clip.none,
        slivers: <Widget>[
          SliverPadding(
            key: const ValueKey<String>('chips'),
            padding: EdgeInsets.only(top: inset + 2, bottom: Space.lg - 4),
            sliver: SliverToBoxAdapter(
              child: ChipRow(
                children: <Widget>[
                  PillChip(
                    label: 'All',
                    selected: _filter == null,
                    count: all.length,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final HighlightColor h in HighlightColor.values)
                    PillChip(
                      label: h.label,
                      selected: _filter == h.index,
                      count: index.colors[h.index] ?? 0,
                      leading: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: theme.highlights[h.index],
                          shape: BoxShape.circle,
                          border: Border.all(color: c.outline),
                        ),
                      ),
                      onTap: () => setState(() => _filter = _filter == h.index ? null : h.index),
                    ),
                  PillChip(
                    label: 'Bookmarks',
                    selected: _filter == -1,
                    count: index.bookmarks,
                    leading: const AppIcon(AppIcons.bookmark),
                    onTap: () => setState(() => _filter = _filter == -1 ? null : -1),
                  ),
                ],
              ),
            ),
          ),
          if (view.lines.isEmpty)
            SliverToBoxAdapter(
              key: const ValueKey<String>('none'),
              child: Padding(
                padding: const EdgeInsets.all(Space.screen),
                child: Text(
                  _query.isEmpty ? 'Nothing in this colour yet.' : 'Nothing matches “$_query”.',
                  style: UnfurlType.body.copyWith(color: c.onSurfaceVariant),
                ),
              ),
            ),
          SliverPadding(
            key: const ValueKey<String>('lines'),
            padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.bottomSafe),
            sliver: SliverList.builder(
              itemCount: view.lines.length,
              findChildIndexCallback: (Key k) => view.indexOfKey[k],
              itemBuilder: (BuildContext context, int i) {
                final _Line line = view.lines[i];
                final bool ease = i < 6 && _seen.add(line.key);
                final bool filtered = _filter != null || _query.isNotEmpty;
                final Widget child = switch (line) {
                  _Head() => Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : Space.lg, bottom: 10),
                    child: SectionHeader(
                      label: '${line.title} · ${line.marks.length}',
                      action: filtered ? null : 'Export',
                      onAction: () => _export(line.title, line.marks),
                    ),
                  ),
                  _Entry() => ListGroupRow(
                    first: line.first,
                    last: line.last,
                    child: _NoteRow(
                      annotation: line.mark.a,
                      doc: line.mark.doc,
                      theme: theme,
                      selected: current?.a.id == line.mark.a.id,
                      onSelect: split ? () => setState(() => _selected = line.mark.a.id) : null,
                    ),
                  ),
                };
                // Always the same wrapper, so a row that stays keeps its element.
                return StaggeredEntrance(key: line.key, index: i, animate: ease, child: child);
              },
            ),
          ),
        ],
      ),
    );
    if (!split) return Scaffold(body: list);
    final UnfurlColors cc = context.colors;
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(width: 440, child: list),
          VerticalDivider(width: 1, color: cc.divider),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.fast),
              switchInCurve: Motion.decelerate,
              child: current == null
                  ? const SizedBox.expand()
                  : _NoteDetail(
                      key: ValueKey<int>(current.a.id),
                      annotation: current.a,
                      doc: current.doc,
                      theme: theme,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _noBody(BuildContext context, double inset) => const SizedBox.shrink();

  Future<void> _export(String title, List<_Mark> g) async {
    final StringBuffer md = StringBuffer('# $title\n');
    final List<Annotation> items = g.map((_Mark x) => x.a).toList()
      ..sort((Annotation a, Annotation b) => a.progress.compareTo(b.progress));
    for (final Annotation a in items) {
      if (a.kind == 'bookmark') {
        md.write('\n- Bookmark: ${a.label}\n');
      } else {
        md.write('\n> ${a.quote.replaceAll('\n', '\n> ')}\n\n${a.label}\n');
        if (a.note != null) md.write('\n${a.note}\n');
      }
    }
    await Platform.shareText(md.toString(), subject: 'Highlights from $title');
  }
}

class _NoteRow extends ConsumerWidget {
  const _NoteRow({
    required this.annotation,
    required this.doc,
    required this.theme,
    this.selected = false,
    this.onSelect,
  });

  final Annotation annotation;
  final Document? doc;
  final ReadingTheme theme;

  /// List and detail: the row shown beside the list, tinted.
  final bool selected;

  /// List and detail: a tap selects instead of opening.
  final VoidCallback? onSelect;

  void _open(BuildContext context) => unawaited(
    openDocument(
      context,
      DocRef(uri: doc!.uri, name: doc!.name, size: doc!.size),
      at: Locator.fromJson(annotation.locator),
      mode: annotation.mode,
    ),
  );

  /// Board 6, V5: Go to page, Edit note, Copy, Share as card, Delete.
  Future<void> _menu(BuildContext context, BuildContext anchor, WidgetRef ref) async {
    final Annotation a = annotation;
    final String? v = await showAppMenu<String>(
      context: context,
      anchorContext: anchor,
      entries: <AppMenuEntry<String>>[
        if (doc != null) const AppMenuEntry<String>(value: 'open', label: 'Go to page', icon: AppIcons.arrowOutward),
        AppMenuEntry<String>(value: 'note', label: a.note == null ? 'Add note' : 'Edit note', icon: AppIcons.editNote),
        const AppMenuEntry<String>(value: 'copy', label: 'Copy', icon: AppIcons.copy),
        const AppMenuEntry<String>(value: 'card', label: 'Share as card', icon: AppIcons.image),
        const AppMenuEntry<String>.divider(),
        const AppMenuEntry<String>(value: 'delete', label: 'Delete', icon: AppIcons.delete, danger: true),
      ],
    );
    if (!context.mounted) return;
    final Library library = ref.read(libraryProvider);
    switch (v) {
      case 'open':
        _open(context);
      case 'note':
        final String? text = await showNoteSheet(
          context,
          quote: a.quote,
          color: theme.highlights[(a.color ?? 0).clamp(0, 3)],
          initial: a.note,
        );
        if (text != null) {
          await library.updateAnnotation(a.id, note: text.isEmpty ? null : text, clearNote: text.isEmpty);
        }
      case 'copy':
        await copyText(a.quote);
        if (context.mounted) AppSnackbar.info(context, 'Copied');
      case 'card':
        await showCardEditor(
          context,
          CardContent(
            quote: a.quote,
            title: doc?.title ?? doc?.name.replaceAll(RegExp(r'\.[^.]+$'), '') ?? '',
            author: doc?.author,
            location: a.label,
            fingerprint: a.fingerprint,
            format: doc == null ? null : Formats.of(doc!.name),
          ),
        );
      case 'delete':
        await library.deleteAnnotation(a.id);
        if (context.mounted) AppSnackbar.undo(context, 'Removed', () => library.restoreAnnotation(a));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final Annotation a = annotation;
    final bool bookmark = a.kind == 'bookmark';
    return ColoredBox(
      color: selected ? c.surfaceContainerHigh : c.surfaceContainerHigh.withAlpha(0),
      child: PressableRow(
        onTap: onSelect ?? (doc == null ? null : () => _open(context)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: <Widget>[
              Row(
                spacing: 6,
                children: <Widget>[
                  AppIcon(bookmark ? AppIcons.bookmark : AppIcons.notes, size: 16, color: c.onSurfaceVariant),
                  Expanded(
                    child: Text(
                      '${a.label} · ${Files.ago(a.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                    ),
                  ),
                  if (!bookmark)
                    // A 48dp target that doesn't push the line taller.
                    SizedBox(
                      width: 32,
                      height: 24,
                      child: OverflowBox(
                        maxWidth: IconSpec.tapTarget,
                        maxHeight: IconSpec.tapTarget,
                        child: Builder(
                          builder: (BuildContext anchor) => AppIconButton(
                            icon: AppIcons.moreVert,
                            filled: false,
                            semanticLabel: 'Highlight actions',
                            onPressed: () => unawaited(_menu(context, anchor, ref)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (bookmark)
                Text(a.label.isEmpty ? a.quote : a.label, style: UnfurlType.titleMedium.copyWith(color: c.onSurface))
              else
                HighlightQuote(text: a.quote, color: theme.highlights[(a.color ?? 0).clamp(0, 3)]),
              if (a.note != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: <Widget>[
                    AppIcon(AppIcons.editNote, size: 18, color: c.onSurfaceVariant),
                    Expanded(
                      child: Text(a.note!, style: UnfurlType.note.copyWith(color: c.onSurfaceVariant)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// List and detail on expanded windows (board 6, V7): the note large, with
/// Go to page and Share as card in its bar.
class _NoteDetail extends StatelessWidget {
  const _NoteDetail({required this.annotation, required this.doc, required this.theme, super.key});

  final Annotation annotation;
  final Document? doc;
  final ReadingTheme theme;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final Annotation a = annotation;
    final String title = doc?.title ?? doc?.name ?? 'Document';
    return SafeArea(
      left: false,
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: Space.bottomSafe),
        children: <Widget>[
          SizedBox(
            height: 56,
            child: Row(
              children: <Widget>[
                const SizedBox(width: Space.xs),
                if (doc != null)
                  AppIconButton(
                    icon: AppIcons.arrowOutward,
                    filled: false,
                    semanticLabel: 'Go to page',
                    onPressed: () => unawaited(
                      openDocument(
                        context,
                        DocRef(uri: doc!.uri, name: doc!.name, size: doc!.size),
                        at: Locator.fromJson(a.locator),
                        mode: a.mode,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UnfurlType.titleMedium.copyWith(fontSize: 18, color: c.onSurface),
                  ),
                ),
                if (a.kind == 'highlight')
                  AppIconButton(
                    icon: AppIcons.image,
                    filled: false,
                    semanticLabel: 'Share as card',
                    onPressed: () => unawaited(
                      showCardEditor(
                        context,
                        CardContent(
                          quote: a.quote,
                          title: title,
                          author: doc?.author,
                          location: a.label,
                          fingerprint: a.fingerprint,
                          format: doc == null ? null : Formats.of(doc!.name),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: Space.xs),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(40, Space.xl, 40, Space.md),
            child: a.kind == 'bookmark'
                ? Text(a.label.isEmpty ? a.quote : a.label, style: UnfurlType.title.copyWith(color: c.onSurface))
                : Text(
                    '“${a.quote}”',
                    style: TextStyle(fontFamily: kLiterata, fontSize: 26, height: 1.5, color: c.onSurface),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '${a.label} · ${Files.when(a.createdAt.millisecondsSinceEpoch)}',
              style: UnfurlType.monoLabel.copyWith(fontSize: 12, color: c.onSurfaceVariant),
            ),
          ),
          if (a.note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(40, Space.xl, 40, 0),
              child: Text(a.note!, style: UnfurlType.body.copyWith(color: c.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}
