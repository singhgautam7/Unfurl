# Unfurl

Unfurl is a free, offline, ad-free reader for Android, built in Flutter. PDF, EPUB, Kindle
(MOBI, PRC, AZW, AZW3/KF8), FB2/FBZ and HTML get the full reader (position, bookmarks,
highlights, notes, read aloud); comics (CBZ, CBR, CB7, CBT) get their own viewer; DOCX, PPTX,
spreadsheets, Markdown, TXT and images open as viewers, and any text document can unfurl into
Reader mode, a reflowed page in the reader's own typography and reading theme. v3 adds reading
Insights, highlight cards, a sleep timer, auto-scroll, volume-key paging and tablet layouts. It
never writes to a user's files and never touches the network.

**Stack:** Flutter 3.47.6 stable · Riverpod 3 (no codegen, as in Mull) · GoRouter · shared_preferences ·
dynamic_color · drift (+ drift_flutter, FTS5) · pdfrx (PDFium only, own viewer) · archive · xml ·
markdown · path_provider · material_color_utilities (card palettes). A Kotlin channel does SAF,
intents, TTS, window flags, volume keys, image save/share and comic archives (Commons Compress
1.28.0, XZ 1.10, junrar 7.5.5 for RAR 4). Package `com.grs.unfurl`, Android only.

**UI source of truth:** `specs/design/unfurl/project/specs/design/HANDOFF.md` and the six boards
in `specs/design/unfurl/project/` (`Unfurl 1 Foundations.dc.html` … `Unfurl 6 v3 Reading
Update.dc.html`), gitignored, on disk. Tokens: `specs/design/unfurl/project/specs/design/` ›
`unfurl-tokens.js` (formulas), `unfurl-v3-tokens.js` (v3) and `tokens.json` (generated hexes).

## Commands

```bash
flutter run
flutter analyze                                          # must be clean
flutter test                                             # must pass
flutter build apk --profile --target-platform android-arm64 -t integration_test/explorer_test.dart
                                                         # on-device tests, run as the app (see the file header)
flutter build apk --profile --target-platform android-arm64 -t integration_test/v3_test.dart
                                                         # v3 on-device round: formats, tracking, cards, comfort
flutter build apk --profile --target-platform android-arm64 -t integration_test/perf_test.dart
                                                         # the timings to compare (setup in the file header);
                                                         # tool/perf_run.sh runs it, tool/perf_table.py compares
PDFIUM_PATH=/path/to/libpdfium.so flutter test test/pdf  # PDF viewer tests on the host (else skipped;
                                                         # pdfium-binaries linux-x64, release pdfium_dart pins)
dart run build_runner build --delete-conflicting-outputs # after drift table changes
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
                                                         # arm64 31.1 MB (see docs/performance.md)
flutter test tool/make_icon.dart                         # launcher icon, splash, store PNG (concept C)
python3 tool/make_fixtures.py                            # regenerate test/fixtures
```

## Key decisions

- **Theme:** Mull's OKLCH role formulas, ported unchanged (`core/theme/palette.dart`), with
  Unfurl's Saffron family (the HANDOFF decision) as default; Settings › Theme (Kuber's layout,
  `ThemeControls`, also a welcome page) offers Mull's sixteen families and Kuber's blue
  (`ThemeFamily.all`, stored as `theme.family`). Expressive colours (`theme.expressive`, on) tints
  surfaces; off, every family shares one neutral grey ramp. Dynamic colour is **off by
  default** (owner's call, 8 October 2026: on, it replaced Saffron with the wallpaper's hue on
  most phones); when on, it replaces only the primary hue, chroma pinned at 0.11.
  `test/theme/tokens_test.dart` pins every chrome role, reading surface, highlight and cover
  colour to `tokens.json`.
- **No WebView.** The earlier plan (foliate-js, docx-preview, SheetJS in a WebView) was dropped:
  a WebView needs a network-capable engine, cold-starts slowly, and can't share Flutter's text
  selection, highlights or motion. Every format is parsed in Dart (`lib/formats/`) on an isolate.
- **One reader engine.** Every Reader-mode format becomes one `ReadingDocument` (sections of
  blocks with inline runs and a `SourceRef` back to the original page) and is laid out by
  `features/reader/engine/` with `TextPainter`: pagination at line boundaries, soft-hyphen
  hyphenation (hyphen drawn by the engine, hanging), first-line indent as a placeholder span,
  paged or scroll, two columns from 840dp. Page turns (v2): Slide, Curl and Cover
  (`engine/page_turn.dart`, real widgets clipped along a straight fold), Fade, None; reduced motion
  maps Curl/Cover to Fade and Slide to None. Tables are real text; a table wider than the page
  scrolls sideways (`Fragment.scroll`), and columns never break inside a word.
- **PDF:** pdfrx for PDFium (render, text, outline, links); the viewer is Unfurl's own
  (`features/pdf/`): `pdf_pages.dart` is the page surface (its own gestures: Android fling physics
  through `ClampingScrollSimulation`, a scroll frame moves one transform, pages rebuilt only when
  one enters or leaves range); `PageRenderer` queues renders by priority (on screen, previews
  first), keeps an LRU of page images, sharp tiles when zoomed, recolour on an isolate, auto-crop.
  Page view shows the file's own colours; "Recolour pages" is opt-in (`pdf.recolourPages`, off).
  Reader mode for PDF is `formats/pdf/pdf_reflow.dart` (columns, running heads, dehyphenation,
  headings), with progress shown while it runs; the result is kept on disk (`core/reflow_cache.dart`,
  app storage, 300 MB LRU, bump `PdfReflow.version` when the analysis changes), and the laid-out
  pages are kept while Page view shows (`ReaderLayoutCache`).
- **File access:** All-files access (`MANAGE_EXTERNAL_STORAGE`) is **off for now**: Play refuses it
  for Unfurl, so it is out of the manifest and `kAllFilesAccess` (`core/explorer.dart`) hides the
  Files tab, the Settings rows and every control that asks for it; folders come through Android's
  picker. To bring it back, set the flag and restore the manifest line. No INTERNET permission,
  ever. Without access, files come through the Storage Access Framework (picked folders and files);
  with it, the Files tab and path-based folders read paths (`file://` URIs) directly, and other apps
  get a MediaStore or FileProvider content URI, never a `file://` one. Read-only either way. Kotlin
  hands over a detached descriptor; Dart reads it with `pread64` through `dart:ffi` (`core/files.dart`,
  `Fd`) and PDFium reads it through `PdfDocument.openCustom`. Never reopen `/proc/self/fd/N` by path:
  Android's storage layer refuses it to an app without storage permissions.
- **Positions and marks** are `Locator`s (text-quote anchor plus section/block/offset and
  page/char hints); per-document data is keyed by a fingerprint (size plus FNV-1a of the first
  and last 64 KB).
- **DB:** drift, schema version 5, FTS5 over entry name, title and author kept by triggers. v3
  tables: `reading_sessions` (raw, open ones recovered at launch), `daily_stats`, `book_stats`,
  `book_days` (aggregates). Schema 5: a Recents row keeps where its file came from (`FileSource`).
  `test/core/query_plans_test.dart` fails if a filtered query on a
  growing table scans it.
- **Tracking:** `core/tracking/`: a pure `LiveSession` accumulator, `ReadingSessionTracker`
  (owner-scoped sessions, idle, background, checkpoints every 60 s) and `StatsStore` folding each
  finished session into the aggregates in one transaction. Readers report through `TrackedPages`
  and `TrackActivity`.
- **Motion (app polish, Nov 2026, Kuber 7.0.0):** `lib/core/motion/kit.dart` exports Kuber's kit
  under Unfurl names: `Motion` springs and tokens, `MotionScope` levels (Expressive, Subtle, Off;
  Auto = Off with Remove animations, Subtle under 3584 MB RAM or a low-RAM flag read once after
  the first frame through the Kotlin channel), `Pressable`, `Haptics` (off by default; never call
  `HapticFeedback`), `ThemeRipple`, `RollingNumber`, `ChartDrawIn`. Selected chips and segments
  have 12 dp corners, unselected are outlined pills. Kuber is the source of truth for motion, press
  feel, shapes and widget behaviour; Mull's version where Kuber has the fault (menu, chips, sheets).
  **No Motion setting** (pass 2): the phone decides (Off under Remove animations, Subtle under 3584 MB
  or a low-RAM flag, else Expressive); a stored `motion.preference` is ignored. Settings › Theme holds
  Haptics, Floating header and Show the pill. Notes: `specs/app-polish/`, `specs/app-polish-2/`.
- **Recents (pass 2):** a file from another app usually comes with a read grant that ends with the
  task. Unfurl records what Android says about it (`Sources.kt`, `FileSource`) and an exact location
  only from a storage or Downloads document URI or a MediaStore row, never guessed. When it can't be
  read, `Library.locate` first looks for the same content in allowed folders, then `sortAccess`
  (`core/library/access.dart`) sorts it: no access (Allow this folder, Open in file manager), unknown
  (open it again from the app that sent it) or gone. "Gone" is said only when the exact place was
  looked at: a held grant's provider, or from Android 11 the path itself (it can be looked up without
  a permission). `DocId.grantable` knows which folders Android's picker refuses. Relinking moves the
  Recents row (`Library.relink`); places, highlights and notes are keyed by fingerprint and stay.
- **Floating header:** `AppScaffold` / `HeaderPage` (`design_system/floating_header.dart`): one
  scroll listener, pill at 32 dp scrolled and back at 8 dp; only the header is sticky (chips scroll).
- **Chapters:** `ReadingDocument.chapters` come from the TOC (shallowest level with two or more
  entries), else one per section; a chapter inside a section starts a page; the footer's "End of
  chapter" is `endsChapter(first, last)` of that page. Headings and bold label lines keep with
  the next block. Word's on/off flags are read only through `formats/office/ooxml.dart`.
- **Format registry:** one `FormatModule` per format declares extensions, MIME types, default
  view and capabilities; the UI omits controls a format cannot use.
- **Icons:** Material Symbols Rounded, variable font bundled, drawn at weight 350 through
  `AppIcon`. Add each glyph's codepoint to `AppIcons`; release builds tree-shake the font.
- **Launcher icon (v2):** concept C ("Bookmarked U"), geometry and colours in
  `core/theme/launcher_icon.dart`; `tool/make_icon.dart` writes the adaptive layers (with
  monochrome), the splash icon, legacy mipmaps and `docs/store/play-store-512.png`. The splash is
  PostPurush's: the icon's pale ochre (#F8E5C7) in light and dark, glyph centred.
- **Packages not used, on purpose:** no WebView, no `flutter_tts` (the Kotlin channel drives
  `TextToSpeech` with utterance callbacks), no `wakelock_plus` (a window flag), no `freezed`
  (plain immutable classes), no `ffi` package (`@Native` leaf calls need only `dart:ffi`).

## Data rules

1. Never write to, modify, move or delete a user's file.
2. All per-document data is keyed by fingerprint, never by URI or path.
3. All annotations, bookmarks and positions use `Locator`; never store raw page numbers or offsets alone.
4. Every schema change bumps the drift schema version and ships a tested migration; never lose user annotations.
5. No network, ever. No `INTERNET` permission.
6. The design spec is the authority on UI; gaps go in `docs/design-gaps.md`.
7. Reading stats are keyed by fingerprint like everything else. Insights reads only the
   aggregates (`daily_stats`, `book_stats`, `book_days`); raw sessions exist only to be folded in.
8. A file that turns out unreadable (DRM, damaged, unsupported) leaves Home and Recents, unless
   it has a saved place or annotations (`Library.unreadable`).

## Layout

```
lib/main.dart            bootstrap: prefs (theme cache) and DB before runApp, licences, PDFium init
lib/app.dart             MaterialApp.router, cached themes, wallpaper seed, launch intent, rescans
lib/core/theme/          oklch · tokens · palette · reading_theme (7 themes) · typography · app_theme ·
                         launcher_icon (v2 icon geometry, shared by the About mark and tool/make_icon)
lib/core/motion/         motion (tokens, Reveal) · transitions (unfurlPage, predictive back)
lib/core/router/         router (Routes) · nav_shell (pill, pill hide) · branch_stack (tab slide, warm tabs)
lib/core/db/             drift tables, FTS5 (database.g.dart is generated)
lib/core/library/        library (folders, scan queue, positions, annotations, relink) · access (states of a
                         file that can't be opened) · enrich (covers, their in-memory index)
lib/core/platform/       the Kotlin channel: SAF, all-files access, listing, intents, TTS, window flags
lib/core/explorer.dart   all-files access (live), folder listings, per-folder session memory
lib/core/                files (Fd, fingerprint) · locator · open (open flows) · providers ·
                         reflow_cache (Reader mode on disk)
lib/core/tracking/       session (LiveSession, rules) · tracker · stats_store
lib/core/layout.dart     SizeClass (600 / 840), AdaptiveSpec, CoverGrid
lib/formats/             reading_document · format_registry (sniff, families) · books · epub · kindle ·
                         fb2 · comics · pdf reflow · office · text (incl. HTML) · charsets · tag_soup
lib/design_system/       shared widgets (table below)
lib/features/            home · library · files (Files tab, pickers, file sheets) · folders · notes ·
                         settings · welcome · viewer
                         (DocumentScreen, OpeningCard, problemState) · reader (engine, chrome,
                         sheets, read aloud, comfort, unfurl transition) · pdf · office (docx, pptx,
                         sheets, images) · comics · insights · cards (highlight cards)
android/.../kotlin       MainActivity (channel, launch window), Storage, Scanner, Speech, Explorer,
                         Comics (zip, 7z, tar, RAR 4 through a duplicated descriptor)
integration_test/        on-device tests: explorer (access, volumes, 5,000-file listing), v3 (formats,
                         tracking, cards, comfort, rotation), v3_perf (timings); perf (pass 2: every tab, scroll,
                         open, sheet, page turn and memory, on the app's own binding); harness.dart
test/                    recents (access states, relinking) · perf (rebuild counts) · lists · settings · viewers ·
                         theme tokens · parsers · locator, fingerprint, DB, migration · read aloud ·
                         page turns, table layout · shell
tool/                    make_fixtures.py · make_icon.dart (launcher, splash, store PNG) · make_perf_fixtures.py ·
                         perf_run.sh · perf_table.py
docs/                    design-gaps.md · performance.md · mull-integration.md · v2-checklist.md ·
                         v3-checklist.md · v3-decisions.md · v3-review.md · v3-screens/ ·
                         play-all-files-declaration.md · store/ (Play Store icon)
```

## Shared widgets

If two elements share a layout they share a widget. One implementation each:

| Need | Use |
|---|---|
| Screen with header and scrolling body | `AppScaffold` (`AppHeader` + `CollapseOnScroll`) |
| Any round icon action (40 disc, 20 glyph, 48 target; circle to squircle while held) | `AppIconButton` (`kind`) |
| Tooltip | `AppTooltip` |
| Any glyph | `AppIcon(AppIcons.x)` |
| Pill button, 56 or 40 dp (primary, secondary, outline, text, accent, danger, dotted) | `AppButton` |
| Bottom sheet | `showAppBottomSheet` (reader: `showReaderSheet`); any other shape: `pushHeldSheet` |
| Overflow, long-press and point menus, an icon on every row | `showAppMenu` + `AppMenuEntry` (never `showMenu`) |
| Toast with undo | `AppSnackbar` |
| Text selection handle (reader and PDF) | `SelectionHandle` |
| Filter / toggle chip (32 dp in a 48 dp hit region), chip row, chip wrap | `PillChip`, `ChipRow`, `ChipWrap` |
| Segmented control | `SegmentedToggle` |
| A reading control (sheet and the Settings › Reader page) | `TextSizeControl`, `LineSpacingControl`, `MarginsControl`, `AlignControl`, `LayoutControl`, `PageTurnControl`, `BrightnessRow` (`reader/sheets.dart`) |
| Colour family card, two-column grid | `FamilyCard`, `TwoColumnGrid` |
| Section header | `SectionHeader` |
| Card (tappable with `onTap`), list container | `SurfaceCard`, `ListContainer` |
| Row: 40 dp icon tile, title, description under it, chevron or whole-row switch | `ListRow` (`switchValue`) |
| A row that draws itself (press scale, 10% state layer, no ink) | `PressableRow` |
| A file that can't be opened | `AccessView` (Recents), `problemState` (damaged, DRM) |
| Book cover, file tile, progress | `CoverArt`, `CoverTile`, `FormatTile`, `ProgressTrack` |
| Blocking state (empty, unreadable, access lost) | `EmptyState` |
| A file loading or heavy work (with progress) | `OpeningCard` |
| Loading | `Delayed` (250 ms), `LoadingHairline` (120 ms) |
| Option tiles in a sheet (templates, fonts, swatches), sheet title | `OptionGroup`, `OptionTile`, `SheetHead` |
| A text field in a sheet or dialog (owns its controller) | `TextControllerScope` |
| Window size, grid columns, side panel | `SizeClass`, `CoverGrid`, `SidePanel` |
| Content arriving (tiles, toolbars, sections) | `Reveal` (with `index` to stagger) |
| Press feel on anything tappable (scale, corners, haptic) | `Pressable` (`core/motion/pressable.dart`) |
| A number or count that changes | `RollingNumber` |
| Nav | `NavPill` inside `NavShell`; hide with `navHiddenProvider` |

## Theme rules

- One token source: `lib/core/theme/`. No hardcoded colours or sizes anywhere else; a raw hex or
  magic number in a widget is a bug. Read colours as `context.colors.<role>`, type as
  `UnfurlType.<step>`, everything else from `Space`, `Radii`, `IconSpec`, `Elevations`, `Motion`.
- Two layers: chrome (`UnfurlColors`, light / dark / AMOLED) and reading surfaces (`ReadingTheme`:
  Light, Sepia, Stone, Sage, Dusk, Dark, AMOLED; stored by name), which paint only the page.
  Highlights and covers are stored as an index and re-derived per theme.
- ThemeData is built once per (family, tone) in `AppTheme` and never per widget.
- Synchronous theme caching: `main` reads prefs before `runApp`, so the first frame is drawn
  from the cached mode, AMOLED flag, dynamic flag and last wallpaper seed. `SettingsController`
  caches the light and dark launch surfaces, which `MainActivity` paints after the splash and
  before Flutter's first frame.
- One typeface for chrome, Instrument Sans (variable): weights move the `wght` axis
  (`.weight(n)`). Mono is the platform monospace. Reading fonts: Literata, Instrument Sans,
  Atkinson Hyperlegible Next, OpenDyslexic, all bundled.

## Motion rule

Every page switch and every show/hide animates with the shared `Motion` tokens: spring for
anything the finger caused, decelerate for anything the system caused, `Motion.of` /
`Motion.curveOf` for reduced motion. No widget names its own `Duration` or `Curve`, including
how long a chip or toast stays (`Motion.chipPage`, `chipZoom`, `chipScrubBack`, `chipLinkBack`,
`toast`, …) and save debounces (`Motion.saveDelay`). Pushed pages
use `unfurlPage`, which the predictive back gesture drives in reverse. Page to Reader is the
three-phase `UnfurlSwitcher`. Content that arrives uses `Reveal`; loading hands over to content
through an `AnimatedSwitcher` on `Motion.fast`.

## Performance guidelines

Budgets and measurements live in `docs/performance.md`; re-run `integration_test/perf_test.dart`
after work on a reader, the library or Insights.

- **Nothing lays out a whole document in one frame** (pass 2; a 700 KB text file froze the app for
  5 s, a font step for 1.4 s). The reader's `Layout` and `DocxPaginator` are resumable: the page in
  front first, the rest in 6 ms slices, one a frame, with the page boundaries of one full run.
- **A book keeps where its pages break, not their painters** (`Fragment.release`): 200,000 words of
  `TextPainter`s were 450 MB. A shown fragment lays its text out again.
- **Tabs:** `BranchStack` slides finished layers (the repaint boundary inside the moving part) and its
  clock starts after the frame that builds the page; so do sheets (`HeldSheetRoute`) and pushes
  (`unfurlPage`). Library, Notes and More are built, laid out and painted unseen while Home idles
  (`WarmTab`, after the streams they need have a value). Entrances (`Reveal`, `StaggeredEntrance`)
  don't run in a tab built offstage.
- **Watch fields, at the leaf.** No `ref.watch(settingsProvider)` whole; a screen's `build()` filters and
  sorts nothing (memoise on identity, as `LibraryScreen._show`); Home is section consumers; page
  position in the readers goes through listenables, not `setState` of the scaffold
  (`test/perf/rebuild_counts_test.dart`).
- **A tile never touches the disk.** Covers are an in-memory index read once off the UI isolate;
  `Covers.watch(fingerprint)` repaints one tile.
- **Writes to `entries`, `documents` or `folders` re-run the library's queries.** Write only what
  changed (`touch`, `_scan`), batch the enricher's marks, and let position saves stay quiet;
  `Library.documentsChanged` tells the lists once, when a document closes.
- **Provider calls (stat, openFd, queries) run on `MainActivity.io`**, never the platform main thread.
- A filter change never blanks a list: rows keyed by id (`findChildIndexCallback`), only new ones ease in.
- Never tween a fill from `Colors.transparent` (use the target at alpha 0); no ink splash on a control
  whose own fill changes; clip only the ends of a list card, not every row.
- Search boxes wait `Motion.searchDelay`; bursts of data redraw at most every `Motion.coalesce`.
- Measure with `integration_test/perf_test.dart` (a test binding draws every vsync and turns semantics
  on, which hides idle costs). Judge build times on the emulator; API 36 AVD raster is host GPU noise.
- Parsing, decoding, word counts and fingerprints run on an isolate, from a static or top-level
  function that takes plain data. Comic pages decode on the Kotlin side; Dart keeps an LRU of
  bytes and decodes at display size.
- Insights reads aggregates only, through granular providers; never scan `reading_sessions` from UI.
- Writes that follow the reader (positions, words left) are debounced (`Motion.saveDelay`) and
  also flushed on pause: Android may end a backgrounded app without disposing anything.
- Long lists are builders or slivers; covers use `ResizeImage`; RepaintBoundary around reader
  surfaces, the PDF view, the nav and each tab page.
- A future that must be ready in the same frame (a cached page) is returned synchronously
  (`SynchronousFuture`), not from an `async` function.
- Every filtered query on a growing table uses an index (`test/core/query_plans_test.dart`).
- Release builds: R8 on, `--obfuscate --split-debug-info=build/symbols` (symbols stay local; there
  is no crash reporting). Java resources that R8 can't strip are excluded in `build.gradle.kts`.

## Standing instructions

- Read the HANDOFF and boards in `specs/design/` before any UI work, and follow the spec exactly.
- Mull (`/Users/gautam/Desktop/Projects/Personal/Mull`) and Headshorts
  (`/Users/gautam/Desktop/Projects/Personal/HeadShorts`) are read-only references. Never modify them.
- Never break existing functionality when adding features.
- No new packages without stating the justification first. Versions are pinned exactly.
- No network, analytics, ads or telemetry, ever.
- Run `dart run build_runner build --delete-conflicting-outputs` after any drift change.
- `flutter analyze` and `flutter test` must be clean before calling anything done.
- Edge-to-edge everywhere; minimum touch target 48x48dp.
- No em dashes in any user-facing string.
- No performance regressions; check the budgets in `docs/performance.md`.
- Format with `dart format -l 120`.

## Release

```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```

8 October 2026: the release manifest declares only `READ_EXTERNAL_STORAGE` (max SDK 29) and
AndroidX's app-private receiver permission; all-files access is off (`kAllFilesAccess`).

24 November 2026 (polish pass 2): arm64 31.5 MB, armeabi-v7a 26.9 MB, x86_64 33.3 MB.

5 October 2026 (v3): arm64 31.1 MB, armeabi-v7a 26.6 MB, x86_64 32.9 MB (v2: 31.6, 27.3, 33.4 MB,
without obfuscation). Check for the `✓ Built` line: a failed build leaves the previous APKs in
`build/`. Signed with release key (`upload-keystore.jks` via `android/key.properties`). The
release manifest never declares `INTERNET`; the debug and profile manifests carry it for the
Flutter tool only. Play declaration draft for all-files access, if it comes back:
`docs/play-all-files-declaration.md`.

## Known gotchas

- **A launch intent is new only on a fresh `onCreate`** (no saved state, not
  `FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY`). Android hands a recreated or restored activity, and a
  task brought back after the process was killed, the VIEW intent that first started it; taking
  it as new reopened that file by itself (8 October 2026, sev 0). `onNewIntent` is always new.
- `integration_test/idle_test.dart` guards that the app settles: once a real folder is scanned
  and enriched, an idle Home draws no frames and the database takes no writes.

- Release builds need `android/app/proguard-rules.pro`: R8 fails on classes Commons Compress and
  junrar refer to but Unfurl doesn't ship (Zstandard, SLF4J's binder). Flutter's Gradle plugin
  picks the file up by itself. Profile builds skip R8, so test comics on a release build.
- drift generates a data class per table; a table named `Sessions` would clash with app classes
  (the tracker's in-memory session is `LiveSession` for that reason).
- `OverflowBox` with an unbounded `maxWidth` inside a Row throws on real phones only at some
  text sizes; bound it (`SizedBox` + `maxWidth`).
- On-device tests: after `handleAppLifecycleStateChanged(paused)` no frames are scheduled, so
  `pump()` hangs; wait with `Future.delayed`. Use `SharedPreferences.setMockInitialValues`, never
  `clear()`, or the test wipes the device's own settings.
- Scroll notifications fire before the frame lays the new offset out; measure what is on screen
  after the frame (the reader re-measures on scroll end).
- Semantics node rects in guideline failures are relative to the parent node, not the screen.
- RAR 5 comics are not supported (junrar reads RAR 4 and older); they show the unsupported state.

- Riverpod 3 moved `Override` to `package:flutter_riverpod/misc.dart`.
- `ref` can't be used in `dispose()`: hold what dispose needs (e.g. `Library`) in a field set in
  `initState`. The readers save their last position from dispose this way.
- `Isolate.run` inside an async *instance* method captures `this` in the closure's context and
  fails on unsendable fields (PDF documents, the DB). Call isolates from a static or top-level
  function that takes only plain data.
- One native scan channel serves all folders, so `Library.scan` queues walks; never listen to
  `Platform.scan` twice at once. Listings (`unfurl/list`) instead share one long-lived stream,
  each event tagged with a listing id, started and cancelled by method calls: an EventChannel
  carries one stream at a time, and a late cancel would otherwise kill the next folder's listing.
- A folder's cold listing is bounded by the storage provider's readdir for apps (about 10x the
  shell's on the same folder); repeat visits come from the native snapshot cache. `adb shell appops`
  is blocked on ColorOS (OnePlus); grant all-files access on the emulator for automated tests.
- Covers live in app support storage, not the cache: Android purges caches under storage
  pressure. The enricher re-reads any book whose cover file went missing.
- `dynamic_color` 2.x builds `material_ui` schemes; Unfurl reads only the `CorePalette` seed.
- A route transition must not swap curves mid-flight: after a predictive back gesture starts,
  `unfurlPage` stays linear until the route is at rest or gone.
- The local emulator (Pixel_9_Pro AVD, 3 GB RAM, nearly full disk) is slow and can't fit a debug
  APK; test with `flutter build apk --profile --target-platform android-arm64`.
