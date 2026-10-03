import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/reading_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_header.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/app_snackbar.dart';
import '../../design_system/buttons.dart';
import '../../design_system/chips.dart';
import '../../design_system/containers.dart';
import '../../design_system/sheets.dart';
import '../reader/reading_prefs.dart';
import '../reader/sheets.dart';
import 'settings_controller.dart';

/// Board 2, A5 Settings: reading defaults, PDF, library; then appearance, as
/// Mull keeps it, under a Theme page.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static String modeLabel(ThemeMode m) => switch (m) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final ReadingPrefs p = ref.watch(readingPrefsProvider);
    final AppSettings s = ref.watch(settingsProvider);
    final ReadingPrefsController ctl = ref.read(readingPrefsProvider.notifier);
    final int folders = (ref.watch(foldersProvider).value ?? const <Folder>[]).length;
    final ReadingThemeId current = p.themeFor(darkChrome: c.isDark, amoledChrome: c.tone == Tone.amoled);
    return AppScaffold(
      title: 'Settings',
      onBack: () => context.pop(),
      children: <Widget>[
        const SectionHeader(label: 'Reading defaults'),
        const SizedBox(height: 10),
        ListContainer(
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
                child: Row(
                  spacing: Space.md,
                  children: <Widget>[
                    Expanded(
                      child: Text('Theme', style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
                    ),
                    for (final ReadingThemeId id in ReadingThemeId.values)
                      ThemeSwatch(
                        theme: ReadingTheme.of(ThemeFamily.saffron, id),
                        selected: id == current,
                        letters: false,
                        size: 30,
                        semantic: '${ReadingTheme.names[id.index]} page',
                        onTap: () => ctl.update((ReadingPrefs x) => x.copyWith(theme: id)),
                      ),
                  ],
                ),
              ),
            ),
            ListRow(
              label: 'Font',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    p.font.label,
                    style: TextStyle(fontFamily: p.font.family, fontSize: 15, color: c.onSurfaceVariant),
                  ),
                  AppIcon(AppIcons.chevronRight, color: c.iconMuted),
                ],
              ),
              onTap: () => _pickFont(context, ref),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: <Widget>[
                  Text('Page turn', style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
                  SegmentedToggle<PageTurn>(
                    options: const <(PageTurn, String, IconData?)>[
                      (PageTurn.slide, 'Slide', null),
                      (PageTurn.fade, 'Fade', null),
                      (PageTurn.none, 'None', null),
                    ],
                    selected: p.pageTurn,
                    onChanged: (PageTurn v) => ctl.update((ReadingPrefs x) => x.copyWith(pageTurn: v)),
                  ),
                ],
              ),
            ),
            ListRow(
              label: 'Keep screen on',
              trailing: Switch(
                value: p.keepScreenOn,
                onChanged: (bool v) => ctl.update((ReadingPrefs x) => x.copyWith(keepScreenOn: v)),
              ),
            ),
            ListRow(
              label: 'Volume keys turn pages',
              subtitle: 'Only while a book is open',
              trailing: Switch(
                value: p.volumeKeys,
                onChanged: (bool v) => ctl.update((ReadingPrefs x) => x.copyWith(volumeKeys: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        const SectionHeader(label: 'PDF'),
        const SizedBox(height: 10),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: <Widget>[
              Text('PDFs open in', style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
              SegmentedToggle<bool>(
                options: const <(bool, String, IconData?)>[
                  (false, 'Page', AppIcons.article),
                  (true, 'Reader', AppIcons.wrapText),
                ],
                selected: p.pdfOpensReader,
                onChanged: (bool v) => ctl.update((ReadingPrefs x) => x.copyWith(pdfOpensReader: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        const SectionHeader(label: 'Library'),
        const SizedBox(height: 10),
        ListContainer(
          children: <Widget>[
            ListRow(label: 'Folders', value: '$folders', onTap: () => context.push(Routes.folders)),
            ListRow(
              label: 'Clear recents',
              danger: true,
              onTap: () async {
                final bool ok = await confirmClear(context);
                if (!ok) return;
                await ref.read(libraryProvider).clearRecents();
                if (context.mounted) AppSnackbar.info(context, 'Recents cleared. Positions and notes are kept.');
              },
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        const SectionHeader(label: 'Appearance'),
        const SizedBox(height: 10),
        ListContainer(
          children: <Widget>[
            ListRow(
              label: 'Theme',
              value:
                  '${s.dynamicColor && s.wallpaperSeed != null ? 'Wallpaper' : 'Saffron'} · ${modeLabel(s.themeMode)}',
              onTap: () => context.push(Routes.theme),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        Text(
          'Unfurl keeps everything on this phone. Nothing here leaves it.',
          style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceMuted),
        ),
      ],
    );
  }

  static Future<bool> confirmClear(BuildContext context) async =>
      await showAppBottomSheet<bool>(
        context: context,
        title: 'Clear recents?',
        description: 'Home forgets what you opened. Reading positions, highlights and notes stay.',
        builder: (BuildContext ctx) => const SizedBox.shrink(),
        actions: <Widget>[
          Builder(builder: (BuildContext ctx) => _DangerButton(onTap: () => Navigator.of(ctx).pop(true))),
          Builder(
            builder: (BuildContext ctx) =>
                AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Navigator.of(ctx).pop(false)),
          ),
        ],
      ) ??
      false;

  static Future<void> _pickFont(BuildContext context, WidgetRef ref) =>
      showReaderSheet<void>(context, (BuildContext ctx) {
        final UnfurlColors c = ctx.colors;
        return Consumer(
          builder: (BuildContext ctx, WidgetRef ref, _) {
            final ReadingPrefs p = ref.watch(readingPrefsProvider);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: Text('Font', style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
                ),
                for (final ReaderFont f in ReaderFont.values)
                  Semantics(
                    button: true,
                    selected: f == p.font,
                    child: InkWell(
                      borderRadius: Radii.thumbR,
                      onTap: () {
                        ref.read(readingPrefsProvider.notifier).update((ReadingPrefs x) => x.copyWith(font: f));
                        Navigator.of(ctx).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    f.family,
                                    style: TextStyle(fontFamily: f.family, fontSize: 18, color: c.onSurface),
                                  ),
                                  Text(f.note, style: UnfurlType.bodySmall.copyWith(color: c.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            AppIcon(AppIcons.check, color: f == p.font ? c.primary : Colors.transparent),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      });
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Material(
      color: c.dangerContainer,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text('Clear recents', style: UnfurlType.titleMedium.copyWith(color: c.onDangerContainer)),
          ),
        ),
      ),
    );
  }
}
