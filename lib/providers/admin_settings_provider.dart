import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSettingsProvider extends ChangeNotifier {
  static const String _logoCacheKey = 'admin_settings_logo_url';
  static const String _logoFileCacheKey = 'admin_settings_logo_file_path';
  static const String _logTag = '[ADMIN_LOGO]';

  String? _logoUrl;
  String? _logoFilePath;
  bool _isLoading = false;

  String? get logoUrl => _logoUrl;
  String? get logoFilePath => _logoFilePath;
  bool get isLoading => _isLoading;
  bool get hasLogo => _logoUrl != null && _logoUrl!.trim().isNotEmpty;
  bool get hasLocalLogo =>
      _logoFilePath != null && _logoFilePath!.trim().isNotEmpty;

  AdminSettingsProvider() {
    _loadCachedLogo();
  }

  Future<void> _loadCachedLogo() async {
    try {
      debugPrint('$_logTag Loading cached logo state');
      final prefs = await SharedPreferences.getInstance();
      final cachedLogo = prefs.getString(_logoCacheKey);
      final cachedLogoFilePath = prefs.getString(_logoFileCacheKey);

      if (cachedLogo != null && cachedLogo.trim().isNotEmpty) {
        _logoUrl = cachedLogo.trim();
        debugPrint('$_logTag Cached logo URL found: $_logoUrl');
      }

      if (cachedLogoFilePath != null && cachedLogoFilePath.trim().isNotEmpty) {
        final logoFile = File(cachedLogoFilePath.trim());
        if (await logoFile.exists()) {
          _logoFilePath = cachedLogoFilePath.trim();
          debugPrint('$_logTag Cached local logo file found: $_logoFilePath');
        } else {
          debugPrint(
            '$_logTag Cached local logo file missing on disk, clearing saved path: $cachedLogoFilePath',
          );
          await prefs.remove(_logoFileCacheKey);
        }
      }

      if ((_logoUrl == null || _logoUrl!.isEmpty) &&
          (_logoFilePath == null || _logoFilePath!.isEmpty)) {
        debugPrint('$_logTag No cached logo available');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('$_logTag Error loading cached admin logo: $e');
    }
  }

  Future<void> fetchAdminSettings() async {
    if (_isLoading) {
      debugPrint(
          '$_logTag fetchAdminSettings skipped because a request is already in progress');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint(
          '$_logTag Fetching admin settings from ${APPUrl.adminSettings}');
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('api_key');
      final accessToken = prefs.getString('access_token');

      if (apiKey == null || apiKey.isEmpty) {
        throw const HttpException('API key not found. Please restart the app.');
      }

      final response = await http.get(
        Uri.parse(APPUrl.adminSettings),
        headers: {
          'X-Tenant': apiKey,
          if (accessToken != null && accessToken.isNotEmpty)
            'Authorization': 'Bearer $accessToken',
        },
      );

      debugPrint(
          '$_logTag Admin settings response code: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to load admin settings. Status code: ${response.statusCode}',
        );
      }

      final Map<String, dynamic> jsonData =
          json.decode(response.body) as Map<String, dynamic>;
      final dynamic rawData = jsonData['data'];
      final extractedLogoUrl = _extractLogoUrl(rawData);
      debugPrint('$_logTag Extracted logo URL: ${extractedLogoUrl ?? 'none'}');

      if (extractedLogoUrl != null && extractedLogoUrl.isNotEmpty) {
        _logoUrl = extractedLogoUrl;
        await prefs.setString(_logoCacheKey, extractedLogoUrl);
        debugPrint('$_logTag Saved remote logo URL to preferences');
        _logoFilePath = await _downloadAndCacheLogo(
          logoUrl: extractedLogoUrl,
          accessToken: accessToken,
          apiKey: apiKey,
        );
        if (_logoFilePath != null && _logoFilePath!.isNotEmpty) {
          await prefs.setString(_logoFileCacheKey, _logoFilePath!);
          debugPrint('$_logTag Saved local logo file path: $_logoFilePath');
        } else {
          debugPrint(
              '$_logTag Logo download did not produce a local file, URL fallback will be used');
        }
      } else {
        debugPrint(
            '$_logTag No logo returned by admin settings, clearing cached branding logo');
        await _clearCachedLogo(prefs);
      }
    } catch (e) {
      debugPrint('$_logTag Error fetching admin settings: $e');
    } finally {
      _isLoading = false;
      debugPrint(
          '$_logTag Fetch completed. Current URL=$_logoUrl, localFile=$_logoFilePath');
      notifyListeners();
    }
  }

  String? _extractLogoUrl(dynamic rawData) {
    if (rawData is! List) {
      debugPrint('$_logTag Admin settings data is not a list');
      return null;
    }

    for (final item in rawData) {
      if (item is! Map<String, dynamic>) {
        debugPrint('$_logTag Skipping non-map admin setting item: $item');
        continue;
      }

      final code = item['code']?.toString().trim().toUpperCase();
      final name = item['name']?.toString().trim().toUpperCase();
      final value = item['value']?.toString().trim();

      debugPrint(
        '$_logTag Inspecting admin setting: code=${code ?? 'null'}, name=${name ?? 'null'}, value=${value ?? 'null'}',
      );

      final isLogoSetting = code == 'LOGO' ||
          code == 'SIDEBAR_LOGO' ||
          name == 'LOGO' ||
          name == 'SIDEBAR LOGO';
      if (!isLogoSetting || value == null || value.isEmpty) {
        continue;
      }

      debugPrint('$_logTag Matching logo setting found in response: $value');
      return _resolveLogoUrl(value);
    }

    debugPrint(
        '$_logTag No supported logo setting found. Expected LOGO or SIDEBAR_LOGO');
    return null;
  }

  String _resolveLogoUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final normalizedBaseUrl = APPUrl.normalizeBaseUrl(APPUrl.baseURL);
    if (value.startsWith('/')) {
      return '$normalizedBaseUrl$value';
    }

    return '$normalizedBaseUrl/$value';
  }

  Future<String?> _downloadAndCacheLogo({
    required String logoUrl,
    required String apiKey,
    String? accessToken,
  }) async {
    try {
      debugPrint('$_logTag Downloading logo file from: $logoUrl');
      final response = await http.get(
        Uri.parse(logoUrl),
        headers: {
          'X-Tenant': apiKey,
          if (accessToken != null && accessToken.isNotEmpty)
            'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        debugPrint(
          '$_logTag Failed to download admin logo. Status code: ${response.statusCode}, bytes=${response.bodyBytes.length}',
        );
        return _logoFilePath;
      }

      final directory = await getApplicationSupportDirectory();
      final logoDirectory = Directory('${directory.path}/epos/admin_branding');
      if (!await logoDirectory.exists()) {
        await logoDirectory.create(recursive: true);
      }

      final extension = _resolveFileExtension(
        contentType: response.headers['content-type'],
        logoUrl: logoUrl,
      );
      final file = File('${logoDirectory.path}/sidebar_logo$extension');
      await file.writeAsBytes(response.bodyBytes, flush: true);

      debugPrint(
        '$_logTag Logo downloaded successfully. Path=${file.path}, bytes=${response.bodyBytes.length}, contentType=${response.headers['content-type']}',
      );

      return file.path;
    } catch (e) {
      debugPrint('$_logTag Error downloading admin logo: $e');
      return _logoFilePath;
    }
  }

  String _resolveFileExtension({
    required String? contentType,
    required String logoUrl,
  }) {
    final normalizedContentType = contentType?.toLowerCase() ?? '';
    if (normalizedContentType.contains('png')) return '.png';
    if (normalizedContentType.contains('jpeg') ||
        normalizedContentType.contains('jpg')) {
      return '.jpg';
    }
    if (normalizedContentType.contains('webp')) return '.webp';

    final uri = Uri.tryParse(logoUrl);
    final path = uri?.path.toLowerCase() ?? logoUrl.toLowerCase();
    if (path.endsWith('.png')) return '.png';
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return '.jpg';
    if (path.endsWith('.webp')) return '.webp';

    return '.png';
  }

  Future<void> _clearCachedLogo(SharedPreferences prefs) async {
    debugPrint('$_logTag Clearing cached logo URL and local file');
    _logoUrl = null;
    _logoFilePath = null;
    await prefs.remove(_logoCacheKey);
    await prefs.remove(_logoFileCacheKey);

    try {
      final directory = await getApplicationSupportDirectory();
      final logoDirectory = Directory('${directory.path}/epos/admin_branding');
      if (await logoDirectory.exists()) {
        await logoDirectory.delete(recursive: true);
        debugPrint(
            '$_logTag Deleted local logo directory: ${logoDirectory.path}');
      }
    } catch (e) {
      debugPrint('$_logTag Error clearing cached admin logo file: $e');
    }
  }

  void clear() {
    debugPrint('$_logTag Provider clear() called');
    _logoUrl = null;
    final existingFilePath = _logoFilePath;
    _logoFilePath = null;
    _isLoading = false;

    if (existingFilePath != null && existingFilePath.trim().isNotEmpty) {
      debugPrint('$_logTag Removing local logo file: $existingFilePath');
      File(existingFilePath).delete().catchError((error) {
        debugPrint('$_logTag Failed to remove local logo file: $error');
      });
    }

    notifyListeners();
  }
}
