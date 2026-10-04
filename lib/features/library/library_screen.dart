import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/explorer.dart';
import '../../core/files.dart';
import '../../core/library/library.dart';
import '../../core/locator.dart';
import '../../core/motion/motion.dart';
import '../../core/open.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_header.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/app_menu.dart';
import '../../design_system/app_snackbar.dart';
import '../../design_system/buttons.dart';
import '../../design_system/chips.dart';
import '../../design_system/covers.dart';
import '../../design_system/search_field.dart';
import '../../design_system/states.dart';
import '../../formats/format_registry.dart';
import '../reader/sheets.dart';
import '../settings/settings_controller.dart';
import '../files/files_screen.dart' show addFolder;

enum _Filter { all, pdf, epub, unread, finished }

/// Board 2, A2 and A3: every PDF and EPUB in every folder, subfolders too.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  _Filter _filter = _Filter.all;
  String _query = '';
  Set<int>? _matches;

  Future<void> _search(String q) async {
    setState(() => _query = q.trim());
    if (_query.isEmpty) return setState(() => _matches = null);
    final Set<int> ids = await ref.read(libraryProvider).search(_query);
    if (mounted && q.trim() == _query) setState(() => _matches = ids);
  }

  bool _keep(BookItem b) => switch (_filter) {
    _Filter.all => true,
    _Filter.pdf => b.format == Formats.pdf,
    _Filter.epub => b.format == Formats.epub,
    _Filter.unread => b.unread,
    _Filter.finished => b.finished,
  };

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final AppSettings s = ref.watch(settingsProvider);
    final List<BookItem> all = ref.watch(booksProvider).value ?? const <BookItem>[];
    final List<Folder> folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final Map<int, int> counts = ref.watch(readableCountsProvider).value ?? const <int, int>{};
    final List<BookItem> filtered = sortBooks(
      all.where((BookItem b) => _keep(b) && (_matches == null || _matches!.contains(b.entry.id))).toList(),
      _query.isNotEmpty ? 'title' : s.librarySort,
    );
    final int unread = all.where((BookItem b) => b.unread).length;
    final Map<_Filter, int> chipCounts = <_Filter, int>{
      _Filter.all: all.length,
      _Filter.pdf: all.where((BookItem b) => b.format == Formats.pdf).length,
      _Filter.epub: all.where((BookItem b) => b.format == Formats.epub).length,
      _Filter.unread: unread,
      _Filter.finished: all.where((BookItem b) => b.finished).length,
    };
    // "Find books across this device" lists every folder's books, so the
    // folder row would list every folder: it steps away (board 5, X7).
    final bool device = s.findOnDevice && ref.watch(filesAccessProvider.select((FilesAccess a) => a.granted));
    final bool showFolders = !device && _filter == _Filter.all && _query.isEmpty && folders.isNotEmpty;
    final String sortLabel = switch (s.librarySort) {
      'title' => 'Title',
      'progress' => 'Progress',
      _ => 'Recent',
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CollapseOnScroll(
          builder: (BuildContext context, bool collapsed) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppHeader(
                title: 'Library',
                collapsed: collapsed,
                actions: <Widget>[
                  AppIconButton(
                    icon: s.libraryGrid ? AppIcons.viewList : AppIcons.gridView,
                    semanticLabel: s.libraryGrid ? 'Show as list' : 'Show as grid',
                    onPressed: () => ref.read(settingsProvider.notifier).setLibraryGrid(grid: !s.libraryGrid),
                  ),
                  Builder(
                    builder: (BuildContext b) => AppIconButton(
                      icon: AppIcons.moreHoriz,
                      semanticLabel: 'Sort and view',
                      onPressed: () => _menu(b, s),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: folders.isEmpty && all.isEmpty && !device
                    ? EmptyState(
                        icon: AppIcons.library,
                        title: 'No books yet',
                        aboveNav: true,
                        message: 'Add a folder and every PDF and EPUB inside it, subfolders included, shows up here. Unfurl only reads it.',
                        actions: <Widget>[
                          AppButton(
                            label: 'Add folder',
                            icon: AppIcons.createNewFolder,
                            onPressed: () => addFolder(context, ref),
                          ),
                        ],
                      )
                    : CustomScrollView(
                        slivers: <Widget>[
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 14),
                            sliver: SliverToBoxAdapter(
                              child: SearchField(
                                hint: 'Search library',
                                onChanged: (String q) => unawaited(_search(q)),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: ChipRow(
                              children: <Widget>[
                                for (final _Filter f in _Filter.values)
                                  PillChip(
                                    label: switch (f) {
                                      _Filter.all => 'All',
                                      _Filter.pdf => 'PDF',
                                      _Filter.epub => 'EPUB',
                                      _Filter.unread => 'Unread',
                                      _Filter.finished => 'Finished',
                                    },
                                    selected: _filter == f,
                                    count: _query.isEmpty ? chipCounts[f] : filtered.length,
                                    onTap: () => setState(() => _filter = f),
                                  ),
                              ],
                            ),
                          ),
                          // The folder row: only on All with no search; it
                          // leaves by size and fade, and the grid glides up.
                          SliverToBoxAdapter(
                            child: AnimatedSize(
                              duration: Motion.of(context, Motion.containerTransform),
                              curve: Motion.decelerate,
                              child: AnimatedOpacity(
                                opacity: showFolders ? 1 : 0,
                                duration: Motion.of(context, Motion.fast),
                                child: showFolders
                                    ? _FolderRow(folders: folders, counts: counts)
                                    : const SizedBox(width: double.infinity),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(Space.screen, 14, Space.screen, 14),
                            sliver: SliverToBoxAdapter(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      _query.isNotEmpty
                                          ? '${filtered.length} ${filtered.length == 1 ? 'result' : 'results'} for “$_query”${_filter == _Filter.all ? '' : ' in ${_filter.name.toUpperCase()}'}'
                                          : '${filtered.length} ${filtered.length == 1 ? 'book' : 'books'}${device ? ' on this device' : ''}${_filter == _Filter.all ? ' · $unread unread' : ''}',
                                      style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                                    ),
                                  ),
                                  if (_query.isEmpty)
                                    Text(
                                      'Sort: $sortLabel',
                                      style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (filtered.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(Space.screen),
                                child: Text(
                                  _query.isNotEmpty
                                      ? 'Nothing matches “$_query”.'
                                      : (all.isEmpty
                                            ? 'No PDFs or EPUBs found in your folders yet.'
                                            : 'No books here.'),
                                  style: UnfurlType.body.copyWith(color: c.onSurfaceVariant),
                                ),
                              ),
                            )
                          else if (_query.isNotEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.bottomSafe),
                              sliver: SliverList.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (BuildContext context, int i) => const SizedBox(height: Space.row),
                                itemBuilder: (BuildContext context, int i) =>
                                    _SearchCard(book: filtered[i], query: _query),
                              ),
                            )
                          else if (s.libraryGrid)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.bottomSafe),
                              sliver: SliverGrid.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisExtent: 190,
                                  mainAxisSpacing: 18,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (BuildContext context, int i) => Align(
                                  alignment: <Alignment>[
                                    Alignment.topLeft,
                                    Alignment.topCenter,
                                    Alignment.topRight,
                                  ][i % 3],
                                  child: SizedBox(
                                    width: 96,
                                    child: Reveal(
                                      index: i < 9 ? i : 0,
                                      child: _BookTile(book: filtered[i]),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.bottomSafe),
                              sliver: SliverToBoxAdapter(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: c.surfaceContainer,
                                    borderRadius: Radii.cardR,
                                    border: Border.all(color: c.outline),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: <Widget>[
                                      for (int i = 0; i < filtered.length; i++) ...<Widget>[
                                        if (i > 0) Divider(color: c.divider),
                                        Reveal(
                                          index: i < 9 ? i : 0,
                                          child: _BookRow(book: filtered[i]),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
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

  Future<void> _menu(BuildContext anchor, AppSettings s) async {
    final String? v = await showAppMenu<String>(
      context: context,
      anchorContext: anchor,
      entries: <AppMenuEntry<String>>[
        AppMenuEntry<String>(
          value: 'recent',
          label: 'Sort: Recent',
          icon: AppIcons.schedule,
          selected: s.librarySort == 'recent',
        ),
        AppMenuEntry<String>(
          value: 'title',
          label: 'Sort: Title',
          icon: AppIcons.sortByAlpha,
          selected: s.librarySort == 'title',
        ),
        AppMenuEntry<String>(
          value: 'progress',
          label: 'Sort: Progress',
          icon: AppIcons.donutLarge,
          selected: s.librarySort == 'progress',
        ),
        const AppMenuEntry<String>.divider(),
        AppMenuEntry<String>(value: 'grid', label: 'View: Grid', icon: AppIcons.gridView, selected: s.libraryGrid),
        AppMenuEntry<String>(value: 'list', label: 'View: List', icon: AppIcons.viewList, selected: !s.libraryGrid),
        const AppMenuEntry<String>.divider(),
        const AppMenuEntry<String>(
          value: 'add',
          label: 'Add folder',
          icon: AppIcons.createNewFolder,
          subtitle: 'read-only access',
        ),
      ],
    );
    if (!mounted || v == null) return;
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    switch (v) {
      case 'grid' || 'list':
        await ctl.setLibraryGrid(grid: v == 'grid');
      case 'add':
        await addFolder(context, ref);
      default:
        await ctl.setLibrarySort(v);
    }
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.folders, required this.counts});

  final List<Folder> folders;
  final Map<int, int> counts;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    Widget card({
      required IconData icon,
      required String name,
      String? meta,
      Color? tint,
      required VoidCallback onTap,
    }) => Semantics(
      button: true,
      label: meta == null ? name : '$name, $meta',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: c.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.cardR,
          side: BorderSide(color: c.outline),
        ),
        child: InkWell(
          customBorder: const RoundedRectangleBorder(borderRadius: Radii.cardR),
          onTap: onTap,
          child: Container(
            width: 128,
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.sm,
              children: <Widget>[
                AppIcon(icon, color: tint ?? c.icon),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UnfurlType.titleMedium.copyWith(fontSize: 14, height: 1.25, color: tint ?? c.onSurface),
                    ),
                    if (meta != null) Text(meta, style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 92,
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, _) => ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.screen),
            children: <Widget>[
              for (final Folder f in folders) ...<Widget>[
                card(
                  icon: f.accessLost ? AppIcons.folderOff : AppIcons.folder,
                  name: f.name,
                  meta: f.accessLost ? 'Access lost' : '${counts[f.id] ?? 0} readable',
                  onTap: () => context.push(Routes.folder(f.id, base: Routes.library)),
                ),
                const SizedBox(width: 10),
              ],
              card(
                icon: AppIcons.createNewFolder,
                name: 'Add folder',
                tint: c.accent,
                onTap: () => addFolder(context, ref),
              ),
              if (folders.length >= 3) ...<Widget>[
                const SizedBox(width: 10),
                card(
                  icon: AppIcons.arrowForward,
                  name: 'See all',
                  meta: '${folders.length} folders',
                  onTap: () => context.push(Routes.foldersIn(Routes.library)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a book, at its place and mode, with the cover leading into it.
Future<void> openBook(BuildContext context, BookItem b, {String? heroTag}) => openDocument(
  context,
  b.ref,
  at: b.doc?.position == null ? null : Locator.fromJson(b.doc!.position!),
  mode: b.doc?.mode,
  heroTag: heroTag,
);

class _BookTile extends ConsumerWidget {
  const _BookTile({required this.book});

  final BookItem book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String tag = 'lib:${book.entry.id}';
    return CoverTile(
      heroTag: tag,
      cover: CoverArt(title: book.title, author: book.author, fingerprint: book.fingerprint, format: book.format),
      progress: book.progress,
      finished: book.finished,
      meta: book.format == Formats.pdf && book.progress > 0 && !book.finished
          ? 'PDF · ${(book.progress * 100).round()}%'
          : null,
      path: book.path,
      onTap: () => openBook(context, book, heroTag: tag),
      onLongPress: () => showBookSheet(context, ref, book),
    );
  }
}

class _BookRow extends ConsumerWidget {
  const _BookRow({required this.book});

  final BookItem book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final String state = book.finished ? 'Finished' : (book.unread ? 'New' : '${(book.progress * 100).round()}%');
    return InkWell(
      onTap: () => openBook(context, book),
      onLongPress: () => showBookSheet(context, ref, book),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        child: Row(
          spacing: 14,
          children: <Widget>[
            CoverArt(
              title: book.title,
              author: book.author,
              fingerprint: book.fingerprint,
              format: book.format,
              width: 44,
              height: 62,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: <Widget>[
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UnfurlType.titleMedium.copyWith(color: c.onSurface),
                  ),
                  if (book.author != null)
                    Text(book.author!, style: UnfurlType.bodySmall.copyWith(height: 1.4, color: c.onSurfaceVariant)),
                  Row(
                    spacing: 4,
                    children: <Widget>[
                      AppIcon(AppIcons.folder, size: 14, color: c.onSurfaceVariant),
                      Flexible(
                        child: Text(
                          book.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UnfurlType.monoLabel.copyWith(fontSize: 10.5, color: c.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Row(
                      spacing: Space.sm,
                      children: <Widget>[
                        Expanded(child: ProgressTrack(value: book.progress)),
                        Text(
                          '${book.format.label} · $state',
                          style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A search result: the match marked the way Mull's search marks it.
class _SearchCard extends ConsumerWidget {
  const _SearchCard({required this.book, required this.query});

  final BookItem book;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    TextSpan marked(String text, TextStyle base) {
      final List<TextSpan> out = <TextSpan>[];
      final String lower = text.toLowerCase();
      final List<String> words = query.toLowerCase().split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).toList();
      int at = 0;
      while (at < text.length) {
        int best = -1, len = 0;
        for (final String w in words) {
          final int i = lower.indexOf(w, at);
          if (i >= 0 && (best < 0 || i < best)) {
            best = i;
            len = w.length;
          }
        }
        if (best < 0) break;
        out.add(TextSpan(text: text.substring(at, best)));
        out.add(
          TextSpan(
            text: text.substring(best, best + len),
            style: TextStyle(backgroundColor: c.primaryContainer, color: c.onPrimaryContainer),
          ),
        );
        at = best + len;
      }
      out.add(TextSpan(text: text.substring(at)));
      return TextSpan(style: base, children: out);
    }

    return Material(
      color: c.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.cardR,
        side: BorderSide(color: c.outline),
      ),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(borderRadius: Radii.cardR),
        onTap: () => openBook(context, book),
        onLongPress: () => showBookSheet(context, ref, book),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
          child: Row(
            spacing: 14,
            children: <Widget>[
              CoverArt(
                title: book.title,
                author: book.author,
                fingerprint: book.fingerprint,
                format: book.format,
                width: 44,
                height: 62,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text.rich(marked(book.title, UnfurlType.titleMedium.copyWith(fontSize: 15, color: c.onSurface))),
                    if (book.author != null)
                      Text.rich(
                        marked(
                          book.author!,
                          UnfurlType.note.copyWith(fontSize: 13, height: 1.5, color: c.onSurfaceVariant),
                        ),
                      ),
                    Text(
                      '${book.format.label} · ${book.doc?.where?.toLowerCase() ?? (book.unread ? 'not started' : '${(book.progress * 100).round()}%')}',
                      style: UnfurlType.monoLabel.copyWith(height: 1.6, color: c.onSurfaceVariant),
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

/// Long-press (A3): Book info, Mark as finished, Remove from library.
Future<void> showBookSheet(BuildContext context, WidgetRef ref, BookItem book) {
  final String state = book.finished ? 'Finished' : (book.unread ? 'Not started' : '${(book.progress * 100).round()}%');
  return showReaderSheet<void>(context, (BuildContext ctx) {
    final UnfurlColors c = ctx.colors;
    Widget row(IconData icon, String label, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: Radii.cardR,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Row(
            spacing: 18,
            children: <Widget>[
              AppIcon(icon, color: c.icon),
              Text(label, style: UnfurlType.body.copyWith(height: 1.3, color: c.onSurface)),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: Space.xs, bottom: 18),
          child: Row(
            spacing: Space.lg,
            children: <Widget>[
              CoverArt(
                title: book.title,
                author: book.author,
                fingerprint: book.fingerprint,
                format: book.format,
                width: 56,
                height: 80,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: <Widget>[
                    Text(book.title, style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
                    if (book.author != null)
                      Text(book.author!, style: UnfurlType.note.copyWith(height: 1.4, color: c.onSurfaceVariant)),
                    Text(
                      '${book.format.label} · $state${book.doc?.where == null ? '' : ' · ${book.doc!.where}'}',
                      style: UnfurlType.monoLabel.copyWith(height: 1.4, color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(color: c.divider),
        const SizedBox(height: Space.sm),
        row(AppIcons.info, 'Book info', () async {
          Navigator.of(ctx).pop();
          await showBookInfo(
            context,
            cover: CoverArt(
              title: book.title,
              author: book.author,
              fingerprint: book.fingerprint,
              format: book.format,
              width: 64,
              height: 92,
            ),
            title: book.title,
            author: book.author,
            facts: <(String, String)>[
              ('Location', '${book.path} › ${book.entry.name}'),
              ('Size', '${Files.size(book.entry.size)} · ${book.format.label}'),
              if (book.entry.units != null) (book.format == Formats.pdf ? 'Pages' : 'Chapters', '${book.entry.units}'),
              ('Progress', state),
              ('Modified', Files.when(book.entry.modified)),
            ],
            highlights: 0,
            onExport: null,
          );
        }),
        row(
          book.finished ? AppIcons.history : AppIcons.taskAlt,
          book.finished ? 'Mark as unread' : 'Mark as finished',
          () async {
            Navigator.of(ctx).pop();
            String? fp = book.fingerprint;
            fp ??= await Files.fingerprint(book.entry.uri);
            if (fp == null) return;
            await ref.read(libraryProvider).touch(fp, book.ref, title: book.entry.title, author: book.entry.author);
            await ref.read(libraryProvider).setFinished(fp, finished: !book.finished);
          },
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.sm, 0),
          decoration: BoxDecoration(color: c.dangerContainer, borderRadius: Radii.cardR),
          child: InkWell(
            borderRadius: Radii.cardR,
            onTap: () async {
              Navigator.of(ctx).pop();
              await ref.read(libraryProvider).setHidden(book.entry.id, hidden: true);
              if (context.mounted) {
                AppSnackbar.undo(
                  context,
                  'Removed ${book.title}',
                  () => ref.read(libraryProvider).setHidden(book.entry.id, hidden: false),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  spacing: 18,
                  children: <Widget>[
                    AppIcon(AppIcons.removeCircle, color: c.onDangerContainer),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Remove from library',
                            style: UnfurlType.body.copyWith(height: 1.3, color: c.onDangerContainer),
                          ),
                          Text(
                            'The file stays on your phone.',
                            style: UnfurlType.bodySmall.copyWith(color: c.onDangerContainer),
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
      ],
    );
  });
}
