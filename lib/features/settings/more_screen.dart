import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/platform.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_header.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/containers.dart';
import 'info_screens.dart';
import 'settings_controller.dart';
import 'settings_screen.dart';

/// Board 2, A5: Mull's grouped rows. Settings (folders live there), About and Licences
/// are pushed pages; the nav hides under them. Then the sibling app. Groups,
/// order and footer follow Mull's More.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    final String? version = ref.watch(appVersionProvider).value;
    return AppScaffold(
      title: 'More',
      children: <Widget>[
        const SectionHeader(label: 'General'),
        const SizedBox(height: Space.md),
        ListContainer(
          children: <Widget>[
            ListRow(
              icon: AppIcons.tune,
              label: 'Settings',
              value: SettingsScreen.themeSummary(settings),
              minHeight: 60,
              onTap: () => context.push(Routes.settings),
            ),
          ],
        ),
        const SizedBox(height: Space.section),
        const SectionHeader(label: 'About Unfurl'),
        const SizedBox(height: Space.md),
        ListContainer(
          children: <Widget>[
            ListRow(
              icon: AppIcons.privacy,
              label: 'Privacy',
              value: 'Offline only',
              minHeight: 60,
              onTap: () => context.push(Routes.privacy),
            ),
            ListRow(
              icon: AppIcons.key,
              label: 'Permissions',
              minHeight: 60,
              onTap: () => context.push(Routes.permissions),
            ),
            ListRow(
              icon: AppIcons.license,
              label: 'Licences',
              minHeight: 60,
              onTap: () => context.push(Routes.licences),
            ),
            ListRow(
              icon: AppIcons.info,
              label: 'About',
              value: version?.split(' ').first,
              minHeight: 60,
              onTap: () => context.push(Routes.about),
            ),
          ],
        ),
        const SizedBox(height: Space.section),
        const SectionHeader(label: 'From the same maker'),
        const SizedBox(height: Space.md),
        const MullCard(),
        const SizedBox(height: Space.section),
        const MadeInIndia(),
      ],
    );
  }
}

/// Mull, the sibling dictionary: "Get" opens its store page; installed, it
/// opens Mull.
class MullCard extends ConsumerWidget {
  const MullCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final bool installed = ref.watch(mullInstalledProvider).value ?? false;
    return SurfaceCard(
      child: Row(
        spacing: 14,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(Space.md),
            child: Image.asset('assets/images/mull.png', width: 48, height: 48, cacheWidth: 144),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Mull', style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
                Text(
                  'An offline dictionary for collecting words worth keeping.',
                  style: UnfurlType.bodySmall.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Material(
            color: c.surfaceContainerHigh,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => unawaited(
                installed ? Platform.openApp(Platform.mullPackage) : Platform.openStore(Platform.mullPackage),
              ),
              child: Container(
                height: 40,
                constraints: const BoxConstraints(minWidth: 56),
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                alignment: Alignment.center,
                child: Text(
                  installed ? 'Open' : 'Get',
                  style: UnfurlType.titleMedium.copyWith(fontSize: 14, color: c.onSurface),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
