import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/domain/product_variant_selection.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/mobile_variant_picker_sheet.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/helpers/zero_price_quick_entry_helper.dart';
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
    ProductVariant? selectedVariant,
    String? scannedBarcode,
  }) async {
    try {
      await _handleProductSelectionImpl(
        context: context,
        product: product,
        onSelected: onSelected,
        addToCartDirectly: addToCartDirectly,
        quantity: quantity,
        customPrice: customPrice,
        customMrp: customMrp,
        customerId: customerId,
        customerName: customerName,
        selectedSaleUnit: selectedSaleUnit,
        selectedVariant: selectedVariant,
        scannedBarcode: scannedBarcode,
      );
    } catch (error) {
      debugPrint('ProductCartHelper error: $error');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: BillingMobileErrorMessages.addToCartFailed,
        );
      }
    }
  }

  static Future<void> _handleProductSelectionImpl({
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
    ProductVariant? selectedVariant,
    String? scannedBarcode,
  }) async {
    debugPrint("=== PRODUCT CART HELPER DEBUG START ===");

    // STEP 0: Resolve a variant if the caller didn't already pick one.
    // Mirrors the stock-selection / zero-price flows below: auto-resolve when
    // unambiguous, otherwise show a picker, all from this single entry point
    // so every add-to-cart call site (mobile, desktop, restaurant) gets
    // variant support without needing to know about it.
    bool variantsOn = false;
    try {
      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      variantsOn =
          appSettingsProvider.appSettings?.productVariantEnabled ?? true;
    } on ProviderNotFoundException catch (_) {
      // No AppSettingsProvider above this context (e.g. isolated widget
      // tests, or a call site outside the app's provider tree) — treat as
      // variants-off rather than aborting the add-to-cart entirely.
      variantsOn = false;
    }

    if (selectedVariant == null && variantsOn && product.hasVariants) {
      selectedVariant = ProductVariantSelection.tryResolveWithoutPicker(
        product,
        scannedBarcode: scannedBarcode,
      );

      if (selectedVariant == null &&
          ProductVariantSelection.needsVariantPicker(product)) {
        selectedVariant = await showMobileVariantPickerSheet(
          context: context,
          product: product,
        );
        if (selectedVariant == null || !context.mounted) {
          debugPrint("❌ Variant picker cancelled - aborting add");
          debugPrint("=== PRODUCT CART HELPER DEBUG END ===");
          return;
        }
      }
    }
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

    // Products explicitly flagged as non-sellable must not be billed from any
    // entry point (grid already hides them; this covers barcode/search adds).
    if (product.sellable == false) {
      showScaffoldError(
        context: context,
        message: BillingMobileErrorMessages.productNotSellable(
          product.productName ?? 'This product',
        ),
      );
      debugPrint("❌ Product is not sellable — aborting add");
      debugPrint("=== PRODUCT CART HELPER DEBUG END ===");
      return;
    }

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
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);
    final activeStore = storeSessionProvider.activeStore;

    // Check if stock management is enabled
    bool stockEnabled =
        generalSettingsProvider.generalSettings?.stockEnabled ?? false;
    debugPrint("📦 Stock management enabled: $stockEnabled");

    // Set the stock enabled status in LocalProductProvider
    localProductProvider.setStockEnabled(stockEnabled);

    // A variant reporting zero stock is a data signal, not a hard stop: the
    // cashier may be holding the physical item. Confirm instead of refusing,
    // and only when stock management AND the oversell-confirmation setting
    // are both enabled. Defaults to false so businesses that don't track
    // variant-level stock (restaurants, quick-service, etc.) aren't nagged.
    final bool confirmOversellOnZeroStock =
        generalSettingsProvider.generalSettings?.confirmOversellOnZeroStock ??
            false;
    if (stockEnabled &&
        confirmOversellOnZeroStock &&
        selectedVariant != null &&
        ProductVariantSelection.isOutOfStock(selectedVariant)) {
      final label = selectedVariant.formattedAttributes.isEmpty
          ? (selectedVariant.sku ?? 'Selected variant')
          : selectedVariant.formattedAttributes;
      final sellAnyway = await showSellAnywayConfirmDialog(
        context: context,
        message: BillingMobileErrorMessages.variantOutOfStockConfirm(label),
      );
      if (!sellAnyway || !context.mounted) {
        debugPrint("❌ Variant out of stock — cashier declined oversell");
        debugPrint("=== PRODUCT CART HELPER DEBUG END ===");
        return;
      }
      debugPrint("⚠️ Variant out of stock — cashier confirmed oversell");
    }

    // Mirror the configured grouping fields so cart merge decisions use the
    // same pricing signature as stock grouping.
    localProductProvider.setActiveStockGroupingFields(
        masterDataProvider.activeStockGroupingFields);

    // Variables to track selected stock and final values
    Stock? selectedStock;
    List<int> selectedStockGroupIds = <int>[];
    double? finalPrice = customPrice;
    double? finalMrp = customMrp;
    num? finalQuantity = quantity;
    bool hasExplicitPriceOverride = customPrice != null;
    final requestedQuantity = finalQuantity ?? 1;

    if (selectedVariant != null && !hasExplicitPriceOverride) {
      final productPrice = ProductVariantSelection.productBasePrice(product);
      finalPrice = selectedVariant.effectivePrice(productPrice);
      if (customMrp == null) {
        finalMrp = selectedVariant.mrp ??
            double.tryParse(product.mrp?.toString() ?? '') ??
            finalPrice;
      }
    }

    // STEP 1: Handle stock selection if stock management is enabled
    if (stockEnabled && product.stock != null && product.stock!.isNotEmpty) {
      debugPrint("📦 STEP 1: Handling stock selection...");

      // Variant-scoped stock (server rule §4): when a variant is chosen, draw
      // only from its scoped stock rows; if it has none, fall back to general
      // (non-variant) stock. Null variant → list unchanged (identical behavior).
      final List<Stock> availableStocks =
          LocalProductProvider.filterStocksForVariant(
        localProductProvider.getStockOptionsForStore(
          product,
          activeStoreId: activeStore?.storeId,
          activeStoreName: activeStore?.storeName,
        ),
        selectedVariant?.id,
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
        final activeGroupingFields =
            masterDataProvider.activeStockGroupingFields;
        final List<CombinedStock> groups = groupStocksByPricing(
          availableStocks,
          activeFields: activeGroupingFields,
        );
        debugPrint(
            "📦 Grouped ${availableStocks.length} stocks into ${groups.length} pricing group(s) using fields: $activeGroupingFields");

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
              : groupStocksByPricing(
                  preferredSaleUnitStocks,
                  activeFields: activeGroupingFields,
                );

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
              // Not silent: an accidental outside-tap dismiss must be visible
              // so the cashier knows the item was NOT billed.
              if (context.mounted) {
                showScaffoldError(
                  context: context,
                  message: BillingMobileErrorMessages.stockNotSelected,
                );
              }
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

    // Sale-unit shortfall (e.g. CASE barcode scanned but the system tracks
    // fewer base units): the physical case exists, so offer an oversell
    // confirmation instead of refusing the sale. This matches the base-unit
    // behavior where addToCart reserves what it can and sells the rest.
    if (stockEnabled &&
        selectedSaleUnit != null &&
        selectedStock != null &&
        (selectedStock.quantity ?? 0) < requestedQuantity) {
      if (!context.mounted) {
        return;
      }
      final sellAnyway = await showSellAnywayConfirmDialog(
        context: context,
        message: BillingMobileErrorMessages.insufficientStockConfirm(
          selectedSaleUnit.unitName ?? product.unit ?? 'selected unit',
          selectedStock.quantity ?? 0,
          requestedQuantity,
        ),
      );
      if (!sellAnyway || !context.mounted) {
        debugPrint("❌ Sale-unit stock shortfall — cashier declined oversell");
        debugPrint("=== PRODUCT CART HELPER DEBUG END ===");
        return;
      }
      debugPrint("⚠️ Sale-unit stock shortfall — cashier confirmed oversell");
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
      num cartQuantity =
          finalQuantity != null && finalQuantity > 0 ? finalQuantity : 1;
      double? existingCartItemPrice;
      bool markPriceAsManualOverride = hasExplicitPriceOverride;

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
                item.variantId == selectedVariant?.id &&
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
                item.variantId == selectedVariant?.id &&
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
          existingCartItemPrice = existingItem.price;
          priceToUse =
              null; // Don't pass price, let addToCart preserve existing price
          mrpToUse =
              null; // Don't pass MRP, let addToCart preserve existing MRP
        } else if (selectedVariant != null) {
          debugPrint(
              "💰 New variant product to cart - using selected variant price/MRP: $finalPrice, $finalMrp");
          priceToUse = finalPrice;
          mrpToUse = finalMrp;
        } else {
          debugPrint(
              "💰 New product to cart - deferring price/MRP to provider resolution (sale-unit chain)");
          priceToUse = null;
          mrpToUse = null;
        }
      } else {
        debugPrint(
            "💰 Using explicit custom price from parameter: $priceToUse, MRP: $mrpToUse");
      }

      // Zero-priced products need a price before entering the cart: open the
      // quick price/quantity entry modal (pre-filled with the default
      // customer's last bought price). Cancelling aborts the add.
      final double predictedUnitPrice =
          priceToUse ?? existingCartItemPrice ?? finalPrice;
      if (ZeroPriceQuickEntryHelper.isZeroPrice(predictedUnitPrice)) {
        if (!context.mounted) {
          return;
        }
        final entry = await ZeroPriceQuickEntryHelper.promptForProduct(
          context: context,
          product: product,
          initialQuantity: cartQuantity,
          mrp: mrpToUse ?? finalMrp,
          selectedStock: selectedStock,
        );
        if (entry == null || !context.mounted) {
          // Not silent: the cashier must know the item was NOT billed.
          if (context.mounted) {
            showScaffoldError(
              context: context,
              message: BillingMobileErrorMessages.zeroPriceEntryCancelled,
            );
          }
          debugPrint(
              "❌ Zero-price entry cancelled - product not added to cart");
          debugPrint("=== PRODUCT CART HELPER DEBUG END ===");
          return;
        }
        priceToUse = entry.price;
        cartQuantity = entry.quantity;
        markPriceAsManualOverride = true;
        debugPrint(
            "💰 Zero-price entry applied: price=${entry.price}, quantity=${entry.quantity}");
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
        markPriceAsManualOverride: markPriceAsManualOverride,
        saleUnitId: selectedSaleUnit?.id,
        saleUnitName: selectedSaleUnit?.unitName,
        saleUnitConversionRate: _parseSaleUnitConversionRate(selectedSaleUnit),
        variantId: selectedVariant?.id,
        variantAttributes: selectedVariant?.attributes,
      );

      if (context.mounted) {
        showScaffold(
          context: context,
          message: 'Added To Cart',
        );
      }
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
