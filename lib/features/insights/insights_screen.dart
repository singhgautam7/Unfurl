import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/tracking/session.dart';
import '../../design_system/app_header.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/chips.dart';
import '../../design_system/containers.dart';
import '../../design_system/covers.dart';
import '../../formats/format_registry.dart';
import '../settings/settings_controller.dart';
import 'book_insights.dart';
import 'insights_data.dart';
import 'insights_widgets.dart';

/// Board 6, V1: the Insights screen. Factual, from the aggregates: totals,
/// one chart with Week / Month / Year, a 12-month heatmap, speed, patterns,
/// listening, finished books, formats and the most-read books. No goals,
/// streaks or badges. Expanded widths get a two-column dashboard.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<InsightsData> data = ref.watch(insightsProvider);
    final SizeClass size = SizeClass.of(context);
    return AppScaffold(
      title: 'Insights',
      onBack: () => context.pop(),
      children: <Widget>[
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.fast),
          switchInCurve: Motion.decelerate,
          child: switch (data) {
            AsyncData<InsightsData>(:final InsightsData value) => KeyedSubtree(
              key: const ValueKey<String>('data'),
              child: value.empty ? const _NoData() : _Dashboard(data: value, size: size),
            ),
            AsyncError<InsightsData>() => const _NoData(key: ValueKey<String>('error')),
            _ => const _Loading(key: ValueKey<String>('loading')),
          },
        ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.label, {this.right});

  final String label;
  final String? right;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: Space.sm),
    child: SectionHeader(label: label, action: right),
  );
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.data, required this.size});

  final InsightsData data;
  final SizeClass size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeFamily family = ref.watch(settingsProvider.select((AppSettings s) => s.family));
    final DateTime t = data.today;
    final Widget overview = StatGrid(
      columns: size == SizeClass.compact ? 2 : 4,
      tiles: <StatTile>[
        StatTile(label: 'Today', value: formatMinutes(data.todayMs)),
        StatTile(label: 'This week', value: formatMinutes(data.weekMs)),
        StatTile(
          label: 'This month',
          value: formatMinutes(data.monthMs),
          sub: formatRange(DateTime(t.year, t.month), t),
        ),
        StatTile(
          label: 'All time',
          value: formatMinutes(data.allTimeMs),
          sub: data.firstDay == null
              ? null
              : 'since ${kMonths[dayOfKey(data.firstDay!).month - 1]} ${dayOfKey(data.firstDay!).year}',
        ),
      ],
    );
    final Widget heat = InsightsBox(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: <Widget>[
          ChartHeader(
            total: switch (data.daysWithReading) {
              0 => 'No reading days yet',
              1 => '1 day with reading',
              final int n => '$n days with reading',
            },
            range: 'last 12 months',
          ),
          Heatmap(
            minutes: data.heatmapMinutes,
            months: data.heatmapMonths,
            family: family,
            gap: size == SizeClass.compact ? 1.5 : 3,
          ),
        ],
      ),
    );
    final double? wpm = data.readerWpm, pph = data.pagesPerHour;
    final Widget speed = KeyValueCard(
      items: <(String, String, String?)>[
        (
          'Reader mode',
          wpm == null ? '—' : '${wpm.round()} wpm',
          wpm == null ? 'after 30 min in Reader' : 'median · last 30 days',
        ),
        (
          'Page view',
          pph == null ? '—' : '${pph.round()} pages/h',
          pph == null ? 'after 30 min in Page view' : 'median · last 30 days',
        ),
      ],
    );
    final (int, DateTime, String?)? longest = data.longest;
    final int? average = data.averageSessionMs;
    final List<Widget> patterns = data.hasPatterns
        ? <Widget>[
            const _Head('Time of day'),
            InsightsBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: <Widget>[
                  ChartHeader(total: data.peakHours, range: 'last 90 days'),
                  BarChart(
                    values: data.hourMinutes,
                    labels: <String>[for (int h = 0; h < 24; h++) h % 6 == 0 ? h.toString().padLeft(2, '0') : ''],
                    height: 72,
                    gap: 2,
                    radius: 3,
                    semanticLabel: 'Reading by hour of day. ${data.peakHours}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            KeyValueCard(
              items: <(String, String, String?)>[
                (
                  'Longest session',
                  longest == null ? '—' : formatMinutes(longest.$1),
                  longest == null
                      ? null
                      : '${formatDay(longest.$2, now: t)}${data.longestTitle == null ? '' : ' · ${data.longestTitle}'}',
                ),
                ('Average session', average == null ? '—' : formatMinutes(average), 'last 90 days'),
              ],
            ),
          ]
        : <Widget>[
            const _Head('Patterns'),
            Text(
              'Time of day and longest session appear after 7 days with reading.',
              style: UnfurlType.note.copyWith(height: 1.5, color: context.colors.onSurfaceVariant),
            ),
          ];
    final List<int> finished = data.finishedByMonth(t.year);
    final int finishedTotal = finished.fold<int>(0, (int a, int b) => a + b);
    final List<(String, double)> formats = data.formats;
    final List<Widget> rest = <Widget>[
      if (data.allListenMs > 0) ...<Widget>[
        const _Head('Listening'),
        KeyValueCard(
          items: <(String, String, String?)>[
            ('Listening this month', formatMinutes(data.listenMonthMs), 'read aloud'),
            ('Listening all time', formatMinutes(data.allListenMs), 'read aloud'),
          ],
        ),
      ],
      if (finishedTotal > 0) ...<Widget>[
        const _Head('Finished books'),
        InsightsBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: <Widget>[
              ChartHeader(
                total: '$finishedTotal ${finishedTotal == 1 ? 'book' : 'books'} finished',
                range: '${t.year}',
              ),
              BarChart(
                values: finished,
                labels: const <String>['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'],
                height: 60,
                showValues: true,
                semanticLabel: '$finishedTotal books finished in ${t.year}',
              ),
            ],
          ),
        ),
      ],
      if (formats.isNotEmpty) ...<Widget>[
        const _Head('Formats', right: 'by reading time'),
        StackedBar(parts: formats, family: family),
      ],
      if (data.top.isNotEmpty) ...<Widget>[
        const _Head('Most-read books', right: 'by time'),
        _MostRead(books: data.top),
      ],
    ];

    if (size == SizeClass.expanded) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.xl,
        children: <Widget>[
          Expanded(
            flex: 680,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                overview,
                const SizedBox(height: Space.lg),
                const _ChartModule(),
                const _Head('Last 12 months'),
                heat,
              ],
            ),
          ),
          Expanded(
            flex: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[const _Head('Reading speed'), speed, ...patterns, ...rest],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        overview,
        const SizedBox(height: Space.md),
        const _ChartModule(),
        const _Head('Last 12 months'),
        heat,
        const _Head('Reading speed'),
        speed,
        ...patterns,
        ...rest,
      ],
    );
  }
}

/// Week / Month / Year and its chart: only this rebuilds on a toggle or a step.
class _ChartModule extends ConsumerWidget {
  const _ChartModule();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ChartState s = ref.watch(chartStateProvider);
    final ChartController ctl = ref.read(chartStateProvider.notifier);
    final ChartData? chart = ref.watch(chartProvider).value;
    final bool month = s.range == ChartRange.month;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.md,
      children: <Widget>[
        SegmentedToggle<ChartRange>(
          options: const <(ChartRange, String, IconData?)>[
            (ChartRange.week, 'Week', null),
            (ChartRange.month, 'Month', null),
            (ChartRange.year, 'Year', null),
          ],
          selected: s.range,
          onChanged: ctl.range,
        ),
        InsightsBox(
          child: AnimatedSize(
            duration: Motion.of(context, Motion.fast),
            curve: Motion.decelerate,
            child: chart == null
                ? const SizedBox(height: 172)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: <Widget>[
                      ChartHeader(
                        total: chart.total,
                        range: chart.range,
                        onBack: () => ctl.step(1),
                        onForward: s.back == 0 ? null : () => ctl.step(-1),
                      ),
                      BarChart(
                        key: ValueKey<String>('${s.range}:${s.back}'),
                        values: chart.values,
                        labels: chart.labels,
                        highlight: chart.highlight,
                        gap: month ? 2 : 6,
                        radius: month ? 3 : 5,
                        semanticLabel: 'Reading time, ${chart.range}: ${chart.total}',
                      ),
                      if (chart.caption != null)
                        Text(
                          chart.caption!,
                          style: UnfurlType.tableCell.copyWith(height: 1.4, color: context.colors.onSurfaceVariant),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _MostRead extends StatelessWidget {
  const _MostRead({required this.books});

  final List<BookTime> books;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: Radii.cardR),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < books.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: c.divider),
            InkWell(
              onTap: () => showBookInsights(
                context,
                fingerprint: books[i].fingerprint,
                title: books[i].label,
                name: books[i].name ?? books[i].label,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.md, Space.sm),
                  child: Row(
                    spacing: 14,
                    children: <Widget>[
                      CoverArt(
                        title: books[i].label,
                        fingerprint: books[i].fingerprint,
                        format: Formats.of(books[i].name ?? '') ?? Formats.epub,
                        width: 32,
                        height: 46,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 3,
                          children: <Widget>[
                            Text(
                              books[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: UnfurlType.titleMedium.copyWith(color: c.onSurface),
                            ),
                            Text(
                              '${formatMinutes(books[i].ms)} · ${Formats.labelOf(books[i].name ?? '')}',
                              style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      AppIcon(AppIcons.chevronRight, color: c.iconMuted),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// First week: nothing yet, and a blank heatmap so the screen still says
/// what it will show.
class _NoData extends ConsumerWidget {
  const _NoData({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final ThemeFamily family = ref.watch(settingsProvider.select((AppSettings s) => s.family));
    final DateTime today = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.sm, 40, Space.sm, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: Radii.cardR),
                child: AppIcon(AppIcons.insights, size: 32, color: c.icon),
              ),
              Text(
                'Nothing to show yet',
                style: UnfurlType.headerTitle.copyWith(letterSpacing: -0.22, color: c.onSurface),
              ),
              Text(
                'Reading time shows up here after your first session. Unfurl counts time while a book is open and you are on the page.',
                style: UnfurlType.body.copyWith(fontSize: 14.5, color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const _Head('Last 12 months'),
        InsightsBox(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: <Widget>[
              const ChartHeader(total: 'No reading days yet', range: 'last 12 months'),
              Heatmap(
                minutes: List<int?>.filled(53 * 7, 0),
                months: <String>[for (int k = 11; k >= 0; k--) kMonths[(today.month - 1 - k) % 12]],
                family: family,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Skeletons in the same layout (board 6, V1 "Loading").
class _Loading extends StatelessWidget {
  const _Loading({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading insights',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.md,
      children: <Widget>[
        const Row(
          spacing: Space.sm,
          children: <Widget>[
            Expanded(child: SkeletonBlock(height: 74, radius: 18)),
            Expanded(child: SkeletonBlock(height: 74, radius: 18)),
          ],
        ),
        const Row(
          spacing: Space.sm,
          children: <Widget>[
            Expanded(child: SkeletonBlock(height: 74, radius: 18)),
            Expanded(child: SkeletonBlock(height: 74, radius: 18)),
          ],
        ),
        const SkeletonBlock(height: 44, radius: Radii.full),
        const SkeletonBlock(height: 190, radius: Radii.card),
        const SizedBox(height: Space.sm),
        SkeletonBlock(height: 12, width: MediaQuery.sizeOf(context).width * 0.4),
        const SkeletonBlock(height: 120, radius: Radii.card),
      ],
    ),
  );
}
