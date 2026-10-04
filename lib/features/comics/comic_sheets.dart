import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/files.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/reading_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/buttons.dart';
import '../../design_system/option_tiles.dart';
import '../files/files_widgets.dart';
import '../reader/sheets.dart';
import '../settings/settings_controller.dart';
import 'comic_pages.dart';
import 'comic_prefs.dart';

/// Board 6, V4 "Comic settings": reading mode, fit, right to left, spreads,
/// the cover alone and the page surround. Changes apply as they are made.
Future<void> showComicSettings(BuildContext context, {required bool rtl, required ValueChanged<bool> onRtl}) =>
    showReaderSheet<void>(context, surface: true, (BuildContext ctx) => _ComicSettings(rtl: rtl, onRtl: onRtl));

class _ComicSettings extends ConsumerStatefulWidget {
  const _ComicSettings({required this.rtl, required this.onRtl});

  final bool rtl;
  final ValueChanged<bool> onRtl;

  @override
  ConsumerState<_ComicSettings> createState() => _ComicSettingsState();
}

class _ComicSettingsState extends ConsumerState<_ComicSettings> {
  late bool _rtl = widget.rtl;

  @override
  Widget build(BuildContext context) {
    final ComicPrefs p = ref.watch(comicPrefsProvider);
    final ComicPrefsController ctl = ref.read(comicPrefsProvider.notifier);
    final ThemeFamily family = ref.watch(settingsProvider.select((AppSettings s) => s.family));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SheetHead(title: 'Comic settings'),
        OptionGroup(
          label: 'Reading mode',
          children: <Widget>[
            for (final (ComicMode m, String label, IconData icon) in <(ComicMode, String, IconData)>[
              (ComicMode.single, 'Single', AppIcons.cropPortrait),
              (ComicMode.spread, 'Two-page', AppIcons.book),
              (ComicMode.webtoon, 'Webtoon', AppIcons.viewDay),
            ])
              OptionTile(
                label: label,
                icon: icon,
                height: 60,
                selected: p.mode == m,
                onTap: () => ctl.update((ComicPrefs x) => x.copyWith(mode: m)),
              ),
          ],
        ),
        OptionGroup(
          label: 'Fit',
          children: <Widget>[
            for (final (ComicFit f, String label) in <(ComicFit, String)>[
              (ComicFit.width, 'Width'),
              (ComicFit.height, 'Height'),
              (ComicFit.screen, 'Screen'),
            ])
              OptionTile(
                label: label,
                height: 40,
                selected: p.fit == f,
                onTap: () => ctl.update((ComicPrefs x) => x.copyWith(fit: f)),
              ),
          ],
        ),
        ExplorerRow(
          name: 'Right to left (manga)',
          meta: 'Mirrors swipes and the scrubber',
          sansMeta: true,
          minHeight: 56,
          switchValue: _rtl,
          onSwitch: (bool v) {
            setState(() => _rtl = v);
            widget.onRtl(v);
          },
        ),
        ExplorerRow(
          name: 'Two pages in landscape',
          meta: 'Automatic on wide screens',
          sansMeta: true,
          minHeight: 56,
          switchValue: p.spreadInLandscape,
          onSwitch: (bool v) => ctl.update((ComicPrefs x) => x.copyWith(spreadInLandscape: v)),
        ),
        ExplorerRow(
          name: 'Show the cover on its own',
          meta: 'Keeps spreads aligned',
          sansMeta: true,
          minHeight: 56,
          switchValue: p.coverAlone,
          onSwitch: (bool v) => ctl.update((ComicPrefs x) => x.copyWith(coverAlone: v)),
        ),
        OptionGroup(
          label: 'Page surround',
          children: <Widget>[
            for (final ReadingThemeId id in ComicPrefs.surrounds)
              Builder(
                builder: (BuildContext context) {
                  final ReadingTheme t = ReadingTheme.of(family, id);
                  return OptionTile(
                    label: t.name,
                    height: 44,
                    background: t.paper,
                    foreground: t.ink,
                    selected: (p.surround ?? ReadingThemeId.light) == id,
                    onTap: () => ctl.update((ComicPrefs x) => x.copyWith(surround: id)),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// Board 6, V4 "Bookmarks": a row per bookmarked page with its thumbnail,
/// and "Bookmark this page".
Future<void> showComicBookmarks(
  BuildContext context, {
  required ComicPages pages,
  required List<Annotation> bookmarks,
  required int current,
  required ValueChanged<int> onOpen,
  required ValueChanged<Annotation> onDelete,
  required VoidCallback onAdd,
}) => showReaderSheet<void>(context, surface: true, (BuildContext ctx) {
  final UnfurlColors c = ctx.colors;
  final List<(Annotation, int)> rows = <(Annotation, int)>[
    for (final Annotation a in bookmarks) (a, ((a.progress * pages.count).round() - 1).clamp(0, pages.count - 1)),
  ]..sort(((Annotation, int) a, (Annotation, int) b) => a.$2.compareTo(b.$2));
  final bool here = rows.any(((Annotation, int) r) => r.$2 == current);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      SheetHead(
        title: 'Bookmarks',
        subtitle: rows.isEmpty ? 'No bookmarks yet' : (rows.length == 1 ? '1 page' : '${rows.length} pages'),
      ),
      for (final (Annotation a, int page) in rows)
        InkWell(
          onTap: () {
            Navigator.of(ctx).pop();
            onOpen(page);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.xs, Space.sm),
              child: Row(
                spacing: 14,
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 46,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: c.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: c.outline),
                    ),
                    child: FutureBuilder<File?>(
                      initialData: pages.thumbNow(page),
                      future: pages.thumb(page),
                      builder: (BuildContext context, AsyncSnapshot<File?> s) => s.data == null
                          ? const SizedBox.shrink()
                          : Image(
                              image: ResizeImage(FileImage(s.data!), width: ComicPages.thumbWidth),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 3,
                      children: <Widget>[
                        Text('Page ${page + 1}', style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
                        Text(
                          'Added ${Files.when(a.createdAt.millisecondsSinceEpoch).replaceFirst('Today', 'today')}'
                          '${page == current ? ' · current page' : ''}',
                          style: UnfurlType.bodySmall.copyWith(height: 1.45, color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  AppIconButton(
                    icon: AppIcons.bookmarkRemove,
                    filled: false,
                    semanticLabel: 'Remove bookmark on page ${page + 1}',
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onDelete(a);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
        child: AppButton(
          label: here ? 'This page is bookmarked' : 'Bookmark this page',
          icon: AppIcons.bookmarkAdd,
          type: AppButtonType.secondary,
          onPressed: here
              ? null
              : () {
                  Navigator.of(ctx).pop();
                  onAdd();
                },
        ),
      ),
    ],
  );
});
