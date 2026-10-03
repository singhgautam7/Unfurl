import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/files.dart';
import '../../core/locator.dart';
import '../../core/open.dart';
import '../../core/platform/platform.dart';
import '../../core/providers.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/buttons.dart';
import '../../design_system/covers.dart';
import '../../design_system/states.dart';
import '../../formats/format_registry.dart';
import '../office/image_screen.dart';
import '../office/office_screens.dart';
import '../office/sheet_screen.dart';
import '../pdf/pdf_screen.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_controller.dart';

/// A document as the viewers receive it: the file, its identity, what
/// Unfurl remembers about it, and where to open it.
class OpenedDoc {
  const OpenedDoc({
    required this.ref,
    required this.fingerprint,
    required this.format,
    required this.record,
    this.at,
    this.mode,
    this.heroTag,
  });

  final DocRef ref;
  final String fingerprint;
  final FormatModule format;
  final Document record;

  /// A passage to open at (a note, a search hit); else the saved position.
  final Locator? at;

  /// 'page' or 'reader'; else the mode last used, else the format default.
  final String? mode;
  final Object? heroTag;

  Locator? get resume => at ?? (record.position == null ? null : Locator.fromJson(record.position!));
}

/// Opens a file: checks it is still there, identifies it (fingerprint),
/// records it, and hands it to its viewer. Most files land with no loader
/// at all; the card appears only after 250ms.
class DocumentScreen extends ConsumerStatefulWidget {
  const DocumentScreen({required this.request, super.key});

  final OpenRequest request;

  @override
  ConsumerState<DocumentScreen> createState() => _DocumentScreenState();
}

enum _Failure { missing, unsupported }

class _DocumentScreenState extends ConsumerState<DocumentScreen> {
  OpenedDoc? _doc;
  _Failure? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    final DocRef asked = widget.request.ref;
    final FormatModule? format = Formats.ofRef(asked);
    if (format == null) return setState(() => _failure = _Failure.unsupported);
    final DocRef? ref = await Platform.stat(asked.uri);
    final String? fp = ref == null ? null : await Files.fingerprint(ref.uri);
    if (!mounted) return;
    if (ref == null || fp == null) return setState(() => _failure = _Failure.missing);
    final Document record = await ref.let((DocRef r) => this.ref.read(libraryProvider).touch(fp, r));
    await this.ref.read(libraryProvider).addRecent(ref, fp);
    await this.ref.read(settingsProvider.notifier).setOpenedFile();
    if (!mounted) return;
    setState(
      () => _doc = OpenedDoc(
        ref: ref,
        fingerprint: fp,
        format: format,
        record: record,
        at: widget.request.at,
        mode: widget.request.mode,
        heroTag: widget.request.heroTag,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.of(context, Motion.fast),
    switchInCurve: Motion.decelerate,
    child: KeyedSubtree(key: ValueKey<Object>(_failure ?? _doc?.fingerprint ?? 'opening'), child: _body()),
  );

  Widget _body() {
    final OpenedDoc? doc = _doc;
    if (_failure != null) return _FailureView(failure: _failure!, ref: widget.request.ref);
    if (doc == null) return OpeningCard(ref: widget.request.ref);
    return switch (doc.format.view) {
      ViewKind.page when doc.format == Formats.pdf => PdfScreen(doc: doc),
      ViewKind.page => DocxScreen(doc: doc),
      ViewKind.slides => PptxScreen(doc: doc),
      ViewKind.grid => SheetScreen(doc: doc),
      ViewKind.image => ImageScreen(doc: doc),
      ViewKind.reader => ReaderScreen(doc: doc),
    };
  }
}

extension<T> on T {
  R let<R>(R Function(T it) f) => f(this);
}

/// Board 4, V5: shown only once opening has taken 250ms.
/// A file on its way in: its name, type and size on a quiet card, shown
/// only if opening takes longer than the loading threshold. Heavy work
/// (Reader mode for a PDF, parsing a book) passes a [label] and a 0..1
/// [progress].
class OpeningCard extends StatelessWidget {
  const OpeningCard({required this.ref, this.label = 'Opening', this.progress, this.onClose, super.key});

  final DocRef ref;
  final String label;
  final ValueListenable<double>? progress;

  /// Instead of leaving the document (Reader mode goes back to the page).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final FormatModule? m = Formats.ofRef(ref);
    return Scaffold(
      body: Delayed(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const LoadingHairline(visible: true),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xs, 6, Space.xs, Space.sm),
                child: AppIconButton(
                  icon: AppIcons.close,
                  filled: false,
                  semanticLabel: 'Close',
                  onPressed: onClose ?? () => Navigator.of(context).maybePop(),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Space.xl),
                  decoration: BoxDecoration(
                    color: c.surfaceContainer,
                    borderRadius: Radii.wordCardR,
                    border: Border.all(color: c.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 14,
                    children: <Widget>[
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: c.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(Space.lg),
                        ),
                        child: AppIcon(m?.icon ?? AppIcons.description, size: 28, color: c.icon),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(ref.name, style: UnfurlType.title.copyWith(color: c.onSurface)),
                          Text(
                            <String>[
                              m?.label ?? ref.extension.toUpperCase(),
                              if (ref.size > 0) Files.size(ref.size),
                            ].join(' · '),
                            style: UnfurlType.monoLabel.copyWith(height: 1.6, color: c.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Text(label, style: UnfurlType.note.copyWith(color: c.onSurfaceVariant)),
                      if (progress != null)
                        ValueListenableBuilder<double>(
                          valueListenable: progress!,
                          builder: (BuildContext context, double v, Widget? _) => TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: v),
                            duration: Motion.of(context, Motion.fast),
                            curve: Motion.decelerate,
                            builder: (BuildContext context, double t, Widget? _) => ProgressTrack(value: t, height: 4),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailureView extends ConsumerWidget {
  const _FailureView({required this.failure, required this.ref});

  final _Failure failure;
  final DocRef ref;

  @override
  Widget build(BuildContext context, WidgetRef wref) => switch (failure) {
    _Failure.missing => DocStateScaffold(
      title: ref.name,
      state: EmptyState(
        icon: AppIcons.folderOff,
        tone: EmptyTone.neutral,
        small: true,
        title: 'Can’t find this file',
        message: 'It may have been moved, renamed or deleted, or Unfurl no longer has access to its folder.',
        actions: <Widget>[
          AppButton(
            label: 'Locate file',
            icon: AppIcons.search,
            onPressed: () async {
              final NavigatorState nav = Navigator.of(context);
              final DocRef? picked = await Platform.pickFile(Formats.pickerMimes);
              if (picked == null) return;
              await wref.read(libraryProvider).removeRecent(ref.uri);
              nav.pop();
              if (context.mounted) await openDocument(context, picked);
            },
          ),
          AppButton(
            label: 'Remove from recents',
            type: AppButtonType.secondary,
            onPressed: () async {
              await wref.read(libraryProvider).removeRecent(ref.uri);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    ),
    _Failure.unsupported => DocStateScaffold(
      title: ref.name,
      state: EmptyState(
        icon: AppIcons.helpCenter,
        tone: EmptyTone.neutral,
        small: true,
        title: 'Unfurl can’t open this type of file',
        message:
            '${ref.extension.toUpperCase()} files aren’t a format Unfurl reads. Another app on your phone may be able to.',
        actions: <Widget>[
          AppButton(
            label: 'Open in another app',
            icon: AppIcons.openInNew,
            onPressed: () => Platform.openWith(ref.uri, ref.mime),
          ),
        ],
      ),
    ),
  };
}

/// A blocking state inside a viewer: the bare top bar (back, file name) over
/// [EmptyState] (board 4, V6).
class DocStateScaffold extends StatelessWidget {
  const DocStateScaffold({required this.title, required this.state, super.key});

  final String title;
  final Widget state;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 64,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: Space.xs),
                  AppIconButton(
                    icon: AppIcons.back,
                    filled: false,
                    semanticLabel: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UnfurlType.titleMedium.copyWith(color: c.onSurface),
                    ),
                  ),
                  const SizedBox(width: Space.lg),
                ],
              ),
            ),
            Expanded(child: state),
          ],
        ),
      ),
    );
  }
}

/// "This file can't be opened": damaged or incomplete.
Widget corruptState(BuildContext context, DocRef ref) => DocStateScaffold(
  title: ref.name,
  state: EmptyState(
    icon: AppIcons.brokenImage,
    tone: EmptyTone.danger,
    small: true,
    title: 'This file can’t be opened',
    message: 'It looks damaged or incomplete. If it came from a download, try getting it again.',
    actions: <Widget>[
      AppButton(
        label: 'Open in another app',
        icon: AppIcons.openInNew,
        onPressed: () => Platform.openWith(ref.uri, ref.mime),
      ),
      AppButton(label: 'Close', type: AppButtonType.secondary, onPressed: () => Navigator.of(context).maybePop()),
    ],
  ),
);
