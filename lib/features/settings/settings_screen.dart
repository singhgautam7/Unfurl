import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/explorer.dart';
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
import '../files/files_screen.dart' show askForAccess;
import '../files/files_widgets.dart';
import '../reader/reading_prefs.dart';
import '../reader/sheets.dart';
import 'settings_controller.dart';

/// Board 2, A5 Settings: reading defaults, PDF, library; then appearance, as
/// Mull keeps it, under a Theme page.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// "Wallpaper · System": the app theme as one line (Settings, More).
  static String themeSummary(AppSettings s) =>
      '${s.dynamicColor && s.wallpaperSeed != null ? 'Wallpaper' : s.family.name} · ${modeLabel(s.themeMode)}';

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
        // The app's look, then the reader's: each its own page, as Mull keeps Theme.
        const SectionHeader(label: 'Appearance'),
        const SizedBox(height: 10),
        ListContainer(
          children: <Widget>[
            ListRow(label: 'Theme', value: themeSummary(s), onTap: () => context.push(Routes.theme)),
            ListRow(
              label: 'Reader',
              value: '${ReadingTheme.names[current.index]} · ${p.font.label} · ${p.size.round()}',
              onTap: () => context.push(Routes.reader),
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
        const SectionHeader(label: 'Library and files'),
        const SizedBox(height: 10),
        Consumer(
          builder: (BuildContext context, WidgetRef ref, _) {
            final bool access = ref.watch(filesAccessProvider.select((FilesAccess a) => a.granted));
            return ListContainer(
              children: <Widget>[
                ExplorerRow(
                  name: 'All files access',
                  meta: access
                      ? 'Lets Files browse the whole phone'
                      : 'Off. Needed to browse the whole phone and to find books everywhere.',
                  sansMeta: true,
                  status: access ? 'On' : 'Off',
                  statusOn: access,
                  trailing: AppIcons.openInNew,
                  onTap: () => askForAccess(context, ref),
                ),
                // Left out while access is off: a control that can't apply.
                if (access)
                  ExplorerRow(
                    name: 'Find books across this device',
                    meta: 'Books lists every PDF and EPUB on the phone',
                    sansMeta: true,
                    switchValue: s.findOnDevice,
                    onSwitch: (bool v) async {
                      await ref.read(settingsProvider.notifier).setFindOnDevice(value: v);
                      await ref.read(libraryProvider).setFindOnDevice(on: v);
                    },
                  ),
                ExplorerRow(
                  name: 'Show hidden files',
                  meta: 'Default for every folder. Change it per folder from the folder menu.',
                  sansMeta: true,
                  switchValue: s.showHidden,
                  onSwitch: (bool v) => ref.read(settingsProvider.notifier).setShowHidden(value: v),
                ),
              ],
            );
          },
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

  static Future<void> pickFont(BuildContext context, WidgetRef ref) =>
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

/// Settings › Reader: every Reading settings control, as the defaults each
/// book opens with (the sheet in a book changes the same values).
class ReaderSettingsScreen extends ConsumerWidget {
  const ReaderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final ReadingPrefs p = ref.watch(readingPrefsProvider);
    final ReadingPrefsController ctl = ref.read(readingPrefsProvider.notifier);
    final ReadingThemeId current = p.themeFor(darkChrome: c.isDark, amoledChrome: c.tone == Tone.amoled);
    return AppScaffold(
      title: 'Reader',
      onBack: () => context.pop(),
      children: <Widget>[
        ListContainer(
          children: <Widget>[
            // Seven swatches stacked under the label (v2 · V2-02).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Expanded(
                        child: Text('Reader colours', style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
                      ),
                      Text(
                        p.theme == null ? 'Auto' : ReadingTheme.names[current.index],
                        style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
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
                ],
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
              onTap: () => SettingsScreen.pickFont(context, ref),
            ),
            const _ControlRow(
              label: 'Text size',
              child: SizedBox(width: 168, child: TextSizeControl()),
            ),
            const _ControlRow(label: 'Line spacing', child: LineSpacingControl()),
            const _ControlRow(label: 'Margins', stacked: true, child: MarginsControl()),
            const _ControlRow(label: 'Align', child: AlignControl()),
            const _ControlRow(label: 'Layout', child: LayoutControl()),
            if (p.layout == ReaderLayout.paged)
              const _ControlRow(label: 'Page turn', stacked: true, child: PageTurnControl()),
            ListRow(
              label: 'Hyphenation',
              trailing: Switch(
                value: p.hyphenate,
                onChanged: (bool v) => ctl.update((ReadingPrefs x) => x.copyWith(hyphenate: v)),
              ),
            ),
            const BrightnessRow(labelled: true, live: false, inset: Space.lg),
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
      ],
    );
  }
}

/// A Reader setting: its name, and the same control the Reading settings
/// sheet shows, beside it or ([stacked]) under it.
class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.label, required this.child, this.stacked = false});

  final String label;
  final Widget child;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final Widget title = Text(label, style: UnfurlType.titleMedium.copyWith(color: context.colors.onSurface));
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Space.lg, vertical: stacked ? 14 : Space.sm),
      child: stacked
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: <Widget>[title, child])
          : Row(
              children: <Widget>[
                Expanded(child: title),
                child,
              ],
            ),
    );
  }
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
