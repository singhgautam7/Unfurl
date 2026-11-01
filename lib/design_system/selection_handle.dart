import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

/// A text selection handle, as Android draws them: an 18dp teardrop in the
/// reading theme's handle colour whose square corner sits on the selection's
/// edge (the foot of its first line for the start, the foot of its last line
/// for the end), inside a 48dp touch target. Reader mode and the PDF page view
/// share it.
///
/// Place it with [SelectionHandle.topLeft]. While it is dragged it reports the
/// point the edge has been dragged to, in global coordinates: the finger's
/// position less where on the handle it took hold, so the selection never
/// jumps to the finger when the drag starts.
class SelectionHandle extends StatefulWidget {
  const SelectionHandle({
    required this.start,
    required this.colour,
    required this.onDrag,
    this.onDragStart,
    this.onDragEnd,
    super.key,
  });

  /// The start handle (left of the first character) or the end handle.
  final bool start;
  final Color colour;
  final ValueChanged<Offset> onDrag;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  /// The visible drop.
  static const double size = 18;

  /// The touch target around it (the 48dp minimum).
  static const double target = 48;
  static const double _pad = (target - size) / 2;

  /// The handle's top-left for a selection edge at [edge] (the bottom-left of
  /// the first line for the start handle, the bottom-right of the last line
  /// for the end handle), in the coordinates the handle is positioned in.
  static Offset topLeft(Offset edge, {required bool start}) =>
      edge - (start ? const Offset(_pad + size, _pad) : const Offset(_pad, _pad));

  @override
  State<SelectionHandle> createState() => _SelectionHandleState();
}

class _SelectionHandleState extends State<SelectionHandle> {
  /// From the finger to the edge point, fixed when the drag starts.
  Offset _grip = Offset.zero;

  Offset get _edge => widget.start
      ? const Offset(SelectionHandle._pad + SelectionHandle.size, SelectionHandle._pad)
      : const Offset(SelectionHandle._pad, SelectionHandle._pad);

  @override
  Widget build(BuildContext context) => Semantics(
    // The toolbar carries the selection's actions; the handles are a
    // pointer affordance only.
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onPanStart: (DragStartDetails d) {
        _grip = _edge - d.localPosition;
        widget.onDragStart?.call();
      },
      onPanUpdate: (DragUpdateDetails d) => widget.onDrag(d.globalPosition + _grip),
      onPanEnd: (_) => widget.onDragEnd?.call(),
      onPanCancel: () => widget.onDragEnd?.call(),
      child: SizedBox.square(
        dimension: SelectionHandle.target,
        child: Padding(
          padding: const EdgeInsets.all(SelectionHandle._pad),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.colour,
              borderRadius: widget.start
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(SelectionHandle.size / 2),
                      bottomLeft: Radius.circular(SelectionHandle.size / 2),
                      bottomRight: Radius.circular(SelectionHandle.size / 2),
                    )
                  : const BorderRadius.only(
                      topRight: Radius.circular(SelectionHandle.size / 2),
                      bottomLeft: Radius.circular(SelectionHandle.size / 2),
                      bottomRight: Radius.circular(SelectionHandle.size / 2),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
