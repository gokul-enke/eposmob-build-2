import 'dart:ui';

import 'package:get/get.dart';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'package:pos_machine/screens/print/barcode_printer_service.dart';
import 'widgets/confirm_barcode_print_modal.dart';

class ProductBarcodeScreen extends StatefulWidget {
  const ProductBarcodeScreen({super.key});

  @override
  State<ProductBarcodeScreen> createState() => _ProductBarcodeScreenState();
}

class _ProductBarcodeScreenState extends State<ProductBarcodeScreen> {
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController categorySearchController =
      TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  GetProduct? selectedProduct;
  bool initLoading = false;
  bool isInitialized = false;
  List<String> categories = ["All Categories"];

  // Track selected products by stable key so selection survives pagination.
  final Set<String> _selectedProductKeys = {};
  final Map<String, GetProduct> _selectedProductsByKey = {};

  @override
  void initState() {
    super.initState();
    loadInitData();
    categoryController.text = "All Categories";
  }

  // ── ALL ORIGINAL LOGIC BELOW — UNTOUCHED ──

  void loadInitData() async {
    debugPrint('🎬 LOADING STOCK SCREEN INIT DATA');
    try {
      setState(() {
        initLoading = true;
      });

      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication token is missing")),
        );
        return;
      }

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

      Provider.of<LocalProductProvider>(context, listen: false)
          .listAllProducts(categoryId: 0);

      _extractCategories();

      setState(() {
        isInitialized = true;
        initLoading = false;
      });
    } catch (error) {
      debugPrint("Error loading products: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading products: $error")),
      );
      setState(() {
        initLoading = false;
      });
    }
  }

  void _extractCategories() {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    final categoryList = categoryProvider.category ?? [];
    final uniqueCategories = categoryList
        .map((category) => category.categoryName ?? "")
        .where((categoryName) => categoryName.isNotEmpty)
        .toList();
    uniqueCategories.sort();

    setState(() {
      categories = ["All Categories", ...uniqueCategories];
    });

    debugPrint("📋 CATEGORIES LOADED: ${categories.length} categories found");
    debugPrint("📋 Categories: $categories");
  }

  void searchProducts(int pageNo) {
    LocalProductProvider provider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    int? catId;
    if (categoryController.text != "All Categories") {
      catId = categoryProvider.category
          ?.firstWhereOrNull((c) => c.categoryName == categoryController.text)
          ?.categoryId;
    }

    provider.listAllProducts(
      filterName: productNameController.text.isEmpty
          ? null
          : productNameController.text,
      categoryId: catId,
      filterBarcode:
          barcodeController.text.isEmpty ? null : barcodeController.text,
      page: pageNo,
    );
  }

  void resetSearch() {
    setState(() {
      productNameController.clear();
      categoryController.text = "All Categories";
      barcodeController.clear();
      _selectedProductKeys.clear();
      _selectedProductsByKey.clear();
    });
    Provider.of<LocalProductProvider>(context, listen: false)
        .listAllProducts(categoryId: 0);
  }

  String _productSelectionKey(GetProduct product) {
    if (product.productId != null) {
      return 'id:${product.productId}';
    }
    return 'fallback:${product.barcode ?? ''}|${product.productName ?? ''}';
  }

  bool _isProductSelected(GetProduct product) {
    return _selectedProductKeys.contains(_productSelectionKey(product));
  }

  void _setProductSelected(GetProduct product, bool selected) {
    final key = _productSelectionKey(product);
    if (selected) {
      _selectedProductKeys.add(key);
      _selectedProductsByKey[key] = product;
    } else {
      _selectedProductKeys.remove(key);
      _selectedProductsByKey.remove(key);
    }
  }

  void _showProductDetails(GetProduct product) {
    setState(() {
      selectedProduct = product;
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width / 2,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stock Details',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildDetailRow('Product Name', product.productName ?? 'N/A'),
                    _buildDetailRow(
                        'Category', product.category?.name ?? 'N/A'),
                    _buildDetailRow('Store Name', 'N/A'), // Product API doesn't return generic store info easily here
                    _buildDetailRow('Supplier', 'N/A'),
                    _buildDetailRow('Unit', product.unit ?? 'N/A'),
                    _buildDetailRow('Retail Price',
                        product.price?.price?.toString() ?? 'N/A'),
                    _buildDetailRow('MRP', product.mrp?.toString() ?? 'N/A'),
                    _buildDetailRow('Purchase Price',
                        product.purchasePrice?.toString() ?? 'N/A'),
                    _buildDetailRow('Quantity',
                        product.numberOfProductsAvailable?.toString() ?? 'N/A'),
                    _buildDetailRow('Rack', 'N/A'),
                    _buildDetailRow('Barcode', product.barcode ?? 'N/A'),
                    _buildDetailRow('Wholesale Price', 'N/A'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomRoundButton(
                    title: "Close",
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: () => Navigator.pop(context),
                    height: 45,
                    width: 120,
                    fontSize: FontSize.s12,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  void _handlePrintSelected(List<GetProduct> selectedProducts) async {
    debugPrint('🖨️ PRINT triggered for ${selectedProducts.length} items');

    final validProducts = selectedProducts
        .where((product) =>
            product.barcode != null && product.barcode!.trim().isNotEmpty)
        .toList();

    if (validProducts.length < selectedProducts.length) {
      final bool shouldContinue = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Missing Barcode'),
              content: Text(validProducts.isEmpty
                  ? 'These products don\'t have a barcode. Please add a barcode first.'
                  : 'Some products don\'t have a barcode. Do you want to skip them and continue?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context,
                      false), // Returning false to indicate cancel/close
                  child: Text(validProducts.isEmpty ? 'Close' : 'Cancel'),
                ),
                if (validProducts.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.pop(
                        context, true), // Returning true to indicate continue
                    child: const Text('Continue'),
                  ),
              ],
            ),
          ) ??
          false;

      if (!shouldContinue || validProducts.isEmpty) {
        return;
      }
    }

    final Map<String, dynamic>? result = await showDialog(
      context: context,
      builder: (context) =>
          ConfirmBarcodePrintModal(selectedProducts: validProducts),
    );

    if (result != null &&
        result['items'] != null &&
        (result['items'] as List).isNotEmpty) {
      final barcodePrinterService = BarcodePrinterService(context);
      await barcodePrinterService.printBarcodes(
        printItems: result['items'],
        stickerSize: result['size'] ?? '50x25mm',
        stickersPerRow: result['stickersPerRow'] ?? 1,
      );
    }
  }

  void _handlePrintSingle(GetProduct product) async {
    debugPrint('🖨️ PRINT single: ${product.productName}');

    if (product.barcode == null || product.barcode!.trim().isEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Missing Barcode'),
          content: const Text(
              'This product don\'t have a barcode. Please add a barcode first.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      return;
    }

    final Map<String, dynamic>? result = await showDialog(
      context: context,
      builder: (context) => ConfirmBarcodePrintModal(selectedProducts: [product]),
    );

    if (result != null &&
        result['items'] != null &&
        (result['items'] as List).isNotEmpty) {
      final barcodePrinterService = BarcodePrinterService(context);
      await barcodePrinterService.printBarcodes(
        printItems: result['items'],
        stickerSize: result['size'] ?? '50x25mm',
        stickersPerRow: result['stickersPerRow'] ?? 1,
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label: ',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s14,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {Color? textColor, Color? bgColor}) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor ?? Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            overflow: TextOverflow.visible,
            softWrap: false,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.13,
              textColor ?? Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final SideBarController sideBarController = Get.put(SideBarController());

    return SafeArea(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Print Barcodes",
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                  Row(
                    children: [
                      if (_selectedProductKeys.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: CustomRoundButton(
                            title:
                                "Print Selected (${_selectedProductKeys.length})",
                            fct: () {
                              final selected =
                                  _selectedProductsByKey.values.toList();
                              _handlePrintSelected(selected);
                            },
                            fontSize: 12,
                            height: 45,
                            width: 180,
                          ),
                        ),
                      if (_selectedProductKeys.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: CustomRoundButton(
                            title: "Clear Selected",
                            fct: () {
                              setState(() {
                                _selectedProductKeys.clear();
                                _selectedProductsByKey.clear();
                              });
                            },
                            fontSize: 12,
                            height: 45,
                            width: 150,
                            boxColor: Colors.white,
                            textColor: ColorManager.kPrimaryColor,
                            borderColor: ColorManager.kPrimaryColor,
                          ),
                        ),
                      // CustomRoundButton(
                      //   title: "Print Barcode",
                      //   fct: () async {
                      //     sideBarController.index.value = 18;
                      //   },
                      //   fontSize: 12,
                      //   height: 45,
                      //   width: 150,
                      // ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── FILTERS — ORIGINAL, UNTOUCHED ──
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BuildDropDownWithSearch<String>(
                              title: null,
                              showName: false,
                              hintText: 'Category',
                              value: categoryController.text == "All Categories"
                                  ? null
                                  : categoryController.text,
                              items: categories
                                  .where((category) =>
                                      category != "All Categories")
                                  .toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  categoryController.text =
                                      newValue ?? "All Categories";
                                });
                                searchProducts(1);
                              },
                              displayText: (category) => category,
                              searchController: categorySearchController,
                              height: 45,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BuildBoxShadowContainer(
                              circleRadius: 7,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 15),
                              height: 45,
                              child: TextField(
                                controller: productNameController,
                                onChanged: (value) {
                                  searchProducts(1);
                                },
                                decoration: InputDecoration(
                                  hintText: 'Product Name',
                                  hintStyle: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s12,
                                    0.27,
                                    ColorManager.textColor.withOpacity(.5),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.27,
                                  ColorManager.textColor.withOpacity(.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BuildBoxShadowContainer(
                              circleRadius: 7,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 15),
                              height: 45,
                              child: TextField(
                                controller: barcodeController,
                                onChanged: (value) {
                                  searchProducts(1);
                                },
                                decoration: InputDecoration(
                                  hintText: 'Barcode',
                                  hintStyle: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s12,
                                    0.27,
                                    ColorManager.textColor.withOpacity(.5),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.27,
                                  ColorManager.textColor.withOpacity(.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: CustomRoundButton(
                          title: "Reset",
                          boxColor: Colors.white,
                          textColor: ColorManager.kPrimaryColor,
                          borderColor: ColorManager.kPrimaryColor,
                          fct: resetSearch,
                          height: 45,
                          width: double.infinity,
                          fontSize: FontSize.s12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: initLoading ||
                              Provider.of<LocalProductProvider>(context,
                                      listen: true)
                                  .isLoading
                          ? const Center(
                              child: CircularProgressIndicator.adaptive())
                          : Consumer<LocalProductProvider>(
                              builder: (context, gridProvider, child) {
                                List<GetProduct>? listProductModelDataList =
                                    gridProvider.paginatedProducts;

                                if (listProductModelDataList.isEmpty) {
                                  return const Center(
                                      child: Text("No product data available"));
                                }

                                // column widths — shared between header and body
                                const Map<int, TableColumnWidth> colWidths = {
                                  0: FixedColumnWidth(55), // No
                                  1: FixedColumnWidth(48), // Checkbox
                                  2: FlexColumnWidth(2.0), // Product Name
                                  3: FlexColumnWidth(1.3), // Barcode
                                  4: FlexColumnWidth(1.3), // Category
                                  5: FlexColumnWidth(0.7), // Qty
                                  6: FlexColumnWidth(1.0), // Price
                                  7: FlexColumnWidth(1.0), // MRP
                                  8: FlexColumnWidth(1.1), // SKU
                                  9: FlexColumnWidth(0.8), // Action
                                };

                                final allSelected =
                                    listProductModelDataList.isNotEmpty &&
                                        listProductModelDataList.every((product) =>
                                            _isProductSelected(product));

                                return BuildBoxShadowContainer(
                                  margin: const EdgeInsets.only(top: 5),
                                  circleRadius: 7,
                                  offsetValue: const Offset(2, 2),
                                  blurRadius: 8.0,
                                  color: Colors.white,
                                  child: Column(
                                    children: [
                                      // ── CHANGED: new table header ──
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
                                          columnWidths: colWidths,
                                          border: null,
                                          defaultVerticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          children: [
                                          TableRow(
                                            children: [
                                              _buildTableHeader('No'),
                                              // Select-all checkbox
                                              Center(
                                                child: Checkbox(
                                                  value: allSelected,
                                                  onChanged: (val) {
                                                    setState(() {
                                                      if (val == true) {
                                                        for (final product
                                                            in listProductModelDataList) {
                                                          _setProductSelected(
                                                              product, true);
                                                        }
                                                      } else {
                                                        for (final product
                                                            in listProductModelDataList) {
                                                          _setProductSelected(
                                                              product, false);
                                                        }
                                                      }
                                                    });
                                                  },
                                                  activeColor: ColorManager
                                                      .kPrimaryColor,
                                                ),
                                              ),
                                              _buildTableHeader(
                                                  'Product Name'),
                                              _buildTableHeader('Barcode'),
                                              _buildTableHeader('Category'),
                                              _buildTableHeader('Qty'),
                                              _buildTableHeader('Price'),
                                              _buildTableHeader('MRP'),
                                              _buildTableHeader('SKU'),
                                              _buildTableHeader('Action'),
                                            ],
                                          ),
                                          ],
                                        ),
                                      ),
                                      // ── CHANGED: new table body ──
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
                                                columnWidths: colWidths,
                                                border: null,
                                                defaultVerticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                children: [
                                                  ...listProductModelDataList
                                                      .asMap()
                                                      .entries
                                                      .map((entry) {
                                                    final int index = entry.key;
                                                    final product = entry.value;
                                                    final isSelected =
                                                        _isProductSelected(product);
                                                    
                                                    // Calculate serial number based on pagination
                                                    final serialNumber =
                                                        gridProvider.paginationFrom +
                                                            index;

                                                    return TableRow(
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? ColorManager
                                                                .kPrimaryColor
                                                                .withOpacity(
                                                                    0.07)
                                                            : index % 2 == 0
                                                                ? Colors.white
                                                                : Colors.grey
                                                                    .withOpacity(
                                                                        0.1),
                                                      ),
                                                      children: [
                                                        _buildTableCell(
                                                            serialNumber.toString()),
                                                        // Row checkbox
                                                        Center(
                                                          child: Checkbox(
                                                            value: isSelected,
                                                            onChanged: (val) {
                                                              setState(() {
                                                                _setProductSelected(
                                                                  product,
                                                                  val == true,
                                                                );
                                                              });
                                                            },
                                                            activeColor:
                                                                ColorManager
                                                                    .kPrimaryColor,
                                                          ),
                                                        ),
                                                        _buildTableCell(
                                                            product.productName ??
                                                                ''),
                                                        _buildTableCell(
                                                            product.barcode ??
                                                                'N/A'),
                                                        _buildTableCell(product
                                                                .category?.name ??
                                                            'N/A'),
                                                        _buildTableCell(product
                                                                .numberOfProductsAvailable ??
                                                            'N/A'),
                                                        _buildTableCell(
                                                            product.price?.price?.toString() ??
                                                                'N/A'),
                                                        _buildTableCell(
                                                            product.mrp?.toString() ?? 'N/A'),
                                                        _buildTableCell(
                                                            product.sku ?? 'N/A'),
                                                        // ── Print icon ──
                                                        Center(
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              IconButton(
                                                                icon: const Icon(
                                                                    Icons.visibility,
                                                                    size: 18,
                                                                    color: Colors
                                                                        .green),
                                                                onPressed: () =>
                                                                    _showProductDetails(
                                                                        product),
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                constraints:
                                                                    const BoxConstraints(),
                                                                tooltip:
                                                                    "View Details",
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                              IconButton(
                                                                icon: const Icon(
                                                                    Icons.print,
                                                                    size: 18,
                                                                    color: Colors
                                                                        .blue),
                                                                onPressed: () =>
                                                                    _handlePrintSingle(
                                                                        product),
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                constraints:
                                                                    const BoxConstraints(),
                                                                tooltip:
                                                                    "Print Barcode",
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }),
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
                    const SizedBox(height: 10),
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

  @override
  void dispose() {
    productNameController.dispose();
    categoryController.dispose();
    categorySearchController.dispose();
    barcodeController.dispose();
    super.dispose();
  }
}
