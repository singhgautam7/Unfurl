# Performance (Part H)

Unfurl had no `specs/performance.md`; its budgets live in `docs/performance.md`, which this follows. No budget is changed.

## Method

- Device: `Kuber_API30` AVD (API 30, arm64, 4 GB RAM given with `-memory 4096`, ephemeral data), on an otherwise idle host. The Pixel_9_Pro AVD named in `CLAUDE.md` had no free storage left for an install; wiping it would have deleted other apps' data.
- Baseline: `main` at 472937d, built from a separate clean worktree. New: `feature/app-polish`. Same flags for both.
- Runs alternate baseline, new, baseline, new so drift on the emulator hits both.
- Cold start: release arm64 APK, `am start -W` TotalTime after `force-stop`, 8 runs per install, 2 installs each (16 per build).
- Memory: `dumpsys meminfo` TOTAL PSS after 6 s idle on Home, after the cold-start runs.
- Frames: `integration_test/v3_perf_test.dart` (profile build), the `perf:` lines.
  - Its open-timing and paging parts cannot run on the current manifest. They open fixtures by path, which needs all-files access, and that was removed on 8 October 2026 (`kAllFilesAccess`). Every open times out at 30 s on both builds.
  - The Library (5,000 files) and Insights (a year, 300 books) parts run, and they are the screens this pass changed most.
- Header rebuilds: `test/header/header_test.dart`, a 200-row page scrolled 2,000 px in 50 steps.
- Size: see `size.md`.

## Before and after

| Measure | Baseline | New | Change |
|---|---|---|---|
| Cold start, median of 16 (ms) | 1554.5 | 1552 | -0.2% |
| Cold start, mean of 16 (ms) | 1553 | 1584 | +2.0% (two outliers at 1776 and 1793 ms; median unchanged) |
| Memory, TOTAL PSS on Home (KB) | 71,954 | 72,096 | +0.2% |
| Header rebuilds while scrolling 2,000 px | n/a (header was restyled through `setState` on the 24 px flip, rebuilding the page body) | 0 header builds, 0 body builds | better |
| First frame | drawn from the cached theme (`test/ui/shell_test.dart` passes) | same; the device probe runs after the first frame | same |
| Release download, arm64 (bytes) | 16,219,790 | 16,296,536 | +0.47% |

### Frames, run 1 (profile, emulator)

| Scenario | Baseline build p50 / p90 / p99 (ms) | New build p50 / p90 / p99 (ms) | Baseline raster p90 / p99 | New raster p90 / p99 |
|---|---|---|---|---|
| Library grid, 5,000 files, 6 flings | 1.61 / 5.56 / 9.80 | 1.63 / 5.55 / 8.10 | 21.2 / 31.9 | 22.4 / 33.4 |
| Insights, 4 flings | 0.74 / 3.95 / 10.53 | 0.60 / 4.52 / 10.96 | 19.6 / 36.8 | 18.0 / 57.8 |

| Scenario | Baseline | New |
|---|---|---|
| Insights screen to content | 285 ms | 314 ms |
| Library search, 5,000 files (median) | 2.44 ms | 2.89 ms |
| Insights data, a year and 300 books (median) | 6.20 ms | 8.46 ms |

Library search and Insights data are pure Dart code this pass did not touch, yet they moved 19% and 36%: that is this emulator's run-to-run spread. Run 2 is below.

### Run 1 finding and fix

Insights build times were higher on the new build in run 1 and in a second windowed run:

| Run | Baseline build p90 / p99 (ms) | New build p90 / p99 (ms) |
|---|---|---|
| Run 1 | 3.95 / 10.53 | 4.52 / 10.96 |
| Second windowed run | 3.20 / 5.49 | 5.36 / 20.42 |

That is over 5%. Cause: every Insights stat number rolled in on first show (`RollingNumber(animateIn: true)`), so a dozen digit animations built on every frame while the test flung the screen. Fix: numbers roll only when a value changes (the prompt's rule), and charts still draw in once. Re-measured below.

### Run 3, after the fix (same boot, new then baseline)

This boot ran headless (software rendering), so raster times are high for both and not comparable with runs 1 and 2. Build times and the timings are.

| Scenario | Baseline | New |
|---|---|---|
| Insights, 4 flings, build p50 / p90 / p99 (ms) | 0.24 / 1.07 / 18.90 | 0.20 / 1.04 / 15.32 |
| Insights screen to content | 255 ms | 251 ms |
| Library grid, 6 flings, build p50 / p90 / p99 (ms) | 0.43 / 1.34 / 9.18 | 0.40 / 1.41 / 10.14 |
| Library search (median) | 0.90 ms | 0.83 ms |
| Insights data (median) | 1.67 ms | 1.08 ms |

Library grid build p90 was 5.56 ms baseline and 5.55 ms new in run 1, and 1.34 against 1.41 here: within run-to-run noise either way, with no consistent direction. The only change on that screen is `Pressable` around each cover tile, which keeps no ticker running at rest. Result: no lasting regression over 5%.

## Rules checked (Part H)

- Nothing added before the first frame. `main` only sets `Haptics.enabled` from the prefs it already read. The RAM probe runs once, after the first frame, and is cached.
- No per-frame `setState`. The floating header updates notifiers only when a threshold is crossed or the direction changes, and it animates through `AnimatedBuilder` (transform, opacity, paint). Pressables and chips keep their tickers idle at rest; no `repeat()` anywhere.
- No storage reads during scroll or on page open. Settings are read once into `AppSettings`, and header widgets use `settingsProvider.select`.
- Lists stay lazy. Painters compare their inputs (the chart painters include the draw-in progress).
- Only transform, opacity, clip and shape animate; no animated blur or large shadows; animated parts sit in repaint boundaries.
- Motion is free when idle: tests assert no scheduled frames after settle for every primitive, the nav and the charts.
- The reader footer no longer scans the rest of the chapter on every page build (review finding). Word counts per block are made once and summed.

## Review findings (independent reviewer, read-only)

| Severity | Finding | Outcome |
|---|---|---|
| medium | Footer split the rest of the chapter with a regex twice per page build (a large TXT or Markdown file is one chapter) | Fixed: `endsChapter` walks blocks from the page end and stops at the first content, and `wordsToChapterEnd` uses per-block counts made once |
| medium | `Haptics.scrolling` was never set, so ticks could fire during a fling | Fixed: one root `NotificationListener` in `app.dart` sets it on scroll start and end |
| medium | `themeAnimationDuration: Duration.zero` makes theme changes from outside the Theme page (system dark mode, wallpaper hue) apply at once | Kept as Kuber does; logged in `decisions.md` |
| low | Dead ternary in `theme_ripple.dart` | Fixed |
| low | `reading.chapters` empty for a document with no sections | Fixed: one empty chapter |
| low | A trailing image counted as "End of chapter" | Fixed (images, rules and tables count as content) |
| low | Section break before a table dropped | Fixed, with a test |
| low | Unused kit primitives (`ShapeLoader`, `AnimatedListItem`, `StaggeredEntrance`, `ContainerTransformRoute`) | Kept, as the prompt asks for each primitive; logged |
| low | A missing RAM figure cached the device as low RAM forever | Fixed: no figure leaves it unknown |
| low | `reader/sheets.dart` and `reader_scaffold.dart` are over 600 lines | Predate this pass; not split |
