import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';

/// One colour family as a card, as Mull's Theme page draws it: three swatches
/// (primary, its container, the raised surface), the name and the blurb.
class FamilyCard extends StatelessWidget {
  const FamilyCard({required this.family, required this.tone, required this.selected, required this.onTap, super.key});

  final ThemeFamily family;

  /// The tone the swatches show, so they match the app as it is now.
  final Tone tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UnfurlColors c = context.colors;
    final UnfurlColors f = family.colors(tone);
    return Semantics(
      button: true,
      selected: selected,
      label: '${family.name} theme',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: c.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.cardR,
          side: BorderSide(color: selected ? c.primary : c.outline, width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const RoundedRectangleBorder(borderRadius: Radii.cardR),
          child: Container(
            padding: const EdgeInsets.all(14),
            constraints: const BoxConstraints(minHeight: 116),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: Space.md,
              children: <Widget>[
                Row(
                  spacing: 6,
                  children: <Widget>[
                    ThemeDot(f.primary),
                    ThemeDot(f.primaryContainer),
                    ThemeDot(f.surfaceContainerHigh, border: c.outline),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(family.name, style: UnfurlType.titleMedium.copyWith(color: c.onSurface)),
                    Text(
                      family.hasAmoled ? '${family.blurb} · true black' : family.blurb,
                      style: UnfurlType.monoLabel.copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A colour swatch.
class ThemeDot extends StatelessWidget {
  const ThemeDot(this.color, {this.size = 34, this.border, super.key});

  final Color color;
  final double size;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: border == null ? null : Border.all(color: border!),
    ),
  );
}

/// Cards two to a row, each row as tall as its taller card (no fixed extent,
/// so nothing clips at large font sizes).
class TwoColumnGrid extends StatelessWidget {
  const TwoColumnGrid({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    spacing: Space.row,
    children: <Widget>[
      for (int i = 0; i < children.length; i += 2)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Space.row,
            children: <Widget>[
              Expanded(child: children[i]),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
            ],
          ),
        ),
    ],
  );
}
