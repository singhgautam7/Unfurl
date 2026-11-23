import 'dart:async';
import 'dart:math' as math;

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
import '../../design_system/containers.dart';
import '../settings/info_screens.dart';
import '../settings/settings_controller.dart';

/// First launch, as Kuber's onboarding: three short pages with dots, Skip at
/// the top right, Back and Next below; then one setup page every install
/// passes (Skip lands on it). Setup asks only what matters the first day:
/// Light, Dark or System, and a folder. The bar below has no fill of its own;
/// a page that does not fit scrolls and fades out above it. The nav pill
/// appears once the flow ends.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

/// One page's actions: the quiet one on the left (none on the first page),
/// the main one on the right.
typedef _Actions = ({String? quiet, VoidCallback? onQuiet, String main, IconData mainIcon, VoidCallback onMain});

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  /// Intro pages before the setup page.
  static const int _setup = 3;

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

  Future<void> _addFolder() async {
    final Folder? f = await addFolderFlow(context, ref, explain: false);
    if (f == null || !mounted) return;
    setState(() => _added = f);
  }

  Future<void> _openFile() async {
    await ref.read(settingsProvider.notifier).setOnboarded();
    if (!mounted) return;
    context.go(Routes.home);
    await pickAndOpenFile(rootNavigatorKey.currentContext ?? context);
  }

  _Actions get _actions => _page < _setup
      ? (
          quiet: _page == 0 ? null : 'Back',
          onQuiet: _page == 0 ? null : () => _go(_page - 1),
          main: 'Next',
          mainIcon: AppIcons.arrowForward,
          onMain: () => _go(_page + 1),
        )
      : _added == null
      ? (
          quiet: 'Skip for now',
          onQuiet: _finish,
          main: 'Choose a folder',
          mainIcon: AppIcons.folderOpen,
          onMain: _addFolder,
        )
      : (quiet: 'Add another', onQuiet: _addFolder, main: 'Get started', mainIcon: AppIcons.doneAll, onMain: _finish);

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final Map<int, int> counts = ref.watch(readableCountsProvider).value ?? const <int, int>{};
    final _Actions a = _actions;
    final bool large = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
    // The setup page's labels are long: its buttons stack, as at large text.
    final bool stacked = large || _page >= _setup;
    final Widget main = _Swap(
      id: a.main,
      child: SizedBox(
        width: double.infinity,
        // The glyph gives way to the label at large text.
        child: AppButton(label: a.main, icon: large ? null : a.mainIcon, onPressed: a.onMain),
      ),
    );
    final Widget? quiet = a.quiet == null
        ? null
        : _Swap(
            id: a.quiet!,
            child: AppButton(label: a.quiet!, type: AppButtonType.text, onPressed: a.onQuiet),
          );
    return PopScope(
      // Back goes to the page before; on the first page it leaves, as ever.
      canPop: _page == 0,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _go(_page - 1);
      },
      child: Scaffold(
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
                      padding: const EdgeInsets.fromLTRB(28, Space.sm, Space.sm, Space.sm),
                      child: Row(
                        children: <Widget>[
                          for (int i = 0; i <= _setup; i++)
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
                          const Spacer(),
                          // Skip lands on the setup page, never past it.
                          AnimatedOpacity(
                            opacity: _page < _setup ? 1 : 0,
                            duration: Motion.of(context, Motion.fast),
                            child: IgnorePointer(
                              ignoring: _page >= _setup,
                              child: ExcludeSemantics(
                                excluding: _page >= _setup,
                                child: AppButton(
                                  label: 'Skip',
                                  type: AppButtonType.text,
                                  height: 40,
                                  onPressed: () => _go(_setup),
                                ),
                              ),
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
                          // Nothing below the text; centred, the page doesn't
                          // sit on an empty lower half.
                          centred: true,
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
                              for (final String f in <String>['DOCX', 'PPTX', 'XLSX', 'CSV', 'MD', 'TXT', 'JPG', 'PNG'])
                                _FormatChip(f, tier1: false),
                            ],
                          ),
                          title: 'Opens more than books',
                          body: 'Documents, slides, sheets, notes and images open too. Any with text can unfurl into Reader mode.',
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
                          art: const _Tile(icon: AppIcons.lock),
                          title: 'Your files stay yours',
                          body: 'Unfurl only reads. Nothing is ever changed or sent anywhere.',
                          extra: SurfaceCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: <Widget>[
                                for (final (int n, IconData i, String t) in <(int, IconData, String)>[
                                  (0, AppIcons.editOff, 'It never edits, moves or deletes a file.'),
                                  (1, AppIcons.folder, 'It sees only the folders you pick.'),
                                  (2, AppIcons.shield, 'It has no internet access.'),
                                ]) ...<Widget>[
                                  if (n > 0) Divider(color: c.divider),
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
                        ),
                        _Page(
                          title: 'Set up Unfurl',
                          body: '',
                          extra: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: Space.md,
                            children: <Widget>[
                              const SectionHeader(label: 'Appearance'),
                              const ThemeControls(modeOnly: true),
                              const SizedBox(height: Space.xs),
                              const SectionHeader(label: 'Your books'),
                              Text(
                                _added == null
                                    ? 'Pick a folder and Unfurl lists what it can open inside it, subfolders too.'
                                    : '${readableFiles(counts[_added!.id] ?? 0)} found in ${_added!.name}.',
                                style: UnfurlType.body.copyWith(color: c.onSurfaceVariant),
                              ),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: AppButton(
                                  label: 'Open a file instead',
                                  // Outlined, so its edge lines up with the text above.
                                  type: AppButtonType.outline,
                                  height: 40,
                                  onPressed: _openFile,
                                ),
                              ),
                            ],
                          ),
                          note: 'Android doesn’t allow picking the whole Download folder, but any folder inside it works.',
                        ),
                      ],
                    ),
                  ),
                  // No background of its own: the page scrolls and fades out above it.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.lg),
                    child: stacked
                        // Stacked at large text, so no label is squeezed.
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: Space.xs,
                            children: <Widget>[main, ?quiet],
                          )
                        : Row(
                            spacing: Space.md,
                            children: <Widget>[
                              if (quiet != null)
                                AnimatedSize(
                                  duration: Motion.of(context, Motion.containerTransform),
                                  curve: Motion.decelerate,
                                  child: quiet,
                                ),
                              Expanded(child: main),
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

/// One welcome page: everything scrolls, the note included. A page that does
/// not fit fades out above the action bar instead of being cut off.
class _Page extends StatelessWidget {
  const _Page({this.art, required this.title, required this.body, this.extra, this.note, this.centred = false});

  /// In the middle of the page, text centred (a page with only a title).
  final bool centred;

  final Widget? art;
  final String title;
  final String body;
  final Widget? extra;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final TextAlign align = centred ? TextAlign.center : TextAlign.start;
    const EdgeInsets pad = EdgeInsets.fromLTRB(28, Space.lg, 28, Space.lg);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) => _FadeScroll(
        child: SingleChildScrollView(
          padding: pad,
          child: ConstrainedBox(
            // Still scrolls when the text is too big for the page.
            constraints: BoxConstraints(minHeight: centred ? box.maxHeight - pad.vertical : 0),
            child: Column(
              mainAxisAlignment: centred ? MainAxisAlignment.center : MainAxisAlignment.start,
              crossAxisAlignment: centred ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              spacing: Space.lg,
              children: <Widget>[
                ?art,
                Text(
                  title,
                  textAlign: align,
                  style: UnfurlType.display.copyWith(color: c.onSurface),
                ),
                if (body.isNotEmpty)
                  Text(
                    body,
                    textAlign: align,
                    style: UnfurlType.body.copyWith(color: c.onSurfaceVariant),
                  ),
                ?extra,
                if (note != null)
                  Text(note!, style: UnfurlType.monoLabel.copyWith(height: 1.5, color: c.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades the foot of a scroller while more lies below, and not otherwise.
class _FadeScroll extends StatefulWidget {
  const _FadeScroll({required this.child});

  final Widget child;

  @override
  State<_FadeScroll> createState() => _FadeScrollState();
}

class _FadeScrollState extends State<_FadeScroll> {
  static const double _fade = 32;
  final ValueNotifier<bool> _more = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _more.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetrics m) {
    _more.value = m.extentAfter > 1;
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollMetricsNotification>(
    onNotification: (ScrollMetricsNotification n) => _onMetrics(n.metrics),
    child: NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification n) => _onMetrics(n.metrics),
      child: ValueListenableBuilder<bool>(
        valueListenable: _more,
        child: widget.child,
        // Always a ShaderMask, so the scroller's state survives the switch.
        builder: (BuildContext context, bool more, Widget? child) => ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (Rect r) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Colors.black, Colors.black, more ? Colors.transparent : Colors.black],
            stops: <double>[0, 1 - _fade / math.max(r.height, _fade), 1],
          ).createShader(r),
          child: child,
        ),
      ),
    ),
  );
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
