import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/customer_purchase_history.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/providers/customer_purchase_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/widgets/stock_selection_modal.dart';
import 'package:pos_machine/widgets/customer_purchase_history_modal.dart';
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
  /// 2. CUSTOMER PURCHASE HISTORY (if customer selected):
  ///    - Fetch customer's last purchases for this product
  ///    - Show history modal with current price (from stock or product)
  ///    - User can choose historical price+quantity OR current price
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
    final customerSelectionProvider = Provider.of<CustomerSelectionProvider>(context, listen: false);
    
    // Use provided customer info first, fallback to global provider
    final int? effectiveCustomerId = customerId ?? customerSelectionProvider.selectedCustomerID;
    final String? effectiveCustomerName = customerName ?? customerSelectionProvider.selectedCustomerName;
    
    debugPrint("🌐 GLOBAL CUSTOMER INFO:");
    debugPrint("  - Provider has customer: ${customerSelectionProvider.hasSelectedCustomer}");
    debugPrint("  - Provider customer ID: ${customerSelectionProvider.selectedCustomerID}");
    debugPrint("  - Provider customer name: ${customerSelectionProvider.selectedCustomerName}");
    debugPrint("  - Effective customer ID: $effectiveCustomerId");
    debugPrint("  - Effective customer name: $effectiveCustomerName");

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final generalSettingsProvider =
        Provider.of<GeneralSettingsProvider>(context, listen: false);

    // Check if stock management is enabled
    bool stockEnabled = generalSettingsProvider.generalSettings?.stockEnabled ?? false;
    debugPrint("📦 Stock management enabled: $stockEnabled");
    
    // Set the stock enabled status in LocalProductProvider
    localProductProvider.setStockEnabled(stockEnabled);

    // Variables to track selected stock and final values
    Stock? selectedStock;
    double? finalPrice = customPrice;
    double? finalMrp = customMrp;
    num? finalQuantity = quantity;

    // STEP 1: Handle stock selection if stock management is enabled
    if (stockEnabled && product.stock != null && product.stock!.isNotEmpty) {
      debugPrint("📦 STEP 1: Handling stock selection...");
      
      if (product.stock!.length > 1) {
        debugPrint("📦 Multiple stock entries detected, filtering available stocks...");
        debugPrint("  - Total stock entries: ${product.stock!.length}");
        
        // Filter available stock options (quantity > 0)
        List<Stock> availableStocks = product.stock!
            .where((stock) => stock.quantity != null && stock.quantity! > 0)
            .toList();

        debugPrint("📦 Available stocks after filtering: ${availableStocks.length}");
        for (int i = 0; i < availableStocks.length; i++) {
          Stock stock = availableStocks[i];
          debugPrint("  Stock $i: ID=${stock.id}, Price=${stock.price}, MRP=${stock.mrp}, Qty=${stock.quantity}");
        }

        if (availableStocks.length > 1) {
          debugPrint("📱 Showing stock selection modal for user choice...");
          
          // Show stock selection modal
          final result = await showDialog(
            context: context,
            builder: (context) => StockSelectionModal(
              product: product,
              stockOptions: availableStocks,
            ),
          );

          if (result != null) {
            debugPrint("✅ User selected stock from modal");
            
            // Process the selected product and stock
            GetProduct selectedProduct = result['product'];
            selectedStock = result['stock'];

            debugPrint("📦 Selected stock details:");
            debugPrint("  - Stock ID: ${selectedStock!.id}");
            debugPrint("  - Stock Price: ${selectedStock!.price}");
            debugPrint("  - Stock MRP: ${selectedStock!.mrp}");

            // Use stock prices as the current prices for customer history modal
            finalPrice = finalPrice ?? double.tryParse(selectedStock!.price ?? "0") ?? 0;
            finalMrp = finalMrp ?? double.tryParse(selectedStock!.mrp ?? "0") ?? 0;

            debugPrint("💰 Stock-based pricing set:");
            debugPrint("  - Final Price: $finalPrice");
            debugPrint("  - Final MRP: $finalMrp");

          } else {
            debugPrint("❌ User cancelled stock selection - aborting");
            debugPrint("=== PRODUCT CART HELPER DEBUG END ===");
            return;
          }
        } else if (availableStocks.isNotEmpty) {
          debugPrint("📦 Single available stock found, auto-selecting...");
          
          // Single stock option available, use it
          selectedStock = availableStocks.first;

          debugPrint("📦 Auto-selected stock details:");
          debugPrint("  - Stock ID: ${selectedStock!.id}");
          debugPrint("  - Stock Price: ${selectedStock!.price}");
          debugPrint("  - Stock MRP: ${selectedStock!.mrp}");
          debugPrint("  - Stock Quantity: ${selectedStock!.quantity}");

          // Use stock prices as the current prices
          finalPrice = finalPrice ?? double.tryParse(selectedStock!.price ?? "0") ?? 0;
          finalMrp = finalMrp ?? double.tryParse(selectedStock!.mrp ?? "0") ?? 0;

          debugPrint("💰 Auto-selected stock pricing:");
          debugPrint("  - Final Price: $finalPrice");
          debugPrint("  - Final MRP: $finalMrp");

        } else {
          debugPrint("❌ No available stock found (all stocks have 0 quantity)");
          showScaffold(
            context: context,
            message: "No stock available for this product.",
          );
          debugPrint("=== PRODUCT CART HELPER DEBUG END ===");
          return;
        }
      } else {
        debugPrint("📦 Product has single stock entry, extracting stock information...");
        
        // Single stock entry - extract the stock information
        selectedStock = product.stock!.first;
        
        debugPrint("📦 Single stock details:");
        debugPrint("  - Stock ID: ${selectedStock!.id}");
        debugPrint("  - Stock Price: ${selectedStock!.price}");
        debugPrint("  - Stock MRP: ${selectedStock!.mrp}");
        debugPrint("  - Stock Quantity: ${selectedStock!.quantity}");

        // Use stock prices as the current prices
        finalPrice = finalPrice ?? double.tryParse(selectedStock!.price ?? "0") ?? 0;
        finalMrp = finalMrp ?? double.tryParse(selectedStock!.mrp ?? "0") ?? 0;

        debugPrint("💰 Single stock pricing:");
        debugPrint("  - Final Price: $finalPrice");
        debugPrint("  - Final MRP: $finalMrp");
      }
    } else if (!stockEnabled) {
      debugPrint("📦 Stock management disabled - using product base pricing");
      
      // Use product's base price and MRP when stock is disabled
      finalPrice = finalPrice ?? double.tryParse(product.price?.price ?? "0") ?? 0;
      finalMrp = finalMrp ?? double.tryParse(product.mrp ?? "0") ?? 0;
      
      // Only pass stock if the addToCart method absolutely requires it (to prevent null errors)
      if (product.stock != null && product.stock!.isNotEmpty) {
        selectedStock = product.stock!.first; // Just to prevent null errors, not for stock management
        debugPrint("📦 Using first stock entry only to prevent null errors, not for stock logic");
        debugPrint("  - Stock ID: ${selectedStock!.id}");
      }

      debugPrint("💰 Product base pricing (Stock Disabled):");
      debugPrint("  - Final Price: $finalPrice");
      debugPrint("  - Final MRP: $finalMrp");
    } else {
      debugPrint("📦 Product has no stock entries, using basic product info...");
      finalPrice = finalPrice ?? double.tryParse(product.price?.price ?? "0") ?? 0;
      finalMrp = finalMrp ?? double.tryParse(product.mrp ?? "0") ?? 0;
      
      debugPrint("💰 Product base pricing (No Stock):");
      debugPrint("  - Final Price: $finalPrice");
      debugPrint("  - Final MRP: $finalMrp");
    }

    // STEP 2: Check for customer purchase history if customer is selected and we're adding directly to cart
    if (addToCartDirectly && effectiveCustomerId != null && effectiveCustomerName != null) {
      debugPrint("🔍 STEP 2: CUSTOMER PURCHASE HISTORY CHECK STARTING...");
      debugPrint("Conditions met for purchase history check:");
      debugPrint("  - addToCartDirectly: $addToCartDirectly");
      debugPrint("  - effectiveCustomerId: $effectiveCustomerId");
      debugPrint("  - effectiveCustomerName: $effectiveCustomerName");
      debugPrint("  - productId: ${product.productId}");
      debugPrint("  - Current price (from stock or product): $finalPrice");

      // Check if this is the default customer (first customer from list) - skip purchase history for default customer
      final customerSelectionProvider = Provider.of<CustomerSelectionProvider>(context, listen: false);
      final bool isDefaultCustomer = customerSelectionProvider.isDefaultCustomer;
      debugPrint("  - isDefaultCustomer: $isDefaultCustomer");
      
      if (isDefaultCustomer) {
        debugPrint("⏭️ SKIPPING purchase history check - this is the default customer");
        debugPrint("🔍 CUSTOMER PURCHASE HISTORY CHECK COMPLETED (SKIPPED)");
      } else {
        try {
          debugPrint("Getting auth token and creating purchase provider...");
          
          final authModel = Provider.of<AuthModel>(context, listen: false);
          final String? token = authModel.token;
          debugPrint("Auth token available: ${token != null && token.isNotEmpty}");
          
          if (token == null || token.isEmpty) {
            debugPrint("❌ No auth token available, skipping purchase history check");
          } else {
            final customerPurchaseProvider = CustomerPurchaseProvider();
            
            debugPrint("📞 Calling customer purchase API...");
            final CustomerPurchaseHistory? purchaseHistory = 
                await customerPurchaseProvider.getCustomerLastPurchases(
              accessToken: token,
              customerId: effectiveCustomerId!,
              productId: product.productId!,
            );
            
            debugPrint("📋 Purchase History API Response:");
            if (purchaseHistory == null) {
              debugPrint("  - Result: null (API failed or exception occurred)");
            } else {
              debugPrint("  - Result: Success = ${purchaseHistory.success}");
              debugPrint("  - Data count: ${purchaseHistory.data.length}");
              
              if (purchaseHistory.data.isNotEmpty) {
                debugPrint("  - Purchase records:");
                for (int i = 0; i < purchaseHistory.data.length; i++) {
                  final item = purchaseHistory.data[i];
                  debugPrint("    Record $i: Price=${item.price}, Qty=${item.quantity}, Date=${item.date}, Order=${item.orderNumber}");
                }
              }
            }
            
            if (purchaseHistory != null && 
                purchaseHistory.success && 
                purchaseHistory.data.isNotEmpty) {
              debugPrint("✅ Found ${purchaseHistory.data.length} purchase history records");
              debugPrint("📱 Showing purchase history modal...");
              
              // Show purchase history modal
              final result = await showDialog(
                context: context,
                builder: (context) => CustomerPurchaseHistoryModal(
                  product: product,
                  purchaseHistory: purchaseHistory.data.take(5).toList(), // Limit to 5 records
                  customerName: effectiveCustomerName!,
                ),
              );
              
              debugPrint("📱 Purchase history modal result:");
              if (result == null) {
                debugPrint("  - User cancelled the modal");
                debugPrint("❌ User cancelled purchase history selection - aborting cart addition");
                debugPrint("=== PRODUCT CART HELPER DEBUG END ===");
                return; // User cancelled, don't proceed with adding to cart
              } else {
                debugPrint("  - User made a selection: ${result.keys.toList()}");
                
                if (result['useCurrentPrice'] == true) {
                  debugPrint("  - User chose to use current price: $finalPrice");
                  debugPrint("  - Keeping current stock selection and pricing");
                  // Continue with current finalPrice and selectedStock
                } else if (result['price'] != null) {
                  debugPrint("  - User selected historical price: ${result['price']}");
                  
                  // Use the selected historical price but keep the selected stock
                  finalPrice = result['price'];
                  debugPrint("  - Updated finalPrice to: $finalPrice");
                  debugPrint("  - Quantity remains: $finalQuantity (not using historical quantity)");
                  debugPrint("  - Stock remains: ${selectedStock?.id} (for inventory tracking)");
                }
              }
            } else {
              debugPrint("ℹ️ No purchase history found for this customer and product");
              debugPrint("  - purchaseHistory == null: ${purchaseHistory == null}");
              if (purchaseHistory != null) {
                debugPrint("  - purchaseHistory.success: ${purchaseHistory.success}");
                debugPrint("  - purchaseHistory.data.isEmpty: ${purchaseHistory.data.isEmpty}");
              }
            }
          }
        } catch (e, stackTrace) {
          debugPrint("❌ Error checking customer purchase history: $e");
          debugPrint("Stack trace: $stackTrace");
          debugPrint("⚠️ Continuing with normal flow despite error");
          // Continue with normal flow if there's an error
        }
      }
      
      debugPrint("🔍 CUSTOMER PURCHASE HISTORY CHECK COMPLETED");
    } else {
      debugPrint("⏭️ Skipping customer purchase history check:");
      debugPrint("  - addToCartDirectly: $addToCartDirectly");
      debugPrint("  - effectiveCustomerId: $effectiveCustomerId");
      debugPrint("  - effectiveCustomerName: $effectiveCustomerName");
    }

    // STEP 3: Handle onSelected callback if provided
    if (onSelected != null) {
      debugPrint("🔄 STEP 3: Calling onSelected callback...");
      onSelected(product, selectedStock);
      localProductProvider.callProductDetails(product.productId!, selectedStock: selectedStock);
    }

    // STEP 4: Add to cart if required
    if (addToCartDirectly) {
      // Set final values with defaults
      final cartQuantity = finalQuantity ?? 1;
      
      debugPrint("🛒 STEP 4: ADDING TO CART");
      debugPrint("Product: ${product.productName}");
      debugPrint("Final Quantity: $cartQuantity");
      debugPrint("Final Price: $finalPrice");
      debugPrint("Final MRP: $finalMrp");
      debugPrint("Selected Stock ID: ${selectedStock?.id}");
      debugPrint("Stock Management Enabled: $stockEnabled");
      
      localProductProvider.addToCart(
        product: product,
        quantity: cartQuantity,
        price: finalPrice,
        mrp: finalMrp,
        selectedStock: selectedStock,
      );

      showScaffold(
        context: context,
        message: 'Added To Cart',
      );
    }
    
    debugPrint("=== PRODUCT CART HELPER DEBUG END ===");
  }
} 