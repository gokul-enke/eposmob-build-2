import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/helpers/product_cart_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:get/get.dart';

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
  final bool showSectionTitles;
  final int? visibleRows;
  final int crossAxisCount;

  const SideBarProductList({
    Key? key,
    this.onProductSelected,
    this.backgroundColor = Colors.white,
    this.categoryHeight = 100,
    this.dividerHeight = 1,
    this.dividerColor = const Color(0xFFF5F5F5),
    this.showSectionTitles = true,
    this.visibleRows,
    this.crossAxisCount = 3,
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

  // Add focus nodes for proper keyboard handling
  final FocusNode _categoryFocusNode = FocusNode();
  final FocusNode _productFocusNode = FocusNode();
  // Track selection for sidebar UI including the injected 'ALL' at index 0
  int _selectedUiCategoryIndex = 0;

  @override
  void initState() {
    super.initState();

    // Add focus listeners for debugging
    _categoryFocusNode.addListener(() {
      debugPrint("Category focus: ${_categoryFocusNode.hasFocus}");
    });

    _productFocusNode.addListener(() {
      debugPrint("Product focus: ${_productFocusNode.hasFocus}");
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure categories are loaded for the sidebar
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      debugPrint("📥 [SidebarProductList] Ensuring categories are loaded...");
      categoryProvider.ensureCategoriesLoaded();

      Provider.of<LocalProductProvider>(context, listen: false)
          .refreshProducts();
    });
  }

  @override
  void dispose() {
    _searchCategoryController.dispose();
    _searchProductController.dispose();
    _categoryScrollController.dispose();
    _categoryFocusNode.dispose();
    _productFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleProductSelection(GetProduct product) async {
    debugPrint("🎯 SIDEBAR PRODUCT SELECTION:");
    debugPrint("  - Product: ${product.productName}");
    debugPrint("  - Product ID: ${product.productId}");

    // Get customer info from global provider
    final customerSelectionProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    debugPrint(
        "  - Customer from provider: ${customerSelectionProvider.selectedCustomerName}");
    debugPrint(
        "  - Customer ID from provider: ${customerSelectionProvider.selectedCustomerID}");

    if (widget.onProductSelected != null) {
      debugPrint("  - Using custom callback (caller handles add-to-cart)");
      // Defer add-to-cart handling to the provided callback to avoid duplicate flows
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        Container(
          height: widget.dividerHeight,
          color: widget.dividerColor,
        ),

        // Category search field using reusable widget
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showSectionTitles) ...[
                Text(
                  'Categories',
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s18, 0.30, ColorManager.textColor),
                ),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  Expanded(
                    child: buildColumnWidgetForTextFields(
                      controller: _searchCategoryController,
                      size: MediaQuery.of(context).size,
                      hintText: 'common.search_category'.tr,
                      readOnly: false,
                      focusNode: _categoryFocusNode,
                      width: double.infinity, // Take full width
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8), // Minimal margin
                      onchanged: (query) {
                        final categoryProvider = Provider.of<CategoryProvider>(
                            context,
                            listen: false);
                        if (query!.isEmpty) {
                          // Reset to show all categories without API call
                          categoryProvider.resetCategoryFilter();
                        } else {
                          // Make API call for filtering
                          categoryProvider.listAllCategory(filterName: query);
                        }
                        setState(() {}); // Update to show/hide clear button
                      },
                    ),
                  ),
                  // Clear button for category search
                  if (_searchCategoryController.text.isNotEmpty)
                    BuildBoxShadowContainer(
                      circleRadius: 7,
                      padding: const EdgeInsets.all(5),
                      width: 50,
                      height: MediaQuery.of(context).size.height *
                          .07, // Same height as text field
                      child: IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCategoryController.clear();
                          // Don't call API, just reset the local category list
                          Provider.of<CategoryProvider>(context, listen: false)
                              .resetCategoryFilter();
                          setState(() {}); // Update to show/hide clear button
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Category horizontal list
        Container(
          height: widget.categoryHeight,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Consumer<CategoryProvider>(
            builder: (context, categoryProvider, child) {
              // Use the main category list loaded during login, fallback to searchCategory
              final rawCategories = categoryProvider.category ??
                  categoryProvider.searchCategory ??
                  [];

              debugPrint(
                  "🏷️ [Sidebar] Categories available: ${rawCategories.length}");
              debugPrint(
                  "🏷️ [Sidebar] categoryProvider.category: ${categoryProvider.category?.length}");
              debugPrint(
                  "🏷️ [Sidebar] categoryProvider.searchCategory: ${categoryProvider.searchCategory?.length}");

              // Inject a local 'ALL' entry only for this sidebar view
              final allCategory = Category(
                categoryId: 0,
                categoryName: 'ALL',
                categorySlug: 'ALL',
                productsCount: 0,
                categoryImage: null,
                categoryIcon: null,
                parent: null,
              );
              final categories = [allCategory, ...rawCategories];

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
                            // Use local UI selection to allow selecting 'ALL' visually
                            final isSelected =
                                index == _selectedUiCategoryIndex;

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                // Handle ALL locally without changing provider selected index
                                if (category.categoryId == 0) {
                                  Provider.of<LocalProductProvider>(context,
                                          listen: false)
                                      .refreshProducts();
                                  setState(() {
                                    _selectedUiCategoryIndex =
                                        index; // highlight ALL
                                  });
                                  return;
                                }

                                // Map UI index to provider index by offsetting -1
                                final providerIndex = index - 1;
                                categoryProvider.selectCategory(
                                  providerIndex,
                                  category.categoryName ?? '',
                                  category.productsCount ?? 0,
                                );

                                // Filter products by specific category
                                Provider.of<LocalProductProvider>(context,
                                        listen: false)
                                    .listAllProducts(
                                        categoryId: category.categoryId);

                                setState(() {
                                  _selectedUiCategoryIndex =
                                      index; // highlight selected
                                });
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
                                    Flexible(
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Outer circle highlight
                                          if (isSelected)
                                            Container(
                                              width: 64,
                                              height: 64,
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
                                            radius: 28,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(28),
                                              child: category.categoryImage !=
                                                      null
                                                  ? Image.network(
                                                      category.categoryImage!,
                                                      width: 56,
                                                      height: 56,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          Icon(Icons.category,
                                                              size: 24,
                                                              color: isSelected
                                                                  ? ColorManager
                                                                      .kPrimaryColor
                                                                  : Colors.grey
                                                                      .shade400),
                                                    )
                                                  : Icon(Icons.category,
                                                      size: 24,
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
                                    ),
                                    const SizedBox(height: 4),
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
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showSectionTitles) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Products',
                            style: buildCustomStyle(FontWeightManager.semiBold,
                                FontSize.s18, 0.30, ColorManager.textColor),
                          ),
                          // Add Product Button
                          GestureDetector(
                            onTap: () async {
                              final result = await showDialog(
                                context: context,
                                builder: (context) =>
                                    const AddProductWithBarcodeModal(
                                  isAddToCart: false,
                                ),
                              );

                              // If product was created successfully, refresh the product list
                              if (result != null) {
                                Provider.of<LocalProductProvider>(context,
                                        listen: false)
                                    .refreshProducts();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: ColorManager.kPrimaryColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Add Product',
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s12,
                                      0.30,
                                      Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: buildColumnWidgetForTextFields(
                            controller: _searchProductController,
                            size: MediaQuery.of(context).size,
                            hintText: 'common.search_product'.tr,
                            readOnly: false,
                            focusNode: _productFocusNode,
                            width: double.infinity, // Take full width
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8), // Minimal margin
                            onchanged: (query) {
                              Provider.of<LocalProductProvider>(context,
                                      listen: false)
                                  .listAllProducts(filterName: query);
                              setState(
                                  () {}); // Update to show/hide clear button
                            },
                          ),
                        ),
                        // Clear button for product search
                        if (_searchProductController.text.isNotEmpty)
                          BuildBoxShadowContainer(
                            circleRadius: 7,
                            padding: const EdgeInsets.all(5),
                            width: 50,
                            height: MediaQuery.of(context).size.height *
                                .07, // Same height as text field
                            child: IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchProductController.clear();
                                Provider.of<LocalProductProvider>(context,
                                        listen: false)
                                    .refreshProducts();
                                setState(() {});
                              },
                            ),
                          ),
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
              // Use sellableFilteredProducts to only show products that are marked as sellable
              final products = productProvider.sellableFilteredProducts;

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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const gridPadding = EdgeInsets.only(
                              top: 16,
                              left: 16,
                              right: 16,
                              bottom: 16,
                            );
                            final columns = widget.crossAxisCount > 0
                                ? widget.crossAxisCount
                                : 1;
                            const crossAxisSpacing = 8.0;
                            const mainAxisSpacing = 8.0;
                            double childAspectRatio = 0.8;

                            if (widget.visibleRows != null &&
                                widget.visibleRows! > 0) {
                              final availableWidth = constraints.maxWidth -
                                  (gridPadding.left + gridPadding.right);
                              final availableHeight = constraints.maxHeight -
                                  (gridPadding.top + gridPadding.bottom);
                              final spacingWidth =
                                  (columns - 1) * crossAxisSpacing;
                              final spacingHeight =
                                  (widget.visibleRows! - 1) * mainAxisSpacing;
                              final effectiveWidth =
                                  availableWidth - spacingWidth;
                              final effectiveHeight =
                                  availableHeight - spacingHeight;

                              if (effectiveWidth > 0 && effectiveHeight > 0) {
                                final itemWidth = effectiveWidth / columns;
                                final itemHeight =
                                    effectiveHeight / widget.visibleRows!;
                                final ratio = itemWidth / itemHeight;
                                if (ratio.isFinite && ratio > 0) {
                                  childAspectRatio = ratio;
                                }
                              }
                            }

                            return GridView.count(
                              padding: gridPadding,
                              crossAxisCount: columns,
                              childAspectRatio: childAspectRatio,
                              crossAxisSpacing: crossAxisSpacing,
                              mainAxisSpacing: mainAxisSpacing,
                              physics: const BouncingScrollPhysics(),
                              children: List.generate(products.length, (index) {
                                final product = products[index];
                                final isSelected =
                                    product == productProvider.selectedProduct;

                                String? primaryImage;
                                if (product.attachment != null &&
                                    product.attachment!.isNotEmpty) {
                                  for (final attachment
                                      in product.attachment!) {
                                    if (attachment.isPrimary == 1) {
                                      primaryImage = attachment.filePath;
                                      break;
                                    }
                                  }
                                  primaryImage ??=
                                      product.attachment!.first.filePath;
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
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: ColorManager
                                                        .kPrimaryColor
                                                        .withOpacity(0.8),
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(4),
                                                    ),
                                                  ),
                                                  child: Consumer<
                                                      AppSettingsProvider>(
                                                    builder: (context,
                                                        appSettingsProvider,
                                                        _) {
                                                      final currency =
                                                          appSettingsProvider
                                                                  .appSettings
                                                                  ?.currency ??
                                                              'INR';
                                                      final raw = product.price
                                                          ?.price; // can be String or num
                                                      String amount;
                                                      if (raw is num) {
                                                        amount = raw
                                                            .toStringAsFixed(2);
                                                      } else if (raw
                                                          is String) {
                                                        final parsed =
                                                            double.tryParse(
                                                                raw);
                                                        amount = parsed != null
                                                            ? parsed
                                                                .toStringAsFixed(
                                                                    2)
                                                            : raw;
                                                      } else {
                                                        amount = '0.00';
                                                      }
                                                      return Text(
                                                        '$currency $amount',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 8,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
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
                            );
                          },
                        ),
                      ),
                    );
            },
          ),
        ),
      ],
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
