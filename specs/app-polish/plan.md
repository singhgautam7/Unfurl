# App polish plan (Kuber 7.0.0 parity + Part L)

Branch `feature/app-polish` from `main` (472937d). Never merged.

## Conflicts with this prompt (CLAUDE.md wins)

| Prompt says | CLAUDE.md / repo | Done |
|---|---|---|
| docx-preview, mammoth.js, foliate-js in a WebView (Part L) | No WebView; every format parsed in Dart | Part L traced and fixed in the Dart pipeline |
| Subagents at any model | Subagents run on Sonnet, medium effort | All subagents Sonnet / medium |
| Add `device_info_plus`-style RAM check (Kuber) | No new packages without justification; a Kotlin channel exists | RAM and low-RAM flag read through the existing `unfurl/platform` channel |
| Commit screenshots of the resume | Personal files: never commit | Resume screenshots in `screenshots/private/` (gitignored) |
| `specs/` deliverables committed | `specs/` was gitignored (design boards) | `.gitignore` now ignores `specs/*` except `specs/app-polish/` |
| Design spec is the authority on UI | Prompt changes nav, header, segmented and chip shapes | Prompt applied where it speaks; spec kept elsewhere; deviations in `docs/design-gaps.md` and `decisions.md` |

## Phases and owners

No two owners edit the same file. Shared code has one owner.

### Phase 1 (parallel)

**M, Motion core** (subagent)
- `lib/core/motion/motion.dart` (tokens added, `Motion.reduced/of/curveOf` read the level)
- new `lib/core/motion/motion_level.dart`, `spring.dart`, `pressable.dart`, `haptics.dart`, `button_group_motion` helpers, `animated_list.dart`, `expand_collapse.dart`, `loader.dart`, `cross_fade.dart`, `rolling_number.dart`, `chart_draw_in.dart`, `theme_ripple.dart`, `animated_weight.dart`
- `lib/core/motion/transitions.dart`
- `lib/features/settings/settings_controller.dart` (fields `motion`, `haptics`, `floatingHeader`, `pillMode`)
- `lib/app.dart` (MotionScope host, theme ripple, device probe after first frame)
- `lib/core/platform/platform.dart`, `android/.../MainActivity.kt` (`deviceMemory` method)
- tests under `test/motion/`

**T, Theme colours** (subagent)
- `lib/core/theme/palette.dart` (Kuber families Unfurl lacks), `test/theme/*`

**L, Part L** (main agent)
- `lib/formats/office/docx.dart`, new `lib/formats/office/ooxml.dart`, the DOCX Page view pagination in `lib/features/office/office_screens.dart`
- `lib/formats/reading_document.dart`, `lib/features/reader/engine/layout.dart`, `lib/features/reader/reader_scaffold.dart`
- tests `test/formats/docx_breaks_test.dart`, `test/reader/chapter_end_test.dart`

### Phase 2 (after M; parallel)

**DS, Design system motion** (subagent)
- `lib/design_system/buttons.dart`, `chips.dart`, `nav_pill.dart`, `containers.dart`, `family_card.dart`, `option_tiles.dart`, `sheets.dart`, `app_snackbar.dart`, `states.dart`, `app_menu.dart`, `search_field.dart`, `covers.dart`
- `lib/core/router/nav_shell.dart`
- tests under `test/design_system/`

**H, Floating header and Look settings** (subagent)
- `lib/design_system/app_header.dart` (+ new `lib/design_system/floating_header.dart` if over 600 lines)
- `lib/features/home/home_screen.dart`, `lib/features/library/library_screen.dart`, `lib/features/notes/notes_screen.dart`, `lib/features/folders/folder_screens.dart`
- `lib/features/settings/info_screens.dart`, `settings_screen.dart`, `more_screen.dart`
- tests under `test/header/`

### Phase 3 (after phase 2 and L)

**R, Feature rollout** (subagent): replaces bare `IconButton` / `InkWell` taps in feature files not owned above with `AppIconButton` / `Pressable`, routes the PDF haptic through `Haptics`, applies rolling numbers and chart draw-in in Insights. Owns the remaining files under `lib/features/` (pdf, comics, viewer, office except the DOCX Page view block, insights, cards, files, welcome, reader sheets and chrome).

### Phase 4

Integration (main), review subagent (read-only, did not write code), one emulator pass, fixes.

## Parts with no code expected

- E: no regrouping needed (A5).
- J: icon (concept C, own handoff `unfurl-icon-v2.js`) and splash (PostPurush) already follow Kuber's layer structure; verify only.
- K: obfuscation and R8 already on; drop `vector_math`; measure.
- B6: Instrument Sans is already a variable font; skip.
