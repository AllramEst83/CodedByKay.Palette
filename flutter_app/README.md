# Palette & MoodBoard (Flutter)

Flutter port of the original vanilla web app (since removed; see git history). One codebase ships as an
**Android** app (phones and tablets) and a **web** app. Behavior was ported from the original `js/` sources;
persisted state uses the same `palette-app-state-v1` JSON shape (`version: 1`).

## Features

- **Palette tab**: pick an image (or use the sample), extract 3-10 dominant colors with
  k-means (in an isolate), sort by prominence/luminance/hue, apply themes (pastel, neon,
  muted, vivid, dark) or harmonies (complementary, analogous, triadic, tetradic), tap a
  swatch to copy its HEX, long-press / right-click to use it as the harmony base, export a
  PNG with the swatch strip (or sidebar for narrow images).
- **Mood board, grid mode**: columns, gutter, padding, corner radius, cell ratio (including
  the image's original aspect ratio, masonry style), background presets and a custom color,
  reorder/remove items, extract a palette from the selected image, PNG export (1920 px wide).
- **Mood board, dynamic mode**: free-form 1600x1000 canvas with drag, corner resize,
  selection, bring-to-front, sticky notes (edit, color, delete), extracted-palette cards
  placed beside their source image, keyboard nudging (arrows, Shift for larger steps,
  Escape to deselect), pinch to zoom, PNG export.
- Autosave (400 ms debounce) and restore of settings, images, notes and palettes.
- Web: drag and drop images onto the preview.

## Layouts

Layouts depend on available width, never on the platform:

| Width | Layout |
|---|---|
| < 600 dp | bottom navigation, preview on top, controls in a modal bottom sheet |
| 600-1023 dp | navigation rail; controls in a side panel (landscape) or a collapsible bottom panel (portrait) |
| >= 1024 dp | top tabs, ~380 px control panel on the left, large preview on the right |

## Setup

```sh
cd flutter_app
flutter pub get
```

Requires Flutter 3.47+ (Dart 3.13+). For Android builds accept the SDK licenses once with
`flutter doctor --android-licenses`.

## Run

```sh
flutter run -d chrome      # web
flutter run -d <device>    # Android phone/tablet/emulator
```

## Quality checks

```sh
flutter analyze
flutter test
```

## Build

```sh
flutter build web --release       # static site in build/web
flutter build appbundle --release # build/app/outputs/bundle/release/app-release.aab
```

### Android release signing

Create an upload keystore, copy `android/key.properties.example` to
`android/key.properties` and fill it in (both the keystore and `key.properties` are
git-ignored). Without `key.properties` the release build falls back to the debug key.

In CI (`.github/workflows/flutter.yml`) set the repository secrets
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD` and
`ANDROID_KEY_ALIAS` to sign the bundle.

### Web hosting

`build/web` is a plain static site (any static host: Netlify, Cloudflare Pages, GitHub
Pages, ...). Serve it from the site root, or pass `--base-href /sub/path/` when building for
a sub-path. The PWA manifest and icons are included.

## Project layout

```
lib/
  core/       pure Dart: color math, k-means, themes/harmonies, grid + dynamic layout
  models/     Swatch, board items
  state/      PaletteController, BoardController, persistence
  services/   image decode/encode, picker, export, sample data, blob store (file / inline)
  ui/         theme, responsive shell, Palette and Mood Board pages, painters, widgets
test/         unit, controller, widget, layout-matrix and persistence tests
```

## Notes

- Fonts (JetBrains Mono, Plus Jakarta Sans) are bundled in `assets/fonts` (OFL licensed).
- Persisted board images are downscaled to 800 px and re-encoded as JPEG (quality 82), so
  transparency in persisted copies is flattened. On Android they are stored as files; on web
  they are inline `data:` URLs with a ~4.5 MB soft cap.
- Pasting images from the clipboard is not supported (no clipboard-image API that works on
  both Android and web without heavy native dependencies); use the picker or drag and drop.
