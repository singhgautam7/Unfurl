# v3 decisions

Decisions taken while building v3 without stopping for approval. Each says what the prompt, `CLAUDE.md`
or the spec left open (or where they disagreed), what was chosen and why. Items marked **Look at this**
are the ones worth a second opinion.

## Formats

1. **Look at this. Kindle and FB2 are parsed in Dart, not by foliate-js.** The v3 prompt says foliate-js is
   "already bundled for EPUB". It isn't: `CLAUDE.md` records that the WebView plan (foliate-js,
   docx-preview, SheetJS) was dropped, and every format is parsed in Dart into one `ReadingDocument`.
   Bringing a WebView back for Kindle files would split the reader in two (selection, highlights, read
   aloud, motion) and needs a network-capable engine. So MOBI, PRC, AZW, AZW3/KF8, FB2, FBZ and
   HTML/XHTML become `ReadingDocument`s like EPUB and get every Reader feature for free. The MOBI/KF8
   reader (`lib/formats/kindle/mobi.dart`) follows foliate-js's `mobi.js` (MIT, John Factotum): PalmDOC
   and HUFF/CDIC decompression, EXTH metadata, KF8 skeleton/fragment reassembly, `kindle:embed` and
   `kindle:pos` links. Credited on the Licences screen.
2. **Spreads come from the reader engine**, which already lays out two columns from 840dp, not from
   foliate-js (same reason).
3. **Comic archives are read in Kotlin**, as the prompt asks, page by page through the detached
   descriptor (no `/proc/self/fd` reopen):
   - zip and tar: Apache Commons Compress 1.28.0 (Apache-2.0); 7z: Commons Compress plus XZ for Java
     1.10 (0BSD / public domain);
   - rar: junrar 7.5.5 (UnRAR licence: free use for extraction; forbids writing a RAR compressor, which
     Unfurl never does). junrar reads RAR 1.5 to 4.x only; **RAR5 comics show the "unsupported
     variant" state** (no permissively licensed Java RAR5 decoder exists; libarchive would mean
     shipping native code).
   Commons Compress depends on commons-io, commons-lang3 and commons-codec (all Apache-2.0); R8 strips
   what isn't used.
4. **Not supported in v3:** DjVu (only GPL decoders: DjVuLibre), CHM (no permissive Dart or Java
   decoder worth shipping), KFX (Amazon's container; DRMION files show the DRM state, plain KFX the
   unsupported state), Topaz/AZW1 (unsupported state, per spec).
5. **DRM detection**, never removal: EPUB `META-INF/encryption.xml` with any algorithm other than the
   two font-obfuscation ones (IDPF and Adobe), or `rights.xml` / `license.lcpl` → protected; MOBI/AZW
   with the PalmDOC encryption field non-zero → protected; KFX DRMION magic → protected.
6. **Magic bytes decide** for `.prc`, `.azw`, `.azw3`, `.mobi` (BOOKMOBI vs Topaz vs KFX) and for
   comics whose archive type doesn't match the extension (a `.cbr` that is really a zip opens as zip).

## Tracking and Insights

7. **Idle threshold.** The spec says 120 s; the prompt asks for an adaptive threshold (3x the
   document's median time per page or screen, at least 60 s, at most 5 min). Chosen: adaptive once a
   document has a median, and the spec's 120 s before it has one.

## Comfort

8. **Read aloud has no live volume control** (Android `TextToSpeech` takes volume per utterance), so the
   sleep timer's 10 s fade lowers the volume of each sentence spoken in the last 10 s and then pauses.

## Layout and screens

9. **More tab.** The v3 More frames draw Insights above a short "Settings" list. The changelog says
   only that the Insights card "sits at the top of More, above Settings". Chosen: the Insights section
   is added on top and v2's groups stay (Privacy, Permissions, Licences, Mull card), so nothing that
   existed is lost. Logged in `docs/design-gaps.md`.
10. **Settings › Controls** is a new page (volume buttons, invert). The v2 "Volume keys turn pages"
    row moves there from Settings › Reader so the switch lives in one place. Tap zones and swipe rows
    in the frame describe controls Unfurl doesn't have; they aren't added (gap).

## Data

11. **One schema bump for all of v3 (2 → 3)**: `entries.issue` and `documents.issue` (comic issue or
    volume), and `reading_sessions`, `daily_stats`, `book_stats`, `book_days` for tracking. Phases A and C
    share it, so a user upgrading from v2 runs one tested migration. DRM and unsupported variants reuse
    `entries.enriched` (-2 protected, -3 variant), so no column was needed. The migration also clears
    the device row's MediaStore generation, so "Find books across this device" looks again for the new
    formats.
12. **"Open with" for `application/octet-stream`** (VIEW only): file managers often send Kindle, FB2 and
    comic files as a generic stream. The extension then decides; anything else gets the existing
    "can't open" sheet. The system file picker also allows the generic type for the same reason.
13. **Device testing on the owner's phone (OnePlus CPH2723, Android 16)**, which had a release build with
    real data. The profile build is installed over it with `--split-per-abi` (same version code, same
    debug key), so the 2 → 3 migration ran on real data after passing the migration tests. Fixtures
    are pushed to the app's own external files directory (`Android/data/com.grs.unfurl/files/fx`), which
    uninstalling removes, and opened with explicit intents.
14. **Comic page order is decided in Dart** (natural sort of entry names), so it is unit-tested; Kotlin
    returns names in archive order and serves pages by name.
15. **A damaged zip** (no central directory, a cut download) is salvaged by walking its local headers;
    readable pages are copied to the app's cache for that session and deleted on close. Other damaged
    archive types show the damaged state without salvage.

## Comics viewer

16. **Decoding goes through Flutter's image cache**: encoded page bytes cross the channel into a 48 MB
    LRU; `ResizeImage` decodes each page at the size it is drawn (device pixels, never upscaled), on
    the engine's IO thread. The image cache is sized to a quarter of `ActivityManager.memoryClass`
    (64 to 256 MB). Prefetches (±2) are cancellable on both sides: the Kotlin queue serves the newest
    request first and skips prefetches made before the last `comicCancel`.
17. **Thumbnails** are 102 px PNGs in the cache directory, per fingerprint, for the last 40 comics.

## Tracking

18. **Idle cut-off point.** When the idle threshold passes, reading time stops a third of the threshold
    after the last activity (about one median page), not at the last touch (which would drop the page
    being read) nor when the idle is noticed (which would add the idle).
19. **A session ends after 10 minutes paused** (idle or away); the next touch starts a new one. Rotation,
    resize and the notification shade don't pause; `paused`/`hidden` (background, screen off) do.
    Read aloud keeps counting as listening in the background.
20. **Forward-only progress.** Reader mode counts words past the furthest point reached in the session;
    contents, links, search, the scrubber and the back chip are jumps, and anything faster than 1,500 wpm
    is treated as one. Page view and comics count unique pages shown for at least 2 s.
21. **Time per book is reading plus listening** (both are time with the book: book insights, most-read,
    the 30-day chart). The overview, charts and heatmap are reading time; listening has its own module.
    Comics count in a book's pages per hour but not in the global "Page view" speed, which they'd skew.
22. **Time-left estimates** use this book's speed once it has 10 minutes in Reader mode, else the reader's
    own 30-day speed (30 minutes needed, as the spec's speed tile), else v2's saved pace, else 230 wpm.
    v2's per-document pace columns are read as a fallback and no longer written.
23. **Sessions belong to the visible mode**: switching Page ⇄ Reader closes one session and opens the
    next (each mode's speed stays clean); a view only reports while it owns the session.

## Insights

24. **Schema 4.** "Estimated time left" needs a book's remaining words, which nothing stored. Schema 3 had
    already reached the test phone, so the word counts are a real 3 → 4 step (`book_stats.total_words`,
    `words_left`, tested), written when Reader mode closes (counted in an isolate). From v2, users run
    2 → 4 in one go.
25. **Charts are `CustomPainter`s** (bars, heatmap) and a flex row (formats); no chart package.
26. **Insights load from aggregates in one pass**: ≤ 371 `daily_stats` rows, one SUM over them for all
    time, the top 5 of `book_stats`, the finished dates. The chart toggle and its ‹ › steps have their own
    providers (a step past the loaded year queries ≤ 366 rows for that range), so a toggle rebuilds only
    the chart. Book insights is five keyed queries run together.
27. **Speed is the median of daily speeds** over 30 days (the spec says "median"), shown once a mode has
    30 minutes; days under a minute in a mode are left out.
28. **"Mostly 21:00–23:00"** is the busiest hour of the last 90 days and the busier of its neighbours.

## Highlight cards

29. **`material_color_utilities` 0.13.0 as a direct dependency.** It was already in the graph (Flutter and
    `dynamic_color`); the cover palette imports it to quantise a 64 px cover (Celebi, in an isolate) and
    score the result. Cached per fingerprint for the session.
30. **The preview is the export.** The card is laid out at 1080 wide inside a `FittedBox`; export is that
    `RepaintBoundary` at pixel ratio 1 (1080 × 1080 / 1350 / 1920), encoded to PNG by the engine off the UI
    isolate.
31. **Contrast is enforced, not hoped for.** Quote and title ink must reach 4.5:1 and the muted line 3:1
    on every background. The spec's accent tone at L 0.535 misses 4.5:1 on cyan hues (4.3:1 in the Mull
    family), so a palette's ink is nudged in OKLCH lightness until it passes. Tested for all 17 families,
    the four reading themes, four accent tones and six cover hues.
32. **Cover palette from HCT tones** (40/95, 94/25, 18/92) of the cover's leading colour, so each of the three
    cover backgrounds keeps its contrast whatever the hue. A book without art uses its typographic cover hue.
33. **Save to Photos** inserts a new image in `Pictures/Unfurl` through MediaStore (Android 10+, no
    permission). It writes a new file the reader asked for and never touches an existing one (data rule 1
    is about the reader's files). Before Android 10 it says so and offers Share. **Share** writes to
    `cache/cards/` (files older than an hour are deleted on the next render) and goes through the existing
    FileProvider; the URI rides as ClipData so the share sheet's own preview can read it (the same fix
    went to "Share file").
34. **Quote size follows board 6's examples.** Auto-fit starts at the ratio's maximum as specified, but
    into 28% of the card's height rather than all the free space; the spec's fitted examples (56, 60, 48,
    34, 40, 30, 84 px) come out within 4 px (`test/tool/fit_calibration_test.dart`). A quote that can't
    fit there at 30 px may use the free space before it is shortened with "…". (Owner feedback,
    5 Oct 2026: sizes looked off.)
35. **v3 sheets sit on `surface`** (board 6 `sheetP`) with tiles, the preview box and Insights cards on
    `surfaceContainer`: the card editor, comic settings and bookmarks, book insights, sleep timer and
    Reading sheets. v1/v2 reader sheets keep `surfaceContainer`. Option tiles draw at the spec's size
    (44dp tiles, 40dp swatches) inside 48dp touch targets; toggle rows are 48dp (56 in comic settings).

## Comfort

36. **Where auto-scroll lives.** Board 6 shows the floating control and a "Reading" sheet for auto page turn
    but no entry point. The reader overflow gets "Sleep timer" (as drawn) and "Auto page turn" / "Auto-scroll"
    (with its on/off state), which opens that Reading sheet; PDF and comics overflows get the same sheet.
    Paged modes reuse the floating control too (play/pause, − / + step the interval, "30s"), so a touch-paused
    auto page turn can be resumed the same way.
37. **Speeds and intervals** are remembered per mode (`autoscroll.reader`, `.pdf`, `.webtoon`) and once for
    auto page turn. While it runs the screen stays on even with "Keep screen on" off; each tick is tracker
    activity, so a hands-free page never idles out.
38. **Not built:** shake to cancel the fade (no sensor code in Unfurl; a touch restarts it), and comfort for
    DOCX pages and slides (not continuous reading surfaces). Read aloud stays per reader as in v2, so its mini
    player (with the timer chip) is in the reader, not on Home as one board 6 frame draws (gap v3-19).
39. **Spreads for text only on tablets:** Reader mode, EPUB, Kindle and FB2 spread when the window is expanded
    and its shortest side is at least 600dp, so a phone in landscape keeps one page (board 6, V7: "On phones
    only comics use spreads"). The gutter is a 1dp rule in the reading theme's muted ink at 25%.
40. **PDF spreads pair from page 1** (1–2, 3–4): PDFs carry no reliable "first page is a cover" flag, and
    pairing from the first page keeps a page's partner stable when the document is reopened. Auto page turn and
    volume keys step two pages in a spread.
41. **Home on tablets** shows Continue reading and In your library as one row of the 5 or 7 column grid, in
    place of the phone's hero card and horizontal list, as board 6 V7 draws. Continue reading now lists every
    Library format (it listed only PDF and EPUB, so Kindle, FB2 and comic books never appeared).
42. **Wide-window centring:** More, Settings pages, empty states and the welcome pages centre at 720dp on
    expanded windows, header included. The selection toolbar keeps a phone's width (440dp) and sits over the
    selection, so on a spread it stays on its page.
