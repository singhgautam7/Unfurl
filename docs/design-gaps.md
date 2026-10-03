# Design gaps and decisions

Every place the spec (`specs/design/unfurl/project/`) is silent, ambiguous or in conflict with
the build prompt, what was done, and which Mull file it follows.

| # | Phase | Gap | What we did | Followed |
|---|---|---|---|---|
| 1 | 0 | The prompt points at `specs/design/HANDOFF.md`; the bundle puts it at `specs/design/unfurl/project/specs/design/HANDOFF.md`. | Read it there. | — |
| 2 | 0 | The prompt says an ochre seed fallback; HANDOFF decides on Saffron. | Saffron (visual: spec wins). Ochre and Turmeric are not shipped: no screen offers a choice, and unread tokens are deleted. | `unfurl-tokens.js` |
| 3 | 0 | No board shows app appearance controls (light/dark/system, true black, wallpaper colours). The prompt's theme cache needs them. | `AppSettings` holds mode (system), AMOLED (off) and dynamic colour (on). Settings › Appearance › Theme opens Mull's Theme page: Light/Dark/System, True black while dark is active, From your wallpaper, and a preview card. | Mull `theme_screen.dart` |
| 4 | 0 | The pill sits 22dp above the frame edge on the boards; a phone with three-button navigation puts its buttons there. | `bottom = max(22, viewPadding.bottom)`. | Headshorts deviation table |
| 5 | 0 | Home's title is "Good afternoon" on every board. | Follows the clock: morning before 12, afternoon to 17, evening otherwise. | — |
| 6 | 0 | No collapsed header is drawn. | Mull's: title steps to `screenTitle`, bar takes `surface` over a `divider` hairline after 24px of scroll. | Mull `app_header.dart` |
| 7 | 0 | Pill hides on scroll? Tab change by horizontal fling? Boards are silent. | Both kept as Mull ships them (hide past 24px down, return on any up; a fling over 240 px/s moves one tab). | Mull `nav_shell.dart` |
| 8 | 0 | The boards render mono as Noto Sans Mono; the token doc says platform monospace. | Platform monospace. | Mull `typography.dart` |
| 9 | 0 | Selected filter chips: A3 shows a check before "PDF", A2 and A6 (`chip()`) do not. | No check; only the "Include subfolders" toggle carries an icon. | Board 2 `chip()` |
| 10 | 0 | Overflow menu, sheet, icon button and group container differ from Mull (52dp pill rows at 15px with no shadow; sheets on `surfaceContainer` with a top outline, no close button, the `scrim` token; 44dp icon disc; radius 20 groups). | Board values used. | Boards 2 and 3 |
| 11 | 0 | Reduced motion: the token doc says springs go linear at 120ms; Mull's helper uses the 90ms fade for everything. | Mull's single helper (`Motion.of`). | Mull `tokens.dart` |
| 12 | 0 | Launcher and splash icon: concept 1d is "a direction sketch, not final artwork". | Concept 1d as drawn on board 1 (§7), in Saffron light: adaptive vector, a monochrome layer for themed icons, legacy PNGs and a 512px store icon, all from `tool/`. The splash shows the same icon on the cached surface. Final artwork can replace the generator's shapes. | Board 1 §7 |
| 13 | 0 | Placeholders: Home and Library bodies, and the Settings, Folders, About and Licences pages are frames only. | Filled. About, Permissions and Privacy follow Mull's pages (header mark, version, feedback, "Made with ❤ in India"). | Mull `about_screen.dart` |
| 14 | 7 | "First launch hides the nav pill; it fades in after the first file opens." With a folder added and nothing opened, Home pointed at a Library the user could not reach. | The pill also appears once any folder is added. | HANDOFF deviations |
| 15 | 7 | Home with a folder but nothing read yet is not drawn. | An "In your library" shelf of unopened books (cover tiles, as Recent books) until Recent books has entries. | Board 2 A1 shelf |
| 16 | 7 | Page turn (Slide, Fade, None) is not in the reading settings sheet on board 3. | It lives in Settings › Reading defaults. | Board 2 Settings |
| 17 | 7 | The middle margin option reads "Margins" on board 3. | Kept as drawn. | Board 3 |
| 18 | 7 | "Some layout may be simplified" (R5) is drawn under the top bar with the chrome shown. | It rides with the chrome: under the top bar, shown and hidden with it, never over the text while reading; closing it is remembered per document. | Board 3 R5 |
| 19 | 7 | The opening state is drawn for a file; heavy work (PDF to Reader mode, a long EPUB) isn't. | The same `OpeningCard` with a label ("Preparing Reader mode") and a determinate track (pages read, then layout). It appears only past the 250 ms threshold and cross-fades into the content. | Board 4 opening state |
| 20 | 7 | The unfurl's Set phase is a cross-fade on board 1; two text layers showing through each other looked muddy on device. | The reader unrolls opaque (a 60 ms fade as the roll starts) over the lifting page, which keeps fading beneath. Timings unchanged. | Board 1 §6 |
| 21 | 7 | Hyphenation: the boards hyphenate; Flutter breaks at a soft hyphen but draws nothing. | The engine draws the hyphen, hanging into the margin as in hand-set books. | — |
| 22 | 7 | Arriving content (tiles, rows, Home sections, selection toolbar) has no motion on the boards. | `Reveal`: a 220 ms fade with an 8dp rise and 0.98 to 1 scale, staggered 28 ms per tile up to 8; covers fade in over their placeholder as they decode. A plain fade under reduced motion. | Board 1 motion (decelerate) |
| 23 | 7 | Library tiles: board A2 shows cover, track, meta and path on every book. | The track shows on every book tile (empty when new); rows are sized to the tile (18dp row gap). | Board 2 A2 |
| 24 | 7 | DOCX in Reader mode: no rule for where sections break. | A new section at each top-level heading once the current one has body text, so a title never sits alone on its page. | — |
| 25 | 7 | Back in the reader: the boards don't say what system back does with the chrome shown. | Back closes a selection or search first, then leaves the book; the top bar's arrow always leaves. | Kindle, Mull's back rule |
| 26 | 7 | Read aloud sentence boundaries. | Sentences end at . ! ? … plus closing quotes, except after titles (Mr., Mrs., Dr. …) and initials. | — |
| 27 | 7 | Define in Mull (R9) asks for a lookup provider "to be agreed with Mull". | Mull already exports `PROCESS_TEXT` and `DEFINE`; Unfurl sends `PROCESS_TEXT` (read-only) to `com.grs.dictionary` and Mull shows its sheet over the book. Not installed: the Play Store pitch. See `docs/mull-integration.md`. | Mull manifest |
| 28 | 7 | Count wording: "1 readable files". | `readableFiles(n)` pluralises everywhere. | — |
