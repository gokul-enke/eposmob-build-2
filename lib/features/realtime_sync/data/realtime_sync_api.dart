import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_models.dart';
import 'package:pos_machine/resources/app_url.dart';

class RealtimeSyncApi {
  RealtimeSyncApi({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration requestTimeout;

  Future<String> authorizeChannel({
    required RealtimeSyncSession session,
    required String socketId,
  }) async {
    final backend = APPUrl.normalizeBaseUrl(session.backendBaseUrl);
    final response = await _client
        .post(
          Uri.parse('$backend/api/broadcasting/auth'),
          headers: {
            'X-Tenant': session.tenantApiKey,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'socket_id': socketId,
            'channel_name': session.channelName,
          }),
        )
        .timeout(requestTimeout);

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw RealtimeSyncException(
        'Realtime channel authorization failed (${response.statusCode}).',
        terminal: true,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RealtimeSyncException(
        'Realtime channel authorization failed (${response.statusCode}).',
      );
    }
    final decoded = _decodeObject(response.body);
    final auth = decoded['auth']?.toString().trim() ?? '';
    if (auth.isEmpty) {
      throw const RealtimeSyncException(
        'Realtime channel authorization returned no token.',
      );
    }
    return auth;
  }

  Future<SyncChangesResponse> pullChanges({
    required RealtimeSyncSession session,
    String? since,
  }) async {
    final backend = APPUrl.normalizeBaseUrl(session.backendBaseUrl);
    final uri = Uri.parse('$backend/api/v1/sync/changes').replace(
      queryParameters: {
        'since': since?.trim() ?? '',
        'store_id': session.storeId.toString(),
      },
    );
    final response = await _client.get(
      uri,
      headers: {
        'X-Tenant': session.tenantApiKey,
        'Authorization': 'Bearer ${session.accessToken}',
        'Accept': 'application/json',
      },
    ).timeout(requestTimeout);

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw RealtimeSyncException(
        'Realtime changes authorization failed (${response.statusCode}).',
        terminal: true,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RealtimeSyncException(
        'Realtime changes request failed (${response.statusCode}).',
      );
    }
    return SyncChangesResponse.fromJson(_decodeObject(response.body));
  }

  Map<String, dynamic> _decodeObject(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    throw const RealtimeSyncException('Backend returned invalid sync JSON.');
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
