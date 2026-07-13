import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_pagination_control.dart';
import 'package:pos_machine/components/build_text_fields.dart';

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
import 'widgets/barcode_mobile_filters.dart';
import 'widgets/confirm_barcode_print_modal.dart';
import 'widgets/product_barcode_responsive.dart';

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
  bool _showFilters = false;
  bool _isPrinting = false;
  List<String> categories = ["All Categories"];

  // Track selected products by stable key so selection survives pagination.
  final Set<String> _selectedProductKeys = {};
  final Map<String, GetProduct> _selectedProductsByKey = {};

  @override
  void initState() {
    super.initState();
    loadInitData();
    categoryController.text = "All Categories";
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _showFilters = !_isMobile(context);
        });
      }
    });
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
        if (mounted) setState(() => initLoading = false);
        return;
      }

      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      if (!categoryProvider.isCategoriesLoaded) {
        debugPrint("📥 Loading categories from API...");
        await categoryProvider.ensureCategoriesLoaded();
        if (!mounted) return;
        debugPrint("✅ Categories loaded and cached");
      } else {
        debugPrint(
            "📋 Using cached categories (${categoryProvider.category?.length ?? 0} items)");
      }

      Provider.of<LocalProductProvider>(context, listen: false)
          .listAllProducts(categoryId: 0);

      _extractCategories();

      if (!mounted) return;
      setState(() {
        isInitialized = true;
        initLoading = false;
      });
    } catch (error) {
      debugPrint("Error loading products: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading products: $error")),
        );
        setState(() => initLoading = false);
      }
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
      for (final category in categoryProvider.category ?? const []) {
        if (category.categoryName == categoryController.text) {
          catId = category.categoryId;
          break;
        }
      }
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

    if (_isMobile(context)) {
      setState(() {
        _showFilters = false;
      });
    }
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

    final isPhone = productBarcodeIsPhone(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isPhone ? 16 : 24),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isPhone ? 16 : 40,
          vertical: isPhone ? 24 : 40,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isPhone
                ? MediaQuery.of(context).size.width
                : MediaQuery.of(context).size.width / 2,
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: EdgeInsetsDirectional.all(isPhone ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Stock Details',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        isPhone ? FontSize.s18 : FontSize.s20,
                        0.30,
                        ColorManager.textColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildDetailRow(
                        'Product Name', product.productName ?? 'N/A'),
                    _buildDetailRow(
                        'Category', product.category?.name ?? 'N/A'),
                    _buildDetailRow('Store Name', 'N/A'),
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
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: CustomRoundButton(
                  title: "Close",
                  boxColor: Colors.white,
                  textColor: ColorManager.kPrimaryColor,
                  borderColor: ColorManager.kPrimaryColor,
                  fct: () => Navigator.pop(context),
                  height: 45,
                  width: isPhone ? double.infinity : 120,
                  fontSize: FontSize.s12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePrintSelected(List<GetProduct> selectedProducts) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
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

      if (!mounted) return;
      final BarcodePrintRequest? result = await showDialog<BarcodePrintRequest>(
        context: context,
        builder: (context) =>
            ConfirmBarcodePrintModal(selectedProducts: validProducts),
      );

      if (mounted && result != null && result.items.isNotEmpty) {
        final barcodePrinterService = BarcodePrinterService(context);
        final printResult = await barcodePrinterService.printBarcodes(
          printItems: result.items,
          stickerSize: result.stickerSize,
          stickersPerRow: result.stickersPerRow,
        );

        if (mounted && printResult.isSuccess) {
          setState(() {
            _selectedProductKeys.clear();
            _selectedProductsByKey.clear();
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _handlePrintSingle(GetProduct product) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
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

      if (!mounted) return;
      final BarcodePrintRequest? result = await showDialog<BarcodePrintRequest>(
        context: context,
        builder: (context) =>
            ConfirmBarcodePrintModal(selectedProducts: [product]),
      );

      if (mounted && result != null && result.items.isNotEmpty) {
        final barcodePrinterService = BarcodePrinterService(context);
        final printResult = await barcodePrinterService.printBarcodes(
          printItems: result.items,
          stickerSize: result.stickerSize,
          stickersPerRow: result.stickersPerRow,
        );

        if (mounted && printResult.isSuccess) {
          setState(() {
            _selectedProductKeys.clear();
            _selectedProductsByKey.clear();
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // ── UI HELPERS ──

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < kProductBarcodePhoneBreakpoint;

  bool _hasActiveFilters() {
    return productNameController.text.isNotEmpty ||
        barcodeController.text.isNotEmpty ||
        categoryController.text != "All Categories";
  }

  Widget _buildCategoryDropdown() {
    return BuildDropDownWithSearch<String>(
      title: null,
      showName: false,
      hintText: 'Category',
      value: categoryController.text == "All Categories"
          ? null
          : categoryController.text,
      items:
          categories.where((category) => category != "All Categories").toList(),
      onChanged: (String? newValue) {
        setState(() {
          categoryController.text = newValue ?? "All Categories";
        });
        searchProducts(1);
      },
      displayText: (category) => category,
      searchController: categorySearchController,
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isPhone = productBarcodeIsPhone(context);

    if (isPhone) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 10),
        child: ProductBarcodeInfoChip(label: label, value: value),
      );
    }

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
            child: SelectableText(
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s12,
          0.18,
          ColorManager.kTitleTextColor,
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildHeaderActions(bool isMobile) {
    if (_selectedProductKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    final printButton = CustomRoundButton(
      title: _isPrinting
          ? 'Printing...'
          : "Print Selected (${_selectedProductKeys.length})",
      fct: () {
        if (_isPrinting) return;
        final selected = _selectedProductsByKey.values.toList();
        _handlePrintSelected(selected);
      },
      fontSize: 12,
      height: 45,
      width: isMobile ? double.infinity : 180,
    );

    final clearButton = CustomRoundButton(
      title: "Clear Selected",
      fct: () {
        setState(() {
          _selectedProductKeys.clear();
          _selectedProductsByKey.clear();
        });
      },
      fontSize: 12,
      height: 45,
      width: isMobile ? double.infinity : 150,
      boxColor: Colors.white,
      textColor: ColorManager.kPrimaryColor,
      borderColor: ColorManager.kPrimaryColor,
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProductBarcodeSelectionBadge(count: _selectedProductKeys.length),
            ],
          ),
          const SizedBox(height: 10),
          printButton,
          const SizedBox(height: 10),
          clearButton,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        printButton,
        const SizedBox(width: 10),
        clearButton,
      ],
    );
  }

  Widget _buildFilterSection(Size size, bool isMobile) {
    if (isMobile && !_showFilters) {
      return const SizedBox.shrink();
    }

    if (isMobile) {
      return BarcodeMobileFilters(
        productNameController: productNameController,
        barcodeController: barcodeController,
        categoryField: _buildCategoryDropdown(),
        onSearch: (value) {
          searchProducts(1);
        },
        onReset: resetSearch,
      );
    }

    return ProductBarcodeFilterLayout(
      children: [
        _buildCategoryDropdown(),
        buildColumnWidgetForTextFields(
          height: 45,
          onchanged: (value) {
            searchProducts(1);
          },
          controller: productNameController,
          size: size,
          hintText: 'Product Name',
        ),
        buildColumnWidgetForTextFields(
          height: 45,
          onchanged: (value) {
            searchProducts(1);
          },
          controller: barcodeController,
          size: size,
          hintText: 'Barcode',
        ),
        CustomRoundButton(
          title: "Reset",
          boxColor: Colors.white,
          textColor: ColorManager.kPrimaryColor,
          borderColor: ColorManager.kPrimaryColor,
          fct: resetSearch,
          height: 45,
          width: double.infinity,
          fontSize: FontSize.s12,
        ),
      ],
    );
  }

  Widget _buildCompactFieldBox({
    required String label,
    required String value,
    bool copyable = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s10,
              0.15,
              Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s12,
                    0.18,
                    ColorManager.textColor,
                  ),
                ),
              ),
              if (copyable && value.isNotEmpty && value != 'N/A') ...[
                const SizedBox(width: 6),
                Builder(
                  builder: (context) => GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      showScaffold(
                        context: context,
                        message: '$label copied to clipboard',
                      );
                    },
                    child: const Icon(
                      Icons.copy,
                      size: 14,
                      color: Colors.black38,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileProductCard({
    required GetProduct product,
    required int serialNumber,
    required bool isSelected,
  }) {
    final categoryName = product.category?.name ?? 'N/A';

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: ProductBarcodeContentCard(
        padding: const EdgeInsetsDirectional.all(14),
        color: isSelected
            ? ColorManager.kPrimaryColor.withValues(alpha: 0.04)
            : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              _setProductSelected(product, val == true);
                            });
                          },
                          activeColor: ColorManager.kPrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              product.productName ?? 'Unnamed',
                              style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                FontSize.s14,
                                0.18,
                                ColorManager.kPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Flexible(
                                  child: SelectableText(
                                    categoryName,
                                    style: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s11,
                                      0.13,
                                      Colors.black54,
                                    ),
                                  ),
                                ),
                                Text(
                                  ' · #$serialNumber',
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s11,
                                    0.13,
                                    Colors.black54,
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
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'View Details',
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: BuildBoxShadowContainer(
                          color: Colors.white,
                          circleRadius: 6,
                          child: IconButton(
                            icon: Icon(Icons.visibility,
                                size: 14,
                                color: ColorManager.kPrimaryColor.withOpacity(0.9)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showProductDetails(product),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Print Barcode',
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: BuildBoxShadowContainer(
                          color: ColorManager.kPrimaryColor,
                          circleRadius: 6,
                          child: IconButton(
                            icon: const Icon(Icons.print,
                                size: 14, color: Colors.white),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _handlePrintSingle(product),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildCompactFieldBox(
                    label: 'Barcode',
                    value: product.barcode ?? 'N/A',
                    copyable: true,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildCompactFieldBox(
                    label: 'Qty',
                    value: product.numberOfProductsAvailable ?? 'N/A',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildCompactFieldBox(
                    label: 'Price',
                    value: product.price?.price?.toString() ?? 'N/A',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(
    LocalProductProvider gridProvider,
    List<GetProduct> listProductModelDataList,
  ) {
    const Map<int, TableColumnWidth> colWidths = {
      0: FixedColumnWidth(55),
      1: FixedColumnWidth(48),
      2: FlexColumnWidth(2.0),
      3: FlexColumnWidth(1.3),
      4: FlexColumnWidth(1.3),
      5: FlexColumnWidth(0.7),
      6: FlexColumnWidth(1.0),
      7: FlexColumnWidth(1.0),
      8: FlexColumnWidth(1.1),
      9: FlexColumnWidth(0.8),
    };

    final allSelected = listProductModelDataList.isNotEmpty &&
        listProductModelDataList
            .every((product) => _isProductSelected(product));

    return ProductBarcodeResponsiveTable(
      minWidth: 960,
      table: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: ColorManager.tableBGColor.withValues(alpha: 0.5),
              border: Border(
                bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
              ),
            ),
            child: Table(
              columnWidths: colWidths,
              border: null,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    _buildTableHeader('No'),
                    Center(
                      child: Checkbox(
                        value: allSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              for (final product in listProductModelDataList) {
                                _setProductSelected(product, true);
                              }
                            } else {
                              for (final product in listProductModelDataList) {
                                _setProductSelected(product, false);
                              }
                            }
                          });
                        },
                        activeColor: ColorManager.kPrimaryColor,
                      ),
                    ),
                    _buildTableHeader('Product Name'),
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
          Expanded(
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
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  child: Table(
                    columnWidths: colWidths,
                    border: null,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      ...listProductModelDataList.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final product = entry.value;
                        final isSelected = _isProductSelected(product);
                        final serialNumber =
                            gridProvider.paginationFrom + index;

                        return TableRow(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ColorManager.kPrimaryColor
                                    .withValues(alpha: 0.07)
                                : index % 2 == 0
                                    ? Colors.white
                                    : Colors.grey.withValues(alpha: 0.06),
                          ),
                          children: [
                            _buildTableCell(serialNumber.toString()),
                            Center(
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    _setProductSelected(product, val == true);
                                  });
                                },
                                activeColor: ColorManager.kPrimaryColor,
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: SelectableText(
                                      product.productName ?? '',
                                      textAlign: TextAlign.center,
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.13,
                                        Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          product.barcode ?? 'N/A',
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.13,
                                            Colors.black,
                                          ),
                                        ),
                                      ),
                                      if (product.barcode != null && product.barcode!.isNotEmpty && product.barcode != 'N/A') ...[
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(
                                                text: product.barcode!));
                                            showScaffold(
                                              context: context,
                                              message: 'Barcode copied to clipboard',
                                            );
                                          },
                                          child: const Icon(
                                            Icons.copy,
                                            size: 14,
                                            color: Colors.black38,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: SelectableText(
                                      product.category?.name ?? 'N/A',
                                      textAlign: TextAlign.center,
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s12,
                                        0.13,
                                        Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _buildTableCell(
                                product.numberOfProductsAvailable ?? 'N/A'),
                            _buildTableCell(
                                product.price?.price?.toString() ?? 'N/A'),
                            _buildTableCell(product.mrp?.toString() ?? 'N/A'),
                            _buildTableCell(product.sku ?? 'N/A'),
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ProductBarcodeIconAction(
                                    icon: Icons.visibility,
                                    iconColor: ColorManager.kPrimaryColor
                                        .withValues(alpha: 0.9),
                                    tooltip: 'View Details',
                                    onPressed: () =>
                                        _showProductDetails(product),
                                  ),
                                  const SizedBox(width: 5),
                                  ProductBarcodeIconAction(
                                    icon: Icons.print,
                                    iconColor: ColorManager.kPrimaryColor,
                                    tooltip: 'Print Barcode',
                                    onPressed: () =>
                                        _handlePrintSingle(product),
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
  }

  Widget _buildMobileList(
    LocalProductProvider gridProvider,
    List<GetProduct> listProductModelDataList,
  ) {
    final allSelected = listProductModelDataList.isNotEmpty &&
        listProductModelDataList
            .every((product) => _isProductSelected(product));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Checkbox(
                  value: allSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        for (final product in listProductModelDataList) {
                          _setProductSelected(product, true);
                        }
                      } else {
                        for (final product in listProductModelDataList) {
                          _setProductSelected(product, false);
                        }
                      }
                    });
                  },
                  activeColor: ColorManager.kPrimaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Select all on page',
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.15,
                  ColorManager.textColor,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
            itemCount: listProductModelDataList.length,
            itemBuilder: (context, index) {
              final product = listProductModelDataList[index];
              final serialNumber = gridProvider.paginationFrom + index;
              return _buildMobileProductCard(
                product: product,
                serialNumber: serialNumber,
                isSelected: _isProductSelected(product),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final bool isMobile = _isMobile(context);
    final double horizontalMargin = isMobile ? 8 : 12;

    return SafeArea(
      child: Container(
        margin: EdgeInsetsDirectional.only(
          start: horizontalMargin,
          end: horizontalMargin,
          top: isMobile ? 10 : 20,
          bottom: isMobile ? 10 : 20,
        ),
        padding: EdgeInsets.all(isMobile ? 4 : 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
          boxShadow: const [
            BoxShadow(
              color: ColorManager.boxShadowColor,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
          color: Colors.white,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            vertical: isMobile ? 12.0 : 5.0,
            horizontal: isMobile ? 12.0 : 20.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Row(
                  children: [
                    const Expanded(
                      child: ProductBarcodePageHeader(
                        title: 'Print Barcodes',
                        subtitle: 'Select products to print barcode labels',
                      ),
                    ),
                    ProductBarcodeFilterToggle(
                      showFilters: _showFilters,
                      hasActiveFilters: _hasActiveFilters(),
                      onToggle: () {
                        setState(() {
                          _showFilters = !_showFilters;
                        });
                      },
                    ),
                  ],
                )
              else
                ProductBarcodePageHeader(
                  title: 'Print Barcodes',
                  subtitle: 'Select products to print barcode labels',
                  trailing: _buildHeaderActions(false),
                ),
              if (isMobile) ...[
                const SizedBox(height: 12),
                _buildHeaderActions(true),
              ],
              const SizedBox(height: 15),
              _buildFilterSection(size, isMobile),
              if (isMobile && _showFilters) const SizedBox(height: 12),
              if (!isMobile) const SizedBox(height: 10),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: initLoading ||
                              Provider.of<LocalProductProvider>(context,
                                      listen: true)
                                  .isLoading
                          ? const ProductBarcodeLoadingState()
                          : Consumer<LocalProductProvider>(
                              builder: (context, gridProvider, child) {
                                List<GetProduct>? listProductModelDataList =
                                    gridProvider.paginatedProducts;

                                if (listProductModelDataList.isEmpty) {
                                  return const ProductBarcodeEmptyState(
                                    title: 'No product data available',
                                    subtitle:
                                        'Try adjusting your filters or search terms',
                                  );
                                }

                                if (isMobile) {
                                  return _buildMobileList(
                                    gridProvider,
                                    listProductModelDataList,
                                  );
                                }

                                return _buildDesktopTable(
                                  gridProvider,
                                  listProductModelDataList,
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: isMobile ? 0 : 20.0,
                        vertical: 10,
                      ),
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
