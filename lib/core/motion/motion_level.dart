import 'package:flutter/widgets.dart';

/// How much Unfurl moves.
enum MotionLevel { expressive, subtle, off }

/// What the user picked. Auto resolves from the phone (see [resolveMotionLevel]).
enum MotionPreference { auto, expressive, subtle, off }

/// Result of the one-off device check, cached in prefs. [unknown] until the
/// check has run (Auto then behaves as Expressive).
enum DeviceClass { unknown, normal, low }

/// Total RAM under this (MB, as Android reports it) is a low-end phone
/// ("under 4 GB"). Android reports less than the nominal size (a 4 GB phone
/// shows about 3.6 to 3.8 GB), so the cut is 3.5 GB.
const int kLowRamMb = 3584;

DeviceClass classifyDevice({required int? ramMb, bool lowRamFlag = false}) =>
    lowRamFlag || (ramMb != null && ramMb < kLowRamMb) ? DeviceClass.low : DeviceClass.normal;

/// Level for [pref] on a phone of class [device]. The phone wins: with
/// [systemOff] (Remove animations, or accessible navigation) the answer is
/// always Off, even over an explicit preference.
MotionLevel resolveMotionLevel(MotionPreference pref, DeviceClass device, {required bool systemOff}) {
  if (systemOff) return MotionLevel.off;
  return switch (pref) {
    MotionPreference.expressive => MotionLevel.expressive,
    MotionPreference.subtle => MotionLevel.subtle,
    MotionPreference.off => MotionLevel.off,
    MotionPreference.auto => device == DeviceClass.low ? MotionLevel.subtle : MotionLevel.expressive,
  };
}

/// The level for everything below it. One instance sits above the routes (see
/// `MotionScopeHost` in app.dart); `Motion.levelOf` reads it.
class MotionScope extends InheritedWidget {
  const MotionScope({super.key, required this.level, this.systemOff = false, required super.child});

  /// Effective level (already Off when [systemOff]).
  final MotionLevel level;

  /// The phone's Remove animations is on.
  final bool systemOff;

  static MotionScope? maybeOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<MotionScope>();

  @override
  bool updateShouldNotify(MotionScope old) => old.level != level || old.systemOff != systemOff;
}
