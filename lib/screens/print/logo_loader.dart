import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/resources/app_url.dart';

class PrintLogoLoader {
  static final Map<String, ui.Image> _uiMemoryCache = <String, ui.Image>{};
  static final Map<String, Uint8List> _bytesMemoryCache = <String, Uint8List>{};

  static bool _isSupportedRaster(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    try {
      return img.findDecoderForData(bytes) != null;
    } catch (_) {
      return false;
    }
  }

  static Uint8List? _validatedBytes(
    Uint8List bytes, {
    required String tag,
    required String source,
  }) {
    if (_isSupportedRaster(bytes)) return bytes;
    debugPrint(
        '$tag rejected non-raster logo response from $source (${bytes.length} bytes)');
    return null;
  }

  static String resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('logos/')) return '${APPUrl.baseURL}/storage/$url';
    return url.startsWith('/')
        ? '${APPUrl.baseURL}$url'
        : '${APPUrl.baseURL}/$url';
  }

  static Future<Uint8List?> _fetchLogoBytes(String? url,
      {String tag = '[LOGO]'}) async {
    if (url == null || url.trim().isEmpty) return null;
    final fullUrl = resolveUrl(url.trim());
    final isSvg = fullUrl.toLowerCase().endsWith('.svg');
    final pngFallbackUrl = isSvg
        ? fullUrl.replaceFirst(RegExp(r'\.svg$', caseSensitive: false), '.png')
        : null;

    final mem = _bytesMemoryCache[fullUrl];
    if (mem != null && mem.isNotEmpty) {
      final valid = _validatedBytes(mem, tag: tag, source: 'memory cache');
      if (valid != null) return valid;
      _bytesMemoryCache.remove(fullUrl);
    }
    if (pngFallbackUrl != null) {
      final pngMem = _bytesMemoryCache[pngFallbackUrl];
      if (pngMem != null && pngMem.isNotEmpty) {
        final valid =
            _validatedBytes(pngMem, tag: tag, source: 'PNG memory cache');
        if (valid != null) {
          _bytesMemoryCache[fullUrl] = valid;
          return valid;
        }
        _bytesMemoryCache.remove(pngFallbackUrl);
      }
    }

    final cachedFilePath =
        await DocumentConfigProvider.getCachedLogoFilePath(fullUrl) ??
            (pngFallbackUrl != null
                ? await DocumentConfigProvider.getCachedLogoFilePath(
                    pngFallbackUrl,
                  )
                : null);
    if (cachedFilePath != null) {
      try {
        if (!(isSvg && cachedFilePath.toLowerCase().endsWith('.svg'))) {
          final bytes = await File(cachedFilePath).readAsBytes();
          final valid = _validatedBytes(
            bytes,
            tag: tag,
            source: 'local cache $cachedFilePath',
          );
          if (valid != null) {
            _bytesMemoryCache[fullUrl] = valid;
            if (pngFallbackUrl != null) {
              _bytesMemoryCache[pngFallbackUrl] = valid;
            }
            return valid;
          }
        }
      } catch (e) {
        debugPrint('$tag local logo read failed: $e');
      }
    }

    try {
      if (pngFallbackUrl != null) {
        final pngResponse = await http.get(Uri.parse(pngFallbackUrl));
        if (pngResponse.statusCode == 200 && pngResponse.bodyBytes.isNotEmpty) {
          final valid = _validatedBytes(
            pngResponse.bodyBytes,
            tag: tag,
            source: pngFallbackUrl,
          );
          if (valid != null) {
            _bytesMemoryCache[fullUrl] = valid;
            _bytesMemoryCache[pngFallbackUrl] = valid;
            return valid;
          }
        }
      }

      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final valid = _validatedBytes(
          response.bodyBytes,
          tag: tag,
          source: fullUrl,
        );
        if (valid != null) {
          _bytesMemoryCache[fullUrl] = valid;
          return valid;
        }
      }
    } catch (e) {
      debugPrint('$tag network logo fetch failed: $e');
    }
    return null;
  }

  static Future<ui.Image?> loadUiLogo(String? url,
      {String tag = '[LOGO]'}) async {
    if (url == null || url.trim().isEmpty) return null;
    final fullUrl = resolveUrl(url.trim());

    final cached = _uiMemoryCache[fullUrl];
    if (cached != null) return cached;

    final bytes = await _fetchLogoBytes(url, tag: tag);
    if (bytes == null || bytes.isEmpty) return null;

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final fi = await codec.getNextFrame();
      _uiMemoryCache[fullUrl] = fi.image;
      return fi.image;
    } catch (e) {
      debugPrint('$tag ui decode failed: $e');
      return null;
    }
  }

  static Future<pw.MemoryImage?> loadPdfLogo(String? url,
      {String tag = '[LOGO]'}) async {
    final bytes = await _fetchLogoBytes(url, tag: tag);
    if (bytes == null || bytes.isEmpty) return null;
    return decodePdfLogoBytes(bytes, tag: tag);
  }

  @visibleForTesting
  static pw.MemoryImage? decodePdfLogoBytes(
    Uint8List bytes, {
    String tag = '[LOGO]',
  }) {
    if (_validatedBytes(bytes, tag: tag, source: 'PDF decoder') == null) {
      return null;
    }
    try {
      return pw.MemoryImage(bytes);
    } catch (e) {
      debugPrint('$tag PDF logo decode failed: $e');
      return null;
    }
  }
}
