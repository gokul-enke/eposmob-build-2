import 'package:shared_preferences/shared_preferences.dart';

class ApiHelper {
  /// Get the stored API key from SharedPreferences
  static Future<String?> getApiKey() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_key');
  }

  /// Get headers with API key included
  static Future<Map<String, String>> getHeaders({
    String? accessToken,
    Map<String, String>? additionalHeaders,
  }) async {
    String? apiKey = await getApiKey();
    
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    if (apiKey != null && apiKey.isNotEmpty) {
      headers['X-API-KEY'] = apiKey;
    }

    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  /// Check if API key exists
  static Future<bool> hasApiKey() async {
    String? apiKey = await getApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }

  /// Clear API key (for logout or reset)
  static Future<void> clearApiKey() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_key');
  }
}