import 'dart:typed_data';

import 'epub/epub.dart';
import 'fb2/fb2.dart';
import 'kindle/mobi.dart';
import 'reading_document.dart';
import 'text/text_formats.dart';

/// One door to every reflowable format, by registry id. Pure Dart, so the
/// reader and the library enricher call it inside an isolate.
abstract final class Books {
  static ReadingDocument document(String format, Uint8List bytes, String name) => switch (format) {
    'epub' => Epub.open(bytes).document(),
    'kindle' => Mobi.open(bytes).document(),
    'fb2' => Fb2.open(bytes).document(),
    'html' => TextFormats.html(bytes, name),
    'md' => TextFormats.markdown(bytes, name),
    _ => TextFormats.plain(bytes, name),
  };

  /// Title, author and cover for the library index, without converting the
  /// whole book where the format allows.
  static BookMeta meta(String format, Uint8List bytes, String name) => switch (format) {
    'epub' => Epub.open(bytes).meta(),
    'kindle' => Mobi.open(bytes).meta(),
    'fb2' => Fb2.open(bytes).meta(),
    'html' => TextFormats.htmlMeta(bytes, name),
    _ => const BookMeta(),
  };
}
