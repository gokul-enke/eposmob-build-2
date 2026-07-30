import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/realtime_sync/data/realtime_sync_cursor_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('isolates cursors by company and store', () async {
    const store = RealtimeSyncCursorStore();

    await store.write(
      companyId: 2,
      storeId: 5,
      syncedAt: '2026-07-29T08:41:17Z',
    );
    await store.write(
      companyId: 2,
      storeId: 6,
      syncedAt: '2026-07-29T08:42:17Z',
    );

    expect(
      await store.read(companyId: 2, storeId: 5),
      '2026-07-29T08:41:17Z',
    );
    expect(
      await store.read(companyId: 2, storeId: 6),
      '2026-07-29T08:42:17Z',
    );
    expect(await store.read(companyId: 3, storeId: 5), isNull);
  });
}
