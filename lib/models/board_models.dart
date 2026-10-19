import 'dart:ui' as ui;

import 'swatch.dart';

enum BoardMode { grid, dynamic }

BoardMode boardModeFromName(String? name) =>
    name == 'dynamic' ? BoardMode.dynamic : BoardMode.grid;

enum BoardItemKind { image, note, swatchGroup }

/// Common geometry/z-order shared by everything placed on the dynamic board.
abstract class BoardItem {
  BoardItem({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.rotation = 0,
    this.zIndex = 0,
  });

  final String id;
  double x;
  double y;
  double w;
  double h;
  double rotation;
  int zIndex;

  BoardItemKind get kind;
}

/// An item that participates in the shared grid ordering (images and palettes).
abstract class OrderedBoardItem extends BoardItem {
  OrderedBoardItem({
    required super.id,
    required super.x,
    required super.y,
    required super.w,
    required super.h,
    super.rotation,
    super.zIndex,
    required this.order,
  });

  int order;
}

class BoardImage extends OrderedBoardItem {
  BoardImage({
    required super.id,
    required this.name,
    required this.image,
    required super.x,
    required super.y,
    required super.w,
    required super.h,
    super.rotation,
    super.zIndex,
    required super.order,
    this.storedSrc,
  });

  final String name;
  final ui.Image image;

  /// Reference to the persisted downscaled copy (data URL on web, file name on
  /// Android); computed lazily on first save and cached.
  String? storedSrc;

  @override
  BoardItemKind get kind => BoardItemKind.image;

  double get aspect => image.height == 0 ? 1 : image.width / image.height;
}

class SwatchGroup extends OrderedBoardItem {
  SwatchGroup({
    required super.id,
    required this.colors,
    required this.sourceName,
    required super.x,
    required super.y,
    required super.w,
    required super.h,
    super.rotation,
    super.zIndex,
    required super.order,
  });

  final List<Swatch> colors;
  final String sourceName;

  @override
  BoardItemKind get kind => BoardItemKind.swatchGroup;

  double get aspect => h == 0 ? 1 : w / h;
}

class StickyNote extends BoardItem {
  StickyNote({
    required super.id,
    required this.text,
    required super.x,
    required super.y,
    super.w = 180,
    super.h = 180,
    super.rotation,
    super.zIndex,
    this.color = '#fef08a',
    this.textColor = '#1c1917',
  });

  String text;
  String color;
  String textColor;

  @override
  BoardItemKind get kind => BoardItemKind.note;
}

const List<String> defaultNoteColors = <String>[
  '#fef08a',
  '#fecaca',
  '#bbf7d0',
  '#bfdbfe',
  '#e9d5ff',
  '#fed7aa',
];

class BackgroundPreset {
  const BackgroundPreset(this.name, this.hex);

  final String name;
  final String hex;
}

const List<BackgroundPreset> backgroundPresets = <BackgroundPreset>[
  BackgroundPreset('Dark Slate', '#0f172a'),
  BackgroundPreset('Pure Black', '#000000'),
  BackgroundPreset('Clean White', '#ffffff'),
  BackgroundPreset('Warm Stone', '#f5f5f4'),
  BackgroundPreset('Midnight Indigo', '#1e1b4b'),
];
