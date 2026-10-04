import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/explorer.dart';
import '../../core/files.dart';
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
import '../../design_system/app_snackbar.dart';
import '../../design_system/buttons.dart';
import '../../design_system/containers.dart';
import '../../formats/format_registry.dart';
import 'file_sheets.dart';
import 'files_widgets.dart';

/// Quick access places that exist on this phone.
final FutureProvider<List<QuickPlace>> quickAccessProvider = FutureProvider<List<QuickPlace>>((Ref ref) {
  ref.watch(filesAccessProvider.select((FilesAccess a) => a.granted));
  return Platform.quickAccess();
});

/// Mounted storage volumes, with space used.
final FutureProvider<List<StorageVolume>> volumesProvider = FutureProvider<List<StorageVolume>>((Ref ref) async {
  ref.watch(filesAccessProvider.select((FilesAccess a) => a.granted));
  final List<StorageVolume> v = await Platform.volumes();
  PathNames.volumes = v;
  return v;
});

final StreamProvider<List<Place>> pinnedPlacesProvider = StreamProvider<List<Place>>(
  (Ref ref) => ref.watch(libraryProvider).watchPinned(),
);

/// Recent folders, less any deleted from internal storage since (a folder
/// on a removed card stays, and shows as disconnected).
final StreamProvider<List<Place>> recentPlacesProvider = StreamProvider<List<Place>>(
  (Ref ref) => ref
      .watch(libraryProvider)
      .watchRecentPlaces()
      .map(
        (List<Place> all) => <Place>[
          for (final Place p in all)
            if (!p.path.startsWith(PathNames.internalRoot) || Directory(p.path).existsSync()) p,
        ],
      ),
);

/// "Not now" folds the privacy card for this session; it returns next launch.
final NotifierProvider<_CardFolded, bool> _cardFoldedProvider = NotifierProvider<_CardFolded, bool>(_CardFolded.new);

class _CardFolded extends Notifier<bool> {
  @override
  bool build() => false;

  void set({required bool folded}) => state = folded;
}

/// Extensions Unfurl opens, for "9 readable" counts.
final Set<String> readableExtensions = <String>{for (final FormatModule m in Formats.all) ...m.extensions};

/// Board 5, X1 to X3: the Files tab. Without all-files access, the privacy
/// card above the folders the user added; with it, Quick access, Storage,
/// Pinned and Recent folders. Folder screens push inside this tab.
class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  @override
  Widget build(BuildContext context) {
    final FilesAccess access = ref.watch(filesAccessProvider);
    // "All files access is on", once, after coming back from Android's page.
    ref.listen(filesAccessProvider, (FilesAccess? was, FilesAccess now) {
      if (now.justGranted && !(was?.justGranted ?? false)) {
        AppSnackbar.info(context, 'All files access is on');
        ref.read(filesAccessProvider.notifier).acknowledge();
        ref.read(_cardFoldedProvider.notifier).set(folded: false);
      }
    });
    return AppScaffold(
      title: 'Files',
      actions: <Widget>[
        Builder(
          builder: (BuildContext b) => AppIconButton(
            icon: AppIcons.moreHoriz,
            semanticLabel: 'More options',
            onPressed: () async {
              final String? v = await showAppMenu<String>(
                context: context,
                anchorContext: b,
                entries: <AppMenuEntry<String>>[
                  AppMenuEntry<String>(
                    value: 'access',
                    label: 'All files access',
                    icon: AppIcons.shieldLock,
                    subtitle: access.granted ? 'On' : 'Off',
                  ),
                  const AppMenuEntry<String>(value: 'settings', label: 'Settings', icon: AppIcons.settings),
                ],
              );
              if (!context.mounted) return;
              switch (v) {
                case 'access':
                  await askForAccess(context, ref);
                case 'settings':
                  await context.push(Routes.settings);
              }
            },
          ),
        ),
      ],
      children: <Widget>[
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.containerTransform),
          switchInCurve: Motion.decelerate,
          switchOutCurve: Motion.decelerate,
          child: KeyedSubtree(
            key: ValueKey<bool>(access.granted),
            child: access.granted ? const FilesHome() : _NoAccess(access: access),
          ),
        ),
      ],
    );
  }
}

/// "Allow access": the pre-sheet, then Android's page. The answer comes back
/// on resume (filesAccessProvider).
Future<void> askForAccess(BuildContext context, WidgetRef ref) async {
  if (ref.read(filesAccessProvider).granted) {
    // Turning it off happens in Android's page too.
    await Platform.requestAllFilesAccess();
    return;
  }
  if (!await showPermissionPreSheet(context)) return;
  await ref.read(filesAccessProvider.notifier).request();
}

class _NoAccess extends ConsumerWidget {
  const _NoAccess({required this.access});

  final FilesAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final bool folded = ref.watch(_cardFoldedProvider);
    final List<Folder> folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final Map<int, int> counts = ref.watch(readableCountsProvider).value ?? const <int, int>{};
    final String? eyebrow = switch (access.note) {
      AccessNote.stillOff => 'ACCESS IS STILL OFF',
      AccessNote.turnedOff => 'ACCESS WAS TURNED OFF',
      AccessNote.none => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AnimatedSize(
          duration: Motion.of(context, Motion.containerTransform),
          curve: Motion.decelerate,
          alignment: Alignment.topCenter,
          child: folded
              ? RowGroup(
                  children: <Widget>[
                    ExplorerRow(
                      icon: AppIcons.shieldLock,
                      tile: TileKind.accent,
                      name: 'Browse every file on your phone',
                      meta: 'All files access is off',
                      trailing: AppIcons.chevronRight,
                      onTap: () => ref.read(_cardFoldedProvider.notifier).set(folded: false),
                    ),
                  ],
                )
              : PrivacyCard(
                  eyebrow: eyebrow,
                  onAllow: () => askForAccess(context, ref),
                  onNotNow: () => ref.read(_cardFoldedProvider.notifier).set(folded: true),
                ),
        ),
        const SizedBox(height: Space.section),
        const SectionHeader(label: 'Your folders'),
        const SizedBox(height: Space.md),
        RowGroup(
          children: <Widget>[
            for (final Folder f in folders)
              ExplorerRow(
                icon: f.accessLost ? AppIcons.folderOff : AppIcons.folder,
                tile: TileKind.plain,
                name: f.name,
                meta: f.accessLost
                    ? 'Access lost'
                    : '${f.path.isEmpty ? f.name : f.path} · ${counts[f.id] ?? 0} readable',
                trailing: AppIcons.chevronRight,
                onTap: () => context.push(Routes.folder(f.id, base: Routes.files)),
              ),
            ExplorerRow(
              icon: AppIcons.createNewFolder,
              tile: TileKind.plain,
              name: 'Add folder',
              accent: true,
              onTap: () => addFolder(context, ref),
            ),
          ],
        ),
        if (folders.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.md),
            child: Text(
              'Pick a folder and Unfurl lists what it can open inside it, including subfolders. It only reads them.',
              style: UnfurlType.note.copyWith(color: c.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// Quick access, Storage, Pinned and Recent folders (X3), shared with the
/// "Choose a folder" picker root (X8), which leaves out Pinned.
class FilesHome extends ConsumerWidget {
  const FilesHome({this.picker = false, super.key});

  final bool picker;

  void _open(BuildContext context, String path) =>
      unawaited(context.push(picker ? Routes.pick(path) : Routes.browse(path)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<QuickPlace> quick = ref.watch(quickAccessProvider).value ?? const <QuickPlace>[];
    final List<StorageVolume> volumes = (ref.watch(volumesProvider).value ?? const <StorageVolume>[])
        .where((StorageVolume v) => v.mounted)
        .toList();
    final List<Place> pinned = ref.watch(pinnedPlacesProvider).value ?? const <Place>[];
    final List<Place> recent = ref.watch(recentPlacesProvider).value ?? const <Place>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (quick.isNotEmpty) ...<Widget>[
          const SectionHeader(label: 'Quick access'),
          const SizedBox(height: Space.md),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: quick.length,
              separatorBuilder: (BuildContext context, int i) => const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int i) {
                final QuickPlace q = quick[i];
                final (IconData icon, String name) = switch (q.id) {
                  'downloads' => (AppIcons.download, 'Downloads'),
                  'documents' => (AppIcons.description, 'Documents'),
                  'whatsapp' => (AppIcons.chat, 'WhatsApp Documents'),
                  'telegram' => (AppIcons.send, 'Telegram'),
                  'bluetooth' => (AppIcons.bluetooth, 'Bluetooth'),
                  _ => (AppIcons.screenshotMonitor, 'Screenshots'),
                };
                return QuickAccessCard(
                  icon: icon,
                  name: name,
                  meta: picker ? '${grouped(q.count)} files' : grouped(q.count),
                  onTap: () => _open(context, q.path),
                );
              },
            ),
          ),
          const SizedBox(height: Space.section),
        ],
        const SectionHeader(label: 'Storage'),
        const SizedBox(height: Space.md),
        RowGroup(
          children: <Widget>[
            for (final StorageVolume v in volumes)
              ExplorerRow(
                icon: switch (v.kind) {
                  'internal' => AppIcons.smartphone,
                  'usb' => AppIcons.usb,
                  _ => AppIcons.sdCard,
                },
                tile: TileKind.plain,
                name: switch (v.kind) {
                  'internal' => 'Internal storage',
                  'usb' =>
                    v.label.isEmpty || v.label.toUpperCase().trim() == 'USB DRIVE'
                        ? 'USB drive'
                        : 'USB drive · ${v.label.replaceAll(RegExp('USB', caseSensitive: false), '').trim()}',
                  _ => 'SD card',
                },
                meta: v.readable ? '${Files.size(v.free)} free of ${Files.size(v.total)}' : 'Can’t read this drive',
                usage: v.readable ? v.used : null,
                trailing: AppIcons.chevronRight,
                onTap: () => _open(context, v.path),
              ),
          ],
        ),
        if (pinned.isNotEmpty && !picker) ...<Widget>[
          const SizedBox(height: Space.section),
          const SectionHeader(label: 'Pinned'),
          const SizedBox(height: Space.md),
          RowGroup(
            children: <Widget>[
              for (final Place p in pinned) _PlaceRow(place: p, pinned: true, onTap: () => _open(context, p.path)),
            ],
          ),
        ],
        if (recent.isNotEmpty) ...<Widget>[
          const SizedBox(height: Space.section),
          const SectionHeader(label: 'Recent folders'),
          const SizedBox(height: Space.md),
          RowGroup(
            children: <Widget>[
              for (final Place p in recent) _PlaceRow(place: p, pinned: false, onTap: () => _open(context, p.path)),
            ],
          ),
        ],
      ],
    );
  }
}

/// A pinned or recent folder: where it is, and for pinned ones how many
/// files Unfurl reads there; "Not connected" when its drive is gone.
class _PlaceRow extends ConsumerStatefulWidget {
  const _PlaceRow({required this.place, required this.pinned, required this.onTap});

  final Place place;
  final bool pinned;
  final VoidCallback onTap;

  @override
  ConsumerState<_PlaceRow> createState() => _PlaceRowState();
}

class _PlaceRowState extends ConsumerState<_PlaceRow> {
  int? _readable;

  @override
  void initState() {
    super.initState();
    if (widget.pinned) {
      unawaited(
        Platform.folderSummary(widget.place.path, readableExtensions).then(((int, int, int)? r) {
          if (mounted && r != null) setState(() => _readable = r.$2);
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Place p = widget.place;
    final bool connected = PathNames.volumeOf(p.path)?.mounted ?? p.path.startsWith(PathNames.internalRoot);
    final List<String> parts = PathNames.parts(p.path);
    // Internal storage is implied; other drives name themselves.
    final String where = (parts.first == 'Internal storage' ? parts.skip(1) : parts).join(' › ');
    final String meta = !connected
        ? 'Not connected'
        : widget.pinned
        ? '${PathNames.readable(PathNames.parentOf(p.path)).replaceFirst(RegExp(r'^Internal storage( › )?'), '')}${_readable == null ? '' : '${PathNames.parentOf(p.path) == PathNames.internalRoot ? '' : ' · '}${_readable!} readable'}'
        : '$where · ${p.visitedAt == null ? '' : Files.when(p.visitedAt!.millisecondsSinceEpoch)}';
    return ExplorerRow(
      icon: widget.pinned ? AppIcons.folder : AppIcons.history,
      tile: TileKind.plain,
      name: p.name,
      meta: meta,
      muted: !connected,
      trailing: widget.pinned ? AppIcons.star : AppIcons.chevronRight,
      trailingAccent: widget.pinned,
      trailingFilled: widget.pinned,
      onTap: connected ? widget.onTap : null,
      onLongPress: widget.pinned ? () => ref.read(libraryProvider).setPinned(p.path, p.name, pinned: false) : null,
    );
  }
}

/// Board 5, X8: "Choose a folder", the picker's root.
class FilesPickerScreen extends StatelessWidget {
  const FilesPickerScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Choose a folder',
    onBack: () => closePicker(context),
    backIcon: AppIcons.close,
    children: const <Widget>[FilesHome(picker: true)],
  );
}

/// Leaves the picker at any depth, back to where Add folder was tapped.
void closePicker(BuildContext context) {
  final NavigatorState nav = Navigator.of(context, rootNavigator: true);
  nav.popUntil((Route<dynamic> r) => !(r.settings.name ?? '').startsWith('/pick'));
}

/// Library's "Add folder": with all-files access, the in-app picker (any
/// folder, Download included); without, the v1 pre-sheet and Android's
/// picker. Checked at tap time.
Future<void> addFolder(BuildContext context, WidgetRef ref, {bool explain = true}) async {
  if (await Platform.hasAllFilesAccess()) {
    if (context.mounted) await context.push(Routes.pick());
    return;
  }
  if (context.mounted) await addFolderFlow(context, ref, explain: explain);
}

/// What the picker returns to Library with: "Download added · 3 books".
String addedMessage(String name, int books) => '$name added · $books ${books == 1 ? 'book' : 'books'}';
