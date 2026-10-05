import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/files.dart';
import '../../core/layout.dart';
import '../../core/motion/motion.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/app_menu.dart';
import '../../design_system/containers.dart';
import '../../design_system/covers.dart';
import '../../design_system/option_tiles.dart';
import '../../formats/format_registry.dart';
import '../files/files_widgets.dart' show ExplorerRow;
import '../reader/sheets.dart';
import '../viewer/document_screen.dart';
import 'insights_data.dart';
import 'insights_widgets.dart';

/// Board 6, V2: a sheet on phones, a 400dp side panel on expanded widths
/// (V3-TABLET), so the book stays in view.
Future<void> showBookInsights(
  BuildContext context, {
  required String fingerprint,
  required String title,
  required String name,
  String? author,
}) {
  Widget view(VoidCallback close) =>
      BookInsightsView(fingerprint: fingerprint, title: title, author: author, name: name, onClose: close);
  if (SizeClass.of(context) == SizeClass.expanded) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close book insights',
      barrierColor: context.colors.scrim,
      transitionDuration: Motion.of(context, Motion.sheet),
      pageBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b) => Align(
        alignment: Alignment.centerRight,
        child: SidePanel(child: view(() => Navigator.of(ctx).pop())),
      ),
      transitionBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b, Widget child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a, curve: Motion.curveOf(ctx, Motion.decelerate))),
        child: child,
      ),
    );
  }
  return showReaderSheet<void>(
    context,
    surface: true,
    heightFactor: 0.9,
    (BuildContext ctx) => view(() => Navigator.of(ctx).pop()),
  );
}

/// "Insights" in a reader's or viewer's overflow menu (board 6, V2: third).
const AppMenuEntry<String> kInsightsEntry = AppMenuEntry<String>(
  value: 'insights',
  label: 'Insights',
  icon: AppIcons.insights,
);

/// Book insights for the document a viewer has open.
Future<void> showDocInsights(BuildContext context, OpenedDoc doc) => showBookInsights(
  context,
  fingerprint: doc.fingerprint,
  title: doc.record.title ?? doc.ref.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
  author: doc.record.author,
  name: doc.ref.name,
);

/// From a menu: the file's fingerprint first if the index hasn't read it.
Future<void> showInsightsFor(
  BuildContext context, {
  required String uri,
  required String title,
  required String name,
  String? fingerprint,
  String? author,
}) async {
  final String? fp = fingerprint ?? await Files.fingerprint(uri);
  if (fp == null || !context.mounted) return;
  await showBookInsights(context, fingerprint: fp, title: title, name: name, author: author);
}

/// A 400dp panel on the right of an expanded screen: `surface`, a 1dp rule
/// on its left (board 6, V7).
class SidePanel extends StatelessWidget {
  const SidePanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Material(
      color: c.surface,
      child: Container(
        width: AdaptiveSpec.sidePanel,
        height: double.infinity,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: c.divider)),
        ),
        child: SafeArea(left: false, child: child),
      ),
    );
  }
}

class BookInsightsView extends ConsumerWidget {
  const BookInsightsView({
    required this.fingerprint,
    required this.title,
    required this.name,
    required this.onClose,
    this.author,
    super.key,
  });

  final String fingerprint;
  final String title;
  final String? author;
  final String name;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final BookInsights? b = ref.watch(bookInsightsProvider(fingerprint)).value;
    final FormatModule format = Formats.of(name) ?? Formats.epub;
    final bool pages = format.view != ViewKind.reader;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SheetHead(title: 'Book insights', onClose: onClose),
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.fast),
            switchInCurve: Motion.decelerate,
            child: b == null
                ? const SizedBox.expand()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl),
                    children: <Widget>[
                      _BookHead(
                        fingerprint: fingerprint,
                        title: b.doc?.title ?? title,
                        author: b.doc?.author ?? author,
                        name: name,
                        format: format,
                      ),
                      if (b.timeMs == 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(Space.xs, Space.xs, Space.xs, Space.md),
                          child: Text(
                            '${b.doc?.openedAt == null ? 'Not opened yet.' : 'Opened ${formatDay(b.doc!.openedAt!, now: b.today)}.'} '
                            'No reading time yet. Time starts counting after 30 seconds on a page.',
                            style: UnfurlType.note.copyWith(fontSize: 14, height: 1.5, color: c.onSurfaceVariant),
                          ),
                        ),
                      _Figures(b: b, pages: pages, format: format),
                      const SizedBox(height: Space.sm),
                      _Progress(b: b, pages: pages),
                      const Padding(
                        padding: EdgeInsets.only(top: 18, bottom: Space.sm),
                        child: SectionHeader(label: 'Daily reading'),
                      ),
                      _Daily(b: b),
                      const SizedBox(height: Space.sm),
                      KeyValueCard(
                        items: <(String, String, String?)>[
                          ('Highlights', '${b.highlights}', null),
                          ('Bookmarks', '${b.bookmarks}', null),
                        ],
                      ),
                      if (b.highlights + b.bookmarks > 0)
                        ExplorerRow(
                          name: 'Open in Notes',
                          icon: AppIcons.notes,
                          meta: 'Highlights and bookmarks for this book',
                          sansMeta: true,
                          trailing: AppIcons.chevronRight,
                          onTap: () {
                            onClose();
                            GoRouter.of(context).go(Routes.notes);
                          },
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _BookHead extends StatelessWidget {
  const _BookHead({
    required this.fingerprint,
    required this.title,
    required this.name,
    required this.format,
    this.author,
  });

  final String fingerprint;
  final String title;
  final String? author;
  final String name;
  final FormatModule format;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xs, 6, Space.xs, Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: Space.lg,
        children: <Widget>[
          CoverArt(title: title, author: author, fingerprint: fingerprint, format: format, width: 72, height: 104),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 5,
              children: <Widget>[
                FormatBadge(Formats.labelOf(name)),
                Text(title, style: UnfurlType.title.copyWith(letterSpacing: -0.2, color: c.onSurface)),
                if (author != null)
                  Text(author!, style: UnfurlType.body.copyWith(fontSize: 14, height: 1.3, color: c.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.b, required this.pages, required this.format});

  final BookInsights b;
  final bool pages;
  final FormatModule format;

  @override
  Widget build(BuildContext context) {
    final BookStat? s = b.stats;
    String speed = '—';
    String? speedSub = pages ? 'after 30 min reading' : 'after 30 min reading';
    if (s != null) {
      if (!pages && s.readerMs >= 30 * 60000 && s.readerWords > 0) {
        speed = '${(s.readerWords / (s.readerMs / 60000)).round()} wpm';
        speedSub = 'Reader mode';
      } else if (pages && s.pageMs >= 30 * 60000 && s.pagePages > 0) {
        speed = '${(s.pagePages / (s.pageMs / 3600000)).round()} pages/h';
        speedSub = format == Formats.comics ? 'Comics' : 'Page view';
      }
    }
    return StatGrid(
      tiles: <StatTile>[
        StatTile(label: 'Time spent', value: formatMinutes(b.timeMs)),
        StatTile(label: 'Sessions', value: '${b.sessions}'),
        StatTile(label: 'Average session', value: b.sessions == 0 ? '—' : formatMinutes(b.timeMs ~/ b.sessions)),
        StatTile(label: 'Reading speed', value: speed, sub: speedSub),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.b, required this.pages});

  final BookInsights b;
  final bool pages;

  /// "about 5 h 40 min" left: words left ÷ this book's speed (or your
  /// average), or pages left ÷ pages per hour.
  (String, String?) _left() {
    final BookStat? s = b.stats;
    final Document? d = b.doc;
    if (pages) {
      final int? units = d?.units;
      final double? pph = b.speeds.pagesPerHour;
      if (units == null || pph == null || pph <= 0) return ('—', 'after 30 min in Page view');
      final int left = math.max(0, (units * (1 - (d?.progress ?? 0))).round());
      return ('about ${formatMinutes((left / pph * 3600000).round())}', 'at ${pph.round()} pages/h');
    }
    final int? words = s?.wordsLeft ?? s?.totalWords;
    final double wpm = b.speeds.wpm ?? 230;
    if (words == null) return ('—', 'after you open it in Reader mode');
    final bool own = s != null && s.readerMs >= 10 * 60000;
    return (
      'about ${formatMinutes((words / wpm * 60000).round())}',
      b.speeds.wpm == null
          ? 'at an average 230 wpm'
          : (own ? 'at ${wpm.round()} wpm' : 'at your average ${wpm.round()} wpm'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final BookStat? s = b.stats;
    final Document? d = b.doc;
    final (String left, String? leftSub) = _left();
    final bool started = s?.firstRead != null;
    return KeyValueCard(
      items: <(String, String, String?)>[
        ('Started', started ? formatDay(s!.firstRead!, now: b.today) : 'Not yet', null),
        ('Finished', s?.finishedAt != null ? formatDay(s!.finishedAt!, now: b.today) : 'Not yet', null),
        ('Estimated time left', left, leftSub),
        if (started || (d?.progress ?? 0) > 0)
          ('Progress', '${((d?.progress ?? 0) * 100).round()}%', d?.where)
        else if (s?.totalWords != null)
          ('Length', '${_thousands(s!.totalWords!)} words', null)
        else if (d?.units != null)
          ('Length', '${d!.units} ${pages ? 'pages' : 'chapters'}', null),
      ],
    );
  }

  static String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (Match _) => ',');
}

class _Daily extends StatelessWidget {
  const _Daily({required this.b});

  final BookInsights b;

  @override
  Widget build(BuildContext context) {
    final int total = b.last30.fold<int>(0, (int a, int m) => a + m);
    final DateTime first = b.today.subtract(const Duration(days: 29));
    return InsightsBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: <Widget>[
          ChartHeader(total: total == 0 ? 'Nothing to chart yet' : formatMinutes(total * 60000), range: 'last 30 days'),
          BarChart(
            values: b.last30,
            labels: <String>[
              for (int i = 0; i < 30; i++) i == 0 ? formatDay(first, now: b.today) : (i == 29 ? 'Today' : ''),
            ],
            highlight: total == 0 ? null : 29,
            height: total == 0 ? 40 : 70,
            gap: 2,
            radius: 3,
            semanticLabel: 'Daily reading, last 30 days: ${total == 0 ? 'none' : formatMinutes(total * 60000)}',
          ),
          if (total > 0)
            Text(
              'Read on ${b.readOn} of the last 30 days',
              style: UnfurlType.tableCell.copyWith(height: 1.4, color: context.colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
