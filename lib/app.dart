import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/motion/motion.dart';
import 'core/explorer.dart';
import 'core/open.dart';
import 'core/platform/platform.dart';
import 'core/providers.dart';
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
      unawaited(_startUp());
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
    final AppSettings s = ref.watch(settingsProvider);
    // No MediaQuery above a MaterialApp, so reduced motion is read from the
    // platform directly.
    final bool reduced = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    return MaterialApp.router(
      title: 'Unfurl',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      themeMode: s.themeMode,
      theme: AppTheme.of(s.family, s.toneFor(Brightness.light)),
      darkTheme: AppTheme.of(s.family, s.toneFor(Brightness.dark)),
      // A theme change (mode, true black, a new wallpaper hue) cross-fades.
      themeAnimationDuration: reduced ? Motion.reducedFade : Motion.background,
      themeAnimationCurve: reduced ? Curves.linear : Motion.decelerate,
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
          child: child!,
        );
      },
    );
  }
}
