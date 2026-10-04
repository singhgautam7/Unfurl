import 'package:flutter/painting.dart';

import 'oklch.dart';
import 'palette.dart';

/// V3-INSIGHTS colours, from `specs/design/unfurl-v3-tokens.js`: the
/// heatmap's five levels (neutral at 0, the seed's primary hue above) and the
/// formats bar's tones. Derived per family and tone, like every chrome role.
abstract final class InsightsColors {
  static const Map<Tone, List<(double, double)>> _heat = <Tone, List<(double, double)>>{
    Tone.light: <(double, double)>[(0.935, 0.011), (0.88, 0.045), (0.78, 0.085), (0.655, 0.115), (0.535, 0.130)],
    Tone.dark: <(double, double)>[(0.30, 0.016), (0.37, 0.040), (0.47, 0.070), (0.60, 0.090), (0.74, 0.105)],
    Tone.amoled: <(double, double)>[(0.15, 0.012), (0.27, 0.040), (0.40, 0.065), (0.56, 0.090), (0.74, 0.105)],
  };

  /// `heat(f, tone, lvl)`.
  static Color heat(ThemeFamily f, Tone tone, int level) {
    final (double l, double c) = _heat[tone]![level];
    return level == 0 ? Oklch(l, c * f.neutralChroma, f.neutralHue).toColor() : Oklch(l, c, f.primaryHue).toColor();
  }

  static List<Color> heatLevels(ThemeFamily f, Tone tone) => <Color>[for (int k = 0; k < 5; k++) heat(f, tone, k)];

  static const List<double> _stackL = <double>[0.535, 0.66, 0.42, 0.78, 0.33, 0.88];

  /// The formats bar's i-th segment (the last, "Other", nearly neutral).
  static Color stack(ThemeFamily f, int i) =>
      Oklch(_stackL[i % _stackL.length], i == 5 ? 0.04 : 0.11, f.primaryHue).toColor();
}

/// `heatBuckets` and `insights.*`.
abstract final class InsightsSpec {
  /// Minutes a day at or above which each level starts.
  static const List<int> heatBuckets = <int>[0, 1, 15, 30, 60];

  static int heatLevel(int minutes) {
    int level = 0;
    for (int k = 1; k < heatBuckets.length; k++) {
      if (minutes >= heatBuckets[k]) level = k;
    }
    return level;
  }

  static const int heatmapDays = 371;
  static const int speedWindowDays = 30;
  static const int speedMinMinutes = 30;
  static const int patternsMinDays = 7;
  static const int patternWindowDays = 90;
  static const int topBooks = 5;
}
