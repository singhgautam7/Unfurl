import 'package:flutter/widgets.dart';

/// Window size classes (board 6, V7 `breakpoints`): compact under 600dp,
/// medium 600–839, expanded from 840. The one breakpoint utility; every
/// adaptive layout asks here.
enum SizeClass {
  compact,
  medium,
  expanded;

  static SizeClass ofWidth(double width) => width >= 840
      ? SizeClass.expanded
      : width >= 600
      ? SizeClass.medium
      : SizeClass.compact;

  static SizeClass of(BuildContext context) => ofWidth(MediaQuery.sizeOf(context).width);

  /// Library and Files grids: 3 / 5 / 7 columns (`gridColumns`).
  int get gridColumns => switch (this) {
    SizeClass.compact => 3,
    SizeClass.medium => 5,
    SizeClass.expanded => 7,
  };

  /// Pill on compact and medium, a rail on expanded (`nav`).
  bool get rail => this == SizeClass.expanded;
}

/// V7 side panels and centred pages.
abstract final class AdaptiveSpec {
  static const double railWidth = 80;
  static const double sidePanel = 400;
  static const double minMain = 560;

  /// More and Settings centre at 720dp on expanded widths.
  static const double centred = 720;

  /// The selection toolbar keeps a phone's width on wide windows.
  static const double selectionToolbar = 440;
}

/// A cover grid for the window: 3 / 5 / 7 columns, tiles 96dp on phones (as
/// v2) and filling their column on tablets, covers at the boards' 96:136.
@immutable
class CoverGrid {
  const CoverGrid({required this.columns, required this.tile});

  factory CoverGrid.of(BuildContext context) {
    final SizeClass size = SizeClass.of(context);
    final double width = MediaQuery.sizeOf(context).width - (size.rail ? AdaptiveSpec.railWidth : 0) - 2 * _screen;
    final int columns = size.gridColumns;
    final double tile = size == SizeClass.compact ? 96 : (width - gap * (columns - 1)) / columns;
    return CoverGrid(columns: columns, tile: tile.floorToDouble());
  }

  static const double _screen = 20, gap = 12;

  final int columns;
  final double tile;

  double get cover => (tile * 136 / 96).roundToDouble();

  /// A row's height: the cover plus [text] under it.
  double extent(double text) => cover + text;

  /// Phones spread three tiles edge, centre, edge; tablets fill the column.
  Alignment alignment(int i) =>
      columns == 3 ? <Alignment>[Alignment.topLeft, Alignment.topCenter, Alignment.topRight][i % 3] : Alignment.topLeft;
}
