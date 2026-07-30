import 'package:pos_machine/features/realtime_sync/data/realtime_entity_api.dart';
import 'package:pos_machine/features/realtime_sync/domain/realtime_sync_models.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';

class RealtimeSyncRepository {
  RealtimeSyncRepository({
    required RealtimeEntityApi entityApi,
    required LocalProductProvider localProducts,
    required CustomerProvider customers,
    required CustomerSelectionProvider customerSelection,
    required StockProvider stocks,
    required SalesProvider sales,
  })  : _entityApi = entityApi,
        _localProducts = localProducts,
        _customers = customers,
        _customerSelection = customerSelection,
        _stocks = stocks,
        _sales = sales;

  final RealtimeEntityApi _entityApi;
  final LocalProductProvider _localProducts;
  final CustomerProvider _customers;
  final CustomerSelectionProvider _customerSelection;
  final StockProvider _stocks;
  final SalesProvider _sales;

  Future<void> apply({
    required RealtimeSyncSession session,
    required RealtimeChangeSet changes,
    required bool Function() isCurrent,
  }) async {
    if (!changes.hasChanges) return;

    if (changes.hasCatalogChanges && _localProducts.cartItems.isNotEmpty) {
      throw const RealtimeSyncDeferredException(
        'Catalog synchronization is waiting for the active cart to finish.',
      );
    }

    RealtimeCatalogSnapshot? catalog;
    if (changes.hasCatalogChanges) {
      catalog = await _entityApi.fetchCatalog(session);
      if (!isCurrent()) return;
    }

    if (changes.customers.hasChanges) {
      final customers = await _entityApi.fetchCustomers(session);
      if (!isCurrent()) return;
      await _customers.applyRealtimeCustomers(
        customers,
        storeId: session.storeId,
      );
      _customerSelection.reconcileWithCustomers(customers);
    }

    if (changes.stocks.hasChanges) {
      final stocks = await _entityApi.fetchStocks(session);
      if (!isCurrent()) return;
      _stocks.applyRealtimeStocks(stocks);
    }

    if (catalog != null && isCurrent()) {
      await _localProducts.applyRealtimeCatalog(
        catalog.products,
        deletedProductIds: {
          ...catalog.deletedProductIds,
          ...changes.products.deleted,
        },
      );
    }

    if (changes.orders.hasChanges) {
      await _sales.refreshOrdersForRealtime(
        accessToken: session.accessToken,
        storeId: session.storeId,
      );
      if (!isCurrent()) return;
    }
  }
}
