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

import '../../components/build_round_button.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'package:pos_machine/screens/print/barcode_printer_service.dart';
import 'widgets/barcode_mobile_filters.dart';
import 'widgets/confirm_barcode_print_modal.dart';
import 'widgets/product_barcode_responsive.dart';

// ---------------------------------------------------------------------------
// BarcodeRow: wraps a base product + optional variant/saleUnit so every
// printable barcode gets its own row in the list.
// ---------------------------------------------------------------------------
class BarcodeRow {
  final GetProduct product;
  final ProductVariant? variant;
  final SaleUnit? saleUnit;

  const BarcodeRow({
    required this.product,
    this.variant,
    this.saleUnit,
  });

  // ── Display helpers ──

  String get _variantSuffix {
    if (variant == null) return '';
    final attrs = variant!.attributes.values
        .where((v) => v != null && v.toString().isNotEmpty)
        .join('/');
    return attrs.isNotEmpty ? ' - $attrs' : '';
  }

  String get _saleUnitSuffix {
    if (saleUnit == null) return '';
    final unitLabel = saleUnit!.unitName ?? '';
    return unitLabel.isNotEmpty ? ' ($unitLabel)' : '';
  }

  dynamic _buildRowNames(dynamic originalNames, String suffix) {
    if (originalNames == null) return null;
    if (originalNames is Map) {
      final newNames = <dynamic, dynamic>{};
      originalNames.forEach((key, value) {
        if (value is String) {
          newNames[key] =
              value.trim().isNotEmpty ? '${value.trim()}$suffix' : value;
        } else if (value is Map) {
          final newSubMap = <dynamic, dynamic>{};
          value.forEach((subKey, subValue) {
            if (subKey == 'name' || subKey == 'value') {
              newSubMap[subKey] =
                  (subValue != null && subValue.toString().trim().isNotEmpty)
                      ? '${subValue.toString().trim()}$suffix'
                      : subValue;
            } else {
              newSubMap[subKey] = subValue;
            }
          });
          newNames[key] = newSubMap;
        } else {
          newNames[key] = value;
        }
      });
      return newNames;
    }
    if (originalNames is List) {
      return originalNames.map((item) {
        if (item is Map) {
          final newItem = <dynamic, dynamic>{};
          item.forEach((key, value) {
            if (key == 'name' || key == 'value') {
              newItem[key] =
                  (value != null && value.toString().trim().isNotEmpty)
                      ? '${value.toString().trim()}$suffix'
                      : value;
            } else {
              newItem[key] = value;
            }
          });
          return newItem;
        }
        return item;
      }).toList();
    }
    return originalNames;
  }

  String get displayName {
    if (variant != null) {
      return '${product.productName ?? ''}$_variantSuffix';
    }
    if (saleUnit != null) {
      return '${product.productName ?? ''}$_saleUnitSuffix';
    }
    return product.productName ?? '';
  }

  String? get barcode {
    if (variant != null) return variant!.barcode;
    if (saleUnit != null) return saleUnit!.barcode;
    return product.barcode;
  }

  String? get sku {
    if (variant != null) return variant!.sku ?? product.sku;
    return product.sku;
  }

  String get quantity {
    if (variant != null) {
      return variant!.quantity?.toString() ?? '0';
    }
    // If the product has variants, the base product's own standalone quantity
    // is the sum of stock entries where productVariantId is null (excluding variants).
    final hasVariants =
        product.variants != null && product.variants!.isNotEmpty;
    if (hasVariants) {
      final baseStockQty = product.stock
          ?.where((s) => s.productVariantId == null)
          .fold<num>(0, (sum, s) => sum + (s.quantity ?? 0));
      if (baseStockQty != null && baseStockQty > 0) {
        return baseStockQty % 1 == 0
            ? baseStockQty.toInt().toString()
            : baseStockQty.toString();
      }
      return '0';
    }
    return product.numberOfProductsAvailable ?? 'N/A';
  }

  String get priceDisplay {
    if (variant != null) {
      //  treat zero variant price as invalid — fall back to base.
      final v = variant!;
      final vPrice = (v.price != null && v.price! > 0) ? v.price : null;
      return (vPrice ?? product.price?.price)?.toString() ?? 'N/A';
    }
    if (saleUnit != null) {
      //  reuse the shared resolution chain (batch override →
      // master price → resolvedPrice → base×rate), all with > 0 guards.
      final resolved = SaleUnit.resolveDisplayPrice(
        product: product,
        saleUnit: saleUnit!,
      );
      return resolved?.toString() ?? product.price?.price?.toString() ?? 'N/A';
    }
    return product.price?.price?.toString() ?? 'N/A';
  }

  String get mrpDisplay {
    if (variant != null) {
      //  treat zero variant MRP as invalid — fall back to base.
      final v = variant!;
      final vMrp = (v.mrp != null && v.mrp! > 0) ? v.mrp : null;
      return (vMrp ?? product.mrp)?.toString() ?? 'N/A';
    }
    return product.mrp?.toString() ?? 'N/A';
  }

  /// Stable, unique key for selection tracking.
  ///
  ///  sale-unit key uses a composite fallback so two local/unsaved
  /// sale units with null [SaleUnit.id] on the same product produce distinct
  /// keys (distinguished by unitId, conversionRate/unitName, and barcode).
  String get selectionKey {
    if (variant != null) {
      return 'variant:${product.productId}:${variant!.id}';
    }
    if (saleUnit != null) {
      final u = saleUnit!;
      return 'unit:${product.productId}:'
          '${u.id ?? u.unitId}:'
          '${u.conversionRate ?? u.unitName}:'
          '${u.barcode ?? ''}';
    }
    if (product.productId != null) {
      return 'id:${product.productId}';
    }
    return 'fallback:${product.barcode ?? ''}|${product.productName ?? ''}';
  }

  /// Returns a [GetProduct] copy with this row's specific barcode, name,
  /// price, MRP, SKU and quantity baked in — so the existing print pipeline
  /// (ConfirmBarcodePrintModal → BarcodePrinterService) works unchanged.
  GetProduct toProductForPrint() {
    if (variant != null) {
      final v = variant!;
      //  treat zero variant price/MRP as invalid — fall back to base.
      final vPrice = (v.price != null && v.price! > 0) ? v.price : null;
      final vMrp = (v.mrp != null && v.mrp! > 0) ? v.mrp : null;
      final rowPrice = vPrice ?? product.price?.price;
      final rowMrp = vMrp ?? product.mrp;
      return product.copyWith(
        barcode: v.barcode ?? product.barcode,
        productName: displayName,
        sku: v.sku ?? product.sku,
        numberOfProductsAvailable: quantity,
        mrp: rowMrp,
        price: ProductPrice(
          price: rowPrice,
          oldPrice: product.price?.oldPrice,
          percentage: product.price?.percentage,
          totalPrice: product.price?.totalPrice,
        ),
        names: _buildRowNames(product.names, _variantSuffix),
        stock: product.stock?.where((s) => s.productVariantId == v.id).toList(),
      );
    }
    if (saleUnit != null) {
      final u = saleUnit!;
      //  use the shared resolution chain so batch overrides and the
      // base×conversionRate auto-fallback are included, matching billing.
      final rowPrice = SaleUnit.resolveDisplayPrice(
        product: product,
        saleUnit: u,
      );
      return product.copyWith(
        barcode: u.barcode ?? product.barcode,
        productName: displayName,
        numberOfProductsAvailable: quantity,
        price: ProductPrice(
          price: rowPrice ?? product.price?.price,
          oldPrice: product.price?.oldPrice,
          percentage: product.price?.percentage,
          totalPrice: product.price?.totalPrice,
        ),
        names: _buildRowNames(product.names, _saleUnitSuffix),
        stock: const [],
      );
    }
    //  base branch — only pass stock records that belong to the base
    // product (productVariantId == null). Variant-owned batch records must not
    // bleed into the base row's print output.
    final baseStock =
        product.stock?.where((s) => s.productVariantId == null).toList() ??
            const [];
    return product.copyWith(stock: baseStock);
  }
}

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

  // ── Barcode-screen pagination (Issue 5) ─────────────────────────────────
  // Pagination is applied to the EXPANDED BarcodeRow list so that page size
  // and serial numbers reflect actual printable rows, not parent products.
  //
  // Memoization: _allBarcodeRows is only recomputed when the provider's
  // filteredProductsVersion counter changes. Selection state changes and page
  // navigation call setState but do NOT increment the version, so re-expansion
  // is skipped for those rebuilds — safe even for catalogs with thousands of rows.

  /// The full expanded list (all pages). Rebuilt only when filtered products change.
  List<BarcodeRow> _allBarcodeRows = const [];

  /// Provider version at the time of last expansion. Used as memoization key.
  int _lastFilteredVersion = -1;

  /// Current page within the expanded BarcodeRow list (1-based).
  int _barcodePage = 1;

  static const int _barcodeRowsPerPage = 20;

  int get _barcodeTotalPages =>
      (_allBarcodeRows.length / _barcodeRowsPerPage).ceil().clamp(1, 999999);

  /// 1-based serial number of the first row on the current page.
  int get _barcodeFrom => (_barcodePage - 1) * _barcodeRowsPerPage + 1;

  /// The slice of expanded rows for the current page.
  List<BarcodeRow> get _currentPageRows {
    final start = (_barcodePage - 1) * _barcodeRowsPerPage;
    if (start >= _allBarcodeRows.length) return const [];
    final end = (start + _barcodeRowsPerPage).clamp(0, _allBarcodeRows.length);
    return _allBarcodeRows.sublist(start, end);
  }

  // Track selected products by stable key so selection survives pagination.
  final Set<String> _selectedProductKeys = {};
  final Map<String, BarcodeRow> _selectedProductsByKey = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => loadInitData());
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
  }

  List<BarcodeRow> expandProductsToBarcodeRows(List<GetProduct> products) {
    final rows = <BarcodeRow>[];
    for (final product in products) {
      final subRows = <BarcodeRow>[];

      final variants = product.variants;
      if (variants != null && variants.isNotEmpty) {
        for (final v in variants) {
          if (!v.active) continue;
          final bc = v.barcode?.trim() ?? '';
          if (bc.isNotEmpty) {
            subRows.add(BarcodeRow(product: product, variant: v));
          }
        }
      }

      final units = product.saleUnits;
      if (units != null && units.isNotEmpty) {
        final baseBarcode = (product.barcode ?? '').trim();
        for (final u in units) {
          final bc = u.barcode?.trim() ?? '';
          if (bc.isNotEmpty && bc != baseBarcode) {
            subRows.add(BarcodeRow(product: product, saleUnit: u));
          }
        }
      }

      // Always show the base product row.
      rows.add(BarcodeRow(product: product));

      // Show any variant or sale-unit rows.
      rows.addAll(subRows);
    }

    final query = barcodeController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      return rows.where((row) {
        final rowBc = row.barcode?.trim().toLowerCase() ?? '';
        return rowBc.contains(query);
      }).toList();
    }

    return rows;
  }

  bool _isRowSelected(BarcodeRow row) {
    return _selectedProductKeys.contains(row.selectionKey);
  }

  void _setRowSelected(BarcodeRow row, bool selected) {
    final key = row.selectionKey;
    if (selected) {
      _selectedProductKeys.add(key);
      _selectedProductsByKey[key] = row;
    } else {
      _selectedProductKeys.remove(key);
      _selectedProductsByKey.remove(key);
    }
  }

  void _showProductDetails(BarcodeRow row) {
    setState(() {
      selectedProduct = row.product;
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
                    _buildDetailRow('Product Name', row.displayName),
                    _buildDetailRow(
                        'Category', row.product.category?.name ?? 'N/A'),
                    _buildDetailRow('Unit', row.product.unit ?? 'N/A'),
                    _buildDetailRow('Retail Price', row.priceDisplay),
                    _buildDetailRow('MRP', row.mrpDisplay),
                    _buildDetailRow('Quantity', row.quantity),
                    _buildDetailRow('Barcode', row.barcode ?? 'N/A'),
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

  Future<void> _handlePrintSelected(List<BarcodeRow> selectedRows) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      final validRows = selectedRows
          .where((row) => row.barcode != null && row.barcode!.trim().isNotEmpty)
          .toList();

      if (validRows.length < selectedRows.length) {
        final bool shouldContinue = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Missing Barcode'),
                content: Text(validRows.isEmpty
                    ? 'These products don\'t have a barcode.'
                    : 'Some products don\'t have a barcode. Skip and continue?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(validRows.isEmpty ? 'Close' : 'Cancel'),
                  ),
                  if (validRows.isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Continue'),
                    ),
                ],
              ),
            ) ??
            false;

        if (!shouldContinue || validRows.isEmpty) {
          return;
        }
      }

      final validProducts =
          validRows.map((r) => r.toProductForPrint()).toList();

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
          printRotationDegrees: result.printRotationDegrees,
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

  Future<void> _handlePrintSingle(BarcodeRow row) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      if (row.barcode == null || row.barcode!.trim().isEmpty) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Missing Barcode'),
            content: const Text('This product doesn\'t have a barcode.'),
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

      final printProduct = row.toProductForPrint();

      if (!mounted) return;
      final BarcodePrintRequest? result = await showDialog<BarcodePrintRequest>(
        context: context,
        builder: (context) =>
            ConfirmBarcodePrintModal(selectedProducts: [printProduct]),
      );

      if (mounted && result != null && result.items.isNotEmpty) {
        final barcodePrinterService = BarcodePrinterService(context);
        final printResult = await barcodePrinterService.printBarcodes(
          printItems: result.items,
          stickerSize: result.stickerSize,
          stickersPerRow: result.stickersPerRow,
          printRotationDegrees: result.printRotationDegrees,
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
        final selectedRows = _selectedProductsByKey.values.toList();
        _handlePrintSelected(selectedRows);
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
    required BarcodeRow row,
    required int serialNumber,
    required bool isSelected,
  }) {
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
                              _setRowSelected(row, val == true);
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
                              row.displayName,
                              style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                FontSize.s14,
                                0.18,
                                ColorManager.kPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '#$serialNumber',
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s11,
                                0.13,
                                Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 16),
                      onPressed: () => _showProductDetails(row),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print, size: 16),
                      onPressed: () => _handlePrintSingle(row),
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
                    value: row.barcode ?? 'N/A',
                    copyable: true,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildCompactFieldBox(
                    label: 'Qty',
                    value: row.quantity,
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
    List<BarcodeRow> barcodeRows,
    int fromIndex,
  ) {
    const Map<int, TableColumnWidth> colWidths = {
      0: FixedColumnWidth(55),
      1: FixedColumnWidth(48),
      2: FlexColumnWidth(2.0),
      3: FlexColumnWidth(1.3),
      4: FlexColumnWidth(1.3),
      5: FlexColumnWidth(0.7),
      6: FlexColumnWidth(0.8),
      7: FlexColumnWidth(0.8),
      8: FlexColumnWidth(1.0),
      9: FixedColumnWidth(90),
    };

    // barcodeRows is already the current-page slice (Issue 5 — no re-expansion).

    final allSelected = barcodeRows.isNotEmpty &&
        barcodeRows.every((row) => _isRowSelected(row));

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FC),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            border: Border(
              bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
            ),
          ),
          child: Table(
            columnWidths: colWidths,
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
                          for (final row in barcodeRows) {
                            _setRowSelected(row, val == true);
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
                    ...barcodeRows.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final row = entry.value;
                      final isSelected = _isRowSelected(row);
                      //  serial numbers based on expanded-row offset.
                      final serialNumber = fromIndex + index;

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
                                  _setRowSelected(row, val == true);
                                });
                              },
                              activeColor: ColorManager.kPrimaryColor,
                            ),
                          ),
                          TableCell(
                            verticalAlignment:
                                TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: SelectableText(
                                    row.displayName,
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
                                        row.barcode ?? 'N/A',
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
                                    if (row.barcode != null &&
                                        row.barcode!.isNotEmpty &&
                                        row.barcode != 'N/A') ...[
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(
                                              text: row.barcode!));
                                          showScaffold(
                                            context: context,
                                            message:
                                                'Barcode copied to clipboard',
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
                            verticalAlignment:
                                TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: SelectableText(
                                    row.product.category?.name ?? 'N/A',
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
                          _buildTableCell(row.quantity),
                          _buildTableCell(row.priceDisplay),
                          _buildTableCell(row.mrpDisplay),
                          _buildTableCell(row.sku ?? 'N/A'),
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ProductBarcodeIconAction(
                                  icon: Icons.visibility,
                                  iconColor: ColorManager.kPrimaryColor
                                      .withValues(alpha: 0.9),
                                  tooltip: 'View Details',
                                  onPressed: () => _showProductDetails(row),
                                ),
                                const SizedBox(width: 5),
                                ProductBarcodeIconAction(
                                  icon: Icons.print,
                                  iconColor: ColorManager.kPrimaryColor,
                                  tooltip: 'Print Barcode',
                                  onPressed: () => _handlePrintSingle(row),
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
    );
  }

  Widget _buildMobileList(
    List<BarcodeRow> barcodeRows,
    int fromIndex,
  ) {
    // barcodeRows is already the current-page slice (Issue 5 — no re-expansion).

    final allSelected = barcodeRows.isNotEmpty &&
        barcodeRows.every((row) => _isRowSelected(row));

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
                        for (final row in barcodeRows) {
                          _setRowSelected(row, true);
                        }
                      } else {
                        for (final row in barcodeRows) {
                          _setRowSelected(row, false);
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
            itemCount: barcodeRows.length,
            itemBuilder: (context, index) {
              final row = barcodeRows[index];
              //  serial numbers based on expanded-row offset.
              final serialNumber = fromIndex + index;
              return _buildMobileProductCard(
                row: row,
                serialNumber: serialNumber,
                isSelected: _isRowSelected(row),
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
                                // Memoized expansion: only re-expand when the
                                // filtered product list actually changes.
                                if (gridProvider.filteredProductsVersion !=
                                    _lastFilteredVersion) {
                                  _lastFilteredVersion =
                                      gridProvider.filteredProductsVersion;
                                  _allBarcodeRows = expandProductsToBarcodeRows(
                                    gridProvider.allFilteredProducts,
                                  );
                                  _barcodePage = 1;
                                }

                                final pageRows = _currentPageRows;

                                if (_allBarcodeRows.isEmpty) {
                                  return const ProductBarcodeEmptyState(
                                    title: 'No product data available',
                                    subtitle:
                                        'Try adjusting your filters or search terms',
                                  );
                                }

                                if (isMobile) {
                                  return _buildMobileList(
                                    pageRows,
                                    _barcodeFrom,
                                  );
                                }

                                return _buildDesktopTable(
                                  pageRows,
                                  _barcodeFrom,
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
                          if (_allBarcodeRows.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return PaginationControl(
                            currentPage: _barcodePage,
                            totalPages: _barcodeTotalPages,
                            onPageChanged: (int page) {
                              setState(() {
                                _barcodePage =
                                    page.clamp(1, _barcodeTotalPages);
                              });
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
