import 'package:shared_preferences/shared_preferences.dart';

/// Reads the tenant API key and active store id that login stores in
/// [SharedPreferences]. Injected into API classes so tests can supply fixed
/// values.
class TenantSession {
  const TenantSession();

  static const apiKeyPreference = 'api_key';
  static const activeStorePreference = 'active_store_id';

  Future<String?> apiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(apiKeyPreference);
    return value == null || value.isEmpty ? null : value;
  }

  Future<int?> activeStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(activeStorePreference);
  }

  /// Standard JSON + bearer + tenant headers.
  static Map<String, String> headers({
    required String accessToken,
    required String apiKey,
  }) =>
      {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'X-Tenant': apiKey,
      };
}
