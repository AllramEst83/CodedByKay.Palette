import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../core/kmeans.dart';
import '../core/palette_theme.dart';
import '../models/swatch.dart';
import '../services/app_messenger.dart';
import '../services/image_service.dart';
import '../services/sample_data.dart';

/// State for the Palette tab: the source image, extracted colors, and the
/// theme/harmony transform applied on top of them.
class PaletteController extends ChangeNotifier {
  PaletteController({this.extractDebounce = const Duration(milliseconds: 200)});

  /// Delay before re-extracting after the color count slider moves.
  final Duration extractDebounce;

  static const int minCount = 3;
  static const int maxCount = 10;

  ui.Image? image;
  String? imageName;
  List<Swatch> sourceColors = <Swatch>[];
  List<Swatch> displayedColors = <Swatch>[];
  SortMode sortMode = SortMode.prominence;
  int paletteCount = 5;
  bool showHexText = true;
  bool showRgbText = false;
  String? activeTheme;
  String? activeHarmony;
  int baseColorIndex = 0;
  bool loading = false;

  int _token = 0;
  Timer? _debounce;

  bool get hasImage => image != null;

  Swatch? get baseColor =>
      baseColorIndex >= 0 && baseColorIndex < sourceColors.length
          ? sourceColors[baseColorIndex]
          : null;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  int _dominantIndex(List<Swatch> colors) {
    if (colors.isEmpty) return 0;
    int idx = 0;
    for (int i = 0; i < colors.length; i++) {
      if (colors[i].count > colors[idx].count) idx = i;
    }
    return idx;
  }

  void _recompute() {
    final String? theme = activeTheme;
    final String? harmony = activeHarmony;
    if (theme != null) {
      displayedColors = applyTheme(sourceColors, theme);
    } else if (harmony != null) {
      displayedColors =
          applyHarmony(sourceColors, baseColorIndex, harmony, sourceColors.length);
    } else {
      displayedColors = sourceColors;
    }
  }

  Future<List<Swatch>> _extract(ui.Image img, int k) async {
    final Uint8List rgba = await ImageService.sampleRgba(img);
    return compute(extractInIsolate, ExtractRequest(rgba, k, sortMode));
  }

  /// Decodes [bytes] and extracts a palette from the result.
  Future<void> loadBytes(Uint8List bytes, {String? name}) async {
    final int token = ++_token;
    loading = true;
    notifyListeners();
    try {
      final ui.Image img = await ImageService.decode(bytes);
      if (token != _token) return;
      await _applyImage(img, name, token);
      if (token == _token) AppMessenger.show('Palette extracted successfully!');
    } catch (err) {
      if (token != _token) return;
      loading = false;
      notifyListeners();
      AppMessenger.show('Could not read that image: $err', isError: true);
    }
  }

  Future<void> loadSample() async {
    final int token = ++_token;
    loading = true;
    notifyListeners();
    try {
      final ui.Image img = await SampleData.sunset();
      if (token != _token) return;
      await _applyImage(img, 'Sunset sample', token);
      if (token == _token) AppMessenger.show('Sample image loaded!');
    } catch (err) {
      if (token != _token) return;
      loading = false;
      notifyListeners();
      AppMessenger.show('Could not build sample image: $err', isError: true);
    }
  }

  /// Loads an already-decoded image (used by tests and the sample loader).
  Future<void> loadImage(ui.Image img, {String? name}) async {
    final int token = ++_token;
    loading = true;
    notifyListeners();
    await _applyImage(img, name, token);
  }

  Future<void> _applyImage(ui.Image img, String? name, int token) async {
    final List<Swatch> colors = await _extract(img, paletteCount);
    if (token != _token) return;
    image = img;
    imageName = name;
    sourceColors = colors;
    baseColorIndex = _dominantIndex(colors);
    _recompute();
    loading = false;
    notifyListeners();
  }

  /// Updates the target color count immediately and re-extracts after a short
  /// debounce. Results from superseded requests are ignored.
  void setPaletteCount(int count) {
    final int clamped = count.clamp(minCount, maxCount);
    if (clamped == paletteCount) return;
    paletteCount = clamped;
    notifyListeners();
    final ui.Image? img = image;
    if (img == null) return;
    _debounce?.cancel();
    final int token = ++_token;
    _debounce = Timer(extractDebounce, () async {
      try {
        final List<Swatch> colors = await _extract(img, clamped);
        if (token != _token) return;
        sourceColors = colors;
        baseColorIndex = _dominantIndex(colors);
        _recompute();
        notifyListeners();
      } catch (err) {
        if (token != _token) return;
        AppMessenger.show('Could not re-extract colors: $err', isError: true);
      }
    });
  }

  void setSortMode(SortMode mode) {
    sortMode = mode;
    if (sourceColors.isNotEmpty) {
      sourceColors = sortPalette(sourceColors, mode);
      baseColorIndex = _dominantIndex(sourceColors);
      _recompute();
    }
    notifyListeners();
  }

  void setBaseColorIndex(int index) {
    if (index < 0 || index >= sourceColors.length) return;
    baseColorIndex = index;
    if (activeHarmony != null) _recompute();
    notifyListeners();
  }

  void applyThemeByName(String name) {
    activeHarmony = null;
    activeTheme = name == 'original' ? null : name;
    _recompute();
    notifyListeners();
  }

  void applyHarmonyByName(String name) {
    activeTheme = null;
    activeHarmony = name;
    _recompute();
    notifyListeners();
  }

  void setShowHexText(bool value) {
    showHexText = value;
    notifyListeners();
  }

  void setShowRgbText(bool value) {
    showRgbText = value;
    notifyListeners();
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'paletteCountK': paletteCount,
        'sortMode': sortMode.name,
        'showHexText': showHexText,
        'showRgbText': showRgbText,
        'activeTheme': activeTheme,
        'activeHarmony': activeHarmony,
        'baseColorIndex': baseColorIndex,
      };

  /// Restores persisted settings; unknown or invalid values are ignored.
  void applySettings(Map<String, Object?> json) {
    final Object? k = json['paletteCountK'];
    if (k is num) paletteCount = k.toInt().clamp(minCount, maxCount);
    final Object? sort = json['sortMode'];
    if (sort is String) sortMode = sortModeFromName(sort);
    final Object? hex = json['showHexText'];
    if (hex is bool) showHexText = hex;
    final Object? rgb = json['showRgbText'];
    if (rgb is bool) showRgbText = rgb;
    final Object? theme = json['activeTheme'];
    activeTheme = theme is String && themeNames.contains(theme) ? theme : null;
    final Object? harmony = json['activeHarmony'];
    activeHarmony = harmony is String && harmonyNames.contains(harmony) ? harmony : null;
    final Object? base = json['baseColorIndex'];
    if (base is num) baseColorIndex = base.toInt();
    notifyListeners();
  }
}
