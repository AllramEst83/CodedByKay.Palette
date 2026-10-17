import 'dart:typed_data';

import 'blob_store_web.dart' if (dart.library.io) 'blob_store_io.dart' as impl;

/// Stores persisted (downscaled) board images outside the main JSON state.
///
/// Implementations return an opaque `src` reference that is saved in the JSON
/// and later passed back to [get].
abstract class ImageBlobStore {
  /// Persists [bytes] for the image [id]; returns its `src` reference.
  Future<String?> put(String id, Uint8List bytes);

  /// Loads the bytes behind [src], or null if missing/unreadable.
  Future<Uint8List?> get(String src);

  /// Deletes every stored blob whose `src` is not in [keep].
  Future<void> retainOnly(Set<String> keep);
}

/// Platform default: files on Android, inline base64 data URLs on web.
ImageBlobStore createPlatformBlobStore() => impl.createBlobStore();

/// In-memory store, used by tests.
class MemoryBlobStore implements ImageBlobStore {
  final Map<String, Uint8List> blobs = <String, Uint8List>{};

  @override
  Future<String?> put(String id, Uint8List bytes) async {
    blobs['mem:$id'] = bytes;
    return 'mem:$id';
  }

  @override
  Future<Uint8List?> get(String src) async => blobs[src];

  @override
  Future<void> retainOnly(Set<String> keep) async =>
      blobs.removeWhere((String key, Uint8List _) => !keep.contains(key));
}
