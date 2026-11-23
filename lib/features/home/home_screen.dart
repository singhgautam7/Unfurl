import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/explorer.dart' show kAllFilesAccess;
import '../../core/db/database.dart';
import '../../core/files.dart';
import '../../core/layout.dart';
import '../../core/library/library.dart';
import '../../core/locator.dart';
import '../../core/motion/motion.dart';
import '../../core/open.dart';
import '../../core/platform/platform.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_header.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/app_menu.dart';
import '../../design_system/buttons.dart';
import '../../design_system/containers.dart';
import '../../design_system/covers.dart';
import '../../formats/format_registry.dart';
import '../insights/book_insights.dart';
import '../library/library_screen.dart' show openBook;
import '../files/files_screen.dart' show addFolder;

/// Board 2, A1: Continue reading, recent books, recent files, and the
/// folder cards (no folder yet, access lost), which sit above everything
/// until resolved and are never dismissible.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// The board shows "Good afternoon"; the greeting follows the clock.
  static String greeting(DateTime now) => switch (now.hour) {
    < 5 => 'Good evening',
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: HeaderPage(
        header: AppHeader(
          title: greeting(DateTime.now()),
          actions: <Widget>[
            AppIconButton(
              icon: AppIcons.fileOpen,
              semanticLabel: 'Open file',
              onPressed: () => pickAndOpenFile(context),
            ),
            Builder(
              builder: (BuildContext b) => AppIconButton(
                icon: AppIcons.moreHoriz,
                semanticLabel: 'More options',
                onPressed: () async {
                  final String? choice = await showAppMenu<String>(
                    context: context,
                    anchorContext: b,
                    entries: const <AppMenuEntry<String>>[
                      AppMenuEntry<String>(
                        value: 'add',
                        label: 'Add folder',
                        icon: AppIcons.createNewFolder,
                        subtitle: 'read-only access',
                      ),
                      AppMenuEntry<String>(value: 'folders', label: 'Folders', icon: AppIcons.folder),
                      AppMenuEntry<String>.divider(),
                      AppMenuEntry<String>(value: 'settings', label: 'Settings', icon: AppIcons.settings),
                    ],
                  );
                  if (!context.mounted) return;
                  switch (choice) {
                    case 'add':
                      await addFolder(context, ref);
                    case 'folders':
                      await context.push(Routes.folders);
                    case 'settings':
                      await context.push(Routes.settings);
                  }
                },
              ),
            ),
          ],
        ),
        body: (BuildContext context, double inset) => ListView(
          clipBehavior: Clip.none,
          padding: EdgeInsets.fromLTRB(Space.screen, inset + 6, Space.screen, Space.bottomSafe),
          // Each section watches only what it draws.
          children: const <Widget>[_FolderCards(), _Continue(), _RecentFiles(), _Suggestions(), _Hint()],
        ),
      ),
    );
  }

  static String _stem(String n) => n.contains('.') ? n.substring(0, n.lastIndexOf('.')) : n;
}

/// What Home draws, worked out once per change of its stream.
final Provider<List<Document>> _readingProvider = Provider<List<Document>>(
  (Ref ref) => <Document>[
    for (final Document d in ref.watch(openedDocumentsProvider).value ?? const <Document>[])
      if (!d.finished && (Formats.of(d.name)?.book ?? false)) d,
  ],
);

final Provider<List<Recent>> _filesProvider = Provider<List<Recent>>(
  (Ref ref) => (ref.watch(recentsProvider).value ?? const <Recent>[])
      .where((Recent r) {
        final FormatModule? m = Formats.of(r.name, r.mime);
        return m != null && !m.book;
      })
      .take(5)
      .toList(),
);

/// Books not opened yet, asked for only while there is little else to show:
/// the whole library is joined to answer.
final Provider<List<BookItem>> _unopenedProvider = Provider<List<BookItem>>(
  (Ref ref) => (ref.watch(booksProvider).value ?? const <BookItem>[])
      .where((BookItem b) => b.doc == null && b.format.book)
      .take(8)
      .toList(),
);

class _FolderCards extends ConsumerWidget {
  const _FolderCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Folder>? folders = ref.watch(foldersProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (folders != null && folders.isEmpty)
          _FolderCard(
            icon: AppIcons.folder,
            danger: false,
            title: 'Add a folder to fill your Library',
            body: 'Unfurl lists the books and documents in folders you choose. It only reads them.',
            action: 'Add folder',
            actionIcon: AppIcons.createNewFolder,
            onAction: () => addFolder(context, ref),
          ),
        for (final Folder f in folders ?? const <Folder>[])
          if (f.accessLost)
            _FolderCard(
              key: ValueKey<int>(f.id),
              icon: AppIcons.folderOff,
              danger: true,
              title: 'Unfurl can’t see ${f.name} anymore',
              body: f.source == 'saf_folder'
                  ? 'Access was removed by Android. Your progress, highlights and notes are kept.'
                  : kAllFilesAccess
                  ? 'All files access was turned off. Your progress, highlights and notes are kept.'
                  : 'Pick it again in Android’s folder picker. Your progress, highlights and notes are kept.',
              action: f.source == 'saf_folder' || !kAllFilesAccess ? 'Grant access again' : 'Go to Files',
              actionIcon: AppIcons.folderOpen,
              onAction: () => regrantFolder(context, ref, f),
            ),
      ],
    );
  }
}

/// Continue reading and the recent books. Tablets show Continue reading as a
/// row of covers (board 6, V7).
class _Continue extends ConsumerWidget {
  const _Continue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Document> reading = ref.watch(_readingProvider);
    final CoverGrid grid = CoverGrid.of(context);
    final bool wide = grid.columns > 3;
    final Document? hero = wide ? null : reading.firstOrNull;
    final List<Document> books = (wide ? reading : reading.skip(1)).take(wide ? grid.columns : 8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (hero != null) ...<Widget>[Reveal(child: _HeroCard(doc: hero)), const SizedBox(height: Space.section)],
        if (books.isNotEmpty) ...<Widget>[
          SectionHeader(
            label: wide ? 'Continue reading' : 'Recent books',
            accent: wide,
            action: 'Library',
            onAction: () => StatefulNavigationShell.maybeOf(context)?.goBranch(1),
          ),
          const SizedBox(height: Space.md),
          Reveal(
            index: 1,
            child: _CoverRow(
              grid: grid,
              count: books.length,
              tile: (int i, double w, double h) {
                final Document d = books[i];
                return Builder(
                  builder: (BuildContext tile) => CoverTile(
                    onLongPress: () => _bookMenu(
                      context,
                      tile,
                      onOpen: () => _resume(context, d, 'home:${d.fingerprint}'),
                      uri: d.uri,
                      fingerprint: d.fingerprint,
                      title: d.title ?? HomeScreen._stem(d.name),
                      author: d.author,
                      name: d.name,
                    ),
                    heroTag: 'home:${d.fingerprint}',
                    cover: CoverArt(
                      title: d.title ?? HomeScreen._stem(d.name),
                      author: d.author,
                      width: w,
                      height: h,
                      fingerprint: d.fingerprint,
                      format: Formats.of(d.name) ?? Formats.pdf,
                      badge: Formats.labelOf(d.name),
                      issue: d.issue,
                    ),
                    progress: d.progress,
                    finished: d.finished,
                    onTap: () => _resume(context, d, 'home:${d.fingerprint}'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: Space.section),
        ],
      ],
    );
  }
}

class _RecentFiles extends ConsumerWidget {
  const _RecentFiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Recent> files = ref.watch(_filesProvider);
    if (files.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader(label: 'Recent files'),
        const SizedBox(height: Space.md),
        Reveal(
          index: 2,
          child: ListContainer(
            children: <Widget>[for (final Recent r in files) FileRow(key: ValueKey<String>(r.uri), recent: r)],
          ),
        ),
      ],
    );
  }
}

/// Until a few books have been read, ones not opened yet.
class _Suggestions extends ConsumerWidget {
  const _Suggestions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CoverGrid grid = CoverGrid.of(context);
    final bool wide = grid.columns > 3;
    // Unknown until the first answer: asking early would flash them in.
    final bool hasRecent =
        ref.watch(openedDocumentsProvider.select((AsyncValue<List<Document>> v) => v.hasValue ? null : true)) ??
        ref.watch(_readingProvider.select((List<Document> r) => r.length > (wide ? 0 : 1)));
    if (hasRecent) return const SizedBox.shrink();
    final List<BookItem> unopened = ref.watch(_unopenedProvider);
    if (unopened.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          label: 'In your library',
          action: 'Library',
          onAction: () => StatefulNavigationShell.maybeOf(context)?.goBranch(1),
        ),
        const SizedBox(height: Space.md),
        Reveal(
          index: 1,
          child: _CoverRow(
            grid: grid,
            count: math.min(unopened.length, wide ? grid.columns : 8),
            tile: (int i, double w, double h) {
              final BookItem b = unopened[i];
              final String tag = 'home:lib:${b.entry.id}';
              return Builder(
                builder: (BuildContext tileCtx) => CoverTile(
                  onLongPress: () => _bookMenu(
                    context,
                    tileCtx,
                    onOpen: () => openBook(context, b, heroTag: tag),
                    uri: b.entry.uri,
                    fingerprint: b.fingerprint,
                    title: b.title,
                    author: b.author,
                    name: b.entry.name,
                  ),
                  heroTag: tag,
                  cover: CoverArt(
                    title: b.title,
                    author: b.author,
                    width: w,
                    height: h,
                    fingerprint: b.fingerprint,
                    format: b.format,
                    badge: Formats.labelOf(b.entry.name),
                    issue: b.issue,
                  ),
                  progress: b.progress,
                  finished: b.finished,
                  onTap: () => openBook(context, b, heroTag: tag),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Space.section),
      ],
    );
  }
}

/// Folders added, nothing opened and no books found yet.
class _Hint extends ConsumerWidget {
  const _Hint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool folders = ref.watch(
      foldersProvider.select(
        (AsyncValue<List<Folder>> v) =>
            (v.value ?? const <Folder>[]).isNotEmpty && !v.value!.any((Folder f) => f.accessLost),
      ),
    );
    if (!folders ||
        ref.watch(_readingProvider.select((List<Document> r) => r.isNotEmpty)) ||
        ref.watch(_filesProvider.select((List<Recent> f) => f.isNotEmpty)) ||
        ref.watch(
          booksProvider.select(
            (AsyncValue<List<BookItem>> v) => (v.value ?? const <BookItem>[]).any((BookItem b) => b.format.book),
          ),
        )) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: Space.xxl),
      child: Text(
        'Open a book from Library, or a file with Open file. What you read shows up here.',
        style: UnfurlType.body.copyWith(color: context.colors.onSurfaceVariant),
      ),
    );
  }
}

/// A row of covers: a horizontal list of 96dp tiles on phones, one row of
/// the 5 or 7 column grid on tablets.
class _CoverRow extends StatelessWidget {
  const _CoverRow({required this.grid, required this.count, required this.tile});

  final CoverGrid grid;
  final int count;
  final Widget Function(int i, double width, double height) tile;

  @override
  Widget build(BuildContext context) {
    if (grid.columns == 3) {
      return SizedBox(
        height: 186,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: count,
          separatorBuilder: (BuildContext context, int i) => const SizedBox(width: 14),
          itemBuilder: (BuildContext context, int i) => SizedBox(width: 96, child: tile(i, 96, 136)),
        ),
      );
    }
    return SizedBox(
      height: grid.extent(50),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CoverGrid.gap,
        children: <Widget>[
          for (int i = 0; i < math.min(count, grid.columns); i++)
            SizedBox(width: grid.tile, child: tile(i, grid.tile, grid.cover)),
        ],
      ),
    );
  }
}

/// Resume: the exact passage and mode last used.
Future<void> _resume(BuildContext context, Document d, String tag) => openDocument(
  context,
  DocRef(uri: d.uri, name: d.name, size: d.size),
  at: d.position == null ? null : Locator.fromJson(d.position!),
  mode: d.mode,
  heroTag: tag,
);

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.icon,
    required this.danger,
    required this.title,
    required this.body,
    required this.action,
    required this.actionIcon,
    required this.onAction,
    super.key,
  });

  final IconData icon;
  final bool danger;
  final String title;
  final String body;
  final String action;
  final IconData actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.section),
      child: SurfaceCard(
        hero: true,
        padding: const EdgeInsets.all(Space.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 14,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: danger ? c.dangerContainer : c.primaryContainer,
                    borderRadius: Radii.thumbR,
                  ),
                  child: AppIcon(icon, color: danger ? c.onDangerContainer : c.onPrimaryContainer),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: <Widget>[
                      Text(title, style: UnfurlType.titleMedium.copyWith(fontSize: 17, color: c.onSurface)),
                      Text(body, style: UnfurlType.note.copyWith(height: 1.55, color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            AppButton(label: action, icon: actionIcon, height: 48, onPressed: onAction),
          ],
        ),
      ),
    );
  }
}

/// Board 1 ContinueHeroCard, at Home's size.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.doc});

  final Document doc;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final String title = doc.title ?? HomeScreen._stem(doc.name);
    // The percentage sits beside the track; this line is the place in words.
    final String where = doc.where ?? (doc.progress > 0 ? '' : 'Not started');
    return SurfaceCard(
      hero: true,
      padding: const EdgeInsets.all(Space.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.lg,
        children: <Widget>[
          const SectionHeader(label: 'Continue reading', accent: true),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Space.lg,
              children: <Widget>[
                Hero(
                  tag: 'hero:${doc.fingerprint}',
                  child: CoverArt(
                    title: title,
                    author: doc.author,
                    fingerprint: doc.fingerprint,
                    format: Formats.of(doc.name) ?? Formats.pdf,
                    width: 84,
                    height: 120,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: UnfurlType.title.copyWith(color: c.onSurface),
                      ),
                      if (doc.author != null)
                        Text(doc.author!, style: UnfurlType.note.copyWith(height: 1.4, color: c.onSurfaceVariant)),
                      const Spacer(),
                      if (where.isNotEmpty)
                        Text(
                          where,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UnfurlType.monoLabel.copyWith(height: 1.4, color: c.onSurfaceVariant),
                        ),
                      Row(
                        spacing: Space.sm,
                        children: <Widget>[
                          Expanded(child: ProgressTrack(value: doc.progress, height: 4)),
                          Text(
                            '${(doc.progress * 100).round()}%',
                            style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppButton(
            label: 'Resume',
            icon: AppIcons.play,
            onPressed: () => _resume(context, doc, 'hero:${doc.fingerprint}'),
          ),
        ],
      ),
    );
  }
}

/// A recent file: its format icon on a 40dp tile, name, "DOCX · 2.1 MB ·
/// Yesterday".
class FileRow extends StatelessWidget {
  const FileRow({required this.recent, super.key});

  final Recent recent;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final FormatModule? m = Formats.of(recent.name, recent.mime);
    return MergeSemantics(
      child: PressableRow(
        onTap: () =>
            openDocument(context, DocRef(uri: recent.uri, name: recent.name, size: recent.size, mime: recent.mime)),
        onLongPress: () => _fileMenu(context, recent),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
          child: Row(
            spacing: 14,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(Space.md)),
                child: AppIcon(m?.icon ?? AppIcons.description, size: 22, color: c.icon),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      recent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UnfurlType.titleMedium.copyWith(color: c.onSurface),
                    ),
                    Text(
                      <String>[
                        Formats.labelOf(recent.name),
                        if (recent.size > 0) Files.size(recent.size),
                        Files.when(recent.openedAt.millisecondsSinceEpoch),
                      ].join(' · '),
                      style: UnfurlType.monoLabel.copyWith(height: 1.5, color: c.onSurfaceVariant),
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

/// A recent file's menu (long press): Open, Share file, Remove from Recents.
Future<void> _fileMenu(BuildContext context, Recent recent) async {
  final Library library = ProviderScope.containerOf(context).read(libraryProvider);
  final String? v = await showAppMenu<String>(
    context: context,
    anchorContext: context,
    entries: const <AppMenuEntry<String>>[
      AppMenuEntry<String>(value: 'open', label: 'Open', icon: AppIcons.menuBook),
      AppMenuEntry<String>(value: 'share', label: 'Share file', icon: AppIcons.share),
      AppMenuEntry<String>.divider(),
      AppMenuEntry<String>(value: 'remove', label: 'Remove from Recents', icon: AppIcons.removeCircle),
    ],
  );
  if (!context.mounted) return;
  switch (v) {
    case 'open':
      await openDocument(context, DocRef(uri: recent.uri, name: recent.name, size: recent.size, mime: recent.mime));
    case 'share':
      await Platform.shareFile(recent.uri, recent.mime);
    case 'remove':
      await library.forgetRecent(recent.uri);
  }
}

/// Opens a recent or an index row from anywhere (shared by Folder screens).
void openRef(BuildContext context, DocRef ref) => unawaited(openDocument(context, ref));

/// A book's menu on Home (long-press): Open, Share file, Insights.
Future<void> _bookMenu(
  BuildContext context,
  BuildContext anchor, {
  required VoidCallback onOpen,
  required String uri,
  required String title,
  required String name,
  String? fingerprint,
  String? author,
}) async {
  final String? v = await showAppMenu<String>(
    context: context,
    anchorContext: anchor,
    entries: const <AppMenuEntry<String>>[
      AppMenuEntry<String>(value: 'open', label: 'Open', icon: AppIcons.menuBook),
      AppMenuEntry<String>(value: 'share', label: 'Share file', icon: AppIcons.share),
      kInsightsEntry,
    ],
  );
  if (!context.mounted) return;
  switch (v) {
    case 'open':
      onOpen();
    case 'share':
      await Platform.shareFile(uri, null);
    case 'insights':
      await showInsightsFor(context, uri: uri, fingerprint: fingerprint, title: title, author: author, name: name);
  }
}
