# v3 checklist

Scope: `specs/design/HANDOFF.md` › "v3 changelog" and board 6 (`Unfurl 6 v3 Reading Update.dc.html`).
Decisions: `docs/v3-decisions.md`. Gaps: `docs/design-gaps.md` › v3.

| ID | Summary | Files touched | Status | Device-verified |
|---|---|---|---|---|
| V3-FORMATS | MOBI, PRC, AZW, AZW3/KF8, FB2, FBZ, HTML/XHTML in Reader view; CBZ/CBR/CB7/CBT in Comics; DRM, damaged and unsupported states; family chips; extension badges; index migration | `formats/kindle/mobi.dart`, `formats/fb2/fb2.dart`, `formats/text/text_formats.dart` (HTML), `formats/tag_soup.dart`, `formats/charsets.dart`, `formats/books.dart`, `formats/format_problem.dart`, `formats/format_registry.dart` (modules, families, `sniff`, badges), `formats/comics/comic_archive.dart`, `android/.../Comics.kt`, `MainActivity.kt`, `Scanner.kt`, `AndroidManifest.xml`, `core/db/database.dart` (schema 3), `core/library/{library,enrich}.dart`, `features/viewer/document_screen.dart` (`problemState`), `design_system/{covers,states}.dart` (`FormatBadge`, detail box), Library chips, folder rows, licences | done | Phone (CPH2723): MOBI, AZW3, FB2, FBZ, HTML, CBZ open; DRM EPUB and AZW, Topaz, RAR 5 and damaged states shown; badges on Home and Library; single-family chip row hidden |
| V3-COMICS | Comics viewer: single, spread, webtoon; fits; RTL; zoom; scrubber with thumbnails; settings and bookmarks sheets | | todo | |
| V3-TRACKING | `ReadingSessionTracker`: active and listening time, idle, sessions, forward-only progress, aggregates, personal estimates (foundation for Insights) | | todo | |
| V3-INSIGHTS | More tab Insights card; Insights screen with every module; empty, sparse and loading states | | todo | |
| V3-BOOK-INSIGHTS | "Insights" third in every book menu; sheet (phone) and 400dp side panel (expanded) | | todo | |
| V3-HIGHLIGHT-CARDS | "Share as card" from highlight menu, Notes overflow, selection overflow; editor; auto-fit; PNG export; share and save | | todo | |
| V3-COMFORT | Sleep timer, auto-scroll, auto page turn, volume buttons (Settings › Controls) | | todo | |
| V3-TABLET | Size classes, nav rail on expanded, 3/5/7 grids, side panels, two-column Insights, spreads, rotation keeps state | | todo | |
