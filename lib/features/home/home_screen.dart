import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/files.dart';
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
    final List<Folder> folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final bool foldersLoaded = ref.watch(foldersProvider).hasValue;
    final List<Document> opened = ref.watch(openedDocumentsProvider).value ?? const <Document>[];
    final List<Recent> recents = ref.watch(recentsProvider).value ?? const <Recent>[];
    final List<BookItem> books = ref.watch(booksProvider).value ?? const <BookItem>[];
    final List<Folder> lost = folders.where((Folder f) => f.accessLost).toList();

    final List<Document> reading = opened
        .where((Document d) => (d.format == 'pdf' || d.format == 'epub') && !d.finished)
        .toList();
    final Document? hero = reading.firstOrNull;
    final List<Document> recentBooks = reading.skip(1).take(8).toList();
    // Until a few books have been read, suggest ones not opened yet.
    final List<BookItem> unopened = books.where((BookItem b) => b.doc == null).toList();
    final List<Recent> files = recents
        .where((Recent r) {
          final FormatModule? m = Formats.of(r.name, r.mime);
          return m != null && !m.book;
        })
        .take(5)
        .toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CollapseOnScroll(
          builder: (BuildContext context, bool collapsed) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppHeader(
                title: greeting(DateTime.now()),
                collapsed: collapsed,
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
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, Space.bottomSafe),
                  children: <Widget>[
                    if (foldersLoaded && folders.isEmpty)
                      _FolderCard(
                        icon: AppIcons.folder,
                        danger: false,
                        title: 'Add a folder to fill your Library',
                        body: 'Unfurl lists the books and documents in folders you choose. It only reads them.',
                        action: 'Add folder',
                        actionIcon: AppIcons.createNewFolder,
                        onAction: () => addFolder(context, ref),
                      ),
                    for (final Folder f in lost)
                      _FolderCard(
                        icon: AppIcons.folderOff,
                        danger: true,
                        title: 'Unfurl can’t see ${f.name} anymore',
                        body: f.source == 'saf_folder'
                            ? 'Access was removed by Android. Your progress, highlights and notes are kept.'
                            : 'All files access was turned off. Your progress, highlights and notes are kept.',
                        action: f.source == 'saf_folder' ? 'Grant access again' : 'Go to Files',
                        actionIcon: AppIcons.folderOpen,
                        onAction: () => regrantFolder(context, ref, f),
                      ),
                    if (hero != null) ...<Widget>[
                      Reveal(
                        child: _HeroCard(doc: hero, books: books),
                      ),
                      const SizedBox(height: Space.section),
                    ],
                    if (recentBooks.isNotEmpty) ...<Widget>[
                      SectionHeader(
                        label: 'Recent books',
                        action: 'Library',
                        onAction: () => StatefulNavigationShell.maybeOf(context)?.goBranch(1),
                      ),
                      const SizedBox(height: Space.md),
                      Reveal(
                        index: 1,
                        child: SizedBox(
                          height: 186,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            itemCount: recentBooks.length,
                            separatorBuilder: (BuildContext context, int i) => const SizedBox(width: 14),
                            itemBuilder: (BuildContext context, int i) {
                              final Document d = recentBooks[i];
                              return SizedBox(
                                width: 96,
                                child: CoverTile(
                                  heroTag: 'home:${d.fingerprint}',
                                  cover: CoverArt(
                                    title: d.title ?? _stem(d.name),
                                    author: d.author,
                                    fingerprint: d.fingerprint,
                                    format: Formats.of(d.name) ?? Formats.pdf,
                                  ),
                                  progress: d.progress,
                                  finished: d.finished,
                                  onTap: () => _resume(context, d, 'home:${d.fingerprint}'),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.section),
                    ],
                    if (files.isNotEmpty) ...<Widget>[
                      const SectionHeader(label: 'Recent files'),
                      const SizedBox(height: Space.md),
                      Reveal(
                        index: 2,
                        child: ListContainer(children: <Widget>[for (final Recent r in files) FileRow(recent: r)]),
                      ),
                    ],
                    if (recentBooks.isEmpty && unopened.isNotEmpty) ...<Widget>[
                      SectionHeader(
                        label: 'In your library',
                        action: 'Library',
                        onAction: () => StatefulNavigationShell.maybeOf(context)?.goBranch(1),
                      ),
                      const SizedBox(height: Space.md),
                      Reveal(
                        index: 1,
                        child: SizedBox(
                          height: 186,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            itemCount: math.min(unopened.length, 8),
                            separatorBuilder: (BuildContext context, int i) => const SizedBox(width: 14),
                            itemBuilder: (BuildContext context, int i) {
                              final BookItem b = unopened[i];
                              final String tag = 'home:lib:${b.entry.id}';
                              return SizedBox(
                                width: 96,
                                child: CoverTile(
                                  heroTag: tag,
                                  cover: CoverArt(
                                    title: b.title,
                                    author: b.author,
                                    fingerprint: b.fingerprint,
                                    format: b.format,
                                  ),
                                  progress: b.progress,
                                  finished: b.finished,
                                  onTap: () => openBook(context, b, heroTag: tag),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.section),
                    ],
                    if (hero == null && files.isEmpty && books.isEmpty && folders.isNotEmpty && lost.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.xxl),
                        child: Text(
                          'Open a book from Library, or a file with Open file. What you read shows up here.',
                          style: UnfurlType.body.copyWith(color: context.colors.onSurfaceVariant),
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

  static String _stem(String n) => n.contains('.') ? n.substring(0, n.lastIndexOf('.')) : n;
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
  const _HeroCard({required this.doc, required this.books});

  final Document doc;
  final List<BookItem> books;

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
          Builder(
            builder: (BuildContext context) =>
                _ResumeButton(onTap: () => _resume(context, doc, 'hero:${doc.fingerprint}')),
          ),
        ],
      ),
    );
  }
}

class _ResumeButton extends StatelessWidget {
  const _ResumeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Semantics(
      button: true,
      label: 'Resume',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: c.primary,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: Space.sm,
              children: <Widget>[
                AppIcon(AppIcons.play, fill: true, size: 20, color: c.onPrimary),
                Text('Resume', style: UnfurlType.titleMedium.copyWith(color: c.onPrimary)),
              ],
            ),
          ),
        ),
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
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () =>
            openDocument(context, DocRef(uri: recent.uri, name: recent.name, size: recent.size, mime: recent.mime)),
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

/// Opens a recent or an index row from anywhere (shared by Folder screens).
void openRef(BuildContext context, DocRef ref) => unawaited(openDocument(context, ref));
