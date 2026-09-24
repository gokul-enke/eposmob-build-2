import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/realtime_sync/data/realtime_entity_api.dart';
import 'package:pos_machine/features/realtime_sync/data/realtime_sync_api.dart';
import 'package:pos_machine/features/realtime_sync/data/reverb_client.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_config.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_models.dart';
import 'package:pos_machine/helpers/date_helper.dart';

void main() {
  const session = RealtimeSyncSession(
    backendBaseUrl: 'https://tenant.example.com',
    companyId: 2,
    storeId: 5,
    tenantApiKey: 'tenant-key',
    accessToken: 'access-token',
  );

  test('catalog error envelope cannot be treated as empty stock', () async {
    final api = RealtimeEntityApi(
        client: MockClient((_) async => http.Response(
            '{"status":"failure","message":"Unavailable"}', 200)));
    await expectLater(
        api.fetchCatalog(session), throwsA(isA<RealtimeSyncException>()));
  });

  test('customer delta sends a fixed updated_at_range', () async {
    late http.Request captured;
    final api = RealtimeEntityApi(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
            jsonEncode({'status': 'success', 'data': []}), 200);
      }),
    );

    await api.fetchCustomers(
      session,
      updatedFrom: '2026-08-06T08:00:00Z',
      updatedTo: '2026-08-06T08:01:00Z',
    );

    expect(captured.url.queryParameters['store_id'], '5');
    final expectedFrom =
        DateHelper.normalizeToApiDateTime('2026-08-06T08:00:00Z');
    final expectedTo =
        DateHelper.normalizeToApiDateTime('2026-08-06T08:01:00Z');
    expect(
      captured.url.queryParameters['updated_at_range'],
      '$expectedFrom,$expectedTo',
    );
  });

  test('unsupported customer delta retries once as a full fetch', () async {
    final requests = <http.Request>[];
    final api = RealtimeEntityApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.queryParameters.containsKey('updated_at_range')) {
          return http.Response('{}', 422);
        }
        return http.Response(
            jsonEncode({'status': 'success', 'data': []}), 200);
      }),
    );

    await api.fetchCustomers(
      session,
      updatedFrom: '2026-08-06T08:00:00Z',
      updatedTo: '2026-08-06T08:01:00Z',
    );

    expect(requests, hasLength(2));
    expect(
      requests.first.url.queryParameters,
      contains('updated_at_range'),
    );
    expect(
      requests.last.url.queryParameters,
      isNot(contains('updated_at_range')),
    );
  });

  test('disconnect completes when no socket was created', () async {
    final api = RealtimeSyncApi(
      client: MockClient((request) async => http.Response('{}', 500)),
    );
    final client = ReverbClient(
      config: const RealtimeSyncConfig(
        enabled: false,
        hostOverride: 'localhost',
        appKey: 'test',
        useTls: false,
        port: 8080,
        eventDebounce: Duration(milliseconds: 1),
        maxReconnectDelay: Duration(seconds: 1),
      ),
      api: api,
    );

    await client.disconnect().timeout(const Duration(seconds: 1));
    await client.dispose();
    api.close();
  });
}
