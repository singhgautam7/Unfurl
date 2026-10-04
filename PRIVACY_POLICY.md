# Privacy policy for Unfurl

**Last updated:** 3 October 2026

**Developer:** Gautam Rajeev Singh
**Application:** Unfurl, an offline reader for PDFs, books and documents

---

## 1. Overview

Unfurl is built to be **offline and private**. It reads files that are already on your phone, and everything it remembers about them stays on your phone.

- **No account:** you never sign in or register.
- **No network access:** Unfurl declares no internet permission. It makes no network request, ever.
- **No analytics, tracking or ads:** there are no third-party SDKs of any kind.

## 2. What Unfurl stores, on your phone only

- The folders you chose, and an index of the files inside them (names, sizes, dates)
- Folders you pinned in Files, and the last eight folders you opened there
- For each document you open: your reading position, whether you finished it, and how long you have read (for the time-left estimate)
- Your highlights, notes and bookmarks
- Small cover images for your books
- Your settings (theme, reading font and size, and so on)

None of this leaves your phone. Android's own backup may include it, according to your Android settings.

## 3. Your files

Unfurl only ever **reads** your files. It never edits, moves, renames or deletes them, and offers no action that would.

Without all files access, Unfurl sees only the folders you pick in Android's folder picker and the files you open, and you can remove a folder's access at any time under Folders. If you turn on all files access (below), the Files tab can show any folder on your phone, but Unfurl still only reads, and it never opens `Android/data` or `Android/obb`.

## 4. Permissions

Unfurl has **no internet permission**, so nothing it reads can leave your phone.

| Permission | Purpose |
| :--- | :--- |
| All files access (optional) | Lets the Files tab browse your whole phone, including Download and other apps' document folders, and lets "Find books across this device" list every PDF and EPUB. Asked for only when you tap "Allow access" in Files, never at launch. Turn it off at any time in Android settings or Settings › All files access; Unfurl keeps working with the folders you picked. |
| Storage, read (Android 10 and below) | The same access on older Android versions, which call it by this name. |
| Internet | Not requested. Unfurl cannot reach the network. |

Android describes all files access as letting an app "modify and delete" files. Unfurl uses it only to read.

## 5. Other apps

- **Read aloud** uses the text-to-speech engine installed on your phone. Unfurl sends it only the sentence being read.
- **Define in Mull** hands the word you selected to Mull, a dictionary app from the same developer, if it is installed. Mull is offline too.
- **Open in another app** and **Share** hand the file to the app you choose, through Android.

## 6. Contact

Questions about this policy: singhgautam.dev@gmail.com
