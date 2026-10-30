import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

class _JpegRequest {
  const _JpegRequest(this.rgba, this.width, this.height, this.quality);

  final Uint8List rgba;
  final int width;
  final int height;
  final int quality;
}

Uint8List _encodeJpegIsolate(_JpegRequest req) {
  final img.Image image = img.Image.fromBytes(
    width: req.width,
    height: req.height,
    bytes: req.rgba.buffer,
    bytesOffset: req.rgba.offsetInBytes,
    numChannels: 4,
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: req.quality));
}

/// Image decode, sampling and encode helpers built on `dart:ui`.
class ImageService {
  const ImageService._();

  /// Longest side allowed for decoded images (keeps memory bounded).
  static const int maxDecodeDim = 4096;

  /// Longest side of the downscaled copy sampled for color extraction.
  static const int sampleDim = 120;

  /// Decodes [bytes], downscaling so the longest side is at most [maxDim].
  /// Throws if the bytes are not a decodable image.
  ///
  /// Uses [ui.instantiateImageCodec] rather than `ImageDescriptor`, whose
  /// `width`/`height` getters are unsupported on web.
  static Future<ui.Image> decode(Uint8List bytes, {int maxDim = maxDecodeDim}) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.Image decoded;
    try {
      decoded = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
    final ({int w, int h}) size = fitWithin(decoded.width, decoded.height, maxDim);
    if (size.w == decoded.width && size.h == decoded.height) return decoded;
    try {
      return await resize(decoded, size.w, size.h);
    } finally {
      decoded.dispose();
    }
  }

  /// Returns the RGBA pixels of [image] scaled so its longest side is at most
  /// [maxDim], for fast color sampling.
  static Future<Uint8List> sampleRgba(ui.Image image, {int maxDim = sampleDim}) async {
    final ({int w, int h}) size = fitWithin(image.width, image.height, maxDim);
    final ui.Image scaled = await resize(image, size.w, size.h);
    try {
      final ByteData? data = await scaled.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('Could not read image pixels');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      scaled.dispose();
    }
  }

  /// Scales [image] to [w]x[h] (caller owns the returned image).
  static Future<ui.Image> resize(ui.Image image, int w, int h) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final ui.Picture picture = recorder.endRecording();
    try {
      return await picture.toImage(w, h);
    } finally {
      picture.dispose();
    }
  }

  /// Longest-side-fit of [w]x[h] into [maxDim] (never upscales).
  static ({int w, int h}) fitWithin(int w, int h, int maxDim) {
    final int longest = math.max(w, h);
    if (longest <= maxDim) return (w: w, h: h);
    final double scale = maxDim / longest;
    return (w: math.max(1, (w * scale).round()), h: math.max(1, (h * scale).round()));
  }

  /// Longest side of persisted copies and their JPEG quality (0-100).
  static const int storageDim = 800;
  static const int storageQuality = 82;

  /// Downscales [image] to at most [maxDim] and re-encodes it as JPEG for
  /// persistence. Transparency is flattened by the JPEG encoder.
  static Future<Uint8List> encodeForStorage(
    ui.Image image, {
    int maxDim = storageDim,
    int quality = storageQuality,
  }) async {
    final ({int w, int h}) size = fitWithin(image.width, image.height, maxDim);
    final ui.Image scaled = (size.w == image.width && size.h == image.height)
        ? image
        : await resize(image, size.w, size.h);
    try {
      final ByteData? data = await scaled.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('Could not read image pixels');
      final Uint8List rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      return await compute(_encodeJpegIsolate, _JpegRequest(rgba, size.w, size.h, quality));
    } finally {
      if (!identical(scaled, image)) scaled.dispose();
    }
  }

  static Future<Uint8List> encodePng(ui.Image image) async {
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Could not encode PNG');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// Renders [paint] into a PNG of [width]x[height] logical pixels.
  static Future<Uint8List> renderToPng(
    int width,
    int height,
    void Function(ui.Canvas canvas, ui.Size size) paint,
  ) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    paint(canvas, ui.Size(width.toDouble(), height.toDouble()));
    final ui.Picture picture = recorder.endRecording();
    try {
      final ui.Image image = await picture.toImage(width, height);
      try {
        return await encodePng(image);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }
}
