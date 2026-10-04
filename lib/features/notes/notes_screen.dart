import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/files.dart';
import '../../core/library/library.dart';
import '../../core/locator.dart';
import '../../core/motion/motion.dart';
import '../../core/open.dart';
import '../../core/platform/platform.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/reading_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_header.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/app_menu.dart';
import '../../design_system/app_snackbar.dart';
import '../../design_system/buttons.dart';
import '../../design_system/chips.dart';
import '../../design_system/containers.dart';
import '../../design_system/search_field.dart';
import '../../design_system/states.dart';
import '../../formats/format_registry.dart';
import '../cards/card_editor.dart';
import '../cards/share_card.dart';
import '../reader/reading_prefs.dart';
import '../reader/sheets.dart';
import '../settings/settings_controller.dart';

/// Board 2, A4: every highlight, note and bookmark, grouped by document,
/// newest group first. A tap opens the document at that passage, in the mode
/// it was made in.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  /// A highlight colour index, -1 for bookmarks, null for all.
  int? _filter;
  bool _searching = false;
  String _query = '';

  bool _keep(Annotation a) {
    if (_filter == -1 && a.kind != 'bookmark') return false;
    if (_filter != null && _filter! >= 0 && (a.kind != 'highlight' || a.color != _filter)) return false;
    if (_query.isNotEmpty) {
      final String q = _query.toLowerCase();
      if (!a.quote.toLowerCase().contains(q) && !(a.note?.toLowerCase().contains(q) ?? false)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final List<(Annotation, Document?)> all =
        ref.watch(allAnnotationsProvider).value ?? const <(Annotation, Document?)>[];
    final ReadingTheme theme = readingThemeOf(context, ref.watch(readingPrefsProvider), ref.watch(settingsProvider));
    final List<(Annotation, Document?)> shown = all.where(((Annotation, Document?) x) => _keep(x.$1)).toList();
    // Groups by document, newest group first (the list is newest first).
    final Map<String, List<(Annotation, Document?)>> groups = <String, List<(Annotation, Document?)>>{};
    for (final (Annotation, Document?) x in shown) {
      groups.putIfAbsent(x.$1.fingerprint, () => <(Annotation, Document?)>[]).add(x);
    }

    if (all.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppHeader(title: 'Notes'),
              Expanded(
                child: EmptyState(
                  icon: AppIcons.notes,
                  title: 'Nothing marked yet',
                  message: 'Highlights, notes and bookmarks from every book collect here. Press and hold any passage while reading to start.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CollapseOnScroll(
          builder: (BuildContext context, bool collapsed) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                child: _searching
                    ? Padding(
                        key: const ValueKey<String>('search'),
                        padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, 14, Space.sm),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: SearchField(
                                hint: 'Search notes',
                                autofocus: true,
                                height: 48,
                                onChanged: (String q) => setState(() => _query = q.trim()),
                              ),
                            ),
                            AppIconButton(
                              icon: AppIcons.close,
                              filled: false,
                              semanticLabel: 'Close search',
                              onPressed: () => setState(() {
                                _searching = false;
                                _query = '';
                              }),
                            ),
                          ],
                        ),
                      )
                    : AppHeader(
                        key: const ValueKey<String>('header'),
                        title: 'Notes',
                        collapsed: collapsed,
                        actions: <Widget>[
                          AppIconButton(
                            icon: AppIcons.search,
                            semanticLabel: 'Search notes',
                            onPressed: () => setState(() => _searching = true),
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 6, bottom: Space.lg),
                      sliver: SliverToBoxAdapter(
                        child: ChipRow(
                          children: <Widget>[
                            PillChip(
                              label: 'All',
                              selected: _filter == null,
                              count: all.length,
                              onTap: () => setState(() => _filter = null),
                            ),
                            for (final HighlightColor h in HighlightColor.values)
                              PillChip(
                                label: h.label,
                                selected: _filter == h.index,
                                count: all
                                    .where(
                                      ((Annotation, Document?) x) => x.$1.kind == 'highlight' && x.$1.color == h.index,
                                    )
                                    .length,
                                leading: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: theme.highlights[h.index],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: c.outline),
                                  ),
                                ),
                                onTap: () => setState(() => _filter = _filter == h.index ? null : h.index),
                              ),
                            PillChip(
                              label: 'Bookmarks',
                              selected: _filter == -1,
                              count: all.where(((Annotation, Document?) x) => x.$1.kind == 'bookmark').length,
                              leading: const AppIcon(AppIcons.bookmark),
                              onTap: () => setState(() => _filter = _filter == -1 ? null : -1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (groups.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(Space.screen),
                          child: Text(
                            _query.isEmpty ? 'Nothing in this colour yet.' : 'Nothing matches “$_query”.',
                            style: UnfurlType.body.copyWith(color: c.onSurfaceVariant),
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.bottomSafe),
                      sliver: SliverList.builder(
                        itemCount: groups.length,
                        itemBuilder: (BuildContext context, int i) {
                          final List<(Annotation, Document?)> g = groups.values.elementAt(i);
                          final Document? d = g.first.$2;
                          final String title = d?.title ?? d?.name ?? 'Document';
                          return Reveal(
                            index: i < 6 ? i : 0,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: Space.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: 10,
                                children: <Widget>[
                                  SectionHeader(
                                    label: '$title · ${g.length}',
                                    action: _filter == null && _query.isEmpty ? 'Export' : null,
                                    onAction: () => _export(title, g),
                                  ),
                                  ListContainer(
                                    children: <Widget>[
                                      for (final (Annotation a, Document? doc) in g)
                                        _NoteRow(annotation: a, doc: doc, theme: theme),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(String title, List<(Annotation, Document?)> g) async {
    final StringBuffer md = StringBuffer('# $title\n');
    final List<Annotation> items = g.map(((Annotation, Document?) x) => x.$1).toList()
      ..sort((Annotation a, Annotation b) => a.progress.compareTo(b.progress));
    for (final Annotation a in items) {
      if (a.kind == 'bookmark') {
        md.write('\n- Bookmark: ${a.label}\n');
      } else {
        md.write('\n> ${a.quote.replaceAll('\n', '\n> ')}\n\n${a.label}\n');
        if (a.note != null) md.write('\n${a.note}\n');
      }
    }
    await Platform.shareText(md.toString(), subject: 'Highlights from $title');
  }
}

class _NoteRow extends ConsumerWidget {
  const _NoteRow({required this.annotation, required this.doc, required this.theme});

  final Annotation annotation;
  final Document? doc;
  final ReadingTheme theme;

  void _open(BuildContext context) => unawaited(
    openDocument(
      context,
      DocRef(uri: doc!.uri, name: doc!.name, size: doc!.size),
      at: Locator.fromJson(annotation.locator),
      mode: annotation.mode,
    ),
  );

  /// Board 6, V5: Go to page, Edit note, Copy, Share as card, Delete.
  Future<void> _menu(BuildContext context, BuildContext anchor, WidgetRef ref) async {
    final Annotation a = annotation;
    final String? v = await showAppMenu<String>(
      context: context,
      anchorContext: anchor,
      entries: <AppMenuEntry<String>>[
        if (doc != null) const AppMenuEntry<String>(value: 'open', label: 'Go to page', icon: AppIcons.arrowOutward),
        AppMenuEntry<String>(value: 'note', label: a.note == null ? 'Add note' : 'Edit note', icon: AppIcons.editNote),
        const AppMenuEntry<String>(value: 'copy', label: 'Copy', icon: AppIcons.copy),
        const AppMenuEntry<String>(value: 'card', label: 'Share as card', icon: AppIcons.image),
        const AppMenuEntry<String>.divider(),
        const AppMenuEntry<String>(value: 'delete', label: 'Delete', icon: AppIcons.delete, danger: true),
      ],
    );
    if (!context.mounted) return;
    final Library library = ref.read(libraryProvider);
    switch (v) {
      case 'open':
        _open(context);
      case 'note':
        final String? text = await showNoteSheet(
          context,
          quote: a.quote,
          color: theme.highlights[(a.color ?? 0).clamp(0, 3)],
          initial: a.note,
        );
        if (text != null) {
          await library.updateAnnotation(a.id, note: text.isEmpty ? null : text, clearNote: text.isEmpty);
        }
      case 'copy':
        await copyText(a.quote);
        if (context.mounted) AppSnackbar.info(context, 'Copied');
      case 'card':
        await showCardEditor(
          context,
          CardContent(
            quote: a.quote,
            title: doc?.title ?? doc?.name.replaceAll(RegExp(r'\.[^.]+$'), '') ?? '',
            author: doc?.author,
            location: a.label,
            fingerprint: a.fingerprint,
            format: doc == null ? null : Formats.of(doc!.name),
          ),
        );
      case 'delete':
        await library.deleteAnnotation(a.id);
        if (context.mounted) AppSnackbar.undo(context, 'Removed', () => library.restoreAnnotation(a));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final Annotation a = annotation;
    final bool bookmark = a.kind == 'bookmark';
    return InkWell(
      onTap: doc == null ? null : () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: <Widget>[
            Row(
              spacing: 6,
              children: <Widget>[
                AppIcon(bookmark ? AppIcons.bookmark : AppIcons.notes, size: 16, color: c.onSurfaceVariant),
                Expanded(
                  child: Text(
                    '${a.label} · ${Files.ago(a.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                  ),
                ),
                if (!bookmark)
                  SizedBox(
                    height: 24,
                    child: OverflowBox(
                      maxHeight: IconSpec.tapTarget,
                      child: Builder(
                        builder: (BuildContext anchor) => AppIconButton(
                          icon: AppIcons.moreVert,
                          filled: false,
                          semanticLabel: 'Highlight actions',
                          onPressed: () => unawaited(_menu(context, anchor, ref)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (bookmark)
              Text(a.label.isEmpty ? a.quote : a.label, style: UnfurlType.titleMedium.copyWith(color: c.onSurface))
            else
              HighlightQuote(text: a.quote, color: theme.highlights[(a.color ?? 0).clamp(0, 3)]),
            if (a.note != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: <Widget>[
                  AppIcon(AppIcons.editNote, size: 18, color: c.onSurfaceVariant),
                  Expanded(
                    child: Text(a.note!, style: UnfurlType.note.copyWith(color: c.onSurfaceVariant)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
