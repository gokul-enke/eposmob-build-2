import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/screens/billing/widgets/product_entry_header.dart';
import 'package:pos_machine/screens/billing/widgets/cart/cart_items_table.dart';
import 'package:pos_machine/widgets/sidebar_product_list.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/components/build_round_button.dart';

class MobileHomeTab extends StatefulWidget {
  final GlobalKey autocompleteProductKey;
  final Function(String) onProcessBarcode;
  final VoidCallback onClearProductFields;
  final VoidCallback focusTextField;
  final VoidCallback onClearCart;

  const MobileHomeTab({
    super.key,
    required this.autocompleteProductKey,
    required this.onProcessBarcode,
    required this.onClearProductFields,
    required this.focusTextField,
    required this.onClearCart,
  });

  @override
  State<MobileHomeTab> createState() => _MobileHomeTabState();
}

class _MobileHomeTabState extends State<MobileHomeTab> {
  bool _isCartExpanded = true;
  bool _isProductGridVisible = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final productProvider = Provider.of<GridSelectionProvider>(context, listen: false);
    final billingProvider = Provider.of<BillingProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Product Entry Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // App Bar
                Row(
                  children: [
                    Icon(
                      Icons.home,
                      color: ColorManager.kPrimaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Add Products',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isProductGridVisible = !_isProductGridVisible;
                        });
                      },
                      icon: Icon(
                        _isProductGridVisible ? Icons.grid_view : Icons.grid_view_outlined,
                        color: ColorManager.kPrimaryColor,
                      ),
                      tooltip: 'Toggle Product Grid',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Product Entry Fields
                ProductEntryHeader(
                  size: size,
                  barcodeController: billingProvider.barcodeController,
                  quantityController: billingProvider.quantityController,
                  unitPriceController: billingProvider.unitPriceController,
                  selectedProductIdController: billingProvider.selectedProductIdController,
                  productProvider: productProvider,
                  autocompleteProductKey: widget.autocompleteProductKey,
                  onProcessBarcode: widget.onProcessBarcode,
                  onClearProductFields: widget.onClearProductFields,
                  focusTextField: widget.focusTextField,
                ),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: Column(
              children: [
                // Product Grid (if visible)
                if (_isProductGridVisible)
                  Container(
                    height: 200,
                    color: Colors.white,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: BuildBoxShadowContainer(
                      circleRadius: 12,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: SideBarProductList(),
                      ),
                    ),
                  ),

                // Cart Section
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: BuildBoxShadowContainer(
                      circleRadius: 12,
                      child: Column(
                        children: [
                          // Cart Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.shopping_cart,
                                  color: ColorManager.kPrimaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Shopping Cart',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                // Cart Summary
                                Consumer<LocalProductProvider>(
                                  builder: (context, provider, child) {
                                    final summary = provider.priceSummary;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${provider.cartItems.length} items',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          '₹${summary?.netTotal.toStringAsFixed(2) ?? '0.00'}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: ColorManager.kPrimaryColor,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isCartExpanded = !_isCartExpanded;
                                    });
                                  },
                                  child: AnimatedRotation(
                                    turns: _isCartExpanded ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Cart Items
                          if (_isCartExpanded)
                            const Expanded(
                              child: CartItemsTable(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Quick Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Clear Cart Button
                      Expanded(
                        child: Consumer<BillingProvider>(
                          builder: (context, provider, child) {
                            return CustomRoundButton(
                              title: provider.isLoadingClearCart ? "Clearing..." : "Clear Cart",
                              fct: provider.isLoadingClearCart ? () {} : widget.onClearCart,
                              fontSize: 14,
                              height: 48,
                              width: double.infinity,
                              boxColor: Colors.red.shade50,
                              borderColor: Colors.red.shade300,
                              textColor: Colors.red.shade700,
                              radius: 12,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Add Custom Product Button
                      Expanded(
                        child: CustomRoundButton(
                          title: "Add Custom",
                          fct: () {
                            // Show add custom product modal
                            _showAddCustomProductModal(context);
                          },
                          fontSize: 14,
                          height: 48,
                          width: double.infinity,
                          boxColor: ColorManager.kPrimaryColor.withOpacity(0.1),
                          borderColor: ColorManager.kPrimaryColor,
                          textColor: ColorManager.kPrimaryColor,
                          radius: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCustomProductModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Add Custom Product',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Form fields would go here
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Product Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: 'Price',
                              prefixText: '₹',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: CustomRoundButton(
                        title: "Add to Cart",
                        fct: () {
                          // Add custom product logic
                          Navigator.pop(context);
                        },
                        fontSize: 16,
                        height: 50,
                        width: double.infinity,
                        boxColor: ColorManager.kPrimaryColor,
                        borderColor: ColorManager.kPrimaryColor,
                        textColor: Colors.white,
                        radius: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
