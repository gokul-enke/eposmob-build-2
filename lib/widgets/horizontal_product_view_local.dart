import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/widgets/price_selection_modal.dart';
import 'package:pos_machine/widgets/product_card_widget.dart';
import '../providers/grid_provider.dart';
import 'package:provider/provider.dart';

class HorizontalProductViewLocal extends StatefulWidget {
  final int? cartId;
  const HorizontalProductViewLocal({super.key, this.cartId});

  @override
  State<HorizontalProductViewLocal> createState() =>
      _HorizontalProductViewLocalState();
}

class _HorizontalProductViewLocalState
    extends State<HorizontalProductViewLocal> {
  final ScrollController _scrollController = ScrollController();
  bool _isDragging = false;

  // Define your custom prices array
  final List<double> customPrices = [
    1.0,
    2.0,
    3.0,
    4.0,
    5.0,
    6.0,
    7.0,
    8.0,
    9.0,
    10.0,
    15.0,
    20.0
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProducts();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    final gridProvider =
        Provider.of<GridSelectionProvider>(context, listen: false);
    await gridProvider.listQuickAccessProducts();
  }

  Future<void> _handleProductSelection(GetProduct product) async {
    // Get currency from app settings
    final currency = Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.currency ??
        'INR';

    debugPrint("🎯 HORIZONTAL PRODUCT SELECTION:");
    debugPrint("  - Product: ${product.productName ?? ''}");
    debugPrint("  - Product ID: ${product.productId}");
    debugPrint("  - About to show price selection modal...");

    // Get customer info from global provider
    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    debugPrint(
        "  - Customer from provider: ${customerSelectionProvider.selectedCustomerName}");
    debugPrint(
        "  - Customer ID from provider: ${customerSelectionProvider.selectedCustomerID}");

    // Show price selection modal first
    double? selectedPrice = await showDialog<double>(
      context: context,
      builder: (context) => PriceSelectionModal(
        productName: product.productName ?? 'Unknown Product',
        prices: customPrices,
        onPriceSelected: (double price) {
          debugPrint("🎯 HORIZONTAL MODAL: Price selected: $currency$price");
        },
      ),
    );

    debugPrint(
        "🎯 HORIZONTAL: Price modal result: ${selectedPrice != null ? '$currency$selectedPrice' : 'cancelled'}");

    // If user selected a price, proceed with adding to cart
    if (selectedPrice != null) {
      debugPrint(
          "  - Adding to cart with selected price: $currency$selectedPrice");
      await ProductCartHelper.handleProductSelection(
        context: context,
        product: product,
        addToCartDirectly: true, // Add to cart directly for horizontal view
        customPrice: selectedPrice, // Pass the selected price
        customMrp: selectedPrice,
        // Customer info will be fetched from global provider in the helper
      );
    } else {
      debugPrint("  - User cancelled price selection - not adding to cart");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GridSelectionProvider>(
      builder: (context, gridProvider, child) {
        final products = gridProvider.quickAccessProductList ?? [];

        if (products.isEmpty) {
          return Container();
        }

        return Container(
          height: 300, // Fixed height for grid
          padding: const EdgeInsets.all(8),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.trackpad,
              },
            ),
            child: GridView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 3 cards per row like sidebar
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8, // Same as sidebar
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ProductCardWidget(
                  product: product,
                  onTap: () => _handleProductSelection(product),
                  isSelected: false, // You can add selection logic if needed
                );
              },
            ),
          ),
        );
      },
    );
  }
}
