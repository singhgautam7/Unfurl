import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/motion/kit.dart';
import 'core/explorer.dart';
import 'core/open.dart';
import 'core/platform/platform.dart';
import 'core/providers.dart';
import 'core/tracking/tracker.dart';
import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/settings_controller.dart';

class UnfurlApp extends ConsumerStatefulWidget {
  const UnfurlApp({super.key});

  @override
  ConsumerState<UnfurlApp> createState() => _UnfurlAppState();
}

class _UnfurlAppState extends ConsumerState<UnfurlApp> with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter(onboarded: ref.read(settingsProvider).onboarded);
  StreamSubscription<DocRef>? _arrivals;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The first frame is drawn from the cached seed; the live one is asked
    // for afterwards and only repaints (cross-fading) if the wallpaper moved.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshWallpaperSeed());
      unawaited(_probeDevice());
      unawaited(_startUp());
      // Sessions a crash or a kill left open are folded into Insights.
      unawaited(ref.read(trackerProvider).recover());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_arrivals?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from elsewhere: grants may have changed and files may have moved.
    if (state == AppLifecycleState.resumed) unawaited(ref.read(libraryProvider).refreshAll());
  }

  /// "Open with" and share: a cold start's file opens straight in its
  /// viewer; a warm start's arrives through [Platform.arrivals]. Then the
  /// folders are rescanned in the background (never on the first frame).
  Future<void> _startUp() async {
    // Device-wide books need all-files access; while that's off a row left
    // from before would only show as a folder Unfurl can't see.
    if (!kAllFilesAccess && ref.read(settingsProvider).findOnDevice) {
      await ref.read(settingsProvider.notifier).setFindOnDevice(value: false);
      await ref.read(libraryProvider).setFindOnDevice(on: false);
    }
    // All-files access is re-read on every resume; start listening now.
    ref.read(filesAccessProvider);
    _arrivals = Platform.arrivals.listen(_open);
    final DocRef? launch = await Platform.takeLaunchIntent();
    if (launch != null) _open(launch);
    await ref.read(libraryProvider).refreshAll();
  }

  void _open(DocRef ref) {
    final BuildContext? ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    unawaited(this.ref.read(settingsProvider.notifier).setOnboarded());
    unawaited(openDocument(ctx, ref));
  }

  /// RAM and the low-RAM flag decide the motion level; asked once, ever,
  /// after the first frame, and cached through the settings.
  Future<void> _probeDevice() async {
    if (ref.read(settingsProvider).deviceClass != DeviceClass.unknown) return;
    final ({int totalMb, bool lowRam})? m = await Platform.deviceMemory();
    if (!mounted) return;
    // No answer (widget tests, a platform error) is left unknown, not cached.
    if (m == null) return;
    await ref.read(settingsProvider.notifier).setDeviceClass(classifyDevice(ramMb: m.totalMb, lowRamFlag: m.lowRam));
  }

  Future<void> _refreshWallpaperSeed() async {
    // dynamic_color still hands the palette back as the deprecated
    // CorePalette; only its primary tone 40 is read, which is the seed
    // Android used. Null below Android 12.
    // ignore: deprecated_member_use
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette == null || !mounted) return;
    await ref.read(settingsProvider.notifier).setWallpaperSeed(Color(palette.primary.get(40)));
  }

  @override
  Widget build(BuildContext context) {
    // Only what themes the app: any other setting leaves the root alone.
    // The family is built per call for a wallpaper, so its parts are watched.
    ref.watch(
      settingsProvider.select(
        (AppSettings s) => (s.themeMode, s.amoled, s.expressive, s.familyId, s.dynamicColor, s.wallpaperSeed),
      ),
    );
    final AppSettings s = ref.read(settingsProvider);
    return MaterialApp.router(
      title: 'Unfurl',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      themeMode: s.themeMode,
      theme: AppTheme.of(s.family, s.toneFor(Brightness.light), expressive: s.expressive),
      darkTheme: AppTheme.of(s.family, s.toneFor(Brightness.dark), expressive: s.expressive),
      // A theme change (mode, pure black, expressive, a new wallpaper hue) is
      // revealed by the ThemeRipple, which owns the change: no cross-fade.
      themeAnimationDuration: Duration.zero,
      builder: (BuildContext context, Widget? child) {
        final bool dark = Theme.of(context).brightness == Brightness.dark;
        final Brightness icons = dark ? Brightness.light : Brightness.dark;
        // Edge-to-edge: transparent bars, icons contrasting with the surface.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: icons,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: icons,
            systemNavigationBarContrastEnforced: false,
          ),
          // No haptic while a list is moving (Kuber's rule): one flag, set from
          // the scroll notifications that bubble up here anyway.
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification n) {
              if (n is ScrollStartNotification) Haptics.scrolling = true;
              if (n is ScrollEndNotification) Haptics.scrolling = false;
              return false;
            },
            child: MotionScopeHost(child: ThemeRipple(child: child!)),
          ),
        );
      },
    );
  }
}

/// Puts a [MotionScope] above every route from the device class and the
/// phone's own switches. Rebuilds only when one of them changes.
class MotionScopeHost extends ConsumerWidget {
  const MotionScopeHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DeviceClass device = ref.watch(settingsProvider.select((AppSettings s) => s.deviceClass));
    final bool systemOff = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    return MotionScope(
      level: resolveMotionLevel(device, systemOff: systemOff),
      systemOff: systemOff,
      child: child,
    );
  }
}
