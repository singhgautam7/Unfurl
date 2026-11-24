import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/library/access.dart';
import '../../core/platform/platform.dart';
import '../../core/providers.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/app_snackbar.dart';
import '../../design_system/buttons.dart';
import '../../design_system/states.dart';
import '../../formats/format_registry.dart';
import 'document_screen.dart' show DocStateScaffold;

/// A file from Recents that can't be opened now: what is true, and the ways
/// forward. Never blames the file for a limit of Android or of Unfurl, and
/// never says a file is gone unless its exact place was looked at.
class AccessView extends ConsumerWidget {
  const AccessView({required this.problem, required this.onRelink, required this.onGone, super.key});

  final AccessProblem problem;

  /// The file again, at a URI Unfurl may read.
  final Future<void> Function(DocRef to) onRelink;

  /// The folder was allowed and the file isn't in it.
  final VoidCallback onGone;

  String get _folder => problem.docId!.folder.label;

  String get _title => switch (problem.state) {
    FileAccess.gone => 'This file isn’t there anymore',
    FileAccess.unknown => switch (problem.sender) {
      final String app => 'Open it again from $app',
      null => 'Open it again where you found it',
    },
    _ => 'Unfurl isn’t allowed in this folder',
  };

  String get _message => switch (problem.state) {
    FileAccess.gone =>
      'It was in $_folder. It may have been moved or deleted. Your place, highlights and notes are kept.',
    FileAccess.unknown => switch (problem.sender) {
      final String app =>
        'Unfurl can only read files you’ve given it permission to read. This one can only be opened again from $app, '
            'where you first opened it. Your place, highlights and notes will be there.',
      null =>
        'Unfurl can only read files you’ve given it permission to read. This one can only be opened again from the '
            'app you first opened it from. Your place, highlights and notes will be there.',
    },
    _ when problem.canAllow =>
      '${problem.exists ?? false ? 'The file is still in $_folder, but' : 'The file was in $_folder.'} Unfurl can only open files in '
          'folders you’ve allowed. Allow this folder and it opens from now on.',
    _ =>
      '${problem.exists ?? false ? 'The file is still in $_folder, but' : 'The file was in $_folder.'} Android doesn’t let apps use that '
          'whole folder. Pick the file yourself and it opens from now on.',
  };

  Future<void> _allow(BuildContext context, WidgetRef ref) async {
    final DocId at = problem.docId!;
    final List<String> before = await Platform.persistedFolders();
    final PickedFolder? picked = await Platform.pickFolder(initial: at.folder.id);
    if (picked == null) return;
    final String? uri = await Platform.fileInFolder(picked.uri, at.id);
    if (uri == null) {
      // Not this file's folder. What was allowed before stays allowed.
      if (!before.contains(picked.uri)) await Platform.releaseFolder(picked.uri);
      if (context.mounted) AppSnackbar.info(context, 'That folder doesn’t hold this file. Pick ${at.folder.label}.');
      return;
    }
    await ref.read(libraryProvider).addFolder(picked);
    final DocRef? file = await Platform.stat(uri);
    if (file == null) return onGone();
    await onRelink(file);
  }

  Future<void> _pick(BuildContext context) async {
    final DocRef? picked = await Platform.pickFile(Formats.pickerMimes, initial: problem.docId?.folder.id);
    if (picked != null) await onRelink(picked);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    await ref.read(libraryProvider).forgetRecent(problem.ref.uri);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppButton pick(AppButtonType type) => AppButton(
      label: 'Pick the file',
      icon: AppIcons.fileOpen,
      type: type,
      onPressed: () => unawaited(_pick(context)),
    );
    final Widget remove = AppButton(
      label: 'Remove from Recents',
      type: switch (problem.state) {
        FileAccess.gone => AppButtonType.primary,
        FileAccess.unknown => AppButtonType.secondary,
        _ => AppButtonType.text,
      },
      onPressed: () => unawaited(_remove(context, ref)),
    );
    return DocStateScaffold(
      title: problem.ref.name,
      state: EmptyState(
        icon: problem.state == FileAccess.gone ? AppIcons.folderOff : AppIcons.lock,
        tone: EmptyTone.neutral,
        small: true,
        title: _title,
        message: _message,
        actions: <Widget>[
          if (problem.canAllow)
            AppButton(
              label: 'Allow this folder',
              icon: AppIcons.folderOpen,
              onPressed: () => unawaited(_allow(context, ref)),
            ),
          if (problem.state == FileAccess.noAccess && !problem.canAllow) pick(AppButtonType.primary),
          if (problem.canShowFolder)
            AppButton(
              label: 'Open in file manager',
              icon: AppIcons.openInNew,
              type: AppButtonType.secondary,
              onPressed: () => unawaited(Platform.openFolder(problem.docId!.folder.id)),
            ),
          remove,
          if (problem.state == FileAccess.gone) pick(AppButtonType.secondary),
        ],
      ),
    );
  }
}
