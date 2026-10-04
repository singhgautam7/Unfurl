import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import '../../core/library/enrich.dart';
import '../../core/theme/launcher_icon.dart';
import '../../core/theme/oklch.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/reading_theme.dart';
import '../../core/theme/typography.dart';
import '../../design_system/covers.dart';
import '../../formats/format_registry.dart';
import '../reader/reading_prefs.dart';

/// Board 6, V5: Classic, Bold, Margin, Cover.
enum CardTemplate {
  classic('Classic'),
  bold('Bold'),
  margin('Margin'),
  cover('Cover');

  const CardTemplate(this.label);
  final String label;
}

/// 1:1, 4:5, 9:16 at 1080 wide (`shareCard.sizes`), with each ratio's
/// starting quote size (`quoteMaxPx`).
enum CardRatio {
  square('1:1', 1080, 64),
  portrait('4:5', 1350, 72),
  story('9:16', 1920, 84);

  const CardRatio(this.label, this.height, this.maxPx);
  final String label;
  final double height;
  final double maxPx;

  static const double width = 1080;
  Size get size => Size(width, height);
}

/// Where the background comes from.
enum CardSource { themes, accent, cover }

/// A card's four colours: background, ink, muted ink, accent.
@immutable
class CardPalette {
  const CardPalette(this.background, this.ink, this.muted, this.accent);

  final Color background;
  final Color ink;
  final Color muted;
  final Color accent;
}

/// `shareCard.*` from `unfurl-v3-tokens.js`.
abstract final class CardSpec {
  /// Quote and title ink at least 4.5:1 on the background; the muted line 3:1.
  static const double inkContrast = 4.5;
  static const double mutedContrast = 3;

  /// Moves [c]'s OKLCH lightness away from [bg] until it reaches [min]:1. The
  /// spec's tones meet it for most hues; a few (cyan at L 0.535) need a nudge.
  static Color legible(Color c, Color bg, double min) {
    if (contrast(c, bg) >= min) return c;
    final Oklch o = Oklch.fromColor(c);
    final bool up = bg.computeLuminance() < 0.18;
    for (double l = o.l; l >= 0 && l <= 1; l += up ? 0.01 : -0.01) {
      final Color t = Oklch(l, o.c * (up ? 0.6 : 1), o.h).toColor();
      if (contrast(t, bg) >= min) return t;
    }
    return up ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  }

  static CardPalette _legible(Color bg, Color ink, Color muted, Color accent) =>
      CardPalette(bg, legible(ink, bg, inkContrast), legible(muted, bg, mutedContrast), accent);

  static const double padding = 96;
  static const double gap = 40;
  static const double minPx = 30;
  static const double stepPx = 2;

  /// The quote's share of the card's height. Board 6 shows fitted sizes well
  /// under the ratio maximum (56 px for a two-line-ish quote at 1:1, 34 px for
  /// a long one at 4:5); fitting into 28% of the height reproduces every
  /// example within 4 px (test/tool/fit_calibration_test.dart). Filling all
  /// the free space made short quotes land at the maximum.
  static const double quoteShare = 0.28;
  static const List<(double, double)> accentTones = <(double, double)>[
    (0.95, 0.035),
    (0.86, 0.07),
    (0.535, 0.13),
    (0.30, 0.06),
  ];

  /// The reading themes offered (`palRead`): paper, ink, muted ink, and the
  /// chrome primary of that theme's tone.
  static const List<ReadingThemeId> themes = <ReadingThemeId>[
    ReadingThemeId.light,
    ReadingThemeId.sepia,
    ReadingThemeId.dark,
    ReadingThemeId.amoled,
  ];

  static CardPalette theme(ThemeFamily f, ReadingThemeId id) {
    final ReadingTheme t = ReadingTheme.of(f, id);
    final Tone tone = t.paper.computeLuminance() > 0.4 ? Tone.light : Tone.dark;
    return _legible(t.paper, t.ink, t.inkMuted, f.colors(tone).primary);
  }

  /// `palAcc(k)`: four tones of the seed's primary hue.
  static CardPalette accent(ThemeFamily f, int k) {
    final (double l0, double c0) = accentTones[k];
    final bool dark = l0 < 0.6;
    final double h = f.primaryHue;
    return _legible(
      Oklch(l0, c0, h).toColor(),
      (dark ? Oklch(0.97, 0.012, h) : Oklch(0.26, 0.06, h)).toColor(),
      (dark ? Oklch(0.86, 0.04, h) : Oklch(0.44, 0.07, h)).toColor(),
      (dark ? Oklch(0.88, 0.09, h) : Oklch(0.535, 0.13, h)).toColor(),
    );
  }

  /// `palCov(k)` from a cover's leading colour (HCT, so the tones keep their
  /// contrast whatever the hue): its own deep tone, the inverse, and a dark one.
  static CardPalette cover(int argb, int k) {
    final Hct seed = Hct.fromInt(argb);
    final double h = seed.hue, chroma = math.min(seed.chroma, 48);
    Color tone(double t, [double? c]) => Color(Hct.from(h, c ?? chroma, t).toInt());
    return switch (k) {
      0 => _legible(tone(40), tone(95, 12), tone(82), tone(82)),
      1 => _legible(tone(94, 10), tone(25), tone(45), tone(40)),
      _ => _legible(tone(18, 16), tone(92, 10), tone(75), tone(75)),
    };
  }

  /// A book without cover art: the typographic cover's own hue.
  static int coverSeed(String title) => CoverColors.at(coverIndexFor(title)).background.toARGB32();
}

/// What the card shows.
@immutable
class CardContent {
  const CardContent({
    required this.quote,
    required this.title,
    this.author,
    this.location,
    this.fingerprint,
    this.format,
  });

  final String quote;
  final String title;
  final String? author;

  /// "Ch. 1 · p. 3".
  final String? location;
  final String? fingerprint;
  final FormatModule? format;
}

/// The editor's choices.
@immutable
class CardStyle {
  const CardStyle({
    this.template = CardTemplate.classic,
    this.ratio = CardRatio.square,
    this.font = ReaderFont.literata,
    this.showTitle = true,
    this.showAuthor = true,
    this.showCover = false,
    this.showLocation = true,
    this.showMark = true,
  });

  final CardTemplate template;
  final CardRatio ratio;
  final ReaderFont font;
  final bool showTitle;
  final bool showAuthor;

  /// The thumbnail; the Cover template always shows it.
  final bool showCover;
  final bool showLocation;
  final bool showMark;

  CardStyle copyWith({
    CardTemplate? template,
    CardRatio? ratio,
    ReaderFont? font,
    bool? showTitle,
    bool? showAuthor,
    bool? showCover,
    bool? showLocation,
    bool? showMark,
  }) => CardStyle(
    template: template ?? this.template,
    ratio: ratio ?? this.ratio,
    font: font ?? this.font,
    showTitle: showTitle ?? this.showTitle,
    showAuthor: showAuthor ?? this.showAuthor,
    showCover: showCover ?? this.showCover,
    showLocation: showLocation ?? this.showLocation,
    showMark: showMark ?? this.showMark,
  );
}

/// The largest quote size that fits [box], searched in 2 px steps from the
/// ratio's maximum down to 30 (binary search over those steps); `fits` is
/// false when even 30 px doesn't, and the card then ends the quote with "…".
({double size, bool fits}) fitQuote(
  String quote,
  TextStyle style,
  Size box, {
  required double maxPx,
  double minPx = CardSpec.minPx,
}) {
  bool fitsAt(double px) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: quote,
        style: style.copyWith(fontSize: px),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: box.width);
    final bool ok = tp.height <= box.height && !tp.didExceedMaxLines;
    tp.dispose();
    return ok;
  }

  final int steps = ((maxPx - minPx) / CardSpec.stepPx).floor();
  if (fitsAt(maxPx)) return (size: maxPx, fits: true);
  if (!fitsAt(minPx)) return (size: minPx, fits: false);
  // Invariant: lo fits, hi doesn't (in steps above minPx).
  int lo = 0, hi = steps;
  while (hi - lo > 1) {
    final int mid = (lo + hi) ~/ 2;
    fitsAt(minPx + mid * CardSpec.stepPx) ? lo = mid : hi = mid;
  }
  return (size: minPx + lo * CardSpec.stepPx, fits: true);
}

/// The card at its export size (1080 wide), drawn in a box of any size by
/// the caller (`FittedBox`), so the preview is the export, scaled.
class ShareCard extends StatelessWidget {
  const ShareCard({required this.content, required this.style, required this.palette, this.onFit, super.key});

  final CardContent content;
  final CardStyle style;
  final CardPalette palette;

  /// The quote size chosen and whether the whole quote fit.
  final void Function(double size, bool fits)? onFit;

  @override
  Widget build(BuildContext context) {
    final CardTemplate t = style.template;
    const double pad = CardSpec.padding;
    final bool cover = t == CardTemplate.cover || style.showCover;
    final CardPalette p = palette;
    final TextStyle quoteStyle = TextStyle(
      fontFamily: style.font.family,
      fontWeight: t == CardTemplate.bold ? FontWeight.w600 : FontWeight.w400,
      fontVariations: <FontVariation>[FontVariation('wght', t == CardTemplate.bold ? 600 : 400)],
      fontStyle: t == CardTemplate.classic && style.font == ReaderFont.literata ? FontStyle.italic : FontStyle.normal,
      height: t == CardTemplate.bold ? 1.22 : 1.45,
      color: p.ink,
    );
    final bool centred = t == CardTemplate.classic;
    final List<Widget> meta = <Widget>[
      if (style.showTitle)
        Text(
          content.title,
          textAlign: centred ? TextAlign.center : TextAlign.start,
          style: UnfurlType.title.copyWith(fontSize: 32, height: 1.3, letterSpacing: 0, color: p.ink),
        ),
      if (style.showAuthor && content.author != null)
        Text(content.author!, style: UnfurlType.label.copyWith(fontSize: 30, height: 1.3, color: p.muted)),
      if (style.showLocation && content.location != null && content.location!.isNotEmpty)
        Text(content.location!, style: UnfurlType.monoLabel.copyWith(fontSize: 24, height: 1.3, color: p.muted)),
    ];
    return SizedBox.fromSize(
      size: style.ratio.size,
      child: ColoredBox(
        color: p.background,
        child: Stack(
          children: <Widget>[
            if (t == CardTemplate.bold)
              Positioned(
                top: pad * 0.3,
                left: pad * 0.85,
                child: Text(
                  '“',
                  style: TextStyle(
                    fontFamily: 'Literata',
                    fontSize: 300,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: p.accent,
                  ),
                ),
              ),
            if (t == CardTemplate.margin)
              Positioned(
                left: pad * 0.75,
                top: pad,
                bottom: pad,
                width: 8,
                child: ColoredBox(color: p.accent),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                t == CardTemplate.margin ? pad * 1.7 : pad,
                pad,
                pad,
                t == CardTemplate.bold ? pad * 1.3 : pad,
              ),
              child: Column(
                mainAxisAlignment: switch (t) {
                  CardTemplate.bold => MainAxisAlignment.end,
                  CardTemplate.cover => MainAxisAlignment.start,
                  _ => MainAxisAlignment.center,
                },
                crossAxisAlignment: centred ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                spacing: CardSpec.gap,
                children: <Widget>[
                  if (cover) _CardCover(content: content),
                  Flexible(
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints box) {
                        // Into 28% of the card first; a quote that can't fit
                        // there even at 30 px may use the free space, and only
                        // past that is it shortened.
                        ({double size, bool fits}) fit = fitQuote(
                          content.quote,
                          quoteStyle,
                          Size(box.maxWidth, math.min(box.maxHeight, style.ratio.height * CardSpec.quoteShare)),
                          maxPx: style.ratio.maxPx,
                        );
                        if (!fit.fits) {
                          fit = fitQuote(
                            content.quote,
                            quoteStyle,
                            Size(box.maxWidth, box.maxHeight),
                            maxPx: CardSpec.minPx,
                          );
                        }
                        if (onFit != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) => onFit!(fit.size, fit.fits));
                        }
                        // Bold tightens by 0.01em of the size it lands on.
                        final TextStyle s = quoteStyle.copyWith(
                          fontSize: fit.size,
                          letterSpacing: t == CardTemplate.bold ? -0.01 * fit.size : 0,
                        );
                        // At the minimum, as many lines as fit, then "…".
                        final int lines = math.max(1, (box.maxHeight / (fit.size * (s.height ?? 1.45))).floor());
                        return Text(
                          content.quote,
                          textAlign: centred ? TextAlign.center : TextAlign.start,
                          maxLines: fit.fits ? null : lines,
                          overflow: fit.fits ? TextOverflow.visible : TextOverflow.ellipsis,
                          style: s,
                        );
                      },
                    ),
                  ),
                  if (t == CardTemplate.classic) Container(width: 80, height: 4, color: p.accent),
                  if (meta.isNotEmpty)
                    Column(
                      crossAxisAlignment: centred ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                      spacing: 6,
                      children: meta,
                    ),
                ],
              ),
            ),
            if (style.showMark)
              Positioned(
                right: pad * 0.6,
                bottom: pad * 0.55,
                child: Row(
                  spacing: 10,
                  children: <Widget>[
                    const ClipOval(
                      child: CustomPaint(size: Size.square(40), painter: _MarkPainter()),
                    ),
                    Text('Unfurl', style: UnfurlType.titleMedium.copyWith(fontSize: 26, height: 1, color: p.muted)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardCover extends StatelessWidget {
  const _CardCover({required this.content});

  final CardContent content;

  @override
  Widget build(BuildContext context) {
    final File? art = Covers.fileFor(content.fingerprint);
    return Container(
      width: 150,
      height: 225,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
      child: art != null
          ? Image(image: ResizeImage(FileImage(art), width: 300), fit: BoxFit.cover)
          : CoverArt(
              title: content.title,
              author: content.author,
              fingerprint: null,
              format: content.format ?? Formats.epub,
              width: 150,
              height: 225,
            ),
    );
  }
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

/// WCAG contrast ratio between two colours.
double contrast(Color a, Color b) {
  final double la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
