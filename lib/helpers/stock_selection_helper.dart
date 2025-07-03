import 'package:flutter/material.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
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

    // Check if product has stock options
    if (product.stock != null && product.stock!.isNotEmpty) {
      // Filter available stock options (quantity > 0)
      List<Stock> availableStocks = product.stock!
          .where((stock) => stock.quantity != null && stock.quantity! > 0)
          .toList();

      if (availableStocks.isEmpty) {
        // No stock available
        if (onError != null) {
          onError("No stock available for this product.");
        }
        return;
      }

      // If multiple stock options are available, show selection modal
      if (availableStocks.length > 1) {
        final result = await showDialog(
          context: context,
          builder: (context) => StockSelectionModal(
            product: product,
            stockOptions: availableStocks,
          ),
        );

        if (result != null) {
          // Process the selected product and stock
          GetProduct selectedProduct = result['product'];
          Stock selectedStock = result['stock'];

          // Add to cart with selected stock
          localProductProvider.addToCart(
            product: selectedProduct,
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
        return;
      } else {
        // Single stock option available, use it directly
        Stock stock = availableStocks.first;
        localProductProvider.addToCart(
          product: product,
          quantity: quantity,
          price: price ?? (double.tryParse(stock.price ?? "0") ?? 0.0),
          mrp: mrp ?? (double.tryParse(stock.mrp ?? "0") ?? 0.0),
          selectedStock: stock,
          isIncreamentUsingCompactQuantityControl:
              isIncreamentUsingCompactQuantityControl,
        );

        if (onSuccess != null) {
          onSuccess();
        }
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
