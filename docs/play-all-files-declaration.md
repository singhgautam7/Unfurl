# Play Console: All files access declaration (draft)

**Permission:** `android.permission.MANAGE_EXTERNAL_STORAGE`

**App:** Unfurl (`com.grs.unfurl`), a free, offline document reader for PDF, EPUB, Word, PowerPoint,
spreadsheets, Markdown, text and images.

## Core functionality that needs it

Unfurl's core purpose is to find and open the documents already on the user's phone. Users keep
those documents wherever other apps put them: the Download folder, Documents, WhatsApp Documents
(`Android/media/com.whatsapp/...`), Telegram, Bluetooth transfers and SD cards. The Files tab is a
read-only file browser for those locations, and the optional "Find books across this device" setting
lists every PDF and EPUB on the device in the Library.

The Storage Access Framework cannot provide this on Android 11 and later:

- the system folder picker refuses the root of internal storage and the Download folder itself, so
  a user cannot grant the folders where most documents arrive;
- each folder must be granted one at a time, which cannot cover documents spread across many apps'
  folders;
- MediaStore does not expose documents (PDF, EPUB, DOCX) created by other apps to a reader that did
  not create them.

## How access is used and limited

- **Optional.** The app works fully without it: Library and Files then use folders the user picks
  with the system picker. Access is requested only when the user taps "Allow access" in the Files
  tab, after an in-app explanation of what Android will show. It is never requested at launch.
- **Read only.** Unfurl opens, shares (through a read-only content URI) and shows information about
  files. It never creates, renames, moves, copies or deletes a user's file, and offers no such action
  anywhere in the app.
- **No network.** The app does not declare the `INTERNET` permission, so no file or data can leave
  the device. There are no ads, analytics, accounts or servers.
- **Private app folders.** `Android/data` and `Android/obb` are never read; the app shows that
  Android doesn't allow apps to open them.

## Video / screenshots for review

1. Files tab without access: the privacy card ("Browse every file on your phone. Unfurl has no
   internet access, so nothing can leave your device.").
2. "Allow access" opens the "Next, Android asks" sheet, then Android's All files access page.
3. With access: Quick access (Downloads, Documents, WhatsApp Documents), opening a PDF from Download.
4. Settings › Library and files: the status row and the switch to turn access off.
