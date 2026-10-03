import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/library/library.dart' show readableFiles;
import '../../core/motion/motion.dart';
import '../../core/open.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/buttons.dart';
import '../settings/info_screens.dart';
import '../settings/settings_controller.dart';

/// Board 2, A0: four pages on first launch. Start and Formats can be
/// skipped straight to Folders. The nav pill appears once the flow ends.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final PageController _pages = PageController();
  int _page = 0;
  Folder? _added;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    unawaited(
      _pages.animateToPage(page, duration: Motion.of(context, Motion.containerTransform), curve: Motion.decelerate),
    );
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).setOnboarded();
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final Map<int, int> counts = ref.watch(readableCountsProvider).value ?? const <int, int>{};
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, Space.sm, Space.md, Space.sm),
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < 4; i++)
                      AnimatedContainer(
                        duration: Motion.of(context, Motion.navIndicator),
                        curve: Motion.curveOf(context, Motion.spring),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _page ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(color: i == _page ? c.primary : c.outline, borderRadius: Radii.fullR),
                      ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _page < 2 ? 1 : 0,
                      duration: Motion.of(context, Motion.fast),
                      child: IgnorePointer(
                        ignoring: _page >= 2,
                        child: AppButton(label: 'Skip', type: AppButtonType.text, height: 48, onPressed: () => _go(2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (int i) => setState(() => _page = i),
                children: <Widget>[
                  _Page(
                    art: const UnfurlMark(),
                    title: 'Open a file and start reading',
                    body: 'PDFs and books open where you left off, in the font, size and theme you choose.',
                    actions: <Widget>[AppButton(label: 'Next', icon: AppIcons.arrowForward, onPressed: () => _go(1))],
                  ),
                  _Page(
                    art: Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: <Widget>[
                        for (final String f in <String>['PDF', 'EPUB']) _FormatChip(f, tier1: true),
                        for (final String f in <String>[
                          'DOCX',
                          'PPTX',
                          'XLSX',
                          'XLS',
                          'ODS',
                          'CSV',
                          'MD',
                          'TXT',
                          'JPG',
                          'PNG',
                          'WEBP',
                        ])
                          _FormatChip(f, tier1: false),
                      ],
                    ),
                    title: 'Opens more than books',
                    body: 'Documents, slides, sheets, notes and images open too. Any of them with text can unfurl into Reader mode.',
                    extra: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: Space.sm,
                      children: <Widget>[
                        _Legend(color: c.primary, text: 'Full reader: bookmarks, highlights, read aloud'),
                        _Legend(color: c.primaryContainer, text: 'Viewer, plus Reader mode for text'),
                      ],
                    ),
                    actions: <Widget>[AppButton(label: 'Next', icon: AppIcons.arrowForward, onPressed: () => _go(2))],
                  ),
                  _Page(
                    art: const _Tile(icon: AppIcons.folderOpen),
                    title: 'Choose where your books live',
                    body: 'Pick a folder and Unfurl lists what it can open inside it, including subfolders.',
                    extra: Container(
                      decoration: BoxDecoration(
                        color: c.surfaceContainer,
                        borderRadius: Radii.cardR,
                        border: Border.all(color: c.outline),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: <Widget>[
                          for (final (IconData i, String t) in <(IconData, String)>[
                            (AppIcons.visibility, 'Read only. Unfurl never edits, moves or deletes your files.'),
                            (AppIcons.folder, 'It sees only the folders you pick, and you can remove access any time.'),
                            (AppIcons.shield, 'Works offline, needs no permissions, nothing leaves your phone.'),
                          ]) ...<Widget>[
                            if (i != AppIcons.visibility) Divider(color: c.divider),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: Space.md,
                                children: <Widget>[
                                  AppIcon(i, size: 22, color: c.icon),
                                  Expanded(
                                    child: Text(t, style: UnfurlType.note.copyWith(height: 1.5, color: c.onSurface)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    note: 'Android doesn’t allow picking the whole Download folder, but any folder inside it works.',
                    actions: <Widget>[
                      AppButton(
                        label: 'Choose a folder',
                        icon: AppIcons.folderOpen,
                        onPressed: () async {
                          final Folder? f = await addFolderFlow(context, ref, explain: false);
                          if (f != null) {
                            setState(() => _added = f);
                            _go(3);
                          }
                        },
                      ),
                      AppButton(label: 'Skip for now', type: AppButtonType.secondary, onPressed: () => _go(3)),
                    ],
                  ),
                  _Page(
                    art: const _Tile(icon: AppIcons.doneAll),
                    title: 'Get started',
                    body: _added == null
                        ? 'Open something now, or add a folder.'
                        : 'Books added: ${readableFiles(counts[_added!.id] ?? 0)} in ${_added!.name}. Open something now, or add another folder.',
                    actions: <Widget>[
                      AppButton(
                        label: 'Open file',
                        icon: AppIcons.fileOpen,
                        onPressed: () async {
                          await ref.read(settingsProvider.notifier).setOnboarded();
                          if (!context.mounted) return;
                          context.go(Routes.home);
                          await pickAndOpenFile(rootNavigatorKey.currentContext ?? context);
                        },
                      ),
                      AppButton(
                        label: _added == null ? 'Add a folder' : 'Add another folder',
                        type: AppButtonType.secondary,
                        onPressed: () async {
                          final Folder? f = await addFolderFlow(context, ref, explain: false);
                          if (f != null) setState(() => _added = f);
                        },
                      ),
                      AppButton(label: 'Go to Home', type: AppButtonType.accent, height: 48, onPressed: _finish),
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
}

class _Page extends StatelessWidget {
  const _Page({
    required this.art,
    required this.title,
    required this.body,
    required this.actions,
    this.extra,
    this.note,
  });

  final Widget art;
  final String title;
  final String body;
  final Widget? extra;
  final String? note;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.screen,
              children: <Widget>[
                art,
                Text(title, style: UnfurlType.display.copyWith(color: c.onSurface)),
                Text(body, style: UnfurlType.body.copyWith(color: c.onSurfaceVariant)),
                ?extra,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: <Widget>[
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.xs),
                  child: Text(
                    note!,
                    textAlign: TextAlign.center,
                    style: UnfurlType.monoLabel.copyWith(height: 1.5, color: c.onSurfaceVariant),
                  ),
                ),
              ...actions,
            ],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: c.primaryContainer, borderRadius: Radii.cardR),
      child: AppIcon(icon, size: 32, color: c.onPrimaryContainer),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip(this.label, {required this.tier1});

  final String label;
  final bool tier1;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tier1 ? c.primary : c.primaryContainer, borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        style: UnfurlType.monoTabular.copyWith(
          fontWeight: FontWeight.w600,
          color: tier1 ? c.onPrimary : c.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 10,
    children: <Widget>[
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      ),
      Expanded(
        child: Text(text, style: UnfurlType.note.copyWith(height: 1.5, color: context.colors.onSurfaceVariant)),
      ),
    ],
  );
}
