# Performance

## Budgets (mid-range device, profile build)

| Budget | Target | How to measure |
|---|---|---|
| Cold start to interactive Home, populated library | < 1.5 s | `adb shell am start -W` on a release APK, `TotalTime`; then the first Home frame in a DevTools timeline |
| Scrolling and animation | 60 fps (120 on capable devices), no jank frames | `flutter run --profile`, DevTools frame chart; integration scroll benchmark for the Library grid (Phase 1) |
| Library search on 5,000 files | < 50 ms | integration benchmark over FTS5 (Phase 1) |
| PDF page turn, prefetched | sharp page < 100 ms | timeline marks around page render (Phase 2) |
| Reader settings change | within one frame of the preview | timeline (Phase 3) |

## Rules

Heavy work never runs on the UI isolate. Covers are decoded at display size and cached with a
cap. Granular providers with `select`; `RepaintBoundary` around the reader surface, the PDF view
and the nav pill (in place: the pill and each tab page). Every long list is a builder or sliver.

## Results

### Phase 0 (2 October 2026)

- Release APK: arm64 17.6 MB (libflutter.so 11.7 MB, app code 4.7 MB). Material Symbols tree-shaken
  from 15.2 MB to 23.7 KB.
- First frame is drawn from the cached theme (`test/ui/shell_test.dart`, "the first frame uses
  the cached theme"); nothing is awaited before `runApp` except `SharedPreferences.getInstance`.
- Cold start: **not measured.** The only device is the Pixel_9_Pro emulator, which has 3 GB of RAM,
  1.3 GB swapped and a load average near 8; Unfurl measured 7 to 13 s and an unrelated installed
  app 6.4 s. Needs a real device.
- Tab slide and pill hide each run inside one `RepaintBoundary` with a translation only, as in
  Headshorts.

### Phase 7 (3 October 2026)

- Release APK, arm64: 31.3 MB. libflutter.so 11.7 MB, app code 8.5 MB, PDFium 6.4 MB, SQLite
  1.7 MB, reading fonts about 4 MB (Literata and its italic are 1.9 MB of that). Material
  Symbols tree-shaken to 243 KB.
- Cold start, release, `am start -W` `TotalTime`, three runs on the Pixel_9_Pro emulator with
  a two-folder library: 1055, 1118 and 958 ms (budget 1.5 s). The emulator is slower than a
  mid-range phone, so a real device should land lower; confirm there.
- Heavy work off the UI isolate, each through a static entry point so the isolate carries only
  plain data: EPUB, DOCX, PPTX, sheet parsing, PDF reflow analysis, PDF recolour and crop
  detection, fingerprints and whole-file reads.
- File reads are `pread64` on the descriptor SAF hands over (no copy, no re-open); PDFium reads
  on demand through `openCustom`, in memory below 1 MB.
- PDF to Reader mode on the 6-page two-column fixture: under a second on the emulator, with the
  loading card's track advancing per page. Long PDFs: text is read page by page and the
  analysis runs once, then is cached per fingerprint for the session.
- Covers: rendered once per fingerprint at 288px, kept in app storage under a 60 MB cap, decoded
  at display size (`ResizeImage`).
- Library scans walk one folder at a time on a single native channel, in batches of 200, and
  write each batch in order; the enricher reads one new book at a time after a scan.
- Not yet measured: library search on 5,000 files, sustained frame times in the readers on a
  real device (DevTools profile run). Both need a physical phone.

## v2

### V2-A, explorer data layer (3 October 2026)

Measured with `integration_test/explorer_test.dart` built in profile mode (arm64) and run as the
app on the Pixel_9_Pro emulator (API 36, 3 GB RAM, load average about 4), all-files access granted
through `appops`. Folder: 5,000 empty `scan-n.pdf` files created from `adb shell`.

| Step | Time |
|---|---|
| readdir through the storage provider (app) | 1,419 to 2,736 ms across runs |
| readdir of the same folder from `adb shell` | 208 to 241 ms (emulator), 310 ms (CPH2723) |
| stat of 5,000 entries, spread over threads | 171 to 737 ms (one stat per entry, `java.nio`, was ~3 stats per entry) |
| first page on screen, cold | 3,209 ms |
| first page on screen, cached (back navigation) | 73 ms |

- **Budget not met on the emulator: first page of 5,000 items under 300 ms.** Almost all of it is the
  storage provider's readdir for apps, about 10x the shell's readdir on the same folder (the provider
  filters entries per app). Neither MediaStore (1,752 ms, and it misses files it hasn't indexed) nor
  `java.nio` streams avoid it. To be measured on a real mid-range phone with access granted (V2-F);
  `adb shell appops` is blocked on ColorOS, so CPH2723 needs the switch turned on by hand.
- **Back navigation is instant:** the native snapshot (path + directory mtime) answers in 73 ms, and
  the last six listings stay warm on the Dart side too.
- Listings stream: head first, a first page of 60, then pages of 300. Cancelling (leaving the folder)
  stops the walk between entries.

### V2-B to V2-F, on screen (4 October 2026)

Same emulator, profile build, the app driven by hand.

| Step | Time |
|---|---|
| UnfurlBench (5,000 files), cold listing, warm provider cache | 172 ms readdir + 23 ms stats |
| Back out and in again | instant: same scroll offset, all 5,000 already loaded |
| Download (9 entries) | 2 ms readdir + 1 ms stats |

- With the provider's directory cache warm, the 5,000-file first page fits the 300 ms budget; the
  cold numbers above stand for the first visit after boot.
- Scroll position is kept per folder for the session; it is tracked as the list scrolls, because
  the controller has no clients by the time the screen is disposed.
- Page turns: Curl and Cover draw real widgets (the page is clipped along the fold, the flap is one
  filled path), so no page is rasterised; both hold 60 fps on the emulator's software renderer in
  profile mode as far as a visual check shows. Measure on a phone with `flutter run --profile` and
  the performance overlay before calling it done.
- Enrichment of a large, broken library is slow on the emulator (about one second per unreadable
  PDF), but it runs one file at a time off the UI and only once per file per launch.

### On the OnePlus (CPH2723, Android 16), 4 October 2026

Profile build, all-files access on. Frames from `dumpsys SurfaceFlinger --latency` on the app's
surface; the panel ran at 90 Hz, dropping to 60 Hz on its own when idle.

| Check | Result |
|---|---|
| Cold start to first frame (`am start -W`, release) | 254 ms |
| 5,000-file folder, integration test, first page | 299 ms cold, 51 ms cached (budget 300) |
| Same folder opened in the app | 243 ms readdir + 35 ms stats; 89 + 54 on a later run |
| Root of internal storage (39 entries) | 2 ms + 1 ms |
| Flinging the 5,000-tile grid (126 frames) | every frame 11.1 ms, none late |
| Curl page turns, drag and taps | every frame 11.1 ms (90 Hz), none late |
| Cover page turns | every frame 16.6 ms (panel at 60 Hz), none late |

The emulator's "budget not met" above was the emulator; on the phone the cold first page fits.
