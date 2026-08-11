import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/features/subscription/domain/company_subscription.dart';
import 'package:pos_machine/resources/app_url.dart';

typedef SubscriptionFallbackLoader = Future<CompanySubscription?> Function();

class SubscriptionAccessRegistry {
  SubscriptionAccessRegistry._();

  static CompanySubscription? _current;
  static bool _verificationFailed = true;

  static bool get permitsOrderSubmission =>
      !_verificationFailed && (_current?.permitsOrderSubmission ?? false);

  static CompanySubscription? get current => _current;

  static void update(
    CompanySubscription? subscription, {
    required bool verificationFailed,
  }) {
    _current = subscription;
    _verificationFailed = verificationFailed;
  }

  static Map<String, dynamic>? rejectedOrderResponse() {
    if (permitsOrderSubmission) return null;
    final blocked = _current?.status == CompanySubscriptionStatus.blocked;
    return {
      'status': 'failure',
      'code': blocked ? 'SUBSCRIPTION_BLOCKED' : 'SUBSCRIPTION_UNVERIFIED',
      'message': blocked
          ? _current!.message
          : 'Unable to verify the company subscription. Refresh and try again.',
      'http_status': blocked ? 403 : 503,
    };
  }
}

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  static const _cacheKey = 'company_subscription_cache';
  static const _verifiedAtKey = 'company_subscription_verified_at';

  final http.Client _client;
  final bool _ownsClient;

  CompanySubscription? _subscription;
  DateTime? _lastVerifiedAt;
  String? _errorMessage;
  bool _isLoading = false;
  bool _verificationFailed = true;
  SubscriptionFallbackLoader? _fallbackLoader;

  CompanySubscription? get subscription => _subscription;
  CompanySubscriptionStatus get status => _verificationFailed
      ? CompanySubscriptionStatus.unknown
      : (_subscription?.status ?? CompanySubscriptionStatus.unknown);
  DateTime? get lastVerifiedAt => _lastVerifiedAt;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isVerified => !_verificationFailed && _subscription != null;

  void setFallbackLoader(SubscriptionFallbackLoader loader) {
    _fallbackLoader = loader;
  }

  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final companyId = prefs.getInt('company_id');
    if (token == null || token.isEmpty || companyId == null) {
      await clear(removeCache: false);
      return;
    }

    final cached = CompanySubscription.decode(prefs.getString(_cacheKey));
    final verifiedAtText = prefs.getString(_verifiedAtKey);
    if (cached != null &&
        (cached.companyId == null || cached.companyId == companyId)) {
      _subscription = cached;
      _lastVerifiedAt = DateTime.tryParse(verifiedAtText ?? '');
      // Cache is useful for messaging, but startup still requires a refresh
      // before an order is submitted.
      _verificationFailed = true;
      _syncRegistry();
      notifyListeners();
    }
  }

  Future<bool> applyLoginPayload(dynamic payload) async {
    final parsed = CompanySubscription.tryParsePayload(payload);
    if (parsed == null) return false;
    await _acceptVerified(parsed);
    return true;
  }

  Future<bool> refresh({bool notifyLoading = true}) async {
    if (_isLoading) return isVerified;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final apiKey = prefs.getString('api_key');
    if (token == null || token.isEmpty || apiKey == null || apiKey.isEmpty) {
      _markVerificationFailure(
        'Sign in again to verify the company subscription.',
      );
      return false;
    }

    _isLoading = true;
    if (notifyLoading) notifyListeners();
    try {
      final response = await _client.get(
        Uri.parse(APPUrl.companySubscriptionStatus),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Tenant': apiKey,
        },
      ).timeout(const Duration(seconds: 15));

      dynamic payload;
      try {
        payload = jsonDecode(response.body);
      } catch (_) {
        payload = null;
      }

      final parsed = CompanySubscription.tryParsePayload(payload);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          parsed != null) {
        await _acceptVerified(parsed, notify: false);
        return true;
      }

      if (await _acceptFallbackIfAvailable()) return true;

      final message = payload is Map
          ? payload['message']?.toString()
          : 'Subscription verification failed (HTTP ${response.statusCode}).';
      _markVerificationFailure(
        message?.trim().isNotEmpty == true
            ? message!.trim()
            : 'Unable to verify the company subscription.',
        notify: false,
      );
      return false;
    } catch (_) {
      if (await _acceptFallbackIfAvailable()) return true;
      _markVerificationFailure(
        'Unable to verify the company subscription. Check your connection and try again.',
        notify: false,
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _acceptFallbackIfAvailable() async {
    final loader = _fallbackLoader;
    if (loader == null) return false;
    try {
      final fallback = await loader();
      if (fallback == null) return false;
      await _acceptVerified(fallback, notify: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> refreshIfStale({
    Duration maximumAge = const Duration(minutes: 2),
  }) async {
    final verifiedAt = _lastVerifiedAt;
    if (isVerified &&
        verifiedAt != null &&
        DateTime.now().difference(verifiedAt) <= maximumAge) {
      return true;
    }
    return refresh();
  }

  Future<void> markBlockedFromBackend({
    required String message,
    String? manageSubscriptionUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _subscription;
    await _acceptVerified(
      CompanySubscription(
        companyId: current?.companyId ?? prefs.getInt('company_id'),
        status: CompanySubscriptionStatus.blocked,
        message: message.trim().isEmpty
            ? 'Your company subscription is blocked.'
            : message.trim(),
        validUntil: current?.validUntil,
        manageSubscriptionUrl:
            manageSubscriptionUrl ?? current?.manageSubscriptionUrl,
      ),
    );
  }

  Future<void> clear({bool removeCache = true}) async {
    _subscription = null;
    _lastVerifiedAt = null;
    _errorMessage = null;
    _verificationFailed = true;
    SubscriptionAccessRegistry.update(null, verificationFailed: true);
    if (removeCache) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_verifiedAtKey);
    }
    notifyListeners();
  }

  Future<void> _acceptVerified(
    CompanySubscription subscription, {
    bool notify = true,
  }) async {
    _subscription = subscription;
    _lastVerifiedAt = DateTime.now();
    _errorMessage = null;
    _verificationFailed = false;
    _syncRegistry();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, subscription.encode());
    await prefs.setString(_verifiedAtKey, _lastVerifiedAt!.toIso8601String());
    if (notify) notifyListeners();
  }

  void _markVerificationFailure(String message, {bool notify = true}) {
    _errorMessage = message;
    _verificationFailed = true;
    _syncRegistry();
    if (notify) notifyListeners();
  }

  void _syncRegistry() {
    SubscriptionAccessRegistry.update(
      _subscription,
      verificationFailed: _verificationFailed,
    );
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
    super.dispose();
  }
}
