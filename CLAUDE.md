# Unfurl

Unfurl is a free, offline, ad-free reader for Android, built in Flutter. PDF and EPUB get the
full reader (position, bookmarks, highlights, notes, read aloud); DOCX, PPTX, spreadsheets,
Markdown, TXT and images open as viewers, and any text document can unfurl into Reader mode,
a reflowed page in the reader's own typography and reading theme. It never writes to a user's
files and never touches the network.

**Stack:** Flutter 3.47.6 stable · Riverpod 3 (no codegen, as in Mull) · GoRouter · shared_preferences ·
dynamic_color · drift (+ drift_flutter, FTS5) · pdfrx (PDFium only, own viewer) · archive · xml ·
markdown · path_provider. A Kotlin channel does SAF, intents, TTS and window flags. Package
`com.grs.unfurl`, Android only.

**UI source of truth:** `specs/design/unfurl/project/specs/design/HANDOFF.md` and the four boards
beside it (`Unfurl 1 Foundations.dc.html` … `Unfurl 4 Viewers and States.dc.html`), gitignored, on
disk. Tokens: `specs/design/unfurl-tokens.js` (formulas) and `tokens.json` (generated hexes).

## Commands

```bash
flutter run
flutter analyze                                          # must be clean
flutter test                                             # must pass
flutter build apk --profile --target-platform android-arm64 -t integration_test/explorer_test.dart
                                                         # on-device tests, run as the app (see the file header)
dart run build_runner build --delete-conflicting-outputs # after drift table changes
flutter build apk --release --split-per-abi              # arm64 31.3 MB (see docs/performance.md)
flutter test tool/make_icon.dart                         # launcher icon, splash, store PNG (concept C)
python3 tool/make_fixtures.py                            # regenerate test/fixtures
```

## Key decisions

- **Theme:** Mull's OKLCH role formulas, ported unchanged (`core/theme/palette.dart`), with
  Unfurl's Saffron family (the HANDOFF decision) as default; Settings › Theme also offers Mull's
  sixteen families (`ThemeFamily.all`, stored as `theme.family`). Dynamic colour (on by default)
  replaces only the primary hue, chroma pinned at 0.11. `test/theme/tokens_test.dart` pins every chrome role,
  reading surface, highlight and cover colour to `tokens.json`.
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
  (`features/pdf/`): LRU page images, sharp tiles when zoomed, recolour on an isolate, auto-crop.
  Reader mode for PDF is `formats/pdf/pdf_reflow.dart` (columns, running heads, dehyphenation,
  headings), with progress shown while it runs.
- **File access:** All-files access is optional and requested only from the Files tab. The app must
  work fully without it. No INTERNET permission, ever. Without access, files come through the Storage
  Access Framework (picked folders and files); with it, the Files tab and path-based folders read
  paths (`file://` URIs) directly, and other apps get a MediaStore or FileProvider content URI, never
  a `file://` one. Read-only either way. Kotlin hands over a detached descriptor;
  Dart reads it with `pread64` through `dart:ffi` (`core/files.dart`, `Fd`) and PDFium reads it
  through `PdfDocument.openCustom`. Never reopen `/proc/self/fd/N` by path: Android's storage
  layer refuses it to an app without storage permissions.
- **Positions and marks** are `Locator`s (text-quote anchor plus section/block/offset and
  page/char hints); per-document data is keyed by a fingerprint (size plus FNV-1a of the first
  and last 64 KB).
- **DB:** drift, schema version 1, FTS5 over entry name, title and author kept by triggers.
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

## Layout

```
lib/main.dart            bootstrap: prefs (theme cache) and DB before runApp, licences, PDFium init
lib/app.dart             MaterialApp.router, cached themes, wallpaper seed, launch intent, rescans
lib/core/theme/          oklch · tokens · palette · reading_theme (7 themes) · typography · app_theme ·
                         launcher_icon (v2 icon geometry, shared by the About mark and tool/make_icon)
lib/core/motion/         motion (tokens, Reveal) · transitions (unfurlPage, predictive back)
lib/core/router/         router (Routes) · nav_shell (tabs, pill hide, tab slide)
lib/core/db/             drift tables, FTS5 (database.g.dart is generated)
lib/core/library/        library (folders, scan queue, positions, annotations) · enrich (covers)
lib/core/platform/       the Kotlin channel: SAF, all-files access, listing, intents, TTS, window flags
lib/core/explorer.dart   all-files access (live), folder listings, per-folder session memory
lib/core/                files (Fd, fingerprint) · locator · open (open flows) · providers
lib/formats/             reading_document · format_registry · epub · pdf reflow · office · text
lib/design_system/       shared widgets (table below)
lib/features/            home · library · files (Files tab, pickers, file sheets) · folders · notes ·
                         settings · welcome · viewer
                         (DocumentScreen, OpeningCard) · reader (engine, chrome, sheets, read
                         aloud, unfurl transition) · pdf · office (docx, pptx, sheets, images)
android/.../kotlin       MainActivity (channel, launch window), Storage, Scanner, Speech, Explorer
integration_test/        on-device tests (explorer: access, volumes, 5,000-file listing)
test/                    theme tokens · parsers · locator, fingerprint, DB, migration · read aloud ·
                         page turns, table layout · shell
tool/                    make_fixtures.py · make_icon.dart (launcher, splash, store PNG)
docs/                    design-gaps.md · performance.md · mull-integration.md · v2-checklist.md ·
                         play-all-files-declaration.md · store/ (Play Store icon)
```

## Shared widgets

If two elements share a layout they share a widget. One implementation each:

| Need | Use |
|---|---|
| Screen with header and scrolling body | `AppScaffold` (`AppHeader` + `CollapseOnScroll`) |
| Any round icon action (40 disc, 20 glyph, 48 target, as Mull) | `AppIconButton` |
| Tooltip | `AppTooltip` |
| Any glyph | `AppIcon(AppIcons.x)` |
| Pill button (primary, secondary, text, accent) | `AppButton` |
| Bottom sheet | `showAppBottomSheet` (reader: `showReaderSheet`) |
| Overflow menu | `showAppMenu` + `AppMenuEntry` |
| Toast with undo | `AppSnackbar` |
| Filter / toggle chip, chip row | `PillChip`, `ChipRow` |
| Segmented control | `SegmentedToggle` |
| A reading control (sheet and the Settings › Reader page) | `TextSizeControl`, `LineSpacingControl`, `MarginsControl`, `AlignControl`, `LayoutControl`, `PageTurnControl`, `BrightnessRow` (`reader/sheets.dart`) |
| Colour family card, two-column grid | `FamilyCard`, `TwoColumnGrid` |
| Section header | `SectionHeader` |
| Card, list container, row | `SurfaceCard`, `ListContainer`, `ListRow` |
| Book cover, file tile, progress | `CoverArt`, `CoverTile`, `FormatTile`, `ProgressTrack` |
| Blocking state (empty, unreadable, access lost) | `EmptyState` |
| A file loading or heavy work (with progress) | `OpeningCard` |
| Loading | `Delayed` (250 ms), `LoadingHairline` (120 ms) |
| Content arriving (tiles, toolbars, sections) | `Reveal` (with `index` to stagger) |
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
`Motion.curveOf` for reduced motion. No widget names its own `Duration` or `Curve`. Pushed pages
use `unfurlPage`, which the predictive back gesture drives in reverse. Page to Reader is the
three-phase `UnfurlSwitcher`. Content that arrives uses `Reveal`; loading hands over to content
through an `AnimatedSwitcher` on `Motion.fast`.

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
flutter build apk --release --split-per-abi
```

4 October 2026 (v2): arm64 31.6 MB, armeabi-v7a 27.3 MB, x86_64 33.4 MB. No signing config yet. The
release manifest declares `MANAGE_EXTERNAL_STORAGE`, `READ_EXTERNAL_STORAGE` (max SDK 29) and
AndroidX's app-private `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`, and never `INTERNET`; the debug
and profile manifests carry `INTERNET` for the Flutter tool only. If Play refuses all-files access,
deleting the `MANAGE_EXTERNAL_STORAGE` line leaves a working app (Files then shows picked folders).
Play declaration draft: `docs/play-all-files-declaration.md`.

## Known gotchas

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
