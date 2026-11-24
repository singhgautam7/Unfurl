import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/explorer.dart';
import '../../core/motion/kit.dart';
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
import '../../design_system/header_preview.dart';
import '../../design_system/sheets.dart';
import '../files/files_screen.dart' show askForAccess;
import '../reader/reading_prefs.dart';
import '../reader/sheets.dart';
import 'settings_controller.dart';

/// Board 2, A5 Settings: reading defaults, PDF, library; then appearance, as
/// Mull keeps it, under a Theme page.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    // Only what this page shows: nothing else in the prefs rebuilds it.
    final bool pdfReader = ref.watch(readingPrefsProvider.select((ReadingPrefs p) => p.pdfOpensReader));
    final ReadingPrefsController ctl = ref.read(readingPrefsProvider.notifier);
    return AppScaffold(
      title: 'Settings',
      onBack: () => context.pop(),
      children: <Widget>[
        // The app's look, then the reader's: each its own page, as Mull keeps Theme.
        const SectionHeader(label: 'Appearance'),
        const SizedBox(height: 10),
        ListContainer(
          children: <Widget>[
            ListRow(
              icon: AppIcons.palette,
              label: 'Theme',
              subtitle: 'Colours, dark mode, wallpaper',
              onTap: () => context.push(Routes.theme),
            ),
            ListRow(
              icon: AppIcons.menuBook,
              label: 'Reader',
              subtitle: 'Page colours, font, text size',
              onTap: () => context.push(Routes.reader),
            ),
            ListRow(
              icon: AppIcons.touchApp,
              label: 'Controls',
              subtitle: 'Volume buttons for turning pages',
              onTap: () => context.push(Routes.controls),
            ),
            // Haptics and the floating header sit beside Theme, as in Kuber's Look and feel.
            Consumer(
              builder: (BuildContext context, WidgetRef ref, _) => ListRow(
                icon: AppIcons.vibration,
                label: 'Haptics',
                subtitle: 'A light tap when you switch, select or confirm',
                switchValue: ref.watch(settingsProvider.select((AppSettings s) => s.haptics)),
                onChanged: (bool v) {
                  unawaited(ref.read(settingsProvider.notifier).setHaptics(value: v));
                  // The tick confirms the new state (it only sounds when on,
                  // and never twice within 50 ms).
                  Haptics.tick();
                },
              ),
            ),
            Consumer(
              builder: (BuildContext context, WidgetRef ref, _) {
                final (bool on, PillMode mode) = ref.watch(
                  settingsProvider.select((AppSettings s) => (s.floatingHeader, s.pillMode)),
                );
                return ListRow(
                  icon: AppIcons.viewDay,
                  label: 'Floating header',
                  subtitle: on ? _pillNames[mode]! : 'Off',
                  onTap: () => _floatingHeader(context),
                );
              },
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
                selected: pdfReader,
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
            final bool findOnDevice = ref.watch(settingsProvider.select((AppSettings s) => s.findOnDevice));
            final bool showHidden = ref.watch(settingsProvider.select((AppSettings s) => s.showHidden));
            return ListContainer(
              children: <Widget>[
                if (kAllFilesAccess)
                  ListRow(
                    icon: AppIcons.folderOpen,
                    label: 'All files access',
                    subtitle: access ? 'On, Files browses the whole phone' : 'Off, needed to browse the whole phone',
                    onTap: () => askForAccess(context, ref),
                  ),
                // Left out while access is off: a control that can't apply.
                if (kAllFilesAccess && access)
                  ListRow(
                    icon: AppIcons.search,
                    label: 'Find books across this device',
                    subtitle: 'Library lists every book on the phone',
                    switchValue: findOnDevice,
                    onChanged: (bool v) async {
                      await ref.read(settingsProvider.notifier).setFindOnDevice(value: v);
                      await ref.read(libraryProvider).setFindOnDevice(on: v);
                    },
                  ),
                ListRow(
                  icon: AppIcons.visibility,
                  label: 'Show hidden files',
                  subtitle: 'Default for every folder',
                  switchValue: showHidden,
                  onChanged: (bool v) => ref.read(settingsProvider.notifier).setShowHidden(value: v),
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
            ListRow(
              icon: AppIcons.folder,
              label: 'Folders',
              subtitle: 'Where Unfurl looks for books',
              onTap: () => context.push(Routes.folders),
            ),
            ListRow(
              icon: AppIcons.delete,
              label: 'Clear recents',
              subtitle: 'Home forgets what you opened',
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

  static const Map<PillMode, String> _pillNames = <PillMode, String>{
    PillMode.always: 'Always',
    PillMode.scrollUp: 'When scrolling up',
    PillMode.scrollStop: 'When scrolling stops',
  };

  /// Kuber's floating header sheet: the switch, then when the pill shows. A
  /// choice applies at once; the sheet stays open to compare.
  static Future<void> _floatingHeader(BuildContext context) => showAppBottomSheet<void>(
    context: context,
    title: 'Floating header',
    description: 'The title bar becomes a pill as you scroll',
    builder: (BuildContext ctx) => Consumer(
      builder: (BuildContext ctx, WidgetRef ref, _) {
        final (bool on, PillMode mode) = ref.watch(
          settingsProvider.select((AppSettings s) => (s.floatingHeader, s.pillMode)),
        );
        final SettingsController ctl = ref.read(settingsProvider.notifier);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListContainer(
              children: <Widget>[
                ListRow(
                  icon: AppIcons.viewDay,
                  label: 'Use the floating header',
                  subtitle: on ? 'On' : 'Off, the title bar scrolls away with the page',
                  switchValue: on,
                  onChanged: (bool v) => ctl.setFloatingHeader(value: v),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            const SectionHeader(label: 'Show the pill'),
            for (final MapEntry<PillMode, String> e in _pillNames.entries) ...<Widget>[
              const SizedBox(height: Space.sm),
              HeaderPreviewCard(
                label: e.value,
                pillMode: e.key,
                selected: on && mode == e.key,
                enabled: on,
                onTap: () {
                  Haptics.tick();
                  unawaited(ctl.setPillMode(e.key));
                },
              ),
            ],
          ],
        );
      },
    ),
  );

  static Future<bool> confirmClear(BuildContext context) async =>
      await showAppBottomSheet<bool>(
        context: context,
        title: 'Clear recents?',
        description: 'Home forgets what you opened. Reading positions, highlights and notes stay.',
        builder: (BuildContext ctx) => const SizedBox.shrink(),
        actions: <Widget>[
          Builder(
            builder: (BuildContext ctx) => SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Clear recents',
                type: AppButtonType.danger,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ),
          ),
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
                    child: PressableRow(
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
              icon: AppIcons.textFields,
              label: 'Font',
              subtitle: p.font.label,
              onTap: () => SettingsScreen.pickFont(context, ref),
            ),
            const _ControlRow(
              label: 'Text size',
              child: SizedBox(width: 168, child: TextSizeControl()),
            ),
            const _ControlRow(label: 'Line spacing', child: LineSpacingControl()),
            const _ControlRow(label: 'Margins', stacked: true, child: MarginsControl()),
            const _ControlRow(label: 'Align', child: AlignControl()),
            const _ControlRow(label: 'Layout', stacked: true, child: LayoutControl()),
            ShowHide(
              visible: p.layout == ReaderLayout.paged,
              child: const _ControlRow(label: 'Page turn', stacked: true, child: PageTurnControl()),
            ),
            ListRow(
              icon: AppIcons.wrapText,
              label: 'Hyphenation',
              subtitle: 'Break long words at line ends',
              switchValue: p.hyphenate,
              onChanged: (bool v) => ctl.update((ReadingPrefs x) => x.copyWith(hyphenate: v)),
            ),
            const BrightnessRow(labelled: true, live: false, inset: Space.lg),
            ListRow(
              icon: AppIcons.brightness,
              label: 'Keep screen on',
              subtitle: 'The screen stays lit while you read',
              switchValue: p.keepScreenOn,
              onChanged: (bool v) => ctl.update((ReadingPrefs x) => x.copyWith(keepScreenOn: v)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Settings › Controls (board 6, V6): volume buttons. They turn pages in
/// paged modes, scroll about a screen in continuous ones and step through
/// comics; never while read aloud plays. Off by default.
class ControlsScreen extends ConsumerWidget {
  const ControlsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReadingPrefs p = ref.watch(readingPrefsProvider);
    final ReadingPrefsController ctl = ref.read(readingPrefsProvider.notifier);
    final UnfurlColors c = context.colors;
    return AppScaffold(
      title: 'Controls',
      onBack: () => context.pop(),
      children: <Widget>[
        const SectionHeader(label: 'Volume buttons'),
        const SizedBox(height: 10),
        ListContainer(
          children: <Widget>[
            ListRow(
              icon: AppIcons.volumeUp,
              label: 'Turn pages with volume buttons',
              subtitle: 'Next or previous page, or about a screen',
              switchValue: p.volumeKeys,
              onChanged: (bool v) => ctl.update((ReadingPrefs x) => x.copyWith(volumeKeys: v)),
            ),
            ListRow(
              icon: AppIcons.swapVert,
              label: 'Invert direction',
              subtitle: 'Volume up goes forward',
              switchValue: p.volumeInvert,
              enabled: p.volumeKeys,
              onChanged: (bool v) => ctl.update((ReadingPrefs x) => x.copyWith(volumeInvert: v)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.xs, 0),
          child: Text(
            'While read aloud is playing, the volume buttons change the volume.',
            style: UnfurlType.note.copyWith(height: 1.5, color: c.onSurfaceVariant),
          ),
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
