import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/features/billing/domain/non_stock_visibility.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/widgets/price_selection_modal.dart';
import 'package:pos_machine/widgets/product_card_widget.dart';
import '../providers/grid_provider.dart';
import 'package:provider/provider.dart';

class HorizontalProductViewLocal extends StatefulWidget {
  final int? cartId;
  final bool autofocus;
  final int focusRequestId;
  const HorizontalProductViewLocal({
    super.key,
    this.cartId,
    this.autofocus = false,
    this.focusRequestId = 0,
  });

  @override
  State<HorizontalProductViewLocal> createState() =>
      _HorizontalProductViewLocalState();
}

class _HorizontalProductViewLocalState
    extends State<HorizontalProductViewLocal> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _gridFocusNode = FocusNode();
  bool _isDragging = false;
  int _focusedProductIndex = 0;

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
    _gridFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProducts();
      _requestGridFocusIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant HorizontalProductViewLocal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autofocus &&
        widget.focusRequestId != oldWidget.focusRequestId) {
      _requestGridFocusIfNeeded();
    }
  }

  void _requestGridFocusIfNeeded() {
    if (!widget.autofocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _gridFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _gridFocusNode.dispose();
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
        productName: product.productName ?? 'general.unknown_product'.tr,
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

  KeyEventResult _handleGridKey(KeyEvent event, List<GetProduct> products) {
    if (event is! KeyDownEvent || products.isEmpty) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      final index = _focusedProductIndex.clamp(0, products.length - 1).toInt();
      _handleProductSelection(products[index]);
      return KeyEventResult.handled;
    }

    int? delta;
    if (key == LogicalKeyboardKey.arrowRight) {
      delta = 1;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      delta = -1;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      delta = 3;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      delta = -3;
    }

    if (delta == null) {
      return KeyEventResult.ignored;
    }

    setState(() {
      _focusedProductIndex = (_focusedProductIndex + delta!)
          .clamp(0, products.length - 1)
          .toInt();
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GridSelectionProvider>(
      builder: (context, gridProvider, child) {
        // Quick-access products come from their own provider, so apply the
        // POS_HIDE_NONSTOCK_PRODUCT rule here too.
        final quickAccess =
            gridProvider.quickAccessProductList ?? <GetProduct>[];
        final products = NonStockVisibility.isEnabledIn(context)
            ? NonStockVisibility.filterProducts(
                quickAccess,
                hideNonStockProduct: true,
                stockEnabled: true,
                activeStoreId: NonStockVisibility.activeStoreIdOf(context),
              )
            : quickAccess;

        if (products.isEmpty) {
          return Container();
        }

        final focusedIndex =
            _focusedProductIndex.clamp(0, products.length - 1).toInt();

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
            child: Focus(
              focusNode: _gridFocusNode,
              autofocus: widget.autofocus,
              onKeyEvent: (node, event) => _handleGridKey(event, products),
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
                    isSelected: _gridFocusNode.hasFocus && index == focusedIndex,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
