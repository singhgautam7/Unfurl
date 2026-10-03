import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/folders/folder_screens.dart';
import '../../features/home/home_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/notes/notes_screen.dart';
import '../../features/settings/info_screens.dart';
import '../../features/settings/more_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/viewer/document_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../motion/transitions.dart';
import '../open.dart';
import 'nav_shell.dart';

abstract final class Routes {
  static const String welcome = '/welcome';
  static const String home = '/home';
  static const String library = '/library';
  static const String notes = '/notes';
  static const String more = '/more';

  static const String document = '/document';
  static const String folders = '/folders';
  static const String settings = '/settings';
  static const String theme = '/settings/theme';
  static const String about = '/about';
  static const String licences = '/licences';
  static const String privacy = '/privacy';
  static const String permissions = '/permissions';

  /// A folder at any depth: one route per level, so back goes up one.
  static String folder(int id, {String path = ''}) =>
      path.isEmpty ? '/folder/$id' : '/folder/$id?path=${Uri.encodeQueryComponent(path)}';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Pushed pages sit on the root navigator, above the shell, so they cover
/// the nav pill and carry their own back button.
GoRoute _pushed(String path, Widget Function(GoRouterState s) build) => GoRoute(
  path: path,
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (BuildContext c, GoRouterState s) => unfurlPage<void>(state: s, child: build(s)),
);

GoRouter buildRouter({required bool onboarded}) => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: onboarded ? Routes.home : Routes.welcome,
  routes: <RouteBase>[
    GoRoute(
      path: Routes.welcome,
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (BuildContext c, GoRouterState s) => unfurlPage<void>(state: s, child: const WelcomeScreen()),
    ),
    _pushed(Routes.document, (GoRouterState s) => DocumentScreen(request: s.extra! as OpenRequest)),
    _pushed(Routes.folders, (GoRouterState s) => const FoldersScreen()),
    _pushed(
      '/folder/:id',
      (GoRouterState s) =>
          FolderScreen(folderId: int.parse(s.pathParameters['id']!), path: s.uri.queryParameters['path'] ?? ''),
    ),
    _pushed(Routes.settings, (GoRouterState s) => const SettingsScreen()),
    _pushed(Routes.theme, (GoRouterState s) => const ThemeScreen()),
    _pushed(Routes.about, (GoRouterState s) => const AboutScreen()),
    _pushed(Routes.licences, (GoRouterState s) => const LicencesScreen()),
    _pushed(Routes.privacy, (GoRouterState s) => const PrivacyScreen()),
    _pushed(Routes.permissions, (GoRouterState s) => const PermissionsScreen()),
    StatefulShellRoute.indexedStack(
      builder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) => NavShell(
        index: shell.currentIndex,
        onSelect: (int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        child: shell,
      ),
      branches: <StatefulShellBranch>[
        for (final (String path, Widget screen) in <(String, Widget)>[
          (Routes.home, const HomeScreen()),
          (Routes.library, const LibraryScreen()),
          (Routes.notes, const NotesScreen()),
          (Routes.more, const MoreScreen()),
        ])
          StatefulShellBranch(
            routes: <RouteBase>[GoRoute(path: path, builder: (BuildContext c, GoRouterState s) => screen)],
          ),
      ],
    ),
  ],
);
