import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/widgets/stock_selection_modal.dart';
import 'package:provider/provider.dart';

class ProductCartHelper {
  /// Centralized method to handle product selection and adding to cart
  ///
  /// FLOW EXPLANATION:
  /// 1. STOCK SELECTION (if stock enabled):
  ///    - Multiple stocks → Show stock modal → User selects stock
  ///    - Single stock → Auto-select stock
  ///    - No stock/disabled → Use product base pricing
  ///
  /// 2. CUSTOMER PURCHASE HISTORY:
  ///    - Add-to-cart does not fetch or show purchase history.
  ///    - Billing cart rows expose a manual history action for old prices.
  ///
  /// 3. ADD TO CART:
  ///    - Use final determined price, quantity, and selected stock
  ///    - Stock used for inventory tracking (if enabled)
  ///    - Historical prices override stock prices but keep stock selection
  static Future<void> handleProductSelection({
    required BuildContext context,
    required GetProduct product,
    Function(GetProduct, Stock?)? onSelected,
    bool addToCartDirectly = true,
    num? quantity,
    double? customPrice,
    double? customMrp,
    int? customerId,
    String? customerName,
    SaleUnit? selectedSaleUnit,
  }) async {
    debugPrint("=== PRODUCT CART HELPER DEBUG START ===");
    debugPrint("Product selected: ${product.productName}");
    debugPrint("Product ID: ${product.productId}");
    debugPrint("Product base price: ${product.price?.price ?? 'null'}");
    debugPrint("Product MRP: ${product.mrp ?? 'null'}");
    debugPrint("Product has ${product.stock?.length ?? 0} stock entries");
    debugPrint("Add to cart directly: $addToCartDirectly");
    debugPrint("Customer ID: $customerId");
    debugPrint("Customer Name: $customerName");
    debugPrint("Quantity: $quantity");
    debugPrint("Custom Price: $customPrice");
    debugPrint("Custom MRP: $customMrp");

    // Get customer information from global provider if not provided in parameters
    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);

    // Use provided customer info first, fallback to global provider
    final int? effectiveCustomerId =
        customerId ?? customerSelectionProvider.selectedCustomerID;
    final String? effectiveCustomerName =
        customerName ?? customerSelectionProvider.selectedCustomerName;

    debugPrint("🌐 GLOBAL CUSTOMER INFO:");
    debugPrint(
        "  - Provider has customer: ${customerSelectionProvider.hasSelectedCustomer}");
    debugPrint(
        "  - Provider customer ID: ${customerSelectionProvider.selectedCustomerID}");
    debugPrint(
        "  - Provider customer name: ${customerSelectionProvider.selectedCustomerName}");
    debugPrint("  - Effective customer ID: $effectiveCustomerId");
    debugPrint("  - Effective customer name: $effectiveCustomerName");

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final generalSettingsProvider =
        Provider.of<GeneralSettingsProvider>(context, listen: false);
    final storeSessionProvider =
        Provider.of<StoreSessionProvider>(context, listen: false);
    final activeStore = storeSessionProvider.activeStore;

    // Check if stock management is enabled
    bool stockEnabled =
        generalSettingsProvider.generalSettings?.stockEnabled ?? false;
    debugPrint("📦 Stock management enabled: $stockEnabled");

    // Set the stock enabled status in LocalProductProvider
    localProductProvider.setStockEnabled(stockEnabled);

    // Variables to track selected stock and final values
    Stock? selectedStock;
    List<int> selectedStockGroupIds = <int>[];
    double? finalPrice = customPrice;
    double? finalMrp = customMrp;
    num? finalQuantity = quantity;
    bool hasExplicitPriceOverride = customPrice != null;
    final requestedQuantity = finalQuantity ?? 1;

    // STEP 1: Handle stock selection if stock management is enabled
    if (stockEnabled && product.stock != null && product.stock!.isNotEmpty) {
      debugPrint("📦 STEP 1: Handling stock selection...");

      final List<Stock> availableStocks =
          localProductProvider.getStockOptionsForStore(
        product,
        activeStoreId: activeStore?.storeId,
        activeStoreName: activeStore?.storeName,
      );

      debugPrint("🏪 Active store filter applied:");
      debugPrint("  - Active Store ID: ${activeStore?.storeId}");
      debugPrint("  - Active Store Name: ${activeStore?.storeName}");
      debugPrint(
          "  - Matching stock entries (qty>0): ${availableStocks.length}");

      if (availableStocks.isEmpty) {
        // All stock entries have qty=0 OR no store-matching entries → base price
        debugPrint(
            "⚠️ No available stock (qty>0) found - fallback to product base pricing");
        finalPrice =
            finalPrice ?? double.tryParse(product.price?.price ?? "0") ?? 0;
        finalMrp = finalMrp ?? double.tryParse(product.mrp ?? "0") ?? 0;
      } else {
        // Group stocks by pricing BEFORE deciding whether to show modal
        final List<CombinedStock> groups =
            groupStocksByPricing(availableStocks);
        debugPrint(
            "📦 Grouped ${availableStocks.length} stocks into ${groups.length} pricing group(s)");

        if (groups.length == 1) {
          // Only 1 pricing group → auto-select, no modal needed
          final group = groups.first;
          selectedStockGroupIds = group.originalStocks
              .map((stock) => stock.id)
              .whereType<int>()
              .toSet()
              .toList()
            ..sort();
          selectedStock = group.firstStock.copyWith(
            quantity: group.totalQuantity,
            price: group.price,
            mrp: group.mrp,
            unit: group.unit,
            purchasePrice: group.purchasePrice,
            hsnCode: group.hsnCode,
            wholesalePrice: group.wholesalePrice,
            wholesaleMinUnit: group.wholesaleMinUnit,
          );

          debugPrint("📦 Single pricing group - auto-selected:");
          debugPrint("  - Stock ID: ${selectedStock.id}");
          debugPrint("  - Price: ${selectedStock.price}");
          debugPrint("  - MRP: ${selectedStock.mrp}");
          debugPrint("  - Combined Qty: ${selectedStock.quantity}");

          finalPrice =
              finalPrice ?? double.tryParse(selectedStock.price ?? "0") ?? 0;
          finalMrp = finalMrp ?? double.tryParse(selectedStock.mrp ?? "0") ?? 0;
        } else {
          final preferredSaleUnitStocks = selectedSaleUnit == null
              ? const <Stock>[]
              : _resolvePreferredSaleUnitStocks(
                  availableStocks,
                  selectedSaleUnit,
                );
          final preferredSaleUnitGroups = preferredSaleUnitStocks.isEmpty
              ? const <CombinedStock>[]
              : groupStocksByPricing(preferredSaleUnitStocks);

          if (preferredSaleUnitGroups.length == 1 &&
              preferredSaleUnitGroups.first.totalQuantity >=
                  requestedQuantity) {
            final preferredGroup = preferredSaleUnitGroups.first;
            selectedStockGroupIds = preferredGroup.originalStocks
                .map((stock) => stock.id)
                .whereType<int>()
                .toSet()
                .toList()
              ..sort();
            selectedStock = preferredGroup.firstStock.copyWith(
              quantity: preferredGroup.totalQuantity,
              price: preferredGroup.price,
              mrp: preferredGroup.mrp,
              unit: preferredGroup.unit,
              purchasePrice: preferredGroup.purchasePrice,
              hsnCode: preferredGroup.hsnCode,
              wholesalePrice: preferredGroup.wholesalePrice,
              wholesaleMinUnit: preferredGroup.wholesaleMinUnit,
            );

            debugPrint(
                "📦 Sale-unit preferred stock group auto-selected for ${selectedSaleUnit?.unitName}");
            finalPrice =
                finalPrice ?? double.tryParse(selectedStock.price ?? "0") ?? 0;
            finalMrp =
                finalMrp ?? double.tryParse(selectedStock.mrp ?? "0") ?? 0;
          } else {
            // Multiple pricing groups → show stock selection modal
            debugPrint(
                "📱 ${groups.length} pricing groups - showing stock selection modal...");

            final result = await showDialog(
              context: context,
              builder: (context) => StockSelectionModal(
                product: product,
                stockOptions: availableStocks,
              ),
            );

            if (result != null) {
              debugPrint("✅ User selected stock from modal");
              selectedStock = result['stock'] as Stock?;
              if (selectedStock == null) {
                debugPrint("❌ Stock selection modal returned no stock");
                debugPrint("=== PRODUCT CART HELPER DEBUG END ===");
                return;
              }
              final originalStocks = (result['originalStocks'] as List?)
                      ?.whereType<Stock>()
                      .toList() ??
                  const <Stock>[];
              selectedStockGroupIds = originalStocks
                  .map((stock) => stock.id)
                  .whereType<int>()
                  .toSet()
                  .toList()
                ..sort();

              debugPrint("📦 Selected stock details:");
              debugPrint("  - Stock ID: ${selectedStock.id}");
              debugPrint("  - Stock Price: ${selectedStock.price}");
              debugPrint("  - Stock MRP: ${selectedStock.mrp}");

              finalPrice = finalPrice ??
                  double.tryParse(selectedStock.price ?? "0") ??
                  0;
              finalMrp =
                  finalMrp ?? double.tryParse(selectedStock.mrp ?? "0") ?? 0;
            } else {
              debugPrint("❌ User cancelled stock selection - aborting");
              debugPrint("=== PRODUCT CART HELPER DEBUG END ===");
              return;
            }
          }
        }
      }
    } else if (!stockEnabled) {
      debugPrint("📦 Stock management disabled - using product base pricing");

      finalPrice =
          finalPrice ?? double.tryParse(product.price?.price ?? "0") ?? 0;
      finalMrp = finalMrp ?? double.tryParse(product.mrp ?? "0") ?? 0;
    } else {
      debugPrint(
          "📦 Product has no stock entries, using basic product info...");
      finalPrice =
          finalPrice ?? double.tryParse(product.price?.price ?? "0") ?? 0;
      finalMrp = finalMrp ?? double.tryParse(product.mrp ?? "0") ?? 0;

      debugPrint("💰 Product base pricing (No Stock):");
      debugPrint("  - Final Price: $finalPrice");
      debugPrint("  - Final MRP: $finalMrp");
    }

    if (stockEnabled &&
        selectedSaleUnit != null &&
        selectedStock != null &&
        (selectedStock.quantity ?? 0) < requestedQuantity) {
      showScaffoldError(
        context: context,
        message:
            'Insufficient stock for ${selectedSaleUnit.unitName ?? product.unit ?? "selected unit"}',
      );
      debugPrint(
          "❌ Selected stock does not cover requested sale-unit quantity");
      debugPrint("=== PRODUCT CART HELPER DEBUG END ===");
      return;
    }

    // STEP 3: Handle onSelected callback if provided
    if (onSelected != null) {
      debugPrint("🔄 STEP 3: Calling onSelected callback...");
      onSelected(product, selectedStock);
      localProductProvider.callProductDetails(product.productId!,
          selectedStock: selectedStock);
    }

    // STEP 4: Add to cart if required
    if (addToCartDirectly) {
      // Set final values with defaults
      final cartQuantity = finalQuantity ?? 1;

      // 🔧 FIX: Check if product already exists in cart with custom price
      // If explicit custom price was provided (from parameter), use that
      // Otherwise, check if product exists with custom price and preserve it
      double? priceToUse = hasExplicitPriceOverride ? finalPrice : null;
      double? mrpToUse = customMrp; // Use custom MRP from parameter if provided

      if (priceToUse == null) {
        // No explicit custom price provided, check if item already exists in cart
        // First check if item exists in cart
        final bool itemExistsInCart = localProductProvider.cartItems.any(
            (item) =>
                item.product.productId == product.productId &&
                item.saleUnitId == selectedSaleUnit?.id &&
                ((selectedStockGroupIds.isNotEmpty &&
                        item.stockGroupIds.isNotEmpty &&
                        item.stockGroupIds.length ==
                            selectedStockGroupIds.length &&
                        item.stockGroupIds.asMap().entries.every((entry) =>
                            entry.value == selectedStockGroupIds[entry.key])) ||
                    (item.selectedStock?.id == selectedStock?.id ||
                        (item.selectedStock == null &&
                            selectedStock == null))));

        if (itemExistsInCart) {
          // Item exists in cart, find it and preserve its custom price
          final existingItem = localProductProvider.cartItems.firstWhere(
            (item) =>
                item.product.productId == product.productId &&
                item.saleUnitId == selectedSaleUnit?.id &&
                ((selectedStockGroupIds.isNotEmpty &&
                        item.stockGroupIds.isNotEmpty &&
                        item.stockGroupIds.length ==
                            selectedStockGroupIds.length &&
                        item.stockGroupIds.asMap().entries.every((entry) =>
                            entry.value == selectedStockGroupIds[entry.key])) ||
                    (item.selectedStock?.id == selectedStock?.id ||
                        (item.selectedStock == null && selectedStock == null))),
          );

          debugPrint(
              "💰 Product already in cart - preserving existing custom price: ${existingItem.price}, MRP: ${existingItem.mrp}");
          priceToUse =
              null; // Don't pass price, let addToCart preserve existing price
          mrpToUse =
              null; // Don't pass MRP, let addToCart preserve existing MRP
        } else {
          debugPrint(
              "💰 New product to cart - using calculated price: $finalPrice, MRP: $finalMrp");
          priceToUse = finalPrice;
          mrpToUse = finalMrp;
        }
      } else {
        debugPrint(
            "💰 Using explicit custom price from parameter: $priceToUse, MRP: $mrpToUse");
      }

      debugPrint("🛒 STEP 4: ADDING TO CART");
      debugPrint("Product: ${product.productName}");
      debugPrint("Final Quantity: $cartQuantity");
      debugPrint("Price to use: $priceToUse");
      debugPrint("MRP to use: $mrpToUse");
      debugPrint("Selected Stock ID: ${selectedStock?.id}");
      debugPrint("Stock Management Enabled: $stockEnabled");

      localProductProvider.addToCart(
        product: product,
        quantity: cartQuantity,
        price: priceToUse,
        mrp: mrpToUse,
        selectedStock: selectedStock,
        stockGroupIds: selectedStockGroupIds,
        markPriceAsManualOverride: hasExplicitPriceOverride,
        saleUnitId: selectedSaleUnit?.id,
        saleUnitName: selectedSaleUnit?.unitName,
        saleUnitConversionRate: _parseSaleUnitConversionRate(selectedSaleUnit),
      );

      showScaffold(
        context: context,
        message: 'Added To Cart',
      );
    }

    debugPrint("=== PRODUCT CART HELPER DEBUG END ===");
  }

  static double? _parseSaleUnitConversionRate(SaleUnit? saleUnit) {
    if (saleUnit == null) {
      return null;
    }
    final parsedRate = double.tryParse(saleUnit.conversionRate?.trim() ?? '');
    if (parsedRate == null || parsedRate <= 0) {
      return null;
    }
    return parsedRate;
  }

  static List<Stock> _resolvePreferredSaleUnitStocks(
    List<Stock> stocks,
    SaleUnit saleUnit,
  ) {
    final saleUnitId = saleUnit.id?.toString().trim();
    final unitId = saleUnit.unitId?.toString().trim();
    final unitName = saleUnit.unitName?.trim().toLowerCase();

    return stocks.where((stock) {
      final purchaseUnitId = stock.purchaseUnitId?.trim().toLowerCase();
      if (purchaseUnitId == null || purchaseUnitId.isEmpty) {
        return false;
      }

      return (saleUnitId != null &&
              purchaseUnitId == saleUnitId.toLowerCase()) ||
          (unitId != null && purchaseUnitId == unitId.toLowerCase()) ||
          (unitName != null && purchaseUnitId == unitName);
    }).toList();
  }
}
