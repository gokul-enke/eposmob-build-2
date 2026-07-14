import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../resources/app_url.dart';

class TenantDomainException implements Exception {
  const TenantDomainException(this.message);

  final String message;

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

      final apiStatus = payload?['status'];
      if (response.statusCode != 200 || apiStatus != 200) {
        final serverMessage = payload?['message']?.toString().trim();
        throw TenantDomainException(
          serverMessage == null || serverMessage.isEmpty
              ? 'The API key could not be verified. Check it and try again.'
              : serverMessage,
        );
      }

      final data = payload?['data'];
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
      );
    } on TenantDomainException {
      rethrow;
    } catch (_) {
      throw const TenantDomainException(
        'Unable to verify the API key. Check your connection and try again.',
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', normalizedKey);
    await prefs.setString('app_url', domain);
    await prefs.setBool('show_default_domain_warning', false);
    APPUrl.updateBaseURL(domain);
    return domain;
  }
}
