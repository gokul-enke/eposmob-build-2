import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_config.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_models.dart';

void main() {
  group('SyncChangesResponse', () {
    test('parses every supported entity including orders', () {
      final response = SyncChangesResponse.fromJson({
        'success': true,
        'synced_at': '2026-07-29T08:41:17+00:00',
        'changes': {
          'customers': {
            'upserted': [1, '2'],
            'deleted': [3],
          },
          'products': {
            'upserted': [4],
            'deleted': [],
          },
          'stocks': {
            'upserted': [5],
            'deleted': [6],
          },
          'orders': {
            'upserted': [7],
            'deleted': [8],
          },
        },
      });

      expect(response.syncedAt, '2026-07-29T08:41:17+00:00');
      expect(response.changes.customers.upserted, [1, 2]);
      expect(response.changes.products.hasChanges, isTrue);
      expect(response.changes.stocks.deleted, [6]);
      expect(response.changes.orders.upserted, [7]);
      expect(response.changes.orders.deleted, [8]);
    });

    test('keeps missing order group backward compatible', () {
      final response = SyncChangesResponse.fromJson({
        'success': true,
        'synced_at': '2026-07-29T08:41:17Z',
        'changes': {
          'customers': {'upserted': [], 'deleted': []},
          'products': {'upserted': [], 'deleted': []},
          'stocks': {'upserted': [], 'deleted': []},
        },
      });

      expect(response.changes.orders.hasChanges, isFalse);
      expect(response.changes.hasChanges, isFalse);
    });

    test('rejects an invalid server cursor', () {
      expect(
        () => SyncChangesResponse.fromJson({
          'success': true,
          'synced_at': 'not-a-time',
          'changes': <String, dynamic>{},
        }),
        throwsFormatException,
      );
    });
  });

  group('RealtimeDataChanged', () {
    test('parses optional store ID', () {
      final event = RealtimeDataChanged.fromJson({
        'entity': 'order',
        'action': 'updated',
        'id': '1001',
        'company_id': 2,
        'store_id': '5',
        'changed_at': '2026-07-29T08:41:17Z',
      });

      expect(event.entity, 'order');
      expect(event.id, 1001);
      expect(event.companyId, 2);
      expect(event.storeId, 5);
    });
  });

  test('production config derives secure tenant websocket URL', () {
    const config = RealtimeSyncConfig(
      appKey: 'public-key',
      port: 443,
      useTls: true,
    );

    final uri = config.websocketUri('https://tenant.example.com');

    expect(uri.scheme, 'wss');
    expect(uri.host, 'tenant.example.com');
    expect(uri.port, 443);
    expect(uri.path, '/app/public-key');
    expect(uri.queryParameters['protocol'], '7');
  });
}
