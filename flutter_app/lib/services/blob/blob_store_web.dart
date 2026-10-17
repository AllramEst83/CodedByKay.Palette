import 'dart:convert';
import 'dart:typed_data';

import 'blob_store.dart';

ImageBlobStore createBlobStore() => InlineBlobStore();

/// Keeps images inline in the saved JSON as `data:` URLs (the legacy format).
class InlineBlobStore implements ImageBlobStore {
  static const String _prefix = 'data:image/jpeg;base64,';

  @override
  Future<String?> put(String id, Uint8List bytes) async => '$_prefix${base64Encode(bytes)}';

  @override
  Future<Uint8List?> get(String src) async {
    if (!src.startsWith(_prefix)) return null;
    try {
      return base64Decode(src.substring(_prefix.length));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> retainOnly(Set<String> keep) async {}
}
