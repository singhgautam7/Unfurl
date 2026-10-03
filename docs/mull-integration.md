# Mull integration

Mull (`com.grs.dictionary`) is the offline dictionary from the same maker. Unfurl links to it in
two places and never depends on it.

## Define in Mull (reader selection, R9)

- The selection toolbar's last action carries Mull's icon (`assets/images/mull.png`).
- Unfurl asks Android whether `com.grs.dictionary` is installed (`Platform.isMullInstalled`,
  backed by a `<queries><package android:name="com.grs.dictionary"/></queries>` entry, so no
  `QUERY_ALL_PACKAGES`).
- Installed: Unfurl sends
  `Intent(ACTION_PROCESS_TEXT).setType("text/plain").setPackage("com.grs.dictionary")` with
  `EXTRA_PROCESS_TEXT` = the selected word and `EXTRA_PROCESS_TEXT_READONLY = true`.
  Mull's `DefineActivity` already declares `PROCESS_TEXT` and `DEFINE` filters ("Define in Mull")
  and shows its word card over the book; nothing changes in Mull.
- Not installed: a reader sheet ("Define … in Mull") with the Play Store button
  (`market://details?id=com.grs.dictionary`, falling back to the web listing).

The HANDOFF imagined a lookup provider that would let Unfurl draw Mull's entry in its own
sheet ("Save to Mull", "Open in Mull"). That needs Mull to export a content provider; until it
does, the PROCESS_TEXT hand-off gives the same result with Mull's own sheet. If Mull adds one,
`defineInMull` in `lib/features/reader/sheets.dart` is the single place to change.

## From the same maker (More)

`MullCard` on More shows Mull's icon, one line, and Get (Play Store) or Open (launch intent),
depending on `mullInstalledProvider`.

## Privacy

Nothing is sent to Mull except the selected word, and only when the reader taps Define. Unfurl
has no network access; the Play Store link opens the Play Store app or a browser.
