import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/explorer.dart';
import '../../core/files.dart';
import '../../core/open.dart';
import '../../core/platform/platform.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/buttons.dart';
import '../../design_system/sheets.dart';
import '../../formats/format_registry.dart';
import 'files_widgets.dart';

/// Board 5, X4: the read-only sheets for a file in Files. There is no
/// rename, move, copy or delete anywhere.

/// A file on the phone, by path.
@immutable
class PathFile {
  const PathFile({required this.path, required this.size, required this.modified});

  final String path;
  final int size;
  final int modified;

  String get name => PathNames.nameOf(path);
  String get uri => Uri.file(path).toString();
  FormatModule? get format => Formats.of(name);

  DocRef get ref => DocRef(uri: uri, name: name, size: size, modified: modified, mime: mimeOf(name));

  /// "PDF", "ZIP".
  String get type => Formats.labelOf(name);

  static String? mimeOf(String name) {
    final FormatModule? m = Formats.of(name);
    if (m == null || m.mimes.isEmpty) return null;
    final String ext = name.contains('.') ? name.substring(name.lastIndexOf('.') + 1).toLowerCase() : '';
    // Images list several types; pick the one the extension names.
    return m.mimes.firstWhere((String t) => t.endsWith('/$ext'), orElse: () => m.mimes.first);
  }
}

/// The icon and tile a file gets in Files lists.
(IconData, TileKind) fileLook(String name) {
  final FormatModule? m = Formats.of(name);
  if (m == null) return (unknownIcon(name), TileKind.muted);
  return (m.icon, m.book ? TileKind.accent : TileKind.box);
}

IconData unknownIcon(String name) {
  final String ext = name.contains('.') ? name.substring(name.lastIndexOf('.') + 1).toLowerCase() : '';
  return switch (ext) {
    'zip' || 'rar' || '7z' || 'tar' || 'gz' => AppIcons.folderZip,
    'apk' || 'xapk' => AppIcons.android,
    'mp3' || 'm4a' || 'wav' || 'ogg' || 'flac' || 'aac' || 'opus' => AppIcons.audioFile,
    'mp4' || 'mkv' || 'mov' || 'avi' || 'webm' || '3gp' => AppIcons.movie,
    'r' || 'py' || 'js' || 'dart' || 'json' || 'html' || 'css' || 'java' || 'kt' || 'xml' => AppIcons.code,
    _ => AppIcons.description,
  };
}

/// "18 Sep", "18 Sep 2026, 09:42".
String _date(int millis, {bool full = false}) {
  final DateTime t = DateTime.fromMillisecondsSinceEpoch(millis);
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final String d = '${t.day} ${months[t.month - 1]}';
  if (!full) return d;
  String two(int n) => n.toString().padLeft(2, '0');
  return '$d ${t.year}, ${two(t.hour)}:${two(t.minute)}';
}

String _bytes(int n) {
  final String s = n.toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// "Page view and Reader mode", "Reader", "Another app".
String opensIn(FormatModule? m) {
  if (m == null) return 'Another app';
  return switch (m.view) {
    ViewKind.page => m.readerMode ? 'Page view and Reader mode' : 'Page view',
    ViewKind.reader => 'Reader',
    ViewKind.slides => 'Slides and Reader mode',
    ViewKind.grid => 'Sheet view',
    ViewKind.image => 'Image viewer',
    ViewKind.comics => 'Comics viewer',
  };
}

/// "PDF document", "EPUB book", "ZIP file".
String typeName(String name) {
  final FormatModule? m = Formats.of(name);
  final String label = Formats.labelOf(name);
  if (m == null) return '$label file';
  return switch (m.group) {
    FormatGroup.pdf => 'PDF document',
    FormatGroup.epub => 'EPUB book',
    FormatGroup.kindle => '$label Kindle book',
    FormatGroup.fb2 => '$label book',
    FormatGroup.comics => '$label comic',
    FormatGroup.documents => '$label document',
    FormatGroup.sheets => '$label spreadsheet',
    FormatGroup.slides => '$label presentation',
    FormatGroup.images => '$label image',
  };
}

/// The file at the top of a Files sheet: tile, name, meta.
class _FileHeader extends StatelessWidget {
  const _FileHeader({required this.file, this.withDate = true});

  final PathFile file;
  final bool withDate;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final (IconData icon, TileKind kind) = fileLook(file.name);
    return Row(
      spacing: 14,
      children: <Widget>[
        RowTile(icon: icon, kind: kind, size: 48),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: UnfurlType.title.copyWith(fontSize: 16, height: 1.3, color: c.onSurface),
              ),
              Text(
                <String>[file.type, Files.size(file.size), if (withDate) _date(file.modified)].join(' · '),
                style: UnfurlType.monoLabel.copyWith(height: 1.5, color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.thumbR,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Row(
            spacing: Space.lg,
            children: <Widget>[
              AppIcon(icon, color: c.icon),
              Text(label, style: UnfurlType.titleMedium.copyWith(color: c.onSurface).weight(500)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Long-press a file: Open, Open with, Share, Info.
Future<void> showFileActions(BuildContext context, PathFile file) => showAppBottomSheet<void>(
  context: context,
  builder: (BuildContext ctx) {
    void then(VoidCallback f) {
      Navigator.of(ctx).pop();
      f();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: <Widget>[
        _FileHeader(file: file),
        Column(
          children: <Widget>[
            _ActionRow(
              icon: AppIcons.menuBook,
              label: 'Open',
              onTap: () => then(() => unawaited(openPathFile(context, file))),
            ),
            _ActionRow(
              icon: AppIcons.openInNew,
              label: 'Open with',
              onTap: () => then(() => unawaited(Platform.openWith(file.uri, file.ref.mime))),
            ),
            _ActionRow(
              icon: AppIcons.shareAndroid,
              label: 'Share',
              onTap: () => then(() => unawaited(Platform.shareFile(file.uri, file.ref.mime))),
            ),
            _ActionRow(
              icon: AppIcons.info,
              label: 'Info',
              onTap: () => then(() => unawaited(showFileInfo(context, file))),
            ),
          ],
        ),
      ],
    );
  },
);

/// A file Unfurl reads opens; anything else offers another app.
Future<void> openPathFile(BuildContext context, PathFile file) =>
    file.format == null ? showCantOpen(context, file) : openDocument(context, file.ref);

/// Type, Size, Modified, Location, Opens in.
Future<void> showFileInfo(BuildContext context, PathFile file) => showAppBottomSheet<void>(
  context: context,
  builder: (BuildContext ctx) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 14,
    children: <Widget>[
      _FileHeader(file: file, withDate: false),
      _KeyValues(<(String, String)>[
        ('Type', typeName(file.name)),
        ('Size', '${Files.size(file.size)} (${_bytes(file.size)} bytes)'),
        ('Modified', _date(file.modified, full: true)),
        ('Location', PathNames.readable(PathNames.parentOf(file.path))),
        ('Opens in', opensIn(file.format)),
      ]),
    ],
  ),
  actions: <Widget>[
    Builder(
      builder: (BuildContext ctx) => AppButton(
        label: file.format == null ? 'Open in another app' : 'Open',
        icon: file.format == null ? AppIcons.openInNew : AppIcons.menuBook,
        onPressed: () {
          Navigator.of(ctx).pop();
          unawaited(file.format == null ? Platform.openWith(file.uri, file.ref.mime) : openDocument(context, file.ref));
        },
      ),
    ),
  ],
);

/// "Unfurl can't open ZIP files."
Future<void> showCantOpen(BuildContext context, PathFile file) => showAppBottomSheet<void>(
  context: context,
  builder: (BuildContext ctx) {
    final UnfurlColors c = ctx.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: <Widget>[
        _FileHeader(file: file),
        Text('Unfurl can’t open ${file.type} files', style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
        Text('Another app on your phone may be able to.', style: UnfurlType.body.copyWith(color: c.onSurfaceVariant)),
      ],
    );
  },
  actions: <Widget>[
    Builder(
      builder: (BuildContext ctx) => AppButton(
        label: 'Open in another app',
        icon: AppIcons.openInNew,
        onPressed: () {
          Navigator.of(ctx).pop();
          unawaited(Platform.openWith(file.uri, file.ref.mime));
        },
      ),
    ),
    Builder(
      builder: (BuildContext ctx) =>
          AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Navigator.of(ctx).pop()),
    ),
  ],
);

/// Folder info from the folder menu.
Future<void> showFolderInfo(
  BuildContext context, {
  required String path,
  required int files,
  required int folders,
  required int readable,
}) => showAppBottomSheet<void>(
  context: context,
  icon: AppIcons.folder,
  title: PathNames.nameOf(path),
  builder: (BuildContext ctx) => _KeyValues(<(String, String)>[
    ('Type', 'Folder'),
    (
      'Contains',
      '${grouped(files)} ${files == 1 ? 'file' : 'files'}, ${grouped(folders)} ${folders == 1 ? 'folder' : 'folders'}',
    ),
    ('Readable', '${grouped(readable)} ${readable == 1 ? 'file' : 'files'} Unfurl opens'),
    ('Location', PathNames.readable(path)),
  ]),
);

class _KeyValues extends StatelessWidget {
  const _KeyValues(this.rows);

  final List<(String, String)> rows;

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
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: c.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.md,
                children: <Widget>[
                  SizedBox(
                    width: 84,
                    child: Text(
                      rows[i].$1,
                      style: UnfurlType.monoLabel.copyWith(height: 1.6, color: c.onSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    child: Text(rows[i].$2, style: UnfurlType.body.copyWith(fontSize: 14, color: c.onSurface)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Next, Android asks": what Android's page will say, before it says it.
/// True to continue to settings.
Future<bool> showPermissionPreSheet(BuildContext context) async =>
    await showAppBottomSheet<bool>(
      context: context,
      icon: AppIcons.openInNew,
      title: 'Next, Android asks',
      description: 'Android opens its All files access page. Turn on the switch, then come back here.',
      builder: (BuildContext ctx) {
        final UnfurlColors c = ctx.colors;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: Radii.cardR,
                border: Border.all(color: c.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: <Widget>[
                  Text(
                    'You’ll see, in Android settings',
                    style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                  ),
                  Row(
                    spacing: Space.md,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Allow access to manage all files',
                          style: UnfurlType.titleMedium.copyWith(color: c.onSurface).weight(500),
                        ),
                      ),
                      // A picture of Android's switch, not a control.
                      ExcludeSemantics(
                        child: IgnorePointer(child: Switch(value: true, onChanged: (_) {})),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: <Widget>[
                AppIcon(AppIcons.info, size: 20, color: c.onSurfaceVariant),
                Expanded(
                  child: Text(
                    'Android’s description mentions modifying and deleting files. Unfurl can only open, share and show info, and it has no internet access.',
                    style: UnfurlType.note.copyWith(height: 1.55, color: c.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        );
      },
      actions: <Widget>[
        Builder(
          builder: (BuildContext ctx) => AppButton(
            label: 'Continue to settings',
            icon: AppIcons.openInNew,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
        Builder(
          builder: (BuildContext ctx) =>
              AppButton(label: 'Not now', type: AppButtonType.text, onPressed: () => Navigator.of(ctx).pop(false)),
        ),
      ],
    ) ??
    false;
