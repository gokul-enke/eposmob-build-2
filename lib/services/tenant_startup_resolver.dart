import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../resources/app_url.dart';
import 'preferences_file_guard.dart';
import 'tenant_config_store.dart';
import 'tenant_domain_service.dart';

/// Where startup sends the user.
class TenantStartupResult {
  const TenantStartupResult.signIn()
      : needsApiKey = false,
        error = null;

  const TenantStartupResult.apiKey(this.error) : needsApiKey = true;

  final bool needsApiKey;
  final String? error;
}

/// Decides at launch whether a till can go straight to sign-in.
///
/// A provisioned till must not be sent back to the API key screen by anything
/// transient: preferences that lost the tenant are restored from
/// [TenantConfigStore], and an unreachable tenant directory is retried on a
/// later launch. Only a directory that refuses the key asks for a new one.
class TenantStartupResolver {
  const TenantStartupResolver._();

  static Future<TenantStartupResult> resolve({
    Future<String> Function(String apiKey)? discoverAndSave,
    Directory? storeDirectory,
  }) async {
    final discover = discoverAndSave ?? TenantDomainService.discoverAndSave;
    final prefs =
        await PreferencesFileGuard.runWithRepair(SharedPreferences.getInstance);
    final stored = await TenantConfigStore.read(directory: storeDirectory);
    var apiKey = prefs.getString('api_key')?.trim() ?? '';
    var savedUrl = APPUrl.normalizeBaseUrl(prefs.getString('app_url') ?? '');

    if (stored != null &&
        (apiKey.isEmpty || (apiKey == stored.apiKey && savedUrl.isEmpty))) {
      apiKey = stored.apiKey;
      savedUrl = stored.appUrl;
      await prefs.setString('api_key', apiKey);
      await prefs.setString('app_url', savedUrl);
      await prefs.setBool('show_default_domain_warning', false);
      const message = 'Restored tenant configuration missing from preferences';
      debugPrint('⚠️ [Tenant] $message');
      unawaited(Sentry.captureMessage(message, level: SentryLevel.warning));
    }

    // No key: SignInScreen lets the Play reviewer account bootstrap its tenant
    // and routes every other account to API key setup.
    if (apiKey.isEmpty) return const TenantStartupResult.signIn();

    final confirmed = stored != null &&
        stored.apiKey == apiKey &&
        stored.appUrl == savedUrl;
    final isDefaultUrl =
        savedUrl == APPUrl.normalizeBaseUrl(APPUrl.defaultBaseURL);
    final flaggedUnverified =
        prefs.getBool('show_default_domain_warning') ?? false;
    // Builds before July saved the default server when find-domain failed, so
    // an unconfirmed default server may be wrong. Any other saved server came
    // from find-domain.
    final needsVerification = savedUrl.isEmpty ||
        (!confirmed && (flaggedUnverified || isDefaultUrl));

    if (!needsVerification) {
      APPUrl.updateBaseURL(savedUrl);
      if (!confirmed) {
        await TenantConfigStore.write(
          TenantConfig(apiKey: apiKey, appUrl: savedUrl),
          directory: storeDirectory,
        );
      }
      return const TenantStartupResult.signIn();
    }

    try {
      await discover(apiKey);
      return const TenantStartupResult.signIn();
    } on TenantDomainException catch (e) {
      if (e.serverRejected || savedUrl.isEmpty) {
        return TenantStartupResult.apiKey(e.message);
      }
      // Offline or the directory is down: keep the saved server and verify on
      // a later launch instead of blocking the till.
      debugPrint('⚠️ [Tenant] Verification postponed: ${e.message}');
      APPUrl.updateBaseURL(savedUrl);
      return const TenantStartupResult.signIn();
    }
  }
}
