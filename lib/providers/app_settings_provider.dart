import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/subscription/domain/company_subscription.dart';
import 'package:pos_machine/models/get_app_settings.dart';
import 'dart:convert';

import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  AppSettings? _appSettings;
  bool _loading = false;
  bool _lastFetchSucceeded = false;

  AppSettings? get appSettings => _appSettings;
  bool get loading => _loading;
  bool get lastFetchSucceeded => _lastFetchSucceeded;
  bool get isReady => !_loading && _lastFetchSucceeded && _appSettings != null;
  bool get allowOverselling => appSettings?.allowOverselling ?? true;
  bool get multiSaleUnitEnabled => appSettings?.multiSaleUnitEnabled ?? false;
  bool get posAuthenticateClearCart =>
      appSettings?.posAuthenticateClearCart ?? false;
  String get posAuthenticateClearCartKey =>
      appSettings?.posAuthenticateClearCartKey ?? '';

  CompanySubscription? get companySubscriptionFallback {
    final settings = _appSettings;
    if (!_lastFetchSucceeded || settings == null) return null;
    return resolveCompanySubscriptionFallback(settings);
  }

  /// During the temporary rollout, a missing or disabled subscription setting
  /// means enforcement is not enabled for that tenant and normal use continues.
  /// Once enabled, malformed values remain unverifiable instead of failing open.
  static CompanySubscription? resolveCompanySubscriptionFallback(
    AppSettings settings, {
    int? companyId,
  }) {
    if (!settings.companySubscriptionFallbackEnabled) {
      return CompanySubscription(
        companyId: companyId,
        status: CompanySubscriptionStatus.active,
        message: '',
      );
    }
    final subscription = CompanySubscription.fromJson({
      'company_id': companyId,
      'subscription_status': settings.companySubscriptionStatus,
      'message': settings.companySubscriptionMessage,
      'valid_until': settings.companySubscriptionValidUntil,
      'manage_subscription_url': settings.companySubscriptionManageUrl,
    });
    if (subscription.status == CompanySubscriptionStatus.unknown) return null;
    return subscription;
  }

  AppSettingsProvider() {
    fetchAppSettings();
  }

  Future<void> fetchAppSettings() async {
    _loading = true;
    _lastFetchSucceeded = false;
    notifyListeners();
    // debugPrint("fetchAppSettings");
    // Get API key from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('api_key');
    final int? activeStoreId = prefs.getInt('active_store_id');

    if (apiKey == null || apiKey.isEmpty) {
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      final Map<String, String> queryParameters = {};
      if (activeStoreId != null) {
        queryParameters['store_id'] = activeStoreId.toString();
      }
      final url = Uri.parse(APPUrl.getAppSettings)
          .replace(queryParameters: queryParameters);

      // This call sits behind the subscription fallback, which order flows can
      // reach. Without a timeout a stalled connection hangs those flows for as
      // long as the socket stays open.
      final response = await http.get(url, headers: {
        'X-Tenant': apiKey,
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _appSettings = AppSettings.fromJson(data);
        _lastFetchSucceeded = true;
      } else {
        throw Exception('Failed to load app settings');
      }
    } catch (error) {
      debugPrint("Error fetching app settings: $error");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Fetches a fresh tenant-scoped app-settings response and converts the
  /// temporary subscription keys into the canonical subscription model.
  Future<CompanySubscription?> fetchCompanySubscriptionFallback() async {
    await fetchAppSettings();
    final settings = _appSettings;
    if (!_lastFetchSucceeded || settings == null) return null;

    final prefs = await SharedPreferences.getInstance();
    return resolveCompanySubscriptionFallback(
      settings,
      companyId: prefs.getInt('company_id'),
    );
  }
}
