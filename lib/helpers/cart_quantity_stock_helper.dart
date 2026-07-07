import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/widgets/stock_selection_modal.dart';
import 'package:provider/provider.dart';

typedef CartQuantityStockSelectionResolver = Future<CartQuantityStockSelection?>
    Function(GetProduct product, List<Stock> stockOptions);

typedef CartQuantityStockMessageHandler = void Function(String message);

class CartQuantityChangeResult {
  final num appliedQuantity;
  final bool changed;

  const CartQuantityChangeResult({
    required this.appliedQuantity,
    required this.changed,
  });
}

class CartQuantityStockSelection {
  final Stock selectedStock;
  final List<int> stockGroupIds;

  const CartQuantityStockSelection({
    required this.selectedStock,
    required this.stockGroupIds,
  });
}

class CartQuantityStockHelper {
  static Future<CartQuantityChangeResult> syncCartItemQuantity({
    required LocalCartItem cartItem,
    required num newQuantity,
    BuildContext? context,
    LocalProductProvider? localProductProvider,
    int? activeStoreId,
    String? activeStoreName,
    CartQuantityStockSelectionResolver? selectionResolver,
    CartQuantityStockMessageHandler? onBlocked,
  }) async {
    final provider = localProductProvider ??
        Provider.of<LocalProductProvider>(context!, listen: false);

    final currentQuantity = cartItem.quantity;
    final productId = cartItem.product.productId;

    if (productId == null) {
      return CartQuantityChangeResult(
        appliedQuantity: currentQuantity,
        changed: false,
      );
    }

    if (newQuantity <= currentQuantity ||
        !provider.isStockEnabled ||
        cartItem.selectedStock == null) {
      provider.setCartItemQuantity(
        productId,
        cartItem.selectedStock,
        newQuantity,
        stockGroupIds: cartItem.stockGroupIds,
        saleUnitId: cartItem.saleUnitId,
      );

      return CartQuantityChangeResult(
        appliedQuantity: newQuantity <= 0 ? 0 : newQuantity,
        changed: newQuantity != currentQuantity,
      );
    }

    if (activeStoreId == null && activeStoreName == null && context != null) {
      final storeSessionProvider =
          Provider.of<StoreSessionProvider>(context, listen: false);
      activeStoreId = storeSessionProvider.activeStore?.storeId;
      activeStoreName = storeSessionProvider.activeStore?.storeName;
    }

    selectionResolver ??= (product, stockOptions) {
      return _selectAdditionalStock(
        context: context!,
        product: product,
        stockOptions: stockOptions,
      );
    };

    onBlocked ??= (message) {
      if (context != null && context.mounted) {
        showScaffoldError(
          context: context,
          message: message,
        );
      }
    };

    final currentProduct =
        provider.getProductById(productId) ?? cartItem.product;
    final saleUnitStep = cartItem.hasSaleUnit ? cartItem.toBaseQuantity(1) : 1;

    num appliedQuantity = currentQuantity;
    num remainingIncrease = newQuantity - currentQuantity;
    bool changed = false;

    final availableOnCurrentSelection =
        provider.getAvailableQuantityForSelection(
      product: currentProduct,
      selectedStock: cartItem.selectedStock,
      stockGroupIds: cartItem.stockGroupIds,
    );

    final quantityOnCurrentSelection = cartItem.hasSaleUnit
        ? _snapQuantityToStep(
            _minQuantity(remainingIncrease, availableOnCurrentSelection),
            saleUnitStep,
          )
        : _minQuantity(remainingIncrease, availableOnCurrentSelection);

    if (quantityOnCurrentSelection > 0) {
      provider.addToCart(
        product: currentProduct,
        quantity: quantityOnCurrentSelection,
        price: cartItem.price,
        mrp: cartItem.mrp,
        markPriceAsManualOverride: cartItem.isManualPriceOverride,
        isIncreamentUsingCompactQuantityControl: true,
        selectedStock: cartItem.selectedStock,
        stockGroupIds: cartItem.stockGroupIds,
        saleUnitId: cartItem.saleUnitId,
        saleUnitName: cartItem.saleUnitName,
        saleUnitConversionRate: cartItem.saleUnitConversionRate,
      );

      appliedQuantity += quantityOnCurrentSelection;
      remainingIncrease -= quantityOnCurrentSelection;
      changed = true;
    }

    while (remainingIncrease > 0) {
      final refreshedProduct =
          provider.getProductById(productId) ?? currentProduct;
      final alternativeStocks = provider.getAlternativeStockOptions(
        product: refreshedProduct,
        selectedStock: cartItem.selectedStock,
        stockGroupIds: cartItem.stockGroupIds,
        activeStoreId: activeStoreId,
        activeStoreName: activeStoreName,
      );

      if (alternativeStocks.isEmpty) {
        // No other batch to draw from, but the cashier may still be counting
        // out physical units in hand. Offer an oversell confirmation when we
        // have a context to show it in; otherwise (headless callers) keep the
        // hard block so existing explicit-resolver integrations are unaffected.
        if (context != null && context.mounted) {
          final sellAnyway = await showSellAnywayConfirmDialog(
            context: context,
            message:
                'No more stock recorded for this item (requested $remainingIncrease more). Sell anyway?',
          );
          if (sellAnyway && context.mounted) {
            provider.setCartItemQuantity(
              productId,
              cartItem.selectedStock,
              newQuantity,
              stockGroupIds: cartItem.stockGroupIds,
              saleUnitId: cartItem.saleUnitId,
            );
            appliedQuantity = newQuantity;
            remainingIncrease = 0;
            changed = true;
            break;
          }
        }
        onBlocked('Selected stock is exhausted. No other stock is available.');
        break;
      }

      final selection = await selectionResolver(
        refreshedProduct,
        alternativeStocks,
      );

      if (selection == null) {
        break;
      }

      final availableForSelection = provider.getAvailableQuantityForSelection(
        product: refreshedProduct,
        selectedStock: selection.selectedStock,
        stockGroupIds: selection.stockGroupIds,
      );

      if (availableForSelection <= 0) {
        onBlocked(
          'Selected stock is no longer available. Please choose another stock.',
        );
        continue;
      }

      final quantityForSelection = cartItem.hasSaleUnit
          ? _snapQuantityToStep(
              _minQuantity(remainingIncrease, availableForSelection),
              saleUnitStep,
            )
          : _minQuantity(remainingIncrease, availableForSelection);

      if (quantityForSelection <= 0) {
        onBlocked(
          'Selected stock does not have enough quantity for one ${cartItem.saleUnitName ?? cartItem.product.unit ?? "unit"}.',
        );
        break;
      }

      provider.addToCart(
        product: refreshedProduct,
        quantity: quantityForSelection,
        price: cartItem.price,
        mrp: cartItem.mrp,
        markPriceAsManualOverride: cartItem.isManualPriceOverride,
        isIncreamentUsingCompactQuantityControl: true,
        selectedStock: selection.selectedStock,
        stockGroupIds: selection.stockGroupIds,
        saleUnitId: cartItem.saleUnitId,
        saleUnitName: cartItem.saleUnitName,
        saleUnitConversionRate: cartItem.saleUnitConversionRate,
      );

      appliedQuantity += quantityForSelection;
      remainingIncrease -= quantityForSelection;
      changed = true;
    }

    return CartQuantityChangeResult(
      appliedQuantity: appliedQuantity,
      changed: changed,
    );
  }

  static num _minQuantity(num first, num second) {
    return first < second ? first : second;
  }

  static num _snapQuantityToStep(num quantity, num step) {
    if (step <= 0) {
      return quantity;
    }

    final multiplier = (quantity / step).floor();
    return multiplier * step;
  }

  static Future<CartQuantityStockSelection?> _selectAdditionalStock({
    required BuildContext context,
    required GetProduct product,
    required List<Stock> stockOptions,
  }) async {
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);
    final groups = groupStocksByPricing(
      stockOptions,
      activeFields: masterDataProvider.activeStockGroupingFields,
    );
    if (groups.isEmpty) {
      return null;
    }

    if (groups.length == 1) {
      final group = groups.first;
      return CartQuantityStockSelection(
        selectedStock: group.firstStock.copyWith(
          quantity: group.totalQuantity,
          price: group.price,
          mrp: group.mrp,
          unit: group.unit,
          purchasePrice: group.purchasePrice,
          hsnCode: group.hsnCode,
          wholesalePrice: group.wholesalePrice,
          wholesaleMinUnit: group.wholesaleMinUnit,
        ),
        stockGroupIds: group.originalStocks
            .map((stock) => stock.id)
            .whereType<int>()
            .toSet()
            .toList()
          ..sort(),
      );
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StockSelectionModal(
        product: product,
        stockOptions: stockOptions,
      ),
    );

    if (result == null) {
      return null;
    }

    final selectedStock = result['stock'] as Stock?;
    if (selectedStock == null) {
      return null;
    }

    final originalStocks =
        (result['originalStocks'] as List?)?.whereType<Stock>().toList() ??
            const <Stock>[];
    final stockGroupIds = originalStocks
        .map((stock) => stock.id)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();

    return CartQuantityStockSelection(
      selectedStock: selectedStock,
      stockGroupIds: stockGroupIds,
    );
  }
}
