# Flutter Port Plan (Android + Web)

Goal: build a Flutter version of the Palette app (palette extractor + mood board) that ships as an Android app and a web app from one codebase. Targets are Android and web only. Supported devices are Android phones and Android tablets; the web build runs in the browser.

## Decisions

- The original vanilla web app has been removed from the repo (it remains in git history, before the "Remove legacy vanilla web app" commit). `.agents/rules` holds the Flutter development rules.
- The Flutter project lives at the repo root. Targets: `android` and `web`.
- Behavior is ported from the existing JS, not redesigned. Persisted JSON keeps the same field names (`version: 1`).
- Platforms: Android and web only. Devices: Android phones and Android tablets. Tablets are a first-class target, not an afterthought. Layouts are chosen by available width, not by device type, so split-screen, foldables, and rotation work too.
- Fallback if Flutter proves too costly: wrap the existing web app with Capacitor or a PWA/TWA for Android only.

## Source-to-target map

| Existing JS | Flutter target |
|---|---|
| `color.js` | `lib/core/color_utils.dart` |
| `kmeans.js` | `lib/core/kmeans.dart`, run in an isolate via `compute` |
| `palette-theme.js` | `lib/core/palette_theme.dart` |
| `palette.js` (state, composite canvas) | `PaletteController` + `PaletteCompositePainter` |
| `moodboard-state.js`, `moodboard.js` | `BoardController` |
| `moodboard-grid.js` | `GridLayout` + `BoardPainter` |
| `moodboard-dynamic.js` | `DynamicBoardView` (`Stack` + gestures) |
| `moodboard-extract.js` | `BoardController.extractPaletteFor(item)` |
| `download.js` | PNG export via `PictureRecorder` + `file_picker.saveFile` |
| `storage.js` | `shared_preferences` + image blob store |
| `sample-data.js` | `SampleData` (`dart:ui` canvas) |

## Phase 0: Scaffold and tooling

- `flutter create` at the repo root (platforms: android, web); set the app id and name.
- Dependencies: `provider`, `shared_preferences`, `file_picker`, `path_provider`, `image`. Add `desktop_drop` only if a version compatible with `file_picker` resolves (they conflict on `cross_file` at `file_picker` 12+).
- Dark slate/indigo theme matching the original look (Tailwind slate/indigo).
- Add `analysis_options.yaml` lints. Set up a CI workflow: `flutter analyze`, `flutter test`, `flutter build web`.
- Exit criteria: empty app builds for web and runs on an Android emulator; CI is green.

## Phase 1: Core logic (pure Dart) with tests

- Port color math, k-means (k-means++ seeding, injectable `Random` for deterministic tests), sort modes, themes, and harmonies.
- Port grid and masonry layout (`layoutGridCells`) as a pure function.
- Unit tests: color round-trips, k-means on known pixel sets, theme and harmony outputs, layout dimensions for every ratio including `original`.
- Exit criteria: all core tests pass without any UI.

## Phase 2: Palette tab

- Image pick, decode, and downscale (cap ~4096 px); sample image generator.
- `PaletteController`: count, sort, theme, harmony, base color, hex/RGB label toggles. Debounce re-extraction on slider changes and ignore stale results.
- Swatch grid with tap to copy and long-press to set harmony base.
- Composite painter ported from `palette.js` (below-strip and sidebar layouts), used for both on-screen display and export.
- PNG export. Bundle JetBrains Mono and Plus Jakarta Sans as assets instead of using a CDN.
- Exit criteria: feature parity with the Palette tab on web and Android.

## Phase 3: Mood board, grid mode

- Multi-image add, board item strip (select, reorder, remove), clear board, sample board.
- Grid settings: columns, gutter, padding, radius, ratio, background (presets plus a custom color picker).
- Grid painter (1920 px base width) shared by display and export.
- Extract palette from the selected image into a swatch group.
- Exit criteria: grid-mode parity, exports match on-screen output.

## Phase 4: Mood board, dynamic mode

- Free-form 1600x1000 logical canvas with drag, corner resize, selection, bring-to-front, and clamping.
- Sticky notes: add, edit text, color, delete. Swatch groups placed next to the source image with collision avoidance (`computeAdjacentPosition`).
- Keyboard nudge on web (arrows, Shift for larger steps, Escape to deselect).
- Dynamic board painter for export.
- Exit criteria: dynamic-mode parity, touch and mouse both work.

## Phase 5: Persistence

- Debounced save (400 ms) of palette settings and board state under the `palette-app-state-v1` schema.
- Image blob store with conditional imports:
  - Android: files in the app documents directory.
  - Web: base64 inline, with the same ~4.5 MB soft cap and "images too large to save" toast.
- Persisted copies downscaled to 800 px and re-encoded as JPEG (q 0.82).
- Corrupt-state handling: clear and continue.
- Exit criteria: restart the app and the board and settings are restored.

## Phase 6: Responsive UI for web and Android

- One codebase, three layouts, chosen with `LayoutBuilder` on available width (not platform):
  - Wide (>= ~1024 dp, large tablets in landscape and wide browser windows): top tabs, a left control panel (~380 px), a large preview on the right.
  - Medium (~600-1023 dp, tablets, including portrait): navigation rail, the preview taking most of the space, controls in a collapsible side panel (~320 px) or a persistent bottom panel in portrait, so the sheet does not cover the preview.
  - Narrow (< 600 dp, phones): bottom navigation, the preview on top, controls in a modal bottom sheet.
- Shared control widgets for all layouts.
- Tablet specifics: handle rotation and window resize without losing state (board, selection, scroll); touch-first targets plus stylus and keyboard/mouse input; mood board dynamic canvas scales to use the larger screen; no layout assumes a fixed orientation (remove any Android orientation lock).
- Loading indicators and shimmer placeholders for async work, per the repo UX rules.
- Accessibility: semantic labels, minimum 48 dp touch targets, WCAG contrast (4.5:1 text, 3:1 large text), never color alone to convey state.
- Web extras: drag-and-drop files, paste image from clipboard where feasible.
- Test on Android phone (~360x800) and tablet (7-8" and 10-12", both orientations) emulators/devices, plus split-screen. The web build is checked in a browser at the same widths and a wide window; no other devices are targeted.
- Exit criteria: usable on Android phones and tablets and in the web build, with no overflow or state loss on rotation or resize.

## Phase 7: Packaging and release

- Android: app icon (reuse `assets/icons/color-palette.png`), adaptive icon, release signing, `flutter build appbundle`. Declare tablet support in the manifest (no `required` restriction on screen size, resizable activity, all orientations) and prepare tablet screenshots for the store listing.
- Web: `flutter build web`, PWA manifest and icons, hosting decision (static host).
- README for the project: setup, run, build.
- Exit criteria: signed AAB and deployable web build produced from CI.

## Risks

- **Web first load.** The Flutter runtime is multi-MB. Mitigation: keep the vanilla app as the lightweight web option.
- **Text rendering differences.** Canvas text in the painters will not match the browser exactly. Mitigation: bundle fonts and compare exports visually.
- **Large images on low-memory devices.** Mitigation: cap decode size, downscale on decode with codec target sizes.
- **K-means is non-deterministic** (random seeding), same as today. Mitigation: injectable `Random` for tests.
- **No existing tests** to compare against. Mitigation: port the logic with golden inputs and outputs captured from the JS.

## Out of scope for the first release

- iOS/iPadOS, Windows/macOS/Linux desktop apps, and any other devices. Only Android phones and tablets, plus the web build, are supported.
- Sharing to other apps (`share_plus`), cloud sync, accounts.
- Persisting the Palette tab's source image (the current app does not either).
