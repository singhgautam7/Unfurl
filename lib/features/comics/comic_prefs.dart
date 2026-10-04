import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/reading_theme.dart';
import '../settings/settings_controller.dart';

/// Board 6, V4: Single, Two-page, Webtoon.
enum ComicMode { single, spread, webtoon }

/// Fit width, height or screen (default screen).
enum ComicFit { width, height, screen }

/// The Comic settings sheet's choices. Right to left is per book (its
/// ComicInfo decides first), stored by fingerprint.
@immutable
class ComicPrefs {
  const ComicPrefs({
    this.mode = ComicMode.single,
    this.fit = ComicFit.screen,
    this.spreadInLandscape = true,
    this.coverAlone = true,
    this.surround,
  });

  final ComicMode mode;
  final ComicFit fit;

  /// "Two pages in landscape": a spread whenever the window is wider than tall.
  final bool spreadInLandscape;

  /// "Show the cover on its own", so pages pair as printed.
  final bool coverAlone;

  /// The reading theme behind the pages (only Light, Sepia, Dark, AMOLED are
  /// offered); null follows the reading theme.
  final ReadingThemeId? surround;

  static const List<ReadingThemeId> surrounds = <ReadingThemeId>[
    ReadingThemeId.light,
    ReadingThemeId.sepia,
    ReadingThemeId.dark,
    ReadingThemeId.amoled,
  ];

  ComicPrefs copyWith({
    ComicMode? mode,
    ComicFit? fit,
    bool? spreadInLandscape,
    bool? coverAlone,
    ReadingThemeId? surround,
  }) => ComicPrefs(
    mode: mode ?? this.mode,
    fit: fit ?? this.fit,
    spreadInLandscape: spreadInLandscape ?? this.spreadInLandscape,
    coverAlone: coverAlone ?? this.coverAlone,
    surround: surround ?? this.surround,
  );

  static T _enum<T extends Enum>(List<T> values, String? name, T fallback) =>
      values.where((T v) => v.name == name).firstOrNull ?? fallback;

  static ComicPrefs read(SharedPreferences p) => ComicPrefs(
    mode: _enum(ComicMode.values, p.getString('comic.mode'), ComicMode.single),
    fit: _enum(ComicFit.values, p.getString('comic.fit'), ComicFit.screen),
    spreadInLandscape: p.getBool('comic.spreadInLandscape') ?? true,
    coverAlone: p.getBool('comic.coverAlone') ?? true,
    surround: ReadingThemeId.values.where((ReadingThemeId r) => r.name == p.getString('comic.surround')).firstOrNull,
  );

  Future<void> write(SharedPreferences p) async {
    await p.setString('comic.mode', mode.name);
    await p.setString('comic.fit', fit.name);
    await p.setBool('comic.spreadInLandscape', spreadInLandscape);
    await p.setBool('comic.coverAlone', coverAlone);
    if (surround != null) await p.setString('comic.surround', surround!.name);
  }
}

class ComicPrefsController extends Notifier<ComicPrefs> {
  @override
  ComicPrefs build() => ComicPrefs.read(ref.watch(prefsProvider));

  void update(ComicPrefs Function(ComicPrefs p) change) {
    state = change(state);
    state.write(ref.read(prefsProvider));
  }

  /// A book's own direction: the reader's choice, else its ComicInfo.
  bool rtlFor(String fingerprint, {required bool fallback}) =>
      ref.read(prefsProvider).getBool('comic.rtl.$fingerprint') ?? fallback;

  Future<void> setRtl(String fingerprint, {required bool rtl}) =>
      ref.read(prefsProvider).setBool('comic.rtl.$fingerprint', rtl);
}

final NotifierProvider<ComicPrefsController, ComicPrefs> comicPrefsProvider =
    NotifierProvider<ComicPrefsController, ComicPrefs>(ComicPrefsController.new);

/// Pages grouped for a spread: the cover alone (if asked), wide pages alone
/// (a double-page scan), the rest in pairs. Indexes are reading order.
List<List<int>> comicSpreads(int count, {required bool coverAlone, required bool Function(int page) wide}) {
  final List<List<int>> out = <List<int>>[];
  int i = 0;
  if (coverAlone && count > 0) {
    out.add(<int>[0]);
    i = 1;
  }
  while (i < count) {
    if (wide(i) || i + 1 >= count || wide(i + 1)) {
      out.add(<int>[i]);
      i++;
    } else {
      out.add(<int>[i, i + 1]);
      i += 2;
    }
  }
  return out;
}
