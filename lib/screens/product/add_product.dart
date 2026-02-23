import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/widgets/add_product_modal.dart';
import 'package:pos_machine/widgets/product_details_dialog.dart';
import 'package:provider/provider.dart';
import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../models/get_product.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  // Controllers
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController createdByController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController hsnCodeController = TextEditingController();
  final TextEditingController categorySearchController =
      TextEditingController();
  final TextEditingController propertySearchController =
      TextEditingController();
  final TextEditingController storeSearchController = TextEditingController();
  final TextEditingController supplierSearchController =
      TextEditingController();
  GetStoreModelData? storeSelected;
  GetSuppliersModelData? supplier;
  final TextEditingController supplierIdController = TextEditingController();
  GetProduct? selectedProduct;

  // Variables for selected filters
  String? selectedCategoryId;
  String? selectedProperties;
  String? selectedSupplierId;
  int page = 1;
  bool initLoading = false;

  String? selectedProperty;
  final List<String> propertyList = [
    'MANUFACTURER',
    'COLOR',
    'SHIRT_SIZE',
    'SHOE_SIZE',
  ];

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      loadInitData();
    });
    super.initState();
  }

  void loadInitData() async {
    try {
      setState(() {
        initLoading = true;
      });

      // Load categories from CategoryProvider with caching (same as sidebar and stock)
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      if (!categoryProvider.isCategoriesLoaded) {
        debugPrint("📥 Loading categories from API...");
        await categoryProvider.listAllCategory();
        debugPrint("✅ Categories loaded and cached");
      } else {
        debugPrint(
            "📋 Using cached categories (${categoryProvider.category?.length ?? 0} items)");
      }

      LocalProductProvider localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      localProductProvider.listAllProducts(
        categoryId:
            selectedCategoryId != null ? int.parse(selectedCategoryId!) : null,
        filterName: productNameController.text,
        filterPrice: amountController.text,
        filterBarcode: barcodeController.text,
        filterHsnCode: hsnCodeController.text,
        filterCreatedBy: createdByController.text,
        filterProperties: selectedProperty,
        filterStore: storeController.text,
        filterSupplier: supplierIdController.text,
        page: page,
      );
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void searchProducts(page) async {
    try {
      setState(() {
        initLoading = true;
      });

      LocalProductProvider localProductProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      localProductProvider.listAllProducts(
        categoryId:
            selectedCategoryId != null ? int.parse(selectedCategoryId!) : null,
        filterName: productNameController.text,
        filterPrice: amountController.text,
        filterBarcode: barcodeController.text,
        filterHsnCode: hsnCodeController.text,
        filterCreatedBy: createdByController.text,
        filterProperties: selectedProperty,
        filterStore: storeController.text,
        filterSupplier: supplierIdController.text.isNotEmpty
            ? supplierIdController.text
            : null,
        page: page,
      );
    } catch (error) {
      // debugPrint(error.toString());
    } finally {
      setState(() {
        initLoading = false;
      });
    }
  }

  void resetSearch() {
    setState(() {
      productNameController.clear();
      storeController.clear();
      amountController.clear();
      barcodeController.clear();
      hsnCodeController.clear();
      createdByController.clear();
      supplierIdController.clear();

      // Reset dropdown selections
      selectedCategoryId = null;
      selectedProperties = null;
      selectedSupplierId = null;
      selectedProperty = null;
      storeSelected = null;
      supplier = null;

      page = 1;
    });
    loadInitData();
  }

  void _showProductDetails(GetProduct product) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProductDetailsDialog(
        product: product,
      ),
    );
  }

  Future<void> refreshData() async {
    resetSearch();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshData,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: ColorManager.boxShadowColor,
                  blurRadius: 6,
                  offset: Offset(1, 1),
                ),
              ],
              color: Colors.white),
          child: Column(
            children: [
              // Fixed Header Section
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Product List",
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s20,
                            0.30,
                            ColorManager.textColor,
                          ),
                        ),
                        CustomRoundButton(
                          title: "Add Product",
                          fct: () async {
                            await showDialog(
                              context: context,
                              builder: (context) =>
                                  const AddProductWithBarcodeModal(),
                            );
                          },
                          fontSize: 12,
                          height: 45,
                          width: 150,
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // First row of filters - Name, Category, Price, Barcode
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Name filter
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text(
                              //   "Name",
                              //   style: buildCustomStyle(
                              //     FontWeightManager.regular,
                              //     FontSize.s14,
                              //     0.27,
                              //     Colors.black.withOpacity(0.6),
                              //   ),
                              // ),
                              const SizedBox(height: 8),
                              buildColumnWidgetForTextFields(
                                height: 45,
                                onchanged: (value) {
                                  searchProducts(1);
                                },
                                controller: productNameController,
                                size: size,
                                hintText: 'Product Name',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),

                        // Category filter
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text(
                              //   "Category",
                              //   style: buildCustomStyle(
                              //     FontWeightManager.regular,
                              //     FontSize.s14,
                              //     0.27,
                              //     Colors.black.withOpacity(0.6),
                              //   ),
                              // ),
                              // const SizedBox(height: 8),
                              Consumer<CategoryProvider>(
                                builder: (context, categoryProvider, child) {
                                  List<Category>? categoryList =
                                      categoryProvider.category;
                                  Category? selectedCategory;
                                  if (selectedCategoryId != null &&
                                      categoryList != null) {
                                    try {
                                      selectedCategory =
                                          categoryList.firstWhere(
                                        (cat) =>
                                            cat.categoryId.toString() ==
                                            selectedCategoryId,
                                        orElse: () => categoryList.first,
                                      );
                                    } catch (e) {
                                      selectedCategory = null;
                                    }
                                  }

                                  return BuildDropDownWithSearch<Category>(
                                    title: null,
                                    showName: false,
                                    hintText: 'Please Select',
                                    value: selectedCategory,
                                    items: categoryList != null &&
                                            categoryList.isNotEmpty
                                        ? categoryList
                                            .where((category) =>
                                                category.categoryName != "ALL")
                                            .toList()
                                        : [],
                                    onChanged: (Category? selected) async {
                                      if (selected != null) {
                                        setState(() {
                                          selectedCategoryId =
                                              selected.categoryId.toString();
                                        });
                                        searchProducts(1);
                                      }
                                    },
                                    displayText: (category) =>
                                        category.categoryName ?? 'Unknown',
                                    searchController: categorySearchController,
                                    height: 45,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 0, vertical: 0),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),

                        // Price filter
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text(
                              //   "Price",
                              //   style: buildCustomStyle(
                              //     FontWeightManager.regular,
                              //     FontSize.s14,
                              //     0.27,
                              //     Colors.black.withOpacity(0.6),
                              //   ),
                              // ),
                              // const SizedBox(height: 8),
                              buildColumnWidgetForTextFields(
                                height: 45,
                                onchanged: (value) {
                                  searchProducts(1);
                                },
                                controller: amountController,
                                size: size,
                                hintText: 'Price',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),

                        // Barcode filter
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text(
                              //   "Barcode",
                              //   style: buildCustomStyle(
                              //     FontWeightManager.regular,
                              //     FontSize.s14,
                              //     0.27,
                              //     Colors.black.withOpacity(0.6),
                              //   ),
                              // ),
                              // const SizedBox(height: 8),
                              buildColumnWidgetForTextFields(
                                height: 45,
                                onchanged: (value) {
                                  searchProducts(1);
                                },
                                margin: const EdgeInsets.only(left: 5),
                                controller: barcodeController,
                                size: size,
                                hintText: 'Barcode',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Second row of filters - HSN Code, Properties, Store, Supplier, Reset Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HSN Code filter
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text(
                              //   "HSN Code",
                              //   style: buildCustomStyle(
                              //     FontWeightManager.regular,
                              //     FontSize.s14,
                              //     0.27,
                              //     Colors.black.withOpacity(0.6),
                              //   ),
                              // ),
                              // const SizedBox(height: 8),
                              buildColumnWidgetForTextFields(
                                height: 45,
                                onchanged: (value) {
                                  searchProducts(1);
                                },
                                controller: hsnCodeController,
                                size: size,
                                hintText: 'HSN Code',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),

                        // Product Properties
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text(
                              //   "Product Properties",
                              //   style: buildCustomStyle(
                              //     FontWeightManager.regular,
                              //     FontSize.s14,
                              //     0.27,
                              //     Colors.black.withOpacity(0.6),
                              //   ),
                              // ),
                              // const SizedBox(height: 8),
                              BuildDropDownWithSearch<String>(
                                title: null,
                                showName: false,
                                hintText: 'Select Property',
                                value: selectedProperty,
                                items: propertyList,
                                onChanged: (String? newValue) {
                                  setState(() {
                                    selectedProperty = newValue;
                                  });
                                  searchProducts(1);
                                },
                                displayText: (property) => property,
                                searchController: propertySearchController,
                                height: 45,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 0, vertical: 0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),

                        // Store
                        /*
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text(
                              //   "Store",
                              //   style: buildCustomStyle(
                              //     FontWeightManager.regular,
                              //     FontSize.s14,
                              //     0.27,
                              //     Colors.black.withOpacity(0.6),
                              //   ),
                              // ),
                              // const SizedBox(height: 8),
                              Consumer<PurchaseProvider>(
                                builder: (context, purchaseProvider, child) {
                                  List<GetStoreModelData> stores =
                                      purchaseProvider.getStoreList ?? [];
                                  return BuildDropDownWithSearch<
                                      GetStoreModelData>(
                                    title: null,
                                    showName: false,
                                    hintText: 'Select Store',
                                    value: storeSelected,
                                    items: stores,
                                    onChanged:
                                        (GetStoreModelData? storeModelData) {
                                      if (storeModelData != null) {
                                        setState(() {
                                          storeSelected = storeModelData;
                                          storeController.text =
                                              "${storeModelData.id ?? 1}";
                                        });
                                        searchProducts(1);
                                      }
                                    },
                                    displayText: (store) =>
                                        store.name ?? 'Unknown Store',
                                    searchController: storeSearchController,
                                    height: 45,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 0, vertical: 0),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        */
                        const Expanded(flex: 1, child: SizedBox()),
                        const SizedBox(width: 15),

                        // Supplier
                        /*
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text(
                              //   "Supplier",
                              //   style: buildCustomStyle(
                              //     FontWeightManager.regular,
                              //     FontSize.s14,
                              //     0.27,
                              //     Colors.black.withOpacity(0.6),
                              //   ),
                              // ),
                              // const SizedBox(height: 8),
                              Consumer<PurchaseProvider>(
                                builder: (context, purchaseProvider, child) {
                                  List<GetSuppliersModelData> suppliers =
                                      purchaseProvider.getSupplierList ?? [];
                                  return BuildDropDownWithSearch<
                                      GetSuppliersModelData>(
                                    title: null,
                                    showName: false,
                                    hintText: 'Select Supplier',
                                    value: supplier,
                                    items: suppliers,
                                    onChanged: (GetSuppliersModelData?
                                        suppliersModelData) {
                                      if (suppliersModelData != null) {
                                        setState(() {
                                          supplier = suppliersModelData;
                                          supplierIdController.text =
                                              "${suppliersModelData.id ?? 1}";
                                        });
                                        searchProducts(1);
                                      }
                                    },
                                    displayText: (supplier) =>
                                        supplier.displayName,
                                    searchController: supplierSearchController,
                                    height: 45,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 0, vertical: 0),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        */
                        const Expanded(flex: 1, child: SizedBox()),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Third row - Reset button
                    Row(
                      children: [
                        Expanded(flex: 2, child: Container()),
                        const SizedBox(width: 15),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 0),
                            child: CustomRoundButton(
                              title: "Reset",
                              boxColor: Colors.white,
                              textColor: ColorManager.kPrimaryColor,
                              fct: resetSearch,
                              height: 45,
                              width: 100,
                              fontSize: FontSize.s12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Expanded area for table and pagination
              Expanded(
                child: Column(
                  children: [
                    // Table Area - Takes remaining space with scrolling table body
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Consumer<LocalProductProvider>(
                          builder: (context, productProvider, child) {
                            List<GetProduct> productList =
                                productProvider.paginatedProducts;

                            if (initLoading) {
                              return const Center(
                                  child: CircularProgressIndicator.adaptive());
                            }

                            if (productList.isEmpty) {
                              return BuildBoxShadowContainer(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 20),
                                circleRadius: 7,
                                offsetValue: const Offset(1, 1),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 50.0),
                                  child: Center(
                                    child: Text(
                                      "No products found",
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s16,
                                        0.18,
                                        Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return BuildBoxShadowContainer(
                              margin: const EdgeInsets.symmetric(horizontal: 0),
                              width: double.infinity,
                              circleRadius: 7,
                              offsetValue: const Offset(2, 2),
                              blurRadius: 8.0,
                              color: Colors.white,
                              child: Column(
                                children: [
                                  // Fixed table header
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: ColorManager.tableBGColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          offset: Offset(0, 2),
                                          blurRadius: 2.0,
                                        ),
                                      ],
                                    ),
                                    child: Table(
                                      columnWidths: const {
                                        0: FractionColumnWidth(0.05), // No
                                        1: FractionColumnWidth(
                                            0.26), // Product Name
                                        2: FractionColumnWidth(
                                            0.12), // Category Name
                                        3: FractionColumnWidth(0.08), // Price
                                        4: FractionColumnWidth(0.08), // MRP
                                        5: FractionColumnWidth(
                                            0.08), // Purchase Price
                                        6: FractionColumnWidth(0.08), // Unit
                                        7: FractionColumnWidth(0.13), // Barcode
                                        8: FractionColumnWidth(0.12), // Action
                                      },
                                      border: null,
                                      defaultVerticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      children: [
                                        TableRow(
                                          children: [
                                            _buildTableHeader("No"),
                                            _buildTableHeader("Product Name"),
                                            _buildTableHeader("Category Name"),
                                            _buildTableHeader("Price"),
                                            _buildTableHeader("MRP"),
                                            _buildTableHeader("Purchase Price"),
                                            _buildTableHeader("Unit"),
                                            _buildTableHeader("Barcode"),
                                            _buildTableHeader("Action"),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Scrollable table body
                                  Expanded(
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.grab,
                                      child: ScrollConfiguration(
                                        behavior:
                                            ScrollConfiguration.of(context)
                                                .copyWith(
                                          dragDevices: {
                                            PointerDeviceKind.mouse,
                                            PointerDeviceKind.touch,
                                            PointerDeviceKind.stylus,
                                            PointerDeviceKind.trackpad,
                                          },
                                        ),
                                        child: SingleChildScrollView(
                                          physics:
                                              const BouncingScrollPhysics(),
                                          scrollDirection: Axis.vertical,
                                          child: Table(
                                            columnWidths: const {
                                              0: FractionColumnWidth(
                                                  0.05), // No
                                              1: FractionColumnWidth(
                                                  0.26), // Product Name
                                              2: FractionColumnWidth(
                                                  0.12), // Category Name
                                              3: FractionColumnWidth(
                                                  0.08), // Price
                                              4: FractionColumnWidth(
                                                  0.08), // MRP
                                              5: FractionColumnWidth(
                                                  0.08), // Purchase Price
                                              6: FractionColumnWidth(
                                                  0.08), // Unit
                                              7: FractionColumnWidth(
                                                  0.13), // Barcode
                                              8: FractionColumnWidth(
                                                  0.12), // Action
                                            },
                                            border: null,
                                            defaultVerticalAlignment:
                                                TableCellVerticalAlignment
                                                    .middle,
                                            children: [
                                              ...productList
                                                  .asMap()
                                                  .entries
                                                  .map((entry) {
                                                int index = entry.key;
                                                var product = entry.value;
                                                String categoryName =
                                                    product.category != null
                                                        ? product.category!
                                                                .name ??
                                                            'Unknown'
                                                        : 'No Category';

                                                return TableRow(
                                                  decoration: BoxDecoration(
                                                    color: index % 2 == 0
                                                        ? Colors.white
                                                        : Colors.grey
                                                            .withOpacity(0.1),
                                                  ),
                                                  children: [
                                                    _buildTableCell(
                                                        "${index + 1}"),
                                                    _buildTableCell(
                                                        "${product.productName}"),
                                                    _buildTableCell(
                                                        categoryName),
                                                    _buildTableCell(
                                                        "${product.price?.price ?? 'N/A'}"),
                                                    _buildTableCell(
                                                        "${product.mrp ?? 'N/A'}"),
                                                    _buildTableCell(() {
                                                      // Debug purchase price resolution
                                                      final productPurchasePrice =
                                                          product.purchasePrice;
                                                      final stockPurchasePrice =
                                                          product.stock !=
                                                                      null &&
                                                                  product.stock!
                                                                      .isNotEmpty
                                                              ? product
                                                                  .stock!
                                                                  .first
                                                                  .purchasePrice
                                                              : null;
                                                      final finalPrice =
                                                          productPurchasePrice ??
                                                              stockPurchasePrice ??
                                                              'N/A';

                                                      debugPrint(
                                                          "🔍 PURCHASE PRICE DEBUG for ${product.productName}:");
                                                      debugPrint(
                                                          "  - Product Purchase Price: $productPurchasePrice");
                                                      debugPrint(
                                                          "  - Stock Purchase Price: $stockPurchasePrice");
                                                      debugPrint(
                                                          "  - Final Display Price: $finalPrice");
                                                      debugPrint(
                                                          "  - Stock Count: ${product.stock?.length ?? 0}");

                                                      return finalPrice
                                                          .toString();
                                                    }()),
                                                    _buildTableCell(
                                                        product.unit ?? 'N/A'),
                                                    _buildTableCell(
                                                        product.barcode ??
                                                            'N/A'),
                                                    Center(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child:
                                                            BuildBoxShadowContainer(
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 5,
                                                                  right: 5),
                                                          circleRadius: 5,
                                                          child: IconButton(
                                                            icon: Icon(
                                                              Icons.visibility,
                                                              size: 18,
                                                              color: ColorManager
                                                                  .kPrimaryColor
                                                                  .withOpacity(
                                                                      0.9),
                                                            ),
                                                            onPressed: () {
                                                              _showProductDetails(
                                                                  product);
                                                            },
                                                            constraints:
                                                                const BoxConstraints(
                                                              minWidth: 36,
                                                              minHeight: 36,
                                                            ),
                                                            padding:
                                                                EdgeInsets.zero,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }).toList(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Pagination Always at Bottom
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10),
                      child: Consumer<LocalProductProvider>(
                        builder: (context, productProvider, child) {
                          if (productProvider.paginatedProducts.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return PaginationControl(
                            currentPage: productProvider.currentPage,
                            totalPages: productProvider.totalPages,
                            onPageChanged: (int page) {
                              searchProducts(page);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Center(
          child: Text(
            text,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.18,
              ColorManager.kPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Text(
            text,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.13,
              Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
