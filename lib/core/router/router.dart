import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/files/files_screen.dart';
import '../../features/folders/folder_screens.dart';
import '../../features/home/home_screen.dart';
import '../../features/insights/insights_screen.dart';
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
  static const String reader = '/settings/reader';
  static const String controls = '/settings/controls';
  static const String about = '/about';
  static const String licences = '/licences';
  static const String privacy = '/privacy';
  static const String permissions = '/permissions';
  static const String insights = '/insights';

  static const String files = '/files';

  /// The Files browser in "Choose this folder" mode (Library › Add folder).
  static String pick([String path = '']) => path.isEmpty ? '/pick' : '/pick?path=${Uri.encodeQueryComponent(path)}';

  /// A picked folder at any depth: one route per level, so back goes up one.
  /// [base] keeps it in the stack it was opened from: '/library' or '/files'
  /// (inside that tab), '' (above the tabs).
  static String folder(int id, {String path = '', String base = ''}) =>
      path.isEmpty ? '$base/folder/$id' : '$base/folder/$id?path=${Uri.encodeQueryComponent(path)}';

  /// The folders list ("See all"), in a tab's stack or above the tabs.
  static String foldersIn(String base) => base.isEmpty ? folders : '$base/folders';

  /// A folder on the phone by path (Files, all-files access), in the Files stack.
  static String browse(String path) => '/files/browse?path=${Uri.encodeQueryComponent(path)}';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Pushed pages sit on the root navigator, above the shell, so they cover
/// the nav pill and carry their own back button.
GoRoute _pushed(String path, Widget Function(GoRouterState s) build) => GoRoute(
  path: path,
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (BuildContext c, GoRouterState s) => unfurlPage<void>(state: s, child: build(s)),
);

/// A tab's own folder screens: the folders list and picked folders at any
/// depth, inside that tab's stack.
List<RouteBase> _folderRoutes(String base) => <RouteBase>[
  GoRoute(
    path: 'folders',
    pageBuilder: (BuildContext c, GoRouterState s) => unfurlPage<void>(
      state: s,
      child: FoldersScreen(base: base),
    ),
  ),
  GoRoute(
    path: 'folder/:id',
    pageBuilder: (BuildContext c, GoRouterState s) => unfurlPage<void>(
      state: s,
      child: FolderScreen(
        folderId: int.parse(s.pathParameters['id']!),
        path: s.uri.queryParameters['path'] ?? '',
        base: base,
      ),
    ),
  ),
];

GoRouter buildRouter({required bool onboarded}) => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: onboarded ? Routes.home : Routes.welcome,
  // Any location Unfurl doesn't know (a stray deep link, a restored state
  // without its document) lands on Home rather than an error page.
  onException: (BuildContext context, GoRouterState state, GoRouter router) => router.go(Routes.home),
  routes: <RouteBase>[
    GoRoute(
      path: Routes.welcome,
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (BuildContext c, GoRouterState s) => unfurlPage<void>(state: s, child: const WelcomeScreen()),
    ),
    GoRoute(
      path: Routes.document,
      parentNavigatorKey: rootNavigatorKey,
      // The document travels as `extra`; without it (process death), go Home.
      redirect: (BuildContext c, GoRouterState s) => s.extra is OpenRequest ? null : Routes.home,
      pageBuilder: (BuildContext c, GoRouterState s) => unfurlPage<void>(
        state: s,
        child: DocumentScreen(request: s.extra! as OpenRequest),
      ),
    ),
    _pushed(Routes.folders, (GoRouterState s) => const FoldersScreen()),
    _pushed(
      '/folder/:id',
      (GoRouterState s) =>
          FolderScreen(folderId: int.parse(s.pathParameters['id']!), path: s.uri.queryParameters['path'] ?? ''),
    ),
    _pushed(Routes.settings, (GoRouterState s) => const SettingsScreen()),
    _pushed(Routes.theme, (GoRouterState s) => const ThemeScreen()),
    _pushed(Routes.reader, (GoRouterState s) => const ReaderSettingsScreen()),
    _pushed(Routes.controls, (GoRouterState s) => const ControlsScreen()),
    _pushed(Routes.about, (GoRouterState s) => const AboutScreen()),
    _pushed(Routes.licences, (GoRouterState s) => const LicencesScreen()),
    _pushed(Routes.privacy, (GoRouterState s) => const PrivacyScreen()),
    _pushed(Routes.permissions, (GoRouterState s) => const PermissionsScreen()),
    _pushed(Routes.insights, (GoRouterState s) => const InsightsScreen()),
    GoRoute(
      path: '/pick',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (BuildContext c, GoRouterState s) => unfurlPage<void>(
        state: s,
        child: (s.uri.queryParameters['path'] ?? '').isEmpty
            ? const FilesPickerScreen()
            : FolderScreen.explorer(root: s.uri.queryParameters['path']!, mode: FolderMode.picker),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (BuildContext context, GoRouterState state, StatefulNavigationShell shell) => NavShell(
        index: shell.currentIndex,
        // Inside a tab (a folder in Library or Files) the pill steps away.
        nested: state.uri.pathSegments.length > 1,
        onSelect: (int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        child: shell,
      ),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(path: Routes.home, builder: (BuildContext c, GoRouterState s) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.library,
              builder: (BuildContext c, GoRouterState s) => const LibraryScreen(),
              routes: _folderRoutes(Routes.library),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: Routes.files,
              builder: (BuildContext c, GoRouterState s) => const FilesScreen(),
              routes: <RouteBase>[
                ..._folderRoutes(Routes.files),
                GoRoute(
                  path: 'browse',
                  pageBuilder: (BuildContext c, GoRouterState s) => unfurlPage<void>(
                    state: s,
                    child: FolderScreen.explorer(root: s.uri.queryParameters['path'] ?? '', mode: FolderMode.explorer),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(path: Routes.notes, builder: (BuildContext c, GoRouterState s) => const NotesScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(path: Routes.more, builder: (BuildContext c, GoRouterState s) => const MoreScreen()),
          ],
        ),
      ],
    ),
  ],
);
