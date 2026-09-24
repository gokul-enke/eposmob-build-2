import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../helpers/atomic_file.dart';

/// The tenant a till is provisioned for, as confirmed by find-domain.
@immutable
class TenantConfig {
  const TenantConfig({required this.apiKey, required this.appUrl});

  final String apiKey;

  /// Normalized server URL, without a trailing slash.
  final String appUrl;

  Map<String, Object> toJson() => {'api_key': apiKey, 'app_url': appUrl};

  static TenantConfig? fromJson(Object? json) {
    if (json is! Map) return null;
    final apiKey = json['api_key'];
    final appUrl = json['app_url'];
    if (apiKey is! String || apiKey.trim().isEmpty) return null;
    if (appUrl is! String || appUrl.trim().isEmpty) return null;
    return TenantConfig(apiKey: apiKey.trim(), appUrl: appUrl.trim());
  }
}

/// Keeps the till's [TenantConfig] in its own file beside SharedPreferences.
///
/// The preferences file is rewritten on almost every action, so a crash can
/// truncate it, and "Clear local storage" wipes it. This file changes only
/// when the till is provisioned and is replaced atomically, so startup can put
/// a lost API key and server back without asking the user.
class TenantConfigStore {
  const TenantConfigStore._();

  static const String fileName = 'tenant_config.json';

  /// Returns null when nothing is saved or the file cannot be used.
  static Future<TenantConfig?> read({Directory? directory}) async {
    try {
      final file = await _file(directory);
      if (file == null || !await file.exists()) return null;
      return TenantConfig.fromJson(json.decode(await file.readAsString()));
    } catch (error, stackTrace) {
      _report('read', error, stackTrace);
      return null;
    }
  }

  /// Best effort: SharedPreferences stays the working copy, so a failure here
  /// is reported rather than thrown.
  static Future<void> write(TenantConfig config, {Directory? directory}) async {
    try {
      final file = await _file(directory);
      if (file == null) return;
      await writeFileAtomically(
          file, utf8.encode(json.encode(config.toJson())));
    } catch (error, stackTrace) {
      _report('write', error, stackTrace);
    }
  }

  /// Throws on failure: a reset that leaves this file behind would be undone
  /// at the next launch.
  static Future<void> delete({Directory? directory}) async {
    final file = await _file(directory);
    if (file != null && await file.exists()) await file.delete();
  }

  static Future<File?> _file(Directory? directory) async {
    if (directory == null) {
      if (kIsWeb) return null;
      directory = await getApplicationSupportDirectory();
    }
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  static void _report(String action, Object error, StackTrace stackTrace) {
    debugPrint('⚠️ Could not $action tenant config: $error');
    unawaited(Sentry.captureException(error, stackTrace: stackTrace));
  }
}
