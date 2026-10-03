import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/motion/motion.dart';
import '../../core/platform/platform.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/reading_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/buttons.dart';
import '../../design_system/chips.dart';
import '../../design_system/containers.dart';
import '../../design_system/covers.dart';
import '../settings/settings_controller.dart';
import 'reading_prefs.dart';

/// The frame every reader sheet shares (board 3): `surfaceContainer`, 28dp
/// top corners, a 1px outline on top, the handle. One sheet at a time.
class ReaderSheet extends StatelessWidget {
  const ReaderSheet({
    required this.child,
    this.heightFactor,
    this.padding = const EdgeInsets.fromLTRB(Space.screen, 10, Space.screen, 0),
    super.key,
  });

  final Widget child;

  /// A fixed height (Contents 0.9); null wraps the content.
  final double? heightFactor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final double h = MediaQuery.sizeOf(context).height;
    return Container(
      height: heightFactor == null ? null : h * heightFactor!,
      constraints: BoxConstraints(maxHeight: h * 0.94),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.sheetR,
        border: Border(top: BorderSide(color: c.outline)),
      ),
      padding: padding.copyWith(bottom: padding.bottom + MediaQuery.paddingOf(context).bottom + Space.lg),
      child: Column(
        mainAxisSize: heightFactor == null ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: Space.lg),
              decoration: BoxDecoration(color: c.outline, borderRadius: Radii.fullR),
            ),
          ),
          if (heightFactor == null) Flexible(child: SingleChildScrollView(child: child)) else Expanded(child: child),
        ],
      ),
    );
  }
}

Future<T?> showReaderSheet<T>(BuildContext context, WidgetBuilder builder, {bool scrim = true, double? heightFactor}) =>
    showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: scrim ? context.colors.scrim : Colors.transparent,
      sheetAnimationStyle: AnimationStyle(
        duration: Motion.of(context, Motion.sheet),
        curve: Motion.curveOf(context, Motion.decelerate),
      ),
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: ReaderSheet(
          heightFactor: heightFactor,
          child: Builder(builder: builder),
        ),
      ),
    );

// ------------------------------------------------------------ reading settings

/// Reading settings (R7): opens at about half height over the live page,
/// which re-renders on every change. [pdf] swaps typography for layout,
/// crop and recolour ("Page settings").
Future<void> showReadingSettings(BuildContext context, {bool pdf = false}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.transparent,
  sheetAnimationStyle: AnimationStyle(
    duration: Motion.of(context, Motion.sheet),
    curve: Motion.curveOf(context, Motion.decelerate),
  ),
  builder: (BuildContext ctx) => DraggableScrollableSheet(
    initialChildSize: pdf ? 0.54 : 0.62,
    minChildSize: 0.3,
    maxChildSize: 0.94,
    expand: false,
    builder: (BuildContext ctx, ScrollController scroll) => ReaderSheet(
      heightFactor: null,
      child: SingleChildScrollView(controller: scroll, child: pdf ? const _PageSettings() : const _ReadingSettings()),
    ),
  ),
);

class _ThemeSwatches extends ConsumerWidget {
  const _ThemeSwatches({required this.withLetters});

  final bool withLetters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final ReadingPrefs p = ref.watch(readingPrefsProvider);
    final ReadingThemeId current = p.themeFor(darkChrome: c.isDark, amoledChrome: c.tone == Tone.amoled);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        for (final ReadingThemeId id in ReadingThemeId.values)
          ThemeSwatch(
            theme: ReadingTheme.of(ThemeFamily.saffron, id),
            selected: id == current,
            label: withLetters ? ReadingTheme.names[id.index] : null,
            semantic: '${ReadingTheme.names[id.index]} page',
            size: 56,
            onTap: () => ref.read(readingPrefsProvider.notifier).update((ReadingPrefs x) => x.copyWith(theme: id)),
          ),
      ],
    );
  }
}

/// A reading theme as a circle: paper with "Aa" in ink, and a primary ring
/// when chosen.
class ThemeSwatch extends StatelessWidget {
  const ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
    required this.semantic,
    this.label,
    this.size = 44,
    this.letters = true,
    super.key,
  });

  final ReadingTheme theme;
  final bool selected;
  final VoidCallback onTap;
  final String semantic;
  final String? label;
  final double size;
  final bool letters;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: semantic,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: <Widget>[
            AnimatedContainer(
              duration: Motion.of(context, Motion.fast),
              width: size,
              height: size,
              // Room for the selection ring, which draws outside the circle.
              margin: const EdgeInsets.all(4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.paper,
                shape: BoxShape.circle,
                border: selected ? null : Border.all(color: c.outline),
                boxShadow: selected
                    ? <BoxShadow>[
                        BoxShadow(color: c.surfaceContainer, spreadRadius: 2),
                        BoxShadow(color: c.primary, spreadRadius: 4),
                      ]
                    : null,
              ),
              child: letters
                  ? Text(
                      'Aa',
                      style: TextStyle(
                        fontFamily: kLiterata,
                        fontSize: size * 0.27,
                        fontWeight: FontWeight.w500,
                        color: theme.ink,
                      ),
                    )
                  : null,
            ),
            if (label != null)
              Text(
                label!,
                style: UnfurlType.label.copyWith(fontSize: 11, color: c.onSurface).weight(selected ? 600 : 500),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReadingSettings extends ConsumerWidget {
  const _ReadingSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final ReadingPrefs p = ref.watch(readingPrefsProvider);
    final ReadingPrefsController ctl = ref.read(readingPrefsProvider.notifier);
    void set(ReadingPrefs Function(ReadingPrefs) f) => ctl.update(f);
    final int sizeIndex = ReadingPrefs.sizes.indexOf(p.size);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.lg,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Reading settings', style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
            ),
            Semantics(
              button: true,
              child: InkWell(
                onTap: ctl.reset,
                child: SizedBox(
                  height: IconSpec.tapTarget,
                  child: Center(
                    child: Text('Reset', style: UnfurlType.monoLabel.copyWith(color: c.accent)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const _ThemeSwatches(withLetters: true),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: Space.sm,
            children: <Widget>[
              for (final ReaderFont f in ReaderFont.values)
                Semantics(
                  button: true,
                  selected: f == p.font,
                  child: Material(
                    color: f == p.font ? c.primaryContainer : c.surfaceContainerHigh,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => set((ReadingPrefs x) => x.copyWith(font: f)),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                        alignment: Alignment.center,
                        child: Text(
                          f.label,
                          style: TextStyle(
                            fontFamily: f.family,
                            fontSize: f == ReaderFont.openDyslexic ? 14 : 15.5,
                            fontWeight: FontWeight.w500,
                            color: f == p.font ? c.onPrimaryContainer : c.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Row(
          spacing: 10,
          children: <Widget>[
            Expanded(
              child: _Track(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _StepButton(
                      label: 'A',
                      size: 13,
                      semantic: 'Smaller text',
                      onTap: sizeIndex > 0
                          ? () => set((ReadingPrefs x) => x.copyWith(size: ReadingPrefs.sizes[sizeIndex - 1]))
                          : null,
                    ),
                    Text('${p.size.round()}', style: UnfurlType.monoTabular.copyWith(color: c.onSurface)),
                    _StepButton(
                      label: 'A',
                      size: 20,
                      semantic: 'Larger text',
                      onTap: sizeIndex < ReadingPrefs.sizes.length - 1
                          ? () => set((ReadingPrefs x) => x.copyWith(size: ReadingPrefs.sizes[sizeIndex + 1]))
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            _IconSegments<double>(
              values: ReadingPrefs.lineHeights,
              icons: const <IconData>[AppIcons.densitySmall, AppIcons.densityMedium, AppIcons.densityLarge],
              labels: const <String>['Tight lines', 'Medium lines', 'Loose lines'],
              selected: p.lineHeight,
              onChanged: (double v) => set((ReadingPrefs x) => x.copyWith(lineHeight: v)),
            ),
          ],
        ),
        Row(
          spacing: 10,
          children: <Widget>[
            Expanded(
              child: SegmentedToggle<double>(
                options: const <(double, String, IconData?)>[
                  (16, 'Narrow', null),
                  (24, 'Margins', null),
                  (36, 'Wide', null),
                ],
                selected: p.margin,
                onChanged: (double v) => set((ReadingPrefs x) => x.copyWith(margin: v)),
              ),
            ),
            _IconSegments<bool>(
              values: const <bool>[true, false],
              icons: const <IconData>[AppIcons.alignJustify, AppIcons.alignLeft],
              labels: const <String>['Justified', 'Left aligned'],
              selected: p.justify,
              onChanged: (bool v) => set((ReadingPrefs x) => x.copyWith(justify: v)),
            ),
          ],
        ),
        _Card(
          children: <Widget>[
            _SwitchRow(
              label: 'Hyphenation',
              value: p.hyphenate,
              onChanged: (bool v) => set((ReadingPrefs x) => x.copyWith(hyphenate: v)),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text('Layout', style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
                    ),
                    SizedBox(
                      width: 168,
                      child: SegmentedToggle<ReaderLayout>(
                        options: const <(ReaderLayout, String, IconData?)>[
                          (ReaderLayout.paged, 'Paged', null),
                          (ReaderLayout.scroll, 'Scroll', null),
                        ],
                        selected: p.layout,
                        onChanged: (ReaderLayout v) => set((ReadingPrefs x) => x.copyWith(layout: v)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const _BrightnessRow(),
          ],
        ),
        const SizedBox(height: Space.sm),
      ],
    );
  }
}

class _PageSettings extends ConsumerWidget {
  const _PageSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final ReadingPrefs p = ref.watch(readingPrefsProvider);
    void set(ReadingPrefs Function(ReadingPrefs) f) => ref.read(readingPrefsProvider.notifier).update(f);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.lg,
      children: <Widget>[
        Text('Page settings', style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
        Consumer(
          builder: (BuildContext context, WidgetRef ref, _) {
            final ReadingThemeId current = p.themeFor(darkChrome: c.isDark, amoledChrome: c.tone == Tone.amoled);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (final ReadingThemeId id in ReadingThemeId.values)
                  ThemeSwatch(
                    theme: ReadingTheme.of(ThemeFamily.saffron, id),
                    selected: id == current,
                    letters: false,
                    size: 56,
                    semantic: '${ReadingTheme.names[id.index]} page',
                    onTap: () => set((ReadingPrefs x) => x.copyWith(theme: id)),
                  ),
              ],
            );
          },
        ),
        SegmentedToggle<PdfLayout>(
          options: const <(PdfLayout, String, IconData?)>[
            (PdfLayout.continuous, 'Continuous', AppIcons.swapVert),
            (PdfLayout.paged, 'Paged', AppIcons.swapHoriz),
          ],
          selected: p.pdfLayout,
          onChanged: (PdfLayout v) => set((ReadingPrefs x) => x.copyWith(pdfLayout: v)),
        ),
        _Card(
          children: <Widget>[
            _SwitchRow(
              label: 'Crop margins',
              value: p.pdfCrop,
              onChanged: (bool v) => set((ReadingPrefs x) => x.copyWith(pdfCrop: v)),
            ),
            _SwitchRow(
              label: 'Recolour pages',
              subtitle: 'Photos keep their colours',
              value: p.pdfRecolour,
              onChanged: (bool v) => set((ReadingPrefs x) => x.copyWith(pdfRecolour: v)),
            ),
            const _BrightnessRow(percent: true),
          ],
        ),
        const SizedBox(height: Space.sm),
      ],
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Space.xs),
    decoration: BoxDecoration(color: context.colors.surfaceContainerHigh, borderRadius: Radii.fullR),
    child: child,
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.size, required this.semantic, required this.onTap});

  final String label;
  final double size;
  final String semantic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: semantic,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: SizedBox(
        width: 48,
        height: 40,
        child: Center(
          child: Text(
            label,
            style: UnfurlType.titleMedium.copyWith(
              fontSize: size,
              color: onTap == null ? context.colors.onSurfaceMuted : context.colors.icon,
            ),
          ),
        ),
      ),
    ),
  );
}

class _IconSegments<T> extends StatelessWidget {
  const _IconSegments({
    required this.values,
    required this.icons,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final List<IconData> icons;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return _Track(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < values.length; i++)
            Semantics(
              button: true,
              selected: values[i] == selected,
              label: labels[i],
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onChanged(values[i]),
                child: AnimatedContainer(
                  duration: Motion.of(context, Motion.fast),
                  width: 44,
                  height: 40,
                  decoration: BoxDecoration(
                    color: values[i] == selected ? c.surface : c.surface.withValues(alpha: 0),
                    borderRadius: Radii.fullR,
                    border: Border.all(color: values[i] == selected ? c.outline : c.outline.withValues(alpha: 0)),
                  ),
                  child: AppIcon(icons[i], size: 20, color: values[i] == selected ? c.onSurface : c.iconMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.cardR,
        border: Border.all(color: c.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[if (i > 0) Divider(color: c.divider), children[i]],
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged, this.subtitle});

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.xs),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(label, style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
                    if (subtitle != null)
                      Text(subtitle!, style: UnfurlType.bodySmall.copyWith(color: c.onSurfaceVariant)),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen brightness for reading, or the system's ("Auto").
class _BrightnessRow extends ConsumerWidget {
  const _BrightnessRow({this.percent = false});

  final bool percent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final ReadingPrefs p = ref.watch(readingPrefsProvider);
    final double v = p.brightness ?? 0.44;
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Row(
          children: <Widget>[
            AppIcon(AppIcons.brightness, size: 20, color: c.icon),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  activeTrackColor: p.brightness == null ? c.onSurfaceMuted : c.primary,
                  inactiveTrackColor: c.surfaceContainerHigh,
                  thumbColor: c.primary,
                  overlayColor: c.primary.withValues(alpha: 0.12),
                  thumbShape: const _BarThumb(),
                ),
                child: Slider(
                  value: v,
                  label: 'Brightness',
                  onChanged: (double x) {
                    ref.read(readingPrefsProvider.notifier).update((ReadingPrefs s) => s.copyWith(brightness: x));
                    unawaited(Platform.setBrightness(x));
                  },
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Automatic brightness',
              child: InkWell(
                onTap: () {
                  ref.read(readingPrefsProvider.notifier).update((ReadingPrefs s) => s.copyWith(clearBrightness: true));
                  unawaited(Platform.setBrightness(null));
                },
                child: SizedBox(
                  width: 56,
                  height: IconSpec.tapTarget,
                  child: Center(
                    child: Text(
                      p.brightness == null ? 'Auto' : (percent ? '${(v * 100).round()}%' : 'Auto'),
                      style: UnfurlType.monoLabel.copyWith(color: p.brightness == null ? c.accent : c.onSurfaceVariant),
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

/// The board's bar thumb: 4x24.
class _BarThumb extends SliderComponentShape {
  const _BarThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(4, 24);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 4, height: 24), const Radius.circular(2)),
      Paint()..color = sliderTheme.thumbColor!,
    );
  }
}

// ------------------------------------------------------------ contents

/// A row in the Contents tab.
class TocRow {
  const TocRow({required this.title, required this.where, required this.current, required this.onTap, this.level = 0});

  final String title;
  final String where;
  final bool current;
  final int level;
  final VoidCallback onTap;
}

/// A bookmark or highlight row.
class MarkRow {
  const MarkRow({required this.annotation, required this.label, required this.where, required this.onTap});

  final Annotation annotation;
  final String label;
  final String where;
  final VoidCallback onTap;
}

/// Contents, Bookmarks, Highlights (R8): at 90% with the current chapter in
/// the middle; the segmented control or a horizontal swipe switches tabs.
class ContentsSheet extends StatefulWidget {
  const ContentsSheet({
    required this.title,
    required this.toc,
    required this.bookmarks,
    required this.highlights,
    required this.theme,
    this.initialTab = 0,
    super.key,
  });

  final String title;
  final List<TocRow> toc;
  final List<MarkRow> bookmarks;
  final List<MarkRow> highlights;
  final ReadingTheme theme;
  final int initialTab;

  @override
  State<ContentsSheet> createState() => _ContentsSheetState();
}

class _ContentsSheetState extends State<ContentsSheet> {
  late int _tab = widget.initialTab;
  late final PageController _pages = PageController(initialPage: widget.initialTab);
  int? _color;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: <Widget>[
        Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: UnfurlType.sheetTitle.copyWith(color: c.onSurface),
        ),
        SegmentedToggle<int>(
          options: const <(int, String, IconData?)>[
            (0, 'Contents', null),
            (1, 'Bookmarks', null),
            (2, 'Highlights', null),
          ],
          selected: _tab,
          onChanged: (int i) {
            setState(() => _tab = i);
            unawaited(
              _pages.animateToPage(
                i,
                duration: Motion.of(context, Motion.containerTransform),
                curve: Motion.decelerate,
              ),
            );
          },
        ),
        Expanded(
          child: PageView(
            controller: _pages,
            onPageChanged: (int i) => setState(() => _tab = i),
            children: <Widget>[_toc(c), _bookmarks(c), _highlights(c)],
          ),
        ),
      ],
    );
  }

  Widget _toc(UnfurlColors c) {
    if (widget.toc.isEmpty) return _empty(c, 'This document has no table of contents.');
    final int current = widget.toc.indexWhere((TocRow r) => r.current);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) => ListView.builder(
        controller: ScrollController(
          initialScrollOffset: current < 0 ? 0 : (current * 52 - box.maxHeight / 2 + 26).clamp(0, double.infinity),
        ),
        padding: EdgeInsets.zero,
        itemCount: widget.toc.length,
        itemExtent: 52,
        itemBuilder: (BuildContext context, int i) {
          final TocRow r = widget.toc[i];
          return Semantics(
            button: true,
            selected: r.current,
            child: Material(
              color: r.current ? c.primaryContainer : Colors.transparent,
              borderRadius: Radii.cardR,
              child: InkWell(
                borderRadius: Radii.cardR,
                onTap: r.onTap,
                child: Padding(
                  padding: EdgeInsets.only(left: Space.screen - 8 + r.level * Space.lg, right: Space.md),
                  child: Row(
                    spacing: Space.md,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UnfurlType.body
                              .copyWith(height: 1.3, color: r.current ? c.onPrimaryContainer : c.onSurface)
                              .weight(r.current ? 600 : 400),
                        ),
                      ),
                      Text(
                        r.where,
                        style: UnfurlType.monoLabel.copyWith(
                          color: r.current ? c.onPrimaryContainer : c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _empty(UnfurlColors c, String text) => Padding(
    padding: const EdgeInsets.only(top: Space.xxl),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: UnfurlType.body.copyWith(color: c.onSurfaceVariant),
    ),
  );

  Widget _bookmarks(UnfurlColors c) {
    if (widget.bookmarks.isEmpty) return _empty(c, 'No bookmarks yet. Tap the bookmark in the top bar to add one.');
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: Radii.cardR,
          border: Border.all(color: c.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            for (int i = 0; i < widget.bookmarks.length; i++) ...<Widget>[
              if (i > 0) Divider(color: c.divider),
              InkWell(
                onTap: widget.bookmarks[i].onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                  child: Row(
                    spacing: 14,
                    children: <Widget>[
                      AppIcon(AppIcons.bookmark, fill: true, color: c.primary),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(widget.bookmarks[i].label, style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
                            Text(
                              widget.bookmarks[i].annotation.quote,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: kLiterata,
                                fontSize: 13,
                                height: 1.5,
                                color: c.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(widget.bookmarks[i].where, style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _highlights(UnfurlColors c) {
    final List<MarkRow> rows = widget.highlights
        .where((MarkRow r) => _color == null || r.annotation.color == _color)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.md,
      children: <Widget>[
        Row(
          spacing: Space.sm,
          children: <Widget>[
            Material(
              color: _color == null ? c.primaryContainer : c.surfaceContainerHigh,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => setState(() => _color = null),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  child: Text(
                    'All ${widget.highlights.length}',
                    style: UnfurlType.titleSmall.copyWith(color: _color == null ? c.onPrimaryContainer : c.onSurface),
                  ),
                ),
              ),
            ),
            for (final HighlightColor h in HighlightColor.values)
              Semantics(
                button: true,
                selected: _color == h.index,
                label: '${h.label} highlights',
                excludeSemantics: true,
                child: Material(
                  color: _color == h.index ? c.primaryContainer : c.surfaceContainerHigh,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = h.index),
                    child: SizedBox.square(
                      dimension: IconSpec.tapTarget - 8,
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(color: widget.theme.highlights[h.index], shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: rows.isEmpty
              ? _empty(c, 'No highlights yet. Press and hold a passage to start.')
              : SingleChildScrollView(
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: Radii.cardR,
                      border: Border.all(color: c.outline),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < rows.length; i++) ...<Widget>[
                          if (i > 0) Divider(color: c.divider),
                          InkWell(
                            onTap: rows[i].onTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: 6,
                                children: <Widget>[
                                  Text(rows[i].where, style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                                  HighlightQuote(
                                    text: rows[i].annotation.quote,
                                    color: widget.theme.highlights[rows[i].annotation.color ?? 0],
                                  ),
                                  if (rows[i].annotation.note != null)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      spacing: 6,
                                      children: <Widget>[
                                        AppIcon(AppIcons.editNote, size: 18, color: c.onSurfaceVariant),
                                        Expanded(
                                          child: Text(
                                            rows[i].annotation.note!,
                                            style: UnfurlType.note.copyWith(color: c.onSurfaceVariant),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// A quote in the reading serif with its highlight colour behind the text.
class HighlightQuote extends StatelessWidget {
  const HighlightQuote({required this.text, required this.color, super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: text,
      style: TextStyle(backgroundColor: color, color: context.colors.onSurface),
    ),
    style: TextStyle(fontFamily: kLiterata, fontSize: 15, height: 1.55, color: context.colors.onSurface),
  );
}

// ------------------------------------------------------------ note

/// Write or edit a note on a highlight. Returns the text, '' to remove the
/// note, or null when dismissed.
Future<String?> showNoteSheet(
  BuildContext context, {
  required String quote,
  required Color color,
  String? initial,
  VoidCallback? onDelete,
}) {
  final TextEditingController text = TextEditingController(text: initial);
  return showReaderSheet<String>(context, (BuildContext ctx) {
    final UnfurlColors c = ctx.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: <Widget>[
        Text(initial == null ? 'Add a note' : 'Note', style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
        HighlightQuote(text: quote.length > 240 ? '${quote.substring(0, 240)}…' : quote, color: color),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: Radii.cardR,
            border: Border.all(color: c.outline),
          ),
          child: TextField(
            controller: text,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            style: UnfurlType.body.copyWith(color: c.onSurface),
            decoration: InputDecoration.collapsed(
              hintText: 'What did this make you think?',
              hintStyle: UnfurlType.body.copyWith(color: c.onSurfaceVariant),
            ),
          ),
        ),
        AppButton(label: 'Save note', onPressed: () => Navigator.of(ctx).pop(text.text.trim())),
        if (onDelete != null)
          AppButton(
            label: 'Remove highlight',
            type: AppButtonType.text,
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete();
            },
          ),
      ],
    );
  });
}

// ------------------------------------------------------------ book info

/// Book info (R10): the cover, the facts, and Export highlights.
Future<void> showBookInfo(
  BuildContext context, {
  required Widget cover,
  required String title,
  required String? author,
  required List<(String, String)> facts,
  required int highlights,
  required VoidCallback? onExport,
}) => showReaderSheet<void>(context, (BuildContext ctx) {
  final UnfurlColors c = ctx.colors;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: Space.lg,
    children: <Widget>[
      Row(
        spacing: Space.lg,
        children: <Widget>[
          cover,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: <Widget>[
                Text(title, style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
                if (author != null)
                  Text(author, style: UnfurlType.body.copyWith(fontSize: 14, height: 1.4, color: c.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
      Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: Radii.cardR,
          border: Border.all(color: c.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            for (int i = 0; i < facts.length; i++) ...<Widget>[
              if (i > 0) Divider(color: c.divider),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Space.md,
                  children: <Widget>[
                    SizedBox(
                      width: 96,
                      child: Text(facts[i].$1, style: UnfurlType.note.copyWith(height: 1.4, color: c.onSurfaceVariant)),
                    ),
                    Expanded(
                      child: SelectableText(
                        facts[i].$2,
                        style: UnfurlType.monoLabel.copyWith(fontSize: 12.5, height: 1.45, color: c.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      if (onExport != null) ...<Widget>[
        AppButton(
          label: 'Export highlights',
          icon: AppIcons.share,
          type: AppButtonType.secondary,
          onPressed: highlights == 0 ? null : onExport,
        ),
        Text(
          highlights == 0
              ? 'No highlights to export yet'
              : '$highlights ${highlights == 1 ? 'highlight' : 'highlights'} as Markdown, via the share sheet',
          textAlign: TextAlign.center,
          style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    ],
  );
});

// ------------------------------------------------------------ voice

/// Read aloud's voice and speed (R10).
Future<void> showVoiceSheet(BuildContext context, {required double rate, required ValueChanged<double> onRate}) =>
    showReaderSheet<void>(context, (BuildContext ctx) => _VoiceSheet(rate: rate, onRate: onRate));

class _VoiceSheet extends ConsumerStatefulWidget {
  const _VoiceSheet({required this.rate, required this.onRate});

  final double rate;
  final ValueChanged<double> onRate;

  @override
  ConsumerState<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends ConsumerState<_VoiceSheet> {
  late double _rate = widget.rate;
  List<Map<Object?, Object?>>? _voices;

  @override
  void initState() {
    super.initState();
    unawaited(
      Platform.voices().then((List<Map<Object?, Object?>> v) {
        if (mounted) setState(() => _voices = v);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final String? chosen = ref.watch(readingPrefsProvider).ttsVoice;
    final String lang = Localizations.localeOf(context).languageCode;
    final List<Map<Object?, Object?>> voices = (_voices ?? const <Map<Object?, Object?>>[])
        .where((Map<Object?, Object?> v) => (v['locale'] as String? ?? '').startsWith(lang))
        .take(12)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.lg,
      children: <Widget>[
        Text('Read aloud', style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
        const SectionHeader(label: 'Speed'),
        SegmentedToggle<double>(
          options: <(double, String, IconData?)>[for (final double r in ReadingPrefs.rates) (r, r.toString(), null)],
          selected: _rate,
          onChanged: (double r) {
            setState(() => _rate = r);
            widget.onRate(r);
            ref.read(readingPrefsProvider.notifier).update((ReadingPrefs p) => p.copyWith(ttsRate: r));
          },
        ),
        const SectionHeader(label: 'Voice'),
        if (_voices == null)
          const SizedBox(height: 56)
        else if (voices.isEmpty)
          Text(
            'No offline voices are installed for this language.',
            style: UnfurlType.note.copyWith(color: c.onSurfaceVariant),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: Radii.cardR,
              border: Border.all(color: c.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < voices.length; i++) ...<Widget>[
                  if (i > 0) Divider(color: c.divider),
                  _voiceRow(
                    c,
                    voices[i],
                    i,
                    chosen == null ? voices[i]['selected'] == true : voices[i]['name'] == chosen,
                  ),
                ],
              ],
            ),
          ),
        InkWell(
          onTap: Platform.openTtsSettings,
          child: SizedBox(
            height: IconSpec.tapTarget,
            child: Row(
              spacing: Space.md,
              children: <Widget>[
                AppIcon(AppIcons.settings, size: 20, color: c.onSurfaceVariant),
                Expanded(
                  child: Text(
                    'More voices in system text-to-speech settings',
                    style: UnfurlType.note.copyWith(height: 1.5, color: c.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _voiceRow(UnfurlColors c, Map<Object?, Object?> v, int i, bool on) {
    final String name = v['name']! as String;
    return InkWell(
      onTap: () {
        ref.read(readingPrefsProvider.notifier).update((ReadingPrefs p) => p.copyWith(ttsVoice: name));
        unawaited(Platform.setVoice(name));
      },
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.only(left: Space.lg, right: Space.xs),
          child: Row(
            spacing: Space.md,
            children: <Widget>[
              AppIcon(on ? AppIcons.radioOn : AppIcons.radioOff, color: on ? c.primary : c.iconMuted),
              Expanded(
                child: Text(
                  '${v['label']} · Voice ${i + 1}',
                  style: UnfurlType.titleMedium.copyWith(color: c.onSurface).weight(on ? 600 : 400),
                ),
              ),
              AppIconButton(
                icon: AppIcons.playCircle,
                filled: false,
                semanticLabel: 'Hear this voice',
                onPressed: () => Platform.previewVoice(name, 'It is a truth universally acknowledged.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Mull

/// "Define in Mull": Mull shows its own word sheet over the book (it
/// handles PROCESS_TEXT); without Mull, a short pitch with a Play Store link.
Future<void> defineInMull(BuildContext context, String word) async {
  final String w = word.trim();
  if (await Platform.isMullInstalled() && await Platform.defineInMull(w)) return;
  if (!context.mounted) return;
  await showReaderSheet<void>(context, (BuildContext ctx) {
    final UnfurlColors c = ctx.colors;
    final String shown = w.length > 30 ? '${w.substring(0, 30)}…' : w;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset('assets/images/mull.png', width: 56, height: 56, cacheWidth: 168),
          ),
        ),
        Text('Define “$shown” in Mull', style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
        Text(
          'Mull is a free offline dictionary from the same maker. Look up any word without leaving your book.',
          style: UnfurlType.body.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Space.xs),
        AppButton(
          label: 'Get it on Play Store',
          icon: AppIcons.shop,
          onPressed: () {
            Navigator.of(ctx).pop();
            unawaited(Platform.openStore(Platform.mullPackage));
          },
        ),
        AppButton(label: 'Not now', type: AppButtonType.text, onPressed: () => Navigator.of(ctx).pop()),
      ],
    );
  });
}

/// Copies to the clipboard and says so.
Future<void> copyText(String text) => Clipboard.setData(ClipboardData(text: text));

/// The chrome is light or dark; reading themes follow it unless chosen.
ReadingTheme readingThemeOf(BuildContext context, ReadingPrefs prefs, AppSettings settings) {
  final UnfurlColors c = context.colors;
  return ReadingTheme.of(settings.family, prefs.themeFor(darkChrome: c.isDark, amoledChrome: c.tone == Tone.amoled));
}
