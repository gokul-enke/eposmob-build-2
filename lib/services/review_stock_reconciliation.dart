import 'package:pos_machine/features/realtime_sync/data/realtime_entity_api.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_models.dart';
import 'package:pos_machine/features/realtime_sync/domain/sync_operation_gate.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

/// Reconciliation replaces quantities from the server, never increments them.
/// It deliberately does not delete review records or infer an order's outcome.
class ReviewStockReconciliation {
  Future<void> refresh({
    required RealtimeSyncSession session,
    required LocalProductProvider products,
    required bool Function() isCurrent,
    RealtimeEntityApi? api,
  }) async {
    final owner = Object();
    if (!SyncOperationGate.instance.tryAcquire(owner)) {
      throw StateError('Another stock synchronization is in progress.');
    }
    final source = api ?? RealtimeEntityApi();
    try {
      final snapshot = await source.fetchCatalog(session);
      await products.hydrated;
      if (!isCurrent()) throw StateError('The active store has changed.');
      await products.applyRealtimeCatalog(snapshot.products,
          deletedProductIds: snapshot.deletedProductIds, isCurrent: isCurrent);
    } finally {
      if (api == null) source.close();
      SyncOperationGate.instance.release(owner);
    }
  }
}
