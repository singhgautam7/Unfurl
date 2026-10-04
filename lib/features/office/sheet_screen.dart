import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/app_snackbar.dart';
import '../../design_system/buttons.dart';
import '../../design_system/chips.dart';
import '../../design_system/search_field.dart';
import '../../formats/format_registry.dart';
import '../../formats/office/sheets.dart';
import '../viewer/document_screen.dart';
import 'office_screens.dart';

/// Spreadsheets (V3): XLSX, XLS, ODS and CSV, parsed off the UI isolate and
/// drawn as a virtualised grid. The column letters, row numbers and the
/// first row stay frozen (no frozen first column: the row numbers already
/// anchor each row); pinch zooms 50% to 200%; a tapped
/// cell shows its full value in a strip that can be copied. No Reader mode.
class SheetScreen extends ConsumerStatefulWidget {
  const SheetScreen({required this.doc, super.key});

  final OpenedDoc doc;

  @override
  ConsumerState<SheetScreen> createState() => _SheetScreenState();
}

class _SheetScreenState extends ConsumerState<SheetScreen> {
  List<SheetData>? _sheets;
  bool _failed = false;
  int _sheet = 0;
  (int, int)? _selected;
  bool _searching = false;
  String _query = '';
  List<(int, int)> _hits = const <(int, int)>[];
  int _hit = 0;
  final GlobalKey<_GridState> _grid = GlobalKey<_GridState>();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final Uint8List? bytes = await Files.readAll(widget.doc.ref.uri);
      if (bytes == null) throw const FormatException();
      final String ext = widget.doc.ref.extension;
      final List<SheetData> sheets = await _parse(bytes, ext);
      if (sheets.isEmpty) throw const FormatException();
      if (mounted) setState(() => _sheets = sheets);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  static Future<List<SheetData>> _parse(Uint8List bytes, String ext) => Isolate.run(() => Sheets.parse(bytes, ext));

  void _search(String q) {
    final String n = q.trim().toLowerCase();
    final SheetData s = _sheets![_sheet];
    final List<(int, int)> hits = <(int, int)>[];
    if (n.isNotEmpty) {
      for (int r = 0; r < s.rows.length && hits.length < 1000; r++) {
        for (int c = 0; c < s.rows[r].length; c++) {
          if (s.rows[r][c].toLowerCase().contains(n)) hits.add((r, c));
        }
      }
    }
    setState(() {
      _query = n;
      _hits = hits;
      _hit = 0;
    });
    if (hits.isNotEmpty) _select(hits.first);
  }

  void _select((int, int) cell) {
    setState(() => _selected = cell);
    _grid.currentState?.reveal(cell);
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return corruptState(context, widget.doc.ref);
    final UnfurlColors c = context.colors;
    final List<SheetData>? sheets = _sheets;
    if (sheets == null) return OpeningCard(ref: widget.doc.ref);
    final SheetData s = sheets[_sheet];
    final (int, int)? sel = _selected;
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Container(
              height: 64,
              padding: const EdgeInsets.fromLTRB(Space.xs, 6, Space.xs, Space.sm),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.outline)),
              ),
              child: _searching
                  ? Row(
                      children: <Widget>[
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: SearchField(
                            hint: 'Search in sheet',
                            autofocus: true,
                            height: 48,
                            onChanged: _search,
                            trailing: _query.isEmpty
                                ? null
                                : Text(
                                    _hits.isEmpty ? 'No results' : '${_hit + 1} of ${_hits.length}',
                                    style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                                  ),
                          ),
                        ),
                        AppIconButton(
                          icon: AppIcons.arrowDown,
                          filled: false,
                          semanticLabel: 'Next result',
                          onPressed: _hits.isEmpty
                              ? null
                              : () {
                                  setState(() => _hit = (_hit + 1) % _hits.length);
                                  _select(_hits[_hit]);
                                },
                        ),
                        AppIconButton(
                          icon: AppIcons.close,
                          filled: false,
                          semanticLabel: 'Close search',
                          onPressed: () => setState(() => _searching = false),
                        ),
                      ],
                    )
                  : Row(
                      spacing: 2,
                      children: <Widget>[
                        AppIconButton(
                          icon: AppIcons.back,
                          filled: false,
                          semanticLabel: 'Back',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        Expanded(
                          child: Text(
                            widget.doc.ref.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: UnfurlType.titleMedium.copyWith(color: c.onSurface),
                          ),
                        ),
                        AppIconButton(
                          icon: AppIcons.search,
                          filled: false,
                          semanticLabel: 'Search in sheet',
                          onPressed: () => setState(() => _searching = true),
                        ),
                        Builder(
                          builder: (BuildContext b) => AppIconButton(
                            icon: AppIcons.moreVert,
                            filled: false,
                            semanticLabel: 'More options',
                            onPressed: () => officeOverflow(
                              context,
                              b,
                              widget.doc,
                              text: s.rows.map((List<String> r) => r.join('\t')).join('\n'),
                              facts: <(String, String)>[
                                ('Name', widget.doc.ref.name),
                                (
                                  'Size',
                                  '${Files.size(widget.doc.ref.size)} · ${Formats.labelOf(widget.doc.ref.name)}',
                                ),
                                ('Sheets', '${sheets.length}'),
                                ('This sheet', '${s.rows.length} rows · ${s.columns} columns'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: _Grid(
                      key: _grid,
                      sheet: s,
                      selected: sel,
                      hits: _hits.toSet(),
                      onSelect: (int r, int col) => setState(() => _selected = (r, col)),
                    ),
                  ),
                  if (sel != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: _CellStrip(sheet: s, cell: sel, onClose: () => setState(() => _selected = null)),
                    ),
                ],
              ),
            ),
            if (sheets.length > 1)
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.outline)),
                ),
                padding: EdgeInsets.only(top: 10, bottom: math.max(16, MediaQuery.paddingOf(context).bottom)),
                child: ChipRow(
                  children: <Widget>[
                    for (int i = 0; i < sheets.length; i++)
                      PillChip(
                        label: sheets[i].name,
                        selected: i == _sheet,
                        onTap: () => setState(() {
                          _sheet = i;
                          _selected = null;
                          _hits = const <(int, int)>[];
                        }),
                      ),
                  ],
                ),
              )
            else
              SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }
}

/// The selected cell's full value: "D7 · Utilities", the value, any comment,
/// and copy.
class _CellStrip extends StatelessWidget {
  const _CellStrip({required this.sheet, required this.cell, required this.onClose});

  final SheetData sheet;
  final (int, int) cell;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final (int r, int col) = cell;
    final String value = sheet.cell(r, col);
    final String header = r > 0 ? sheet.cell(0, col) : '';
    final String? comment = sheet.comments[cell];
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, 6, Space.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.cardR,
        border: Border.all(color: c.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${Sheets.column(col)}${r + 1}${header.isEmpty ? '' : ' · $header'}',
                  style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: Space.xs),
                SelectableText(
                  value.isEmpty ? 'Empty' : value,
                  style: UnfurlType.body
                      .copyWith(
                        height: 1.4,
                        color: value.isEmpty ? c.onSurfaceVariant : c.onSurface,
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      )
                      .weight(600),
                ),
                if (comment != null)
                  Text('Comment: $comment', style: UnfurlType.note.copyWith(height: 1.5, color: c.onSurfaceVariant)),
              ],
            ),
          ),
          AppIconButton(
            icon: AppIcons.copy,
            filled: false,
            semanticLabel: 'Copy value',
            onPressed: () {
              unawaited(Clipboard.setData(ClipboardData(text: value)));
              AppSnackbar.info(context, 'Copied');
            },
          ),
        ],
      ),
    );
  }
}

/// A grid that only ever lays out the cells on screen: column letters and
/// row numbers frozen, the first row frozen with them, pan with
/// momentum, pinch to zoom.
class _Grid extends StatefulWidget {
  const _Grid({required this.sheet, required this.selected, required this.hits, required this.onSelect, super.key});

  final SheetData sheet;
  final (int, int)? selected;
  final Set<(int, int)> hits;
  final void Function(int r, int c) onSelect;

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> with SingleTickerProviderStateMixin {
  Offset _offset = Offset.zero;
  double _zoom = 1;
  double _zoomStart = 1;
  Offset _focalStart = Offset.zero;
  Offset _offsetStart = Offset.zero;
  late final AnimationController _fling = AnimationController.unbounded(vsync: this)..addListener(_onFling);
  FrictionSimulation? _fx, _fy;
  Size _view = Size.zero;
  late List<double> _widths = _measureColumns();
  final LinkedHashMap<String, TextPainter> _cache = LinkedHashMap<String, TextPainter>();

  static const double _rowH = 36, _headH = 30, _numW = 36;

  @override
  void didUpdateWidget(_Grid old) {
    super.didUpdateWidget(old);
    if (old.sheet != widget.sheet) {
      _widths = _measureColumns();
      _offset = Offset.zero;
      _clearCache();
    }
  }

  @override
  void dispose() {
    _fling.dispose();
    _clearCache();
    super.dispose();
  }

  void _clearCache() {
    for (final TextPainter t in _cache.values) {
      t.dispose();
    }
    _cache.clear();
  }

  List<double> _measureColumns() {
    final SheetData s = widget.sheet;
    return <double>[
      for (int c = 0; c < s.columns; c++)
        (s.rows.take(200).fold<int>(3, (int m, List<String> r) => math.max(m, c < r.length ? r[c].length : 0)) * 7.2 +
                18)
            .clamp(64, 260)
            .toDouble(),
    ];
  }

  double get _contentW => _widths.fold<double>(0, (double a, double b) => a + b) * _zoom;
  double get _contentH => widget.sheet.rows.length * _rowH * _zoom;

  Offset _clamp(Offset o) => Offset(
    o.dx.clamp(0, math.max(0, _contentW - (_view.width - _numW) + 24)).toDouble(),
    o.dy.clamp(0, math.max(0, _contentH - (_view.height - _headH - _rowH * _zoom) + 160)).toDouble(),
  );

  void _onFling() {
    final double t = _fling.value;
    setState(() => _offset = _clamp(Offset(_fx?.x(t) ?? _offset.dx, _fy?.x(t) ?? _offset.dy)));
    if ((_fx?.isDone(t) ?? true) && (_fy?.isDone(t) ?? true)) _fling.stop();
  }

  /// Scrolls a cell into view.
  void reveal((int, int) cell) {
    final double x = _widths.take(cell.$2).fold<double>(0, (double a, double b) => a + b) * _zoom;
    final double y = cell.$1 * _rowH * _zoom;
    setState(() => _offset = _clamp(Offset(math.max(0, x - 80), math.max(0, y - 120))));
  }

  (int, int)? _cellAt(Offset p) {
    const double frozenW = _numW;
    final double frozenH = _headH + _rowH * _zoom;
    if (p.dx < _numW || p.dy < _headH) return null;
    final int r = p.dy < frozenH ? 0 : ((p.dy - _headH + _offset.dy) / (_rowH * _zoom)).floor();
    int c = 0;
    if (p.dx >= frozenW) {
      double x = _numW - _offset.dx;
      for (c = 0; c < _widths.length; c++) {
        if (x + _widths[c] * _zoom > p.dx) break;
        x += _widths[c] * _zoom;
      }
    }
    if (r >= widget.sheet.rows.length || c >= widget.sheet.columns) return null;
    return (r, c);
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        _view = box.biggest;
        return GestureDetector(
          onScaleStart: (ScaleStartDetails d) {
            _fling.stop();
            _zoomStart = _zoom;
            _focalStart = d.localFocalPoint;
            _offsetStart = _offset;
          },
          onScaleUpdate: (ScaleUpdateDetails d) {
            setState(() {
              final double z = (_zoomStart * d.scale).clamp(0.5, 2.0);
              if (z != _zoom) {
                _zoom = z;
                _clearCache();
              }
              _offset = _clamp(_offsetStart * (_zoom / _zoomStart) - (d.localFocalPoint - _focalStart));
            });
          },
          onScaleEnd: (ScaleEndDetails d) {
            final Offset v = d.velocity.pixelsPerSecond;
            if (v.distance < 50) return;
            _fx = FrictionSimulation(0.015, _offset.dx, -v.dx);
            _fy = FrictionSimulation(0.015, _offset.dy, -v.dy);
            unawaited(_fling.animateWith(_Idle()));
          },
          onTapUp: (TapUpDetails d) {
            final (int, int)? cell = _cellAt(d.localPosition);
            if (cell != null) widget.onSelect(cell.$1, cell.$2);
          },
          child: Semantics(
            label: 'Sheet ${widget.sheet.name}, ${widget.sheet.rows.length} rows',
            child: ClipRect(
              child: CustomPaint(
                size: Size.infinite,
                painter: _GridPainter(
                  sheet: widget.sheet,
                  widths: _widths,
                  offset: _offset,
                  zoom: _zoom,
                  colors: c,
                  selected: widget.selected,
                  hits: widget.hits,
                  cache: _cache,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Drives the fling's clock; the frictions decide where it lands.
class _Idle extends Simulation {
  @override
  double x(double time) => time;

  @override
  double dx(double time) => 1;

  @override
  bool isDone(double time) => time > 4;
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.sheet,
    required this.widths,
    required this.offset,
    required this.zoom,
    required this.colors,
    required this.selected,
    required this.hits,
    required this.cache,
  });

  final SheetData sheet;
  final List<double> widths;
  final Offset offset;
  final double zoom;
  final UnfurlColors colors;
  final (int, int)? selected;
  final Set<(int, int)> hits;
  final LinkedHashMap<String, TextPainter> cache;

  static const double _rowH = 36, _headH = 30, _numW = 36;

  TextPainter _text(String key, String text, TextStyle style, double maxW) {
    final TextPainter? hit = cache.remove(key);
    if (hit != null) {
      cache[key] = hit;
      return hit;
    }
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(1, maxW));
    cache[key] = tp;
    if (cache.length > 1500) cache.remove(cache.keys.first)!.dispose();
    return tp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final UnfurlColors c = colors;
    final Paint divider = Paint()..color = c.divider;
    final Paint outline = Paint()..color = c.outline;
    final double rowH = _rowH * zoom;
    final TextStyle cell = TextStyle(
      fontFamily: UnfurlType.sans,
      fontSize: 12.5 * zoom,
      color: c.onSurface,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    final TextStyle bold = cell.copyWith(
      fontWeight: FontWeight.w600,
      fontVariations: const <FontVariation>[FontVariation('wght', 600)],
    );
    final TextStyle head = TextStyle(
      fontFamily: UnfurlType.mono,
      fontSize: 11,
      color: c.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    canvas.drawRect(Offset.zero & size, Paint()..color = c.surface);

    // Visible columns and rows (after the frozen row 1).
    final List<(int, double)> cols = <(int, double)>[];
    double x = _numW - offset.dx;
    for (int col = 0; col < widths.length; col++) {
      final double w = widths[col] * zoom;
      if (x + w > _numW && x < size.width) cols.add((col, x));
      x += w;
      if (x > size.width) break;
    }
    final int firstRow = math.max(1, (offset.dy / rowH).floor() + 1);
    final int lastRow = math.min(sheet.rows.length - 1, firstRow + (size.height / rowH).ceil() + 1);

    // A last row reads as totals (bold figures) only when it says so.
    final bool totals =
        sheet.rows.isNotEmpty &&
        sheet.rows.last.any((String v) => RegExp(r'\b(total|sum)\b', caseSensitive: false).hasMatch(v));
    void drawCell(int r, int col, double cx, double cy, double w, {bool frozenRow = false}) {
      final bool sel = selected == (r, col);
      final bool hit = hits.contains((r, col));
      Color? bg;
      if (sel) {
        bg = c.primaryContainer;
      } else if (hit) {
        bg = c.primary.withValues(alpha: 0.18);
      } else if (frozenRow) {
        bg = c.surfaceContainer;
      }
      final Rect rect = Rect.fromLTWH(cx, cy, w, rowH);
      if (bg != null) canvas.drawRect(rect, Paint()..color = bg);
      final String v = sheet.cell(r, col);
      if (v.isNotEmpty) {
        final bool numeric = sheet.numeric.contains((r, col));
        final TextPainter tp = _text(
          '$r:$col:$zoom:${sel ? 1 : 0}',
          v,
          (frozenRow || r == sheet.rows.length - 1 && numeric && totals ? bold : cell).copyWith(
            color: sel ? c.onPrimaryContainer : null,
          ),
          w - 16,
        );
        tp.paint(canvas, Offset(numeric ? cx + w - 8 - tp.width : cx + 8, cy + (rowH - tp.height) / 2));
      }
      canvas.drawLine(Offset(cx + w, cy), Offset(cx + w, cy + rowH), divider);
      canvas.drawLine(
        Offset(cx, cy + rowH),
        Offset(cx + w, cy + rowH),
        frozenRow
            ? (Paint()
                ..color = c.outline
                ..strokeWidth = 2)
            : divider,
      );
      if (sel) {
        canvas.drawRect(
          rect.deflate(1),
          Paint()
            ..color = c.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    // Body.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(_numW, _headH + rowH, size.width, size.height));
    for (int r = firstRow; r <= lastRow; r++) {
      final double y = _headH + rowH + (r - 1) * rowH - offset.dy;
      for (final (int col, double cx) in cols) {
        drawCell(r, col, cx, y, widths[col] * zoom);
      }
    }
    canvas.restore();
    // Frozen first row.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(_numW, _headH, size.width, _headH + rowH));
    for (final (int col, double cx) in cols) {
      drawCell(0, col, cx, _headH, widths[col] * zoom, frozenRow: true);
    }
    canvas.restore();

    // Column letters.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, _headH), Paint()..color = c.surfaceContainerHigh);
    void letter(int col, double cx, double w) {
      final TextPainter tp = _text('h:$col', Sheets.column(col), head, w);
      tp.paint(canvas, Offset(cx + (w - tp.width) / 2, (_headH - tp.height) / 2));
      canvas.drawLine(Offset(cx + w, 0), Offset(cx + w, _headH), divider);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(_numW, 0, size.width, _headH));
    for (final (int col, double cx) in cols) {
      letter(col, cx, widths[col] * zoom);
    }
    canvas.restore();
    canvas.drawLine(const Offset(0, _headH), Offset(size.width, _headH), outline);
    // Row numbers.
    canvas.drawRect(Rect.fromLTWH(0, _headH, _numW, size.height), Paint()..color = c.surfaceContainerHigh);
    void number(int r, double y) {
      final TextPainter tp = _text('n:$r:$zoom', '${r + 1}', head, _numW);
      tp.paint(canvas, Offset((_numW - tp.width) / 2, y + (rowH - tp.height) / 2));
      canvas.drawLine(Offset(0, y + rowH), Offset(_numW, y + rowH), divider);
    }

    if (sheet.rows.isNotEmpty) number(0, _headH);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, _headH + rowH, _numW, size.height));
    for (int r = firstRow; r <= lastRow; r++) {
      number(r, _headH + rowH + (r - 1) * rowH - offset.dy);
    }
    canvas.restore();
    canvas.drawLine(const Offset(_numW, 0), Offset(_numW, size.height), outline);
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.offset != offset ||
      old.zoom != zoom ||
      old.selected != selected ||
      old.sheet != sheet ||
      old.colors != colors ||
      old.hits != hits;
}
