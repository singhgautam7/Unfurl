import 'package:flutter/material.dart';
import 'package:unfurl/core/theme/palette.dart';
import 'package:unfurl/core/theme/reading_theme.dart';
import 'package:unfurl/features/reader/engine/layout.dart';
import 'package:unfurl/features/reader/engine/reader_style.dart';
import 'package:unfurl/features/reader/engine/reader_view.dart';
import 'package:unfurl/features/reader/reading_prefs.dart';
import 'package:unfurl/formats/reading_document.dart';

/// A document of [n] paragraphs, each long enough for several lines.
ReadingDocument paragraphs([int n = 60]) => ReadingDocument(
  title: 't',
  sections: <Section>[
    Section(
      title: '',
      blocks: <Block>[
        for (int i = 0; i < n; i++)
          Block(
            kind: BlockKind.paragraph,
            runs: <Inline>[Inline('Paragraph $i. ${'The quick brown fox jumps over the lazy dog. ' * 6}')],
          ),
      ],
    ),
  ],
);

ReaderStyle styleOf({double size = 18}) => ReaderStyle.of(
  ReadingPrefs(pageTurn: PageTurn.none, size: size),
  ReadingTheme.of(ThemeFamily.saffron, ReadingThemeId.light),
  book: true,
);

/// A [ReaderView] filling the test window, reporting selections to [onSelection].
Widget readerView(
  ReaderController c, {
  ReaderLayout layout = ReaderLayout.paged,
  ReaderStyle? style,
  ReaderLayoutCache? cache,
  void Function(List<Rect> rects)? onSelection,
}) => MaterialApp(
  home: ReaderView(
    controller: c,
    style: style ?? styleOf(),
    layoutMode: layout,
    pageTurn: PageTurn.none,
    onCentreTap: () {},
    onLink: (_) {},
    onMarkTap: (_, _) {},
    onSelection: onSelection ?? (_) {},
    onFontStep: (_) {},
    layoutCache: cache,
  ),
);
