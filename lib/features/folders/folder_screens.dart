import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:isolate';

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
import '../files/file_sheets.dart';
import '../files/files_screen.dart';
import '../files/files_widgets.dart';
import '../reader/sheets.dart';
import '../settings/settings_controller.dart';

/// The Folders list (See all): every granted folder, its path and readable
/// count; the x removes access after an undo strip; Add folder floats.
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({this.base = '', super.key});

  /// The stack it lives in: '/library', '/files' or '' (above the tabs).
  final String base;

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
                                      onTap: () => context.push(Routes.folder(folders[i].id, base: base)),
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
                    onTap: () => addFolder(context, ref),
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
  const _Header({
    required this.title,
    required this.onBack,
    this.crumb,
    this.onCrumb,
    this.actions = const <Widget>[],
    this.backIcon = AppIcons.back,
  });

  final String title;
  final IconData backIcon;
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
            AppIconButton(
              icon: backIcon,
              semanticLabel: backIcon == AppIcons.close ? 'Close' : 'Back',
              onPressed: onBack,
            ),
            Expanded(
              child: Semantics(
                button: onCrumb != null,
                label: crumb == null ? title : '$title, in $crumb',
                onTap: onCrumb,
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
                      style: UnfurlType.monoLabel.copyWith(height: 1.5, color: danger ? c.danger : c.onSurfaceVariant),
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

/// Where a folder screen's contents come from and what it may do.
enum FolderMode {
  /// A folder added to the library (A6): its indexed contents.
  library,

  /// Files (X4): any folder on the phone, every file, read-only actions.
  explorer,

  /// "Choose this folder" (X8): browse to a folder and add it to Library.
  picker,
}

/// One entry, whichever source it came from.
@immutable
class _Item {
  const _Item({
    required this.name,
    required this.isDir,
    required this.uri,
    this.size = 0,
    this.modified = 0,
    this.mime,
    this.rel = '',
    this.doc,
    this.fingerprint,
    this.title,
    this.author,
    this.path = '',
  });

  final String name;
  final bool isDir;
  final String uri;
  final int size;
  final int modified;
  final String? mime;

  /// Its directory relative to the screen's folder (Include subfolders).
  final String rel;
  final Document? doc;
  final String? fingerprint;
  final String? title;
  final String? author;

  /// Library: the path within the granted folder. Explorer: the full path.
  final String path;

  bool get hidden => name.startsWith('.');
  FormatModule? get format => Formats.of(name, mime);
}

/// A folder at any depth (A6, and X4/X8 in v2): subfolders first, then
/// files; search scoped here; type chips for what is present; Include
/// subfolders. In Files it lists every file (those Unfurl can't open are
/// muted), streams large folders, and offers read-only file actions; in the
/// picker it lists what Unfurl reads and adds the folder to Library.
class FolderScreen extends ConsumerStatefulWidget {
  const FolderScreen({required int this.folderId, required this.path, this.base = '', super.key})
    : root = '',
      mode = FolderMode.library;

  const FolderScreen.explorer({required this.root, required this.mode, super.key})
    : folderId = null,
      path = '',
      base = Routes.files;

  final int? folderId;

  /// Library: relative path inside the granted folder, '' at its root.
  final String path;

  /// The stack it lives in: '/library', '/files' or '' (above the tabs).
  final String base;

  /// Explorer and picker: the folder's full path.
  final String root;
  final FolderMode mode;

  @override
  ConsumerState<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends ConsumerState<FolderScreen> {
  FormatGroup? _group;

  /// The "Other" chip: files Unfurl can't open (Files only).
  bool _other = false;
  bool _deep = false;
  bool _showAll = false;
  String _query = '';

  /// name, modified, size or type.
  String _sort = 'name';
  late bool _grid = widget.mode == FolderMode.picker ? false : ref.read(settingsProvider.notifier).folderGrid(_gridKey);

  // Library.
  Map<String, (int, int)> _counts = const <String, (int, int)>{};
  StreamSubscription<List<(Entry, Document?)>>? _sub;
  List<(Entry, Document?)> _entries = const <(Entry, Document?)>[];
  bool _loaded = false;

  // Explorer and picker.
  DirListing? _listing;
  late bool _hidden = _hiddenFor(widget.root) ?? ref.read(settingsProvider).showHidden;
  final Map<String, (int, int, int)?> _summaries = <String, (int, int, int)?>{};
  Map<String, Document> _docs = const <String, Document>{};
  List<_Item>? _deepItems;

  /// Books on screen in Files, fingerprinted one at a time so a cover and
  /// progress Unfurl already has can show (path to fingerprint and document).
  final Map<String, (String, Document?)?> _prints = <String, (String, Document?)?>{};
  final List<String> _printQueue = <String>[];
  bool _printing = false;
  bool _pinned = false;
  StreamSubscription<bool>? _pinSub;
  Folder? _already;
  bool _adding = false;
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: ExplorerSession.memoryOf(widget.root)?.offset ?? 0,
  )..addListener(() => _offset = _scroll.offset);

  /// Kept as it changes: the controller is detached by the time dispose runs.
  late double _offset = ExplorerSession.memoryOf(widget.root)?.offset ?? 0;

  /// Per-folder "Show hidden files" for the session.
  static final Map<String, bool> _hiddenOverride = <String, bool>{};
  static bool? _hiddenFor(String path) => _hiddenOverride[path];

  bool get _explorer => widget.mode != FolderMode.library;
  bool get _picker => widget.mode == FolderMode.picker;
  String get _gridKey => _explorer ? 'path:${widget.root}' : '${widget.folderId}/${widget.path}';

  @override
  void initState() {
    super.initState();
    if (_explorer) {
      unawaited(_startExplorer());
    } else {
      _watch();
    }
  }

  Future<void> _startExplorer() async {
    if (PathNames.volumes.isEmpty) PathNames.volumes = await Platform.volumes();
    if (!mounted) return;
    _openListing();
    final Library lib = ref.read(libraryProvider);
    if (_picker) {
      final Folder? f = await lib.folderForPath(widget.root);
      if (mounted) setState(() => _already = f);
    } else if (!PathNames.isRoot(widget.root) && !PathNames.isRestricted(widget.root)) {
      unawaited(lib.visit(widget.root, PathNames.nameOf(widget.root)));
      _pinSub = lib.watchPinnedPath(widget.root).listen((bool p) {
        if (mounted) setState(() => _pinned = p);
      });
    }
  }

  void _openListing() {
    final DirListing? old = _listing;
    if (old != null) {
      old.removeListener(_onListing);
      ExplorerSession.release(old);
    }
    _listing = ExplorerSession.open(widget.root, sort: _sort, hidden: _hidden)..addListener(_onListing);
    _onListing();
  }

  int _docsFor = -1;

  void _onListing() {
    if (!mounted) return;
    final DirListing l = _listing!;
    setState(() {});
    // Progress and covers for books already read, once the listing is in.
    if (l.done && _docsFor != l.entries.length) {
      _docsFor = l.entries.length;
      final List<String> uris = <String>[
        for (final DirEntry e in l.entries)
          if (!e.isDir && Library.bookExts.contains(e.extension)) Uri.file('${widget.root}/${e.name}').toString(),
      ];
      if (uris.isNotEmpty) {
        unawaited(
          ref.read(libraryProvider).documentsByUris(uris).then((Map<String, Document> d) {
            if (mounted) setState(() => _docs = d);
          }),
        );
      }
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_pinSub?.cancel());
    final DirListing? l = _listing;
    if (l != null) {
      l.removeListener(_onListing);
      ExplorerSession.remember(widget.root, FolderMemory(offset: _offset, loaded: l.entries.length));
      ExplorerSession.release(l);
    }
    _scroll.dispose();
    super.dispose();
  }

  void _watch() {
    unawaited(_sub?.cancel());
    _sub = ref.read(libraryProvider).watchLevel(widget.folderId!, widget.path, deep: _deep).listen((
      List<(Entry, Document?)> rows,
    ) async {
      final Map<String, (int, int)> counts = await ref.read(libraryProvider).countsUnder(widget.folderId!);
      if (mounted) {
        setState(() {
          _entries = rows;
          _counts = counts;
          _loaded = true;
        });
      }
    });
  }

  /// Include subfolders in Files: every file below, walked off the UI isolate.
  Future<void> _walkDeep() async {
    setState(() => _deepItems = null);
    final List<(String, int, int)> found = await _walk(widget.root, _hidden);
    if (!mounted || !_deep) return;
    setState(() {
      _deepItems = <_Item>[
        for (final (String p, int size, int modified) in found)
          _Item(
            name: PathNames.nameOf(p),
            isDir: false,
            uri: Uri.file(p).toString(),
            size: size,
            modified: modified,
            mime: PathFile.mimeOf(PathNames.nameOf(p)),
            rel: PathNames.parentOf(p).length > widget.root.length
                ? PathNames.parentOf(p).substring(widget.root.length + 1)
                : '',
            path: p,
          ),
      ];
    });
  }

  // ------------------------------------------------------------ items

  List<_Item> get _items {
    if (!_explorer) {
      return <_Item>[
        for (final (Entry e, Document? d) in _entries)
          _Item(
            name: e.name,
            isDir: e.isDir,
            uri: e.uri,
            size: e.size,
            modified: e.modified,
            mime: e.mime,
            rel: e.parent,
            doc: d,
            fingerprint: e.fingerprint,
            title: e.title,
            author: e.author,
            path: widget.path.isEmpty ? e.name : '${widget.path}/${e.name}',
          ),
      ];
    }
    if (_deep) return _deepItems ?? const <_Item>[];
    return <_Item>[
      for (final DirEntry e in _listing?.entries ?? const <DirEntry>[])
        _itemOf(widget.root, e, _docs[Uri.file('${widget.root}/${e.name}').toString()]),
    ];
  }

  String get _name => _explorer
      ? (PathNames.isRoot(widget.root) ? PathNames.parts(widget.root).first : PathNames.nameOf(widget.root))
      : (widget.path.isEmpty ? '' : widget.path.split('/').last);

  @override
  Widget build(BuildContext context) => _explorer ? _buildExplorer(context) : _buildLibrary(context);

  // ------------------------------------------------------------ library

  Widget _buildLibrary(BuildContext context) {
    final List<Folder> folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final Folder? folder = folders.where((Folder f) => f.id == widget.folderId).firstOrNull;
    final ScanState? scan = ref.watch(_scansProvider)[widget.folderId];
    if (folder == null) return const Scaffold();
    final String title = widget.path.isEmpty ? folder.name : _name;
    final List<String> parts = <String>[folder.name, if (widget.path.isNotEmpty) ...widget.path.split('/')];
    final List<_Item> all = _items;
    final List<_Item> subdirs = _deep
        ? const <_Item>[]
        : (all.where((_Item e) => e.isDir).toList()
            ..sort((_Item a, _Item b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
    final List<_Item> files = all.where((_Item e) => !e.isDir).toList();
    final int unreadable = files.where((_Item e) => e.format == null).length;

    Widget body;
    if (folder.accessLost) {
      body = EmptyState(
        icon: AppIcons.folderOff,
        tone: EmptyTone.danger,
        small: true,
        title: 'Unfurl lost access to ${folder.name}',
        message: folder.source == 'path_folder' ? 'All files access was turned off. Your progress and notes are kept.' : 'Android removed access, which can happen after a backup restore or a storage change. Your progress and notes are kept.',
        actions: <Widget>[
          AppButton(
            label: folder.source == 'path_folder' ? 'Go to Files' : 'Grant access again',
            icon: AppIcons.folderOpen,
            onPressed: () => regrantFolder(context, ref, folder),
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
      final List<_Item> shown = _filter(files, showUnsupported: _showAll);
      final int folderCount = <String>{for (final _Item e in shown) e.rel}.length;
      body = _list(
        title: title,
        subdirs: _filterDirs(subdirs),
        shown: shown,
        presentFrom: files,
        scanCard: scan == null ? null : _ScanCard(name: folder.name, scan: scan),
        subdirRow: (_Item d) {
          final (int readable, int _) = _counts[d.path] ?? (0, 0);
          return _FolderRow(
            name: d.name,
            meta: scan != null && !_counts.containsKey(d.path)
                ? 'Counting…'
                : (readable == 0 ? 'No readable files' : '$readable readable ${readable == 1 ? 'file' : 'files'}'),
            muted: readable == 0,
            onTap: () => context.push(Routes.folder(widget.folderId!, path: d.path, base: widget.base)),
          );
        },
        metaLeft: scan != null
            ? 'Found so far'
            : _deep
            ? '${shown.length} ${shown.length == 1 ? 'file' : 'files'} in $folderCount ${folderCount == 1 ? 'folder' : 'folders'}'
            : _showAll && unreadable > 0
            ? '${shown.length} files · $unreadable can’t be opened'
            : '${shown.length} ${shown.length == 1 ? 'file' : 'files'}${subdirs.isEmpty ? '' : ' here'}',
      );
    }
    final List<String> ancestors = parts.sublist(0, parts.length - 1);
    return _scaffold(
      title: title,
      crumb: _crumbOf(ancestors),
      onCrumb: ancestors.isEmpty
          ? null
          : () => _pathSheet(
              parts,
              (int i) => _counts[parts.sublist(1, i + 1).join('/')]?.$1 ?? 0,
              root: 'Granted folder',
            ),
      actions: folder.accessLost ? const <Widget>[] : _actions(),
      body: body,
    );
  }

  // ------------------------------------------------------------ explorer

  Widget _buildExplorer(BuildContext context) {
    final DirListing? l = _listing;
    final List<String> parts = PathNames.parts(widget.root);
    final String title = parts.last;
    final List<String> ancestors = parts.sublist(0, parts.length - 1);
    final List<_Item> all = _items;
    final List<_Item> subdirs = _deep ? const <_Item>[] : all.where((_Item e) => e.isDir).toList();
    final List<_Item> files = all.where((_Item e) => !e.isDir).toList();
    final int readable = files.where((_Item e) => e.format != null && !e.hidden).length;
    final int total = _deep ? files.length : ((l?.total ?? 0) - (l?.dirs ?? 0));

    Widget? bottom;
    Widget body;
    final DirProblem? problem = l?.problem;
    if (PathNames.isRestricted(widget.root) || problem == DirProblem.restricted) {
      body = _state(
        AppIcons.lock,
        'Android doesn’t allow apps to open this folder.',
        _picker
            ? 'Choose another folder. Folders under Android/media can be added.'
            : 'It holds private files for other apps. To see them, use the app that created them.',
      );
    } else if (problem == DirProblem.denied) {
      body = _state(
        AppIcons.folderOff,
        'Unfurl can’t see this folder',
        'All files access was turned off. Your progress and notes are kept.',
        danger: true,
      );
      bottom = _bottomButton('Go to Files', AppIcons.folderOpen, () => context.go(Routes.files));
    } else if (problem == DirProblem.removed) {
      final bool usb = PathNames.volumeOf(widget.root)?.kind == 'usb';
      body = usb
          ? _state(
              AppIcons.usbOff,
              'Can’t read this drive',
              'It may have been unplugged, or it uses a format Android can’t read.',
              danger: true,
            )
          : _state(
              AppIcons.sdCardAlert,
              'SD card was removed',
              'Put it back to keep browsing. Reading progress for its books is kept.',
              danger: true,
            );
      bottom = usb
          ? _bottomButton('Try again', AppIcons.refresh, () => setState(_openListing))
          : _bottomButton('Back to Files', AppIcons.folderOpen, () => context.go(Routes.files));
    } else if (problem == DirProblem.unreadable || problem == DirProblem.missing) {
      body = _state(
        problem == DirProblem.missing ? AppIcons.folderOff : AppIcons.usbOff,
        problem == DirProblem.missing ? 'This folder is gone' : 'Can’t read this folder',
        problem == DirProblem.missing
            ? 'It may have been moved or deleted. Anything you read from it keeps its progress and notes.'
            : 'It may have been unplugged, or it uses a format Android can’t read.',
        danger: true,
      );
      bottom = _bottomButton('Try again', AppIcons.refresh, () => setState(_openListing));
    } else if (l != null && l.done && (l.total ?? 0) == 0 && !_deep) {
      body = _state(
        AppIcons.folderOpen,
        'This folder is empty',
        'Files added here later will show up when you come back.',
        neutral: true,
      );
    } else {
      final List<_Item> shown = _filter(files, showUnsupported: !_picker);
      final bool loading = _deep ? _deepItems == null : (l == null || l.total == null);
      body = _list(
        title: title,
        subdirs: _filterDirs(subdirs),
        shown: shown,
        presentFrom: files,
        skeleton: loading,
        loadingMore: !_deep && l != null && l.total != null && !l.done ? (l.entries.length, l.total!) : null,
        subdirRow: _explorerDirRow,
        metaLeft: loading
            ? 'Reading folder…'
            : _picker
            ? '${grouped(total)} ${total == 1 ? 'file' : 'files'} · ${grouped(readable)} readable'
            : '${grouped(total)} ${total == 1 ? 'file' : 'files'} · ${grouped(readable)} readable',
        metaRight: _picker ? 'Readable files' : null,
      );
      if (_picker && !PathNames.isRoot(widget.root)) {
        bottom = _already != null
            ? FolderPickerBar(
                noteIcon: AppIcons.checkCircle,
                note: 'Already in your Library',
                icon: AppIcons.library,
                label: 'Back to Library',
                onPressed: () => closePicker(context),
              )
            : FolderPickerBar(
                note:
                    '${PathNames.readable(widget.root)} · ${grouped(readable)} readable ${readable == 1 ? 'file' : 'files'}',
                label: _adding ? 'Adding…' : 'Choose this folder',
                onPressed: _adding ? () {} : _choose,
              );
      }
    }
    return _scaffold(
      title: title,
      crumb: _crumbOf(ancestors),
      onCrumb: ancestors.isEmpty ? null : () => _pathSheet(parts, (int _) => -1, root: 'Storage'),
      actions: _picker ? const <Widget>[] : _actions(),
      body: body,
      bottom: bottom,
      closeIcon: _picker,
    );
  }

  /// "Choose this folder": add it by path, scan it, back to Library.
  Future<void> _choose() async {
    setState(() => _adding = true);
    final Library lib = ref.read(libraryProvider);
    final Folder f = await lib.addPathFolder(
      widget.root,
      name: PathNames.nameOf(widget.root),
      readable: PathNames.readable(widget.root).replaceFirst(RegExp(r'^Internal storage › '), ''),
    );
    final int books = await lib.bookCount(f.id);
    if (!mounted) return;
    closePicker(context);
    AppSnackbar.info(rootNavigatorKey.currentContext ?? context, addedMessage(f.name, books));
  }

  Widget _explorerDirRow(_Item d) {
    final String path = d.path;
    final bool restricted = PathNames.isRestricted(path);
    if (!restricted && !_summaries.containsKey(path)) {
      _summaries[path] = null;
      unawaited(
        Platform.folderSummary(path, readableExtensions).then(((int, int, int)? r) {
          if (mounted) setState(() => _summaries[path] = r);
        }),
      );
    }
    final (int, int, int)? s = _summaries[path];
    // A folder of folders says so, rather than "0 files" (docs/design-gaps.md).
    final bool onlyFolders = s != null && s.$1 == 0 && s.$3 > 0;
    final String meta = restricted
        ? 'Not available to apps'
        : s == null
        ? 'Counting…'
        : d.hidden
        ? 'Hidden · ${grouped(s.$1)} ${s.$1 == 1 ? 'file' : 'files'}'
        : onlyFolders
        ? '${grouped(s.$3)} ${s.$3 == 1 ? 'folder' : 'folders'}'
        : '${grouped(s.$1)} ${s.$1 == 1 ? 'file' : 'files'} · ${s.$2 == 0 ? 'No readable files' : '${grouped(s.$2)} readable'}';
    return ExplorerRow(
      icon: AppIcons.folder,
      tile: TileKind.plain,
      name: d.name,
      meta: meta,
      muted: d.hidden || restricted,
      trailing: restricted ? AppIcons.lock : AppIcons.chevronRight,
      onTap: () => context.push(_picker ? Routes.pick(path) : Routes.browse(path)),
    );
  }

  // ------------------------------------------------------------ shared

  List<_Item> _filter(List<_Item> files, {required bool showUnsupported}) {
    final String q = _query.toLowerCase();
    final List<_Item> out = files.where((_Item e) {
      final FormatModule? m = e.format;
      if (m == null && !showUnsupported) return false;
      if (_other && m != null) return false;
      if (_group != null && m?.group != _group) return false;
      if (q.isNotEmpty && !e.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    // The library sorts here; Files arrives sorted from the platform.
    if (!_explorer || _deep) {
      out.sort(
        (_Item a, _Item b) => switch (_sort) {
          'modified' => b.modified.compareTo(a.modified),
          'size' => b.size.compareTo(a.size),
          'type' => Formats.labelOf(a.name).compareTo(Formats.labelOf(b.name)),
          _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        },
      );
    }
    return out;
  }

  List<_Item> _filterDirs(List<_Item> dirs) =>
      _query.isEmpty ? dirs : dirs.where((_Item d) => d.name.toLowerCase().contains(_query.toLowerCase())).toList();

  String? _crumbOf(List<String> ancestors) => ancestors.isEmpty
      ? null
      : (ancestors.length > 2 ? '… › ${ancestors.sublist(ancestors.length - 2).join(' › ')}' : ancestors.join(' › '));

  String get _sortLabel => switch (_sort) {
    'modified' => 'Modified',
    'size' => 'Size',
    'type' => 'Type',
    _ => 'Name',
  };

  Widget _state(IconData icon, String title, String message, {bool danger = false, bool neutral = false}) => EmptyState(
    icon: icon,
    tone: danger ? EmptyTone.danger : (neutral ? EmptyTone.neutral : EmptyTone.accent),
    small: true,
    title: title,
    message: message,
  );

  Widget _bottomButton(String label, IconData icon, VoidCallback onPressed) => Padding(
    padding: EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, MediaQuery.paddingOf(context).bottom + Space.xl),
    child: AppButton(label: label, icon: icon, onPressed: onPressed),
  );

  List<Widget> _actions() => <Widget>[
    AppIconButton(
      icon: _grid ? AppIcons.viewList : AppIcons.gridView,
      semanticLabel: _grid ? 'Show as list' : 'Show as grid',
      onPressed: () {
        setState(() => _grid = !_grid);
        unawaited(ref.read(settingsProvider.notifier).setFolderGrid(_gridKey, grid: _grid));
      },
    ),
    Builder(
      builder: (BuildContext b) => AppIconButton(
        icon: AppIcons.moreHoriz,
        semanticLabel: 'Sort and show',
        onPressed: () => _explorer ? _explorerMenu(b) : _menu(b),
      ),
    ),
  ];

  Widget _scaffold({
    required String title,
    required String? crumb,
    required VoidCallback? onCrumb,
    required List<Widget> actions,
    required Widget body,
    Widget? bottom,
    bool closeIcon = false,
  }) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(
            title: title,
            crumb: crumb,
            onCrumb: onCrumb,
            backIcon: closeIcon ? AppIcons.close : AppIcons.back,
            onBack: closeIcon ? () => closePicker(context) : () => context.pop(),
            actions: actions,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.fast),
              child: KeyedSubtree(
                key: ValueKey<Object>('${_grid}_${_group}_${_other}_${_deep}_${_showAll}_$_hidden'),
                child: body,
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.containerTransform),
            curve: Motion.decelerate,
            child: bottom ?? const SizedBox(width: double.infinity),
          ),
        ],
      ),
    ),
  );

  Widget _list({
    required String title,
    required List<_Item> subdirs,
    required List<_Item> shown,
    required List<_Item> presentFrom,
    required Widget Function(_Item) subdirRow,
    required String metaLeft,
    String? metaRight,
    Widget? scanCard,
    bool skeleton = false,
    (int, int)? loadingMore,
  }) {
    final UnfurlColors c = context.colors;
    final Set<FormatGroup> present = <FormatGroup>{for (final _Item e in presentFrom) ?e.format?.group};
    final bool hasOther = _explorer && presentFrom.any((_Item e) => e.format == null);
    final bool anyNonBook = shown.any((_Item e) => !(e.format?.book ?? false));
    return CustomScrollView(
      controller: _explorer ? _scroll : null,
      slivers: <Widget>[
        if (!_picker)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.screen, Space.xs, Space.screen, 14),
            sliver: SliverToBoxAdapter(
              child: SearchField(hint: 'Search in $title', onChanged: (String q) => setState(() => _query = q.trim())),
            ),
          ),
        if (!_picker)
          SliverToBoxAdapter(
            child: ChipRow(
              children: <Widget>[
                PillChip(
                  label: 'All',
                  selected: _group == null && !_other,
                  count: _explorer && loadingMore == null && !skeleton ? presentFrom.length : null,
                  onTap: () => setState(() {
                    _group = null;
                    _other = false;
                  }),
                ),
                for (final FormatGroup g in FormatGroup.values)
                  if (present.contains(g))
                    PillChip(
                      label: g.label,
                      selected: _group == g,
                      onTap: () => setState(() {
                        _group = _group == g ? null : g;
                        _other = false;
                      }),
                    ),
                if (hasOther)
                  PillChip(
                    label: 'Other',
                    selected: _other,
                    onTap: () => setState(() {
                      _other = !_other;
                      _group = null;
                    }),
                  ),
                if (_explorer && _hidden)
                  PillChip(
                    label: 'Hidden files',
                    selected: true,
                    leading: const AppIcon(AppIcons.visibility),
                    onTap: _toggleHidden,
                  ),
                PillChip(
                  label: 'Include subfolders',
                  toggle: true,
                  selected: _deep,
                  leading: AppIcon(_deep ? AppIcons.check : AppIcons.subdirectory),
                  onTap: _toggleDeep,
                ),
              ],
            ),
          ),
        if (scanCard != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.screen, 14, Space.screen, 0),
            sliver: SliverToBoxAdapter(child: scanCard),
          ),
        if (subdirs.isNotEmpty)
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
                    for (int i = 0; i < subdirs.length; i++) ...<Widget>[
                      if (i > 0) Divider(height: 1, color: c.divider),
                      subdirRow(subdirs[i]),
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
                  child: Text(metaLeft, style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                ),
                Text(metaRight ?? 'Sort: $_sortLabel', style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            Space.screen,
            0,
            Space.screen,
            _picker ? Space.xl : (loadingMore != null ? Space.md : Space.bottomSafe),
          ),
          sliver: _grid
              ? SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    // Rows fit their tiles: books carry a track, other
                    // files a name line.
                    mainAxisExtent: skeleton || anyNonBook ? 188 : 170,
                    mainAxisSpacing: 18,
                  ),
                  itemCount: skeleton ? 9 : shown.length + (loadingMore != null ? 3 : 0),
                  itemBuilder: (BuildContext context, int i) => Align(
                    alignment: <Alignment>[Alignment.topLeft, Alignment.topCenter, Alignment.topRight][i % 3],
                    child: SizedBox(
                      width: 96,
                      child: skeleton || i >= shown.length
                          ? const SkeletonTile()
                          : Reveal(index: i < 9 ? i : 0, child: _tile(shown[i])),
                    ),
                  ),
                )
              : SliverList.builder(
                  itemCount: skeleton ? 9 : shown.length,
                  itemBuilder: (BuildContext context, int i) {
                    final bool first = i == 0, last = i == (skeleton ? 8 : shown.length - 1);
                    final Widget row = skeleton
                        ? SkeletonRow(index: i)
                        : Reveal(index: i < 9 ? i : 0, child: _explorer ? _explorerRow(shown[i]) : _row(shown[i]));
                    // One rounded group, drawn row by row so long folders stay lazy.
                    // The border is one colour (a rounded border can't mix
                    // colours); the divider between rows is drawn inside.
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.surfaceContainer,
                        border: Border(
                          left: BorderSide(color: c.outline),
                          right: BorderSide(color: c.outline),
                          top: first ? BorderSide(color: c.outline) : BorderSide.none,
                          bottom: last ? BorderSide(color: c.outline) : BorderSide.none,
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: first ? const Radius.circular(Radii.card) : Radius.zero,
                          bottom: last ? const Radius.circular(Radii.card) : Radius.zero,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: first ? const Radius.circular(Radii.card) : Radius.zero,
                          bottom: last ? const Radius.circular(Radii.card) : Radius.zero,
                        ),
                        child: last
                            ? row
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  row,
                                  Divider(height: 1, color: c.divider),
                                ],
                              ),
                      ),
                    );
                  },
                ),
        ),
        if (loadingMore != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.bottomSafe),
            sliver: SliverToBoxAdapter(
              child: LoadingRow(loaded: loadingMore.$1, total: loadingMore.$2),
            ),
          ),
      ],
    );
  }

  void _toggleDeep() => setState(() {
    _deep = !_deep;
    if (_explorer) {
      if (_deep) unawaited(_walkDeep());
    } else {
      _watch();
    }
  });

  void _toggleHidden() => setState(() {
    _hidden = !_hidden;
    _hiddenOverride[widget.root] = _hidden;
    _openListing();
    if (_deep) unawaited(_walkDeep());
  });

  void _wantPrint(_Item e) {
    if (_prints.containsKey(e.path) || e.size == 0) return;
    _prints[e.path] = null;
    _printQueue.add(e.path);
    // ponytail: the 24 most recent requests; a fast fling drops the rest,
    // which ask again when they are built again.
    if (_printQueue.length > 24) _prints.remove(_printQueue.removeAt(0));
    unawaited(_drainPrints());
  }

  Future<void> _drainPrints() async {
    if (_printing) return;
    _printing = true;
    final Library lib = ref.read(libraryProvider);
    while (_printQueue.isNotEmpty && mounted) {
      final String path = _printQueue.removeLast();
      String? fp;
      try {
        fp = await Files.fingerprint(Uri.file(path).toString());
      } on Exception {
        fp = null;
      }
      if (fp == null) continue;
      final Document? doc = await lib.document(fp);
      if (!mounted) break;
      setState(() => _prints[path] = (fp!, doc));
    }
    _printing = false;
  }

  Widget _tile(_Item e) {
    final FormatModule? m = e.format;
    final String meta = '${Files.size(e.size)} · ${Files.when(e.modified)}';
    if (m != null && m.book && !e.hidden) {
      if (_explorer && e.doc == null && e.fingerprint == null) _wantPrint(e);
      final (String, Document?)? printed = _prints[e.path];
      final Document? doc = e.doc ?? printed?.$2;
      final double progress = doc?.progress ?? 0;
      return CoverTile(
        cover: CoverArt(
          title: doc?.title ?? e.title ?? _stem(e.name),
          author: doc?.author ?? e.author,
          fingerprint: e.fingerprint ?? doc?.fingerprint ?? printed?.$1,
          format: m,
        ),
        progress: progress,
        finished: doc?.finished ?? false,
        meta:
            '${m.label} · ${doc == null || progress <= 0 ? 'New' : (doc.finished ? 'Finished' : '${(progress * 100).round()}%')}',
        onTap: () => _open(e),
        onLongPress: _explorer && !_picker ? () => showFileActions(context, _file(e)) : null,
      );
    }
    final bool image = _explorer && m == Formats.image && !e.hidden;
    return CoverTile(
      cover: image
          ? _Thumb(path: e.path, label: Formats.labelOf(e.name))
          : FormatTile(
              label: m?.label ?? Formats.labelOf(e.name),
              icon: m?.icon ?? unknownIcon(e.name),
              muted: m == null || e.hidden,
            ),
      progress: 0,
      finished: false,
      name: _stem(e.name),
      muted: m == null || e.hidden,
      meta: e.hidden
          ? 'Hidden · ${Files.size(e.size)}'
          : (_explorer ? '${Formats.labelOf(e.name)} · ${Files.size(e.size)}' : meta),
      onTap: _picker ? () {} : () => _open(e),
      onLongPress: _explorer && !_picker ? () => showFileActions(context, _file(e)) : null,
    );
  }

  /// A row in Files: muted, dashed tile and "Open in another app" for files
  /// Unfurl can't read; long-press for actions.
  Widget _explorerRow(_Item e) {
    final (IconData icon, TileKind kind) = fileLook(e.name);
    final bool muted = e.format == null || e.hidden;
    final String rel = _deep && e.rel.isNotEmpty ? ' · ${e.rel.replaceAll('/', ' › ')}' : '';
    return ExplorerRow(
      icon: e.hidden ? AppIcons.visibilityOff : icon,
      tile: muted ? TileKind.muted : kind,
      name: e.name,
      muted: muted,
      meta: e.hidden
          ? 'Hidden · ${Files.size(e.size)}'
          : '${Formats.labelOf(e.name)} · ${Files.size(e.size)}${e.format == null ? ' · Open in another app' : (_picker ? '' : ' · ${Files.when(e.modified)}')}$rel',
      onTap: _picker ? null : () => _open(e),
      onLongPress: _picker ? null : () => showFileActions(context, _file(e)),
    );
  }

  PathFile _file(_Item e) => PathFile(path: e.path, size: e.size, modified: e.modified);

  Widget _row(_Item e) {
    final UnfurlColors c = context.colors;
    final FormatModule? m = e.format;
    final bool muted = m == null;
    final String rel = widget.path.isEmpty
        ? e.rel
        : (e.rel.length > widget.path.length ? e.rel.substring(widget.path.length + 1) : '');
    return InkWell(
      onTap: () => _open(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 10),
        child: Row(
          spacing: 14,
          children: <Widget>[
            RowTile(icon: m?.icon ?? unknownIcon(e.name), kind: muted ? TileKind.muted : TileKind.box),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UnfurlType.titleMedium
                        .copyWith(color: muted ? c.onSurfaceMuted : c.onSurface)
                        .weight(muted ? 500 : 600),
                  ),
                  Text(
                    '${m?.label ?? Formats.labelOf(e.name)} · ${Files.size(e.size)} · ${Files.when(e.modified)}',
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

  static String _stem(String n) => n.contains('.') ? n.substring(0, n.lastIndexOf('.')) : n;

  void _open(_Item e) {
    if (_explorer) {
      unawaited(openPathFile(context, _file(e)));
      return;
    }
    final Document? doc = e.doc;
    final DocRef ref = DocRef(uri: e.uri, name: e.name, size: e.size, modified: e.modified, mime: e.mime);
    unawaited(
      openDocument(context, ref, at: doc?.position == null ? null : Locator.fromJson(doc!.position!), mode: doc?.mode),
    );
  }

  Future<void> _menu(BuildContext anchor) async {
    final String? v = await showAppMenu<String>(
      context: context,
      anchorContext: anchor,
      entries: <AppMenuEntry<String>>[
        AppMenuEntry<String>(value: 'name', label: 'Sort: Name', icon: AppIcons.sortByAlpha, selected: _sort == 'name'),
        AppMenuEntry<String>(
          value: 'modified',
          label: 'Sort: Modified',
          icon: AppIcons.schedule,
          selected: _sort == 'modified',
        ),
        AppMenuEntry<String>(value: 'size', label: 'Sort: Size', icon: AppIcons.straighten, selected: _sort == 'size'),
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
      if (v == 'all') {
        _showAll = !_showAll;
      } else {
        _sort = v;
      }
    });
  }

  /// Files (X4): Sort by, Include subfolders, Show hidden files, Pin to
  /// Files, Folder info.
  Future<void> _explorerMenu(BuildContext anchor) async {
    final bool canPin = !PathNames.isRoot(widget.root) && !PathNames.isRestricted(widget.root);
    final String? v = await showAppMenu<String>(
      context: context,
      anchorContext: anchor,
      entries: <AppMenuEntry<String>>[
        AppMenuEntry<String>(
          value: 'sort',
          label: 'Sort by',
          icon: AppIcons.sort,
          subtitle: switch (_sort) {
            'modified' => 'Modified, newest first',
            'size' => 'Size, largest first',
            'type' => 'Type, A to Z',
            _ => 'Name, A to Z',
          },
        ),
        AppMenuEntry<String>(
          value: 'deep',
          label: 'Include subfolders',
          icon: AppIcons.subdirectory,
          switchValue: _deep,
        ),
        AppMenuEntry<String>(
          value: 'hidden',
          label: 'Show hidden files',
          icon: AppIcons.visibility,
          switchValue: _hidden,
        ),
        const AppMenuEntry<String>.divider(),
        if (canPin)
          AppMenuEntry<String>(
            value: 'pin',
            label: _pinned ? 'Unpin' : 'Pin to Files',
            icon: AppIcons.star,
            accentIcon: _pinned,
          ),
        const AppMenuEntry<String>(value: 'info', label: 'Folder info', icon: AppIcons.info),
      ],
    );
    if (!mounted || v == null) return;
    switch (v) {
      case 'sort':
        if (!anchor.mounted) return;
        final String? s = await showAppMenu<String>(
          context: context,
          anchorContext: anchor,
          entries: <AppMenuEntry<String>>[
            for (final (String key, String label, IconData icon) in <(String, String, IconData)>[
              ('name', 'Name, A to Z', AppIcons.sortByAlpha),
              ('modified', 'Modified, newest first', AppIcons.schedule),
              ('size', 'Size, largest first', AppIcons.straighten),
              ('type', 'Type, A to Z', AppIcons.description),
            ])
              AppMenuEntry<String>(value: key, label: label, icon: icon, selected: _sort == key),
          ],
        );
        if (s != null && mounted && s != _sort) {
          setState(() {
            _sort = s;
            _openListing();
          });
        }
      case 'deep':
        _toggleDeep();
      case 'hidden':
        _toggleHidden();
      case 'pin':
        await ref.read(libraryProvider).setPinned(widget.root, PathNames.nameOf(widget.root), pinned: !_pinned);
      case 'info':
        final List<_Item> all = _items;
        if (!mounted) return;
        await showFolderInfo(
          context,
          path: widget.root,
          files: all.where((_Item e) => !e.isDir).length,
          folders: all.where((_Item e) => e.isDir).length,
          readable: all.where((_Item e) => !e.isDir && e.format != null).length,
        );
    }
  }

  /// "Go to folder": every level from the top, this one marked. [readableAt]
  /// gives a level's readable count, or -1 to leave it out.
  Future<void> _pathSheet(List<String> parts, int Function(int) readableAt, {required String root}) =>
      showReaderSheet<void>(
        context,
        (BuildContext ctx) => _PathTree(
          parts: parts,
          subtitle: (int i) {
            final int readable = readableAt(i);
            return i == 0 ? root : (readable < 0 ? 'Folder' : readableFiles(readable));
          },
          onPick: (int i) {
            Navigator.of(ctx).pop();
            if (i < parts.length - 1) _goUp(parts.length - 1 - i);
          },
        ),
      );

  /// Up [levels] folders. The library pushes one route per level; Files may
  /// have jumped in (Quick access, Pinned), so it replaces this screen.
  void _goUp(int levels) {
    if (!_explorer) {
      for (int k = 0; k < levels; k++) {
        context.pop();
      }
      return;
    }
    String target = widget.root;
    for (int k = 0; k < levels; k++) {
      target = PathNames.parentOf(target);
    }
    context.pushReplacement(_picker ? Routes.pick(target) : Routes.browse(target));
  }
}

/// An explorer entry as an item.
_Item _itemOf(String root, DirEntry e, Document? doc) => _Item(
  name: e.name,
  isDir: e.isDir,
  uri: Uri.file('$root/${e.name}').toString(),
  size: e.size,
  modified: e.modified,
  mime: e.isDir ? null : PathFile.mimeOf(e.name),
  doc: doc,
  path: '$root/${e.name}',
);

/// An image file's own picture, decoded at the size it is drawn.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.path, required this.label});

  final String path;
  final String label;

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: Radii.coverR,
      child: SizedBox(
        width: 96,
        height: 136,
        child: Image(
          image: ResizeImage(FileImage(File(path)), width: (96 * dpr).round()),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          frameBuilder: (BuildContext context, Widget child, int? frame, bool sync) => sync
              ? child
              : AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: Motion.of(context, Motion.reveal),
                  curve: Motion.decelerate,
                  child: child,
                ),
          errorBuilder: (BuildContext context, Object e, StackTrace? s) =>
              FormatTile(label: label, icon: AppIcons.image),
        ),
      ),
    );
  }
}

/// Every file below [root] (up to 5,000), off the UI isolate.
Future<List<(String, int, int)>> _walk(String root, bool hidden) => Isolate.run(() {
  final List<(String, int, int)> out = <(String, int, int)>[];
  final List<Directory> queue = <Directory>[Directory(root)];
  while (queue.isNotEmpty && out.length < 5000) {
    final Directory d = queue.removeAt(0);
    List<FileSystemEntity> children;
    try {
      children = d.listSync(followLinks: false);
    } on FileSystemException {
      continue;
    }
    for (final FileSystemEntity e in children) {
      final String name = e.path.substring(e.path.lastIndexOf('/') + 1);
      if (!hidden && name.startsWith('.')) continue;
      if (e is Directory) {
        if (!PathNames.isRestricted(e.path)) queue.add(e);
      } else if (e is File) {
        final FileStat s = e.statSync();
        out.add((e.path, s.size, s.modified.millisecondsSinceEpoch));
        if (out.length >= 5000) break;
      }
    }
  }
  return out;
});

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

/// "Go to folder": the path as a tree, as a file manager draws it. Each level
/// sits one step in from its parent, joined by a connector. A deep path shows
/// its root, a row standing for the folders between (tap to show them all)
/// and the last three; the indent stops growing after eight levels.
class _PathTree extends StatefulWidget {
  const _PathTree({required this.parts, required this.subtitle, required this.onPick});

  final List<String> parts;
  final String Function(int index) subtitle;
  final ValueChanged<int> onPick;

  @override
  State<_PathTree> createState() => _PathTreeState();
}

class _PathTreeState extends State<_PathTree> {
  static const double step = 20, maxDepth = 8;
  static const int tail = 3;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final int n = widget.parts.length;
    final bool fold = !_all && n > tail + 2;
    // Indices to show; -1 is the row for the folded middle.
    final List<int> shown = fold
        ? <int>[0, -1, for (int i = n - tail; i < n; i++) i]
        : <int>[for (int i = 0; i < n; i++) i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 2,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: Text('Go to folder', style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
        ),
        for (int row = 0; row < shown.length; row++)
          _row(c, depth: math.min(row, maxDepth.toInt()), index: shown[row], hidden: n - tail - 1),
      ],
    );
  }

  Widget _row(UnfurlColors c, {required int depth, required int index, required int hidden}) {
    final bool folded = index < 0;
    final bool here = index == widget.parts.length - 1;
    final Color fg = here ? c.onPrimaryContainer : c.onSurface;
    return Semantics(
      button: true,
      selected: here,
      label: folded ? '$hidden more folders' : widget.parts[index],
      onTap: folded ? () => setState(() => _all = true) : () => widget.onPick(index),
      excludeSemantics: true,
      child: Material(
        color: here ? c.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(Space.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(Space.lg),
          onTap: folded ? () => setState(() => _all = true) : () => widget.onPick(index),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.only(left: Space.sm, right: Space.lg),
              child: Row(
                children: <Widget>[
                  CustomPaint(
                    size: Size(depth * step, 56),
                    painter: _Connector(depth: depth, step: step, child: !here, color: c.outline),
                  ),
                  AppIcon(
                    folded ? AppIcons.moreHoriz : (here ? AppIcons.folderOpen : AppIcons.folder),
                    color: here ? c.onPrimaryContainer : c.icon,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          folded ? '$hidden more ${hidden == 1 ? 'folder' : 'folders'}' : widget.parts[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UnfurlType.titleMedium.copyWith(color: folded ? c.onSurfaceVariant : fg),
                        ),
                        Text(
                          folded ? 'Show all' : (here ? 'You are here' : widget.subtitle(index)),
                          style: UnfurlType.monoLabel.copyWith(
                            height: 1.5,
                            color: here ? c.onPrimaryContainer : (folded ? c.accent : c.onSurfaceVariant),
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
    );
  }
}

/// The elbow from the parent's icon down and across to this row's icon.
class _Connector extends CustomPainter {
  const _Connector({required this.depth, required this.step, required this.child, required this.color});

  final int depth;
  final double step;

  /// A row below: a stub runs down from this row's icon to meet its elbow.
  final bool child;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final double mid = size.height / 2;
    // Icons are 24 wide and start where this box ends; a parent's centre is
    // one step back. Lines overrun by 2 to bridge the gap between rows.
    if (child) {
      final double own = depth * step + IconSpec.size / 2;
      canvas.drawLine(Offset(own, mid + IconSpec.size / 2 + 2), Offset(own, size.height + 2), line);
    }
    if (depth == 0) return;
    final double x = (depth - 1) * step + IconSpec.size / 2;
    canvas.drawPath(
      Path()
        ..moveTo(x, -2)
        ..lineTo(x, mid - 6)
        ..quadraticBezierTo(x, mid, x + 6, mid)
        ..lineTo(size.width - 2, mid),
      line,
    );
  }

  @override
  bool shouldRepaint(_Connector old) => old.depth != depth || old.child != child || old.color != color;
}
