import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/layout.dart';
import '../../core/library/enrich.dart';
import '../../core/motion/motion.dart';
import '../../core/platform/platform.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/reading_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../design_system/app_icon.dart';
import '../../design_system/app_snackbar.dart';
import '../../design_system/buttons.dart';
import '../../design_system/chips.dart';
import '../../design_system/option_tiles.dart';
import '../files/files_widgets.dart';
import '../insights/book_insights.dart' show SidePanel;
import '../reader/reading_prefs.dart';
import '../reader/sheets.dart';
import '../settings/settings_controller.dart';
import 'share_card.dart';

/// Board 6, V5: the card editor, a sheet on phones and a 400dp side panel on
/// expanded widths. Opens with the current reading theme and font, Classic
/// and 1:1, then remembers the last choices.
Future<void> showCardEditor(BuildContext context, CardContent content) {
  Widget editor(VoidCallback close) => CardEditor(content: content, onClose: close);
  if (SizeClass.of(context) == SizeClass.expanded) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close card editor',
      barrierColor: context.colors.scrim,
      transitionDuration: Motion.of(context, Motion.sheet),
      pageBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b) => Align(
        alignment: Alignment.centerRight,
        child: SidePanel(child: editor(() => Navigator.of(ctx).pop())),
      ),
      transitionBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b, Widget child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a, curve: Motion.curveOf(ctx, Motion.decelerate))),
        child: child,
      ),
    );
  }
  return showReaderSheet<void>(
    context,
    heightFactor: 0.94,
    (BuildContext ctx) => editor(() => Navigator.of(ctx).pop()),
  );
}

/// A cover's leading colours, quantised off the UI isolate and remembered
/// per fingerprint for the session.
abstract final class CoverPalette {
  static final Map<String, List<int>> _cache = <String, List<int>>{};

  static Future<List<int>?> of(String? fingerprint) async {
    if (fingerprint == null) return null;
    final List<int>? hit = _cache[fingerprint];
    if (hit != null) return hit;
    final File? art = Covers.fileFor(fingerprint);
    if (art == null) return null;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(await art.readAsBytes(), targetWidth: 64);
      final ui.Image img = (await codec.getNextFrame()).image;
      codec.dispose();
      final ByteData? rgba = await img.toByteData();
      img.dispose();
      if (rgba == null) return null;
      final List<int> seeds = await Isolate.run(() => _score(rgba));
      return _cache[fingerprint] = seeds;
    } on Object {
      return null;
    }
  }

  static Future<List<int>> _score(ByteData rgba) async {
    final List<int> pixels = <int>[
      for (int i = 0; i + 3 < rgba.lengthInBytes; i += 4)
        if (rgba.getUint8(i + 3) > 200)
          0xFF000000 | rgba.getUint8(i) << 16 | rgba.getUint8(i + 1) << 8 | rgba.getUint8(i + 2),
    ];
    final QuantizerResult q = await QuantizerCelebi().quantize(pixels, 64);
    return Score.score(q.colorToCount, desired: 3, filter: false);
  }
}

class CardEditor extends ConsumerStatefulWidget {
  const CardEditor({required this.content, required this.onClose, super.key});

  final CardContent content;
  final VoidCallback onClose;

  @override
  ConsumerState<CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends ConsumerState<CardEditor> {
  final GlobalKey _card = GlobalKey();
  late CardStyle _style;
  CardSource _source = CardSource.themes;
  int _swatch = 0;
  int? _coverSeed;
  double? _fitted;
  bool _fits = true;
  bool _busy = false;

  late final SharedPreferences _prefs = ref.read(prefsProvider);

  @override
  void initState() {
    super.initState();
    final ReadingPrefs rp = ref.read(readingPrefsProvider);
    T pick<T extends Enum>(List<T> values, String key, T fallback) =>
        values.where((T v) => v.name == _prefs.getString(key)).firstOrNull ?? fallback;
    _style = CardStyle(
      template: pick(CardTemplate.values, 'card.template', CardTemplate.classic),
      ratio: pick(CardRatio.values, 'card.ratio', CardRatio.square),
      font: pick(ReaderFont.values, 'card.font', rp.font),
      showTitle: _prefs.getBool('card.title') ?? true,
      showAuthor: _prefs.getBool('card.author') ?? true,
      showCover: _prefs.getBool('card.cover') ?? false,
      showLocation: _prefs.getBool('card.location') ?? true,
      showMark: _prefs.getBool('card.mark') ?? true,
    );
    _source = pick(CardSource.values, 'card.source', CardSource.themes);
    _swatch = _prefs.getInt('card.swatch') ?? -1;
    unawaited(
      CoverPalette.of(widget.content.fingerprint).then((List<int>? seeds) {
        if (mounted) setState(() => _coverSeed = seeds?.firstOrNull);
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // First time: the theme being read in.
    if (_swatch < 0) {
      final ReadingThemeId id = readingThemeOf(context, ref.read(readingPrefsProvider), ref.read(settingsProvider)).id;
      _swatch = switch (id) {
        ReadingThemeId.sepia => 1,
        ReadingThemeId.dark || ReadingThemeId.dusk => 2,
        ReadingThemeId.amoled => 3,
        _ => 0,
      };
    }
  }

  void _set(CardStyle s) {
    setState(() => _style = s);
    unawaited(_prefs.setString('card.template', s.template.name));
    unawaited(_prefs.setString('card.ratio', s.ratio.name));
    unawaited(_prefs.setString('card.font', s.font.name));
    unawaited(_prefs.setBool('card.title', s.showTitle));
    unawaited(_prefs.setBool('card.author', s.showAuthor));
    unawaited(_prefs.setBool('card.cover', s.showCover));
    unawaited(_prefs.setBool('card.location', s.showLocation));
    unawaited(_prefs.setBool('card.mark', s.showMark));
  }

  void _setBackground(CardSource source, int swatch) {
    setState(() {
      _source = source;
      _swatch = swatch;
    });
    unawaited(_prefs.setString('card.source', source.name));
    unawaited(_prefs.setInt('card.swatch', swatch));
  }

  List<CardPalette> _palettes(ThemeFamily f) => switch (_source) {
    CardSource.themes => <CardPalette>[for (final ReadingThemeId id in CardSpec.themes) CardSpec.theme(f, id)],
    CardSource.accent => <CardPalette>[for (int k = 0; k < 4; k++) CardSpec.accent(f, k)],
    CardSource.cover => <CardPalette>[
      for (int k = 0; k < 3; k++) CardSpec.cover(_coverSeed ?? CardSpec.coverSeed(widget.content.title), k),
    ],
  };

  String _swatchName(ThemeFamily f, int i) => switch (_source) {
    CardSource.themes => ReadingTheme.of(f, CardSpec.themes[i]).name,
    CardSource.accent => 'Accent ${i + 1}',
    CardSource.cover => 'Cover ${i + 1}',
  };

  /// The card as a 1080-wide PNG, encoded off the UI thread by the engine.
  Future<Uint8List?> _render() async {
    final RenderRepaintBoundary? b = _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (b == null) return null;
    final ui.Image img = await b.toImage(pixelRatio: CardRatio.width / b.size.width);
    try {
      return (await img.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();
    } finally {
      img.dispose();
    }
  }

  /// Cached renders live in `cache/cards`; older ones go each time.
  static Future<File> _cacheFile() async {
    final Directory dir = Directory(p.join((await getTemporaryDirectory()).path, 'cards'));
    if (dir.existsSync()) {
      for (final FileSystemEntity e in dir.listSync()) {
        if (e is File && DateTime.now().difference(e.statSync().modified) > const Duration(hours: 1)) await e.delete();
      }
    } else {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'unfurl-card-${DateTime.now().millisecondsSinceEpoch}.png'));
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final Uint8List? png = await _render();
      if (png == null) return;
      final File f = await _cacheFile();
      await f.writeAsBytes(png, flush: true);
      await Platform.shareImage(f.path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final Uint8List? png = await _render();
      if (png == null) return;
      final String? uri = await Platform.saveImage(png, 'Unfurl card ${DateTime.now().millisecondsSinceEpoch}.png');
      if (!mounted) return;
      uri == null
          ? AppSnackbar.error(context, 'Couldn’t save the card. Use Share instead.')
          : AppSnackbar.info(context, 'Saved to Pictures/Unfurl');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final ThemeFamily family = ref.watch(settingsProvider.select((AppSettings s) => s.family));
    final List<CardPalette> palettes = _palettes(family);
    final int swatch = _swatch.clamp(0, palettes.length - 1);
    final CardStyle s = _style;
    final double ratio = s.ratio.height / CardRatio.width;
    final String? caption = !_fits
        ? (s.ratio == CardRatio.story ? 'Quote shortened to fit.' : 'Quote shortened to fit. Try 9:16.')
        : (_fitted != null && _fitted! < s.ratio.maxPx ? 'Text fitted to ${_fitted!.round()} px' : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SheetHead(title: 'Share as card', onClose: widget.onClose),
        // The live preview: the export itself, scaled.
        Container(
          margin: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, Space.xs),
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: Radii.cardR),
          child: Column(
            spacing: Space.sm,
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) {
                  final double h = (MediaQuery.sizeOf(context).height * 0.3).clamp(150, 320);
                  final double w = (h / ratio).clamp(0, box.maxWidth);
                  return AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    curve: Motion.decelerate,
                    width: w,
                    height: w * ratio,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: <BoxShadow>[BoxShadow(color: c.shadow, blurRadius: 20, offset: const Offset(0, 6))],
                    ),
                    child: FittedBox(
                      child: RepaintBoundary(
                        key: _card,
                        child: ShareCard(
                          content: widget.content,
                          style: s,
                          palette: palettes[swatch],
                          onFit: (double size, bool fits) {
                            if (mounted && (size != _fitted || fits != _fits)) {
                              setState(() {
                                _fitted = size;
                                _fits = fits;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (caption != null)
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: UnfurlType.monoLabel.copyWith(color: _fits ? c.onSurfaceVariant : c.danger),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              OptionGroup(
                label: 'Template',
                children: <Widget>[
                  for (final CardTemplate t in CardTemplate.values)
                    OptionTile(
                      label: t.label,
                      height: 44,
                      selected: s.template == t,
                      onTap: () => _set(s.copyWith(template: t)),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 0),
                child: SegmentedToggle<CardSource>(
                  options: const <(CardSource, String, IconData?)>[
                    (CardSource.themes, 'Theme', null),
                    (CardSource.accent, 'Accent', null),
                    (CardSource.cover, 'Book cover', null),
                  ],
                  selected: _source,
                  onChanged: (CardSource v) => _setBackground(v, 0),
                ),
              ),
              OptionGroup(
                label: 'Background',
                value: _swatchName(family, swatch),
                gap: Space.xs, // 12dp between circles: 4 plus the targets' 4dp margins.
                scroll: true,
                children: <Widget>[
                  for (int i = 0; i < palettes.length; i++)
                    OptionTile(
                      round: true,
                      width: 40,
                      height: 40,
                      background: palettes[i].background,
                      selected: i == swatch,
                      semanticLabel: _swatchName(family, i),
                      onTap: () => _setBackground(_source, i),
                    ),
                ],
              ),
              OptionGroup(
                label: 'Font',
                value: s.font.label,
                children: <Widget>[
                  for (final ReaderFont f in ReaderFont.values)
                    OptionTile(
                      label: 'Aa',
                      height: 48,
                      semanticLabel: f.label,
                      style: TextStyle(fontFamily: f.family, fontSize: 20, height: 1),
                      selected: s.font == f,
                      onTap: () => _set(s.copyWith(font: f)),
                    ),
                ],
              ),
              OptionGroup(
                label: 'Aspect ratio',
                children: <Widget>[
                  for (final CardRatio r in CardRatio.values)
                    OptionTile(
                      label: r.label,
                      height: 44,
                      selected: s.ratio == r,
                      onTap: () => _set(s.copyWith(ratio: r)),
                    ),
                ],
              ),
              ExplorerRow(
                name: 'Book title',
                switchValue: s.showTitle,
                onSwitch: (bool v) => _set(s.copyWith(showTitle: v)),
              ),
              ExplorerRow(
                name: 'Author',
                switchValue: s.showAuthor,
                onSwitch: (bool v) => _set(s.copyWith(showAuthor: v)),
              ),
              ExplorerRow(
                name: 'Cover thumbnail',
                switchValue: s.template == CardTemplate.cover || s.showCover,
                onSwitch: s.template == CardTemplate.cover ? null : (bool v) => _set(s.copyWith(showCover: v)),
              ),
              ExplorerRow(
                name: 'Page or location',
                switchValue: s.showLocation,
                onSwitch: (bool v) => _set(s.copyWith(showLocation: v)),
              ),
              ExplorerRow(
                name: 'Unfurl mark',
                switchValue: s.showMark,
                onSwitch: (bool v) => _set(s.copyWith(showMark: v)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 10, Space.lg, Space.xs),
          child: Row(
            spacing: 10,
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: 'Save to Photos',
                  icon: AppIcons.download,
                  type: AppButtonType.secondary,
                  tight: true,
                  onPressed: _busy ? null : () => unawaited(_save()),
                ),
              ),
              Expanded(
                child: AppButton(
                  label: 'Share',
                  icon: AppIcons.share,
                  tight: true,
                  onPressed: _busy ? null : () => unawaited(_share()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
