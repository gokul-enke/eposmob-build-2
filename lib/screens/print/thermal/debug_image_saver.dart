import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class PrintDebugImageSaver {
  static Future<void> saveKotImage(img.Image image, String paperSize) async {
    if (!kDebugMode) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final debugDir = Directory('${tempDir.path}/kot_debug');

      if (!await debugDir.exists()) {
        await debugDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'kot_${paperSize}_$timestamp.png';
      final filepath = '${debugDir.path}/$filename';

      final pngBytes = img.encodePng(image);
      final file = File(filepath);
      await file.writeAsBytes(pngBytes);

      debugPrint('🖼️ DEBUG: KOT image saved to: $filepath');
      debugPrint('📐 Image size: ${image.width}x${image.height}px');

      final base64File = File('${debugDir.path}/kot_${paperSize}_$timestamp.txt');
      await base64File.writeAsString(base64Encode(pngBytes));
      debugPrint('📝 Base64 saved to: ${base64File.path}');

      await _cleanupOldPngFiles(
        debugDir: debugDir,
        maxPngFiles: 10,
        deleteLogPrefix: '🗑️ Deleted old debug image:',
      );
    } catch (e) {
      debugPrint('⚠️ Error saving debug image: $e');
    }
  }

  static Future<void> saveReceiptImages(
    img.Image imagePart1,
    img.Image imagePart2,
    String paperSize,
  ) async {
    if (!kDebugMode) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final debugDir = Directory('${tempDir.path}/receipt_debug');

      if (!await debugDir.exists()) {
        await debugDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final pngBytesPart1 = img.encodePng(imagePart1);
      final pngBytesPart2 = img.encodePng(imagePart2);

      final filePart1 =
          File('${debugDir.path}/receipt_${paperSize}_${timestamp}_part1.png');
      await filePart1.writeAsBytes(pngBytesPart1);

      final filePart2 =
          File('${debugDir.path}/receipt_${paperSize}_${timestamp}_part2.png');
      await filePart2.writeAsBytes(pngBytesPart2);

      debugPrint('🖼️ DEBUG: Receipt Part1 saved to: ${filePart1.path}');
      debugPrint('🖼️ DEBUG: Receipt Part2 saved to: ${filePart2.path}');
      debugPrint(
          '📐 Part1 size: ${imagePart1.width}x${imagePart1.height}px, Part2 size: ${imagePart2.width}x${imagePart2.height}px');

      final base64Part1 =
          File('${debugDir.path}/receipt_${paperSize}_${timestamp}_part1.txt');
      await base64Part1.writeAsString(base64Encode(pngBytesPart1));

      final base64Part2 =
          File('${debugDir.path}/receipt_${paperSize}_${timestamp}_part2.txt');
      await base64Part2.writeAsString(base64Encode(pngBytesPart2));

      debugPrint('📝 Base64 Part1 saved to: ${base64Part1.path}');
      debugPrint('📝 Base64 Part2 saved to: ${base64Part2.path}');

      await _cleanupOldPngFiles(
        debugDir: debugDir,
        maxPngFiles: 10,
        deleteLogPrefix: '🗑️ Deleted old debug receipt image:',
      );
    } catch (e) {
      debugPrint('⚠️ Error saving receipt debug images: $e');
    }
  }

  static Future<void> _cleanupOldPngFiles({
    required Directory debugDir,
    required int maxPngFiles,
    required String deleteLogPrefix,
  }) async {
    final images =
        debugDir.listSync().where((f) => f.path.endsWith('.png')).toList();
    debugPrint('📁 Total debug images: ${images.length}');

    if (images.length > maxPngFiles) {
      images.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      for (var i = 0; i < images.length - maxPngFiles; i++) {
        await images[i].delete();
        debugPrint('$deleteLogPrefix ${images[i].path}');
      }
    }
  }
}
