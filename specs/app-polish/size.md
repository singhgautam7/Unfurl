# App size (Part K)

## K1. Before (main, 472937d)

Built from a clean worktree of `main`, 19 November 2026.

| Measure | Bytes | MB |
|---|---|---|
| Release APK arm64 (`--split-per-abi --obfuscate --split-debug-info`) | 31,179,518 | 31.18 |
| Release APK armeabi-v7a | 26,671,694 | 26.67 |
| Release APK x86_64 | 32,991,692 | 32.99 |
| AAB (`appbundle`, arm64 only, `--analyze-size`) | 29,359,221 | 29.36 |
| Play download, arm64 device (`bundletool get-size total`, spec: arm64-v8a, en, 420 dpi, SDK 34) | 16,219,790 | 16.22 |

AAB breakdown (decompressed, from `--analyze-size`): native libs 13 MB (Flutter engine, PDFium, sqlite), Dart AOT 9 MB (package:flutter 3 MB, package:unfurl 2 MB, drift 204 KB, markdown 119 KB, riverpod 113 KB, material_color_utilities 109 KB, go_router 94 KB, xml 78 KB, pdfrx_engine 78 KB), assets 2 MB (fonts: Literata, Instrument Sans, Atkinson Hyperlegible Next, OpenDyslexic; Material Symbols tree-shaken from 15.2 MB to 318 KB), dex 560 KB, res 99 KB.

## K2. Steps

| Step | State | Saving |
|---|---|---|
| 1. Obfuscation | Already on (`--obfuscate --split-debug-info=build/symbols`; symbols stay local, no crash reporting) | 0 (already counted) |
| 2. R8 minify and resource shrink | Already on: Flutter's Gradle plugin turns both on for release builds by default (dex is 1.18 MB); keep rules in `android/app/proguard-rules.pro`; Commons Codec phonetic tables excluded in `build.gradle.kts`. Native libs are stored uncompressed in the APK (checked with `unzip -v`). | 0 (already counted) |
| 3. Fonts | No `google_fonts`, no `http`, nothing fetches fonts (no INTERNET permission). Instrument Sans is already one variable font (B6 not needed). Reading fonts are bundled by design (offline reader). | 0 |
| 4. Unused dependencies and assets | `vector_math` removed (no imports). It stays in the graph through Flutter, so the binary does not change. Every declared asset is referenced (audit A6). 11 unused `AppIcons` constants cost nothing (the icon font is tree-shaken by codepoint). | 0 |
| 5. Heavy packages | None replaceable in this pass: PDFium (pdfrx) and sqlite (drift) are the core of the app. `markdown` (119 KB AOT) is the only optional-looking one; replacing it is not worth it. | n/a |
| 6. Native libraries | `--split-per-abi` for APKs; the AAB serves one ABI per device. Native libs are stored uncompressed (AGP default `useLegacyPackaging = false`), which makes the download a little bigger but the installed size smaller, since nothing is extracted. Kept. | 0 |
| 7. Images | Only `assets/images/mull.png` (small) ships; launcher layers are vectors. Nothing to convert. | 0 |

## K3. After (feature/app-polish, final build)

| Measure | Before | After | Change |
|---|---|---|---|
| Release APK arm64 | 31,179,518 | 31,313,742 | +134,224 (+0.43%) |
| Release APK armeabi-v7a | 26,671,694 | 26,855,070 | +183,376 (+0.69%) |
| Release APK x86_64 | 32,991,692 | 33,125,916 | +134,224 (+0.41%) |
| AAB, arm64 | 29,359,221 | 29,512,154 | +152,933 (+0.52%) |
| Play download, arm64 device | 16,219,790 | 16,296,372 | +76,582 (+0.47%) |

The growth is the motion kit, the floating header, the Look settings and the Part L fixes: new Dart code, no new packages or assets. Step 4 saved nothing measurable, and steps 1, 2, 3, 6 and 7 were already in place. Behaviour check: the full suite passes (248), and the obfuscated, shrunk release build launches on the emulator and opens Home, the Theme page, Settings and the reader without a crash. Symbols stay in `build/symbols` (local; there is no crash reporting).
