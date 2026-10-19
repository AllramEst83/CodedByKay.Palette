import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'blob_store.dart';

ImageBlobStore createBlobStore() => FileBlobStore();

/// Stores one JPEG file per image in the app documents directory.
class FileBlobStore implements ImageBlobStore {
  static const String _prefix = 'file:';
  Directory? _dir;

  Future<Directory> _directory() async {
    final Directory? cached = _dir;
    if (cached != null) return cached;
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${docs.path}${Platform.pathSeparator}board_images');
    await dir.create(recursive: true);
    return _dir = dir;
  }

  String _safeName(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  @override
  Future<String?> put(String id, Uint8List bytes) async {
    final Directory dir = await _directory();
    final String name = '${_safeName(id)}.jpg';
    await File('${dir.path}${Platform.pathSeparator}$name').writeAsBytes(bytes, flush: true);
    return '$_prefix$name';
  }

  @override
  Future<Uint8List?> get(String src) async {
    if (!src.startsWith(_prefix)) return null;
    final String name = src.substring(_prefix.length);
    if (name.contains('/') || name.contains(r'\') || name.contains('..')) return null;
    final Directory dir = await _directory();
    final File file = File('${dir.path}${Platform.pathSeparator}$name');
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> retainOnly(Set<String> keep) async {
    final Directory dir = await _directory();
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is! File) continue;
      final String name = entity.uri.pathSegments.last;
      if (!keep.contains('$_prefix$name')) {
        await entity.delete();
      }
    }
  }
}
