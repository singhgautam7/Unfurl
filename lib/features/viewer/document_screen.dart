import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/files.dart';
import '../../core/library/access.dart';
import '../../core/library/library.dart';
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
import '../../design_system/app_snackbar.dart';
import '../../design_system/buttons.dart';
import '../../design_system/covers.dart';
import '../../design_system/states.dart';
import '../../formats/format_problem.dart';
import '../../formats/format_registry.dart';
import '../comics/comics_screen.dart';
import '../office/image_screen.dart';
import '../office/office_screens.dart';
import '../office/sheet_screen.dart';
import '../pdf/pdf_screen.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_controller.dart';
import 'access_view.dart';

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

class _DocumentScreenState extends ConsumerState<DocumentScreen> {
  OpenedDoc? _doc;
  bool _unsupported = false;
  FormatProblem? _problem;
  AccessProblem? _access;

  @override
  void initState() {
    super.initState();
    _library = ref.read(libraryProvider);
    unawaited(_open(widget.request.ref));
  }

  late final Library _library;

  @override
  void dispose() {
    // The viewer has saved its place by now; Home and Library catch up once.
    if (_doc != null) _library.documentsChanged();
    super.dispose();
  }

  /// Opens [asked]; [relinkFrom] is the URI it was known by before, whose
  /// Recents row moves with it.
  Future<void> _open(DocRef asked, {String? relinkFrom}) async {
    final FormatModule? byName = Formats.ofRef(asked);
    if (byName == null) return setState(() => _unsupported = true);
    FormatModule format = byName;
    DocRef? file = await Platform.stat(asked.uri);
    if (file == null) {
      // Not readable here: the same file somewhere Unfurl may read, or why not.
      final (DocRef? found, AccessProblem? problem) = await _library.locate(asked);
      if (!mounted) return;
      if (found == null) return setState(() => _access = problem);
      file = found;
      relinkFrom ??= asked.uri;
    }
    final DocRef opened = file.withSource(asked.source);
    final String? fp = await Files.fingerprint(opened.uri);
    if (!mounted) return;
    if (fp == null) {
      final (_, AccessProblem? problem) = await _library.locate(asked);
      if (!mounted) return;
      return setState(() => _access = problem ?? AccessProblem(state: FileAccess.unknown, ref: asked));
    }
    // The first bytes decide where the extension misleads (board 6, V3).
    try {
      final Uint8List head =
          await Files.withFd<Uint8List>(opened.uri, (Fd fd) async => fd.read(0, 512)) ?? Uint8List(0);
      format = Formats.sniff(head, byName) ?? byName;
    } on FormatProblem catch (p) {
      return setState(() => _problem = p);
    }
    if (!mounted) return;
    final Library library = _library;
    final SettingsController settings = ref.read(settingsProvider.notifier);
    final Document record = await library.touch(fp, opened);
    // Only the same content keeps the old row's place in Recents.
    if (relinkFrom != null && await library.fingerprintAt(relinkFrom) == fp) {
      await library.relink(relinkFrom, opened, fp);
    } else {
      await library.addRecent(opened, fp);
      if (relinkFrom != null && mounted) {
        AppSnackbar.info(context, 'This is a different file. ${widget.request.ref.name} stays in Recents.');
      }
    }
    await settings.setOpenedFile();
    if (!mounted) return;
    setState(() {
      _access = null;
      _doc = OpenedDoc(
        ref: opened,
        fingerprint: fp,
        format: format,
        record: record,
        at: widget.request.at,
        mode: widget.request.mode,
        heroTag: widget.request.heroTag,
      );
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.of(context, Motion.fast),
    switchInCurve: Motion.decelerate,
    child: KeyedSubtree(
      key: ValueKey<Object>(_problem ?? (_unsupported ? 'unsupported' : _access ?? _doc?.fingerprint ?? 'opening')),
      child: _body(),
    ),
  );

  Widget _body() {
    final OpenedDoc? doc = _doc;
    if (_problem != null) return problemState(context, widget.request.ref, _problem!);
    if (_unsupported) return _unsupportedState(context, widget.request.ref);
    final AccessProblem? access = _access;
    if (access != null) {
      return AccessView(
        problem: access,
        onRelink: (DocRef to) => _open(to, relinkFrom: access.ref.uri),
        onGone: () => setState(
          () => _access = AccessProblem(
            state: FileAccess.gone,
            ref: access.ref,
            docId: access.docId,
            sender: access.sender,
            exists: false,
            folderApp: access.folderApp,
            sdk: access.sdk,
          ),
        ),
      );
    }
    if (doc == null) return OpeningCard(ref: widget.request.ref);
    return switch (doc.format.view) {
      ViewKind.page when doc.format == Formats.pdf => PdfScreen(doc: doc),
      ViewKind.page => DocxScreen(doc: doc),
      ViewKind.slides => PptxScreen(doc: doc),
      ViewKind.grid => SheetScreen(doc: doc),
      ViewKind.image => ImageScreen(doc: doc),
      ViewKind.reader => ReaderScreen(doc: doc),
      ViewKind.comics => ComicsScreen(doc: doc),
    };
  }
}

/// Board 4, V5: shown only once opening has taken 250ms.
/// A file on its way in: its name, type and size on a quiet card, shown
/// only if opening takes longer than the loading threshold. Heavy work
/// (Reader mode for a PDF, parsing a book) passes a [label] and a 0..1
/// [progress].
class OpeningCard extends StatelessWidget {
  const OpeningCard({
    required this.ref,
    this.label = 'Opening',
    this.progress,
    this.onClose,
    this.immediate = false,
    super.key,
  });

  final DocRef ref;
  final String label;
  final ValueListenable<double>? progress;

  /// Instead of leaving the document (Reader mode goes back to the page).
  final VoidCallback? onClose;

  /// Shown at once: a mode switch the reader asked for, under an animation
  /// that would otherwise reveal an empty page.
  final bool immediate;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final FormatModule? m = Formats.ofRef(ref);
    return Scaffold(
      body: Delayed(
        after: immediate ? Duration.zero : Delayed.threshold,
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
                            <String>[Formats.labelOf(ref.name), if (ref.size > 0) Files.size(ref.size)].join(' · '),
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

Widget _unsupportedState(BuildContext context, DocRef ref) => DocStateScaffold(
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
);

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

/// Board 6, V3: a file Unfurl recognises but can't read. DRM and a damaged
/// archive in the danger tone, an unsupported variant neutral; the file name,
/// format and cause in the mono box. [onOpenReadable] offers what could be read.
Widget problemState(BuildContext context, DocRef ref, FormatProblem p, {VoidCallback? onOpenReadable}) {
  final String ext = Formats.labelOf(ref.name);
  final FormatModule? m = Formats.ofRef(ref);
  final bool comic = m == Formats.comics;
  final (int, int)? readable = p.readable;
  final (IconData icon, EmptyTone tone, String title, String message, String detail) = switch (p.kind) {
    ProblemKind.drm => (
      AppIcons.lock,
      EmptyTone.danger,
      'This book is protected (DRM) and can’t be opened',
      'The store locked this file to its own app. Unfurl doesn’t remove DRM. Open it in the app you bought it from, or download a DRM-free copy if the store offers one.',
      '${ref.name} · $ext · ${p.detail}',
    ),
    ProblemKind.damaged when readable != null => (
      AppIcons.brokenImage,
      EmptyTone.danger,
      'This archive is damaged',
      'Unfurl could read ${readable.$1}${readable.$2 > readable.$1 ? ' of ${readable.$2}' : ''} pages. The file may not have finished downloading. Try copying or downloading it again.',
      '${ref.name} · $ext · ${readable.$2 > readable.$1 ? 'pages ${readable.$1 + 1}–${readable.$2} unreadable' : 'the end of the file is missing'}',
    ),
    ProblemKind.damaged => (
      AppIcons.brokenImage,
      EmptyTone.danger,
      comic ? 'This archive is damaged' : 'This file can’t be opened',
      'It looks damaged or incomplete. If it came from a download, try getting it again.',
      '${ref.name} · $ext · ${p.detail}',
    ),
    ProblemKind.unsupported => (
      AppIcons.help,
      EmptyTone.neutral,
      comic ? 'This comic archive type isn’t supported' : 'This Kindle file type isn’t supported',
      switch (p.detail) {
        'Topaz (AZW1)' => 'Unfurl opens MOBI, PRC, AZW and AZW3 (KF8). This file uses Topaz, an older Kindle format made from scanned pages.',
        'KFX' => 'Unfurl opens MOBI, PRC, AZW and AZW3 (KF8). This file uses KFX, a newer Kindle format.',
        'RAR 5 archive' =>
          'Unfurl opens CBZ, CB7, CBT and CBR made with RAR 4 or older. This comic was packed with RAR 5.',
        _ =>
          comic
              ? 'Unfurl opens CBZ, CBR, CB7 and CBT comics. This file’s archive couldn’t be read.'
              : 'Unfurl opens MOBI, PRC, AZW and AZW3 (KF8). This file uses a variant it can’t read.',
      },
      '${ref.name} · ${p.detail}',
    ),
  };
  return Scaffold(
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.xs, 0, 0),
            child: AppIconButton(
              icon: AppIcons.close,
              filled: false,
              semanticLabel: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: EmptyState(
              icon: icon,
              tone: tone,
              small: true,
              top: Space.xl,
              title: title,
              message: message,
              detail: detail,
              actions: <Widget>[
                if (onOpenReadable != null && readable != null)
                  AppButton(label: 'Open ${readable.$1} pages', onPressed: onOpenReadable)
                else
                  AppButton(
                    label: 'Open in another app',
                    icon: AppIcons.openInNew,
                    onPressed: () => Platform.openWith(ref.uri, ref.mime),
                  ),
                AppButton(label: 'Close', type: AppButtonType.text, onPressed: () => Navigator.of(context).maybePop()),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
