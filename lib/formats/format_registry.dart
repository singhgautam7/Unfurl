import 'package:flutter/widgets.dart';

import '../core/platform/platform.dart';
import '../design_system/app_icon.dart';

/// How a format opens by default.
enum ViewKind { page, reader, slides, grid, image }

/// The type chips in a folder ("PDF", "Documents", "Sheets"...).
enum FormatGroup {
  pdf('PDF'),
  epub('EPUB'),
  documents('Documents'),
  sheets('Sheets'),
  slides('Slides'),
  text('Text'),
  images('Images');

  const FormatGroup(this.label);
  final String label;
}

/// One format's contract (the extensibility rule): what it handles, how it
/// opens, and what it can do. The UI reads capabilities from here and omits
/// a control a format cannot use; adding a format means adding a module.
@immutable
class FormatModule {
  const FormatModule({
    required this.id,
    required this.label,
    required this.extensions,
    required this.mimes,
    required this.view,
    required this.group,
    required this.icon,
    this.readerMode = false,
    this.annotations = false,
    this.tts = false,
    this.search = true,
    this.book = false,
  });

  final String id;

  /// "PDF", "DOCX": the format label on tiles and meta lines.
  final String label;
  final List<String> extensions;
  final List<String> mimes;
  final ViewKind view;
  final FormatGroup group;
  final IconData icon;

  /// Can unfurl into Reader mode (a [ViewKind.reader] format always is).
  final bool readerMode;

  /// Highlights, notes and bookmarks (in Reader mode, and on PDF pages).
  final bool annotations;
  final bool tts;
  final bool search;

  /// A Tier 1 book: listed in Library, full reader.
  final bool book;

  /// Has a Page view and a Reader view to toggle between.
  bool get hasModeToggle => readerMode && view != ViewKind.reader;
}

abstract final class Formats {
  static const FormatModule pdf = FormatModule(
    id: 'pdf',
    label: 'PDF',
    extensions: <String>['pdf'],
    mimes: <String>['application/pdf'],
    view: ViewKind.page,
    group: FormatGroup.pdf,
    icon: AppIcons.pdf,
    readerMode: true,
    annotations: true,
    tts: true,
    book: true,
  );
  static const FormatModule epub = FormatModule(
    id: 'epub',
    label: 'EPUB',
    extensions: <String>['epub'],
    mimes: <String>['application/epub+zip'],
    view: ViewKind.reader,
    group: FormatGroup.epub,
    icon: AppIcons.book,
    readerMode: true,
    annotations: true,
    tts: true,
    book: true,
  );
  static const FormatModule docx = FormatModule(
    id: 'docx',
    label: 'DOCX',
    extensions: <String>['docx'],
    mimes: <String>['application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    view: ViewKind.page,
    group: FormatGroup.documents,
    icon: AppIcons.description,
    readerMode: true,
    annotations: true,
    tts: true,
  );
  static const FormatModule pptx = FormatModule(
    id: 'pptx',
    label: 'PPTX',
    extensions: <String>['pptx'],
    mimes: <String>['application/vnd.openxmlformats-officedocument.presentationml.presentation'],
    view: ViewKind.slides,
    group: FormatGroup.slides,
    icon: AppIcons.slideshow,
    readerMode: true,
    annotations: true,
    tts: true,
  );
  static const FormatModule xlsx = FormatModule(
    id: 'xlsx',
    label: 'XLSX',
    extensions: <String>['xlsx'],
    mimes: <String>['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
    view: ViewKind.grid,
    group: FormatGroup.sheets,
    icon: AppIcons.tableView,
  );
  static const FormatModule xls = FormatModule(
    id: 'xls',
    label: 'XLS',
    extensions: <String>['xls'],
    mimes: <String>['application/vnd.ms-excel'],
    view: ViewKind.grid,
    group: FormatGroup.sheets,
    icon: AppIcons.tableView,
  );
  static const FormatModule ods = FormatModule(
    id: 'ods',
    label: 'ODS',
    extensions: <String>['ods'],
    mimes: <String>['application/vnd.oasis.opendocument.spreadsheet'],
    view: ViewKind.grid,
    group: FormatGroup.sheets,
    icon: AppIcons.tableView,
  );
  static const FormatModule csv = FormatModule(
    id: 'csv',
    label: 'CSV',
    extensions: <String>['csv'],
    mimes: <String>['text/csv', 'text/comma-separated-values'],
    view: ViewKind.grid,
    group: FormatGroup.sheets,
    icon: AppIcons.tableView,
  );
  static const FormatModule md = FormatModule(
    id: 'md',
    label: 'MD',
    extensions: <String>['md', 'markdown'],
    mimes: <String>['text/markdown', 'text/x-markdown'],
    view: ViewKind.reader,
    group: FormatGroup.text,
    icon: AppIcons.article,
    readerMode: true,
    annotations: true,
    tts: true,
  );
  static const FormatModule txt = FormatModule(
    id: 'txt',
    label: 'TXT',
    extensions: <String>['txt', 'text'],
    mimes: <String>['text/plain'],
    view: ViewKind.reader,
    group: FormatGroup.text,
    icon: AppIcons.notesText,
    readerMode: true,
    annotations: true,
    tts: true,
  );
  static const FormatModule image = FormatModule(
    id: 'image',
    label: 'IMAGE',
    extensions: <String>['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif'],
    mimes: <String>['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/bmp', 'image/heic', 'image/heif'],
    view: ViewKind.image,
    group: FormatGroup.images,
    icon: AppIcons.image,
    search: false,
  );

  static const List<FormatModule> all = <FormatModule>[pdf, epub, docx, pptx, xlsx, xls, ods, csv, md, txt, image];

  static final Map<String, FormatModule> _byExt = <String, FormatModule>{
    for (final FormatModule m in all)
      for (final String e in m.extensions) e: m,
  };
  static final Map<String, FormatModule> _byMime = <String, FormatModule>{
    for (final FormatModule m in all)
      for (final String t in m.mimes) t: m,
  };

  /// The module for a file name (extension first, then MIME type), or null
  /// when Unfurl cannot open it.
  static FormatModule? of(String name, [String? mime]) {
    final int dot = name.lastIndexOf('.');
    final String ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return _byExt[ext] ?? (mime == null ? null : _byMime[mime]);
  }

  static FormatModule? ofRef(DocRef ref) => of(ref.name, ref.mime);

  /// The label for a tile: the module's, or the bare extension.
  static String labelOf(String name) {
    final FormatModule? m = of(name);
    if (m != null && m != image) return m.label;
    final int dot = name.lastIndexOf('.');
    return dot < 0 ? 'FILE' : name.substring(dot + 1).toUpperCase();
  }

  /// MIME types for the system file picker.
  static List<String> get pickerMimes => <String>[for (final FormatModule m in all) ...m.mimes];
}
