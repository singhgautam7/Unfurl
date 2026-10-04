import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../core/platform/platform.dart';
import '../design_system/app_icon.dart';
import 'format_problem.dart';

/// How a format opens by default.
enum ViewKind { page, reader, slides, grid, image, comics }

/// The type chips, in the spec's order (board 6, V3 `chipOrder`): All · PDF ·
/// EPUB · Kindle · FB2 · Comics · Documents, then the non-book families the
/// Files tab also shows.
enum FormatGroup {
  pdf('PDF'),
  epub('EPUB'),
  kindle('Kindle'),
  fb2('FB2'),
  comics('Comics'),
  documents('Documents'),
  sheets('Sheets'),
  slides('Slides'),
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

  /// Reading time counts here (every reader and viewer but images and
  /// spreadsheets), so Insights can be opened for it.
  bool get tracked => view != ViewKind.image && view != ViewKind.grid;
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
    // Slides only: no Reader mode (owner, 4 Oct 2026; docs/design-gaps.md),
    // so no highlights or read aloud either, which live in Reader mode.
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
    group: FormatGroup.documents,
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
    group: FormatGroup.documents,
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

  // v3 (board 6, V3-FORMATS): reflowable ebooks open in Reader view with
  // every Reader feature; comics in the Comics viewer.
  static const FormatModule kindle = FormatModule(
    id: 'kindle',
    label: 'MOBI',
    extensions: <String>['mobi', 'prc', 'azw', 'azw3', 'kf8'],
    mimes: <String>[
      'application/x-mobipocket-ebook',
      'application/vnd.amazon.ebook',
      'application/vnd.amazon.mobi8-ebook',
    ],
    view: ViewKind.reader,
    group: FormatGroup.kindle,
    icon: AppIcons.book,
    readerMode: true,
    annotations: true,
    tts: true,
    book: true,
  );
  static const FormatModule fb2 = FormatModule(
    id: 'fb2',
    label: 'FB2',
    extensions: <String>['fb2', 'fbz'],
    mimes: <String>[
      'application/x-fictionbook+xml',
      'application/x-fictionbook',
      'text/fb2+xml',
      'application/x-zip-compressed-fb2',
    ],
    view: ViewKind.reader,
    group: FormatGroup.fb2,
    icon: AppIcons.book,
    readerMode: true,
    annotations: true,
    tts: true,
    book: true,
  );
  static const FormatModule html = FormatModule(
    id: 'html',
    label: 'HTML',
    extensions: <String>['html', 'htm', 'xhtml', 'xht'],
    mimes: <String>['text/html', 'application/xhtml+xml'],
    view: ViewKind.reader,
    group: FormatGroup.documents,
    icon: AppIcons.html,
    readerMode: true,
    annotations: true,
    tts: true,
    book: true,
  );
  static const FormatModule comics = FormatModule(
    id: 'comics',
    label: 'CBZ',
    extensions: <String>['cbz', 'cbr', 'cb7', 'cbt'],
    mimes: <String>[
      'application/vnd.comicbook+zip',
      'application/vnd.comicbook-rar',
      'application/x-cbz',
      'application/x-cbr',
      'application/x-cb7',
      'application/x-cbt',
    ],
    view: ViewKind.comics,
    group: FormatGroup.comics,
    icon: AppIcons.comic,
    search: false,
    book: true,
  );

  static const List<FormatModule> all = <FormatModule>[
    pdf,
    epub,
    kindle,
    fb2,
    html,
    comics,
    docx,
    pptx,
    xlsx,
    xls,
    ods,
    csv,
    md,
    txt,
    image,
  ];

  /// Extensions the Library lists (and device discovery looks for).
  static final List<String> bookExtensions = <String>[
    for (final FormatModule m in all)
      if (m.book) ...m.extensions,
  ];

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
    final String lower = name.toLowerCase();
    if (lower.endsWith('.fb2.zip')) return fb2;
    final int dot = lower.lastIndexOf('.');
    final String ext = dot < 0 ? '' : lower.substring(dot + 1);
    return _byExt[ext] ?? (mime == null ? null : _byMime[mime]);
  }

  static FormatModule? ofRef(DocRef ref) => of(ref.name, ref.mime);

  /// The badge for a tile or row: the real extension, not the family
  /// ("AZW3", not "Kindle"; board 6, V3 badges).
  static String labelOf(String name) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.fb2.zip')) return 'FBZ';
    if (lower.endsWith('.jpeg')) return 'JPG';
    if (lower.endsWith('.htm')) return 'HTML';
    if (lower.endsWith('.markdown')) return 'MD';
    if (lower.endsWith('.text')) return 'TXT';
    final int dot = name.lastIndexOf('.');
    return dot < 0 ? 'FILE' : name.substring(dot + 1).toUpperCase();
  }

  /// What a file's first bytes say it is, where extensions mislead: a `.prc`
  /// or `.azw` may be MOBI, Topaz or KFX; a `.cbr` may really be a zip. Throws
  /// a [FormatProblem] for a protected file or a variant Unfurl can't read.
  static FormatModule? sniff(Uint8List head, FormatModule? byName) {
    bool starts(List<int> magic, [int at = 0]) {
      if (head.length < at + magic.length) return false;
      for (int i = 0; i < magic.length; i++) {
        if (head[at + i] != magic[i]) return false;
      }
      return true;
    }

    String text(int at, int length) =>
        head.length < at + length ? '' : latin1.decode(Uint8List.sublistView(head, at, at + length));

    if (text(0, 3) == 'TPZ') throw const FormatProblem(ProblemKind.unsupported, 'Topaz (AZW1)');
    if (starts(<int>[0xEA, 0x44, 0x52, 0x4D, 0x49, 0x4F, 0x4E, 0xEE])) {
      throw const FormatProblem(ProblemKind.drm, 'KFX · Kindle DRM');
    }
    if (text(0, 4) == 'CONT' && byName == kindle) throw const FormatProblem(ProblemKind.unsupported, 'KFX');
    final String palm = text(60, 8);
    if (palm == 'BOOKMOBI' || palm == 'TEXtREAd') return kindle;
    if (text(0, 5) == '%PDF-') return pdf;
    if (starts(<int>[0x50, 0x4B, 0x03, 0x04])) {
      if (text(30, 28) == 'mimetypeapplication/epub+zip') return epub;
      return byName;
    }
    if (starts(<int>[0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]) && byName == comics) {
      throw const FormatProblem(ProblemKind.unsupported, 'RAR 5 archive');
    }
    return byName;
  }

  /// MIME types for the system file picker.
  /// Plus the generic stream type, which providers often give Kindle, FB2 and
  /// comic files; the extension decides once picked.
  static List<String> get pickerMimes => <String>[
    for (final FormatModule m in all) ...m.mimes,
    'application/octet-stream',
  ];
}
