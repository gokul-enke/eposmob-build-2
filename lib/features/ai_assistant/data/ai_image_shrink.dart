import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../domain/ai_models.dart';

/// Re-encodes a picked or pasted image as a JPEG (quality 85) no larger than
/// [AiUploadLimits.imageEdge] on its longest edge, like the web chat does.
/// Also drops EXIF data such as location. Runs on a background isolate.
/// Throws [FormatException] when the bytes are not a readable image.
Future<Uint8List> shrinkAiImage(Uint8List bytes) => compute(_shrink, bytes);

Uint8List _shrink(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Not an image');
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > AiUploadLimits.imageEdge) {
    final scale = AiUploadLimits.imageEdge / longest;
    image = img.copyResize(image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
        interpolation: img.Interpolation.average);
  }
  // Transparent PNGs get a white background, not black.
  final flat = img.Image(width: image.width, height: image.height)
    ..clear(img.ColorRgb8(255, 255, 255));
  img.compositeImage(flat, image);
  return img.encodeJpg(flat, quality: 85);
}
