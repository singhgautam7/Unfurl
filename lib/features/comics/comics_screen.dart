import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../formats/comics/comic_archive.dart';
import '../../formats/format_problem.dart';
import '../viewer/document_screen.dart';

/// CBZ, CBR, CB7 and CBT (board 6, V4).
class ComicsScreen extends StatefulWidget {
  const ComicsScreen({required this.doc, super.key});

  final OpenedDoc doc;

  @override
  State<ComicsScreen> createState() => _ComicsScreenState();
}

class _ComicsScreenState extends State<ComicsScreen> {
  ComicArchive? _comic;
  FormatProblem? _problem;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final ComicArchive c = await ComicArchive.open(widget.doc.ref.uri);
      if (!mounted) return unawaited(c.close());
      setState(() => _comic = c);
    } on FormatProblem catch (p) {
      if (mounted) setState(() => _problem = p);
    }
  }

  @override
  void dispose() {
    unawaited(_comic?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_problem != null) return problemState(context, widget.doc.ref, _problem!);
    final ComicArchive? c = _comic;
    if (c == null) return OpeningCard(ref: widget.doc.ref);
    return Scaffold(
      body: PageView.builder(
        itemCount: c.pages.length,
        itemBuilder: (BuildContext context, int i) => FutureBuilder<Uint8List?>(
          future: c.page(i),
          builder: (BuildContext context, AsyncSnapshot<Uint8List?> s) =>
              s.data == null ? const SizedBox.expand() : Image.memory(s.data!, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
