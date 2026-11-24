# Test report

One full pass on 19 November 2026, then the failures fixed and only the affected checks rerun.

## Automated (host)

| Check | Result |
|---|---|
| `flutter analyze` | Pass: no issues |
| `dart format -l 120 --set-exit-if-changed lib test integration_test` | Pass: 0 files changed |
| `flutter test` (whole suite) | Pass: 248 passed, 8 skipped (the PDF viewer tests, which need `PDFIUM_PATH`, as before) |
| Motion levels: each primitive at Expressive, Subtle, Off (`test/motion/motion_test.dart`, 35 tests) | Pass |
| Auto picks Off with Remove animations, Subtle on low RAM, Expressive otherwise (`resolveMotionLevel` table) | Pass |
| Spring retarget keeps value and velocity | Pass |
| Idle cost: no scheduled frames after settle (primitives, nav, charts) | Pass |
| Shapes: selected 12 dp, unselected full pill, segmented and chips, all levels (`test/design_system/motion_widgets_test.dart`, 14 tests) | Pass |
| Nav: indicator moves to the tapped tab; haptic only on a change, only with Haptics on | Pass |
| Active tab tap scrolls to the top; other taps unchanged (`test/ui/shell_test.dart`, existing) | Pass |
| Snackbar keeps its timer and close button | Pass |
| Touch targets 48 dp (`androidTapTargetGuideline`) | Pass |
| Pill header: pill past 32 dp, back at 8 dp, no flicker between (`test/header/header_test.dart`, 12 tests) | Pass |
| Pill header round trip: the header's rect is the rest rect again | Pass |
| Show modes Always, When scrolling up (16/8 dp), When scrolling stops (300 ms) | Pass |
| Floating header off: the header scrolls away; no page is sticky | Pass |
| Live setting change updates an open page | Pass |
| Header and body rebuilds while scrolling 2,000 px | Pass: 0 and 0 |
| Hidden pill excluded from semantics and taps; same labels, same order in pill and header | Pass |
| Settings persist; the haptics switch sets `Haptics.enabled` | Pass |
| Home, Theme and Settings at text scale 2.0 on 360x640, no overflow | Pass |
| Theme: families build in light, dark and AMOLED, expressive on and off; ids unique and in order (`test/theme/families_test.dart`) | Pass |
| Theme tokens pinned to `tokens.json` (`test/theme/tokens_test.dart`, existing) | Pass |
| Insights numbers render the same text at every level; charts settle (`test/rollout/rollout_test.dart`, 12 tests) | Pass |
| Part L1 (`test/formats/docx_breaks_test.dart`, 9 tests) | Pass |
| Part L2 (`test/reader/chapter_end_test.dart`, 10 tests) | Pass |
| Goldens | Not added. Unfurl has no golden harness (no goldens existed before this pass), and goldens rendered on macOS fonts would not match CI. Theme combinations are covered by the token and family tests plus device screenshots in light, dark and Pure black. |

## On the emulator

Device: `Kuber_API30` AVD (API 30, 1080x2400, 4 GB RAM). The Pixel_9_Pro AVD had no free storage left for an install (its 6 GB data partition was full).

| Check | Result |
|---|---|
| L1 before (baseline build): resume DOCX Page view | Reproduced: 29 pages, one bullet per page, every bullet underlined |
| L1 after: Page view | Pass: 3 pages, no false underline, no clipping. Page 1 ends at the same role heading as the PDF's page 1. Page 3 holds the last section: the only PDF is a different variant of the resume, and Unfurl draws in its own sans, not Arial |
| L1 before: Reader mode | Reproduced: a bold label alone at a page foot; a last page with one line |
| L1 after: Reader mode | Pass: labels and role lines keep with their text; the last page reads "End of section" with its section |
| L1: PDF resume in Reader mode | Not re-checked on the device after the change; the PDF path (`pdf_reflow.dart`) was not changed, and the shared engine rules are covered by the tests |
| L2: EPUB, one spine file with three TOC chapters plus a chapter over two files, default size | Pass: "End of chapter" exactly on the last page of each of the five chapters; each chapter opens a page |
| L2: same, after rotation to landscape | Pass |
| L2: same, at the largest reader text size (28) | Pass. Once, right after the size change, page taps did not turn for a while (one swipe turned one page); it did not happen again and could not be reproduced. Not investigated further. |
| Theme page: Light, Dark, Pure black; circle reveal from the tap | Pass (screenshots, the reveal caught mid-way) |
| Motion: Auto on a 4 GB device | Pass: "Auto (Expressive)" |
| Motion: Auto with Remove animations on | Pass: "Off. Your phone has animations turned off." |
| Floating header: pill on scroll, Look settings and live previews | Pass (screenshots) |
| Largest font (2.0) on a 360 dp wide screen: Home, Settings, Theme | Pass after two fixes. The Settings row values squeezed row titles into a word per line; values now stack under the label from 1.5x. The Theme preview's chip clipped at the edge; it now wraps. Both predate this pass. The pill drops its title at 1.5x and up, as in Kuber. |
| Low-end AVD (`Kuber_LowEnd`: 2 GB, 2 cores, API 30): Auto picks Subtle | Pass: "Auto (Subtle)" (screenshot). The final obfuscated release build launches there without a crash (874 ms) |
| TalkBack | Not run with TalkBack itself (the API 30 Google APIs image has no TalkBack app). Semantics checked through the accessibility tree (`uiautomator dump`): the reader page footer, Look rows and pill previews carry labels; the header and pill are covered by the semantics tests above. |
| Cold start, memory, frames | See `performance.md`. One finding over 5% (Insights build times, from numbers rolling in on first show) was fixed and re-measured |
| Release build (obfuscated, R8) launches and opens Home, Theme, Settings, reader | Pass (cold-start runs used the release APK) |
| Icon and splash | Not changed (`decisions.md`). The splash shows on cold start with the icon on pale ochre; the first frame is not delayed (median cold start unchanged). |
| Kuber side by side | Kuber's own v7.0.0 screenshots of the same states are in `screenshots/kuber/`, next to Unfurl's in `screenshots/`. Kuber's emulator was not driven, because another session may be using it. |

## Not tested, and why

- `integration_test/v3_test.dart` and the open and paging parts of `v3_perf_test.dart` need all-files access, which the manifest no longer declares (8 October 2026). They time out on `main` too.
- PDF viewer host tests need `PDFIUM_PATH` (skipped as before).
- Golden images: see above.
