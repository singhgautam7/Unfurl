import 'dart:async';

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

/// The Folders list (See all): every granted folder, its path and readable
/// count; the x removes access after an undo strip; Add folder floats.
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final Set<int> removing = ref.watch(_removingProvider);
    final List<Folder> folders = (ref.watch(foldersProvider).value ?? const <Folder>[])
        .where((Folder f) => !removing.contains(f.id))
        .toList();
    final Map<int, int> counts = ref.watch(readableCountsProvider).value ?? const <int, int>{};
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(title: 'Folders', onBack: () => context.pop()),
                Expanded(
                  child: folders.isEmpty
                      ? const EmptyState(
                          icon: AppIcons.folder,
                          title: 'No folders yet',
                          message: 'Pick a folder and Unfurl lists what it can open inside it, including subfolders. It only reads them.',
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(Space.screen, Space.xs, Space.screen, Space.bottomSafe),
                          children: <Widget>[
                            Container(
                              decoration: BoxDecoration(
                                color: c.surfaceContainer,
                                borderRadius: Radii.cardR,
                                border: Border.all(color: c.outline),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: <Widget>[
                                  for (int i = 0; i < folders.length; i++) ...<Widget>[
                                    if (i > 0) Divider(color: c.divider),
                                    _FolderRow(
                                      name: folders[i].name,
                                      meta: folders[i].accessLost
                                          ? 'Access lost'
                                          : '${folders[i].path.isEmpty ? folders[i].name : folders[i].path} · ${readableFiles(counts[folders[i].id] ?? 0)}',
                                      danger: folders[i].accessLost,
                                      trailing: AppIcons.close,
                                      trailingLabel: 'Remove access to ${folders[i].name}',
                                      onTap: () => context.push(Routes.folder(folders[i].id)),
                                      onTrailing: () {
                                        final Folder f = folders[i];
                                        ref.read(libraryProvider).removeWithUndo(f);
                                        AppSnackbar.undo(
                                          context,
                                          'Removed ${f.name}. The folder itself is untouched.',
                                          () => ref.read(libraryProvider).undoRemove(f.id),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 28,
              child: Center(
                child: Material(
                  color: c.primary,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => addFolderFlow(context, ref),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.xl, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: Space.sm,
                        children: <Widget>[
                          AppIcon(AppIcons.createNewFolder, color: c.onPrimary),
                          Flexible(
                            child: Text(
                              'Add folder',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: UnfurlType.body.copyWith(height: 1, color: c.onPrimary).weight(600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack, this.crumb, this.onCrumb, this.actions = const <Widget>[]});

  final String title;
  final VoidCallback onBack;
  final String? crumb;
  final VoidCallback? onCrumb;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, 14, Space.sm),
        child: Row(
          spacing: Space.xs,
          children: <Widget>[
            AppIconButton(icon: AppIcons.back, semanticLabel: 'Back', onPressed: onBack),
            Expanded(
              child: Semantics(
                button: onCrumb != null,
                label: crumb == null ? title : '$title, in $crumb',
                excludeSemantics: true,
                child: InkWell(
                  onTap: onCrumb,
                  borderRadius: Radii.chipR,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.only(left: Space.xs),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (crumb != null)
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    crumb!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                                  ),
                                ),
                                AppIcon(AppIcons.expandMore, size: 16, color: c.onSurfaceVariant),
                              ],
                            ),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: UnfurlType.headerTitle.copyWith(color: c.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.name,
    required this.meta,
    required this.onTap,
    this.muted = false,
    this.danger = false,
    this.trailing = AppIcons.chevronRight,
    this.trailingLabel,
    this.onTrailing,
  });

  final String name;
  final String meta;
  final bool muted;
  final bool danger;
  final IconData trailing;
  final String? trailingLabel;
  final VoidCallback onTap;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 6, Space.xs, 6),
          child: Row(
            spacing: 14,
            children: <Widget>[
              AppIcon(danger ? AppIcons.folderOff : AppIcons.folder, color: c.icon),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UnfurlType.titleMedium.copyWith(color: muted ? c.onSurfaceVariant : c.onSurface),
                    ),
                    Text(
                      meta,
                      style: UnfurlType.monoLabel.copyWith(
                        height: 1.5,
                        color: danger ? c.danger : c.onSurfaceVariant,
                        fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTrailing != null)
                AppIconButton(
                  icon: trailing,
                  filled: false,
                  tint: c.iconMuted,
                  semanticLabel: trailingLabel ?? '',
                  onPressed: onTrailing,
                )
              else
                SizedBox.square(
                  dimension: IconSpec.tapTarget,
                  child: Center(child: AppIcon(trailing, color: c.iconMuted)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _FolderSort { name, modified, size }

/// A folder at any depth (A6): subfolders first, then files; search scoped
/// here; type chips for what is present; Include subfolders; Show all files.
class FolderScreen extends ConsumerStatefulWidget {
  const FolderScreen({required this.folderId, required this.path, super.key});

  final int folderId;

  /// Relative path inside the granted folder, '' at its root.
  final String path;

  @override
  ConsumerState<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends ConsumerState<FolderScreen> {
  FormatGroup? _group;
  bool _deep = false;
  bool _showAll = false;
  String _query = '';
  _FolderSort _sort = _FolderSort.name;
  late bool _grid = ref.read(settingsProvider.notifier).folderGrid('${widget.folderId}/${widget.path}');
  Map<String, (int, int)> _counts = const <String, (int, int)>{};
  StreamSubscription<List<(Entry, Document?)>>? _sub;
  List<(Entry, Document?)> _entries = const <(Entry, Document?)>[];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _watch() {
    unawaited(_sub?.cancel());
    _sub = ref.read(libraryProvider).watchLevel(widget.folderId, widget.path, deep: _deep).listen((
      List<(Entry, Document?)> rows,
    ) async {
      final Map<String, (int, int)> counts = await ref.read(libraryProvider).countsUnder(widget.folderId);
      if (mounted) {
        setState(() {
          _entries = rows;
          _counts = counts;
          _loaded = true;
        });
      }
    });
  }

  String get _name => widget.path.isEmpty ? '' : widget.path.split('/').last;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final List<Folder> folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final Folder? folder = folders.where((Folder f) => f.id == widget.folderId).firstOrNull;
    final ScanState? scan = ref.watch(_scansProvider)[widget.folderId];
    if (folder == null) return const Scaffold();
    final String title = widget.path.isEmpty ? folder.name : _name;
    final List<String> parts = <String>[folder.name, if (widget.path.isNotEmpty) ...widget.path.split('/')];
    final List<String> ancestors = parts.sublist(0, parts.length - 1);
    final String? crumb = ancestors.isEmpty
        ? null
        : (ancestors.length > 2 ? '… › ${ancestors.sublist(ancestors.length - 2).join(' › ')}' : ancestors.join(' › '));

    final List<Entry> subdirs = _deep
        ? const <Entry>[]
        : (_entries.where(((Entry, Document?) e) => e.$1.isDir).map(((Entry, Document?) e) => e.$1).toList()
            ..sort((Entry a, Entry b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
    final List<(Entry, Document?)> files = _entries.where(((Entry, Document?) e) => !e.$1.isDir).toList();
    final Set<FormatGroup> present = <FormatGroup>{
      for (final (Entry e, Document? _) in files) ?Formats.of(e.name, e.mime)?.group,
    };
    final int unreadable = files.where(((Entry, Document?) e) => Formats.of(e.$1.name, e.$1.mime) == null).length;
    List<(Entry, Document?)> shown = files.where(((Entry, Document?) e) {
      final FormatModule? m = Formats.of(e.$1.name, e.$1.mime);
      if (m == null && !_showAll) return false;
      if (_group != null && m?.group != _group) return false;
      if (_query.isNotEmpty && !e.$1.name.toLowerCase().contains(_query.toLowerCase())) return false;
      return true;
    }).toList();
    shown = <(Entry, Document?)>[...shown]
      ..sort(
        ((Entry, Document?) a, (Entry, Document?) b) => switch (_sort) {
          _FolderSort.name => a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase()),
          _FolderSort.modified => b.$1.modified.compareTo(a.$1.modified),
          _FolderSort.size => b.$1.size.compareTo(a.$1.size),
        },
      );
    final List<Entry> shownDirs = _query.isEmpty
        ? subdirs
        : subdirs.where((Entry d) => d.name.toLowerCase().contains(_query.toLowerCase())).toList();
    final int folderCount = <String>{for (final (Entry e, Document? _) in shown) e.parent}.length;

    Widget body;
    if (folder.accessLost) {
      body = EmptyState(
        icon: AppIcons.folderOff,
        tone: EmptyTone.danger,
        small: true,
        title: 'Unfurl lost access to ${folder.name}',
        message: 'Android removed access, which can happen after a backup restore or a storage change. Your progress and notes are kept.',
        actions: <Widget>[
          AppButton(
            label: 'Grant access again',
            icon: AppIcons.folderOpen,
            onPressed: () => regrantFolder(context, ref),
          ),
          AppButton(
            label: 'Remove folder',
            type: AppButtonType.secondary,
            onPressed: () async {
              await ref.read(libraryProvider).removeFolder(folder);
              if (context.mounted) context.pop();
            },
          ),
        ],
      );
    } else if (_loaded && files.isEmpty && subdirs.isEmpty && scan == null) {
      body = EmptyState(
        icon: AppIcons.folderOpen,
        tone: EmptyTone.neutral,
        small: true,
        title: 'This folder is empty',
        message: 'Anything saved to $title will show up here.',
      );
    } else if (_loaded && !_showAll && unreadable == files.length && files.isNotEmpty && subdirs.isEmpty) {
      body = EmptyState(
        icon: AppIcons.visibilityOff,
        tone: EmptyTone.neutral,
        small: true,
        title: 'Nothing here Unfurl can open',
        message: '$title has ${files.length} ${files.length == 1 ? 'file' : 'files'}, none in a format Unfurl reads.',
        actions: <Widget>[
          AppButton(
            label: 'Show all files',
            icon: AppIcons.visibility,
            onPressed: () => setState(() => _showAll = true),
          ),
        ],
      );
    } else {
      body = CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.screen, Space.xs, Space.screen, 14),
            sliver: SliverToBoxAdapter(
              child: SearchField(hint: 'Search in $title', onChanged: (String q) => setState(() => _query = q.trim())),
            ),
          ),
          SliverToBoxAdapter(
            child: ChipRow(
              children: <Widget>[
                PillChip(label: 'All', selected: _group == null, onTap: () => setState(() => _group = null)),
                for (final FormatGroup g in FormatGroup.values)
                  if (present.contains(g))
                    PillChip(
                      label: g.label,
                      selected: _group == g,
                      onTap: () => setState(() => _group = _group == g ? null : g),
                    ),
                PillChip(
                  label: 'Include subfolders',
                  toggle: true,
                  selected: _deep,
                  leading: AppIcon(_deep ? AppIcons.check : AppIcons.accountTree),
                  onTap: () => setState(() {
                    _deep = !_deep;
                    _watch();
                  }),
                ),
              ],
            ),
          ),
          if (scan != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 14, Space.screen, 0),
              sliver: SliverToBoxAdapter(
                child: _ScanCard(name: folder.name, scan: scan),
              ),
            ),
          if (shownDirs.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 14, Space.screen, 0),
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
                      for (int i = 0; i < shownDirs.length; i++) ...<Widget>[
                        if (i > 0) Divider(color: c.divider),
                        Builder(
                          builder: (BuildContext context) {
                            final String path = widget.path.isEmpty
                                ? shownDirs[i].name
                                : '${widget.path}/${shownDirs[i].name}';
                            final (int readable, int _) = _counts[path] ?? (0, 0);
                            return _FolderRow(
                              name: shownDirs[i].name,
                              meta: scan != null && !_counts.containsKey(path)
                                  ? 'Counting…'
                                  : (readable == 0
                                        ? 'No readable files'
                                        : '$readable readable ${readable == 1 ? 'file' : 'files'}'),
                              muted: readable == 0,
                              onTap: () => context.push(Routes.folder(widget.folderId, path: path)),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
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
                      scan != null
                          ? 'Found so far'
                          : _deep
                          ? '${shown.length} ${shown.length == 1 ? 'file' : 'files'} in $folderCount ${folderCount == 1 ? 'folder' : 'folders'}'
                          : _showAll && unreadable > 0
                          ? '${shown.length} files · $unreadable can’t be opened'
                          : '${shown.length} ${shown.length == 1 ? 'file' : 'files'}${subdirs.isEmpty ? '' : ' here'}',
                      style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    'Sort: ${switch (_sort) {
                      _FolderSort.name => 'Name',
                      _FolderSort.modified => 'Modified',
                      _FolderSort.size => 'Size',
                    }}',
                    style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.bottomSafe),
            sliver: _grid
                ? SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      // Rows fit their tiles: books carry a track, other
                      // files a name line.
                      mainAxisExtent:
                          shown.any(((Entry, Document?) e) => !(Formats.of(e.$1.name, e.$1.mime)?.book ?? false))
                          ? 188
                          : 170,
                      mainAxisSpacing: 18,
                    ),
                    itemCount: shown.length,
                    itemBuilder: (BuildContext context, int i) => Align(
                      alignment: <Alignment>[Alignment.topLeft, Alignment.topCenter, Alignment.topRight][i % 3],
                      child: SizedBox(
                        width: 96,
                        child: Reveal(index: i < 9 ? i : 0, child: _tile(shown[i])),
                      ),
                    ),
                  )
                : SliverToBoxAdapter(
                    child: shown.isEmpty
                        ? const SizedBox.shrink()
                        : Container(
                            decoration: BoxDecoration(
                              color: c.surfaceContainer,
                              borderRadius: Radii.cardR,
                              border: Border.all(color: c.outline),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: <Widget>[
                                for (int i = 0; i < shown.length; i++) ...<Widget>[
                                  if (i > 0) Divider(color: c.divider),
                                  Reveal(index: i < 9 ? i : 0, child: _row(shown[i])),
                                ],
                              ],
                            ),
                          ),
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(
              title: title,
              crumb: crumb,
              onCrumb: crumb == null ? null : () => _pathSheet(folder, parts),
              onBack: () => context.pop(),
              actions: <Widget>[
                if (!folder.accessLost)
                  AppIconButton(
                    icon: _grid ? AppIcons.viewList : AppIcons.gridView,
                    semanticLabel: _grid ? 'Show as list' : 'Show as grid',
                    onPressed: () {
                      setState(() => _grid = !_grid);
                      unawaited(
                        ref
                            .read(settingsProvider.notifier)
                            .setFolderGrid('${widget.folderId}/${widget.path}', grid: _grid),
                      );
                    },
                  ),
                if (!folder.accessLost)
                  Builder(
                    builder: (BuildContext b) => AppIconButton(
                      icon: AppIcons.moreHoriz,
                      semanticLabel: 'Sort and show',
                      onPressed: () => _menu(b),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                child: KeyedSubtree(key: ValueKey<Object>('${_grid}_${_group}_${_deep}_$_showAll'), child: body),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile((Entry, Document?) e) {
    final Entry entry = e.$1;
    final Document? doc = e.$2;
    final FormatModule? m = Formats.of(entry.name, entry.mime);
    final String meta = '${Files.size(entry.size)} · ${Files.when(entry.modified)}';
    if (m != null && m.book) {
      final double progress = doc?.progress ?? 0;
      return CoverTile(
        cover: CoverArt(
          title: doc?.title ?? entry.title ?? _stem(entry.name),
          author: doc?.author ?? entry.author,
          fingerprint: entry.fingerprint,
          format: m,
        ),
        progress: progress,
        finished: doc?.finished ?? false,
        meta:
            '${m.label} · ${doc == null || progress <= 0 ? 'New' : (doc.finished ? 'Finished' : '${(progress * 100).round()}%')}',
        onTap: () => _open(entry, doc),
      );
    }
    return CoverTile(
      cover: FormatTile(
        label: m?.label ?? Formats.labelOf(entry.name),
        icon: m?.icon ?? AppIcons.description,
        muted: m == null,
      ),
      progress: 0,
      finished: false,
      name: _stem(entry.name),
      meta: meta,
      onTap: () => _open(entry, doc),
    );
  }

  Widget _row((Entry, Document?) e) {
    final UnfurlColors c = context.colors;
    final Entry entry = e.$1;
    final FormatModule? m = Formats.of(entry.name, entry.mime);
    final bool muted = m == null;
    final String rel = widget.path.isEmpty
        ? entry.parent
        : (entry.parent.length > widget.path.length ? entry.parent.substring(widget.path.length + 1) : '');
    return InkWell(
      onTap: () => _open(entry, e.$2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 10),
        child: Row(
          spacing: 14,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: muted ? Colors.transparent : c.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(Space.md),
                border: muted ? Border.all(color: c.outline) : null,
              ),
              child: AppIcon(m?.icon ?? _unknownIcon(entry.name), size: 22, color: muted ? c.onSurfaceVariant : c.icon),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UnfurlType.titleMedium
                        .copyWith(color: muted ? c.onSurfaceVariant : c.onSurface)
                        .weight(muted ? 500 : 600),
                  ),
                  Text(
                    '${m?.label ?? Formats.labelOf(entry.name)} · ${Files.size(entry.size)} · ${Files.when(entry.modified)}',
                    style: UnfurlType.monoLabel.copyWith(height: 1.5, color: c.onSurfaceVariant),
                  ),
                  if (_deep && rel.isNotEmpty)
                    Row(
                      spacing: 4,
                      children: <Widget>[
                        AppIcon(AppIcons.subdirectory, size: 14, color: c.accent),
                        Flexible(
                          child: Text(
                            rel.replaceAll('/', ' › '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: UnfurlType.monoLabel.copyWith(fontSize: 10.5, color: c.accent),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _unknownIcon(String name) {
    final String ext = name.contains('.') ? name.substring(name.lastIndexOf('.') + 1).toLowerCase() : '';
    return switch (ext) {
      'zip' || 'rar' || '7z' || 'tar' || 'gz' => AppIcons.folderZip,
      'r' || 'py' || 'js' || 'dart' || 'json' || 'html' || 'css' || 'java' || 'kt' => AppIcons.code,
      _ => AppIcons.description,
    };
  }

  static String _stem(String n) => n.contains('.') ? n.substring(0, n.lastIndexOf('.')) : n;

  void _open(Entry entry, Document? doc) {
    final DocRef ref = DocRef(
      uri: entry.uri,
      name: entry.name,
      size: entry.size,
      modified: entry.modified,
      mime: entry.mime,
    );
    unawaited(
      openDocument(context, ref, at: doc?.position == null ? null : Locator.fromJson(doc!.position!), mode: doc?.mode),
    );
  }

  Future<void> _menu(BuildContext anchor) async {
    final String? v = await showAppMenu<String>(
      context: context,
      anchorContext: anchor,
      entries: <AppMenuEntry<String>>[
        AppMenuEntry<String>(
          value: 'name',
          label: 'Sort: Name',
          icon: AppIcons.sortByAlpha,
          selected: _sort == _FolderSort.name,
        ),
        AppMenuEntry<String>(
          value: 'modified',
          label: 'Sort: Modified',
          icon: AppIcons.schedule,
          selected: _sort == _FolderSort.modified,
        ),
        AppMenuEntry<String>(
          value: 'size',
          label: 'Sort: Size',
          icon: AppIcons.straighten,
          selected: _sort == _FolderSort.size,
        ),
        const AppMenuEntry<String>.divider(),
        AppMenuEntry<String>(
          value: 'all',
          label: _showAll ? 'Hide files Unfurl can’t open' : 'Show all files',
          icon: _showAll ? AppIcons.visibilityOff : AppIcons.visibility,
          subtitle: _showAll ? null : 'includes files Unfurl can’t open',
        ),
      ],
    );
    if (!mounted || v == null) return;
    setState(() {
      switch (v) {
        case 'all':
          _showAll = !_showAll;
        case 'modified':
          _sort = _FolderSort.modified;
        case 'size':
          _sort = _FolderSort.size;
        default:
          _sort = _FolderSort.name;
      }
    });
  }

  /// "Go to folder": every level from the granted root, this one marked.
  Future<void> _pathSheet(Folder folder, List<String> parts) => showReaderSheet<void>(context, (BuildContext ctx) {
    final UnfurlColors c = ctx.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 2,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: Text('Go to folder', style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
        ),
        for (int i = 0; i < parts.length; i++)
          Builder(
            builder: (BuildContext context) {
              final bool here = i == parts.length - 1;
              final String path = parts.sublist(1, i + 1).join('/');
              final (int readable, int _) = _counts[path] ?? (0, 0);
              return Material(
                color: here ? c.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(Space.lg),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Space.lg),
                  onTap: here
                      ? () => Navigator.of(ctx).pop()
                      : () {
                          Navigator.of(ctx).pop();
                          // Pop back to that level: one route per level.
                          for (int k = 0; k < parts.length - 1 - i; k++) {
                            context.pop();
                          }
                        },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 6),
                      child: Row(
                        spacing: 14,
                        children: <Widget>[
                          AppIcon(
                            here ? AppIcons.folderOpen : AppIcons.folder,
                            color: here ? c.onPrimaryContainer : c.icon,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                parts[i],
                                style: UnfurlType.titleMedium.copyWith(
                                  color: here ? c.onPrimaryContainer : c.onSurface,
                                ),
                              ),
                              Text(
                                here ? 'You are here' : (i == 0 ? 'Granted folder' : readableFiles(readable)),
                                style: UnfurlType.monoLabel.copyWith(
                                  height: 1.5,
                                  color: here ? c.onPrimaryContainer : c.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  });
}

final Provider<Set<int>> _removingProvider = Provider<Set<int>>((Ref ref) {
  final Library lib = ref.watch(libraryProvider);
  void listener() => ref.invalidateSelf();
  lib.removing.addListener(listener);
  ref.onDispose(() => lib.removing.removeListener(listener));
  return lib.removing.value;
});

final Provider<Map<int, ScanState>> _scansProvider = Provider<Map<int, ScanState>>((Ref ref) {
  final Library lib = ref.watch(libraryProvider);
  void listener() => ref.invalidateSelf();
  lib.scans.addListener(listener);
  ref.onDispose(() => lib.scans.removeListener(listener));
  return lib.scans.value;
});

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.name, required this.scan});

  final String name;
  final ScanState scan;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final bool known = scan.expected > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.cardR,
        border: Border.all(color: c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.sm,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text('Scanning $name', style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
              ),
              Text(
                known ? '${scan.found} of about ${scan.expected}' : '${scan.found} found',
                style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ),
          if (known)
            ProgressTrack(value: (scan.found / scan.expected).clamp(0, 1))
          else
            const LoadingHairline(visible: true),
          Text(
            'Results appear as they’re found. Anything listed can be opened now.',
            style: UnfurlType.bodySmall.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
