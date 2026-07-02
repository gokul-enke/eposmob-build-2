import 'dart:convert';

/// Parses standard enkepos API error envelopes for user-facing messages.
class ApiResponseHelper {
  static String messageFromBody(String body, {String fallback = 'Request failed'}) {
    try {
      final decoded = json.decode(body);
      if (decoded is! Map) return fallback;

      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }

      final data = decoded['data'];
      if (data is String && data.trim().isNotEmpty) {
        return data.trim();
      }
      if (data is Map) {
        for (final value in data.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
    } catch (_) {
      // Fall through to fallback.
    }
    return fallback;
  }

  /// Throws [Exception] when HTTP status is not 200 or body `status` is `failed`.
  static void ensureSuccess(
    int statusCode,
    String body, {
    String fallback = 'Request failed',
  }) {
    if (statusCode != 200) {
      throw Exception(messageFromBody(body, fallback: fallback));
    }

    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded['status'] == 'failed') {
        throw Exception(messageFromBody(body, fallback: fallback));
      }
    } catch (e) {
      if (e is Exception) rethrow;
    }
  }
}
