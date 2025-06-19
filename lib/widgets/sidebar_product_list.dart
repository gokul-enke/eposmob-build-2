import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class SideBarProductList extends StatefulWidget {
  /// Function to call when a product is selected
  final Function(dynamic)? onProductSelected;

  /// Optional background color
  final Color backgroundColor;

  /// Optional category item height
  final double categoryHeight;

  /// Optional divider height and color
  final double dividerHeight;
  final Color dividerColor;

  const SideBarProductList({
    Key? key,
    this.onProductSelected,
    this.backgroundColor = Colors.white,
    this.categoryHeight = 100,
    this.dividerHeight = 1,
    this.dividerColor = const Color(0xFFF5F5F5),
  }) : super(key: key);

  @override
  State<SideBarProductList> createState() => _SideBarProductListState();
}

class _SideBarProductListState extends State<SideBarProductList> {
  final TextEditingController _searchCategoryController =
      TextEditingController();
  final TextEditingController _searchProductController =
      TextEditingController();
  final ScrollController _categoryScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryProvider>(context, listen: false).listAllCategory();
      Provider.of<LocalProductProvider>(context, listen: false)
          .refreshProducts();
    });
  }

  @override
  void dispose() {
    _searchCategoryController.dispose();
    _searchProductController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  Future<void> _handleProductSelection(GetProduct product) async {
    debugPrint("🎯 SIDEBAR PRODUCT SELECTION:");
    debugPrint("  - Product: ${product.productName}");
    debugPrint("  - Product ID: ${product.productId}");
    
    // Get customer info from global provider
    final customerSelectionProvider = Provider.of<CustomerSelectionProvider>(context, listen: false);
    debugPrint("  - Customer from provider: ${customerSelectionProvider.selectedCustomerName}");
    debugPrint("  - Customer ID from provider: ${customerSelectionProvider.selectedCustomerID}");

    if (widget.onProductSelected != null) {
      debugPrint("  - Using custom callback");
      // If there's a custom callback, use the helper but handle the callback manually
      await ProductCartHelper.handleProductSelection(
        context: context,
        product: product,
        addToCartDirectly: false, // Don't add to cart, let callback handle it
        // Customer info will be fetched from global provider in the helper
      );
      // Call the custom callback
      widget.onProductSelected!(product);
    } else {
      debugPrint("  - Using default behavior - adding to cart directly");
      // Default behavior - add to cart directly
      await ProductCartHelper.handleProductSelection(
        context: context,
        product: product,
        addToCartDirectly: true, // Add to cart directly for sidebar view
        // Customer info will be fetched from global provider in the helper
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? customerId =
        Provider.of<AuthModel>(context, listen: false).userId;

    return BuildBoxShadowContainer(
      circleRadius: 10,
      margin: const EdgeInsets.only(top: 10, bottom: 10, right: 10),
      color: widget.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category search section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Search Category',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s18,
                  0.30, ColorManager.textColor),
            ),
          ),

          // Category search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCategoryController,
              cursorColor: ColorManager.kPrimaryColor,
              decoration: InputDecoration(
                hintText: 'Search category',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                prefixIcon:
                    const Icon(Icons.search, color: ColorManager.kPrimaryColor),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: ColorManager.kPrimaryColor),
                ),
              ),
              onChanged: (query) {
                Provider.of<CategoryProvider>(context, listen: false)
                    .listAllCategory(filterName: query);
              },
            ),
          ),

          // Category horizontal list
          Container(
            height: widget.categoryHeight,
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                final categories = categoryProvider.category ?? [];

                return categories.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : MouseRegion(
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
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            controller: _categoryScrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final isSelected = index ==
                                  categoryProvider.selectedCategoryIndex;

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  categoryProvider.selectCategory(
                                    index,
                                    category.categoryName ?? '',
                                    category.productsCount ?? 0,
                                  );

                                  // Filter products by selected category
                                  if (category.categoryId == 0) {
                                    // "ALL" category selected
                                    Provider.of<LocalProductProvider>(context,
                                            listen: false)
                                        .refreshProducts();
                                  } else {
                                    // Specific category selected
                                    Provider.of<LocalProductProvider>(context,
                                            listen: false)
                                        .listAllProducts(
                                            categoryId: category.categoryId);
                                  }

                                  // Force rebuild to ensure UI updates
                                  setState(() {});
                                },
                                child: Container(
                                  width: 85,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Category image with highlight effect
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Outer circle highlight
                                          if (isSelected)
                                            Container(
                                              width: 76,
                                              height: 76,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: [
                                                    ColorManager.kPrimaryColor
                                                        .withOpacity(0.7),
                                                    ColorManager.kPrimaryColor
                                                        .withOpacity(0.3),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                            ),

                                          // Main circle avatar
                                          CircleAvatar(
                                            backgroundColor: isSelected
                                                ? Colors.white
                                                : Colors.grey.shade200,
                                            radius: 34,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(33),
                                              child: category.categoryImage !=
                                                      null
                                                  ? Image.network(
                                                      category.categoryImage!,
                                                      width: 64,
                                                      height: 64,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          Icon(Icons.category,
                                                              size: 30,
                                                              color: isSelected
                                                                  ? ColorManager
                                                                      .kPrimaryColor
                                                                  : Colors.grey
                                                                      .shade400),
                                                    )
                                                  : Icon(Icons.category,
                                                      size: 30,
                                                      color: isSelected
                                                          ? ColorManager
                                                              .kPrimaryColor
                                                          : Colors
                                                              .grey.shade400),
                                            ),
                                          ),

                                          // Selection indicator dot
                                          if (isSelected)
                                            Positioned(
                                              bottom: 0,
                                              child: Container(
                                                width: 12,
                                                height: 3,
                                                decoration: BoxDecoration(
                                                  color: ColorManager
                                                      .kPrimaryColor,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Category name
                                      Text(
                                        category.categoryName ?? 'Unknown',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? ColorManager.kPrimaryColor
                                              : Colors.grey.shade800,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
              },
            ),
          ),

          // Divider
          Container(
            height: widget.dividerHeight,
            color: widget.dividerColor,
          ),

          // Product search section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Products',
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s18, 0.30, ColorManager.textColor),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchProductController,
                              cursorColor: ColorManager.kPrimaryColor,
                              decoration: InputDecoration(
                                hintText: 'Search product',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                ),
                                prefixIcon: const Icon(Icons.search,
                                    color: ColorManager.kPrimaryColor),
                                suffixIcon: _searchProductController
                                        .text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchProductController.clear();
                                          Provider.of<LocalProductProvider>(
                                                  context,
                                                  listen: false)
                                              .refreshProducts();
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: ColorManager.kPrimaryColor),
                                ),
                              ),
                              onChanged: (query) {
                                Provider.of<LocalProductProvider>(context,
                                        listen: false)
                                    .listAllProducts(filterName: query);
                                setState(
                                    () {}); // Update to show/hide clear button
                              },
                            ),
                          ),
                          // const SizedBox(width: 8),
                          // Container(
                          //   height: 48,
                          //   width: 48,
                          //   decoration: BoxDecoration(
                          //     color: Colors.grey.shade50,
                          //     borderRadius: BorderRadius.circular(10),
                          //     border: Border.all(color: Colors.grey.shade200),
                          //   ),
                          //   child: IconButton(
                          //     icon: const Icon(Icons.filter_list,
                          //         color: ColorManager.kPrimaryColor),
                          //     onPressed: () {
                          //       // Show filter options
                          //       // You can implement this later
                          //     },
                          //   ),
                          // ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Products grid
          Expanded(
            child: Consumer<LocalProductProvider>(
              builder: (context, productProvider, child) {
                final products = productProvider.filteredProducts;

                return products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              "No products available",
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : MouseRegion(
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
                          child: GridView.count(
                            padding: const EdgeInsets.only(
                                top: 16, left: 16, right: 16, bottom: 16),
                            crossAxisCount: 3,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            physics: const BouncingScrollPhysics(),
                            children: List.generate(products.length, (index) {
                              final product = products[index];
                              final isSelected =
                                  product == productProvider.selectedProduct;

                              // Find primary image
                              String? primaryImage;
                              if (product.attachment != null &&
                                  product.attachment!.isNotEmpty) {
                                for (var attachment in product.attachment!) {
                                  if (attachment.isPrimary == 1) {
                                    primaryImage = attachment.filePath;
                                    break;
                                  }
                                }
                                // If no primary image found, use the first one
                                if (primaryImage == null &&
                                    product.attachment!.isNotEmpty) {
                                  primaryImage =
                                      product.attachment!.first.filePath;
                                }
                              }

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _handleProductSelection(product),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(
                                            color: ColorManager.kPrimaryColor,
                                            width: 1)
                                        : Border.all(
                                            color: Colors.grey.shade100),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Product image
                                      Expanded(
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(8),
                                                topRight: Radius.circular(8),
                                              ),
                                              child: Container(
                                                color: Colors.grey.shade50,
                                                child: primaryImage != null
                                                    ? Image.network(
                                                        primaryImage,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context,
                                                                error,
                                                                stackTrace) =>
                                                            const Icon(
                                                                Icons
                                                                    .image_not_supported,
                                                                size: 24,
                                                                color: Colors
                                                                    .grey),
                                                      )
                                                    : const Icon(
                                                        Icons
                                                            .inventory_2_outlined,
                                                        size: 24,
                                                        color: Colors.grey),
                                              ),
                                            ),
                                            // Price indicator
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: ColorManager
                                                      .kPrimaryColor
                                                      .withOpacity(0.8),
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                    topLeft: Radius.circular(4),
                                                  ),
                                                ),
                                                child: Text(
                                                  '${product.price?.price ?? '0.00'} ${product.currency ?? ''}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Selection indicator
                                            if (isSelected)
                                              Positioned(
                                                top: 0,
                                                left: 0,
                                                child: Container(
                                                  height: 16,
                                                  width: 16,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: ColorManager
                                                        .kPrimaryColor,
                                                    borderRadius:
                                                        BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(8),
                                                      bottomRight:
                                                          Radius.circular(8),
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 10,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Product name/unit
                                      Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Text(
                                          "${product.productName} / ${product.unit}",
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      );
              },
            ),
          ),
        ],
      ),
    );
  }



// Helper widget for image display in carousel
  Widget buildCarouselImage(String? urlImage) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade100,
      child: urlImage != null
          ? Image.network(
              urlImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image,
                size: 60,
                color: Colors.grey,
              ),
            )
          : const Icon(
              Icons.image_not_supported,
              size: 60,
              color: Colors.grey,
            ),
    );
  }
}
