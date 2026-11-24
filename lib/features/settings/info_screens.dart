import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/explorer.dart' show kAllFilesAccess;
import '../../core/motion/kit.dart';
import '../../core/platform/platform.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/launcher_icon.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_header.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/buttons.dart';
import '../../design_system/chips.dart';
import '../../design_system/containers.dart';
import '../../design_system/family_card.dart';
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
    style: UnfurlType.monoLabel.copyWith(color: context.colors.onSurfaceVariant),
  );
}

/// The app icon as the launcher draws it (v2 · V2-ICON): the glyph on its
/// pale ochre under the rounded-square mask.
class UnfurlMark extends StatelessWidget {
  const UnfurlMark({this.size = 72, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Unfurl',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * 92 / 512),
      child: CustomPaint(size: Size.square(size), painter: const _MarkPainter()),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = LauncherIcon.background);
    LauncherIcon.paint(canvas, size.width);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => false;
}

/// Appearance, as Kuber's Theme page: Light, Dark or System; Expressive
/// colours; Pure black while dark is in effect; the families, each previewed
/// under the current switches; colours from the wallpaper; a live preview.
class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return AppScaffold(
      title: 'Theme',
      onBack: () => context.pop(),
      children: <Widget>[
        const ThemeControls(),
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
              // Wraps at large text instead of clipping the chip.
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
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

/// Every theme switch, shared by Settings › Theme and the welcome flow.
class ThemeControls extends ConsumerStatefulWidget {
  /// [modeOnly]: Light, Dark and System alone, as the
  /// welcome setup page asks for nothing else.
  const ThemeControls({this.modeOnly = false, super.key});

  final bool modeOnly;

  @override
  ConsumerState<ThemeControls> createState() => _ThemeControlsState();
}

class _ThemeControlsState extends ConsumerState<ThemeControls> {
  /// Where the last tap landed: a theme change ripples out from it.
  Offset? _tap;

  /// A theme change, revealed as a ripple from the tap (handoff decision 15).
  Future<void> _ripple(FutureOr<void> Function() change) => ThemeRipple.of(context).run(_tap, change);

  Widget _mode(ThemeMode mode, SettingsController ctl) => SegmentedToggle<ThemeMode>(
    options: const <(ThemeMode, String, IconData?)>[
      (ThemeMode.light, 'Light', null),
      (ThemeMode.dark, 'Dark', null),
      (ThemeMode.system, 'System', null),
    ],
    selected: mode,
    onChanged: (ThemeMode m) => _ripple(() => ctl.setThemeMode(m)),
  );

  @override
  Widget build(BuildContext context) {
    final SettingsController ctl = ref.read(settingsProvider.notifier);
    Widget listen(Widget child) => Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent e) => _tap = e.position,
      child: child,
    );
    if (widget.modeOnly) {
      return listen(_mode(ref.watch(settingsProvider.select((AppSettings s) => s.themeMode)), ctl));
    }
    // The theme page uses nearly every field, so it watches them all.
    final AppSettings s = ref.watch(settingsProvider);
    final bool light = s.themeMode == ThemeMode.light;
    final Tone tone = s.toneFor(MediaQuery.platformBrightnessOf(context));
    return listen(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _mode(s.themeMode, ctl),
          const SizedBox(height: Space.md),
          ListContainer(
            children: <Widget>[
              ListRow(
                icon: AppIcons.palette,
                label: 'Expressive colours',
                subtitle: 'Tint backgrounds with your theme colour',
                switchValue: s.expressive,
                onChanged: (bool v) => _ripple(() => ctl.setExpressive(value: v)),
              ),
              // Dimmed in Light, where it can't act; choosing Dark turns it on.
              ListRow(
                icon: AppIcons.darkMode,
                label: 'Pure black',
                subtitle: light ? 'Used in dark mode' : 'Black background in dark mode, saves battery on OLED',
                switchValue: s.amoled && !light,
                enabled: !light,
                onChanged: (bool v) => _ripple(() => ctl.setAmoled(value: v)),
              ),
            ],
          ),
          if (s.themeMode == ThemeMode.system)
            Padding(
              padding: const EdgeInsets.only(left: Space.lg, top: Space.sm),
              child: Row(
                spacing: 6,
                children: <Widget>[
                  AppIcon(AppIcons.info, size: 14, color: context.colors.onSurfaceVariant),
                  Expanded(
                    child: Text(
                      'Applies when your phone is in dark mode',
                      style: UnfurlType.bodySmall.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Space.lg),
          // Picking a family turns wallpaper colour off.
          TwoColumnGrid(
            children: <Widget>[
              for (final ThemeFamily f in ThemeFamily.all)
                FamilyCard(
                  family: f,
                  tone: tone,
                  expressive: s.expressive,
                  selected: !s.dynamicColor && s.familyId == f.id,
                  onTap: () => _ripple(() async {
                    await ctl.setDynamicColor(value: false);
                    await ctl.setFamily(f.id);
                  }),
                ),
            ],
          ),
          // Below Android 12 there is no wallpaper colour: no row at all.
          if (s.wallpaperSeed != null) ...<Widget>[
            const SizedBox(height: Space.lg),
            ListContainer(
              children: <Widget>[
                ListRow(
                  icon: AppIcons.image,
                  label: 'From your wallpaper',
                  subtitle: 'Otherwise ${ThemeFamily.byId(s.familyId).name}',
                  switchValue: s.dynamicColor,
                  onChanged: (bool v) => _ripple(() => ctl.setDynamicColor(value: v)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// About, as Mull's: a note from the developer, what it stands for as four
/// tiles, what it is in a paragraph, the version, legal, and the ways out to
/// the developer. The mark (v2 · V2-ICON) heads the page, as on A5; the
/// Offline tile carries the V2-04 line.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const String portfolio = 'https://singhgautam.com';
  static const String moreApps = 'https://play.google.com/store/apps/developer?id=Gautam+Rajeev+Singh';
  static const String feedback = 'singhgautam.dev@gmail.com';

  static const List<(IconData, String, String)> _pillars = <(IconData, String, String)>[
    (AppIcons.wrapText, 'Unfurl', 'Any PDF reflows into a page in your font, size and theme. Highlights come along.'),
    (
      AppIcons.folderOpen,
      'Everything',
      'PDF, EPUB, Kindle, FB2 and HTML books get the full reader; comics their own viewer. Word, slides, sheets, Markdown, text and images open too.',
    ),
    (
      AppIcons.editOff,
      'Read only',
      'Unfurl never edits, moves or deletes a file. Notes and highlights stay in the app.',
    ),
    (AppIcons.lock, 'Offline', 'Works offline. Unfurl has no internet access, so nothing can leave your phone.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnfurlColors c = context.colors;
    final String? version = ref.watch(appVersionProvider).value;
    return AppScaffold(
      title: 'About Unfurl',
      onBack: () => context.pop(),
      children: <Widget>[
        const SizedBox(height: Space.sm),
        const Align(alignment: Alignment.centerLeft, child: UnfurlMark()),
        const SizedBox(height: Space.xl),
        _AboutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionHeader(label: 'A note from the developer'),
              const SizedBox(height: Space.md),
              Text('A reader that stays out of the way.', style: UnfurlType.sheetTitle.copyWith(color: c.onSurface)),
              const SizedBox(height: Space.lg),
              Text(
                'Hey there,\n\n'
                'Thank you for installing Unfurl.\n\n'
                'I read a lot on my phone: books, papers, the odd manual that arrives in a chat. Every reader '
                'I tried wanted an account, showed ads, or opened one kind of file and not the next. And a PDF '
                'on a phone screen meant pinching and panning, line by line.\n\n'
                'So I built the one I wanted. It opens what is already on your phone, remembers where you were, '
                'and lets a PDF unfurl into a page that reads like a book, in your own font and colours. It '
                'never touches the network, so what you read stays yours.\n\n'
                'I hope it becomes the one you reach for.',
                style: UnfurlType.body.copyWith(height: 1.7, color: c.onSurface),
              ),
              const SizedBox(height: Space.xl),
              Text('Gautam Rajeev Singh', style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
              const SizedBox(height: Space.xs),
              PressableRow(
                semanticLabel: 'singhgautam.com',
                onTap: () => unawaited(Platform.openUrl(portfolio)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: IconSpec.tapTarget),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: 1,
                    child: Text('singhgautam.com', style: UnfurlType.bodySmall.copyWith(color: c.accent)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        const MadeInIndia(),
        const SizedBox(height: Space.xl),
        const Padding(
          padding: EdgeInsets.only(left: Space.xs, bottom: Space.sm),
          child: SectionHeader(label: 'What it stands for'),
        ),
        for (int row = 0; row < _pillars.length; row += 2) ...<Widget>[
          if (row > 0) const SizedBox(height: Space.row),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Space.row,
              children: <Widget>[for (int i = row; i < row + 2; i++) Expanded(child: _Pillar(_pillars[i]))],
            ),
          ),
        ],
        const SizedBox(height: Space.xl),
        _AboutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionHeader(label: 'What it is'),
              const SizedBox(height: Space.md),
              Text(
                'A free reader for the documents already on your phone. Add a folder, or browse the whole phone '
                'in Files, and every book lands in your Library with its cover and your place in it. Highlight, '
                'add notes, bookmark, search, or have it read aloud.',
                style: UnfurlType.body.copyWith(height: 1.6, color: c.onSurfaceVariant),
              ),
              const SizedBox(height: Space.md),
              Text(
                'There is no account, ad, streak or red dot anywhere in it.',
                style: UnfurlType.body.copyWith(height: 1.6, color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        _AboutCard(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, Space.md),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text('Version', style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
              ),
              PillChip(label: version ?? '…', onTap: null),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        const SectionHeader(label: 'Legal'),
        const SizedBox(height: Space.sm),
        ListContainer(
          children: <Widget>[
            ListRow(
              icon: AppIcons.privacy,
              label: 'Privacy policy',
              subtitle: 'Offline only',
              onTap: () => context.push(Routes.privacy),
            ),
            ListRow(
              icon: AppIcons.key,
              label: 'Permissions',
              subtitle: 'What Unfurl asks for',
              onTap: () => context.push(Routes.permissions),
            ),
            ListRow(
              icon: AppIcons.license,
              label: 'Licences',
              subtitle: 'Fonts and packages it uses',
              onTap: () => context.push(Routes.licences),
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
            ListRow(
              icon: AppIcons.mail,
              label: 'Send feedback',
              subtitle: 'Opens your email app',
              onTap: () => Platform.email(feedback, 'Unfurl ${version ?? ''}'),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        Text(
          'No account. No server. Nothing leaves the phone.',
          textAlign: TextAlign.center,
          style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceMuted),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.child, this.padding = const EdgeInsets.all(Space.xl)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.cardR,
        border: Border.all(color: c.outline),
      ),
      child: child,
    );
  }
}

/// One pillar: the glyph, then the title and line at the foot. As tall as
/// its row needs, so nothing clips at any text size.
class _Pillar extends StatelessWidget {
  const _Pillar(this.tile);

  final (IconData, String, String) tile;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final (IconData icon, String title, String line) = tile;
    return _AboutCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppIcon(icon, size: 20, color: c.iconMuted),
          const SizedBox(height: Space.xl),
          Text(title, style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
          const SizedBox(height: 6),
          Text(line, style: UnfurlType.bodySmall.copyWith(height: 1.4, color: c.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Permissions, as Mull states them: what is asked for, when and why.
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
          SectionHeader(label: title),
          Text(text, style: UnfurlType.body.copyWith(color: c.onSurface)),
        ],
      ),
    );
    return AppScaffold(
      title: 'Permissions',
      onBack: () => context.pop(),
      children: <Widget>[
        if (kAllFilesAccess)
          para(
            'All files access',
            'Optional, and asked for only from the Files tab. With it, Files can browse your whole phone and '
                'Library can find books anywhere on it. Unfurl only reads: it never edits, moves or deletes a file. '
                'Everything else works without it.',
          ),
        para(
          'Files and folders',
          'Not a permission. You pick folders in Android’s own folder picker, and Unfurl can only read those. '
              'Remove access at any time under Folders.',
        ),
        para('Internet', 'Not requested. Unfurl cannot reach the network.'),
        para('Notifications', 'Not requested. Unfurl never notifies you.'),
        Text(
          'Change all files access at any time in Android settings.',
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
    if (t.contains('bsd zero clause')) return '0BSD';
    if (t.contains('unrar')) return 'UnRAR';
    if (t.contains('bsd') || t.contains('redistribution and use in source and binary forms')) return 'BSD-3-Clause';
    if (t.contains('mozilla public license')) return 'MPL 2.0';
    if (t.contains('zlib')) return 'Zlib';
    if (t.contains('this product includes software developed at')) return 'Apache 2.0';
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
