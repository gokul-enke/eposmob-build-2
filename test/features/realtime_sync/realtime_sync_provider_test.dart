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

/// Every pull is deferred, as with a cart open while products changed.
class _CartOpenRepository implements RealtimeSyncRepository {
  int applies = 0;

  @override
  Future<void> apply({
    required RealtimeSyncSession session,
    required RealtimeChangeSet changes,
    required String? updatedFrom,
    required String updatedTo,
    required bool Function() isCurrent,
  }) async {
    applies++;
    throw const RealtimeSyncDeferredException('Cart is open.');
  }

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

  test('a pull deferred for the cart waits for the pending catch-up',
      () async {
    var pulls = 0;
    final api = RealtimeSyncApi(
      client: MockClient((request) async {
        pulls++;
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
    addTearDown(provider.dispose);

    await provider.start(session);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Before: the finally block re-pulled at once, in a tight loop.
    expect(pulls, 1);
    expect(repository.applies, 1);

    // The scheduled pending catch-up (5 s while waiting for the cart) runs.
    await Future<void>.delayed(const Duration(milliseconds: 5200));
    expect(pulls, 2);
    expect(repository.applies, 2);
  });
}
