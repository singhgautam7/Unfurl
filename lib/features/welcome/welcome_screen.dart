import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout.dart';
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

/// Board 2, A0: four pages on first launch. The pages scroll; one action
/// row stays put beneath them (a text action left, the main action right)
/// and its labels change with a short slide and fade as the page turns.
/// The nav pill appears once the flow ends.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

/// One page's actions: the quiet one on the left, the main one on the right.
typedef _Actions = ({String quiet, VoidCallback onQuiet, String main, IconData mainIcon, VoidCallback onMain});

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

  Future<void> _addFolder({required bool advance}) async {
    final Folder? f = await addFolderFlow(context, ref, explain: false);
    if (f == null || !mounted) return;
    setState(() => _added = f);
    if (advance) _go(3);
  }

  Future<void> _openFile() async {
    await ref.read(settingsProvider.notifier).setOnboarded();
    if (!mounted) return;
    context.go(Routes.home);
    await pickAndOpenFile(rootNavigatorKey.currentContext ?? context);
  }

  _Actions get _actions => switch (_page) {
    0 || 1 => (
      quiet: 'Skip',
      onQuiet: () => _go(2),
      main: 'Next',
      mainIcon: AppIcons.arrowForward,
      onMain: () => _go(_page + 1),
    ),
    2 => (
      quiet: 'Skip for now',
      onQuiet: () => _go(3),
      main: 'Choose a folder',
      mainIcon: AppIcons.folderOpen,
      onMain: () => _addFolder(advance: true),
    ),
    _ => (quiet: 'Go to Home', onQuiet: _finish, main: 'Open file', mainIcon: AppIcons.fileOpen, onMain: _openFile),
  };

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final Map<int, int> counts = ref.watch(readableCountsProvider).value ?? const <int, int>{};
    final _Actions a = _actions;
    return Scaffold(
      body: SafeArea(
        child: Center(
          // The pages centre at 720dp on wide windows, as More does.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AdaptiveSpec.centred),
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
                            decoration: BoxDecoration(
                              color: i == _page ? c.primary : c.outline,
                              borderRadius: Radii.fullR,
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
                      const _Page(
                        art: UnfurlMark(),
                        title: 'Open a file and start reading',
                        body: 'PDFs and books open where you left off, in the font, size and theme you choose.',
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
                                (
                                  AppIcons.folder,
                                  'It sees only the folders you pick, and you can remove access any time.',
                                ),
                                (AppIcons.shield, 'Unfurl has no internet access, so nothing can leave your phone.'),
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
                                        child: Text(
                                          t,
                                          style: UnfurlType.note.copyWith(height: 1.5, color: c.onSurface),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        note:
                            'Android doesn’t allow picking the whole Download folder, but any folder inside it works.',
                      ),
                      _Page(
                        art: const _Tile(icon: AppIcons.doneAll),
                        title: 'Get started',
                        body: _added == null
                            ? 'Open something now, or add a folder.'
                            : 'Books added: ${readableFiles(counts[_added!.id] ?? 0)} in ${_added!.name}. Open something now, or add another folder.',
                        extra: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: AppButton(
                            label: _added == null ? 'Add a folder' : 'Add another folder',
                            icon: AppIcons.createNewFolder,
                            type: AppButtonType.secondary,
                            height: 48,
                            onPressed: () => _addFolder(advance: false),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, Space.xl),
                  child: Row(
                    spacing: Space.md,
                    children: <Widget>[
                      AnimatedSize(
                        duration: Motion.of(context, Motion.containerTransform),
                        curve: Motion.decelerate,
                        child: _Swap(
                          id: a.quiet,
                          child: AppButton(label: a.quiet, type: AppButtonType.text, onPressed: a.onQuiet),
                        ),
                      ),
                      Expanded(
                        child: _Swap(
                          id: a.main,
                          child: SizedBox(
                            width: double.infinity,
                            child: AppButton(label: a.main, icon: a.mainIcon, onPressed: a.onMain),
                          ),
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
    );
  }
}

/// A button whose label changed: the old one fades, then the new one rises in.
class _Swap extends StatelessWidget {
  const _Swap({required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.of(context, Motion.containerTransform),
    // In sequence, never both at once: the old label is gone by 40%, the
    // new one rises in after it.
    switchInCurve: const Interval(0.4, 1, curve: Motion.decelerate),
    switchOutCurve: const Interval(0.6, 1, curve: Motion.decelerate),
    transitionBuilder: (Widget child, Animation<double> t) => FadeTransition(
      opacity: t,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(t),
        child: child,
      ),
    ),
    child: KeyedSubtree(key: ValueKey<String>(id), child: child),
  );
}

/// One welcome page: everything scrolls, the note included.
class _Page extends StatelessWidget {
  const _Page({required this.art, required this.title, required this.body, this.extra, this.note});

  final Widget art;
  final String title;
  final String body;
  final Widget? extra;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.screen,
        children: <Widget>[
          art,
          Text(title, style: UnfurlType.display.copyWith(color: c.onSurface)),
          Text(body, style: UnfurlType.body.copyWith(color: c.onSurfaceVariant)),
          ?extra,
          if (note != null) Text(note!, style: UnfurlType.monoLabel.copyWith(height: 1.5, color: c.onSurfaceVariant)),
        ],
      ),
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
    // Sized to its label (the board's 36dp tile); an aligned Container
    // would stretch to the Wrap's width.
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      decoration: BoxDecoration(color: tier1 ? c.primary : c.primaryContainer, borderRadius: BorderRadius.circular(10)),
      child: Align(
        widthFactor: 1,
        child: Text(
          label,
          style: UnfurlType.monoTabular.copyWith(
            fontWeight: FontWeight.w600,
            color: tier1 ? c.onPrimary : c.onPrimaryContainer,
          ),
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
