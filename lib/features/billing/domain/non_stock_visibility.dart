import 'package:flutter/widgets.dart';
import 'package:pos_machine/features/billing/domain/product_variant_selection.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:provider/provider.dart';

/// Pure visibility rules for the `POS_HIDE_NONSTOCK_PRODUCT` app setting.
///
/// When a tenant enables this setting, anything that reports no available
/// quantity disappears from the POS: products in the catalog grids/search,
/// individual stock rows in the stock-selection modal, and zero-stock
/// variants in the variant picker.
///
/// The rules only apply when stock tracking is on (`GeneralSettings
/// .stockEnabled`). With stock tracking off, quantities are not maintained,
/// so every row would look like zero and the whole catalog would vanish.
/// Both flags must therefore be true before anything is hidden — everything
/// here fails open.
class NonStockVisibility {
  const NonStockVisibility._();

  /// True when out-of-stock items must be hidden from POS listings.
  ///
  /// [hideNonStockProduct] comes from `AppSettings.posHideNonStockProduct`
  /// and [stockEnabled] from `GeneralSettings.stockEnabled`.
  static bool isActive({
    required bool hideNonStockProduct,
    required bool stockEnabled,
  }) =>
      hideNonStockProduct && stockEnabled;

  /// Available quantity across [stocks], treating null quantities as zero.
  static num totalQuantity(Iterable<Stock>? stocks) {
    if (stocks == null) return 0;
    num total = 0;
    for (final stock in stocks) {
      total += stock.quantity ?? 0;
    }
    return total;
  }

  /// Stock rows that still carry sellable quantity.
  ///
  /// Used for both the stock-selection modal rows and the "does this product
  /// have any stock at all" product-level check, so a product and its rows can
  /// never disagree about what is available.
  static List<Stock> visibleStocks(Iterable<Stock>? stocks) {
    if (stocks == null) return const <Stock>[];
    return stocks
        .where((stock) => (stock.quantity ?? 0) > 0)
        .toList(growable: false);
  }

  /// Variants that still carry sellable quantity.
  ///
  /// A null [ProductVariant.quantity] means the backend does not track stock
  /// at variant level, so those variants stay visible.
  static List<ProductVariant> visibleVariants(
    Iterable<ProductVariant>? variants,
  ) {
    if (variants == null) return const <ProductVariant>[];
    return variants
        .where((variant) => variant.quantity == null || variant.quantity! > 0)
        .toList(growable: false);
  }

  /// Whether [product] should remain visible in POS listings.
  ///
  /// A product is hidden when it has stock rows but none of them carry
  /// quantity, or — for variant products — when every active variant is out
  /// of stock. Products that carry no stock rows at all are left visible:
  /// that means stock was never recorded for them rather than sold out, and
  /// the existing add-to-cart flow already falls back to base pricing.
  static bool isProductVisible(
    GetProduct product, {
    int? activeStoreId,
  }) {
    if (product.hasVariants) {
      final activeVariants = ProductVariantSelection.activeVariantsForStore(
        product,
        activeStoreId: activeStoreId,
      );
      // Variant products with no active variants are already rejected by the
      // add-to-cart flow; leave that messaging untouched.
      if (activeVariants.isEmpty) return true;
      return visibleVariants(activeVariants).isNotEmpty;
    }

    final stocks = product.stock;
    if (stocks == null || stocks.isEmpty) return true;

    // Only judge the rows the active store can actually sell, so stock held
    // by another branch never keeps a sold-out product on screen.
    final scopedStocks = LocalProductProvider.filterStocksForStore(
      LocalProductProvider.filterStocksForVariant(stocks, null),
      activeStoreId: activeStoreId,
    );
    if (scopedStocks.isEmpty) return true;

    return visibleStocks(scopedStocks).isNotEmpty;
  }

  /// Filters [products] down to the ones that should stay visible.
  ///
  /// Returns the list unchanged when the feature is inactive, so callers can
  /// wrap existing lists without branching.
  static List<GetProduct> filterProducts(
    List<GetProduct> products, {
    required bool hideNonStockProduct,
    required bool stockEnabled,
    int? activeStoreId,
  }) {
    if (!isActive(
      hideNonStockProduct: hideNonStockProduct,
      stockEnabled: stockEnabled,
    )) {
      return products;
    }
    return products
        .where((product) =>
            isProductVisible(product, activeStoreId: activeStoreId))
        .toList(growable: false);
  }

  /// Reads the active store id without requiring [StoreSessionProvider] to be
  /// present. Isolated tests and legacy embedding trees may not expose store
  /// session state; unscoped stock stays valid in that case.
  static int? activeStoreIdOf(BuildContext context) {
    try {
      return Provider.of<StoreSessionProvider>(context, listen: false)
          .activeStore
          ?.storeId;
    } on ProviderNotFoundException catch (_) {
      return null;
    }
  }

  /// Whether out-of-stock items must be hidden, for widgets that may be built
  /// outside a [LocalProductProvider] scope (isolated widget tests).
  static bool isEnabledIn(BuildContext context, {bool listen = true}) {
    try {
      return listen
          ? context.watch<LocalProductProvider>().hideNonStockProduct
          : context.read<LocalProductProvider>().hideNonStockProduct;
    } on ProviderNotFoundException catch (_) {
      return false;
    }
  }
}
