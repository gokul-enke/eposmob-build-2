import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/widgets/price_selection_modal.dart';
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
    1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0,
    15.0, 20.0
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
    debugPrint("🎯 HORIZONTAL PRODUCT SELECTION:");
    debugPrint("  - Product: ${product.productName}");
    debugPrint("  - Product ID: ${product.productId}");
    debugPrint("  - About to show price selection modal...");
    
    // Get customer info from global provider
    final customerSelectionProvider = Provider.of<CustomerSelectionProvider>(context, listen: false);
    debugPrint("  - Customer from provider: ${customerSelectionProvider.selectedCustomerName}");
    debugPrint("  - Customer ID from provider: ${customerSelectionProvider.selectedCustomerID}");
    
    // Show price selection modal first
    double? selectedPrice = await showDialog<double>(
      context: context,
      builder: (context) => PriceSelectionModal(
        productName: product.productName ?? 'Unknown Product',
        prices: customPrices,
        onPriceSelected: (double price) {
          debugPrint("🎯 HORIZONTAL MODAL: Price selected: ₹$price");
        },
      ),
    );

    debugPrint("🎯 HORIZONTAL: Price modal result: ${selectedPrice != null ? '₹$selectedPrice' : 'cancelled'}");

    // If user selected a price, proceed with adding to cart
    if (selectedPrice != null) {
      debugPrint("  - Adding to cart with selected price: ₹$selectedPrice");
      await ProductCartHelper.handleProductSelection(
        context: context,
        product: product,
        addToCartDirectly: true, // Add to cart directly for horizontal view
        customPrice: selectedPrice, // Pass the selected price
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

        return SizedBox(
          height: 50,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(
                      products.length,
                      (index) {
                        final product = products[index];
                        return GestureDetector(
                          onTap: () => _handleProductSelection(product),
                          child: Container(
                            width: 120,
                            margin: const EdgeInsets.only(left: 5, right: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 50,
                                  decoration: const BoxDecoration(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      bottomLeft: Radius.circular(10),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      bottomLeft: Radius.circular(10),
                                    ),
                                    child: Image.network(
                                      product.attachment?.isNotEmpty == true
                                          ? product.attachment![0].filePath ??
                                              'https://via.placeholder.com/150'
                                          : 'https://via.placeholder.com/150',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                        color: Colors.grey[100],
                                        child: const Icon(Icons.image_not_supported,
                                            color: Colors.grey, size: 20),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          product.productName ?? 'Product Name',
                                          maxLines: 2,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${product.price?.price ?? ''}/${product.unit ?? ''}',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black.withOpacity(0.7),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
