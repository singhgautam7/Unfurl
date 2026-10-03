import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../formats/reading_document.dart';

/// One place in a document, understood by both Page and Reader mode, for the
/// reading position, bookmarks and annotations alike (data rule 3).
///
/// A text-quote anchor (the exact text plus ~32 characters either side)
/// survives a re-extraction; the hints (reader section/block/offset, PDF page
/// and character range) make the common case instant. Resolution tries the
/// hints, checks them against the quote, and falls back to a quote search.
@immutable
class Locator {
  const Locator({
    this.section,
    this.block,
    this.offset,
    this.length = 0,
    this.page,
    this.pageStart,
    this.exact = '',
    this.prefix = '',
    this.suffix = '',
    this.progress = 0,
  });

  factory Locator.fromJson(String json) {
    final Map<String, Object?> m = jsonDecode(json) as Map<String, Object?>;
    return Locator(
      section: m['s'] as int?,
      block: m['b'] as int?,
      offset: m['o'] as int?,
      length: (m['l'] as int?) ?? 0,
      page: m['p'] as int?,
      pageStart: m['ps'] as int?,
      exact: (m['x'] as String?) ?? '',
      prefix: (m['pre'] as String?) ?? '',
      suffix: (m['suf'] as String?) ?? '',
      progress: ((m['pr'] as num?) ?? 0).toDouble(),
    );
  }

  /// Anchored at [offset] in a reading document, covering [length] chars.
  factory Locator.inDocument(ReadingDocument doc, int section, int block, int offset, {int length = 0}) {
    final Block b = doc.sections[section].blocks[block];
    final int global = b.start + offset;
    final String text = doc.plainText;
    final int end = (global + length).clamp(0, text.length);
    final (int, int)? at = b.source?.locate(offset);
    return Locator(
      section: section,
      block: block,
      offset: offset,
      length: length,
      page: at?.$1,
      pageStart: at?.$2,
      exact: text.substring(global.clamp(0, text.length), end),
      prefix: text.substring((global - context).clamp(0, text.length), global.clamp(0, text.length)),
      suffix: text.substring(end, (end + context).clamp(0, text.length)),
      progress: doc.progressAt(section, block, offset),
    );
  }

  /// Anchored at [start] in a PDF page's own text.
  factory Locator.inPage(int page, String pageText, int start, {int length = 0, double progress = 0}) {
    final int s = start.clamp(0, pageText.length);
    final int e = (s + length).clamp(0, pageText.length);
    return Locator(
      page: page,
      pageStart: s,
      length: length,
      exact: pageText.substring(s, e),
      prefix: pageText.substring((s - context).clamp(0, s), s),
      suffix: pageText.substring(e, (e + context).clamp(e, pageText.length)),
      progress: progress,
    );
  }

  static const int context = 32;

  final int? section;
  final int? block;
  final int? offset;
  final int length;

  /// 1-based PDF page, DOCX page or slide.
  final int? page;

  /// Character index in that page's text.
  final int? pageStart;
  final String exact;
  final String prefix;
  final String suffix;

  /// 0..1, for display ("62%") and sorting; never used to resolve.
  final double progress;

  String toJson() => jsonEncode(<String, Object?>{
    if (section != null) 's': section,
    if (block != null) 'b': block,
    if (offset != null) 'o': offset,
    if (length != 0) 'l': length,
    if (page != null) 'p': page,
    if (pageStart != null) 'ps': pageStart,
    if (exact.isNotEmpty) 'x': exact,
    if (prefix.isNotEmpty) 'pre': prefix,
    if (suffix.isNotEmpty) 'suf': suffix,
    'pr': double.parse(progress.toStringAsFixed(5)),
  });

  /// Resolves to (section, block, offset) in [doc]: the hint when it still
  /// holds the quote, else the best quote match, else the page hint through
  /// the source map, else the progress.
  (int, int, int) resolveIn(ReadingDocument doc) {
    final int? s = section, b = block, o = offset;
    if (s != null && b != null && o != null && s < doc.sections.length && b < doc.sections[s].blocks.length) {
      final String text = doc.sections[s].blocks[b].text;
      if (exact.isEmpty || (o + exact.length <= text.length && text.substring(o, o + exact.length) == exact)) {
        return (s, b, o.clamp(0, text.length));
      }
    }
    final int? found = quoteSearch(doc.plainText);
    if (found != null) return doc.positionOfIndex(found);
    final int? p = page;
    if (p != null) {
      final (int, int, int)? mapped = fromPage(doc, p, pageStart ?? 0);
      if (mapped != null) return mapped;
    }
    return doc.positionAt(progress);
  }

  /// Resolves to (page, index) given each page's text (1-based pages).
  (int, int) resolveInPages(List<String> pageTexts) {
    final int? p = page, ps = pageStart;
    if (p != null && p >= 1 && p <= pageTexts.length && ps != null) {
      final String t = pageTexts[p - 1];
      if (exact.isEmpty || (ps + exact.length <= t.length && t.substring(ps, ps + exact.length) == exact)) {
        return (p, ps);
      }
      final int? near = Locator(exact: exact, prefix: prefix, suffix: suffix).quoteSearch(t);
      if (near != null) return (p, near);
    }
    if (exact.isNotEmpty) {
      for (int i = 0; i < pageTexts.length; i++) {
        final int? at = quoteSearch(pageTexts[i]);
        if (at != null) return (i + 1, at);
      }
    }
    return (p ?? (progress * pageTexts.length).floor().clamp(0, pageTexts.length - 1) + 1, 0);
  }

  /// Index of the quote in [text], preferring the occurrence whose
  /// surroundings match the stored prefix and suffix best. Whitespace is
  /// compared loosely, since extraction may rejoin lines differently.
  int? quoteSearch(String text) {
    if (exact.trim().isEmpty) return null;
    final String needle = exact.trim();
    int? best;
    int bestScore = -1;
    int from = 0;
    while (true) {
      final int at = text.indexOf(needle, from);
      if (at < 0) break;
      final int score =
          _common(text.substring((at - prefix.length).clamp(0, at), at), prefix, fromEnd: true) +
          _common(
            text.substring(at + needle.length, (at + needle.length + suffix.length).clamp(0, text.length)),
            suffix,
          );
      if (score > bestScore) {
        bestScore = score;
        best = at;
      }
      from = at + 1;
    }
    if (best == null && needle.length > 12) {
      // The text changed around the quote: try its middle third.
      final String core = needle.substring(needle.length ~/ 3, needle.length * 2 ~/ 3);
      final int at = text.indexOf(core);
      if (at >= 0) return (at - needle.length ~/ 3).clamp(0, text.length);
    }
    return best;
  }

  static int _common(String a, String b, {bool fromEnd = false}) {
    final String x = a.replaceAll(RegExp(r'\s+'), ' ');
    final String y = b.replaceAll(RegExp(r'\s+'), ' ');
    int n = 0;
    while (n < x.length && n < y.length) {
      final bool same = fromEnd ? x[x.length - 1 - n] == y[y.length - 1 - n] : x[n] == y[n];
      if (!same) break;
      n++;
    }
    return n;
  }

  /// The reader position for a PDF page character, through the source map.
  static (int, int, int)? fromPage(ReadingDocument doc, int page, int pageIndex) {
    (int, int, int)? before;
    for (int s = 0; s < doc.sections.length; s++) {
      for (int b = 0; b < doc.sections[s].blocks.length; b++) {
        final SourceRef? src = doc.sections[s].blocks[b].source;
        if (src == null) continue;
        if (src.page <= page && src.lastPage >= page) {
          final int? o = src.offsetOf(page, pageIndex);
          if (o != null) return (s, b, o);
          before ??= (s, b, 0);
        } else if (src.page > page) {
          return before ?? (s, b, 0);
        }
      }
    }
    return before;
  }

  Locator withProgress(double p) => Locator(
    section: section,
    block: block,
    offset: offset,
    length: length,
    page: page,
    pageStart: pageStart,
    exact: exact,
    prefix: prefix,
    suffix: suffix,
    progress: p,
  );
}
