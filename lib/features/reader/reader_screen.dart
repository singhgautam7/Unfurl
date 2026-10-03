import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files.dart';
import '../../core/providers.dart';
import '../../core/library/library.dart';
import '../../core/motion/motion.dart';
import '../../core/library/enrich.dart';
import '../../formats/epub/epub.dart';
import '../../formats/format_registry.dart';
import '../../formats/reading_document.dart';
import '../../formats/text/text_formats.dart';
import '../viewer/document_screen.dart';
import 'reader_scaffold.dart';

/// EPUB, Markdown and plain text: straight into Reader mode, their only
/// view. The file is converted off the UI isolate.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.doc, super.key});

  final OpenedDoc doc;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  ReadingDocument? _reading;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  late final Library _library = ref.read(libraryProvider);

  Future<void> _load() async {
    try {
      final Uint8List? bytes = await Files.readAll(widget.doc.ref.uri);
      if (bytes == null) throw const FormatException('unreadable');
      final String name = widget.doc.ref.name;
      final FormatModule f = widget.doc.format;
      final ReadingDocument doc = await _parse(f.id, bytes, name);
      // A book opened from outside the library still shows its own title.
      if (f.id == 'epub' && widget.doc.record.title == null && doc.title.isNotEmpty) {
        unawaited(_library.touch(widget.doc.fingerprint, widget.doc.ref, title: doc.title, author: doc.author));
      }
      if (f.id == 'epub' && !Covers.tried(widget.doc.fingerprint)) {
        unawaited(_cover(bytes).then((Uint8List? c) => Covers.write(widget.doc.fingerprint, c ?? Uint8List(0))));
      }
      if (mounted) setState(() => _reading = doc);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  static Future<Uint8List?> _cover(Uint8List bytes) => Isolate.run(() => Epub.open(bytes).meta().cover);

  /// Static, so the isolate's closure carries only the bytes.
  static Future<ReadingDocument> _parse(String format, Uint8List bytes, String name) => Isolate.run(
    () => switch (format) {
      'epub' => Epub.open(bytes).document(),
      'md' => TextFormats.markdown(bytes, name),
      _ => TextFormats.plain(bytes, name),
    },
  );

  @override
  Widget build(BuildContext context) {
    if (_failed) return corruptState(context, widget.doc.ref);
    final ReadingDocument? r = _reading;
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.fast),
      switchInCurve: Motion.decelerate,
      child: r == null
          ? OpeningCard(key: const ValueKey<String>('opening'), ref: widget.doc.ref)
          : ReaderScaffold(doc: widget.doc, reading: r),
    );
  }
}
