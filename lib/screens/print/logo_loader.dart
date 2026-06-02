import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/resources/app_url.dart';

class PrintLogoLoader {
  static final Map<String, ui.Image> _uiMemoryCache = <String, ui.Image>{};
  static final Map<String, Uint8List> _bytesMemoryCache = <String, Uint8List>{};

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
    if (mem != null && mem.isNotEmpty) return mem;
    if (pngFallbackUrl != null) {
      final pngMem = _bytesMemoryCache[pngFallbackUrl];
      if (pngMem != null && pngMem.isNotEmpty) {
        _bytesMemoryCache[fullUrl] = pngMem;
        return pngMem;
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
          if (bytes.isNotEmpty) {
            _bytesMemoryCache[fullUrl] = bytes;
            if (pngFallbackUrl != null) {
              _bytesMemoryCache[pngFallbackUrl] = bytes;
            }
            return bytes;
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
          _bytesMemoryCache[fullUrl] = pngResponse.bodyBytes;
          _bytesMemoryCache[pngFallbackUrl] = pngResponse.bodyBytes;
          return pngResponse.bodyBytes;
        }
      }

      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        _bytesMemoryCache[fullUrl] = response.bodyBytes;
        return response.bodyBytes;
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
    return pw.MemoryImage(bytes);
  }
}
