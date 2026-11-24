# Decisions (deviations from Kuber, mappings, colours, removals)

Kuber is the source of truth for values. Where `CLAUDE.md` conflicts with the prompt, `CLAUDE.md` wins (see `plan.md`).

## Stack mapping

Both apps are Flutter. Kuber's code was ported with Unfurl names:

| Kuber | Unfurl |
|---|---|
| `KuberMotion` (tokens in `app_theme.dart`) | `Motion` (`lib/core/motion/motion.dart`); existing tokens kept, Kuber's added |
| `KuberHaptics` | `Haptics` (`lib/core/motion/haptics.dart`) |
| `motion_level.dart`, `MotionScope`, `levelOf` | same names, `lib/core/motion/motion_level.dart`; `Motion.levelOf(context)` |
| `spring_curve.dart`, `springTo` | `lib/core/motion/spring.dart` |
| `Pressable`, `ExpandCollapse`, `ChevronTurn`, `ContainerTransformRoute`, `SkeletonCrossFade`, `ChartDrawIn`, `AnimatedWeight`, `ThemeRipple` | same names in `lib/core/motion/`, barrel `kit.dart` |
| `KuberShapeLoader` | `ShapeLoader` |
| `AnimatedAmount` (money) | `RollingNumber` (plain integers; Unfurl has no money) |
| `KuberAnimatedListItem`, `StaggeredEntrance` | `AnimatedListItem`, `StaggeredEntrance`; Unfurl's `Reveal` kept and moved to Kuber's stagger (30 ms, 6 items) |
| `KuberButtonGroup` | Unfurl's `SegmentedToggle` restyled to the button group (API kept for its 10 call sites) |
| `KuberChip` shape rule | `PillChip` |
| `KuberNavBar` / `NavIndicator` | `NavPill` (single sliding indicator); `NavRail` gets `AnimatedWeight` |
| `KuberAppBar` / `KuberHeaderPage` floating header | `AppHeader` / `AppScaffold` (one common header) |
| Look page | Unfurl's Theme page (Settings > Appearance > Theme) |
| `device_info_plus` RAM probe | Kotlin `deviceMemory` on the existing `unfurl/platform` channel (`ActivityManager.MemoryInfo.totalMem`, `isLowRamDevice`); no new package (`CLAUDE.md`) |

## Motion

- Springs, durations, stagger, press scales and radii are Kuber's exact values (`Motion.springFast` 800/0.6, `springDefault` 380/0.8, `springSlow` 200/0.8, `springStandard` 700/0.9, `springSubtle` 600/1.0; `fxDefault` 200, `reflow` 230, `digitRoll` 300, `themeReveal` 800 / 500 ms).
- Low RAM threshold: Kuber's `kLowRamMb` 3584 MB (a "4 GB" phone reports about 3.6 to 3.8 GB), or Android's low-RAM flag. The prompt says "under 4 GB"; Kuber's value is what it means in practice.
- `Motion.of` / `curveOf` follow Kuber: anything not Expressive gets the 90 ms fade and a linear curve. Existing Unfurl call sites (120) therefore become short fades at Subtle, as in Kuber.
- `resolveMotionLevel`: the phone's Remove animations (or accessibility navigation) forces Off even over an explicit choice, as Kuber.
- Pressable fires `Haptics.tick()` on tap (the prompt asks for it in the pressable; Kuber's pressable does not tick).
- Haptics default **off**, as Kuber. Unfurl had one unconditional haptic (PDF text selection); it now follows the switch. Logged as the one behaviour that changes by default.
- Extra tokens added so no widget names a Duration: `expandFadeDelay`, `digitStep`, `chartDraw`, `chartBar`, `hapticGap`.
- Not ported (no use in Unfurl): Kuber's shimmer (Unfurl has no skeletons), route styles beyond the sheet style, `FloatingHeaderMode.off` (Unfurl stores Floating header as a bool and Show the pill as `PillMode`).
- Sheets open on Kuber's sheet springs (`springSlow` open, `springStandard` close) rather than the fixed 260 ms.
- B6 (variable font): skipped. Instrument Sans is already the variable chrome font; `UnfurlType` moves its `wght` axis.

## Shapes (D2)

- Selected = 12 dp corners, unselected = full pill (Kuber decision 26: Kuber uses `RoundedRectangleBorder(12)`, not a true superellipse; copied).
- Unfurl has no multi-select chip groups. Kuber applies the rule to every chip, so every `PillChip` follows it (Notes filter, sheet tabs, PDF bookmark filter, format chips).
- `SegmentedToggle` shows no check on the selected pill (Kuber's button group draws one) so labels in the reader sheet's narrow rows do not truncate.
- `FamilyCard`: selected corners 20 to 12 dp with a check that grows in (Kuber's family cards are static; the morph and check follow the button group rule).

## Theme (C)

- Kept (Unfurl only): Saffron (default), the `kuber` family, wallpaper colour, and every reading surface theme (Light, Sepia, Stone, Sage, Dusk, Dark, AMOLED) and highlight colour token. These paint only the page and stay out of Part C.
- Added from Kuber: **Sky** and **Ruby** (exact Mull parameters from Kuber `theme_families.dart:356-357`) and **Signature**. Kuber builds Signature from an M3 scheme with hardcoded black/white surfaces, not Mull parameters; Unfurl's Signature uses the `kuber` primary over a near-neutral ramp (approximation). Appended to `ThemeFamily.all` so stored ids still resolve.
- Font size: Kuber's app text size setting is not added. Unfurl follows the system font scale (and has its own reader text size); Part C's options do not list it and adding a setting is a new feature.
- Theme change: Kuber's `ThemeRipple` (snapshot, circle reveal from the tap) with `themeAnimationDuration: Duration.zero`.

## Settings (E)

- No regrouping: Unfurl already keeps every setting on exactly one page (audit A5). Motion, Haptics, Floating header and Show the pill go on the Theme page (Unfurl's Look page), under the theme controls, in Kuber's order.

## Icon and splash (J)

- Icon: no change. Unfurl's icon is concept C from its own handoff (`specs/design/unfurl/project/specs/design/unfurl-icon-v2.js`), already built like Kuber's: vector background, foreground and monochrome layers, `mipmap-anydpi-v26/ic_launcher.xml`, legacy `ic_launcher.png` in every density, Play icon `docs/store/play-store-512.png` (`tool/make_icon.dart`). No duplicates left.
- Splash: no change. It is already PostPurush's structure (`values-v31` / `values-night-v31` splash attributes, `launch_background` fallback below API 31), native only, using Unfurl's icon and `icon_bg`. The system splash honours Remove animations on its own.

## Size (K)

- Removed `vector_math` (no imports; still in the graph through Flutter, so no size change).
- Obfuscation, R8 and the symbols folder were already on (`CLAUDE.md` release command).

## Review follow-ups

- Rolling numbers roll only when a value changes, not on first show. Rolling a dozen Insights stat tiles in on open raised the Insights build p90 on the emulator (see `performance.md`); the prompt asks for rolling numbers "for amounts and counts that change". Charts still draw in once, as Kuber.

- `themeAnimationDuration: Duration.zero` (as Kuber): theme changes made on the Theme page go through the ripple. A change that comes from outside, such as the phone switching to dark mode while the app is open or a new wallpaper hue, now applies at once rather than cross-fading for 240 ms. This is Kuber's behaviour; kept.
- Kit primitives built but not yet used, because Unfurl has nothing they replace today: `ShapeLoader` (Unfurl draws no spinner), `AnimatedListItem` and `StaggeredEntrance` (lists use `Reveal`), and `ContainerTransformRoute` (pushes use `unfurlPage`, and covers open through the unfurl transition). They are kept because the prompt asks for each primitive once, with tests; the tree shaker drops them from release builds while unused.

## Part L

- See `bugs.md`. Shared OOXML on/off helper `lib/formats/office/ooxml.dart`. No vendored JS exists to patch.
- Bold label lines (short, all bold) keep with the next block in the reader engine: a heuristic for page breaking only; the block's kind, look and chapters are unchanged.

## Design board deviations (also in `docs/design-gaps.md`)

- `SegmentedToggle` is separate pills with a selection morph, no longer a sliding thumb on a track.
- `NavPill` has one sliding indicator; label weight 500 to 700.
- Selected chip and segment corners are 12 dp.
- The floating pill header (Kuber v7.0.0-c) replaces the boards' fixed header that only restyles on scroll.
