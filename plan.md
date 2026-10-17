# Flutter Port Plan (Android + Web)

Goal: build a Flutter version of the Palette app (palette extractor + mood board) that ships as an Android app and a web app from one codebase.

## Decisions

- The vanilla web app (`index.html`, `js/`, `css/`) stays as is. `AGENTS.md` and `.agents/rules` mandate vanilla web for it, so Flutter does not replace it.
- The Flutter project lives in `flutter_app/` at the repo root. Targets: `android` and `web`.
- Behavior is ported from the existing JS, not redesigned. Persisted JSON keeps the same field names (`version: 1`).
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

- `flutter create` into `flutter_app/` (platforms: android, web); set the app id and name.
- Dependencies: `provider`, `shared_preferences`, `file_picker`, `path_provider`, `image`. Add `desktop_drop` only if a version compatible with `file_picker` resolves (they conflict on `cross_file` at `file_picker` 12+).
- Dark slate/indigo theme matching the current look (see `index.html` Tailwind classes).
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

- One codebase, two layouts:
  - Wide (web): top tabs, a left control panel (~380 px), a large preview on the right.
  - Narrow (Android): bottom navigation, the preview on top, controls in a modal bottom sheet.
- Shared control widgets for both layouts.
- Loading indicators and shimmer placeholders for async work, per the repo UX rules.
- Accessibility: semantic labels, minimum 48 dp touch targets, WCAG contrast (4.5:1 text, 3:1 large text), never color alone to convey state.
- Web extras: drag-and-drop files, paste image from clipboard where feasible.
- Exit criteria: usable at phone, tablet, and desktop widths.

## Phase 7: Packaging and release

- Android: app icon (reuse `assets/icons/color-palette.png`), adaptive icon, release signing, `flutter build appbundle`.
- Web: `flutter build web`, PWA manifest and icons, hosting decision (static host).
- README for `flutter_app/`: setup, run, build.
- Exit criteria: signed AAB and deployable web build produced from CI.

## Risks

- **Web first load.** The Flutter runtime is multi-MB. Mitigation: keep the vanilla app as the lightweight web option.
- **Text rendering differences.** Canvas text in the painters will not match the browser exactly. Mitigation: bundle fonts and compare exports visually.
- **Large images on low-memory devices.** Mitigation: cap decode size, downscale on decode with codec target sizes.
- **K-means is non-deterministic** (random seeding), same as today. Mitigation: injectable `Random` for tests.
- **No existing tests** to compare against. Mitigation: port the logic with golden inputs and outputs captured from the JS.

## Out of scope for the first release

- iOS, desktop targets.
- Sharing to other apps (`share_plus`), cloud sync, accounts.
- Persisting the Palette tab's source image (the current app does not either).
