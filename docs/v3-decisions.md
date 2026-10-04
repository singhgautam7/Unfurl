# v3 decisions

Decisions taken while building v3 without stopping for approval. Each says what the prompt, `CLAUDE.md`
or the spec left open (or where they disagreed), what was chosen and why. Items marked **Look at this**
are the ones worth a second opinion.

## Formats

1. **Look at this. Kindle and FB2 are parsed in Dart, not by foliate-js.** The v3 prompt says foliate-js is
   "already bundled for EPUB". It isn't: `CLAUDE.md` records that the WebView plan (foliate-js,
   docx-preview, SheetJS) was dropped, and every format is parsed in Dart into one `ReadingDocument`.
   Bringing a WebView back for Kindle files would split the reader in two (selection, highlights, read
   aloud, motion) and needs a network-capable engine. So MOBI, PRC, AZW, AZW3/KF8, FB2, FBZ and
   HTML/XHTML become `ReadingDocument`s like EPUB and get every Reader feature for free. The MOBI/KF8
   reader (`lib/formats/kindle/mobi.dart`) follows foliate-js's `mobi.js` (MIT, John Factotum): PalmDOC
   and HUFF/CDIC decompression, EXTH metadata, KF8 skeleton/fragment reassembly, `kindle:embed` and
   `kindle:pos` links. Credited on the Licences screen.
2. **Spreads come from the reader engine**, which already lays out two columns from 840dp, not from
   foliate-js (same reason).
3. **Comic archives are read in Kotlin**, as the prompt asks, page by page through the detached
   descriptor (no `/proc/self/fd` reopen):
   - zip and tar: Apache Commons Compress 1.28.0 (Apache-2.0); 7z: Commons Compress plus XZ for Java
     1.10 (0BSD / public domain);
   - rar: junrar 7.5.5 (UnRAR licence: free use for extraction; forbids writing a RAR compressor, which
     Unfurl never does). junrar reads RAR 1.5 to 4.x only; **RAR5 comics show the "unsupported
     variant" state** (no permissively licensed Java RAR5 decoder exists; libarchive would mean
     shipping native code).
   Commons Compress depends on commons-io, commons-lang3 and commons-codec (all Apache-2.0); R8 strips
   what isn't used.
4. **Not supported in v3:** DjVu (only GPL decoders: DjVuLibre), CHM (no permissive Dart or Java
   decoder worth shipping), KFX (Amazon's container; DRMION files show the DRM state, plain KFX the
   unsupported state), Topaz/AZW1 (unsupported state, per spec).
5. **DRM detection**, never removal: EPUB `META-INF/encryption.xml` with any algorithm other than the
   two font-obfuscation ones (IDPF and Adobe), or `rights.xml` / `license.lcpl` → protected; MOBI/AZW
   with the PalmDOC encryption field non-zero → protected; KFX DRMION magic → protected.
6. **Magic bytes decide** for `.prc`, `.azw`, `.azw3`, `.mobi` (BOOKMOBI vs Topaz vs KFX) and for
   comics whose archive type doesn't match the extension (a `.cbr` that is really a zip opens as zip).

## Tracking and Insights

7. **Idle threshold.** The spec says 120 s; the prompt asks for an adaptive threshold (3x the
   document's median time per page or screen, at least 60 s, at most 5 min). Chosen: adaptive once a
   document has a median, and the spec's 120 s before it has one.

## Comfort

8. **Read aloud has no live volume control** (Android `TextToSpeech` takes volume per utterance), so the
   sleep timer's 10 s fade lowers the volume of each sentence spoken in the last 10 s and then pauses.

## Layout and screens

9. **More tab.** The v3 More frames draw Insights above a short "Settings" list. The changelog says
   only that the Insights card "sits at the top of More, above Settings". Chosen: the Insights section
   is added on top and v2's groups stay (Privacy, Permissions, Licences, Mull card), so nothing that
   existed is lost. Logged in `docs/design-gaps.md`.
10. **Settings › Controls** is a new page (volume buttons, invert). The v2 "Volume keys turn pages"
    row moves there from Settings › Reader so the switch lives in one place. Tap zones and swipe rows
    in the frame describe controls Unfurl doesn't have; they aren't added (gap).

## Data

11. **One schema bump for all of v3 (2 → 3)**: `entries.issue` and `documents.issue` (comic issue or
    volume), and `reading_sessions`, `daily_stats`, `book_stats`, `book_days` for tracking. Phases A and C
    share it, so a user upgrading from v2 runs one tested migration. DRM and unsupported variants reuse
    `entries.enriched` (-2 protected, -3 variant), so no column was needed. The migration also clears
    the device row's MediaStore generation, so "Find books across this device" looks again for the new
    formats.
12. **"Open with" for `application/octet-stream`** (VIEW only): file managers often send Kindle, FB2 and
    comic files as a generic stream. The extension then decides; anything else gets the existing
    "can't open" sheet. The system file picker also allows the generic type for the same reason.
13. **Device testing on the owner's phone (OnePlus CPH2723, Android 16)**, which had a release build with
    real data. The profile build is installed over it with `--split-per-abi` (same version code, same
    debug key), so the 2 → 3 migration ran on real data after passing the migration tests. Fixtures
    are pushed to the app's own external files directory (`Android/data/com.grs.unfurl/files/fx`), which
    uninstalling removes, and opened with explicit intents.
14. **Comic page order is decided in Dart** (natural sort of entry names), so it is unit-tested; Kotlin
    returns names in archive order and serves pages by name.
15. **A damaged zip** (no central directory, a cut download) is salvaged by walking its local headers;
    readable pages are copied to the app's cache for that session and deleted on close. Other damaged
    archive types show the damaged state without salvage.

## Comics viewer

16. **Decoding goes through Flutter's image cache**: encoded page bytes cross the channel into a 48 MB
    LRU; `ResizeImage` decodes each page at the size it is drawn (device pixels, never upscaled), on
    the engine's IO thread. The image cache is sized to a quarter of `ActivityManager.memoryClass`
    (64 to 256 MB). Prefetches (±2) are cancellable on both sides: the Kotlin queue serves the newest
    request first and skips prefetches made before the last `comicCancel`.
17. **Thumbnails** are 102 px PNGs in the cache directory, per fingerprint, for the last 40 comics.
