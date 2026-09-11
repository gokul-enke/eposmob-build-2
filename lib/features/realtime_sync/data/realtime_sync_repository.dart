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
    required String? updatedFrom,
    required String updatedTo,
    required bool Function() isCurrent,
  }) async {
    if (!changes.hasChanges) return;

    if (changes.hasCatalogChanges && _localProducts.cartItems.isNotEmpty) {
      throw const RealtimeSyncDeferredException(
        'Catalog synchronization is waiting for the active cart to finish.',
      );
    }

    // A large catalog may still be decoding right after launch; do not decide
    // full-vs-delta against a half-loaded baseline.
    await _localProducts.hydrated;
    if (!isCurrent()) return;

    final hasProductBaseline = _localProducts.products.isNotEmpty;
    final hasCustomerBaseline = _customers.allCustomers?.isNotEmpty ?? false;
    final hasStockBaseline = _stocks.allStocks?.isNotEmpty ?? false;
    final canUseRange =
        updatedFrom != null && DateTime.tryParse(updatedFrom) != null;

    RealtimeCatalogSnapshot? catalog;
    if (changes.hasCatalogChanges) {
      catalog = await _entityApi.fetchCatalog(
        session,
        updatedFrom: canUseRange && hasProductBaseline ? updatedFrom : null,
        updatedTo: canUseRange && hasProductBaseline ? updatedTo : null,
      );
      if (!isCurrent()) return;
    }

    if (changes.customers.hasChanges) {
      final customers = await _entityApi.fetchCustomers(
        session,
        updatedFrom: canUseRange && hasCustomerBaseline ? updatedFrom : null,
        updatedTo: canUseRange && hasCustomerBaseline ? updatedTo : null,
      );
      if (!isCurrent()) return;
      await _customers.mergeRealtimeCustomers(
        customers,
        storeId: session.storeId,
        deletedCustomerIds: changes.customers.deleted.toSet(),
      );
      _customerSelection.reconcileWithCustomers(
        _customers.allCustomers ?? const [],
      );
    }

    if (changes.stocks.hasChanges) {
      final stocks = await _entityApi.fetchStocks(
        session,
        updatedFrom: canUseRange && hasStockBaseline ? updatedFrom : null,
        updatedTo: canUseRange && hasStockBaseline ? updatedTo : null,
      );
      if (!isCurrent()) return;
      _stocks.mergeRealtimeStocks(
        stocks,
        deletedStockIds: changes.stocks.deleted.toSet(),
      );
    }

    if (catalog != null && isCurrent()) {
      await _localProducts.mergeRealtimeCatalog(
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
