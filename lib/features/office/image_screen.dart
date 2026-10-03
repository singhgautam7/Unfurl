import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/files.dart';
import '../../core/motion/motion.dart';
import '../../core/platform/platform.dart';
import '../../core/providers.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/app_menu.dart';
import '../../design_system/buttons.dart';
import '../../formats/format_registry.dart';
import '../reader/chrome.dart';
import '../reader/sheets.dart';
import '../viewer/document_screen.dart';

/// Images (V4): on true black, pinch and pan, rotate, and swipe through the
/// other images in the same folder. No Reader mode.
class ImageScreen extends ConsumerStatefulWidget {
  const ImageScreen({required this.doc, super.key});

  final OpenedDoc doc;

  @override
  ConsumerState<ImageScreen> createState() => _ImageScreenState();
}

class _ImageScreenState extends ConsumerState<ImageScreen> {
  List<DocRef> _images = const <DocRef>[];
  late final PageController _pages = PageController();
  int _index = 0;
  bool _chrome = true;
  int _quarterTurns = 0;
  double _zoom = 1;

  @override
  void initState() {
    super.initState();
    _images = <DocRef>[widget.doc.ref];
    unawaited(_siblings());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// The other images in this file's folder, by name, when it came from one.
  Future<void> _siblings() async {
    final AppDatabase db = ref.read(databaseProvider);
    final Entry? me =
        await (db.select(db.entries)
              ..where((e) => e.uri.equals(widget.doc.ref.uri))
              ..limit(1))
            .getSingleOrNull();
    if (me == null) return;
    final List<Entry> all =
        await (db.select(db.entries)
              ..where(
                (e) =>
                    e.folderId.equals(me.folderId) & e.parent.equals(me.parent) & e.ext.isIn(Formats.image.extensions),
              )
              ..orderBy(<OrderClauseGenerator<$EntriesTable>>[(e) => OrderingTerm.asc(e.name)]))
            .get();
    if (!mounted || all.length < 2) return;
    final int at = all.indexWhere((Entry e) => e.uri == widget.doc.ref.uri);
    setState(() {
      _images = <DocRef>[
        for (final Entry e in all) DocRef(uri: e.uri, name: e.name, size: e.size, modified: e.modified, mime: e.mime),
      ];
      _index = math.max(0, at);
    });
    _pages.jumpToPage(_index);
  }

  @override
  Widget build(BuildContext context) {
    final DocRef current = _images[_index];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _chrome = !_chrome),
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _images.length,
                  physics: _zoom > 1.01 ? const NeverScrollableScrollPhysics() : null,
                  onPageChanged: (int i) => setState(() {
                    _index = i;
                    _quarterTurns = 0;
                    _zoom = 1;
                  }),
                  itemBuilder: (BuildContext context, int i) => _ZoomImage(
                    key: ValueKey<String>(_images[i].uri),
                    ref: _images[i],
                    quarterTurns: i == _index ? _quarterTurns : 0,
                    onZoom: (double z) {
                      if ((z - _zoom).abs() > 0.01) setState(() => _zoom = z);
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ChromeSlide(
                visible: _chrome,
                child: ReaderTopBar(
                  title: current.name,
                  onBack: () => Navigator.of(context).maybePop(),
                  actions: <Widget>[
                    AppIconButton(
                      icon: AppIcons.rotateRight,
                      filled: false,
                      semanticLabel: 'Rotate',
                      onPressed: () => setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
                    ),
                    Builder(
                      builder: (BuildContext b) => AppIconButton(
                        icon: AppIcons.moreVert,
                        filled: false,
                        semanticLabel: 'More options',
                        onPressed: () async {
                          final String? choice = await showAppMenu<String>(
                            context: context,
                            anchorContext: b,
                            entries: const <AppMenuEntry<String>>[
                              AppMenuEntry<String>(value: 'share', label: 'Share file', icon: AppIcons.share),
                              AppMenuEntry<String>(value: 'info', label: 'File info', icon: AppIcons.info),
                              AppMenuEntry<String>.divider(),
                              AppMenuEntry<String>(
                                value: 'other',
                                label: 'Open in another app',
                                icon: AppIcons.openInNew,
                              ),
                            ],
                          );
                          if (!context.mounted) return;
                          switch (choice) {
                            case 'share':
                              await Platform.shareFile(current.uri, current.mime);
                            case 'info':
                              await showBookInfo(
                                context,
                                cover: const SizedBox.shrink(),
                                title: current.name,
                                author: null,
                                facts: <(String, String)>[
                                  ('Name', current.name),
                                  ('Size', Files.size(current.size)),
                                  ('Modified', Files.when(current.modified)),
                                ],
                                highlights: 0,
                                onExport: null,
                              );
                            case 'other':
                              await Platform.openWith(current.uri, current.mime);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 28,
              left: 0,
              right: 0,
              child: Center(
                child: TimedChip(
                  key: ValueKey<int>((_zoom * 100).round()),
                  text: '${(_zoom * 100).round()}%',
                  duration: const Duration(milliseconds: 1500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomImage extends StatefulWidget {
  const _ZoomImage({required this.ref, required this.quarterTurns, required this.onZoom, super.key});

  final DocRef ref;
  final int quarterTurns;
  final ValueChanged<double> onZoom;

  @override
  State<_ZoomImage> createState() => _ZoomImageState();
}

class _ZoomImageState extends State<_ZoomImage> {
  Uint8List? _bytes;
  bool _failed = false;
  final TransformationController _tx = TransformationController();

  @override
  void initState() {
    super.initState();
    _tx.addListener(() => widget.onZoom(_tx.value.getMaxScaleOnAxis()));
    unawaited(
      Files.readAll(widget.ref.uri).then((Uint8List? b) {
        if (mounted) setState(() => b == null ? _failed = true : _bytes = b);
      }),
    );
  }

  @override
  void dispose() {
    _tx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return corruptState(context, widget.ref);
    final Uint8List? b = _bytes;
    if (b == null) return const SizedBox.expand();
    final Size s = MediaQuery.sizeOf(context);
    final int px = (math.max(s.width, s.height) * MediaQuery.devicePixelRatioOf(context) * 1.5).round();
    return GestureDetector(
      onDoubleTapDown: (TapDownDetails d) {
        if (_tx.value.getMaxScaleOnAxis() > 1.01) {
          _tx.value = Matrix4.identity();
        } else {
          final Offset p = d.localPosition;
          _tx.value = Matrix4.identity()
            ..translateByDouble(-p.dx, -p.dy, 0, 1)
            ..scaleByDouble(2.5, 2.5, 1, 1);
        }
      },
      child: InteractiveViewer(
        transformationController: _tx,
        maxScale: 8,
        child: Center(
          child: AnimatedRotation(
            turns: widget.quarterTurns / 4,
            duration: Motion.of(context, Motion.containerTransform),
            curve: Motion.spring,
            child: Image.memory(
              b,
              cacheWidth: px,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              semanticLabel: widget.ref.name,
              errorBuilder: (BuildContext c, Object e, StackTrace? t) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
