import 'package:flutter/material.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/widgets/stock_selection_modal.dart';
import 'package:provider/provider.dart';

/// Global function to handle adding products to cart with stock selection.
///
/// This function checks if a product has multiple available stock options and
/// shows a selection modal if needed. It then adds the product to the cart
/// with the selected stock or default stock if only one is available.
///
/// Parameters:
/// - context: BuildContext for showing dialogs and accessing providers
/// - product: The product to add to the cart
/// - quantity: Optional quantity (defaults to 1)
/// - price: Optional custom price
/// - mrp: Optional custom MRP
/// - isIncreamentUsingCompactQuantityControl: Optional flag for quantity control
/// - onSuccess: Optional callback when product is successfully added
/// - onError: Optional callback when an error occurs

Future<void> handleAddProductToCart({
  required BuildContext context,
  required GetProduct product,
  num? quantity = 1,
  double? price,
  double? mrp,
  bool isIncreamentUsingCompactQuantityControl = false,
  Function()? onSuccess,
  Function(String)? onError,
  int? productId,
  Stock? selectedStock,
}) async {
  try {
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final storeSessionProvider =
        Provider.of<StoreSessionProvider>(context, listen: false);
    final activeStore = storeSessionProvider.activeStore;

    // Check if product has stock options
    if (product.stock != null && product.stock!.isNotEmpty) {
      final availableStocks = localProductProvider.getStockOptionsForStore(
        product,
        activeStoreId: activeStore?.storeId,
        activeStoreName: activeStore?.storeName,
      );

      if (availableStocks.isEmpty) {
        // No stock with qty>0 → fall back to base product pricing
        localProductProvider.addToCart(
          product: product,
          quantity: quantity,
          price: price,
          mrp: mrp,
          isIncreamentUsingCompactQuantityControl:
              isIncreamentUsingCompactQuantityControl,
        );

        if (onSuccess != null) {
          onSuccess();
        }
        return;
      }

      // Group stocks by pricing before deciding whether to show modal
      final groups = groupStocksByPricing(availableStocks);

      if (groups.length == 1) {
        // Single pricing group → auto-select, no modal needed
        final group = groups.first;
        final autoStock = group.firstStock.copyWith(
          quantity: group.totalQuantity,
          price: group.price,
          mrp: group.mrp,
          unit: group.unit,
          purchasePrice: group.purchasePrice,
          hsnCode: group.hsnCode,
        );

        localProductProvider.addToCart(
          product: product,
          quantity: quantity,
          price: price ?? (double.tryParse(autoStock.price ?? "0") ?? 0.0),
          mrp: mrp ?? (double.tryParse(autoStock.mrp ?? "0") ?? 0.0),
          selectedStock: autoStock,
          isIncreamentUsingCompactQuantityControl:
              isIncreamentUsingCompactQuantityControl,
        );

        if (onSuccess != null) {
          onSuccess();
        }
      } else {
        // Multiple pricing groups → show stock selection modal
        final result = await showDialog(
          context: context,
          builder: (context) => StockSelectionModal(
            product: product,
            stockOptions: availableStocks,
          ),
        );

        if (result != null) {
          Stock selectedStock = result['stock'];

          localProductProvider.addToCart(
            product: product,
            quantity: quantity,
            price:
                price ?? (double.tryParse(selectedStock.price ?? "0") ?? 0.0),
            mrp: mrp ?? (double.tryParse(selectedStock.mrp ?? "0") ?? 0.0),
            selectedStock: selectedStock,
            isIncreamentUsingCompactQuantityControl:
                isIncreamentUsingCompactQuantityControl,
          );

          if (onSuccess != null) {
            onSuccess();
          }
        }
        // User cancelled selection - do nothing
      }
    } else {
      // No stock options, add product directly
      localProductProvider.addToCart(
        product: product,
        quantity: quantity,
        price: price,
        mrp: mrp,
        isIncreamentUsingCompactQuantityControl:
            isIncreamentUsingCompactQuantityControl,
      );

      if (onSuccess != null) {
        onSuccess();
      }
    }
  } catch (e) {
    debugPrint("Error handling stock selection: $e");
    if (onError != null) {
      onError("Failed to add product to cart: $e");
    }
  }
}
