# v3 review

Phase I, 5 October 2026: a whole-codebase pass after v3 (formats, comics, tracking, Insights, book
insights, highlight cards, comfort, tablets). Numbers are in `docs/performance.md` › v3;
decisions in `docs/v3-decisions.md`. Everything below was run, not assumed; where a check needs
the owner's phone it says so.

## Build and release

| Check | Result |
|---|---|
| Release build | **Was broken.** R8 failed on classes Commons Compress and junrar reference but Unfurl doesn't ship. Fixed with `android/app/proguard-rules.pro` (`-dontwarn` for Zstandard and SLF4J's binder, both optional). |
| Release APK on device | Comics in all four archive types, damaged and RAR 5 states, Kindle, FB2, PDF and DOCX on the R8-shrunk, obfuscated build; no class or method errors |
| Size, arm64 | 32.68 MB (v3 before) → **31.11 MB** (v2 was 31.6). Codec's phonetic tables excluded (98 KB); `--obfuscate --split-debug-info` (app code −1.44 MB) |
| Merged release manifest | `MANAGE_EXTERNAL_STORAGE`, `READ_EXTERNAL_STORAGE` (max SDK 29), AndroidX's app-private receiver permission. **No `INTERNET`.** |
| Assets | Only fonts, licences, the Mull icon and the privacy policy; the 80 KB Material Symbols codepoints file is not bundled; the icon font is tree-shaken to 283 KB |

## Code

| Check | Result |
|---|---|
| Stricter lints | Added `cancel_subscriptions`, `close_sinks`, `discarded_futures`, `avoid_dynamic_calls`, `avoid_slow_async_io`, `avoid_type_to_string`, `literal_only_boolean_expressions`, `no_adjacent_strings_in_list`, `test_types_in_equals`, `prefer_void_to_null`, `only_throw_errors`, `unnecessary_lambdas`, `use_named_constants`. 7 fire-and-forget futures marked `unawaited`; 3 deliberate cases annotated with the reason (the app-long listing stream and controller, map removals of a completing future). Not adopted: `avoid_catches_without_on_clauses` (parsers of untrusted files catch everything on purpose, to show "can't open" rather than crash). |
| Disposal | Every controller, subscription, timer and notifier a State creates is disposed. Two leaks fixed: the note sheet's and the PDF password sheet's `TextEditingController`, now owned by `TextControllerScope` (disposing after the sheet's future would break its exit animation). |
| Motion tokens | 14 raw durations moved to `Motion` (chips, toasts, chrome auto-hide, save and sharpen delays) and one raw curve; the zoom % chip is 1 s in comics and images alike (board 6). Remaining literals are named constants (`Delayed`, `LoadingHairline`), a 1 s countdown tick and the layout engine's frame tick. |
| Colours | No raw chrome colours; the literals left are document content (white PDF paper, slide defaults, black image backdrop, the AMOLED preview) and the card palette's black/white contrast fallback. |
| `print`, TODO, FIXME | None in `lib/` |
| Shared widgets | Book insights' "Open in Notes" was a raw `ListTile` (its ripple hidden under the sheet's colour, a framework assertion); now `ExplorerRow` |

## Data

| Check | Result |
|---|---|
| Query plans | `test/core/query_plans_test.dart` records every SELECT behind Home, Library, Notes, More, Insights, book insights and the tracker (34 distinct) and runs `EXPLAIN QUERY PLAN`. Every filtered query on `entries`, `annotations`, `reading_sessions` and `book_days` uses a key or index. Scans left are of small tables (folders, recents, a year of `daily_stats`, `book_stats`) or Notes' list of every highlight. No new index, so no schema change. |
| Migration | Schema 4; `test/core/migration_test.dart` covers 1→3, 2→3 and 3→4 with annotations kept |
| Tracking writes | A session folds into a year of aggregates in 0.2 ms; checkpoints every 60 s and on pause |

## Behaviour found in Phases H and I

Fixed, each with a test that fails without it:

1. A file found unreadable after opening (an EPUB's DRM is inside the archive) stayed in Continue
   reading with Resume. `Library.unreadable` drops it unless it has a place or annotations.
2. Rotation (any relayout) slid the reader back about a page each time; the engine now keeps its
   anchor until the reader turns.
3. Scroll layout always opened at the top of the book.
4. Switching Paged and Scroll lost the place.
5. Scroll layout had no first-line indents.
6. The place saved in Scroll could trail the screen (measured before the last scroll frame).
7. Words left for "Estimated time left" were saved only when the reader closed; now on pause too.
8. Continue reading listed only PDF and EPUB (Kindle, FB2 and comics never appeared).
9. Switch rows (Settings › Controls, Settings) gave TalkBack a bare "switch, on": the rows now merge
   their label with the switch (`ExplorerRow`, `ListRow`).

## Accessibility

`test/ui/accessibility_test.dart` runs Flutter's Android tap-target (48dp), labelled-tap-target
and text-contrast guidelines over More, Insights, book insights, the card editor, Settings and
Settings › Controls, in light and dark. All pass. Contrast on Settings is left to the tokens: the
"Clear recents" row is 4.77:1 by its tokens (#BD413F on #F7F3EE) but samples under 4.5 at a
half-pixel offset.

## Performance

Within budget where measurable: Library search over 5,000 files 3.0 ms (budget 50), Insights
data 6.8 ms for a year, every format open under 0.7 s on the emulator, UI-thread frame build
under 10 ms at p99 on every surface. Cold start matches v2 on the same emulator (2215 vs 2107 ms
mean; the emulator is about twice as slow today as when v2 measured 1.0 s).

## Open

- **Needs the owner's phone:** cold start against the 1.5 s budget, raster frame times in the
  Reader and Insights (the emulator's GPU translation dominates them), and the v3 device suite
  (`integration_test/v3_test.dart`) on CPH2723.
- Signing config for Play is still not set up (CLAUDE.md › Release).
- RAR 5 comics stay unsupported (junrar reads RAR 4 and older).
