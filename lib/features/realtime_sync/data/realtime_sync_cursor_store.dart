import 'package:shared_preferences/shared_preferences.dart';

class RealtimeSyncCursorStore {
  const RealtimeSyncCursorStore();

  String _key({required int companyId, required int storeId}) =>
      'realtime_sync_cursor_${companyId}_$storeId';

  Future<String?> read({
    required int companyId,
    required int storeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(companyId: companyId, storeId: storeId));
  }

  Future<void> write({
    required int companyId,
    required int storeId,
    required String syncedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(companyId: companyId, storeId: storeId),
      syncedAt,
    );
  }

  Future<void> clear({
    required int companyId,
    required int storeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(companyId: companyId, storeId: storeId));
  }
}
