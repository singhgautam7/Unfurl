# App polish audit (Part A)

Read-only findings, 19 November 2026. Kuber = `/Users/gautam/Desktop/Projects/Personal/Kuber - Expense Manager/kuber` (v7.0.0, v7.0.0-b, v7.0.0-c).

## A1 Theme

- Unfurl: Light / Dark / System (`SegmentedToggle`, `lib/features/settings/info_screens.dart:196`), Pure black (`theme.amoled`), Expressive colours (`theme.expressive`, on), wallpaper colour (`theme.dynamic`, off), 18 families (`ThemeFamily.all`, `lib/core/theme/palette.dart:417`, Saffron default). Stored by `SettingsController` (`lib/features/settings/settings_controller.dart:92-148`), read once in `main`. `ThemeData` cached per (family, tone, expressive) in `AppTheme`.
- Theme change today: Flutter's implicit `AnimatedTheme` lerp, `Motion.background` 240 ms (`lib/app.dart:105`). No reveal.
- Kuber: `ThemeRipple` (`lib/core/motion/theme_ripple.dart`): snapshot with `toImageSync`, apply underneath, circle reveal from the tap over `themeReveal` 800 ms (Subtle 500 ms, `easeInOutSine`; Off a 90 ms fade). `themeAnimationDuration: Duration.zero`.
- Selected option: Kuber button group, unselected full pill, selected 12 dp corners, check grows in on `springStandard`.
- Colours Kuber has that Unfurl lacks: Sky, Ruby, Signature (Unfurl's `kuber` family to be checked against Signature). Unfurl has nothing Kuber lacks by name. Reading themes (Light, Sepia, Stone, Sage, Dusk, Dark, AMOLED) and highlight colours are Unfurl only.
- Font size: Kuber has an app text size (5 levels); Unfurl follows the system font scale and has a reader text size only.
- Hardcoded colours outside `lib/core/theme`: slide ink and paper (`office_screens.dart:945,950`), image backdrop (`image_screen.dart:89`), share card (`cards/share_card.dart:74`), PDF paper fallback (`pdf_pages.dart:884`, `pdf_screen.dart:1806`). All are document or media colours, kept as is.

## A2 Motion and haptics

- Unfurl `Motion` (`lib/core/motion/motion.dart`): durations match Kuber's where both have them (instant 90, fast 150, navIndicator 220, containerTransform 240, sheet 260, snackEnter 180, snackExit 140); no springs (`spring` is `Curves.easeOutBack`); reduced motion = system `disableAnimations || accessibleNavigation`. No Motion setting.
- Inventory in `lib/`: 13 AnimationController, 20 AnimatedContainer, 12 AnimatedOpacity, 16 AnimatedSwitcher, 51 InkWell, 68 IconButton, 33 GestureDetector, 0 CircularProgressIndicator, 3 showModalBottomSheet, 0 showDialog.
- Haptics: one unconditional `HapticFeedback.selectionClick()` (`lib/features/pdf/pdf_screen.dart:679`). No switch.
- Kuber `KuberMotion` (`lib/core/theme/app_theme.dart:111-222`): springs fast 800/0.6, default 380/0.8, slow 200/0.8, standard 700/0.9, subtle 600/1.0 (mass 1, stiffness, damping ratio); fxDefault 200, reflow 230, digitRoll 300, themeReveal 800/500; curveEffects `Cubic(0.33, 1, 0.68, 1)`; stagger 30 ms, limit 6; press scales card/row 0.98, subtle 0.99, fab 0.96, chip 0.96; button group widen 0.15.
- Kuber Auto: Off when Remove animations is on; Subtle when `isLowRamDevice` or RAM under 3584 MB; else Expressive. Probed once after launch with `device_info_plus`, cached in prefs.
- Kuber kit dependencies: only its own motion files, `KuberMotion`/`KuberShape` tokens, prefs keys, riverpod and shared_preferences; `container_transform` needs go_router.

## A3 Nav, tabs and chips

- `NavPill` (`lib/design_system/nav_pill.dart:119-189`): per-item `AnimatedContainer`, fill fades between tabs (no sliding indicator), label weight fixed. No haptics.
- Active tab tap (`lib/core/router/router.dart:143-148`, `nav_shell.dart:35-62`): scrolls to top at the tab root (Kuber's timing, `easeInOutSine`), pops to the root inside a folder. Already Kuber's behaviour except the pop, which Unfurl had before; kept.
- Single-select segmented controls (`SegmentedToggle`): reader sheets (6), Insights range, Theme mode, Settings PDF opens in, card editor source. No multi-select chip groups anywhere; chip rows (Notes filter, sheet tabs, PDF bookmarks filter, `FormatChips`) are single-select or toggles.
- Kuber: `NavIndicator` with two edge springs (leading `springFast`, trailing `springDefault`), label `AnimatedWeight` 500 to 700, `KuberHaptics.tick()` on tab change. Shape rule (decision 26): unselected full pill, selected 12 dp rounded rectangle, `springFast` morph; Subtle fades only.

## A4 Header and screens

- `AppHeader` + `CollapseOnScroll` (`lib/design_system/app_header.dart`): fixed bar above the list, restyles at 24 px, no hysteresis, no pill. Body rebuilds on each flip where screens build it inside the builder.
- Hand-rolled headers (not `AppScaffold`): Home, Library (`HeaderSearch`), Notes (search row), Folders, Folder (`_Header` + `HeaderSearch`).
- `AppScaffold`: Files, Files picker, Insights, More, Settings, Reader settings, Controls, Theme, About, Permissions, Privacy, Licences.
- Own chrome (out of scope for the floating header): reader, PDF, comics, document and office viewers, welcome.
- Kuber floating header (`lib/shared/widgets/kuber_app_bar.dart`): pill at 32 dp, back at 8 dp (24 dp gap), pill 56 high, radius 28, margin 12, top 8; modes Always / When scrolling up (hide after 16 dp down, show after 8 dp up) / When scrolling stops (show 300 ms after scroll end); setting Off scrolls the header away. Hidden pill is `IgnorePointer` + `ExcludeSemantics`. One listener per page, body never rebuilds. Owner rule: only the header is sticky; chips and filters scroll with the body.

## A5 Settings and More

- Settings hub: Appearance (Theme, Reader, Controls), PDF (opens in), Library and files, Library. Every key has one row; no duplicates. More holds Insights, Settings and About links only.
- Verdict: Unfurl already follows "every setting on exactly one page". Part E: no regrouping. Motion, Haptics, Floating header and Show the pill go on the Theme page (Unfurl's Look page), under the theme controls.
- Settings cache: `AppSettings` read once in `SettingsController.build()`; nine screens watch the whole state, so new fields must be read with `select`.

## A6 Performance

- Recorded (`docs/performance.md`): cold start 254 ms on the phone; emulator 2.0 to 2.4 s; open times 364 to 676 ms; frame build p90 under 7 ms; arm64 APK 31.11 MB. Memory never recorded.
- Lists are slivers or builders; Home and the Folders list are eager but short.
- No per-frame `setState` outside page turns; header `setState` only on threshold flips.
- Unused: `vector_math` (no imports), 11 `AppIcons` constants (tree-shaken), `Motion.volumeRepeat`, `Motion.standard`.

## A7 Part L trace (main agent)

- No WebView, docx-preview, mammoth.js or foliate-js in Unfurl (removed by design, `CLAUDE.md`). DOCX is parsed in Dart: `lib/formats/office/docx.dart` (`Docx.parse`, `Docx.toReading`).
- Page view: `lib/features/office/office_screens.dart:184-230` paginates `DocxItem`s by `pageHeight`, `margin` and `pageBreakBefore`.
- Reader mode: `Docx.toReading` builds a `ReadingDocument`; laid out by `lib/features/reader/engine/layout.dart` (`Layout._paginate`), positions in `reader_view.dart`, chapter labels and time left in `reader_scaffold.dart`.
- Chapters: EPUB sections are spine files (`lib/formats/epub/epub.dart:118-143`) with TOC entries pointing into them; Markdown, HTML and TXT are one section with heading TOC entries (`lib/formats/text/text_formats.dart`); DOCX splits at Heading 1; PDF reflow at detected headings (`lib/formats/pdf/pdf_reflow.dart:844`).
