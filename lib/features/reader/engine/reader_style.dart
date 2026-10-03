import 'package:flutter/material.dart';

import '../../../core/theme/reading_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../formats/reading_document.dart';
import '../reading_prefs.dart';

/// Everything that decides how a page looks: the reading theme's colours and
/// the reader's typography. Built once per change; layouts key off it.
@immutable
class ReaderStyle {
  const ReaderStyle({
    required this.theme,
    required this.font,
    required this.size,
    required this.lineHeight,
    required this.margin,
    required this.justify,
    required this.hyphenate,
    required this.bookParagraphs,
    required this.mono,
  });

  factory ReaderStyle.of(ReadingPrefs prefs, ReadingTheme theme, {required bool book, bool mono = false}) =>
      ReaderStyle(
        theme: theme,
        font: prefs.font,
        size: prefs.size,
        lineHeight: prefs.lineHeight,
        margin: prefs.margin,
        justify: prefs.justify,
        hyphenate: prefs.hyphenate,
        bookParagraphs: book,
        mono: mono,
      );

  final ReadingTheme theme;
  final ReaderFont font;
  final double size;
  final double lineHeight;
  final double margin;
  final bool justify;
  final bool hyphenate;

  /// Books set paragraphs with a 1.4em first-line indent and no gap;
  /// documents (Markdown, DOCX) with a gap and no indent.
  final bool bookParagraphs;

  /// Plain text that looks like code: everything in mono.
  final bool mono;

  String get _family => mono ? UnfurlType.mono : font.family;

  TextStyle get body => TextStyle(
    fontFamily: _family,
    fontSize: mono ? size * 0.82 : size,
    height: lineHeight,
    color: theme.ink,
    fontVariations: const <FontVariation>[FontVariation('wght', 400)],
    fontFeatures: const <FontFeature>[FontFeature.enable('kern')],
  );

  /// The heading for a block: chapter labels (all caps, level 1 from a
  /// PDF) in the 13/600 tracked label; h1 28, h2 19, h3 and below the body
  /// size, all in the house sans; level 6 is the mono eyebrow.
  TextStyle heading(Block b) {
    final bool label = b.level == 1 && b.text == b.text.toUpperCase() && b.text.length > 12;
    if (b.level >= 6) {
      return TextStyle(
        fontFamily: UnfurlType.mono,
        fontSize: 11,
        height: 1.4,
        color: theme.inkMuted,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      );
    }
    if (label) {
      return TextStyle(
        fontFamily: UnfurlType.sans,
        fontSize: 13,
        height: 1.4,
        letterSpacing: 13 * 0.08,
        color: theme.inkMuted,
        fontWeight: FontWeight.w600,
        fontVariations: const <FontVariation>[FontVariation('wght', 600)],
      );
    }
    final double s = switch (b.level) {
      1 => size * 1.55,
      2 => size * 1.06,
      _ => size * 0.95,
    };
    return TextStyle(
      fontFamily: UnfurlType.sans,
      fontSize: s,
      height: b.level == 1 ? 1.15 : 1.3,
      letterSpacing: b.level == 1 ? -0.022 * s : 0,
      color: theme.ink,
      fontWeight: FontWeight.w600,
      fontVariations: const <FontVariation>[FontVariation('wght', 600)],
    );
  }

  TextStyle styleFor(Block b) => switch (b.kind) {
    BlockKind.heading => heading(b),
    BlockKind.quote => body.copyWith(fontStyle: FontStyle.italic, color: theme.inkMuted),
    BlockKind.code => TextStyle(fontFamily: UnfurlType.mono, fontSize: size * 0.72, height: 1.5, color: theme.ink),
    BlockKind.caption => body.copyWith(
      fontStyle: FontStyle.italic,
      fontSize: size * 0.8,
      color: theme.inkMuted,
      height: 1.4,
    ),
    BlockKind.table => TextStyle(fontFamily: UnfurlType.sans, fontSize: size * 0.72, height: 1.35, color: theme.ink),
    _ => body,
  };

  TextAlign alignFor(Block b) => switch (b.kind) {
    BlockKind.heading || BlockKind.code || BlockKind.table || BlockKind.listItem => TextAlign.start,
    BlockKind.caption => TextAlign.center,
    _ => justify && !mono ? TextAlign.justify : TextAlign.start,
  };

  /// Space above a block, given the one before it.
  double spaceBefore(Block b, Block? prev) {
    if (prev == null) return 0;
    switch (b.kind) {
      case BlockKind.heading:
        return b.level >= 6 ? size * 0.9 : size * (b.level == 1 ? 1.4 : 1.1);
      case BlockKind.paragraph:
        if (prev.kind == BlockKind.heading) return size * (prev.level >= 6 ? 0.25 : 0.6);
        return bookParagraphs && prev.kind == BlockKind.paragraph ? 0 : size * 0.6;
      case BlockKind.listItem:
        return prev.kind == BlockKind.listItem ? size * 0.3 : size * 0.6;
      case BlockKind.image || BlockKind.table || BlockKind.code || BlockKind.quote || BlockKind.rule:
        return size * 0.8;
      case BlockKind.caption:
        return size * 0.4;
    }
  }

  /// First-line indent for book paragraphs after a paragraph.
  double indentFor(Block b, Block? prev) =>
      bookParagraphs && b.kind == BlockKind.paragraph && prev?.kind == BlockKind.paragraph ? size * 1.4 : 0;

  /// Left inset for quotes and list items.
  double insetFor(Block b) => switch (b.kind) {
    BlockKind.quote => 17,
    BlockKind.listItem => size * 1.4 * b.level.clamp(1, 4),
    BlockKind.code => 12,
    _ => 0,
  };

  @override
  bool operator ==(Object other) =>
      other is ReaderStyle &&
      other.theme.id == theme.id &&
      other.theme.handle == theme.handle &&
      other.font == font &&
      other.size == size &&
      other.lineHeight == lineHeight &&
      other.margin == margin &&
      other.justify == justify &&
      other.hyphenate == hyphenate &&
      other.bookParagraphs == bookParagraphs &&
      other.mono == mono;

  @override
  int get hashCode =>
      Object.hash(theme.id, theme.handle, font, size, lineHeight, margin, justify, hyphenate, bookParagraphs, mono);
}

/// Inserts soft hyphens at likely syllable breaks in long words, so
/// justified lines do not open rivers. Conservative: common suffixes and
/// prefixes, and vowel-consonant-consonant-vowel splits, never within the
/// first or last three letters.
abstract final class Hyphenator {
  static const String shy = '­';
  static final RegExp _word = RegExp(r"[A-Za-z]{7,}");
  static const List<String> _suffixes = <String>[
    'tion',
    'sion',
    'ment',
    'ness',
    'able',
    'ible',
    'ity',
    'ous',
    'ive',
    'ing',
    'ful',
    'less',
    'ship',
    'ence',
    'ance',
    'ally',
    'ious',
  ];
  static const List<String> _prefixes = <String>[
    'under',
    'inter',
    'over',
    'trans',
    'super',
    'counter',
    'pre',
    'dis',
    'mis',
    'non',
    'un',
    're',
    'in',
    'con',
    'com',
  ];

  /// Positions (in [word]) after which a break is allowed.
  static List<int> points(String word) {
    final String w = word.toLowerCase();
    final Set<int> out = <int>{};
    for (final String s in _suffixes) {
      if (w.endsWith(s) && w.length - s.length >= 4) out.add(w.length - s.length);
    }
    for (final String p in _prefixes) {
      if (w.startsWith(p) && w.length - p.length >= 5) {
        out.add(p.length);
        break;
      }
    }
    const String vowels = 'aeiouy';
    for (int i = 1; i + 2 < w.length; i++) {
      final bool v0 = vowels.contains(w[i - 1]),
          c1 = !vowels.contains(w[i]),
          c2 = !vowels.contains(w[i + 1]),
          v3 = vowels.contains(w[i + 2]);
      if (v0 && c1 && c2 && v3) out.add(i + 1);
    }
    return out.where((int i) => i >= 3 && i <= w.length - 3).toList()..sort();
  }

  /// The text with soft hyphens, and for each original index its index in
  /// the result (length + 1 entries).
  static (String, List<int>) apply(String text) {
    final StringBuffer out = StringBuffer();
    final List<int> map = List<int>.filled(text.length + 1, 0);
    int at = 0, added = 0;
    for (final RegExpMatch m in _word.allMatches(text)) {
      for (int i = at; i < m.start; i++) {
        map[i] = i + added;
        out.write(text[i]);
      }
      final String word = m[0]!;
      final Set<int> breaks = points(word).toSet();
      for (int k = 0; k < word.length; k++) {
        if (breaks.contains(k)) {
          out.write(shy);
          added++;
        }
        map[m.start + k] = m.start + k + added;
        out.write(word[k]);
      }
      at = m.end;
    }
    for (int i = at; i < text.length; i++) {
      map[i] = i + added;
      out.write(text[i]);
    }
    map[text.length] = text.length + added;
    return (out.toString(), map);
  }
}
