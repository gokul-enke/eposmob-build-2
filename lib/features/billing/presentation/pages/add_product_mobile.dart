import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/domain/add_created_product_to_cart.dart';
import 'package:pos_machine/features/billing/domain/add_product_form_helpers.dart';
import 'package:pos_machine/features/products/domain/variant_form_payload.dart';
import 'package:pos_machine/features/products/presentation/variant_editor_section.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/language.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/language_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/helpers/purchase_price_permission.dart';
import 'package:pos_machine/resources/color_manager.dart';

class AddProductMobileScreen extends StatefulWidget {
  const AddProductMobileScreen({
    super.key,
    this.barcode,
    this.isAddToCart = false,
  });

  final String? barcode;
  final bool isAddToCart;

  @override
  State<AddProductMobileScreen> createState() => _AddProductMobileScreenState();
}

class _AddProductMobileScreenState extends State<AddProductMobileScreen> {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();

  int _currentStep = 1;
  bool _isLoading = false;
  bool _isSaveAndCreateLoading = false;
  bool _isGeneratingBarcode = false;
  bool _isCheckingDuplicateBarcode = false;
  bool _isValidatedOnce = false;
  bool _showAdvancedOptions = false;
  bool _showSaleUnitValidation = false;
  bool _languagesRequested = false;

  String? _confirmedDuplicateBarcode;

  bool _canViewPurchasePrice({bool listen = false}) =>
      canViewPurchasePrice(context, listen: listen);

  // Step 1
  final _productNameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _categorySearchController = TextEditingController();
  final _barcodeFocusNode = FocusNode();
  Category? _selectedCategory;

  // Step 2
  final Map<int, TextEditingController> _languageNameControllers = {};
  final Map<int, bool> _languageTranslating = {};

  // Step 3
  String? _selectedUnit;
  final _unitSearchController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');
  final _itemCodeController = TextEditingController();
  final _minMarginController = TextEditingController();
  final _minMarginPriceController = TextEditingController();
  final _baseConversionRateController = TextEditingController(text: '1');
  final List<AddProductSaleUnitRow> _saleUnitRows = [];

  final VariantEditorController _variantController = VariantEditorController();
  bool _variantPropertiesRequested = false;
  bool _isLoadingVariantProperties = false;

  static final _decimalInputFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'));
  static final _conversionRateFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}$'));

  @override
  void initState() {
    super.initState();
    if (widget.barcode != null) {
      _barcodeController.text = widget.barcode!;
    }
    _barcodeFocusNode.addListener(_handleBarcodeFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLanguages();
      _fetchVariantProperties();
    });
  }

  @override
  void dispose() {
    _barcodeFocusNode.removeListener(_handleBarcodeFocusChange);
    _productNameController.dispose();
    _barcodeController.dispose();
    _categorySearchController.dispose();
    _barcodeFocusNode.dispose();
    for (final controller in _languageNameControllers.values) {
      if (controller != _productNameController) {
        controller.dispose();
      }
    }
    _languageNameControllers.clear();
    _purchasePriceController.dispose();
    _mrpController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    _itemCodeController.dispose();
    _minMarginController.dispose();
    _minMarginPriceController.dispose();
    _unitSearchController.dispose();
    _baseConversionRateController.dispose();
    _clearSaleUnitRows();
    _variantController.dispose();
    super.dispose();
  }

  void _handleBarcodeFocusChange() {
    if (!_barcodeFocusNode.hasFocus) {
      _ensureBarcodeDuplicateConfirmed();
    }
  }

  void _clearSaleUnitRows() {
    for (final row in _saleUnitRows) {
      row.dispose();
    }
    _saleUnitRows.clear();
  }

  Future<void> _fetchLanguages() async {
    if (_languagesRequested) return;
    _languagesRequested = true;

    final token = Provider.of<AuthModel>(context, listen: false).token ?? '';
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    await languageProvider.fetchLanguages(accessToken: token);

    if (!mounted) return;
    if (languageProvider.error != null) {
      showScaffoldError(context: context, message: languageProvider.error!);
    }
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

  void _retryFetchLanguages() {
    _languagesRequested = false;
    _fetchLanguages();
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
    }
  }

  List<GetProduct> _findExistingProductsByBarcode(String barcode) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return const <GetProduct>[];
    return Provider.of<LocalProductProvider>(context, listen: false)
        .filterProductByBarcode(barCode: trimmed);
  }

  Future<bool> _ensureBarcodeDuplicateConfirmed() async {
    final barcode = _barcodeController.text.trim();
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

      if (!mounted) return false;

      if (selectedProduct != null) {
        _fillFormFromExistingProduct(selectedProduct);
        setState(() {
          _confirmedDuplicateBarcode = barcode;
        });
        return true;
      }

      setState(() {
        _barcodeController.clear();
        _confirmedDuplicateBarcode = null;
      });
      return false;
    } finally {
      _isCheckingDuplicateBarcode = false;
    }
  }

  Future<GetProduct?> _showDuplicateBarcodeDialog({
    required String barcode,
    required List<GetProduct> existingProducts,
  }) {
    return showModalBottomSheet<GetProduct>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        GetProduct selectedProduct = existingProducts.first;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Duplicate Barcode Found',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Barcode: $barcode',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a product to copy its details into the form.',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: existingProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final product = existingProducts[index];
                        final isSelected = identical(product, selectedProduct);
                        return InkWell(
                          onTap: () {
                            setSheetState(() {
                              selectedProduct = product;
                            });
                          },
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
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.productName
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                true
                                            ? product.productName!.trim()
                                            : 'Unnamed Product',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: ColorManager.kPrimaryColor,
                                        size: 20,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Qty: ${AddProductFormHelpers.getAvailableQuantity(product)}',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: ColorManager.kPrimaryColor),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: ColorManager.kPrimaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(sheetContext, selectedProduct),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorManager.kPrimaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _fillFormFromExistingProduct(GetProduct product) {
    final purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final unitList = purchaseProvider.getUnitList ?? const <String, String>{};
    final categories = categoryProvider.category ?? const <Category>[];

    final resolvedUnit =
        AddProductFormHelpers.resolveUnitValue(product.unit, unitList);
    final resolvedCategory =
        AddProductFormHelpers.resolveCategory(product, categories);

    setState(() {
      _productNameController.text = product.productName?.trim() ?? '';
      _barcodeController.text = product.barcode?.trim() ?? '';
      _itemCodeController.text = product.itemCode?.trim() ?? '';
      _sellingPriceController.text =
          AddProductFormHelpers.formatDynamicNumber(product.price?.price);
      _mrpController.text =
          AddProductFormHelpers.formatDynamicNumber(product.mrp);
      _purchasePriceController.text =
          AddProductFormHelpers.formatDynamicNumber(product.purchasePrice);
      _quantityController.text =
          AddProductFormHelpers.getAutofillQuantity(product);
      _selectedUnit = resolvedUnit;
      _selectedCategory = resolvedCategory;
    });

    _syncLanguageControllersFromProduct(product);
    _syncSaleUnitsFromProduct(product);
  }

  void _syncLanguageControllersFromProduct(GetProduct product) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final activeLanguages = languageProvider.languages
        .where((language) => language.active)
        .toList(growable: false);
    final baseLanguage = AddProductFormHelpers.getBaseLanguage(activeLanguages);

    _syncLanguageControllers(activeLanguages, baseLanguage);

    for (final language in activeLanguages) {
      if (baseLanguage != null && language.id == baseLanguage.id) continue;
      final translatedName = AddProductFormHelpers.extractTranslatedName(
        product.names,
        language,
      );
      _languageNameControllers[language.id]?.text = translatedName;
    }
  }

  void _syncSaleUnitsFromProduct(GetProduct product) {
    _clearSaleUnitRows();
    final saleUnits = (product.saleUnits ?? const <SaleUnit>[])
        .where((saleUnit) => saleUnit.unitId?.toString() != _selectedUnit)
        .toList(growable: false);
    for (final saleUnit in saleUnits) {
      _saleUnitRows.add(
        AddProductSaleUnitRow(
          selectedUnitId: saleUnit.unitId?.toString(),
          conversionRate: saleUnit.conversionRate ?? '',
          barcode: saleUnit.barcode ?? '',
          price: AddProductFormHelpers.formatDynamicNumber(saleUnit.price),
        ),
      );
    }
    setState(() {
      _showAdvancedOptions = saleUnits.isNotEmpty;
      _showSaleUnitValidation = false;
    });
  }

  Future<void> _generateBarcode() async {
    if (_isGeneratingBarcode || widget.barcode != null) return;
    await _generateBarcodeIntoController(_barcodeController);
  }

  Future<void> _generateBarcodeIntoController(
    TextEditingController controller, {
    void Function(bool value)? onLoadingChanged,
  }) async {
    onLoadingChanged?.call(true);
    setState(() {
      if (identical(controller, _barcodeController)) {
        _isGeneratingBarcode = true;
      }
    });

    try {
      final token = Provider.of<AuthModel>(context, listen: false).token;
      if (token == null || token.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'Authentication token not found. Please log in again.',
        );
        return;
      }

      final gridProvider =
          Provider.of<GridSelectionProvider>(context, listen: false);
      final productProvider =
          Provider.of<LocalProductProvider>(context, listen: false);
      final result = await gridProvider.generateBarcodeAPI(accessToken: token);

      if (!mounted) return;

      if (result != null &&
          result['status'] == 'success' &&
          result['data'] != null) {
        final generatedBarcode = result['data']['barcode'] as String;
        final resolvedBarcode = AddProductFormHelpers.getNextAvailableBarcode(
          seedBarcode: generatedBarcode,
          productProvider: productProvider,
          mainBarcode: _barcodeController.text,
          saleUnitRows: _saleUnitRows,
          additionalBarcodeControllers:
              _variantController.rows.map((row) => row.barcodeController),
          excludeController: controller,
          mainBarcodeController: _barcodeController,
        );
        final wasAdjusted = resolvedBarcode != generatedBarcode;

        setState(() {
          controller.text = resolvedBarcode;
          if (identical(controller, _barcodeController)) {
            _confirmedDuplicateBarcode = null;
          }
        });

        showScaffold(
          context: context,
          message: wasAdjusted
              ? 'Barcode generated and incremented to keep it unique'
              : 'Barcode generated successfully',
        );
      } else {
        showScaffoldError(
          context: context,
          message: result?['message'] ?? 'Failed to generate barcode',
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Error generating barcode: $e',
      );
    } finally {
      onLoadingChanged?.call(false);
      if (mounted) {
        setState(() {
          if (identical(controller, _barcodeController)) {
            _isGeneratingBarcode = false;
          }
        });
      }
    }
  }

  Future<void> _translateLanguage(Language language) async {
    final baseText = _productNameController.text.trim();
    if (baseText.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'Please enter Product Name before translating.',
      );
      return;
    }

    if (_languageTranslating[language.id] == true) return;

    setState(() {
      _languageTranslating[language.id] = true;
    });

    final token = Provider.of<AuthModel>(context, listen: false).token ?? '';
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    final translated = await languageProvider.translateText(
      accessToken: token,
      targetLang: language.code,
      text: baseText,
    );

    if (!mounted) return;

    if (translated != null && translated.isNotEmpty) {
      _languageNameControllers[language.id]?.text = translated;
      showScaffold(
        context: context,
        message: 'Translated to ${language.name}',
      );
    } else {
      showScaffoldError(
        context: context,
        message: 'Translation failed. Please try again.',
      );
    }

    if (mounted) {
      setState(() {
        _languageTranslating[language.id] = false;
      });
    }
  }

  void _handleBaseUnitChange(String? newValue) {
    setState(() {
      _selectedUnit = newValue;
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
      _saleUnitRows.add(AddProductSaleUnitRow(conversionRate: '1'));
    });
  }

  void _removeSaleUnitRow(int index) {
    final row = _saleUnitRows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  Future<void> _goToNextStep() async {
    if (_currentStep == 1) {
      setState(() => _isValidatedOnce = true);
      final isFormValid = _formKeyStep1.currentState!.validate();
      final isCategoryValid = _selectedCategory != null;

      if (!isFormValid || !isCategoryValid) {
        if (!isCategoryValid) {
          showScaffoldError(
            context: context,
            message: 'Please select a Product Category.',
          );
        } else {
          showScaffoldError(
            context: context,
            message: 'Please fill all required fields correctly',
          );
        }
        return;
      }

      final canContinue = await _ensureBarcodeDuplicateConfirmed();
      if (!mounted || !canContinue) return;

      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      setState(() => _currentStep = 3);
    }
  }

  Future<void> _submitForm({bool keepOpen = false}) async {
    final multiSaleUnitEnabled =
        context.read<AppSettingsProvider>().multiSaleUnitEnabled;
    setState(() {
      _isValidatedOnce = true;
      _showSaleUnitValidation = multiSaleUnitEnabled && _showAdvancedOptions;
    });

    final isFormValid = _formKeyStep3.currentState!.validate();
    final isUnitValid = _selectedUnit != null;
    final isCategoryValid = _selectedCategory != null;

    if (!isFormValid || !isUnitValid || !isCategoryValid) {
      showScaffoldError(
        context: context,
        message: 'Please fill all required fields correctly',
      );
      return;
    }

    if (multiSaleUnitEnabled &&
        !AddProductFormHelpers.validateSaleUnits(
          showAdvancedOptions: _showAdvancedOptions,
          selectedUnit: _selectedUnit,
          mainBarcode: _barcodeController.text,
          saleUnitRows: _saleUnitRows,
          onError: (message) =>
              showScaffoldError(context: context, message: message),
        )) {
      return;
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

    if (multiSaleUnitEnabled && _showAdvancedOptions) {
      final baseRate = _baseConversionRateController.text.trim();
      if (baseRate.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'Base unit conversion rate is required.',
        );
        return;
      }
      final parsedRate = num.tryParse(baseRate);
      if (parsedRate == null || parsedRate <= 0) {
        showScaffoldError(
          context: context,
          message: 'Base unit conversion rate must be greater than 0.',
        );
        return;
      }
    }

    final canContinue = await _ensureBarcodeDuplicateConfirmed();
    if (!mounted || !canContinue) return;

    setState(() {
      if (keepOpen) {
        _isSaveAndCreateLoading = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final token = Provider.of<AuthModel>(context, listen: false).token ?? '';
      final gridProvider =
          Provider.of<GridSelectionProvider>(context, listen: false);
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      final itemCodeEnabled =
          Provider.of<AppSettingsProvider>(context, listen: false)
                  .appSettings
                  ?.itemCodeEnabled ??
              false;

      final activeLanguages = languageProvider.languages
          .where((lang) => lang.active)
          .toList(growable: false);
      final productNames = AddProductFormHelpers.buildProductNamesPayload(
        languages: activeLanguages,
        languageNameControllers: _languageNameControllers,
      );
      final saleUnits = AddProductFormHelpers.buildSaleUnitsPayload(
        showAdvancedOptions: multiSaleUnitEnabled && _showAdvancedOptions,
        selectedUnit: _selectedUnit,
        saleUnitRows: _saleUnitRows,
      );
      final variants = (variantEnabled && _variantController.hasRows)
          ? buildCreateVariantsPayload(_variantController.toCreateInputs())
          : const <Map<String, dynamic>>[];
      final canViewPurchasePrice = _canViewPurchasePrice();

      final result = await gridProvider.createProductAPI(
        categoryId: _selectedCategory!.categoryId.toString(),
        productName: _productNameController.text,
        sellingPrice: _sellingPriceController.text,
        mrp: _mrpController.text,
        unit: _selectedUnit!,
        quantity: _quantityController.text,
        barcode: _barcodeController.text,
        accessToken: token,
        purchasePrice:
            canViewPurchasePrice ? _purchasePriceController.text : '0',
        productNames: productNames.isNotEmpty ? productNames : null,
        saleUnits: saleUnits.isNotEmpty ? saleUnits : null,
        variants: variants.isNotEmpty ? variants : null,
        conversionRateBase: _baseConversionRateController.text.trim().isNotEmpty
            ? _baseConversionRateController.text.trim()
            : '1',
        itemCode: itemCodeEnabled ? _itemCodeController.text.trim() : null,
        minMarginPercentage: _minMarginController.text.trim().isNotEmpty
            ? _minMarginController.text.trim()
            : null,
        minMarginPrice: _minMarginPriceController.text.trim().isNotEmpty
            ? _minMarginPriceController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (result is Map<String, dynamic> &&
          result['status'] != 'failed' &&
          result.containsKey('data')) {
        GetProduct? createdProduct;
        try {
          createdProduct = GetProduct.fromJson(result['data']);
          Provider.of<LocalProductProvider>(context, listen: false)
              .addProduct(createdProduct);
        } catch (e) {
          debugPrint('Error parsing product: $e');
        }

        if (widget.isAddToCart && createdProduct != null) {
          await addCreatedProductToCart(
            context: context,
            product: createdProduct,
            sellingPriceText: _sellingPriceController.text,
          );
          if (!mounted) return;
        }

        Provider.of<LocalProductProvider>(context, listen: false)
            .refreshProducts();

        if (!keepOpen) {
          if (createdProduct != null) {
            Navigator.pop(context, {
              'product': createdProduct,
              'initialQuantity': _quantityController.text,
            });
          } else {
            Navigator.pop(context, {
              'product': result['data'],
              'initialQuantity': _quantityController.text,
            });
          }
        } else {
          _resetFormFields();
        }

        showScaffold(context: context, message: 'Product added successfully');
      } else {
        showScaffoldError(
          context: context,
          message: AddProductFormHelpers.parseCreateProductError(result),
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Error adding product: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          if (keepOpen) {
            _isSaveAndCreateLoading = false;
          } else {
            _isLoading = false;
          }
        });
      }
    }
  }

  void _resetFormFields() {
    _barcodeController.clear();
    _productNameController.clear();
    _mrpController.clear();
    _quantityController.text = '0';
    _sellingPriceController.clear();
    _purchasePriceController.clear();
    _itemCodeController.clear();
    _minMarginController.clear();
    _minMarginPriceController.clear();
    _baseConversionRateController.text = '1';
    for (final controller in _languageNameControllers.values) {
      if (controller != _productNameController) {
        controller.clear();
      }
    }
    setState(() {
      _confirmedDuplicateBarcode = null;
      _selectedUnit = null;
      _selectedCategory = null;
      _isValidatedOnce = false;
      _showAdvancedOptions = false;
      _showSaleUnitValidation = false;
      _currentStep = 1;
      _clearSaleUnitRows();
      _variantController.clear();
    });
  }

  Widget _buildStepIndicator(int stepNumber, String title) {
    final isActive = _currentStep == stepNumber;
    final isCompleted = _currentStep > stepNumber;
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive || isCompleted
                ? ColorManager.kPrimaryColor
                : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: isActive ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: isActive || isCompleted
                ? ColorManager.kPrimaryColor
                : Colors.grey.shade600,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider() {
    return Expanded(
      child: Container(
        height: 1.5,
        color: Colors.grey.shade300,
        margin: const EdgeInsets.only(bottom: 22),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    bool isRequired = false,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    FocusNode? focusNode,
    VoidCallback? onEditingComplete,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator ??
              (isRequired
                  ? (val) =>
                      val == null || val.trim().isEmpty ? 'Required' : null
                  : null),
          onEditingComplete: onEditingComplete,
          onChanged: onChanged,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.grey.shade50,
            suffixIcon: suffixIcon,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: ColorManager.kPrimaryColor,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSquareActionButton({
    required bool isLoading,
    required VoidCallback? onPressed,
    required Widget icon,
  }) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : icon,
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoading || _isSaveAndCreateLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: isBusy ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Add New Product',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade100, height: 1),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.barcode != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              'No product found with barcode ${widget.barcode}',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          children: [
                            _buildStepIndicator(1, 'Basic Info'),
                            _buildStepDivider(),
                            _buildStepIndicator(2, 'Localization'),
                            _buildStepDivider(),
                            _buildStepIndicator(3, 'Pricing'),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.blue.shade50,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade50,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _buildStepContent(),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: _buildBottomActions(),
                ),
              ],
            ),
          ),
          if (isBusy)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(ColorManager.kPrimaryColor),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.info, 'Basic Information'),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'Product Name',
            hintText: 'e.g. Premium Coffee Beans',
            controller: _productNameController,
            isRequired: true,
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: 'Barcode',
            hintText: 'Scan or enter barcode',
            controller: _barcodeController,
            focusNode: _barcodeFocusNode,
            isRequired: true,
            readOnly: widget.barcode != null,
            onChanged: (_) {
              if (_confirmedDuplicateBarcode != null) {
                setState(() => _confirmedDuplicateBarcode = null);
              }
            },
            onEditingComplete: () => _ensureBarcodeDuplicateConfirmed(),
            suffixIcon: widget.barcode != null
                ? null
                : _buildSquareActionButton(
                    isLoading: _isGeneratingBarcode,
                    onPressed: _generateBarcode,
                    icon: const Icon(Icons.refresh,
                        color: Colors.white, size: 22),
                  ),
          ),
          const SizedBox(height: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Product Category',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Consumer<CategoryProvider>(
                builder: (context, categoryProvider, _) {
                  final categories = categoryProvider.category ?? [];
                  return CustomDropDownWithSearch<Category>(
                    hintText: 'Select Category...',
                    value: _selectedCategory,
                    items: categories,
                    searchController: _categorySearchController,
                    onChanged: (cat) {
                      setState(() => _selectedCategory = cat);
                    },
                    displayText: (cat) => cat.categoryName ?? '',
                  );
                },
              ),
              if (_isValidatedOnce && _selectedCategory == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.red[700],
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Consumer<LanguageProvider>(
      builder: (context, langProvider, _) {
        if (langProvider.isLoading && langProvider.languages.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (langProvider.error != null && langProvider.languages.isEmpty) {
          return Column(
            children: [
              Text(
                langProvider.error!,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.red[700],
                  fontSize: 13,
                ),
              ),
              TextButton(
                onPressed: _retryFetchLanguages,
                child: Text('general.retry'.tr),
              ),
            ],
          );
        }

        final languages = langProvider.languages
            .where((lang) => lang.active)
            .toList(growable: false);
        final baseLanguage = AddProductFormHelpers.getBaseLanguage(languages);
        _syncLanguageControllers(languages, baseLanguage);

        final otherLanguages = languages
            .where((lang) => baseLanguage == null || lang.id != baseLanguage.id)
            .toList();

        if (otherLanguages.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(Icons.translate, 'Other Language Names'),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No other languages available.',
                    style: TextStyle(fontFamily: 'Poppins', color: Colors.grey),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(Icons.translate, 'Other Language Names'),
            const SizedBox(height: 20),
            ...otherLanguages.map((language) {
              final isTranslating = _languageTranslating[language.id] == true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _buildInputField(
                  label: 'Product Name (${language.name})',
                  hintText: 'Enter name in ${language.name}',
                  controller: _languageNameControllers[language.id]!,
                  suffixIcon: _buildSquareActionButton(
                    isLoading: isTranslating,
                    onPressed: isTranslating
                        ? null
                        : () => _translateLanguage(language),
                    icon: const Icon(Icons.translate,
                        color: Colors.white, size: 20),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildStep3() {
    final multiSaleUnitEnabled = context
            .watch<AppSettingsProvider>()
            .appSettings
            ?.multiSaleUnitEnabled ??
        false;
    final canViewPurchasePrice = _canViewPurchasePrice(listen: true);
    return Form(
      key: _formKeyStep3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSectionHeader(
                  Icons.account_balance_wallet,
                  'Pricing & Stock',
                ),
              ),
              if (multiSaleUnitEnabled)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Advanced',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Switch(
                      value: _showAdvancedOptions,
                      activeThumbColor: ColorManager.kPrimaryColor,
                      onChanged: _toggleAdvancedOptions,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Product Unit',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Consumer<PurchaseProvider>(
                builder: (context, purchaseProvider, _) {
                  final unitList =
                      purchaseProvider.getUnitList ?? const <String, String>{};
                  return CustomDropDownWithSearch<String>(
                    hintText: 'Select Unit...',
                    value: _selectedUnit,
                    items: unitList.keys.toList(),
                    searchController: _unitSearchController,
                    onChanged: _handleBaseUnitChange,
                    displayText: (unitKey) => unitList[unitKey] ?? unitKey,
                  );
                },
              ),
              if (_isValidatedOnce && _selectedUnit == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.red[700],
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (canViewPurchasePrice)
            _buildInputField(
              label: 'Purchase Price',
              hintText: '0.00',
              controller: _purchasePriceController,
              isRequired: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_decimalInputFormatter],
            ),
          const SizedBox(height: 18),
          _buildInputField(
            label: 'Max Sale Price / MRP',
            hintText: 'Optional',
            controller: _mrpController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalInputFormatter],
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: 'Selling Price',
            hintText: '0.00',
            controller: _sellingPriceController,
            isRequired: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalInputFormatter],
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: 'Quantity',
            hintText: '0',
            controller: _quantityController,
            isRequired: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalInputFormatter],
          ),
          const SizedBox(height: 18),
          Consumer<AppSettingsProvider>(
            builder: (context, appSettingsProvider, _) {
              final itemCodeEnabled =
                  appSettingsProvider.appSettings?.itemCodeEnabled ?? false;
              if (!itemCodeEnabled) return const SizedBox.shrink();
              return Column(
                children: [
                  _buildInputField(
                    label: 'Item Code',
                    hintText: 'PROD-12345',
                    controller: _itemCodeController,
                  ),
                  const SizedBox(height: 18),
                ],
              );
            },
          ),
          _buildInputField(
            label: 'Max Discount Percentage',
            hintText: 'Optional',
            controller: _minMarginController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalInputFormatter],
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: 'Max Discount Amount',
            hintText: 'Optional',
            controller: _minMarginPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalInputFormatter],
          ),
          if (multiSaleUnitEnabled && _showAdvancedOptions) ...[
            const SizedBox(height: 24),
            _buildAdvancedSaleUnitsSection(),
          ],
          const SizedBox(height: 24),
          _buildVariantsSection(),
        ],
      ),
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
        return VariantEditorSection(
          controller: _variantController,
          properties: productProvider.productProperties,
          isLoadingProperties: _isLoadingVariantProperties,
          showPurchasePrice: _canViewPurchasePrice(),
          onRetryLoadProperties: _retryFetchVariantProperties,
          onGenerateBarcode: (target, setLoading) =>
              _generateBarcodeIntoController(target,
                  onLoadingChanged: setLoading),
        );
      },
    );
  }

  Widget _buildAdvancedSaleUnitsSection() {
    return Consumer<PurchaseProvider>(
      builder: (context, purchaseProvider, _) {
        final unitList =
            purchaseProvider.getUnitList ?? const <String, String>{};
        final canConfigure = _selectedUnit != null;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
              const Text(
                'Multi Sale Unit',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Base unit is required before adding additional sale units.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              if (!canConfigure)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.35)),
                  ),
                  child: Text(
                    'Select the product unit first to activate this section.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                )
              else ...[
                _buildBaseSaleUnitCard(unitList),
                const SizedBox(height: 12),
                ...List.generate(_saleUnitRows.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _saleUnitRows.length - 1 ? 0 : 12,
                    ),
                    child: _buildEditableSaleUnitCard(
                      unitList,
                      _saleUnitRows[index],
                      index,
                    ),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addSaleUnitRow,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('product_sale_unit.add_sale_unit'.tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorManager.kPrimaryColor,
                      side: BorderSide(color: ColorManager.kPrimaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBaseSaleUnitCard(Map<String, String> unitList) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${AddProductFormHelpers.resolveUnitLabel(_selectedUnit, unitList)} (Base Unit)',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          _buildInputField(
            label: 'Conversion Rate',
            hintText: '1',
            controller: _baseConversionRateController,
            isRequired: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_conversionRateFormatter],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _barcodeController,
            builder: (context, value, _) {
              final barcodeText =
                  value.text.trim().isEmpty ? '-' : value.text.trim();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Barcode',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.grey.shade200, width: 1.5),
                    ),
                    child: Text(
                      barcodeText,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditableSaleUnitCard(
    Map<String, String> unitList,
    AddProductSaleUnitRow row,
    int index,
  ) {
    final availableUnits = unitList.entries
        .where((entry) => entry.key != _selectedUnit)
        .map((entry) => entry.key)
        .toList();

    final hasValidationError = _showSaleUnitValidation &&
        ((row.selectedUnitId?.isEmpty ?? true) ||
            row.conversionRateController.text.trim().isEmpty ||
            row.barcodeController.text.trim().isEmpty ||
            row.priceController.text.trim().isEmpty);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              hasValidationError ? Colors.red.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sale Unit ${index + 1}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _removeSaleUnitRow(index),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Sale Unit',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              CustomDropDownWithSearch<String>(
                hintText: 'Select unit',
                value: row.selectedUnitId,
                items: availableUnits,
                searchController: row.searchController,
                onChanged: (value) {
                  setState(() => row.selectedUnitId = value);
                },
                displayText: (item) => unitList[item] ?? item,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInputField(
            label: 'Conversion Rate',
            hintText: '1',
            controller: row.conversionRateController,
            isRequired: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_conversionRateFormatter],
          ),
          const SizedBox(height: 12),
          _buildInputField(
            label: 'Barcode',
            hintText: 'Enter or generate',
            controller: row.barcodeController,
            isRequired: true,
            suffixIcon: _buildSquareActionButton(
              isLoading: row.isGeneratingBarcode,
              onPressed: row.isGeneratingBarcode
                  ? null
                  : () => _generateBarcodeIntoController(
                        row.barcodeController,
                        onLoadingChanged: (value) {
                          row.isGeneratingBarcode = value;
                        },
                      ),
              icon:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          _buildInputField(
            label: 'Price',
            hintText: '0.00',
            controller: row.priceController,
            isRequired: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalInputFormatter],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    if (_currentStep == 1) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorManager.kPrimaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          onPressed: _goToNextStep,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Next',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward, color: Colors.white, size: 18),
            ],
          ),
        ),
      );
    }

    if (_currentStep == 2) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => setState(() => _currentStep = 1),
              child: Text(
                'Back',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: _goToNextStep,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Next',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => setState(() => _currentStep = 2),
                child: Text(
                  'Back',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: ColorManager.kPrimaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: (_isLoading || _isSaveAndCreateLoading)
                    ? null
                    : () => _submitForm(keepOpen: true),
                child: _isSaveAndCreateLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ColorManager.kPrimaryColor,
                          ),
                        ),
                      )
                    : Text(
                        'Save & Add Another',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ColorManager.kPrimaryColor,
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.kPrimaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: (_isLoading || _isSaveAndCreateLoading)
                ? null
                : () => _submitForm(keepOpen: false),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Save Product',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
