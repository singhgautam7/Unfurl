import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design_system/app_icon.dart';
import '../design_system/app_snackbar.dart';
import '../design_system/buttons.dart';
import '../design_system/sheets.dart';
import '../formats/format_registry.dart';
import 'db/database.dart';
import 'library/library.dart';
import 'locator.dart';
import 'platform/platform.dart';
import 'providers.dart';
import 'router/router.dart';

/// What the document route opens: the file, and optionally a place and a
/// mode (a note's passage, Resume).
class OpenRequest {
  const OpenRequest(this.ref, {this.at, this.mode, this.heroTag});

  final DocRef ref;
  final Locator? at;

  /// 'page' or 'reader'.
  final String? mode;
  final Object? heroTag;
}

/// Opens [ref] in its viewer, or explains why Unfurl can't.
Future<void> openDocument(BuildContext context, DocRef ref, {Locator? at, String? mode, Object? heroTag}) async {
  if (Formats.ofRef(ref) == null) return showUnsupportedSheet(context, ref);
  await context.push(
    Routes.document,
    extra: OpenRequest(ref, at: at, mode: mode, heroTag: heroTag),
  );
}

/// "Open file": the system picker, every format Unfurl reads. Works for files
/// inside Download, which a folder grant cannot reach.
Future<void> pickAndOpenFile(BuildContext context) async {
  final DocRef? ref = await Platform.pickFile(Formats.pickerMimes);
  if (ref != null && context.mounted) await openDocument(context, ref);
}

/// The add-folder pre-sheet (board 2, A6), then the system folder picker.
Future<Folder?> addFolderFlow(BuildContext context, WidgetRef ref, {bool explain = true}) async {
  if (explain) {
    final bool? go = await showAppBottomSheet<bool>(
      context: context,
      icon: AppIcons.createNewFolder,
      title: 'Add a folder',
      description: 'Choose a folder with your books or documents. Android doesn’t allow picking the whole Download folder, but any folder inside it works.',
      builder: (BuildContext ctx) => const _FileOpenNote(),
      actions: <Widget>[
        Builder(
          builder: (BuildContext ctx) => AppButton(
            label: 'Choose folder',
            icon: AppIcons.folderOpen,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
        Builder(
          builder: (BuildContext ctx) =>
              AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Navigator.of(ctx).pop(false)),
        ),
      ],
    );
    if (go != true) return null;
  }
  final PickedFolder? picked = await Platform.pickFolder();
  if (picked == null) return null;
  final Folder folder = await ref.read(libraryProvider).addFolder(picked);
  if (context.mounted) AppSnackbar.info(context, 'Added ${folder.name}. Unfurl only reads it.');
  return folder;
}

class _FileOpenNote extends StatelessWidget {
  const _FileOpenNote();

  @override
  Widget build(BuildContext context) => const _IconNote(
    icon: AppIcons.fileOpen,
    text: 'Files in Download can still be opened one at a time with Open file.',
  );
}

class _IconNote extends StatelessWidget {
  const _IconNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 10,
    children: <Widget>[
      AppIcon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium!
              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    ],
  );
}

/// A file Unfurl can't read: hand it to another app.
Future<void> showUnsupportedSheet(BuildContext context, DocRef ref) async {
  final String ext = ref.extension.toUpperCase();
  await showAppBottomSheet<void>(
    context: context,
    icon: AppIcons.folderZip,
    title: ref.name,
    description:
        'Unfurl can’t open ${ext.isEmpty ? 'this type of' : ext} files. Another app on your phone may be able to.',
    builder: (BuildContext ctx) => const SizedBox.shrink(),
    actions: <Widget>[
      Builder(
        builder: (BuildContext ctx) => AppButton(
          label: 'Open in another app',
          icon: AppIcons.openInNew,
          onPressed: () {
            Navigator.of(ctx).pop();
            unawaited(Platform.openWith(ref.uri, ref.mime));
          },
        ),
      ),
      Builder(
        builder: (BuildContext ctx) =>
            AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Navigator.of(ctx).pop()),
      ),
    ],
  );
}

/// Re-grants a folder whose access was removed: a picked folder through
/// Android's picker again; a Files folder lives on all-files access, which
/// only the Files tab's privacy card asks for.
Future<void> regrantFolder(BuildContext context, WidgetRef ref, Folder folder) async {
  if (folder.source != 'saf_folder') return context.go(Routes.files);
  await addFolderFlow(context, ref, explain: false);
}

/// The Library's ordering.
List<BookItem> sortBooks(List<BookItem> books, String sort) {
  final List<BookItem> out = List<BookItem>.of(books);
  switch (sort) {
    case 'title':
      out.sort((BookItem a, BookItem b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    case 'progress':
      out.sort((BookItem a, BookItem b) => b.progress.compareTo(a.progress));
    default:
      out.sort((BookItem a, BookItem b) {
        final DateTime? x = a.doc?.openedAt, y = b.doc?.openedAt;
        if (x != null || y != null) return (y ?? DateTime(0)).compareTo(x ?? DateTime(0));
        return b.entry.modified.compareTo(a.entry.modified);
      });
  }
  return out;
}

extension OpenRef on WidgetRef {
  Library get library => read(libraryProvider);
}
