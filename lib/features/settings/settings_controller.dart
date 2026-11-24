import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/motion/haptics.dart';
import '../../core/motion/motion_level.dart';
import '../../core/theme/palette.dart';

/// When the floating header's pill shows (Settings › Appearance).
enum PillMode { always, scrollUp, scrollStop }

/// Device-level settings that must be known before the first frame, kept in
/// SharedPreferences and read synchronously in `main` so the first frame is
/// already in the right theme. Per-document data never lives here.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.amoled = false,
    this.expressive = true,
    this.dynamicColor = false,
    this.familyId = 'saffron',
    this.wallpaperSeed,
    this.onboarded = false,
    this.openedFile = false,
    this.libraryGrid = true,
    this.librarySort = 'recent',
    this.findOnDevice = false,
    this.showHidden = false,
    this.haptics = false,
    this.floatingHeader = true,
    this.pillMode = PillMode.always,
    this.deviceClass = DeviceClass.unknown,
  });

  final ThemeMode themeMode;

  /// Pure black chrome. Only takes effect while dark is in effect.
  final bool amoled;

  /// Expressive colours (Kuber): surfaces tinted by the family; off, one
  /// neutral grey ramp for every family.
  final bool expressive;
  final bool dynamicColor;

  /// The chosen colour family when dynamic colour is off (Settings › Theme).
  final String familyId;

  /// The last wallpaper seed Android handed over, cached so a cold start with
  /// dynamic colour draws its first frame in the wallpaper's hue.
  final Color? wallpaperSeed;

  /// The welcome flow has run.
  final bool onboarded;

  /// A file has been opened at least once: until then the nav pill hides
  /// (HANDOFF "Deviations from Mull").
  final bool openedFile;

  /// Grid or list, for Library and every folder alike.
  final bool libraryGrid;

  /// 'recent', 'title' or 'progress'.
  final String librarySort;

  /// "Find books across this device": Library lists every PDF and EPUB on the
  /// phone (all-files access only), instead of added folders.
  final bool findOnDevice;

  /// Files: show hidden (dot) files by default; each folder can override.
  final bool showHidden;

  /// Haptic feedback (off by default).
  final bool haptics;

  /// The header floats over the page as a pill; off, it scrolls away.
  final bool floatingHeader;
  final PillMode pillMode;

  /// Probed once, ever, after the first frame (RAM and the low-RAM flag).
  final DeviceClass deviceClass;

  ThemeFamily get family =>
      dynamicColor && wallpaperSeed != null ? ThemeFamily.fromSeed(wallpaperSeed!) : ThemeFamily.byId(familyId);

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
    bool? expressive,
    bool? dynamicColor,
    String? familyId,
    Color? wallpaperSeed,
    bool? onboarded,
    bool? openedFile,
    bool? libraryGrid,
    String? librarySort,
    bool? findOnDevice,
    bool? showHidden,
    bool? haptics,
    bool? floatingHeader,
    PillMode? pillMode,
    DeviceClass? deviceClass,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    amoled: amoled ?? this.amoled,
    expressive: expressive ?? this.expressive,
    dynamicColor: dynamicColor ?? this.dynamicColor,
    familyId: familyId ?? this.familyId,
    wallpaperSeed: wallpaperSeed ?? this.wallpaperSeed,
    onboarded: onboarded ?? this.onboarded,
    openedFile: openedFile ?? this.openedFile,
    libraryGrid: libraryGrid ?? this.libraryGrid,
    librarySort: librarySort ?? this.librarySort,
    findOnDevice: findOnDevice ?? this.findOnDevice,
    showHidden: showHidden ?? this.showHidden,
    haptics: haptics ?? this.haptics,
    floatingHeader: floatingHeader ?? this.floatingHeader,
    pillMode: pillMode ?? this.pillMode,
    deviceClass: deviceClass ?? this.deviceClass,
  );

  static const String kMode = 'theme.mode';
  static const String kAmoled = 'theme.amoled';
  static const String kExpressive = 'theme.expressive';
  static const String kDynamic = 'theme.dynamic';
  static const String kSeed = 'theme.seed';
  static const String kFamily = 'theme.family';
  static const String kOnboarded = 'app.onboarded';
  static const String kOpenedFile = 'app.openedFile';
  static const String kLibraryGrid = 'library.grid';
  static const String kLibrarySort = 'library.sort';
  static const String kFindOnDevice = 'library.findOnDevice';
  static const String kShowHidden = 'files.showHidden';
  static const String kHaptics = 'haptics.enabled';
  static const String kFloatingHeader = 'header.floating';
  static const String kPillMode = 'header.pill';
  static const String kDeviceClass = 'motion.deviceClass';

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
      expressive: prefs.getBool(kExpressive) ?? true,
      // Saffron unless chosen otherwise; wallpaper colour is opt-in, or it
      // would replace that hue on most phones.
      dynamicColor: prefs.getBool(kDynamic) ?? false,
      familyId: prefs.getString(kFamily) ?? 'saffron',
      wallpaperSeed: seed == null ? null : Color(seed),
      onboarded: prefs.getBool(kOnboarded) ?? false,
      openedFile: prefs.getBool(kOpenedFile) ?? false,
      libraryGrid: prefs.getBool(kLibraryGrid) ?? true,
      librarySort: prefs.getString(kLibrarySort) ?? 'recent',
      findOnDevice: prefs.getBool(kFindOnDevice) ?? false,
      showHidden: prefs.getBool(kShowHidden) ?? false,
      haptics: prefs.getBool(kHaptics) ?? false,
      floatingHeader: prefs.getBool(kFloatingHeader) ?? true,
      pillMode: _named(PillMode.values, prefs.getString(kPillMode), PillMode.always),
      deviceClass: _named(DeviceClass.values, prefs.getString(kDeviceClass), DeviceClass.unknown),
    );
  }
}

T _named<T extends Enum>(List<T> values, String? name, T fallback) =>
    values.firstWhere((T v) => v.name == name, orElse: () => fallback);

/// Overridden in `main` with the instance opened during bootstrap.
final Provider<SharedPreferences> prefsProvider = Provider<SharedPreferences>(
  (Ref ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

/// Held in memory and written through, so reading the theme is synchronous
/// and a change repaints only the widgets that selected on it.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final AppSettings s = AppSettings.read(ref.watch(prefsProvider));
    Haptics.enabled = s.haptics;
    return s;
  }

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

  Future<void> setExpressive({required bool value}) async {
    state = state.copyWith(expressive: value);
    await _prefs.setBool(AppSettings.kExpressive, value);
    await _cacheLaunchColours();
  }

  Future<void> setFamily(String id) async {
    state = state.copyWith(familyId: id);
    await _prefs.setString(AppSettings.kFamily, id);
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

  Future<void> setFindOnDevice({required bool value}) async {
    state = state.copyWith(findOnDevice: value);
    await _prefs.setBool(AppSettings.kFindOnDevice, value);
  }

  Future<void> setShowHidden({required bool value}) async {
    state = state.copyWith(showHidden: value);
    await _prefs.setBool(AppSettings.kShowHidden, value);
  }

  Future<void> setHaptics({required bool value}) async {
    state = state.copyWith(haptics: value);
    Haptics.enabled = value;
    await _prefs.setBool(AppSettings.kHaptics, value);
  }

  Future<void> setFloatingHeader({required bool value}) async {
    state = state.copyWith(floatingHeader: value);
    await _prefs.setBool(AppSettings.kFloatingHeader, value);
  }

  Future<void> setPillMode(PillMode value) async {
    state = state.copyWith(pillMode: value);
    await _prefs.setString(AppSettings.kPillMode, value.name);
  }

  /// The one-off device probe's result, cached so it never runs again.
  Future<void> setDeviceClass(DeviceClass value) async {
    state = state.copyWith(deviceClass: value);
    await _prefs.setString(AppSettings.kDeviceClass, value.name);
  }

  Future<void> _cacheLaunchColours() async {
    final ThemeFamily f = state.family;
    final bool e = state.expressive;
    await _prefs.setInt(AppSettings.kLaunchLight, f.colors(Tone.light, expressive: e).surface.toARGB32());
    await _prefs.setInt(
      AppSettings.kLaunchDark,
      f.colors(state.amoled ? Tone.amoled : Tone.dark, expressive: e).surface.toARGB32(),
    );
  }
}

final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
