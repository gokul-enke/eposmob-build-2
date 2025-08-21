import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/widgets/product_autocomplete_list_mobile.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/widgets/product_autocomplete_list.dart';
import 'package:websafe_svg/websafe_svg.dart';

class HomeWidget extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final String? selectedOrderId;

  const HomeWidget({
    super.key,
    required this.cartItems,
    this.selectedOrderId,
  });

  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> {
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitPriceController = TextEditingController();
  final TextEditingController selectedProductIdController =
      TextEditingController();
  final TextEditingController selectedProductNameController =
      TextEditingController();
  final FocusNode _quantityFocusNode = FocusNode();
  final FocusNode _unitPriceFocusNode = FocusNode();
  final FocusNode _barcodeNode = FocusNode();
  bool _isProcessingBarcode = false;
  bool isLoadingAddItem = false;
  GlobalKey _autocompleteProductKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _quantityFocusNode.addListener(() {
      if (_quantityFocusNode.hasFocus) {
        quantityController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: quantityController.text.length,
        );
      }
    });

    _unitPriceFocusNode.addListener(() {
      if (_unitPriceFocusNode.hasFocus) {
        unitPriceController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: unitPriceController.text.length,
        );
      }
    });

    // Load order if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      final provider = Provider.of<LocalProductProvider>(context, listen: false);
      
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
    barcodeController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    selectedProductIdController.dispose();
    selectedProductNameController.dispose();
    _quantityFocusNode.dispose();
    _unitPriceFocusNode.dispose();
    _barcodeNode.dispose();
    super.dispose();
  }

  Future<void> processBarcode(String barcode) async {
    if (_isProcessingBarcode || barcode.isEmpty) return;

    setState(() {
      _isProcessingBarcode = true;
    });
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
        }

        await ProductCartHelper.handleProductSelection(
          context: context,
          product: product,
          quantity: quantity,
          addToCartDirectly: true,
        );

        setState(() {
          _autocompleteProductKey = GlobalKey();
          quantityController.clear();
          barcodeController.clear();
          selectedProductIdController.clear();
          unitPriceController.clear();
        });
        _focusTextField();
      } else {
        // Handle barcode not found case
      }
    } catch (e) {
      debugPrint("Error processing barcode: $e");
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isProcessingBarcode = false;
          });
        }
      });
    }
  }

  void _focusTextField() {
    selectedProductNameController.clear();
    Provider.of<LocalProductProvider>(context, listen: false)
        .resetSelectedProduct();
  }

  Future<void> _addItem() async {
    setState(() {
      isLoadingAddItem = true;
    });
    try {
      final localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final selectedProduct = localProductProvider.selectedProduct;

      if (selectedProduct != null) {
        debugPrint("Adding product: ${selectedProduct.productName}");

        localProductProvider.addToCart(
          product: selectedProduct,
          quantity: num.tryParse(quantityController.text),
          price: double.tryParse(unitPriceController.text),
        );

        setState(() {
          _autocompleteProductKey = GlobalKey();
          quantityController.clear();
          barcodeController.clear();
          selectedProductIdController.clear();
          unitPriceController.clear();
        });
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
      setState(() {
        isLoadingAddItem = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalProductProvider>(
      builder: (context, provider, child) {
        
        final isEditingOrder = provider.currentOrder != null;
        
        return Column(
          children: [
            // Fixed Top Section - Product Entry
            Material(
              elevation: 4,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: _buildProductEntrySection(),
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
                            _buildCartItemsSection(provider),
                            // Empty space if needed
                            if (provider.cartItems.length < 4)
                              SizedBox(height: (4 - provider.cartItems.length) * 80),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _buildActionButtons(provider, isEditingOrder),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductEntrySection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: barcodeController,
                focusNode: _barcodeNode,
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
                autocompleteProductKey: _autocompleteProductKey,
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

                  setState(() {
                    selectedProductIdController.text =
                        selectedProduct.productId.toString();
                    unitPriceController.text = defaultPrice.toString();
                    quantityController.text = '1';
                    selectedProductNameController.text =
                        selectedProduct.productName ?? '';
                    barcodeController.text = selectedProduct.barcode ?? '';
                  });
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
                  setState(() {
                    _autocompleteProductKey = GlobalKey();
                    quantityController.clear();
                    barcodeController.clear();
                    selectedProductIdController.clear();
                    unitPriceController.clear();
                    selectedProductNameController.clear();
                  });
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
                    color: ColorManager.kButtonRed,
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
                controller: quantityController,
                focusNode: _quantityFocusNode,
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
                controller: unitPriceController,
                focusNode: _unitPriceFocusNode,
                decoration: InputDecoration(
                  labelText: 'Price',
                  prefixText: '₹ ',
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
              onPressed: isLoadingAddItem ? null : _addItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: isLoadingAddItem
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                title: Text(
                  item.product.productName ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.quantity} ${item.product.unit ?? ''}'),
                    Text('₹${item.price?.toStringAsFixed(2) ?? '0.00'}'),
                  ],
                ),
                trailing: SizedBox(
                  width: 80, // Fixed width to prevent overflow
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${(item.price! * item.quantity).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14, // Slightly smaller font
                        ),
                      ),
                      const SizedBox(height: 4), // Reduced spacing
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20), // Smaller icon
                        padding: EdgeInsets.zero, // Remove default padding
                        constraints: const BoxConstraints(), // Remove constraints
                        onPressed: () {
                          provider.removeFromCart(
                            item.product.productId!,
                            item.selectedStock,
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
              '₹${provider.cartTotal.toStringAsFixed(2)}',
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

  void _saveOrder(LocalProductProvider provider, bool isEditingOrder) async {
    if (provider.cartItems.isEmpty) {
      showScaffoldError(
        context: context,
        message: "Please add items to cart",
      );
      return;
    }

    // Validate that all items have valid pricing
    bool hasInvalidPricing = provider.cartItems
        .any((item) => item.price == null || item.price! < 0);

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
          deliveryMethod: provider.currentOrder?.deliveryMethod ?? "Store Takeaway",
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
          deliveryMethod: "Store Takeaway",
        );

        showScaffold(
          context: context,
          message: "Order Saved Successfully",
        );
      }

      // Clear cart after successful save
      provider.clearCart();
      provider.clearCurrentOrder();

      // Clear form fields
      setState(() {
        quantityController.clear();
        barcodeController.clear();
        selectedProductIdController.clear();
        unitPriceController.clear();
        selectedProductNameController.clear();
      });

      _focusTextField();

    } catch (e) {
      debugPrint("Error saving order: $e");
      showScaffoldError(
        context: context,
        message: "Failed to save order. Please try again.",
      );
    }
  }

  Widget _buildActionButtons(LocalProductProvider provider, bool isEditingOrder) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              provider.clearCart();
              provider.clearCurrentOrder();
              setState(() {
                quantityController.clear();
                barcodeController.clear();
                selectedProductIdController.clear();
                unitPriceController.clear();
                selectedProductNameController.clear();
              });
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
            onPressed: () => _saveOrder(provider, isEditingOrder),
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
        const SizedBox(width: 12),
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

void showScaffoldError({required BuildContext context, required String message}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ),
  );
}