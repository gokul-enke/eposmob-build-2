import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/realtime_sync/data/realtime_sync_api.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_models.dart';

void main() {
  const session = RealtimeSyncSession(
    backendBaseUrl: 'https://tenant.example.com',
    companyId: 2,
    storeId: 5,
    tenantApiKey: 'tenant-key',
    accessToken: 'access-token',
  );

  test('pull sends tenant, bearer, store, and cursor', () async {
    late http.Request captured;
    final api = RealtimeSyncApi(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'synced_at': '2026-07-29T08:41:17Z',
            'changes': {
              'customers': {'upserted': [], 'deleted': []},
              'products': {'upserted': [], 'deleted': []},
              'stocks': {'upserted': [], 'deleted': []},
              'orders': {
                'upserted': [9],
                'deleted': []
              },
            },
          }),
          200,
        );
      }),
    );

    final response = await api.pullChanges(
      session: session,
      since: '2026-07-29T08:40:00+00:00',
    );

    expect(captured.headers['X-Tenant'], 'tenant-key');
    expect(captured.headers['Authorization'], 'Bearer access-token');
    expect(captured.url.queryParameters['store_id'], '5');
    expect(
      captured.url.queryParameters['since'],
      '2026-07-29T08:40:00+00:00',
    );
    expect(response.changes.orders.upserted, [9]);
  });

  test('broadcast auth uses matching private company channel', () async {
    late http.Request captured;
    final api = RealtimeSyncApi(
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'auth': 'key:signature'}), 200);
      }),
    );

    final auth = await api.authorizeChannel(
      session: session,
      socketId: '1.2',
    );
    final body = jsonDecode(captured.body) as Map<String, dynamic>;

    expect(auth, 'key:signature');
    expect(captured.headers['X-Tenant'], 'tenant-key');
    expect(body['socket_id'], '1.2');
    expect(body['channel_name'], 'private-company.2.sync');
  });

  test('authorization failures are terminal', () async {
    final api = RealtimeSyncApi(
      client: MockClient((request) async => http.Response('{}', 401)),
    );

    try {
      await api.pullChanges(session: session);
      fail('Expected RealtimeSyncException');
    } on RealtimeSyncException catch (error) {
      expect(error.terminal, isTrue);
    }
  });
}
