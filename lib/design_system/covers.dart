import 'dart:io';

import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../core/library/enrich.dart';
import '../core/motion/motion.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/reading_theme.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import '../formats/format_registry.dart';
import 'app_icon.dart';

/// The reading serif, for covers and quotes.
const String kLiterata = 'Literata';

/// A stable category hue for a title, so a book keeps its cover colour.
int coverIndexFor(String key) =>
    key.codeUnits.fold<int>(7, (int h, int u) => (h * 31 + u) & 0x7fffffff) % CoverColors.hues.length;

/// A 3dp progress track: `surfaceContainerHigh` under `primary`.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({required this.value, this.height = 3, super.key});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    return Container(
      height: height,
      decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(height)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0, 1),
        child: Container(
          decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(height)),
        ),
      ),
    );
  }
}

/// The face of a book: its own cover art when there is one (EPUB art, a
/// PDF's first page), else a typographic cover in Mull's category hue. Every
/// image is decoded at the size it is drawn.
class CoverArt extends StatelessWidget {
  const CoverArt({
    required this.title,
    required this.fingerprint,
    required this.format,
    this.author,
    this.width = 96,
    this.height = 136,
    super.key,
  });

  final String title;
  final String? author;
  final String? fingerprint;
  final FormatModule format;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final bool small = width < 70;
    final BorderRadius radius = BorderRadius.circular(small ? 4 : Radii.cover);
    return ValueListenableBuilder<int>(
      valueListenable: Covers.changed,
      builder: (BuildContext context, int _, Widget? child) {
        final File? art = Covers.fileFor(fingerprint);
        final double dpr = MediaQuery.devicePixelRatioOf(context);
        if (art != null) {
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: c.outline, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image(
              image: ResizeImage(FileImage(art), width: (width * dpr).round()),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              // Art decoded after the first frame fades in over the
              // placeholder instead of popping.
              frameBuilder: (BuildContext context, Widget child, int? frame, bool sync) => sync
                  ? child
                  : Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        format == Formats.pdf ? _paper(c, radius, small) : _typographic(c, radius, small),
                        AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: Motion.of(context, Motion.reveal),
                          curve: Motion.decelerate,
                          child: child,
                        ),
                      ],
                    ),
              errorBuilder: (BuildContext context, Object e, StackTrace? s) => _typographic(c, radius, small),
            ),
          );
        }
        return format == Formats.pdf ? _paper(c, radius, small) : _typographic(c, radius, small);
      },
    );
  }

  /// A PDF waiting for its first page: a white page with the title set
  /// small, as the boards draw it.
  Widget _paper(UnfurlColors c, BorderRadius radius, bool small) {
    final ReadingTheme page = ReadingTheme.of(ThemeFamily.saffron, ReadingThemeId.light);
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 10, vertical: small ? 8 : 16),
      decoration: BoxDecoration(
        color: page.paper,
        borderRadius: radius,
        border: Border.all(color: c.outline),
      ),
      child: small
          ? Column(
              spacing: 3,
              children: <Widget>[
                Container(height: 2, width: width * 0.6, color: page.ink),
                Container(height: 2, width: width * 0.4, color: page.rule),
              ],
            )
          : Column(
              spacing: 5,
              children: <Widget>[
                Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kLiterata,
                    fontSize: 7.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: page.ink,
                  ),
                ),
                Container(height: 2, width: width * 0.5, color: page.rule),
                if (author != null)
                  Text(
                    author!,
                    maxLines: 1,
                    style: TextStyle(fontFamily: kLiterata, fontSize: 6, color: page.inkMuted),
                  ),
                const Spacer(),
                Container(height: 2, width: width * 0.34, color: page.rule),
              ],
            ),
    );
  }

  Widget _typographic(UnfurlColors c, BorderRadius radius, bool small) {
    final CoverColors cc = CoverColors.at(coverIndexFor(title));
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 10, vertical: small ? 7 : 14),
      decoration: BoxDecoration(color: cc.background, borderRadius: radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: small ? 4 : 8,
        children: <Widget>[
          Flexible(
            child: Text(
              title,
              maxLines: small ? 4 : 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kLiterata,
                fontSize: small ? 7 : (width < 90 ? 12 : 13),
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: cc.ink,
              ),
            ),
          ),
          if (!small) ...<Widget>[
            Container(width: 20, height: 1, color: cc.ink),
            if (author != null)
              Text(
                author!.toUpperCase(),
                maxLines: 2,
                style: UnfurlType.monoLabel.copyWith(fontSize: 7.5, letterSpacing: 0.45, height: 1.3, color: cc.ink),
              ),
          ],
        ],
      ),
    );
  }
}

/// A file Unfurl opens that is not a book: a typographic tile with the
/// format label large (board 2, A6 grid).
class FormatTile extends StatelessWidget {
  const FormatTile({
    required this.label,
    required this.icon,
    this.width = 96,
    this.height = 136,
    this.muted = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final double width;
  final double height;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final Widget tile = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: Space.md),
      decoration: muted
          ? null
          : BoxDecoration(
              color: c.surfaceContainerHigh,
              borderRadius: Radii.coverR,
              border: Border.all(color: c.outline),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          AppIcon(icon, size: 20, color: muted ? c.onSurfaceMuted : c.icon),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: UnfurlType.title.copyWith(
                fontSize: 24,
                height: 1,
                letterSpacing: -0.48,
                color: muted ? c.onSurfaceMuted : c.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
    // A file Unfurl can't open: a dashed outline (board 5, X4).
    return muted
        ? CustomPaint(
            painter: DashedOutline(color: c.outline, radius: Radii.cover),
            child: tile,
          )
        : tile;
  }
}

/// A 1dp dashed rounded outline.
class DashedOutline extends CustomPainter {
  const DashedOutline({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Path outline = Path()
      ..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.5), Radius.circular(radius)));
    for (final PathMetric m in outline.computeMetrics()) {
      for (double d = 0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), p);
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutline old) => old.color != color || old.radius != radius;
}

/// A tile in a grid of books: the cover, the progress, the state line and
/// where it lives. Long-press presses it in (scale 0.96, a primary ring).
class CoverTile extends StatefulWidget {
  const CoverTile({
    required this.cover,
    required this.progress,
    required this.finished,
    required this.onTap,
    this.onLongPress,
    this.meta,
    this.path,
    this.name,
    this.heroTag,
    this.muted = false,
    super.key,
  });

  final Widget cover;
  final double progress;
  final bool finished;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Overrides the state line ("PDF · 41%", "2.1 MB · Yesterday").
  final String? meta;
  final String? path;

  /// A file name under a format tile.
  final String? name;

  /// A file Unfurl can't open, or a hidden one: the name in `onSurfaceMuted`.
  final bool muted;

  /// Shared with the reader for the cover-to-reader transition.
  final Object? heroTag;

  @override
  State<CoverTile> createState() => _CoverTileState();
}

class _CoverTileState extends State<CoverTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final bool unread = !widget.finished && widget.progress <= 0;
    final String state =
        widget.meta ?? (widget.finished ? 'Finished' : (unread ? 'New' : '${(widget.progress * 100).round()}%'));
    Widget cover = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        widget.cover,
        if (widget.finished)
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
              child: AppIcon(AppIcons.check, size: 16, color: c.onPrimary),
            ),
          ),
      ],
    );
    if (widget.heroTag != null) cover = Hero(tag: widget.heroTag!, child: cover);
    return Semantics(
      button: true,
      label: '${widget.name ?? ''} $state',
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                setState(() => _pressed = false);
                widget.onLongPress!();
              },
        onLongPressDown: (_) => setState(() => _pressed = true),
        onLongPressCancel: () => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: <Widget>[
            AnimatedScale(
              scale: _pressed ? 0.96 : 1,
              duration: Motion.of(context, Motion.fast),
              curve: Motion.curveOf(context, Motion.spring),
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.fast),
                foregroundDecoration: BoxDecoration(
                  borderRadius: Radii.coverR,
                  border: Border.all(color: _pressed ? c.primary : c.primary.withValues(alpha: 0), width: 3),
                ),
                child: cover,
              ),
            ),
            if (widget.name != null)
              Text(
                widget.name!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: UnfurlType.tableCell.copyWith(
                  fontWeight: widget.muted ? FontWeight.w500 : FontWeight.w600,
                  fontVariations: <FontVariation>[FontVariation('wght', widget.muted ? 500 : 600)],
                  color: widget.muted ? c.onSurfaceMuted : c.onSurface,
                ),
              ),
            if (widget.name == null) ProgressTrack(value: widget.finished ? 1 : widget.progress),
            Text(
              state,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: UnfurlType.monoLabel.copyWith(
                color: widget.meta == null && unread ? c.accent : c.onSurfaceVariant,
              ),
            ),
            if (widget.path != null)
              Text(
                widget.path!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: UnfurlType.monoLabel.copyWith(fontSize: 10.5, color: c.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}
