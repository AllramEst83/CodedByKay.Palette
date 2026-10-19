import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/board_models.dart';
import '../models/swatch.dart';
import '../services/app_messenger.dart';
import '../services/blob/blob_store.dart';
import '../services/image_service.dart';
import 'board_controller.dart';
import 'palette_controller.dart';

const String storageKey = 'palette-app-state-v1';
const int storageVersion = 1;

/// Soft cap for the saved JSON; beyond it image sources are dropped.
const int sizeSoftCap = 4718592; // 4.5 MiB

/// Debounced save/restore of palette settings and the mood board, using the
/// same `palette-app-state-v1` JSON shape as the legacy web app.
class AppPersistence {
  AppPersistence({
    required this.palette,
    required this.board,
    required this.prefs,
    required this.blobs,
    this.debounce = const Duration(milliseconds: 400),
  });

  final PaletteController palette;
  final BoardController board;
  final SharedPreferences prefs;
  final ImageBlobStore blobs;
  final Duration debounce;

  Timer? _timer;
  bool _attached = false;
  bool _saving = false;
  bool _dirty = false;
  bool _warnedTooLarge = false;
  bool _restoring = false;

  /// Starts watching the controllers for changes to save.
  void attach() {
    if (_attached) return;
    _attached = true;
    palette.addListener(_schedule);
    board.addListener(_schedule);
  }

  void dispose() {
    _timer?.cancel();
    if (_attached) {
      palette.removeListener(_schedule);
      board.removeListener(_schedule);
    }
  }

  void _schedule() {
    if (_restoring) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  /// Saves now (serialized: a save requested mid-save runs right after it).
  Future<void> flush() async {
    _timer?.cancel();
    if (_saving) {
      _dirty = true;
      return;
    }
    _saving = true;
    try {
      do {
        _dirty = false;
        await _saveOnce();
      } while (_dirty);
    } finally {
      _saving = false;
    }
  }

  // ---- save ---------------------------------------------------------------

  Future<Map<String, Object?>> _snapshot() async {
    final List<BoardImage> images = List<BoardImage>.of(board.images);
    final List<Map<String, Object?>> imageJson = <Map<String, Object?>>[];
    for (final BoardImage item in images) {
      item.storedSrc ??= await _storeImage(item);
      imageJson.add(<String, Object?>{
        'id': item.id,
        'name': item.name,
        'x': item.x,
        'y': item.y,
        'w': item.w,
        'h': item.h,
        'rotation': item.rotation,
        'zIndex': item.zIndex,
        'order': item.order,
        'src': item.storedSrc,
      });
    }
    return <String, Object?>{
      'version': storageVersion,
      'palette': palette.toJson(),
      'moodboard': <String, Object?>{
        ...board.settingsToJson(),
        'images': imageJson,
        'stickyNotes': <Map<String, Object?>>[
          for (final StickyNote n in board.notes)
            <String, Object?>{
              'id': n.id,
              'text': n.text,
              'x': n.x,
              'y': n.y,
              'w': n.w,
              'h': n.h,
              'rotation': n.rotation,
              'zIndex': n.zIndex,
              'color': n.color,
              'textColor': n.textColor,
            },
        ],
        'swatchGroups': <Map<String, Object?>>[
          for (final SwatchGroup g in board.swatchGroups)
            <String, Object?>{
              'id': g.id,
              'colors': g.colors.map((Swatch s) => s.toJson()).toList(),
              'sourceName': g.sourceName,
              'x': g.x,
              'y': g.y,
              'w': g.w,
              'h': g.h,
              'rotation': g.rotation,
              'zIndex': g.zIndex,
              'order': g.order,
            },
        ],
      },
    };
  }

  Future<String?> _storeImage(BoardImage item) async {
    try {
      final Uint8List bytes = await ImageService.encodeForStorage(item.image);
      return await blobs.put(item.id, bytes);
    } catch (err) {
      debugPrint('Could not store image ${item.name}: $err');
      return null;
    }
  }

  Future<void> _saveOnce() async {
    try {
      final Map<String, Object?> snapshot = await _snapshot();
      String payload = jsonEncode(snapshot);
      if (payload.length > sizeSoftCap) {
        final Map<String, Object?> mb = Map<String, Object?>.of(
          snapshot['moodboard']! as Map<String, Object?>,
        );
        mb['images'] = <Map<String, Object?>>[
          for (final Map<String, Object?> i in mb['images']! as List<Map<String, Object?>>)
            <String, Object?>{...i, 'src': null},
        ];
        payload = jsonEncode(<String, Object?>{...snapshot, 'moodboard': mb});
        if (!_warnedTooLarge) {
          _warnedTooLarge = true;
          AppMessenger.show(
            'Board images too large to save — layout saved, re-add images next visit',
            isError: true,
          );
        }
      }
      await prefs.setString(storageKey, payload);
      await _cleanupBlobs(snapshot);
    } catch (err) {
      debugPrint('Persist failed, retrying with reduced payload: $err');
      try {
        final Map<String, Object?> minimal = <String, Object?>{
          'version': storageVersion,
          'palette': palette.toJson(),
          'moodboard': <String, Object?>{
            ...board.settingsToJson(),
            'images': <Object?>[],
            'stickyNotes': <Object?>[],
            'swatchGroups': <Object?>[],
          },
        };
        await prefs.setString(storageKey, jsonEncode(minimal));
      } catch (err2) {
        debugPrint('Could not persist app state: $err2');
      }
    }
  }

  Future<void> _cleanupBlobs(Map<String, Object?> snapshot) async {
    final Map<String, Object?> mb = snapshot['moodboard']! as Map<String, Object?>;
    final Set<String> keep = <String>{
      for (final Map<String, Object?> i in mb['images']! as List<Map<String, Object?>>)
        if (i['src'] is String) i['src']! as String,
    };
    try {
      await blobs.retainOnly(keep);
    } catch (err) {
      debugPrint('Blob cleanup failed: $err');
    }
  }

  // ---- restore ------------------------------------------------------------

  /// Reads the saved state, if any. Corrupt state is cleared. Returns whether
  /// anything was restored.
  Future<bool> restore() async {
    final String? raw = prefs.getString(storageKey);
    if (raw == null) return false;

    final Map<String, Object?> state;
    try {
      final Object? parsed = jsonDecode(raw);
      if (parsed is! Map<String, Object?> || parsed['version'] != storageVersion) return false;
      state = parsed;
    } catch (err) {
      debugPrint('Could not read persisted state, clearing: $err');
      await prefs.remove(storageKey);
      return false;
    }

    _restoring = true;
    try {
      final Object? paletteJson = state['palette'];
      if (paletteJson is Map<String, Object?>) palette.applySettings(paletteJson);
      final Object? mbJson = state['moodboard'];
      if (mbJson is Map<String, Object?>) await _restoreBoard(mbJson);
      return true;
    } catch (err) {
      debugPrint('Persisted state was invalid, clearing: $err');
      await prefs.remove(storageKey);
      return false;
    } finally {
      _restoring = false;
    }
  }

  double _num(Object? v, double fallback) => v is num ? v.toDouble() : fallback;

  Future<void> _restoreBoard(Map<String, Object?> mb) async {
    board.applySettings(mb);

    final Object? images = mb['images'];
    if (images is List<Object?>) {
      for (final Object? entry in images) {
        if (entry is! Map<String, Object?>) continue;
        final Object? src = entry['src'];
        if (src is! String) continue;
        try {
          final Uint8List? bytes = await blobs.get(src);
          if (bytes == null) continue;
          final ui.Image image = await ImageService.decode(bytes);
          board.hydrateImage(BoardImage(
            id: (entry['id'] as String?) ?? 'mb_${board.images.length}',
            name: (entry['name'] as String?) ?? 'Image',
            image: image,
            x: _num(entry['x'], 60),
            y: _num(entry['y'], 60),
            w: _num(entry['w'], 260),
            h: _num(entry['h'], 200),
            rotation: _num(entry['rotation'], 0),
            zIndex: _num(entry['zIndex'], 0).toInt(),
            order: _num(entry['order'], board.images.length + 1).toInt(),
            storedSrc: src,
          ));
        } catch (err) {
          debugPrint('Could not restore image ${entry['name']}: $err');
        }
      }
    }

    final Object? notes = mb['stickyNotes'];
    if (notes is List<Object?>) {
      for (final Object? entry in notes) {
        if (entry is! Map<String, Object?>) continue;
        board.hydrateNote(StickyNote(
          id: (entry['id'] as String?) ?? 'note_${board.notes.length}',
          text: (entry['text'] as String?) ?? '',
          x: _num(entry['x'], 60),
          y: _num(entry['y'], 60),
          w: _num(entry['w'], 180),
          h: _num(entry['h'], 180),
          rotation: _num(entry['rotation'], 0),
          zIndex: _num(entry['zIndex'], 0).toInt(),
          color: (entry['color'] as String?) ?? '#fef08a',
          textColor: (entry['textColor'] as String?) ?? '#1c1917',
        ));
      }
    }

    final Object? groups = mb['swatchGroups'];
    if (groups is List<Object?>) {
      for (final Object? entry in groups) {
        if (entry is! Map<String, Object?>) continue;
        final Object? colors = entry['colors'];
        if (colors is! List<Object?> || colors.isEmpty) continue;
        board.hydrateSwatchGroup(SwatchGroup(
          id: (entry['id'] as String?) ?? 'swatch_${board.swatchGroups.length}',
          colors: <Swatch>[
            for (final Object? c in colors)
              if (c is Map<String, Object?>) Swatch.fromJson(c),
          ],
          sourceName: (entry['sourceName'] as String?) ?? 'image',
          x: _num(entry['x'], 60),
          y: _num(entry['y'], 60),
          w: _num(entry['w'], 180),
          h: _num(entry['h'], 170),
          rotation: _num(entry['rotation'], 0),
          zIndex: _num(entry['zIndex'], 0).toInt(),
          order: _num(entry['order'], board.images.length + board.swatchGroups.length + 1).toInt(),
        ));
      }
    }
    board.finishHydration();
  }
}
