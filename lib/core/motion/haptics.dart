import 'dart:async';

import 'package:flutter/services.dart';

import 'motion.dart';

/// The five haptics. The Haptics switch must be on ([enabled], default off),
/// at most one per 50 ms, none while a scroll is active ([scrolling]). They
/// do not depend on the Motion level. Never call `HapticFeedback` directly.
///
/// Flutter has no CONFIRM / REJECT / GESTURE_THRESHOLD constants, so those use
/// the closest call (confirm = light, reject = heavy, threshold = medium).
abstract final class Haptics {
  /// The Haptics switch. Mirrors `AppSettings.haptics`.
  static bool enabled = false;

  /// True between a scroll start and its end (fling included).
  static bool scrolling = false;

  static const Duration minGap = Motion.hapticGap;

  /// Clock, replaceable in tests.
  static DateTime Function() now = DateTime.now;
  static DateTime? _last;

  /// Clears the throttle (tests).
  static void reset() => _last = null;

  static bool _allow() {
    if (!enabled || scrolling) return false;
    final DateTime t = now();
    final DateTime? l = _last;
    if (l != null && t.difference(l) < minGap) return false;
    _last = t;
    return true;
  }

  /// A selection changed: switch, checkbox, radio, chip, segmented, tab, nav.
  static void tick() {
    if (_allow()) unawaited(HapticFeedback.selectionClick());
  }

  /// A long press triggered (only at the trigger, not the hold).
  static void longPress() {
    if (_allow()) unawaited(HapticFeedback.mediumImpact());
  }

  /// A drag crossed its commit point.
  static void threshold() {
    if (_allow()) unawaited(HapticFeedback.mediumImpact());
  }

  /// Save or success.
  static void confirm() {
    if (_allow()) unawaited(HapticFeedback.lightImpact());
  }

  /// An action failed.
  static void reject() {
    if (_allow()) unawaited(HapticFeedback.heavyImpact());
  }
}
