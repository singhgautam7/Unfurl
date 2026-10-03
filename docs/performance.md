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
