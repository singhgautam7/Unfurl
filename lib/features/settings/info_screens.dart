import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../design_system/buttons.dart';
import '../../design_system/chips.dart';
import '../../design_system/containers.dart';
import '../../design_system/states.dart';
import '../reader/sheets.dart';
import 'settings_controller.dart';

/// The line under More and on About.
class MadeInIndia extends StatelessWidget {
  const MadeInIndia({super.key});

  @override
  Widget build(BuildContext context) => Text(
    'Made with ❤️ in India',
    textAlign: TextAlign.center,
    style: UnfurlType.monoLabel.copyWith(color: context.colors.onSurfaceMuted),
  );
}

/// The Unfurl mark, concept 1d ("Unrolling page"): a page with its foot
/// still rolled, on a saffron field.
class UnfurlMark extends StatelessWidget {
  const UnfurlMark({this.size = 72, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final double u = size / 72;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(18 * u)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 18 * u,
            top: 13 * u,
            child: Transform.rotate(
              angle: -0.105,
              child: Container(
                width: 36 * u,
                height: 40 * u,
                padding: EdgeInsets.symmetric(horizontal: 6 * u, vertical: 8 * u),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(5 * u), bottom: Radius.circular(2 * u)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4 * u,
                  children: <Widget>[
                    Container(
                      height: 4 * u,
                      width: 15 * u,
                      decoration: BoxDecoration(color: c.primary, borderRadius: Radii.fullR),
                    ),
                    Container(
                      height: 4 * u,
                      decoration: BoxDecoration(color: c.outline, borderRadius: Radii.fullR),
                    ),
                    Container(
                      height: 4 * u,
                      width: 19 * u,
                      decoration: BoxDecoration(color: c.outline, borderRadius: Radii.fullR),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 14 * u,
            top: 50 * u,
            child: Transform.rotate(
              angle: -0.105,
              child: Container(
                width: 45 * u,
                height: 10 * u,
                decoration: BoxDecoration(color: c.primaryContainer, borderRadius: Radii.fullR),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Appearance, as Mull's Theme page: Light, Dark or System; true black
/// while dark is in effect; colours from the wallpaper; a live preview.
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final AppSettings s = ref.watch(settingsProvider);
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    final Brightness platform = MediaQuery.platformBrightnessOf(context);
    final bool darkInEffect = switch (s.themeMode) {
      ThemeMode.light => false,
      ThemeMode.dark => true,
      ThemeMode.system => platform == Brightness.dark,
    };
    Widget row({
      required Widget leading,
      required String title,
      required String note,
      required bool value,
      required ValueChanged<bool>? onChanged,
    }) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.cardR,
        border: Border.all(color: c.outline),
      ),
      child: MergeSemantics(
        child: Row(
          spacing: Space.md,
          children: <Widget>[
            leading,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
                  Text(note, style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant)),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
    return AppScaffold(
      title: 'Theme',
      onBack: () => context.pop(),
      children: <Widget>[
        SegmentedToggle<ThemeMode>(
          options: const <(ThemeMode, String, IconData?)>[
            (ThemeMode.light, 'Light', null),
            (ThemeMode.dark, 'Dark', null),
            (ThemeMode.system, 'System', null),
          ],
          selected: s.themeMode,
          onChanged: ctl.setThemeMode,
        ),
        const SizedBox(height: Space.md),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: darkInEffect
              ? Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: row(
                    leading: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF000000),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: c.outline),
                      ),
                    ),
                    title: 'True black (AMOLED)',
                    note: 'Appears only while dark is active',
                    value: s.amoled,
                    onChanged: (bool v) => ctl.setAmoled(value: v),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        row(
          leading: Row(
            spacing: 4,
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
              ),
            ],
          ),
          title: 'From your wallpaper',
          note: s.wallpaperSeed == null ? 'dynamic colour, Android 12+' : 'otherwise Saffron',
          value: s.dynamicColor,
          onChanged: s.wallpaperSeed == null ? null : (bool v) => ctl.setDynamicColor(value: v),
        ),
        const SizedBox(height: Space.section),
        const SectionHeader(label: 'Preview'),
        const SizedBox(height: Space.sm),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Space.md,
            children: <Widget>[
              Text('Pride and Prejudice', style: UnfurlType.title.copyWith(color: c.onSurface)),
              Text('Chapter 34 · 6 min left', style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant)),
              Container(
                height: 4,
                decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: Radii.fullR),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.62,
                  child: Container(
                    decoration: BoxDecoration(color: c.primary, borderRadius: Radii.fullR),
                  ),
                ),
              ),
              Row(
                spacing: Space.sm,
                children: <Widget>[
                  AppButton(label: 'Resume', icon: AppIcons.play, height: 44, onPressed: () {}),
                  PillChip(label: 'Unread', selected: true, count: 3, onTap: () {}),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// About (A5) with Mull's structure: the mark, the version, what it
/// promises, then legal and the developer.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const String portfolio = 'https://singhgautam.com';
  static const String moreApps = 'https://play.google.com/store/apps/developer?id=Gautam+Rajeev+Singh';
  static const String listing = 'https://play.google.com/store/apps/details?id=com.grs.unfurl';
  static const String feedback = 'singhgautam.dev@gmail.com';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final String? version = ref.watch(appVersionProvider).value;
    return AppScaffold(
      title: 'About',
      onBack: () => context.pop(),
      children: <Widget>[
        const SizedBox(height: 22),
        const Align(alignment: Alignment.centerLeft, child: UnfurlMark()),
        const SizedBox(height: 14),
        Text('Unfurl', style: UnfurlType.display.copyWith(color: c.onSurface)),
        Text(
          'Version ${version ?? '…'}',
          style: UnfurlType.monoTabular.copyWith(height: 1.6, color: c.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Text(
          'A reader for PDFs, books and the documents on your phone.',
          style: UnfurlType.body.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: <Widget>[
              Row(
                spacing: 10,
                children: <Widget>[
                  AppIcon(AppIcons.shield, color: c.icon),
                  Flexible(
                    child: Text('Private by design', style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
                  ),
                ],
              ),
              Text(
                'Works offline, needs no permissions, nothing leaves your phone.',
                style: UnfurlType.note.copyWith(color: c.onSurface),
              ),
              Text(
                'No account · no ads · no analytics · no network access',
                style: UnfurlType.monoLabel.copyWith(height: 1.6, color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ListContainer(
          children: <Widget>[
            ListRow(icon: AppIcons.license, label: 'Licences', onTap: () => context.push(Routes.licences)),
            ListRow(
              icon: AppIcons.privacy,
              label: 'Privacy policy',
              value: 'Offline only',
              onTap: () => context.push(Routes.privacy),
            ),
            ListRow(
              icon: AppIcons.key,
              label: 'Permissions',
              value: 'None',
              onTap: () => context.push(Routes.permissions),
            ),
            ListRow(
              icon: AppIcons.mail,
              label: 'Send feedback',
              value: 'opens email',
              onTap: () => Platform.email(feedback, 'Unfurl ${version ?? ''}'),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        const SectionHeader(label: 'The developer'),
        const SizedBox(height: Space.sm),
        ListContainer(
          children: <Widget>[
            ListRow(
              icon: AppIcons.person,
              label: 'Gautam Rajeev Singh',
              subtitle: 'singhgautam.com',
              onTap: () => Platform.openUrl(portfolio),
            ),
            ListRow(
              icon: AppIcons.apps,
              label: 'More apps',
              subtitle: 'Everything else on Google Play',
              onTap: () => Platform.openUrl(moreApps),
            ),
            ListRow(
              icon: AppIcons.star,
              label: 'Rate Unfurl',
              subtitle: 'Helps others find it',
              onTap: () => Platform.openStore('com.grs.unfurl'),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        const MadeInIndia(),
      ],
    );
  }
}

/// Permissions, as Mull states them: what is asked for and why (nothing).
class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    Widget para(String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.sm,
        children: <Widget>[
          Text(title.toUpperCase(), style: UnfurlType.sectionHeader.copyWith(color: c.onSurfaceVariant)),
          Text(text, style: UnfurlType.body.copyWith(color: c.onSurface)),
        ],
      ),
    );
    return AppScaffold(
      title: 'Permissions',
      onBack: () => context.pop(),
      children: <Widget>[
        para(
          'Files and folders',
          'Not a permission. You pick folders in Android’s own folder picker, and Unfurl can only read those. Remove access at any time under Folders.',
        ),
        para('Internet', 'Not requested. Unfurl cannot reach the network.'),
        para('Storage', 'Not requested. Unfurl never asks to see everything on your phone.'),
        para('Notifications', 'Not requested. Unfurl never notifies you.'),
        Text(
          'Unfurl declares no runtime permissions at all.',
          style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceMuted),
        ),
      ],
    );
  }
}

/// The privacy policy, rendered from the PRIVACY_POLICY.md in the
/// repository, so the app and the store listing never say different things.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return AppScaffold(
      title: 'Privacy policy',
      onBack: () => context.pop(),
      children: <Widget>[
        FutureBuilder<String>(
          future: rootBundle.loadString('PRIVACY_POLICY.md'),
          builder: (BuildContext context, AsyncSnapshot<String> snap) {
            final String? md = snap.data;
            if (md == null) return const LoadingHairline(visible: true);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: _render(md, c));
          },
        ),
      ],
    );
  }

  static List<Widget> _render(String md, UnfurlColors c) {
    final List<Widget> out = <Widget>[];
    final List<String> paragraph = <String>[];
    final TextStyle body = UnfurlType.body.copyWith(height: 1.6, color: c.onSurfaceVariant);
    void flush() {
      if (paragraph.isEmpty) return;
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: _rich(paragraph.join(' '), body, c),
        ),
      );
      paragraph.clear();
    }

    for (final String raw in md.split('\n')) {
      final String line = raw.trimRight();
      if (line.isEmpty || line == '---') {
        flush();
      } else if (line.startsWith('# ')) {
        flush();
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: Space.lg),
            child: Text(
              line.substring(2),
              style: UnfurlType.display.copyWith(fontSize: 28, height: 1.2, color: c.onSurface),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        flush();
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: Space.md, bottom: Space.sm),
            child: Text(line.substring(3), style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
          ),
        );
      } else if (line.startsWith('- ')) {
        flush();
        out.add(
          Padding(
            padding: const EdgeInsets.only(left: Space.md, bottom: Space.xs),
            child: _rich('•  ${line.substring(2)}', body, c),
          ),
        );
      } else if (line.startsWith('|')) {
        flush();
        final List<String> cells = line
            .split('|')
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList();
        if (cells.length < 2 || cells.first.startsWith(':-') || cells.first == 'Permission') continue;
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: _rich('**${cells[0]}**: ${cells[1]}', body, c),
          ),
        );
      } else {
        paragraph.add(line);
      }
    }
    flush();
    return out;
  }

  static Widget _rich(String text, TextStyle base, UnfurlColors c) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp marks = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
    int at = 0;
    for (final RegExpMatch m in marks.allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      spans.add(
        TextSpan(
          text: m.group(1) ?? m.group(2),
          style: m.group(1) != null
              ? base.copyWith(color: c.onSurface).weight(600)
              : UnfurlType.monoLabel.copyWith(color: c.onSurface),
        ),
      );
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(TextSpan(style: base, children: spans));
  }
}

/// Licences (A5): every bundled asset and package, its licence on a row;
/// tap for the full text.
class LicencesScreen extends StatefulWidget {
  const LicencesScreen({super.key});

  @override
  State<LicencesScreen> createState() => _LicencesScreenState();
}

class _LicencesScreenState extends State<LicencesScreen> {
  final Map<String, List<String>> _texts = <String, List<String>>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await for (final LicenseEntry e in LicenseRegistry.licenses) {
      final String text = e.paragraphs.map((LicenseParagraph p) => p.text).join('\n\n');
      for (final String p in e.packages) {
        _texts.putIfAbsent(p, () => <String>[]).add(text);
      }
    }
    if (mounted) setState(() {});
  }

  static String kind(String text) {
    final String t = text.toLowerCase();
    if (t.contains('sil open font license')) return 'OFL 1.1';
    if (t.contains('apache license')) return 'Apache 2.0';
    if (t.contains('mit license') || t.contains('permission is hereby granted, free of charge')) return 'MIT';
    if (t.contains('bsd') || t.contains('redistribution and use in source and binary forms')) return 'BSD-3-Clause';
    if (t.contains('mozilla public license')) return 'MPL 2.0';
    if (t.contains('zlib')) return 'Zlib';
    return 'See text';
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final List<String> names = _texts.keys.toList()
      ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return AppScaffold(
      title: 'Licences',
      onBack: () => context.pop(),
      children: <Widget>[
        if (names.isEmpty)
          const LoadingHairline(visible: true)
        else
          ListContainer(
            children: <Widget>[
              for (final String n in names)
                ListRow(
                  label: n,
                  value: kind(_texts[n]!.first),
                  onTap: () => showReaderSheet<void>(
                    context,
                    heightFactor: 0.9,
                    (BuildContext ctx) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(n, style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
                        const SizedBox(height: Space.md),
                        Expanded(
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _texts[n]!.join('\n\n---\n\n'),
                              style: UnfurlType.monoLabel.copyWith(fontSize: 12, height: 1.5, color: c.onSurface),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
