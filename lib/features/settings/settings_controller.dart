import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/palette.dart';

/// Device-level settings that must be known before the first frame, kept in
/// SharedPreferences and read synchronously in `main` so the first frame is
/// already in the right theme. Per-document data never lives here.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.amoled = false,
    this.dynamicColor = true,
    this.wallpaperSeed,
    this.onboarded = false,
    this.openedFile = false,
    this.libraryGrid = true,
    this.librarySort = 'recent',
  });

  final ThemeMode themeMode;

  /// True black chrome. Only takes effect while dark is in effect.
  final bool amoled;
  final bool dynamicColor;

  /// The last wallpaper seed Android handed over, cached so a cold start with
  /// dynamic colour draws its first frame in the wallpaper's hue.
  final Color? wallpaperSeed;

  /// The welcome flow has run.
  final bool onboarded;

  /// A file has been opened at least once: until then the nav pill hides
  /// (HANDOFF "Deviations from Mull").
  final bool openedFile;
  final bool libraryGrid;

  /// 'recent', 'title' or 'progress'.
  final String librarySort;

  ThemeFamily get family =>
      dynamicColor && wallpaperSeed != null ? ThemeFamily.fromSeed(wallpaperSeed!) : ThemeFamily.saffron;

  Tone toneFor(Brightness platform) {
    final bool dark = switch (themeMode) {
      ThemeMode.light => false,
      ThemeMode.dark => true,
      ThemeMode.system => platform == Brightness.dark,
    };
    if (!dark) return Tone.light;
    return amoled ? Tone.amoled : Tone.dark;
  }

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? amoled,
    bool? dynamicColor,
    Color? wallpaperSeed,
    bool? onboarded,
    bool? openedFile,
    bool? libraryGrid,
    String? librarySort,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    amoled: amoled ?? this.amoled,
    dynamicColor: dynamicColor ?? this.dynamicColor,
    wallpaperSeed: wallpaperSeed ?? this.wallpaperSeed,
    onboarded: onboarded ?? this.onboarded,
    openedFile: openedFile ?? this.openedFile,
    libraryGrid: libraryGrid ?? this.libraryGrid,
    librarySort: librarySort ?? this.librarySort,
  );

  static const String kMode = 'theme.mode';
  static const String kAmoled = 'theme.amoled';
  static const String kDynamic = 'theme.dynamic';
  static const String kSeed = 'theme.seed';
  static const String kOnboarded = 'app.onboarded';
  static const String kOpenedFile = 'app.openedFile';
  static const String kLibraryGrid = 'library.grid';
  static const String kLibrarySort = 'library.sort';

  /// Read by `MainActivity` (as `flutter.theme.launch*`) to paint the window
  /// before Flutter's first frame, so a launch never flashes white or black.
  static const String kLaunchLight = 'theme.launchLight';
  static const String kLaunchDark = 'theme.launchDark';

  static AppSettings read(SharedPreferences prefs) {
    final int? seed = prefs.getInt(kSeed);
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (ThemeMode m) => m.name == prefs.getString(kMode),
        orElse: () => ThemeMode.system,
      ),
      amoled: prefs.getBool(kAmoled) ?? false,
      dynamicColor: prefs.getBool(kDynamic) ?? true,
      wallpaperSeed: seed == null ? null : Color(seed),
      onboarded: prefs.getBool(kOnboarded) ?? false,
      openedFile: prefs.getBool(kOpenedFile) ?? false,
      libraryGrid: prefs.getBool(kLibraryGrid) ?? true,
      librarySort: prefs.getString(kLibrarySort) ?? 'recent',
    );
  }
}

/// Overridden in `main` with the instance opened during bootstrap.
final Provider<SharedPreferences> prefsProvider = Provider<SharedPreferences>(
  (Ref ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

/// Held in memory and written through, so reading the theme is synchronous
/// and a change repaints only the widgets that selected on it.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.read(ref.watch(prefsProvider));

  SharedPreferences get _prefs => ref.read(prefsProvider);

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(AppSettings.kMode, mode.name);
  }

  Future<void> setAmoled({required bool value}) async {
    state = state.copyWith(amoled: value);
    await _prefs.setBool(AppSettings.kAmoled, value);
    await _cacheLaunchColours();
  }

  Future<void> setDynamicColor({required bool value}) async {
    state = state.copyWith(dynamicColor: value);
    await _prefs.setBool(AppSettings.kDynamic, value);
    await _cacheLaunchColours();
  }

  /// The live wallpaper seed, once the platform answers. A change animates
  /// (MaterialApp's theme cross-fade) and is cached for the next cold start.
  Future<void> setWallpaperSeed(Color? seed) async {
    if (seed == null || seed.toARGB32() == state.wallpaperSeed?.toARGB32()) return;
    state = state.copyWith(wallpaperSeed: seed);
    await _prefs.setInt(AppSettings.kSeed, seed.toARGB32());
    await _cacheLaunchColours();
  }

  Future<void> setOnboarded() async {
    state = state.copyWith(onboarded: true);
    await _prefs.setBool(AppSettings.kOnboarded, true);
  }

  Future<void> setOpenedFile() async {
    if (state.openedFile) return;
    state = state.copyWith(openedFile: true);
    await _prefs.setBool(AppSettings.kOpenedFile, true);
  }

  Future<void> setLibraryGrid({required bool grid}) async {
    state = state.copyWith(libraryGrid: grid);
    await _prefs.setBool(AppSettings.kLibraryGrid, grid);
  }

  Future<void> setLibrarySort(String sort) async {
    state = state.copyWith(librarySort: sort);
    await _prefs.setString(AppSettings.kLibrarySort, sort);
  }

  /// Grid or list, remembered per folder level.
  bool folderGrid(String key) => _prefs.getBool('folder.grid.$key') ?? true;
  Future<void> setFolderGrid(String key, {required bool grid}) => _prefs.setBool('folder.grid.$key', grid);

  Future<void> _cacheLaunchColours() async {
    final ThemeFamily f = state.family;
    await _prefs.setInt(AppSettings.kLaunchLight, f.colors(Tone.light).surface.toARGB32());
    await _prefs.setInt(AppSettings.kLaunchDark, f.colors(state.amoled ? Tone.amoled : Tone.dark).surface.toARGB32());
  }
}

final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
