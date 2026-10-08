import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/features/realtime_sync/data/realtime_sync_api.dart';
import 'package:pos_machine/features/realtime_sync/data/realtime_sync_repository.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_config.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_models.dart';
import 'package:pos_machine/features/realtime_sync/presentation/realtime_sync_provider.dart';
import 'package:pos_machine/providers/sync_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pulls are deferred while a cart is open and products have changed.
class _CartOpenRepository implements RealtimeSyncRepository {
  int applies = 0;
  bool cartOpen = true;

  @override
  Future<void> apply({
    required RealtimeSyncSession session,
    required RealtimeChangeSet changes,
    required String? updatedFrom,
    required String updatedTo,
    required bool Function() isCurrent,
  }) async {
    applies++;
    if (cartOpen) {
      throw const RealtimeSyncDeferredException('Cart is open.');
    }
  }

  int remoteChanges = 0;

  @override
  void noteRemoteChange() => remoteChanges++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const session = RealtimeSyncSession(
    backendBaseUrl: 'https://pos.example.test',
    companyId: 3,
    storeId: 1,
    tenantApiKey: 'tenant',
    accessToken: 'token',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a pull deferred for the cart retries only once an hour',
      (tester) async {
    var pulls = 0;
    final cursors = <String?>[];
    final api = RealtimeSyncApi(
      client: MockClient((request) async {
        pulls++;
        cursors.add(request.url.queryParameters['since']);
        return http.Response(
          jsonEncode({
            'success': true,
            'synced_at': '2026-10-06T12:00:05Z',
            'changes': {
              'products': {
                'upserted': [1],
              },
              'offers': {
                'upserted': [9],
              },
            },
          }),
          200,
        );
      }),
    );
    final repository = _CartOpenRepository();
    final provider = RealtimeSyncProvider(
      repository: repository,
      manualSync: SyncProvider(),
      // No app key: the socket is never opened, only the pull runs.
      config: const RealtimeSyncConfig(appKey: ''),
      api: api,
    );
    try {
      await provider.start(session);
      await tester.pump(const Duration(seconds: 5));
      expect(pulls, 1);
      expect(repository.applies, 1);

      await tester.pump(const Duration(minutes: 59, seconds: 54));
      expect(pulls, 1);

      await tester.pump(const Duration(seconds: 1));
      expect(pulls, 2);
      expect(repository.applies, 2);

      await tester.pump(const Duration(hours: 1));
      expect(pulls, 3);
      expect(repository.applies, 3);
      // Deferred changes keep their original cursor until they are applied.
      expect(cursors, ['', '', '']);

      repository.cartOpen = false;
      // An explicit catch-up can still run without waiting for the hour.
      await provider.catchUp();
      expect(pulls, 4);
      expect(provider.lastSyncedAt, '2026-10-06T12:00:05Z');

      await tester.pump(const Duration(hours: 1));
      expect(pulls, 4);
    } finally {
      provider.dispose();
    }
  });

  testWidgets('hourly cart retry does not delay recovery from a failed pull',
      (tester) async {
    var pulls = 0;
    final api = RealtimeSyncApi(
      client: MockClient((request) async {
        pulls++;
        if (pulls == 2) return http.Response('Unavailable', 503);
        return http.Response(
          jsonEncode({
            'success': true,
            'synced_at': '2026-10-06T12:00:05Z',
            'changes': {
              'products': {
                'upserted': [1],
              },
            },
          }),
          200,
        );
      }),
    );
    final repository = _CartOpenRepository();
    final provider = RealtimeSyncProvider(
      repository: repository,
      manualSync: SyncProvider(),
      config: const RealtimeSyncConfig(appKey: ''),
      api: api,
    );

    try {
      await provider.start(session);
      expect(pulls, 1);

      await provider.catchUp();
      expect(pulls, 2);
      expect(provider.status, RealtimeSyncStatus.retrying);

      await tester.pump(const Duration(seconds: 1));
      expect(pulls, 3);
      expect(repository.applies, 2);

      await tester.pump(const Duration(seconds: 5));
      expect(pulls, 3);
    } finally {
      provider.dispose();
    }
  });
}
