# Part L bugs

Both reproduced on the Pixel_9_Pro emulator (API 36) with the baseline profile build from `main` (472937d), then fixed on `feature/app-polish`. The resume files were pushed from Downloads and opened through a MediaStore content URI. Screenshots of them are in `screenshots/private/` (gitignored; personal). No text from them appears here.

Unfurl has no WebView, docx-preview, mammoth.js or foliate-js (removed by design; see `CLAUDE.md`). The leads that name them map to Unfurl's own Dart pipeline: `lib/formats/office/docx.dart` (both modes), `lib/features/office/office_screens.dart` (Page view) and `lib/features/reader/engine/layout.dart` (Reader mode pagination).

## L1. DOCX: blank pages and irregular page breaks

### Repro
1. Open the resume DOCX (one section, Letter, 936-twip margins, 61 paragraphs, 28 with `<w:pageBreakBefore w:val="0"/>`, 5 empty).
2. Page view: the header reads "p. 1 of 29". The PDF of the same resume has 2 pages. From page 2 on, each page holds one bullet and is otherwise empty. Every bullet is also underlined.
3. Reader mode: the bold "EDUCATION" label sits alone at the foot of a page, and the last page holds a single line.

### Leads
| Lead | Verdict |
|---|---|
| 1. The presence of `w:pageBreakBefore` is read as on, ignoring `w:val="0"` | **Confirmed.** `docx.dart:151` was `_child(ppr, 'pageBreakBefore') != null`. The same mistake read `<w:u w:val="none"/>` as underlined (`docx.dart:162`). `keepNext` and `keepLines` were never read. |
| 2. Reader mode splits pages or chapters at paragraph flags or empty paragraphs | Ruled out. `Docx.toReading` ignores the flags, skips empty paragraphs, and starts a section only at Heading 1 (the resume has no heading styles: one section). |
| 3. Empty paragraphs become blank pages, or the page maths ignores `pgSz` / `pgMar` | Partly. Empty paragraphs could fill a page of their own after a real break, and only the left margin was read and used for all four sides. Neither caused the resume's 29 pages. Fixed anyway. |
| 4. docx-preview options force breaks | Not applicable (no docx-preview). Unfurl's own Page view paginator honoured `pageBreakBefore` exactly as parsed, so lead 1 was the cause. |
| Page view, found after the first fix (29 pages became 3, with a line clipped at page 1's foot) | **Confirmed, two more causes.** (a) Every paragraph was drawn at a fixed `height: 1.5`, while the document asks for single spacing (`w:spacing w:line="240" w:lineRule="auto"`), so Page view text was about 30% taller than Word's. (b) An empty paragraph drawn with `Text.rich` took its line height from the default 14 px style, while `_measure` used the paragraph's own size, so every empty paragraph drew taller than it measured and pushed the page's last line under the page number. |
| Reader mode, found in repro | **Confirmed.** The reader engine kept only true heading blocks with the text below them. A short all-bold line, the way Word and Google Docs files without heading styles label a section, could be left at a page foot. That left an almost empty last page. |

### Root cause
OOXML on/off properties (ST_OnOff) were read by presence, not value. Google Docs writes `pageBreakBefore`, `keepNext` and `keepLines` with `w:val="0"` on most paragraphs, so every such paragraph started a new page in Page view. In Reader mode, pagination had no keep-with-next rule for bold label lines.

### Fix
- `lib/formats/office/ooxml.dart` (new): one shared reader for OOXML properties: `ooxmlOn` (ST_OnOff: bare, `1`, `true`, `on` are on; `0`, `false`, `off` are off; absent inherits) and `ooxmlUnderline` (`none` is off). `docx.dart` uses it for every flag (bold, italic, underline, `pageBreakBefore`).
- `lib/formats/office/docx.dart`:
  - `pageBreakBefore` is read by value and inherited from the paragraph style through `basedOn`.
  - A `<w:br w:type="page"/>` inside a paragraph splits it, so the text after the break starts the next page. Before, it was dropped unless the break came first.
  - A section break (`sectPr` in a paragraph, not `continuous`) starts the next page.
  - `w:lastRenderedPageBreak` is ignored on purpose: it is a cache, not a break.
  - All four margins are read (`Docx.margins`).
  - Line spacing is read (`DocxLine`): `w:spacing w:line` and `w:lineRule` from the paragraph, then its style chain, then `w:pPrDefault`, else single. Auto is a multiple of Word's single line (1.15 of the font size); exact and atLeast are points.
  - `docxPages()` is the pure Page view paginator. A page breaks only on overflow or an on break, and a page holding only empty paragraphs is never kept.
- `lib/features/office/office_screens.dart`:
  - Page view uses `docxPages`, the per-side margins and the document's line spacing.
  - Each paragraph is drawn with its span's own style as the paragraph style, so what is drawn matches what `_measure` measured, empty paragraphs included.
- `lib/features/reader/engine/layout.dart`:
  - A heading keeps with the next block: it moves to the next page unless two of that block's lines fit under it.
  - So does a label line, which is one of:
    - a short line all in bold, such as "EDUCATION";
    - a short line that starts in bold and introduces a list (a role line with its bullets).
  - Whitespace-only blocks never open a page.

### Tests
- `test/formats/docx_breaks_test.dart` builds synthetic DOCX files:
  - ST_OnOff table.
  - Off-valued flags give no extra pages in Page view.
  - Off-valued flags give no extra pages or chapters in Reader mode (same page count as without the flags).
  - One page break run gives exactly one break, with the text after it on page 2.
  - `pageBreakBefore` on (bare, `1`, from a style) breaks, and a line break does not.
  - Empty paragraphs never make a blank page.
  - Section break versus continuous.
  - Per-side margins.
- `test/reader/chapter_end_test.dart`: a bold label is never left at a page foot at sizes 16 to 32. This test fails without the fix and passes with it.
- `test/formats/docx_breaks_test.dart`: line spacing from the paragraph, style and default; a section break before a table.
- `test/reader/chapter_end_test.dart`: a role line that starts bold and introduces a list is never left at a page foot. It fails without the rule.
- Emulator, before and after (`screenshots/private/`):
  - Page view went from 29 pages to 3, and page 1 now ends where the PDF's page 1 does (at the third role heading).
  - Page 3 holds only the last section. Two causes: Unfurl draws in its own sans, not Arial, and the only PDF in Downloads is a different variant of the resume (its title line and wording differ). So an exact page count match cannot be checked.
  - Reader mode: no label is stranded, and no near-empty last page remains; the last page reads "End of section".

## L2. Reader mode: the chapter end is wrong most of the time

### What "wrong" meant (reproduced)
- The footer's "N min left in chapter" was measured from the top of the page with a 30-word cut-off. On a chapter's last page it read "1 min left" or more, not "End of chapter". On the resume, the page before the last read "1 min left in section".
- Each page's footer used the controller's current position, not its own. The pages built ahead of the reader (neighbours in the page view, the second page of a spread) carried the current page's label. So the end-of-chapter label appeared on the wrong page.
- "Chapter" meant a spine file. An EPUB file holding several TOC chapters had one "end" at the file's end. A chapter spread over two files ended at the first file's end. Markdown, HTML and TXT are one section, so "end of section" appeared only on the book's last page, and "Chapter X of Y", the scrubber label, the running head and the sleep timer's "end of chapter" all used files.
- A TOC chapter that starts mid file began mid page, under the previous chapter's last lines.
- A whitespace-only paragraph that did not fit on a page went alone onto a new page: a blank last page at the chapter's end (EPUB files often end with `<p>&nbsp;</p>`).

### Leads
| Lead | Verdict |
|---|---|
| 1. Chapter means spine item, not TOC entry | **Confirmed** (EPUB sections are spine files, `epub.dart:118-143`; Markdown and HTML are one section). |
| 2. Page count measured before layout settles (fonts, images, prefs) | Ruled out. Fonts are bundled and registered before the first frame. Image sizes are read before layout (`ImageSizes.of`). The layout is rebuilt on every style or size change (`ReaderLayoutCache` is keyed by style and page size). |
| 3. Column rounding adds a blank page or clips lines | Ruled out. Pagination is line based with a 0.5 px tolerance. Spreads lay out per column at the same width. A layout with a fractional width showed no blank or clipped page in the tests. |
| 4. Trailing empty content pushes a blank page | **Confirmed**, in the engine: a whitespace-only block was carried to a new page when it did not fit. |
| 5. Made-up chapters in reflowed formats (false breaks from L1) | Partly. DOCX made no false chapters (Heading 1 only), but L1's false page breaks made Page view look chaptered. PDF reflow sections come from detected headings and stay the chapters when there is no TOC. |
| 6. Locator and progress maths uses a stale or rounded location | **Confirmed.** The end test used the page's first position and a word threshold, and the footer used the controller's position (stale for pages built ahead). |

### Root cause
The reader had no notion of a chapter apart from a section (a spine file or a whole file). The footer judged "end of chapter" from the wrong position, the top of the current page, by a 30-word threshold.

### Fix (shared engine, all formats)
- `lib/formats/reading_document.dart`: `ReadingDocument.chapters`, built once.
  - They come from the TOC entries at the shallowest level that has two or more entries.
  - A lone `# Title` above `##` chapters belongs to the first chapter.
  - Text before the first entry is chapter 0 unless it is only headings.
  - Without a TOC (TXT, DOCX by Heading 1, reflowed PDF), each section is a chapter.
  - Helpers: `chapterAt(global)` (binary search), `chapterEnd(i)`, `endsChapter(first, last)` (exact: no words left between the page's last position and the next chapter), and `chapterBlocks`.
- `lib/features/reader/engine/layout.dart`: a chapter that starts inside a section starts a new page, unless the page so far holds only headings (a title). Headings keep with the next block, and whitespace never opens a page.
- `lib/features/reader/engine/reader_view.dart`: the footer callback gets the spread's own first and last positions.
- `lib/features/reader/reader_scaffold.dart`: chapters now drive the following.
  - The footer reads "End of chapter" exactly on the page holding the chapter's last words. Otherwise "N min left" counts from the page's top to the chapter's end, at least 1.
  - The running head shows the chapter title.
  - "Chapter X of Y", the scrubber label and the book info count use chapters.
  - The sleep timer's "end of chapter" uses chapters.
- Positions: `Locator` and the document model (sections, blocks, offsets) are unchanged, so saved positions and highlights resolve to the same place. Only pagination moved. DOCX paragraph indices change only for files with a page break run inside a paragraph, and Locators resolve by text quote first.

### Tests
`test/reader/chapter_end_test.dart` covers these cases:
- One spine file with three TOC chapters.
- One chapter over two files.
- Markdown with a title and `##` chapters.
- Plain text with one chapter.
- Sections without a TOC (the PDF reflow and DOCX shape).

For each case, every page:
- is non-blank;
- never crosses a chapter;
- has exactly one "End of chapter" page per chapter, which is that chapter's last page;
- leads into a next chapter whose first page opens with its heading block;
- never ends on a heading at its foot.

The same checks run after font size changes (18, 28, 36) and a rotation (360x600 to 600x340). Saved Locators resolve to the same (section, block, offset), and the page found for them contains them.

A PDF reflow test with a real PDF needs `PDFIUM_PATH` (host PDFium) and was not run. The no-TOC section case covers its chapter shape.
