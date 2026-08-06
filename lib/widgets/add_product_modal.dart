import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/domain/add_created_product_to_cart.dart';
import 'package:pos_machine/features/billing/domain/add_product_form_helpers.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/language.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/language_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/features/products/domain/variant_form_payload.dart';
import 'package:pos_machine/features/products/presentation/variant_editor_section.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/widgets/add_category_modal.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/newcomponents/custom_container_box.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';

class _SaleUnitFormRow {
  _SaleUnitFormRow({
    this.selectedUnitId,
    String conversionRate = '',
    String barcode = '',
    String price = '',
  })  : conversionRateController = TextEditingController(text: conversionRate),
        barcodeController = TextEditingController(text: barcode),
        priceController = TextEditingController(text: price),
        searchController = TextEditingController();

  String? selectedUnitId;
  final TextEditingController conversionRateController;
  final TextEditingController barcodeController;
  final TextEditingController priceController;
  final TextEditingController searchController;
  bool isGeneratingBarcode = false;

  void dispose() {
    conversionRateController.dispose();
    barcodeController.dispose();
    priceController.dispose();
    searchController.dispose();
  }
}

class AddProductWithBarcodeModal extends StatefulWidget {
  final String? barcode;
  final bool isAddToCart;

  const AddProductWithBarcodeModal(
      {Key? key, this.barcode, this.isAddToCart = false})
      : super(key: key);

  @override
  State<AddProductWithBarcodeModal> createState() =>
      _AddProductWithBarcodeModalState();
}

class _AddProductWithBarcodeModalState
    extends State<AddProductWithBarcodeModal> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>(); // Step 1
  final TextEditingController _productBarcodeController =
      TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productMRPController = TextEditingController();
  final TextEditingController _productQuantityController =
      TextEditingController();
  final TextEditingController _productSellingPriceController =
      TextEditingController();
  final TextEditingController _productPurchasePriceController =
      TextEditingController();
  final TextEditingController _productItemCodeController =
      TextEditingController();
  final TextEditingController _productMinMarginController =
      TextEditingController();
  final TextEditingController _productMinMarginPriceController =
      TextEditingController();
  final TextEditingController _unitSearchController = TextEditingController();
  final TextEditingController _categorySearchController =
      TextEditingController();
  final TextEditingController _baseConversionRateController =
      TextEditingController(text: '1');
  final Map<int, TextEditingController> _languageNameControllers = {};
  final Map<int, bool> _languageTranslating = {};
  final Map<int, FocusNode> _translateButtonFocusNodes = {};
  bool _languagesRequested = false;

  // Focus nodes for each text field
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _productNameFocusNode = FocusNode();
  final FocusNode _mrpFocusNode = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();
  final FocusNode _sellingPriceFocusNode = FocusNode();
  final FocusNode _purchasePriceFocusNode = FocusNode();
  final FocusNode _itemCodeFocusNode = FocusNode();
  final FocusNode _minMarginFocusNode = FocusNode();
  final FocusNode _minMarginPriceFocusNode = FocusNode();
  final FocusNode _unitFocusNode = FocusNode();
  final FocusNode _categoryFocusNode = FocusNode();
  final FocusNode _generateBarcodeFocusNode = FocusNode();

  bool isLoading = false;
  bool isSaveAndCreateLoading = false;
  bool isBarcodeGenerating = false;
  bool _isCheckingDuplicateBarcode = false;
  String? _confirmedDuplicateBarcode;
  String? selectedUnit;
  Category? selectedCategory;
  bool isValidatedOnce = false;
  bool _showAdvancedOptions = false;
  bool _showSaleUnitValidation = false;
  final List<_SaleUnitFormRow> _saleUnitRows = [];

  final VariantEditorController _variantController = VariantEditorController();
  bool _variantPropertiesRequested = false;
  bool _isLoadingVariantProperties = false;

  @override
  void initState() {
    if (widget.barcode != null) {
      _productBarcodeController.text = widget.barcode!;
    }

    // Set default quantity value to 0 when opening the modal
    _productQuantityController.text = '0';
    super.initState();

    _barcodeFocusNode.addListener(_handleBarcodeFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _productNameFocusNode.requestFocus();
      }
      _fetchLanguages();
      _fetchVariantProperties();
    });
  }

  Future<void> _fetchVariantProperties() async {
    if (_variantPropertiesRequested) return;
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    if (appSettings?.productVariantEnabled != true) return;
    _variantPropertiesRequested = true;

    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    if (productProvider.hasProductProperties) return;

    final accessToken =
        Provider.of<AuthModel>(context, listen: false).token ?? '';
    if (accessToken.isEmpty) return;

    setState(() => _isLoadingVariantProperties = true);
    try {
      await productProvider.fetchProductProperties(accessToken: accessToken);
    } catch (e) {
      debugPrint('⚠️ fetchProductProperties failed: $e');
    } finally {
      if (mounted) setState(() => _isLoadingVariantProperties = false);
    }
  }

  void _retryFetchVariantProperties() {
    _variantPropertiesRequested = false;
    _fetchVariantProperties();
  }

  // Helper method to unfocus all text fields except the specified one
  void _unfocusAllExcept(FocusNode? keepFocused) {
    final allFocusNodes = [
      _barcodeFocusNode,
      _productNameFocusNode,
      _mrpFocusNode,
      _quantityFocusNode,
      _sellingPriceFocusNode,
      _purchasePriceFocusNode,
      _itemCodeFocusNode,
      _minMarginFocusNode,
      _minMarginPriceFocusNode,
      _unitFocusNode,
      _categoryFocusNode,
    ];

    for (final node in allFocusNodes) {
      if (node != keepFocused && node.hasFocus) {
        node.unfocus();
      }
    }
  }

  void _handleBarcodeFocusChange() {
    if (!_barcodeFocusNode.hasFocus) {
      _ensureBarcodeDuplicateConfirmed();
    }
  }

  List<GetProduct> _findExistingProductsByBarcode(String barcode) {
    final trimmedBarcode = barcode.trim();
    if (trimmedBarcode.isEmpty) {
      return const <GetProduct>[];
    }

    return Provider.of<LocalProductProvider>(context, listen: false)
        .filterProductByBarcode(barCode: trimmedBarcode);
  }

  Future<bool> _ensureBarcodeDuplicateConfirmed() async {
    final barcode = _productBarcodeController.text.trim();
    if (barcode.isEmpty) {
      _confirmedDuplicateBarcode = null;
      return true;
    }

    if (_confirmedDuplicateBarcode == barcode || _isCheckingDuplicateBarcode) {
      return true;
    }

    final existingProducts = _findExistingProductsByBarcode(barcode);
    if (existingProducts.isEmpty) {
      _confirmedDuplicateBarcode = null;
      return true;
    }

    _isCheckingDuplicateBarcode = true;
    try {
      final selectedProduct = await _showDuplicateBarcodeDialog(
        barcode: barcode,
        existingProducts: existingProducts,
      );

      if (!mounted) {
        return false;
      }

      if (selectedProduct != null) {
        _fillFormFromExistingProduct(selectedProduct);
        setState(() {
          _confirmedDuplicateBarcode = barcode;
        });
        return true;
      }

      setState(() {
        _productBarcodeController.clear();
        _confirmedDuplicateBarcode = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _barcodeFocusNode.requestFocus();
        }
      });
      return false;
    } finally {
      _isCheckingDuplicateBarcode = false;
    }
  }

  Future<GetProduct?> _showDuplicateBarcodeDialog({
    required String barcode,
    required List<GetProduct> existingProducts,
  }) async {
    final result = await showDialog<GetProduct>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;
        GetProduct selectedProduct = existingProducts.first;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: size.width * 0.55,
              maxHeight: size.height * 0.7,
            ),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'product_form.duplicate_barcode_title'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s20,
                              0.30,
                              ColorManager.textColor,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black54),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'product_form.duplicate_barcode_message'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s13,
                        0.27,
                        ColorManager.textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'product_form.barcode_value_label'.tr.replaceAll('@barcode', barcode),
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s12,
                        0.27,
                        Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'product_form.select_product_copy_hint'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s11,
                        0.27,
                        Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: existingProducts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final product = existingProducts[index];
                          return _buildExistingProductCard(
                            product,
                            isSelected: identical(product, selectedProduct),
                            onTap: () {
                              setDialogState(() {
                                selectedProduct = product;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 110,
                          height: 40,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              side:
                                  BorderSide(color: ColorManager.kPrimaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'general.cancel'.tr,
                              style: TextStyle(
                                color: ColorManager.kPrimaryColor,
                                fontSize: FontSize.s12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 130,
                          height: 40,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(dialogContext)
                                .pop(selectedProduct),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorManager.kPrimaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'product_form.continue_btn'.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: FontSize.s12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    return result;
  }

  Widget _buildExistingProductCard(
    GetProduct product, {
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    final categoryName = product.category?.name?.trim();
    final sellingPrice = product.price?.price?.toString().trim();
    final mrp = product.mrp?.toString().trim();
    final unit = product.unit?.trim();
    final availableQuantity = _getAvailableQuantity(product);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? ColorManager.kPrimaryColor.withOpacity(0.08)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? ColorManager.kPrimaryColor
                  : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.productName?.trim().isNotEmpty == true
                          ? product.productName!.trim()
                          : 'product_form.unnamed_product'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.27,
                        ColorManager.textColor,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: ColorManager.kPrimaryColor,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                runSpacing: 8,
                spacing: 14,
                children: [
                  _buildProductDetailItem('product.barcode'.tr, product.barcode ?? '-'),
                  _buildProductDetailItem(
                      'product.category'.tr,
                      categoryName != null && categoryName.isNotEmpty
                          ? categoryName
                          : '-'),
                  _buildProductDetailItem(
                      'product_form.selling_price'.tr,
                      sellingPrice != null && sellingPrice.isNotEmpty
                          ? sellingPrice
                          : '-'),
                  _buildProductDetailItem(
                      'product.mrp'.tr, mrp != null && mrp.isNotEmpty ? mrp : '-'),
                  _buildProductDetailItem(
                      'product.unit'.tr, unit != null && unit.isNotEmpty ? unit : '-'),
                  _buildProductDetailItem('product_form.available_qty'.tr, availableQuantity),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductDetailItem(String label, String value) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s11,
              0.27,
              Colors.black54,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getAvailableQuantity(GetProduct product) {
    final stockQuantity = product.stock?.fold<num>(
      0,
      (sum, stock) => sum + (stock.quantity ?? 0),
    );

    if (stockQuantity != null && stockQuantity > 0) {
      return stockQuantity % 1 == 0
          ? stockQuantity.toInt().toString()
          : stockQuantity.toString();
    }

    final available = product.numberOfProductsAvailable?.trim();
    if (available != null && available.isNotEmpty) {
      return available;
    }

    return '-';
  }

  void _fillFormFromExistingProduct(GetProduct product) {
    final resolvedUnit = _resolveUnitValue(product.unit);
    final resolvedCategory = _resolveCategory(product);
    final resolvedQuantity = _getAutofillQuantity(product);
    final resolvedSellingPrice = _formatDynamicNumber(product.price?.price);
    final resolvedMrp = _formatDynamicNumber(product.mrp);
    final resolvedPurchasePrice = _formatDynamicNumber(product.purchasePrice);

    setState(() {
      _productNameController.text = product.productName?.trim() ?? '';
      _productBarcodeController.text = product.barcode?.trim() ?? '';
      _productItemCodeController.text = product.itemCode?.trim() ?? '';
      _productSellingPriceController.text = resolvedSellingPrice;
      _productMRPController.text = resolvedMrp;
      _productPurchasePriceController.text = resolvedPurchasePrice;
      _productQuantityController.text = resolvedQuantity;
      selectedUnit = resolvedUnit;
      selectedCategory = resolvedCategory;
    });

    _syncLanguageControllersFromProduct(product);
    _syncSaleUnitsFromProduct(product);
  }

  Category? _resolveCategory(GetProduct product) {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final categories = categoryProvider.category ?? const <Category>[];

    if (product.categoryId != null) {
      for (final category in categories) {
        if (category.categoryId == product.categoryId) {
          return category;
        }
      }
    }

    final productCategoryName = product.category?.name?.trim().toLowerCase();
    if (productCategoryName != null && productCategoryName.isNotEmpty) {
      for (final category in categories) {
        if (category.categoryName?.trim().toLowerCase() ==
            productCategoryName) {
          return category;
        }
      }
    }

    return null;
  }

  String? _resolveUnitValue(String? unit) {
    final trimmedUnit = unit?.trim();
    if (trimmedUnit == null || trimmedUnit.isEmpty) {
      return null;
    }

    final purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    final unitList = purchaseProvider.getUnitList ?? const <String, String>{};

    if (unitList.containsKey(trimmedUnit)) {
      return trimmedUnit;
    }

    final normalizedUnit = trimmedUnit.toLowerCase();
    for (final entry in unitList.entries) {
      if (entry.key.toLowerCase() == normalizedUnit ||
          entry.value.toLowerCase() == normalizedUnit) {
        return entry.key;
      }
    }

    return trimmedUnit;
  }

  String _getAutofillQuantity(GetProduct product) {
    final stockQuantity = product.stock?.fold<num>(
      0,
      (sum, stock) => sum + (stock.quantity ?? 0),
    );

    if (stockQuantity != null && stockQuantity > 0) {
      return _formatNum(stockQuantity);
    }

    final available = product.numberOfProductsAvailable?.trim();
    if (available != null && available.isNotEmpty) {
      return available;
    }

    return '0';
  }

  String _formatDynamicNumber(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is num) {
      return _formatNum(value);
    }

    final text = value.toString().trim();
    if (text.isEmpty) {
      return '';
    }

    final parsed = num.tryParse(text);
    return parsed != null ? _formatNum(parsed) : text;
  }

  String _formatNum(num value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  String _extractTranslatedName(dynamic names, Language language) {
    if (names == null) return '';
    final targetCode = language.code.toLowerCase();

    if (names is Map) {
      final direct = names[targetCode] ?? names[language.code];
      if (direct != null) {
        if (direct is String) return direct;
        if (direct is Map) {
          final fromMap = direct['name'] ?? direct['value'];
          if (fromMap != null) return fromMap.toString();
        }
      }

      for (final value in names.values) {
        if (value is Map) {
          final code = value['code']?.toString().toLowerCase() ??
              value['language_code']?.toString().toLowerCase();
          final languageId = value['language_id']?.toString();
          if (code == targetCode || languageId == language.id.toString()) {
            final name = value['name'] ?? value['value'];
            if (name != null) return name.toString();
          }
        }
      }
    }

    if (names is List) {
      for (final value in names) {
        if (value is Map) {
          final code = value['code']?.toString().toLowerCase() ??
              value['language_code']?.toString().toLowerCase();
          final languageId = value['language_id']?.toString();
          if (code == targetCode || languageId == language.id.toString()) {
            final name = value['name'] ?? value['value'];
            if (name != null) return name.toString();
          }
        }
      }
    }

    return '';
  }

  void _syncLanguageControllersFromProduct(GetProduct product) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final activeLanguages = languageProvider.languages
        .where((language) => language.active)
        .toList(growable: false);
    final baseLanguage = _getBaseLanguage(activeLanguages);

    _syncLanguageControllers(activeLanguages, baseLanguage);

    for (final language in activeLanguages) {
      if (baseLanguage != null && language.id == baseLanguage.id) {
        continue;
      }

      final translatedName = _extractTranslatedName(product.names, language);
      _languageNameControllers[language.id]?.text = translatedName;
      _languageTranslating.putIfAbsent(language.id, () => false);
    }
  }

  void _clearSaleUnitRows() {
    for (final row in _saleUnitRows) {
      row.dispose();
    }
    _saleUnitRows.clear();
  }

  void _syncSaleUnitsFromProduct(GetProduct product) {
    _clearSaleUnitRows();

    final saleUnits = (product.saleUnits ?? const <SaleUnit>[])
        .where((saleUnit) => saleUnit.unitId?.toString() != selectedUnit)
        .toList(growable: false);
    for (final saleUnit in saleUnits) {
      _saleUnitRows.add(
        _SaleUnitFormRow(
          selectedUnitId: saleUnit.unitId?.toString(),
          conversionRate: saleUnit.conversionRate ?? '',
          barcode: saleUnit.barcode ?? '',
          price: saleUnit.price?.toString() ?? '',
        ),
      );
    }

    setState(() {
      _showAdvancedOptions = saleUnits.isNotEmpty;
      _showSaleUnitValidation = false;
    });
  }

  String _resolveUnitLabel(String? unitId, Map<String, String>? unitList) {
    if (unitId == null || unitId.isEmpty) {
      return 'product_sale_unit.select_unit_hint'.tr;
    }
    return unitList?[unitId] ?? unitId;
  }

  void _handleBaseUnitChange(String? newValue) {
    setState(() {
      selectedUnit = newValue;
      for (final row in _saleUnitRows) {
        if (row.selectedUnitId == newValue) {
          row.selectedUnitId = null;
        }
      }
    });
  }

  void _toggleAdvancedOptions(bool enabled) {
    setState(() {
      _showAdvancedOptions = enabled;
      if (!enabled) {
        _showSaleUnitValidation = false;
        _clearSaleUnitRows();
      }
    });
  }

  void _addSaleUnitRow() {
    setState(() {
      _saleUnitRows.add(_SaleUnitFormRow(conversionRate: '1'));
    });
  }

  void _removeSaleUnitRow(int index) {
    final row = _saleUnitRows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  Future<void> _generateBarcodeIntoController(
    TextEditingController controller, {
    void Function(bool value)? onLoadingChanged,
  }) async {
    onLoadingChanged?.call(true);
    setState(() {});

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'product_form.auth_token_missing'.tr,
        );
        return;
      }

      GridSelectionProvider gridSelectionProvider =
          Provider.of<GridSelectionProvider>(context, listen: false);

      final Map<String, dynamic>? result = await gridSelectionProvider
          .generateBarcodeAPI(accessToken: accessToken);

      if (!mounted) {
        return;
      }

      if (result != null &&
          result['status'] == 'success' &&
          result['data'] != null) {
        final String generatedBarcode = result['data']['barcode'];
        final resolvedBarcode = _getNextAvailableBarcode(
          generatedBarcode,
          excludeController: controller,
        );
        final wasAdjusted = resolvedBarcode != generatedBarcode;

        setState(() {
          controller.text = resolvedBarcode;
        });

        showScaffold(
          context: context,
          message: wasAdjusted
              ? 'product_form.barcode_generated_incremented'.tr
              : 'product_form.barcode_generated_success'.tr,
        );
      } else {
        showScaffoldError(
          context: context,
          message: result?['message'] ?? 'product_form.failed_generate_barcode'.tr,
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'product_form.error_generating_barcode'.tr.replaceAll('@error', e.toString()),
      );
    } finally {
      onLoadingChanged?.call(false);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Set<String> _collectCurrentFormBarcodes({
    TextEditingController? excludeController,
  }) {
    final usedBarcodes = <String>{};

    void addBarcode(String? value, TextEditingController controller) {
      if (excludeController != null &&
          identical(controller, excludeController)) {
        return;
      }
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        usedBarcodes.add(trimmed);
      }
    }

    addBarcode(_productBarcodeController.text, _productBarcodeController);
    for (final row in _saleUnitRows) {
      addBarcode(row.barcodeController.text, row.barcodeController);
    }
    for (final row in _variantController.rows) {
      addBarcode(row.barcodeController.text, row.barcodeController);
    }

    return usedBarcodes;
  }

  bool _barcodeExistsInLocalProducts(String barcode) {
    final normalized = barcode.trim();
    if (normalized.isEmpty) {
      return false;
    }

    return Provider.of<LocalProductProvider>(context, listen: false)
        .filterProductByBarcode(barCode: normalized)
        .isNotEmpty;
  }

  String _incrementBarcodeString(String barcode, int step) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      final nextValue = BigInt.parse(trimmed) + BigInt.from(step);
      final nextText = nextValue.toString();
      return nextText.length < trimmed.length
          ? nextText.padLeft(trimmed.length, '0')
          : nextText;
    }

    return '$trimmed-$step';
  }

  String _getNextAvailableBarcode(
    String seedBarcode, {
    TextEditingController? excludeController,
  }) {
    final seed = seedBarcode.trim();
    if (seed.isEmpty) {
      return seedBarcode;
    }

    final currentFormBarcodes =
        _collectCurrentFormBarcodes(excludeController: excludeController);

    bool isTaken(String candidate) {
      return currentFormBarcodes.contains(candidate) ||
          _barcodeExistsInLocalProducts(candidate);
    }

    if (!isTaken(seed)) {
      return seed;
    }

    for (int step = 1; step <= 9999; step++) {
      final candidate = _incrementBarcodeString(seed, step);
      if (!isTaken(candidate)) {
        return candidate;
      }
    }

    return '${seed}_${DateTime.now().millisecondsSinceEpoch}';
  }

  bool _validateSaleUnits() {
    if (!_showAdvancedOptions || selectedUnit == null) {
      return true;
    }

    final usedUnitIds = <String>{selectedUnit!};
    final usedBarcodes = <String>{_productBarcodeController.text.trim()};

    for (final row in _saleUnitRows) {
      final unitId = row.selectedUnitId?.trim();
      final conversionRate = row.conversionRateController.text.trim();
      final barcode = row.barcodeController.text.trim();

      if (unitId == null || unitId.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'product_form.select_unit_every_row'.tr,
        );
        return false;
      }

      if (usedUnitIds.contains(unitId)) {
        showScaffoldError(
          context: context,
          message: 'product_form.unique_unit_per_row'.tr,
        );
        return false;
      }
      usedUnitIds.add(unitId);

      if (conversionRate.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'product_form.enter_conversion_rate_every'.tr,
        );
        return false;
      }

      final parsedRate = num.tryParse(conversionRate);
      if (parsedRate == null || parsedRate <= 0) {
        showScaffoldError(
          context: context,
          message: 'product_form.conversion_rate_must_be_positive'.tr,
        );
        return false;
      }

      if (barcode.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'product_form.enter_or_generate_barcode_every'.tr,
        );
        return false;
      }

      if (usedBarcodes.contains(barcode)) {
        showScaffoldError(
          context: context,
          message: 'product_form.barcodes_must_be_unique'.tr,
        );
        return false;
      }
      usedBarcodes.add(barcode);

      final price = row.priceController.text.trim();
      if (price.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'product_form.enter_price_every'.tr,
        );
        return false;
      }

      final parsedPrice = num.tryParse(price);
      if (parsedPrice == null || parsedPrice <= 0) {
        showScaffoldError(
          context: context,
          message: 'product_form.price_must_be_positive'.tr,
        );
        return false;
      }
    }

    return true;
  }

  List<Map<String, dynamic>> _buildSaleUnitsPayload() {
    if (!_showAdvancedOptions ||
        selectedUnit == null ||
        _saleUnitRows.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    return _saleUnitRows
        .map((row) => {
              'unit_id':
                  int.tryParse(row.selectedUnitId ?? '') ?? row.selectedUnitId,
              'conversion_rate':
                  num.parse(row.conversionRateController.text.trim()),
              'barcode': row.barcodeController.text.trim(),
              'price': num.parse(row.priceController.text.trim()),
            })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _productBarcodeController.dispose();
    _productNameController.dispose();
    _productMRPController.dispose();
    _productQuantityController.dispose();
    _productSellingPriceController.dispose();
    _productPurchasePriceController.dispose();
    _productItemCodeController.dispose();
    _productMinMarginController.dispose();
    _productMinMarginPriceController.dispose();
    _unitSearchController.dispose();
    _categorySearchController.dispose();
    _baseConversionRateController.dispose();

    for (final controller in _languageNameControllers.values) {
      if (controller != _productNameController) {
        controller.dispose();
      }
    }
    _languageNameControllers.clear();
    _languageTranslating.clear();
    _clearSaleUnitRows();
    _variantController.dispose();
    for (final node in _translateButtonFocusNodes.values) {
      node.dispose();
    }
    _translateButtonFocusNodes.clear();

    // Dispose focus nodes
    _barcodeFocusNode.dispose();
    _productNameFocusNode.dispose();
    _mrpFocusNode.dispose();
    _quantityFocusNode.dispose();
    _sellingPriceFocusNode.dispose();
    _purchasePriceFocusNode.dispose();
    _itemCodeFocusNode.dispose();
    _minMarginFocusNode.dispose();
    _minMarginPriceFocusNode.dispose();
    _unitFocusNode.dispose();
    _categoryFocusNode.dispose();
    _generateBarcodeFocusNode.dispose();

    isLoading = false;
    isSaveAndCreateLoading = false;
    selectedUnit = null;
    selectedCategory = null;
    isValidatedOnce = false;
    super.dispose();
  }

  Future<void> _fetchLanguages() async {
    if (_languagesRequested) return;
    _languagesRequested = true;

    final accessToken =
        Provider.of<AuthModel>(context, listen: false).token ?? '';
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    await languageProvider.fetchLanguages(accessToken: accessToken);

    if (!mounted) return;
    if (languageProvider.error != null) {
      showScaffoldError(
        context: context,
        message: languageProvider.error!,
      );
    }
  }

  void _retryFetchLanguages() {
    _languagesRequested = false;
    _fetchLanguages();
  }

  Language? _getBaseLanguage(List<Language> languages) {
    if (languages.isEmpty) return null;

    try {
      return languages.firstWhere((lang) => lang.code.toLowerCase() == 'en');
    } catch (_) {
      return languages.first;
    }
  }

  void _syncLanguageControllers(
    List<Language> languages,
    Language? baseLanguage,
  ) {
    for (final language in languages) {
      if (!_languageNameControllers.containsKey(language.id)) {
        if (baseLanguage != null && language.id == baseLanguage.id) {
          _languageNameControllers[language.id] = _productNameController;
        } else {
          _languageNameControllers[language.id] = TextEditingController();
        }
      }
      _languageTranslating.putIfAbsent(language.id, () => false);
      _translateButtonFocusNodes.putIfAbsent(language.id, () => FocusNode());
    }
  }

  ButtonStyle _buildSquareActionButtonStyle() {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.all(ColorManager.kPrimaryColor),
      foregroundColor: WidgetStateProperty.all(Colors.white),
      padding: WidgetStateProperty.all(EdgeInsets.zero),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      elevation: WidgetStateProperty.resolveWith<double>(
        (states) => states.contains(WidgetState.focused) ? 9 : 4,
      ),
      shadowColor: WidgetStateProperty.resolveWith<Color>(
        (states) => states.contains(WidgetState.focused)
            ? ColorManager.kPrimaryColor.withOpacity(0.45)
            : Colors.black.withOpacity(0.18),
      ),
      side: WidgetStateProperty.resolveWith<BorderSide>(
        (states) => states.contains(WidgetState.focused)
            ? BorderSide(
                color: Colors.white.withOpacity(0.9),
                width: 1.2,
              )
            : BorderSide.none,
      ),
    );
  }

  Future<void> _translateLanguage(Language language) async {
    final baseText = _productNameController.text.trim();
    if (baseText.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'product_form.enter_name_before_translate'.tr,
      );
      return;
    }

    if (_languageTranslating[language.id] == true) return;

    setState(() {
      _languageTranslating[language.id] = true;
    });

    final accessToken =
        Provider.of<AuthModel>(context, listen: false).token ?? '';
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    final translated = await languageProvider.translateText(
      accessToken: accessToken,
      targetLang: language.code,
      text: baseText,
    );

    if (!mounted) return;

    if (translated != null && translated.isNotEmpty) {
      _languageNameControllers[language.id]?.text = translated;
      showScaffold(
        context: context,
        message: 'product_form.translated_to'.tr.replaceAll('@language', language.name),
      );
    } else {
      showScaffoldError(
        context: context,
        message: 'product_form.translation_failed'.tr,
      );
    }

    if (mounted) {
      setState(() {
        _languageTranslating[language.id] = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _translateButtonFocusNodes[language.id]?.requestFocus();
        }
      });
    }
  }

  Future<void> generateBarcode() async {
    if (isBarcodeGenerating) return;

    setState(() {
      isBarcodeGenerating = true;
    });

    await _generateBarcodeIntoController(
      _productBarcodeController,
      onLoadingChanged: (value) => isBarcodeGenerating = value,
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final multiSaleUnitEnabled = context
            .watch<AppSettingsProvider>()
            .appSettings
            ?.multiSaleUnitEnabled ??
        false;
    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    Map<String, String>? unitList = purchaseProvider.getUnitList;

    CategoryProvider categoryProvider = Provider.of<CategoryProvider>(
      context,
    );
    List<Category>? categoryList = categoryProvider.category;

    final languageProvider = Provider.of<LanguageProvider>(context);
    return Focus(
      autofocus: false,
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (!isLoading && !isSaveAndCreateLoading) {
            Navigator.pop(context, null);
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.f4) {
          if (!isLoading && !isSaveAndCreateLoading) {
            Navigator.pop(context, null);
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.f8) {
          if (!isLoading && !isSaveAndCreateLoading) {
            _submitForm(keepOpen: true);
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.f9) {
          if (!isLoading && !isSaveAndCreateLoading) {
            _submitForm(keepOpen: false);
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: size.width > 1100 ? 1050 : size.width * 0.92,
              maxHeight: MediaQuery.of(context).size.height * 0.88),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'product_form.title'.tr,
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s20,
                            0.30,
                            ColorManager.textColor,
                          ),
                        ),
                      ),
                      if (multiSaleUnitEnabled)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'product_form.advanced'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.medium,
                                FontSize.s12,
                                0.27,
                                Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Switch(
                              value: _showAdvancedOptions,
                              activeThumbColor: ColorManager.kPrimaryColor,
                              onChanged: _toggleAdvancedOptions,
                            ),
                          ],
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  Text(
                    widget.barcode != null
                        ? 'product_form.no_product_found_barcode'.tr.replaceAll('@barcode', '${widget.barcode}')
                        : 'product_form.subtitle'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s12,
                      0.27,
                      Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Row 1: Product Name, Barcode, Category
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'product.product_name'.tr,
                          _productNameController,
                          TextInputType.text,
                          size,
                          isRequired: true,
                          focusNode: _productNameFocusNode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildBarcodeField(size),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCategoryDropdown(size, categoryList),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildLanguageFields(size, languageProvider),
                  const SizedBox(height: 12),

                  // Row 2: Unit, Purchase Price, Max Sale Price / MRP
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildUnitDropdown(size, unitList),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextField(
                          'product.purchase_price'.tr,
                          _productPurchasePriceController,
                          TextInputType.number,
                          size,
                          isRequired: true,
                          inputFormatter: FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$')),
                          focusNode: _purchasePriceFocusNode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextField(
                          'product_form.max_sale_price_mrp'.tr,
                          _productMRPController,
                          TextInputType.number,
                          size,
                          isRequired: false,
                          inputFormatter: FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$')),
                          focusNode: _mrpFocusNode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 3: Selling Price, Quantity, Item Code (conditional)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'product_form.selling_price'.tr,
                          _productSellingPriceController,
                          TextInputType.number,
                          size,
                          isRequired: true,
                          inputFormatter: FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$')),
                          focusNode: _sellingPriceFocusNode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextField(
                          'product_form.quantity'.tr,
                          _productQuantityController,
                          TextInputType.number,
                          size,
                          isRequired: true,
                          inputFormatter: FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$')),
                          focusNode: _quantityFocusNode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Consumer<AppSettingsProvider>(
                          builder: (context, appSettingsProvider, child) {
                            final itemCodeEnabled = appSettingsProvider
                                    .appSettings?.itemCodeEnabled ??
                                false;
                            if (!itemCodeEnabled) {
                              return const SizedBox.shrink();
                            }
                            return _buildTextField(
                              'product.item_code'.tr,
                              _productItemCodeController,
                              TextInputType.text,
                              size,
                              isRequired: false,
                              focusNode: _itemCodeFocusNode,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 4: Min Margin Percentage / Min Margin Price (optional)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'product_form.max_discount_percentage'.tr,
                          _productMinMarginController,
                          TextInputType.number,
                          size,
                          isRequired: false,
                          inputFormatter: FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$')),
                          focusNode: _minMarginFocusNode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextField(
                          'product_form.max_discount_amount'.tr,
                          _productMinMarginPriceController,
                          TextInputType.number,
                          size,
                          isRequired: false,
                          inputFormatter: FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$')),
                          focusNode: _minMarginPriceFocusNode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (multiSaleUnitEnabled && _showAdvancedOptions) ...[
                    _buildAdvancedOptionsSection(size, unitList),
                    const SizedBox(height: 20),
                  ],
                  _buildVariantsSection(),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Close Button
                      SizedBox(
                        width: 115,
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, null),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: ColorManager.kPrimaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'product_form.close'.tr,
                                style: TextStyle(
                                  color: ColorManager.kPrimaryColor,
                                  fontSize: FontSize.s12,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: ColorManager.kPrimaryColor
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  'F4',
                                  style: TextStyle(
                                    color: ColorManager.kPrimaryColor
                                        .withOpacity(0.7),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Save and Create Button
                      SizedBox(
                        width: 172,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: (isLoading || isSaveAndCreateLoading)
                              ? null
                              : () => _submitForm(keepOpen: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: ColorManager.kPrimaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isSaveAndCreateLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        ColorManager.kPrimaryColor),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'product_form.save_and_create'.tr,
                                      style: TextStyle(
                                        color: ColorManager.kPrimaryColor,
                                        fontSize: FontSize.s12,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: ColorManager.kPrimaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        'F8',
                                        style: TextStyle(
                                          color: ColorManager.kPrimaryColor
                                              .withOpacity(0.7),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Add Product Button
                      SizedBox(
                        width: 120,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: (isLoading || isSaveAndCreateLoading)
                              ? null
                              : () => _submitForm(keepOpen: false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorManager.kPrimaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'general.save'.tr,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: FontSize.s12,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text(
                                        'F9',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ), // Dialog
    ); // Focus
  }

  // Helper method for text fields
  Widget _buildTextField(
    String title,
    TextEditingController controller,
    TextInputType keyboardType,
    Size size, {
    bool isRequired = false,
    TextInputFormatter? inputFormatter,
    FocusNode? focusNode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: title,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              if (isRequired)
                TextSpan(
                  text: ' *',
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
                    0.27,
                    Colors.red,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        CustomBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.only(left: 12),
          height: size.height * 0.048,
          width: double.infinity,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            autofocus: focusNode == _productNameFocusNode,
            keyboardType: keyboardType,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
            inputFormatters: inputFormatter != null ? [inputFormatter] : null,
            cursorColor: ColorManager.kPrimaryColor,
            onTap: () {
              if (focusNode != null) {
                _unfocusAllExcept(focusNode);
              }
            },
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            validator: isRequired
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return 'product_form.required'.tr;
                    }
                    return null;
                  }
                : null,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s11,
              0.27,
              ColorManager.textColor.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }

  // Barcode field with generate button
  Widget _buildBarcodeField(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'product.barcode'.tr,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              TextSpan(
                text: ' *',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: CustomBoxShadowContainer(
                circleRadius: 7,
                alignment: Alignment.centerLeft,
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.only(left: 12),
                height: size.height * 0.048,
                width: double.infinity,
                child: TextFormField(
                  controller: _productBarcodeController,
                  focusNode: _barcodeFocusNode,
                  readOnly: widget.barcode != null,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    if (_confirmedDuplicateBarcode != null) {
                      setState(() {
                        _confirmedDuplicateBarcode = null;
                      });
                    }
                  },
                  onFieldSubmitted: (_) async {
                    final canContinue =
                        await _ensureBarcodeDuplicateConfirmed();
                    if (!mounted || !canContinue) {
                      return;
                    }
                    FocusScope.of(context).nextFocus();
                  },
                  cursorColor: ColorManager.kPrimaryColor,
                  onTap: () {
                    _unfocusAllExcept(_barcodeFocusNode);
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'product_form.required'.tr;
                    }
                    return null;
                  },
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.27,
                    ColorManager.textColor.withOpacity(0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: size.height * 0.048,
              width: size.height * 0.048,
              child: ElevatedButton(
                focusNode: _generateBarcodeFocusNode,
                onPressed: widget.barcode != null
                    ? null
                    : () async {
                        _unfocusAllExcept(null);
                        _generateBarcodeFocusNode.requestFocus();
                        await generateBarcode();
                        if (mounted) {
                          _generateBarcodeFocusNode.requestFocus();
                        }
                      },
                style: _buildSquareActionButtonStyle(),
                child: isBarcodeGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageFields(
    Size size,
    LanguageProvider languageProvider,
  ) {
    if (languageProvider.isLoading && languageProvider.languages.isEmpty) {
      return Row(
        children: [
          const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'product_form.loading_languages'.tr,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s11,
              0.27,
              Colors.black.withOpacity(0.6),
            ),
          ),
        ],
      );
    }

    if (languageProvider.error != null && languageProvider.languages.isEmpty) {
      return Row(
        children: [
          Expanded(
            child: Text(
              languageProvider.error!,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s11,
                0.27,
                Colors.red[700]!,
              ),
            ),
          ),
          TextButton(
            onPressed: _retryFetchLanguages,
            child: Text('product_form.retry'.tr),
          ),
        ],
      );
    }

    final languages = languageProvider.languages
        .where((lang) => lang.active)
        .toList(growable: false);
    if (languages.isEmpty) {
      return const SizedBox.shrink();
    }

    final baseLanguage = _getBaseLanguage(languages);
    _syncLanguageControllers(languages, baseLanguage);

    final List<Widget> fields = [];
    for (final language in languages) {
      if (baseLanguage != null && language.id == baseLanguage.id) {
        continue;
      }
      fields.add(_buildLanguageField(size, language));
      fields.add(const SizedBox(height: 12));
    }

    if (fields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'product_form.other_language_names'.tr,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.27,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 6),
        ...fields,
      ],
    );
  }

  Widget _buildLanguageField(Size size, Language language) {
    final controller = _languageNameControllers[language.id];
    final isTranslating = _languageTranslating[language.id] ?? false;
    final translateFocusNode = _translateButtonFocusNodes[language.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'product_form.product_name_in_language'.tr.replaceAll('@language', language.name),
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: CustomBoxShadowContainer(
                circleRadius: 7,
                alignment: Alignment.centerLeft,
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.only(left: 12),
                height: size.height * 0.048,
                width: double.infinity,
                child: TextFormField(
                  controller: controller,
                  textDirection:
                      language.isRtl ? TextDirection.rtl : TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  cursorColor: ColorManager.kPrimaryColor,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.27,
                    ColorManager.textColor.withOpacity(0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: size.height * 0.048,
              width: size.height * 0.048,
              child: Tooltip(
                message: 'product_form.translate_tooltip'.tr,
                child: ElevatedButton(
                  focusNode: translateFocusNode,
                  onPressed:
                      isTranslating ? null : () => _translateLanguage(language),
                  style: _buildSquareActionButtonStyle(),
                  child: isTranslating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.translate,
                          size: 18,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _buildProductNamesPayload(
      List<Language> languages) {
    final payload = <Map<String, dynamic>>[];

    for (final language in languages) {
      final controller = _languageNameControllers[language.id];
      final text = controller?.text.trim() ?? '';
      if (text.isNotEmpty) {
        payload.add({
          'language_id': language.id,
          'name': text,
        });
      }
    }

    return payload;
  }

  // Unit dropdown
  Widget _buildUnitDropdown(Size size, Map<String, String>? unitList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'product_form.product_unit'.tr,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              TextSpan(
                text: ' *',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        CustomDropDownWithSearch<String>(
          focusNode: _unitFocusNode,
          title: "",
          hintText: 'product_form.choose_product_unit'.tr,
          value: selectedUnit,
          height: size.height * 0.048,
          margin: EdgeInsets.zero,
          items: unitList?.entries.map((entry) => entry.key).toList() ?? [],
          onChanged: (String? newValue) {
            _handleBaseUnitChange(newValue);
          },
          displayText: (item) => unitList?[item] ?? '',
          searchController: _unitSearchController,
        ),
        if (isValidatedOnce && selectedUnit == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'product_form.required'.tr,
              style: TextStyle(color: Colors.red[700], fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildVariantsSection() {
    return Consumer2<AppSettingsProvider, ProductProvider>(
      builder: (context, appSettingsProvider, productProvider, child) {
        final variantEnabled =
            appSettingsProvider.appSettings?.productVariantEnabled ?? false;
        if (!variantEnabled) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: VariantEditorSection(
            controller: _variantController,
            properties: productProvider.productProperties,
            isLoadingProperties: _isLoadingVariantProperties,
            onRetryLoadProperties: _retryFetchVariantProperties,
            onGenerateBarcode: (target, setLoading) =>
                _generateBarcodeIntoController(
              target,
              onLoadingChanged: setLoading,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdvancedOptionsSection(
    Size size,
    Map<String, String>? unitList,
  ) {
    final canConfigureSaleUnits = selectedUnit != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ColorManager.kPrimaryColor.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'product_sale_unit.multi_sale_unit'.tr,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s12,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'product_sale_unit.base_unit_required'.tr,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s11,
              0.27,
              Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          if (!canConfigureSaleUnits)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.35)),
              ),
              child: Text(
                'product_form.select_unit_first'.tr,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s11,
                  0.27,
                  Colors.orange.shade800,
                ),
              ),
            )
          else ...[
            _buildBaseSaleUnitCard(size, unitList),
            const SizedBox(height: 10),
            ...List.generate(
              _saleUnitRows.length,
              (index) => Padding(
                padding: EdgeInsets.only(
                  bottom: index == _saleUnitRows.length - 1 ? 0 : 10,
                ),
                child: _buildEditableSaleUnitCard(
                  size,
                  unitList,
                  _saleUnitRows[index],
                  index,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: OutlinedButton.icon(
                onPressed: _addSaleUnitRow,
                icon: const Icon(Icons.add, size: 18),
                label: Text('product_sale_unit.add_sale_unit'.tr),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorManager.kPrimaryColor,
                  side: BorderSide(color: ColorManager.kPrimaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBaseSaleUnitCard(Size size, Map<String, String>? unitList) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'product_sale_unit.base_unit_label'.tr.replaceAll('@unit', _resolveUnitLabel(selectedUnit, unitList)),
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s12,
                  0.27,
                  ColorManager.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildReadOnlyInfoField(
                  'product_sale_unit.sale_unit_label'.tr,
                  _resolveUnitLabel(selectedUnit, unitList),
                  size,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  'product_sale_unit.conversion_rate'.tr,
                  _baseConversionRateController,
                  TextInputType.number,
                  size,
                  isRequired: true,
                  inputFormatter: FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,3}$'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _productBarcodeController,
                  builder: (context, value, _) {
                    return _buildReadOnlyInfoField(
                      'product.barcode'.tr,
                      value.text.trim().isEmpty ? '-' : value.text.trim(),
                      size,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableSaleUnitCard(
    Size size,
    Map<String, String>? unitList,
    _SaleUnitFormRow row,
    int index,
  ) {
    final availableUnits = (unitList ?? const <String, String>{})
        .entries
        .where((entry) => entry.key != selectedUnit)
        .map((entry) => entry.key)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _showSaleUnitValidation &&
                  ((row.selectedUnitId?.isEmpty ?? true) ||
                      row.conversionRateController.text.trim().isEmpty ||
                      row.barcodeController.text.trim().isEmpty ||
                      row.priceController.text.trim().isEmpty)
              ? Colors.red.shade200
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'product_form.sale_unit_index'.tr.replaceAll('@n', '${index + 1}'),
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s12,
                  0.27,
                  ColorManager.textColor,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _removeSaleUnitRow(index),
                splashRadius: 18,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'product_sale_unit.sale_unit_star'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s12,
                        0.27,
                        Colors.black.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    CustomDropDownWithSearch<String>(
                      title: '',
                      hintText: 'product_sale_unit.select_unit_hint'.tr,
                      value: row.selectedUnitId,
                      height: size.height * 0.048,
                      margin: EdgeInsets.zero,
                      items: availableUnits,
                      onChanged: (String? value) {
                        setState(() {
                          row.selectedUnitId = value;
                        });
                      },
                      displayText: (item) => unitList?[item] ?? item,
                      searchController: row.searchController,
                    ),
                    if (_showSaleUnitValidation &&
                        (row.selectedUnitId == null ||
                            row.selectedUnitId!.isEmpty))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'product_form.required'.tr,
                          style:
                              TextStyle(color: Colors.red[700], fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  'product_sale_unit.conversion_rate'.tr,
                  row.conversionRateController,
                  TextInputType.number,
                  size,
                  isRequired: true,
                  inputFormatter: FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,3}$'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBarcodeEditorField(size, row),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  'product.price'.tr,
                  row.priceController,
                  TextInputType.number,
                  size,
                  isRequired: true,
                  inputFormatter: FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}$'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyInfoField(String title, String value, Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        CustomBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: size.height * 0.048,
          width: double.infinity,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s11,
                0.27,
                ColorManager.textColor.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarcodeEditorField(Size size, _SaleUnitFormRow row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'product.barcode'.tr,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              TextSpan(
                text: ' *',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: CustomBoxShadowContainer(
                circleRadius: 7,
                alignment: Alignment.centerLeft,
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.only(left: 12),
                height: size.height * 0.048,
                width: double.infinity,
                child: TextFormField(
                  controller: row.barcodeController,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  cursorColor: ColorManager.kPrimaryColor,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s11,
                    0.27,
                    ColorManager.textColor.withOpacity(0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: size.height * 0.048,
              width: size.height * 0.048,
              child: ElevatedButton(
                onPressed: row.isGeneratingBarcode
                    ? null
                    : () async {
                        await _generateBarcodeIntoController(
                          row.barcodeController,
                          onLoadingChanged: (value) =>
                              row.isGeneratingBarcode = value,
                        );
                      },
                style: _buildSquareActionButtonStyle(),
                child: row.isGeneratingBarcode
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
              ),
            ),
          ],
        ),
        if (_showSaleUnitValidation &&
            row.barcodeController.text.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'product_form.required'.tr,
              style: TextStyle(color: Colors.red[700], fontSize: 11),
            ),
          ),
      ],
    );
  }

  // Category dropdown
  Widget _buildCategoryDropdown(Size size, List<Category>? categoryList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'product_form.product_category'.tr,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.black.withOpacity(0.6),
                ),
              ),
              TextSpan(
                text: ' *',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s12,
                  0.27,
                  Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: CustomDropDownWithSearch<Category>(
                focusNode: _categoryFocusNode,
                title: "",
                hintText: 'product_form.select_category'.tr,
                value: selectedCategory,
                height: size.height * 0.048,
                margin: EdgeInsets.zero,
                items: categoryList ?? [],
                onChanged: (Category? newCategory) {
                  setState(() {
                    selectedCategory = newCategory;
                  });
                },
                displayText: (category) => category.categoryName ?? '',
                searchController: _categorySearchController,
              ),
            ),
            const SizedBox(width: 8),
            BuildBoxShadowContainer(
              height: size.height * 0.048,
              width: size.height * 0.048,
              circleRadius: 7,
              child: InkWell(
                onTap: () async {
                  final categoryProvider =
                      Provider.of<CategoryProvider>(context, listen: false);
                  final existingIds = categoryProvider.category
                          ?.map((c) => c.categoryId)
                          .toSet() ??
                      {};

                  final result = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const AddCategoryModal(),
                  );

                  if (result == true) {
                    final updatedCategories = categoryProvider.category ?? [];
                    Category? newCategory;
                    for (var c in updatedCategories) {
                      if (c.categoryId != null &&
                          !existingIds.contains(c.categoryId)) {
                        newCategory = c;
                        break;
                      }
                    }
                    if (newCategory != null) {
                      setState(() {
                        selectedCategory = newCategory;
                      });
                    }
                  }
                },
                child: const Center(
                  child: Icon(
                    Icons.add,
                    size: 20,
                    color: ColorManager.kButtonGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (isValidatedOnce && selectedCategory == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'product_form.required'.tr,
              style: TextStyle(color: Colors.red[700], fontSize: 11),
            ),
          ),
      ],
    );
  }

  // Submit form
  Future<void> _submitForm({bool keepOpen = false}) async {
    final multiSaleUnitEnabled =
        context.read<AppSettingsProvider>().multiSaleUnitEnabled;
    setState(() {
      isValidatedOnce = true;
      _showSaleUnitValidation = multiSaleUnitEnabled && _showAdvancedOptions;
    });

    bool isFormValid = formKey.currentState!.validate();
    bool isUnitValid = selectedUnit != null;
    bool isCategoryValid = selectedCategory != null;

    if (isFormValid && isUnitValid && isCategoryValid) {
      if (multiSaleUnitEnabled && !_validateSaleUnits()) {
        return;
      }

      if (multiSaleUnitEnabled && _showAdvancedOptions) {
        final baseRate = _baseConversionRateController.text.trim();
        if (baseRate.isEmpty) {
          showScaffoldError(
            context: context,
            message: 'product_form.base_conversion_rate_required'.tr,
          );
          return;
        }
        final parsedRate = num.tryParse(baseRate);
        if (parsedRate == null || parsedRate <= 0) {
          showScaffoldError(
            context: context,
            message: 'product_form.base_conversion_rate_must_be_positive'.tr,
          );
          return;
        }
      }

      final variantEnabled =
          Provider.of<AppSettingsProvider>(context, listen: false)
                  .appSettings
                  ?.productVariantEnabled ??
              false;
      if (variantEnabled && _variantController.hasRows) {
        final variantError =
            validateVariantRows(_variantController.toCreateInputs());
        if (variantError != null) {
          showScaffoldError(context: context, message: variantError);
          return;
        }
      }

      final canContinue = await _ensureBarcodeDuplicateConfirmed();
      if (!canContinue) {
        return;
      }

      formKey.currentState!.save();
      setState(() {
        if (keepOpen) {
          isSaveAndCreateLoading = true;
        } else {
          isLoading = true;
        }
      });

      try {
        String? accessToken =
            Provider.of<AuthModel>(context, listen: false).token;
        GridSelectionProvider gridSelectionProvider =
            Provider.of<GridSelectionProvider>(context, listen: false);
        final languageProvider =
            Provider.of<LanguageProvider>(context, listen: false);
        final productNames =
            _buildProductNamesPayload(languageProvider.languages);
        final saleUnits = multiSaleUnitEnabled
            ? _buildSaleUnitsPayload()
            : const <Map<String, dynamic>>[];
        final variants = (variantEnabled && _variantController.hasRows)
            ? buildCreateVariantsPayload(_variantController.toCreateInputs())
            : const <Map<String, dynamic>>[];

        final itemCodeEnabled =
            Provider.of<AppSettingsProvider>(context, listen: false)
                    .appSettings
                    ?.itemCodeEnabled ??
                false;

        final result = await gridSelectionProvider.createProductAPI(
          categoryId: selectedCategory!.categoryId.toString(),
          productName: _productNameController.text,
          sellingPrice: _productSellingPriceController.text,
          mrp: _productMRPController.text,
          unit: selectedUnit!,
          quantity: _productQuantityController.text,
          barcode: _productBarcodeController.text,
          accessToken: accessToken ?? "",
          purchasePrice: _productPurchasePriceController.text,
          productNames: productNames.isNotEmpty ? productNames : null,
          saleUnits: saleUnits.isNotEmpty ? saleUnits : null,
          variants: variants.isNotEmpty ? variants : null,
          conversionRateBase:
              _baseConversionRateController.text.trim().isNotEmpty
                  ? _baseConversionRateController.text.trim()
                  : '1',
          itemCode:
              itemCodeEnabled ? _productItemCodeController.text.trim() : null,
          minMarginPercentage:
              _productMinMarginController.text.trim().isNotEmpty
                  ? _productMinMarginController.text.trim()
                  : null,
          minMarginPrice:
              _productMinMarginPriceController.text.trim().isNotEmpty
                  ? _productMinMarginPriceController.text.trim()
                  : null,
        );

        if (!mounted) {
          return;
        }

        if (result is Map<String, dynamic> &&
            result['status'] != 'failed' &&
            result.containsKey('data')) {
          GetProduct? createdProduct;
          try {
            createdProduct = GetProduct.fromJson(result['data']);
            Provider.of<LocalProductProvider>(context, listen: false)
                .addProduct(createdProduct);
          } catch (e) {
            debugPrint("Error parsing product: $e");
          }

          if (widget.isAddToCart && createdProduct != null) {
            await addCreatedProductToCart(
              context: context,
              product: createdProduct,
              sellingPriceText: _productSellingPriceController.text,
            );
            if (!mounted) {
              return;
            }
          }

          Provider.of<LocalProductProvider>(context, listen: false)
              .refreshProducts();

          try {
            final returnedProduct = GetProduct.fromJson(result['data']);
            if (!keepOpen) {
              Navigator.pop(context, {
                'product': returnedProduct,
                'initialQuantity': _productQuantityController.text,
              });
            }
          } catch (_) {
            if (!keepOpen) {
              Navigator.pop(context, {
                'product': result['data'],
                'initialQuantity': _productQuantityController.text,
              });
            }
          }
          if (keepOpen) {
            _resetFormFields();
          }
          showScaffold(context: context, message: 'product_form.product_added_success'.tr);
        } else {
          showScaffoldError(
            context: context,
            message: AddProductFormHelpers.parseCreateProductError(result),
          );
        }
      } catch (e) {
        showScaffoldError(
          context: context,
          message: 'product_form.error_adding_product'.tr.replaceAll('@error', e.toString()),
        );
        debugPrint("Error in product creation: $e");
      } finally {
        setState(() {
          if (keepOpen) {
            isSaveAndCreateLoading = false;
          } else {
            isLoading = false;
          }
        });
      }
    } else {
      showScaffoldError(
        context: context,
        message: 'product_form.fill_required_fields'.tr,
      );
    }
  }

  void _resetFormFields() {
    _productBarcodeController.clear();
    _productNameController.clear();
    _productMRPController.clear();
    _productQuantityController.text = '0';
    _productSellingPriceController.clear();
    _productPurchasePriceController.clear();
    _productItemCodeController.clear();
    _productMinMarginController.clear();
    _productMinMarginPriceController.clear();
    _baseConversionRateController.text = '1';
    for (var controller in _languageNameControllers.values) {
      if (controller != _productNameController) {
        controller.clear();
      }
    }
    setState(() {
      _confirmedDuplicateBarcode = null;
      selectedUnit = null;
      selectedCategory = null;
      isValidatedOnce = false;
      _showAdvancedOptions = false;
      _showSaleUnitValidation = false;
      _clearSaleUnitRows();
      _variantController.clear();
    });
  }
}
