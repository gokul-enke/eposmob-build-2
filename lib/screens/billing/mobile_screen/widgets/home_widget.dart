import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';

import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/widgets/product_autocomplete_list_mobile.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';

import 'package:websafe_svg/websafe_svg.dart';

class HomeWidget extends StatefulWidget {
  final String? selectedOrderId;

  const HomeWidget({
    super.key,
    this.selectedOrderId,
  });

  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> {
  // We'll use the BillingProvider controllers and focus nodes instead of local ones

  @override
  void initState() {
    super.initState();

    // Setup focus listeners through billing provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final billingProvider =
          Provider.of<BillingProvider>(context, listen: false);

      // Setup focus change handlers
      billingProvider.quantityFocusNode.addListener(() {
        billingProvider.handleQuantityFocusChange();
      });

      billingProvider.unitPriceFocusNode.addListener(() {
        billingProvider.handleUnitPriceFocusChange();
      });

      // Load order if provided
      _loadOrderIfNeeded();
    });
  }

  @override
  void didUpdateWidget(HomeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOrderId != oldWidget.selectedOrderId) {
      _loadOrderIfNeeded();
    }
  }

  void _loadOrderIfNeeded() {
    if (widget.selectedOrderId != null) {
      final provider =
          Provider.of<LocalProductProvider>(context, listen: false);

      // Check if we need to load the order
      if (provider.currentOrder?.id != widget.selectedOrderId) {
        provider.loadOrderForEditing(widget.selectedOrderId!);

        // Show a message that order is loaded
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showScaffold(
            context: context,
            message: 'Order loaded for editing',
          );
        });
      }
    }
  }

  @override
  void dispose() {
    // Controllers and focus nodes are managed by BillingProvider
    super.dispose();
  }

  Future<void> processBarcode(String barcode) async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    // Use billing provider's barcode processing with debounce
    billingProvider.processBarcodeWithDebounce(barcode, () async {
      String query = barcode;
      List<GetProduct> filteredProducts = [];

      try {
        String? prefix;
        String? productCode;
        String? lastFive;

        if (query.length > 2) {
          prefix = query.substring(0, 3);
        }

        if (prefix != '000' || query.length != 14) {
          filteredProducts =
              Provider.of<LocalProductProvider>(context, listen: false)
                  .filterProductByBarcode(barCode: query);
        } else {
          productCode = query.substring(3, 9);
          lastFive = query.substring(9, 14);
          filteredProducts =
              Provider.of<LocalProductProvider>(context, listen: false)
                  .filterProductByBarcode(barCode: productCode);
        }

        if (filteredProducts.isNotEmpty) {
          GetProduct product = filteredProducts.first;

          num? quantity;
          SaleUnit? matchedSaleUnit;

          for (final saleUnit in product.saleUnits ?? const <SaleUnit>[]) {
            final saleUnitBarcode = saleUnit.barcode?.trim() ?? '';
            if (saleUnitBarcode.isNotEmpty && saleUnitBarcode == query.trim()) {
              matchedSaleUnit = saleUnit;
              break;
            }
          }
          if ((product.unit == 'KGS' || product.unit == 'KG') &&
              prefix == '000' &&
              query.length == 14) {
            String weightKg = lastFive!.substring(0, 2);
            String weightGrams = lastFive.substring(2, 5);
            quantity =
                double.parse(weightKg) + (double.parse(weightGrams) / 1000);
          } else if ((product.unit == 'PCS' || product.unit == 'PC') &&
              prefix == '000' &&
              query.length == 14) {
            quantity = int.parse(lastFive!);
          } else if (matchedSaleUnit != null) {
            quantity =
                num.tryParse(matchedSaleUnit.conversionRate?.trim() ?? '') ?? 1;
          }

          await ProductCartHelper.handleProductSelection(
            context: context,
            product: product,
            quantity: quantity,
            addToCartDirectly: true,
            customerId: billingProvider.selectedCustomerID,
            customerName: billingProvider.selectedCustomer?.name,
            selectedSaleUnit: matchedSaleUnit,
          );

          // Clear fields using billing provider
          billingProvider.clearProductFieldsAndReset();
          _focusTextField();
        } else {
          // Handle barcode not found case
          showScaffoldError(
            context: context,
            message: "Product not found for barcode: $barcode",
          );
        }
      } catch (e) {
        debugPrint("Error processing barcode: $e");
        if (mounted) {
          showScaffoldError(
            context: context,
            message: "Invalid barcode format",
          );
        }
      }
    });
  }

  void _focusTextField() {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    billingProvider.selectedProductNameController.clear();
    Provider.of<LocalProductProvider>(context, listen: false)
        .resetSelectedProduct();
  }

  Future<void> _addItem() async {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);

    billingProvider.setLoadingAddItem(true);

    try {
      final selectedProduct = localProductProvider.selectedProduct;

      if (selectedProduct != null) {
        debugPrint("Adding product: ${selectedProduct.productName}");

        final customPrice =
            double.tryParse(billingProvider.unitPriceController.text);
        final customQuantity =
            num.tryParse(billingProvider.quantityController.text);

        await ProductCartHelper.handleProductSelection(
          context: context,
          product: selectedProduct,
          quantity: customQuantity,
          customPrice:
              customPrice != null && customPrice > 0 ? customPrice : null,
        );

        // Clear fields using billing provider
        billingProvider.clearProductFieldsAndReset();
        _focusTextField();
      } else {
        showScaffoldError(
          context: context,
          message: "Please select a product first",
        );
      }
    } catch (e) {
      debugPrint('Error adding item: $e');
      showScaffoldError(
        context: context,
        message: "Error adding item to cart",
      );
    } finally {
      billingProvider.setLoadingAddItem(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BillingProvider, LocalProductProvider>(
      builder: (context, billingProvider, localProvider, child) {
        final isEditingOrder = localProvider.currentOrder != null;

        return Column(
          children: [
            // Fixed Top Section - Product Entry
            Material(
              elevation: 4,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: _buildProductEntrySection(billingProvider),
              ),
            ),

            // Flexible Middle Section with Proper Scroll
            Flexible(
              child: Container(
                color: Colors.white,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildCartItemsSection(localProvider),
                            // Empty space if needed
                            if (localProvider.cartItems.length < 4)
                              SizedBox(
                                  height: (4 - localProvider.cartItems.length) *
                                      80),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Fixed Bottom Section - Action Buttons
            Material(
              elevation: 8,
              child: Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _buildActionButtons(
                    billingProvider, localProvider, isEditingOrder),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductEntrySection(BillingProvider billingProvider) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: billingProvider.barcodeController,
                focusNode: billingProvider.barcodeNode,
                decoration: InputDecoration(
                  labelText: 'Barcode',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                keyboardType: TextInputType.text,
                onChanged: (query) {
                  if (query.isNotEmpty) {
                    processBarcode(query);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MobileProductAutocomplete(
                autocompleteProductKey: billingProvider.autocompleteProductKey,
                size: MediaQuery.of(context).size,
                onSelected: (GetProduct selectedProduct, Stock? selectedStock) {
                  double defaultPrice = 0.0;
                  if (selectedStock != null) {
                    defaultPrice =
                        double.tryParse(selectedStock.price ?? "0") ?? 0.0;
                  } else {
                    defaultPrice =
                        double.tryParse(selectedProduct.price?.price ?? "0") ??
                            0.0;
                  }

                  billingProvider.selectedProductIdController.text =
                      selectedProduct.productId.toString();
                  billingProvider.unitPriceController.text =
                      defaultPrice.toString();
                  billingProvider.quantityController.text = '1';
                  billingProvider.selectedProductNameController.text =
                      selectedProduct.productName ?? '';
                  billingProvider.barcodeController.text =
                      selectedProduct.barcode ?? '';
                },
                productList:
                    Provider.of<LocalProductProvider>(context, listen: false)
                        .filteredProducts!,
              ),
            ),
            const SizedBox(width: 10),
            BuildBoxShadowContainer(
              height: MediaQuery.of(context).size.height * .07,
              width: 50,
              circleRadius: 5,
              child: InkWell(
                onTap: () {
                  billingProvider.clearProductFieldsAndReset();
                  Provider.of<LocalProductProvider>(context, listen: false)
                      .resetSelectedProduct();
                  _focusTextField();
                  showScaffold(
                    context: context,
                    message: 'Product Details Cleared Successfully',
                  );
                },
                child: Center(
                  child: WebsafeSvg.asset(
                    ImageAssets.oderlistCloseIcon,
                    width: 27,
                    colorFilter: const ColorFilter.mode(
                        ColorManager.kButtonRed, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: billingProvider.quantityController,
                focusNode: billingProvider.quantityFocusNode,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: billingProvider.unitPriceController,
                focusNode: billingProvider.unitPriceFocusNode,
                decoration: InputDecoration(
                  labelText: 'Price',
                  prefixText: ' ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: billingProvider.isLoadingAddItem ? null : _addItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: billingProvider.isLoadingAddItem
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add, color: Colors.white),
              label: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCartItemsSection(LocalProductProvider provider) {
    final cartItems = provider.cartItems;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'ORDER ITEMS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cartItems.length,
            itemBuilder: (_, index) {
              final item = cartItems[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  title: Text(
                    item.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item.displayQuantity} ${item.displayUnitName}'),
                      Text(
                        '${item.displayPrice?.toStringAsFixed(2) ?? '0.00'}',
                      ),
                    ],
                  ),
                  trailing: SizedBox(
                    width: 80, // Fixed width to prevent overflow
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${((item.price ?? 0) * item.quantity).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14, // Slightly smaller font
                          ),
                        ),
                        const SizedBox(height: 4), // Reduced spacing
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 20), // Smaller icon
                          padding: EdgeInsets.zero, // Remove default padding
                          constraints:
                              const BoxConstraints(), // Remove constraints
                          onPressed: () {
                            provider.removeFromCart(
                              item.product.productId!,
                              item.selectedStock,
                              stockGroupIds: item.stockGroupIds,
                              saleUnitId: item.saleUnitId,
                              variantId: item.variantId,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '${provider.cartTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _saveOrder(BillingProvider billingProvider,
      LocalProductProvider provider, bool isEditingOrder) async {
    if (provider.cartItems.isEmpty) {
      showScaffoldError(
        context: context,
        message: "Please add items to cart",
      );
      return;
    }

    // Validate that all items have valid pricing
    bool hasInvalidPricing = provider.cartItems
        .any((item) => item.price == null || (item.price ?? 0) < 0);

    if (hasInvalidPricing) {
      showScaffoldError(
        context: context,
        message: "Please ensure all items have valid prices before saving",
      );
      return;
    }

    try {
      if (isEditingOrder) {
        // Update existing order
        provider.updateSavedOrder(
          provider.currentOrder!.id,
          customerName: provider.currentOrder?.customerName,
          customerPhone: provider.currentOrder?.customerPhone,
          comment: provider.currentOrder?.comment ?? "",
          deliveryMethod:
              provider.currentOrder?.deliveryMethod ?? "Store Takeaway",
          context: context,
        );

        showScaffold(
          context: context,
          message: "Order Updated Successfully",
        );
      } else {
        // Save as new order
        provider.saveCurrentCartAsOrder(
          customerName: null,
          customerPhone: null,
          comment: "",
          deliveryMethod: context.read<BillingProvider>().deliveryMethod,
        );

        showScaffold(
          context: context,
          message: "Order Saved Successfully",
        );
      }

      // Clear cart after successful save
      provider.clearCart();
      provider.clearCurrentOrder();

      // Clear form fields using billing provider
      billingProvider.clearProductFieldsAndReset();

      _focusTextField();
    } catch (e) {
      debugPrint("Error saving order: $e");
      showScaffoldError(
        context: context,
        message: "Failed to save order. Please try again.",
      );
    }
  }

  Widget _buildActionButtons(BillingProvider billingProvider,
      LocalProductProvider provider, bool isEditingOrder) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              billingProvider.clearCart();
              provider.clearCart();
              provider.clearCurrentOrder();
              billingProvider.clearProductFieldsAndReset();
              showScaffold(
                context: context,
                message: 'Cart cleared successfully',
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'CLEAR',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () =>
                _saveOrder(billingProvider, provider, isEditingOrder),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.orange),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isEditingOrder ? 'UPDATE' : 'SAVE',
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ),
        if (Provider.of<AppSettingsProvider>(context, listen: false)
                .appSettings
                ?.showConfirmOrderButton ??
            true)
          const SizedBox(width: 12),
        if (Provider.of<AppSettingsProvider>(context, listen: false)
                .appSettings
                ?.showConfirmOrderButton ??
            true)
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // Implement confirm functionality
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'CONFIRM',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

// Helper functions
void showScaffold({required BuildContext context, required String message}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ),
  );
}

void showScaffoldError(
    {required BuildContext context, required String message}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ),
  );
}
