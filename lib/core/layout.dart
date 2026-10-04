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
}
