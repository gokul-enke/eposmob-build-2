import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../resources/app_url.dart';
import 'preferences_file_guard.dart';
import 'tenant_config_store.dart';

class TenantDomainException implements Exception {
  const TenantDomainException(this.message, {this.serverRejected = true});

  final String message;

  /// True when the tenant directory answered and refused the key. False when
  /// it could not be asked (offline, timeout, server error), which says
  /// nothing about whether a till's saved server is still right.
  final bool serverRejected;

  @override
  String toString() => message;
}

/// Resolves an API key to its tenant server and persists only verified results.
class TenantDomainService {
  const TenantDomainService._();

  static Future<String> discoverDomain(
    String tenantKey, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final normalizedKey = tenantKey.trim();
    if (normalizedKey.isEmpty) {
      throw const TenantDomainException('API key is required.');
    }

    final httpClient = client ?? http.Client();
    final ownsClient = client == null;

    try {
      final response = await httpClient.post(
        Uri.parse(APPUrl.findDomainUrl),
        headers: {
          'X-Tenant-Key': normalizedKey,
          'Accept': 'application/json',
        },
      ).timeout(timeout);

      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) payload = decoded;
      } catch (_) {}

      // A gateway error or captive-portal page is not an answer about the key.
      if (response.statusCode >= 500 || payload == null) {
        throw const TenantDomainException(
          'The CloudPOS server is not responding. Try again shortly.',
          serverRejected: false,
        );
      }

      final apiStatus = payload['status'];
      if (response.statusCode != 200 || apiStatus != 200) {
        final serverMessage = payload['message']?.toString().trim();
        throw TenantDomainException(
          serverMessage == null || serverMessage.isEmpty
              ? 'The API key could not be verified. Check it and try again.'
              : serverMessage,
        );
      }

      final data = payload['data'];
      final rawDomain = data is Map<String, dynamic>
          ? data['domain']?.toString().trim()
          : null;
      if (rawDomain == null || rawDomain.isEmpty) {
        throw const TenantDomainException(
          'No server is configured for this API key. Contact support.',
        );
      }

      final domain =
          rawDomain.startsWith('http://') || rawDomain.startsWith('https://')
              ? APPUrl.normalizeBaseUrl(rawDomain)
              : APPUrl.normalizeBaseUrl('https://$rawDomain');
      final uri = Uri.tryParse(domain);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        throw const TenantDomainException(
          'The server configured for this API key is invalid. Contact support.',
        );
      }

      return domain;
    } on TimeoutException {
      throw const TenantDomainException(
        'Tenant verification timed out. Check your connection and try again.',
        serverRejected: false,
      );
    } on TenantDomainException {
      rethrow;
    } catch (_) {
      throw const TenantDomainException(
        'Unable to verify the API key. Check your connection and try again.',
        serverRejected: false,
      );
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  static Future<String> discoverAndSave(
    String tenantKey, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final normalizedKey = tenantKey.trim();
    final domain = await discoverDomain(
      normalizedKey,
      client: client,
      timeout: timeout,
    );

    // Written first: it survives the crashes and resets that lose preferences.
    await TenantConfigStore.write(
      TenantConfig(apiKey: normalizedKey, appUrl: domain),
    );
    final prefs =
        await PreferencesFileGuard.runWithRepair(SharedPreferences.getInstance);
    await prefs.setString('api_key', normalizedKey);
    await prefs.setString('app_url', domain);
    await prefs.setBool('show_default_domain_warning', false);
    APPUrl.updateBaseURL(domain);
    return domain;
  }
}
