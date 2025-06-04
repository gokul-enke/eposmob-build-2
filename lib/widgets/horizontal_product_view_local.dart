import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';
import 'package:pos_machine/widgets/stock_selection_modal.dart';
import 'package:pos_machine/models/get_product.dart';
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
    debugPrint("=== HORIZONTAL PRODUCT VIEW DEBUG ===");
    debugPrint("Product selected: ${product.productName}");
    debugPrint("Product ID: ${product.productId}");
    debugPrint("Product base price: ${product.price?.price ?? 'null'}");
    debugPrint("Product MRP: ${product.mrp ?? 'null'}");
    debugPrint("Product has ${product.stock?.length ?? 0} stock entries");

    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final generalSettingsProvider =
        Provider.of<GeneralSettingsProvider>(context, listen: false);

    // Check if stock management is enabled
    bool stockEnabled = generalSettingsProvider.generalSettings?.stockEnabled ?? false;
    debugPrint("Stock management enabled: $stockEnabled");

    if (!stockEnabled) {
      debugPrint("Stock management disabled, adding product directly to cart...");
      
      localProductProvider.addToCart(
        product: product,
      );

      showScaffold(
        context: context,
        message: 'Added To Cart',
      );
      debugPrint("=== END HORIZONTAL PRODUCT VIEW DEBUG ===");
      return;
    }

    // Check if product has multiple stock options
    if (product.stock != null && product.stock!.length > 1) {
      debugPrint("Multiple stock entries detected, filtering available stocks...");
      
      // Filter available stock options (quantity > 0)
      List<Stock> availableStocks = product.stock!
          .where((stock) => stock.quantity != null && stock.quantity! > 0)
          .toList();

      debugPrint("Available stocks after filtering: ${availableStocks.length}");
      for (int i = 0; i < availableStocks.length; i++) {
        Stock stock = availableStocks[i];
        debugPrint("  Stock $i: ID=${stock.id}, Price=${stock.price}, MRP=${stock.mrp}, Qty=${stock.quantity}");
      }

      if (availableStocks.length > 1) {
        debugPrint("Showing stock selection modal for user choice...");
        
        // Show stock selection modal
        final result = await showDialog(
          context: context,
          builder: (context) => StockSelectionModal(
            product: product,
            stockOptions: availableStocks,
          ),
        );

        if (result != null) {
          debugPrint("User selected stock from modal");
          
          // Process the selected product and stock
          GetProduct selectedProduct = result['product'];
          Stock selectedStock = result['stock'];

          debugPrint("Selected stock: ID=${selectedStock.id}, Price=${selectedStock.price}, MRP=${selectedStock.mrp}");

          double stockPrice = double.tryParse(selectedStock.price ?? "0") ?? 0;
          double stockMrp = double.tryParse(selectedStock.mrp ?? "0") ?? 0;

          debugPrint("Adding to cart: Price=${stockPrice}, MRP=${stockMrp}");

          localProductProvider.addToCart(
            product: selectedProduct,
            price: stockPrice,
            mrp: stockMrp,
            selectedStock: selectedStock,
          );

          showScaffold(
            context: context,
            message: 'Added To Cart',
          );
        } else {
          debugPrint("User cancelled stock selection");
        }
      } else if (availableStocks.isNotEmpty) {
        debugPrint("Single available stock found, auto-selecting...");
        
        // Single stock option available, use it
        Stock stock = availableStocks.first;

        debugPrint("Auto-selected stock: ID=${stock.id}, Price=${stock.price}, MRP=${stock.mrp}, Qty=${stock.quantity}");

        double stockPrice = double.tryParse(stock.price ?? "0") ?? 0;
        double stockMrp = double.tryParse(stock.mrp ?? "0") ?? 0;

        debugPrint("Adding to cart with single stock: Price=${stockPrice}, MRP=${stockMrp}");

        localProductProvider.addToCart(
          product: product,
          price: stockPrice,
          mrp: stockMrp,
          selectedStock: stock,
        );

        showScaffold(
          context: context,
          message: 'Added To Cart',
        );
      } else {
        debugPrint("No available stock found (all stocks have 0 quantity)");
        
        showScaffold(
          context: context,
          message: "No stock available for this product.",
        );
      }
    } else {
      debugPrint("Product has single or no stock entries, using auto-selection logic...");
      
      // Let the addToCart method handle auto-selection for single stock
      localProductProvider.addToCart(
        product: product,
      );

      showScaffold(
        context: context,
        message: 'Added To Cart',
      );
    }
    debugPrint("=== END HORIZONTAL PRODUCT VIEW DEBUG ===");
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
