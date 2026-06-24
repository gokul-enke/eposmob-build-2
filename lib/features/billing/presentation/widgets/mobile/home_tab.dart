import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/features/billing/presentation/widgets/product_entry_header.dart';
import 'package:pos_machine/widgets/sidebar_product_list.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/mobile_home_app_bar.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/mobile_home_cart_card.dart';

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
                MobileHomeAppBar(
                  onShowGrid: () => _showProductGridModal(context),
                ),
                const SizedBox(height: 8),
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
                  child: MobileHomeCartCard(onClearCart: widget.onClearCart),
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
        height: MediaQuery.of(context).size.height * 0.95,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  showSectionTitles: false,
                  visibleRows: 3,
                  crossAxisCount: 4,
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

