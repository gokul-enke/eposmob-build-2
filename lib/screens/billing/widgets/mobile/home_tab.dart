import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/screens/billing/widgets/product_entry_header.dart';
import 'package:pos_machine/screens/billing/widgets/cart/cart_items_table.dart';
import 'package:pos_machine/widgets/sidebar_product_list.dart';
import 'package:pos_machine/widgets/sync_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';

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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final productProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Product Entry Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // App Bar (Order info + controls)
                Row(
                  children: [
                    // Left: Order label + number (like desktop)
                    Consumer<LocalProductProvider>(
                      builder: (context, localProductProvider, _) {
                        final isEditingOrder =
                            localProductProvider.currentOrder != null;
                        final orderNumber = isEditingOrder
                            ? '#${localProductProvider.currentOrder!.orderNumber}'
                            : '#00000';
                        return Row(
                          children: [
                            Text(
                              isEditingOrder ? 'Edit - ' : 'New - ',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              orderNumber,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const Spacer(),
                    // Keyboard toggle
                    Consumer<KeyboardProvider>(
                      builder: (context, keyboardProvider, _) {
                        final showing = keyboardProvider.showKeyboardFeature;
                        return IconButton(
                          onPressed: () {
                            if (showing) {
                              keyboardProvider.featureOff();
                              keyboardProvider.clear();
                            } else {
                              keyboardProvider.featureOn();
                            }
                          },
                          icon: Icon(
                            showing ? Icons.keyboard_hide : Icons.keyboard,
                            color: showing
                                ? ColorManager.kPrimaryColor
                                : Colors.grey.shade600,
                          ),
                          tooltip: showing ? 'Hide Keyboard' : 'Show Keyboard',
                        );
                      },
                    ),
                    // Sync button
                    const SyncButton(
                      showTooltip: true,
                      showText: false,
                    ),
                    const SizedBox(width: 4),
                    // Connectivity indicator
                    _ConnectivityIndicatorMobile(),
                    const SizedBox(width: 8),
                    // Grid toggle - Show modal instead
                    IconButton(
                      onPressed: () {
                        _showProductGridModal(context);
                      },
                      icon: const Icon(
                        Icons.grid_view_outlined,
                        color: ColorManager.kPrimaryColor,
                      ),
                      tooltip: 'Show Product Grid',
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
                  selectedProductIdController:
                      billingProvider.selectedProductIdController,
                  productProvider: productProvider,
                  autocompleteProductKey: widget.autocompleteProductKey,
                  onProcessBarcode: widget.onProcessBarcode,
                  onClearProductFields: widget.onClearProductFields,
                  focusTextField: widget.focusTextField,
                ),
              ],
            ),
          ),

          // Content Area - Now just cart and actions
          Expanded(
            child: Column(
              children: [
                // Cart Section - Takes most of the space
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                                const Icon(
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
                                    // Use cartTotal getter to recalculate and update summary live
                                    final total = provider.cartTotal;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${provider.cartItems.length} items',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          '₹${total.toStringAsFixed(2)}',
                                          style: const TextStyle(
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

                          // Cart Items - Takes remaining space
                          if (_isCartExpanded)
                            const Expanded(
                              child: CartItemsTable(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Quick Actions - Fixed at bottom
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      // Clear Cart Button
                      Expanded(
                        child: Consumer<BillingProvider>(
                          builder: (context, provider, child) {
                            return CustomRoundButton(
                              title: provider.isLoadingClearCart
                                  ? "Clearing..."
                                  : "Clear Cart",
                              fct: provider.isLoadingClearCart
                                  ? () {}
                                  : widget.onClearCart,
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
                      // Add Custom Product Button (commented out)
                      // const SizedBox(width: 12),
                      // Expanded(
                      //   child: CustomRoundButton(
                      //     title: "Add Custom",
                      //     fct: () {
                      //       // Show add custom product modal
                      //       _showAddCustomProductModal(context);
                      //     },
                      //     fontSize: 14,
                      //     height: 48,
                      //     width: double.infinity,
                      //     boxColor: ColorManager.kPrimaryColor.withOpacity(0.1),
                      //     borderColor: ColorManager.kPrimaryColor,
                      //     textColor: ColorManager.kPrimaryColor,
                      //     radius: 12,
                      //   ),
                      // ),
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

  void _showProductGridModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
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
                  const Icon(
                    Icons.grid_view,
                    color: ColorManager.kPrimaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Product Grid',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Product Grid Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SideBarProductList(
                  categoryHeight: 80,
                  dividerHeight: 1,
                  onProductSelected: (product) async {
                    // Add selected product to cart, then close the modal
                    await ProductCartHelper.handleProductSelection(
                      context: context,
                      product: product,
                      addToCartDirectly: true,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*
  // Commented out since the 'Add Custom' button is disabled.
  void _showAddCustomProductModal(BuildContext context) {
    // ... modal implementation was here
  }
  */
}

class _ConnectivityIndicatorMobile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<BillingProvider>(
      builder: (context, billingProvider, child) {
        final hasNet = billingProvider.hasInternet;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: hasNet
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasNet ? Colors.green : Colors.red,
              width: 1,
            ),
          ),
          child: Icon(
            hasNet ? Icons.wifi : Icons.wifi_off,
            size: 18,
            color: hasNet ? Colors.green : Colors.red,
          ),
        );
      },
    );
  }
}
