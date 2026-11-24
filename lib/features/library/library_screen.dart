import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/explorer.dart';
import '../../core/files.dart';
import '../../core/layout.dart';
import '../../core/library/library.dart';
import '../../core/locator.dart';
import '../../core/motion/kit.dart';
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
import '../../design_system/containers.dart';
import '../../design_system/covers.dart';
import '../../design_system/states.dart';
import '../../formats/format_registry.dart';
import '../insights/book_insights.dart';
import '../reader/sheets.dart';
import '../settings/settings_controller.dart';
import '../files/files_screen.dart' show addFolder;
import '../files/files_widgets.dart' show RowTile, TileKind;

/// Unread and Finished: v2's chips, in the sort menu since the v3 chip row
/// holds format families (board 6, V3 chips).
enum _Status { all, unread, finished }

/// Board 2, A2 and A3 (v3 families): every file Unfurl opens in every folder,
/// subfolders too, filtered by the folder screen's type chips; PDF first.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  /// Null: All. PDF until the user picks another (or there is none).
  FormatGroup? _family = FormatGroup.pdf;
  _Status _status = _Status.all;
  String _query = '';
  Set<int>? _matches;

  Timer? _typing;

  void _search(String q) {
    _typing?.cancel();
    final String query = q.trim();
    if (query.isEmpty) {
      return setState(() {
        _query = '';
        _matches = null;
      });
    }
    _typing = Timer(Motion.searchDelay, () async {
      final Set<int> ids = await ref.read(libraryProvider).search(query);
      if (!mounted || _typing?.isActive == true) return;
      setState(() {
        _query = query;
        _matches = ids;
      });
    });
  }

  @override
  void dispose() {
    _typing?.cancel();
    super.dispose();
  }

  /// What is shown, worked out once per change of what it depends on and not
  /// on every build (500 books filtered and sorted took a frame's time).
  (List<BookItem>, FormatGroup?, _Status, String, Set<int>?)? _key;
  late _Shown _shown;

  _Shown _show(List<BookItem> all, String sort) {
    final key = (all, _family, _status, '$_query/$sort', _matches);
    final old = _key;
    if (old != null &&
        identical(old.$1, all) &&
        old.$2 == key.$2 &&
        old.$3 == key.$3 &&
        old.$4 == key.$4 &&
        identical(old.$5, key.$5)) {
      return _shown;
    }
    _key = key;
    final Map<FormatGroup, int> families = <FormatGroup, int>{};
    for (final BookItem b in all) {
      families[b.format.group] = (families[b.format.group] ?? 0) + 1;
    }
    // A family no longer present (or the only one) falls back to All.
    final FormatGroup? family = families.length > 1 && families.containsKey(_family) ? _family : null;
    final List<BookItem> items = sortBooks(
      all.where((BookItem b) => _keep(b, family) && (_matches == null || _matches!.contains(b.entry.id))).toList(),
      _query.isNotEmpty ? 'title' : sort,
    );
    return _shown = _Shown(
      items: items,
      families: families.keys.toSet(),
      family: family,
      books: items.every((BookItem b) => b.format.book),
      unread: items.where((BookItem b) => b.format.book && b.unread).length,
    );
  }

  /// Rows already eased in: a filter change eases in only what appears.
  final Set<Key> _seen = <Key>{};

  Widget _ease(int i, Key key, Widget child) =>
      StaggeredEntrance(key: key, index: i, animate: i < 9 && _seen.add(key), child: child);

  bool _keep(BookItem b, FormatGroup? family) =>
      (family == null || b.format.group == family) &&
      switch (_status) {
        _Status.all => true,
        _Status.unread => b.format.book && b.unread,
        _Status.finished => b.finished,
      };

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final (bool asGrid, String sort, bool findOnDevice) = ref.watch(
      settingsProvider.select((AppSettings s) => (s.libraryGrid, s.librarySort, s.findOnDevice)),
    );
    final List<BookItem> all = ref.watch(booksProvider).value ?? const <BookItem>[];
    final List<Folder> folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final _Shown shown = _show(all, sort);
    final List<BookItem> filtered = shown.items;
    final FormatGroup? family = shown.family;
    final bool books = shown.books;
    final int unread = shown.unread;
    final bool anyFile = !books;
    // "Find books across this device" lists every folder's books, so the
    // folder row would list every folder: it steps away (board 5, X7).
    final bool device = findOnDevice && ref.watch(filesAccessProvider.select((FilesAccess a) => a.granted));
    final CoverGrid grid = CoverGrid.of(context);
    final bool showFolders = !device && _status == _Status.all && _query.isEmpty && folders.isNotEmpty;
    final String sortLabel = switch (sort) {
      'title' => 'Title',
      'progress' => 'Progress',
      _ => 'Recent',
    };

    return Scaffold(
      body: HeaderPage(
        header: HeaderSearch(
          hint: 'Search library',
          onChanged: _search,
          enabled: !(folders.isEmpty && all.isEmpty && !device),
          builder: (BuildContext context, Widget? search) => AppHeader(
            title: 'Library',
            actions: <Widget>[
              ?search,
              Builder(
                builder: (BuildContext b) => AppIconButton(
                  icon: AppIcons.moreHoriz,
                  semanticLabel: 'Sort and view',
                  onPressed: () => _menu(b, asGrid: asGrid, sort: sort),
                ),
              ),
            ],
          ),
        ),
        body: (BuildContext context, double inset) => folders.isEmpty && all.isEmpty && !device
            ? HeaderPage.below(
                EmptyState(
                  icon: AppIcons.library,
                  title: 'No books yet',
                  aboveNav: true,
                  message: 'Add a folder and every book inside it, subfolders included, shows up here. Unfurl only reads it.',
                  actions: <Widget>[
                    AppButton(
                      label: 'Add folder',
                      icon: AppIcons.createNewFolder,
                      onPressed: () => addFolder(context, ref),
                    ),
                  ],
                ),
              )
            : CustomScrollView(
                clipBehavior: Clip.none,
                slivers: <Widget>[
                  SliverToBoxAdapter(child: SizedBox(height: inset + Space.xs)),
                  // Families present, in the spec's order; none with
                  // only one (board 6, V3 chips).
                  if (shown.families.length > 1)
                    SliverToBoxAdapter(
                      child: FormatChips(
                        present: shown.families,
                        selected: family,
                        shown: filtered.length,
                        onSelected: (FormatGroup? g) => setState(() => _family = g),
                      ),
                    ),
                  // The folder row: not while searching or showing
                  // Unread / Finished; it leaves by size and fade, and
                  // the grid glides up.
                  SliverToBoxAdapter(
                    child: AnimatedSize(
                      duration: Motion.of(context, Motion.containerTransform),
                      curve: Motion.decelerate,
                      child: AnimatedOpacity(
                        opacity: showFolders ? 1 : 0,
                        duration: Motion.of(context, Motion.fast),
                        child: showFolders ? _FolderRow(folders: folders) : const SizedBox(width: double.infinity),
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
                                  ? '${filtered.length} ${filtered.length == 1 ? 'result' : 'results'} for “$_query”${family == null ? '' : ' in ${family.label}'}'
                                  : '${filtered.length} ${books ? (filtered.length == 1 ? 'book' : 'books') : (filtered.length == 1 ? 'file' : 'files')}${device ? ' on this device' : ''}${switch (_status) {
                                      _Status.all => unread > 0 ? ' · $unread unread' : '',
                                      _Status.unread => ' · unread',
                                      _Status.finished => ' · finished',
                                    }}',
                              style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                            ),
                          ),
                          if (_query.isEmpty)
                            Text('Sort: $sortLabel', style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant)),
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
                              : (all.isEmpty ? 'No books found in your folders yet.' : 'Nothing here.'),
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
                        findItemIndexCallback: shown.indexOf,
                        itemBuilder: (BuildContext context, int i) =>
                            _SearchCard(key: _Shown.keyOf(filtered[i]), book: filtered[i], query: _query),
                      ),
                    )
                  else if (asGrid)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.bottomSafe),
                      sliver: SliverGrid.builder(
                        // 3 / 5 / 7 columns (board 6, V7).
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: grid.columns,
                          // Other files carry a name line over the meta.
                          mainAxisExtent: grid.extent(anyFile ? 72 : 54),
                          mainAxisSpacing: 18,
                          crossAxisSpacing: grid.columns == 3 ? 0 : 12,
                        ),
                        itemCount: filtered.length,
                        findChildIndexCallback: shown.indexOf,
                        itemBuilder: (BuildContext context, int i) => _ease(
                          i,
                          _Shown.keyOf(filtered[i]),
                          Align(
                            alignment: grid.alignment(i),
                            child: SizedBox(
                              width: grid.tile,
                              child: _BookTile(book: filtered[i], width: grid.tile, height: grid.cover),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.bottomSafe),
                      sliver: SliverList.builder(
                        itemCount: filtered.length,
                        findChildIndexCallback: shown.indexOf,
                        itemBuilder: (BuildContext context, int i) => _ease(
                          i,
                          _Shown.keyOf(filtered[i]),
                          ListGroupRow(
                            first: i == 0,
                            last: i == filtered.length - 1,
                            child: _BookRow(book: filtered[i]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _menu(BuildContext anchor, {required bool asGrid, required String sort}) async {
    final String? v = await showAppMenu<String>(
      context: context,
      anchorContext: anchor,
      entries: <AppMenuEntry<String>>[
        AppMenuEntry<String>(
          value: 'recent',
          label: 'Sort: Recent',
          icon: AppIcons.schedule,
          selected: sort == 'recent',
        ),
        AppMenuEntry<String>(
          value: 'title',
          label: 'Sort: Title',
          icon: AppIcons.sortByAlpha,
          selected: sort == 'title',
        ),
        AppMenuEntry<String>(
          value: 'progress',
          label: 'Sort: Progress',
          icon: AppIcons.donutLarge,
          selected: sort == 'progress',
        ),
        const AppMenuEntry<String>.divider(),
        AppMenuEntry<String>(
          value: 'show:all',
          label: 'Show: All',
          icon: AppIcons.library,
          selected: _status == _Status.all,
        ),
        AppMenuEntry<String>(
          value: 'show:unread',
          label: 'Show: Unread',
          icon: AppIcons.unreadDot,
          selected: _status == _Status.unread,
        ),
        AppMenuEntry<String>(
          value: 'show:finished',
          label: 'Show: Finished',
          icon: AppIcons.checkCircle,
          selected: _status == _Status.finished,
        ),
        const AppMenuEntry<String>.divider(),
        AppMenuEntry<String>(value: 'grid', label: 'View: Grid', icon: AppIcons.gridView, selected: asGrid),
        AppMenuEntry<String>(value: 'list', label: 'View: List', icon: AppIcons.viewList, selected: !asGrid),
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
      case 'show:all' || 'show:unread' || 'show:finished':
        setState(() => _status = _Status.values.byName(v.substring(5)));
      case 'grid' || 'list':
        await ctl.setLibraryGrid(grid: v == 'grid');
      case 'add':
        await addFolder(context, ref);
      default:
        await ctl.setLibrarySort(v);
    }
  }
}

double _lineHeight(BuildContext context, TextStyle style) {
  final TextPainter tp = TextPainter(
    text: TextSpan(text: 'Ag', style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final double h = tp.height;
  tp.dispose();
  return h;
}

/// What the Library shows now.
class _Shown {
  _Shown({
    required this.items,
    required this.families,
    required this.family,
    required this.books,
    required this.unread,
  });

  final List<BookItem> items;
  final Set<FormatGroup> families;
  final FormatGroup? family;

  /// Only books (no documents, sheets or images).
  final bool books;
  final int unread;

  static Key keyOf(BookItem b) => ValueKey<int>(b.entry.id);

  late final Map<Key, int> _index = <Key, int>{for (int i = 0; i < items.length; i++) keyOf(items[i]): i};

  int? indexOf(Key key) => _index[key];
}

class _FolderRow extends ConsumerWidget {
  const _FolderRow({required this.folders});

  final List<Folder> folders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final Map<int, int> counts = ref.watch(readableCountsProvider).value ?? const <int, int>{};
    Widget card({
      required IconData icon,
      required String name,
      String? meta,
      Color? tint,
      required VoidCallback onTap,
    }) => SurfaceCard(
      semanticLabel: meta == null ? name : '$name, $meta',
      onTap: onTap,
      padding: const EdgeInsets.all(Space.md),
      child: SizedBox(
        width: 128 - Space.md * 2,
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
                if (meta != null)
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        // The cards' height from their text as drawn (font scale included):
        // padding, the icon, the gap, the name and the meta line.
        height:
            Space.md * 2 +
            IconSpec.size +
            Space.sm +
            _lineHeight(context, UnfurlType.titleMedium.copyWith(fontSize: 14, height: 1.25)) +
            _lineHeight(context, UnfurlType.monoLabel) +
            1,
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
  const _BookTile({required this.book, this.width = 96, this.height = 136});

  final BookItem book;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String tag = 'lib:${book.entry.id}';
    final bool file = !book.format.book;
    return CoverTile(
      heroTag: tag,
      cover: CoverArt(
        title: book.noMetadata ? book.entry.name : book.title,
        author: book.author,
        fingerprint: book.fingerprint,
        format: book.format,
        badge: Formats.labelOf(book.entry.name),
        issue: book.issue,
        width: width,
        height: height,
      ),
      progress: book.progress,
      finished: book.finished,
      muted: book.protected,
      // A document, sheet or image: its name over size and date, as in a folder.
      name: file ? BookItem.stem(book.entry.name) : null,
      meta: file ? _fileMeta(book) : _tileMeta(book),
      path: book.path,
      onTap: () => openBook(context, book, heroTag: tag),
      onLongPress: () => showBookSheet(context, ref, book),
    );
  }
}

/// "2.1 MB · Yesterday": a file that isn't a book.
String _fileMeta(BookItem book) => '${Files.size(book.entry.size)} · ${Files.when(book.entry.modified)}';

/// "#14 · 30%", "No metadata", "Protected (DRM)", "PDF · 41%"; null for
/// the tile's own New / 41% / Finished.
String? _tileMeta(BookItem book) {
  if (book.protected) return 'Protected (DRM)';
  if (book.noMetadata) return 'No metadata';
  final String pct = '${(book.progress * 100).round()}%';
  if (book.format == Formats.comics && book.issue != null) {
    return book.progress > 0 && !book.finished ? '${book.issue} · $pct' : book.issue;
  }
  return book.format == Formats.pdf && book.progress > 0 && !book.finished ? 'PDF · $pct' : null;
}

class _BookRow extends ConsumerWidget {
  const _BookRow({required this.book});

  final BookItem book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final String state = book.finished ? 'Finished' : (book.unread ? 'New' : '${(book.progress * 100).round()}%');
    final bool file = !book.format.book;
    return PressableRow(
      onTap: () => openBook(context, book),
      onLongPress: () => showBookSheet(context, ref, book),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        child: Row(
          spacing: 14,
          children: <Widget>[
            if (file)
              RowTile(icon: book.format.icon, kind: TileKind.box)
            else
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
                  if (file)
                    Text(_fileMeta(book), style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant))
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xs),
                      child: Row(
                        spacing: Space.sm,
                        children: <Widget>[
                          Expanded(child: ProgressTrack(value: book.progress)),
                          Text(
                            _tileMeta(book) ?? state,
                            style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            FormatBadge(Formats.labelOf(book.entry.name)),
          ],
        ),
      ),
    );
  }
}

/// A search result: the match marked the way Mull's search marks it.
class _SearchCard extends ConsumerWidget {
  const _SearchCard({required this.book, required this.query, super.key});

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

    return SurfaceCard(
      onTap: () => openBook(context, book),
      onLongPress: () => showBookSheet(context, ref, book),
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
                  '${Formats.labelOf(book.entry.name)} · ${book.doc?.where?.toLowerCase() ?? (book.unread ? 'not started' : '${(book.progress * 100).round()}%')}',
                  style: UnfurlType.monoLabel.copyWith(height: 1.6, color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Long-press (A3): Book info, Mark as finished, Remove from library.
Future<void> showBookSheet(BuildContext context, WidgetRef ref, BookItem book) {
  final String state = book.finished ? 'Finished' : (book.unread ? 'Not started' : '${(book.progress * 100).round()}%');
  return showReaderSheet<void>(context, (BuildContext ctx) {
    final UnfurlColors c = ctx.colors;
    Widget row(IconData icon, String label, VoidCallback onTap) => PressableRow(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: Radii.cardR,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Row(
            spacing: 18,
            children: <Widget>[
              AppIcon(icon, color: c.icon),
              Expanded(
                child: Text(label, style: UnfurlType.body.copyWith(height: 1.3, color: c.onSurface)),
              ),
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
                      '${Formats.labelOf(book.entry.name)} · $state${book.doc?.where == null ? '' : ' · ${book.doc!.where}'}',
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
              ('Size', '${Files.size(book.entry.size)} · ${Formats.labelOf(book.entry.name)}'),
              if (book.entry.units != null) (book.format == Formats.pdf ? 'Pages' : 'Chapters', '${book.entry.units}'),
              ('Progress', state),
              ('Modified', Files.when(book.entry.modified)),
            ],
            highlights: 0,
            onExport: null,
          );
        }),
        if (book.format.book)
          row(AppIcons.insights, 'Insights', () async {
            Navigator.of(ctx).pop();
            await showInsightsFor(
              context,
              uri: book.entry.uri,
              fingerprint: book.fingerprint,
              title: book.title,
              author: book.author,
              name: book.entry.name,
            );
          }),
        if (book.format.book)
          row(
            book.finished ? AppIcons.history : AppIcons.checkCircle,
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
          child: PressableRow(
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
