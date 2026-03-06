import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/language.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/language_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/newcomponents/custom_container_box.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';

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
  final TextEditingController _unitSearchController = TextEditingController();
  final TextEditingController _categorySearchController =
      TextEditingController();
  final Map<int, TextEditingController> _languageNameControllers = {};
  final Map<int, bool> _languageTranslating = {};
  bool _languagesRequested = false;

  // Focus nodes for each text field
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _productNameFocusNode = FocusNode();
  final FocusNode _mrpFocusNode = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();
  final FocusNode _sellingPriceFocusNode = FocusNode();
  final FocusNode _purchasePriceFocusNode = FocusNode();
  final FocusNode _unitFocusNode = FocusNode();
  final FocusNode _categoryFocusNode = FocusNode();

  bool isLoading = false;
  bool isSaveAndCreateLoading = false;
  bool isBarcodeGenerating = false;
  bool _isCheckingDuplicateBarcode = false;
  String? _confirmedDuplicateBarcode;
  String? selectedUnit;
  Category? selectedCategory;
  bool isValidatedOnce = false;

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
      _fetchLanguages();
    });
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
      final shouldContinue = await _showDuplicateBarcodeDialog(
        barcode: barcode,
        existingProducts: existingProducts,
      );

      if (!mounted) {
        return false;
      }

      if (shouldContinue) {
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

  Future<bool> _showDuplicateBarcodeDialog({
    required String barcode,
    required List<GetProduct> existingProducts,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Duplicate Barcode Found',
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
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'There is already a product with the same barcode. Do you want to continue?',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s13,
                    0.27,
                    ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Barcode: $barcode',
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
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
                      return _buildExistingProductCard(product);
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
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: ColorManager.kPrimaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Cancel',
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
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorManager.kPrimaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Continue',
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
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  Widget _buildExistingProductCard(GetProduct product) {
    final categoryName = product.category?.name?.trim();
    final sellingPrice = product.price?.price?.toString().trim();
    final mrp = product.mrp?.toString().trim();
    final unit = product.unit?.trim();
    final availableQuantity = _getAvailableQuantity(product);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.productName?.trim().isNotEmpty == true
                ? product.productName!.trim()
                : 'Unnamed Product',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.27,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            runSpacing: 8,
            spacing: 14,
            children: [
              _buildProductDetailItem('Barcode', product.barcode ?? '-'),
              _buildProductDetailItem(
                  'Category',
                  categoryName != null && categoryName.isNotEmpty
                      ? categoryName
                      : '-'),
              _buildProductDetailItem(
                  'Selling Price',
                  sellingPrice != null && sellingPrice.isNotEmpty
                      ? sellingPrice
                      : '-'),
              _buildProductDetailItem(
                  'MRP', mrp != null && mrp.isNotEmpty ? mrp : '-'),
              _buildProductDetailItem(
                  'Unit', unit != null && unit.isNotEmpty ? unit : '-'),
              _buildProductDetailItem('Available Qty', availableQuantity),
            ],
          ),
        ],
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

  @override
  void dispose() {
    _productBarcodeController.dispose();
    _productNameController.dispose();
    _productMRPController.dispose();
    _productQuantityController.dispose();
    _productSellingPriceController.dispose();
    _productPurchasePriceController.dispose();
    _unitSearchController.dispose();
    _categorySearchController.dispose();

    for (final controller in _languageNameControllers.values) {
      if (controller != _productNameController) {
        controller.dispose();
      }
    }
    _languageNameControllers.clear();
    _languageTranslating.clear();

    // Dispose focus nodes
    _barcodeFocusNode.dispose();
    _productNameFocusNode.dispose();
    _mrpFocusNode.dispose();
    _quantityFocusNode.dispose();
    _sellingPriceFocusNode.dispose();
    _purchasePriceFocusNode.dispose();
    _unitFocusNode.dispose();
    _categoryFocusNode.dispose();

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

  Future<void> generateBarcode() async {
    if (isBarcodeGenerating) return;

    setState(() {
      isBarcodeGenerating = true;
    });

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      if (accessToken == null || accessToken.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'Authentication token not found. Please log in again.',
        );
        return;
      }

      GridSelectionProvider gridSelectionProvider =
          Provider.of<GridSelectionProvider>(context, listen: false);

      final Map<String, dynamic>? result = await gridSelectionProvider
          .generateBarcodeAPI(accessToken: accessToken);

      if (result != null &&
          result['status'] == 'success' &&
          result['data'] != null) {
        final String generatedBarcode = result['data']['barcode'];

        setState(() {
          _productBarcodeController.text = generatedBarcode;
        });

        showScaffold(
          context: context,
          message: 'Barcode generated successfully',
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
        message: 'Error generating barcode: ${e.toString()}',
      );
    } finally {
      setState(() {
        isBarcodeGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    PurchaseProvider purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    Map<String, String>? unitList = purchaseProvider.getUnitList;

    CategoryProvider categoryProvider = Provider.of<CategoryProvider>(
      context,
    );
    List<Category>? categoryList = categoryProvider.category;

    final languageProvider = Provider.of<LanguageProvider>(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: size.width * 0.45,
            maxHeight: MediaQuery.of(context).size.height * 0.75),
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
                    Text(
                      "Create New Product",
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s20,
                        0.30,
                        ColorManager.textColor,
                      ),
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
                      ? "No product found with barcode ${widget.barcode}"
                      : "Create a new product with custom barcode",
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
                        "Product Name",
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
                        "Purchase Price",
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
                        "Max Sale Price / MRP",
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

                // Row 3: Selling Price, Quantity, Empty
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Selling Price",
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
                        "Quantity",
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
                    const Expanded(
                      child: SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Close Button
                    SizedBox(
                      width: 100,
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, null),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: ColorManager.kPrimaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Close",
                          style: TextStyle(
                            color: ColorManager.kPrimaryColor,
                            fontSize: FontSize.s12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Save and Create Button
                    SizedBox(
                      width: 140,
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
                            : Text(
                                "Save and Create",
                                style: TextStyle(
                                  color: ColorManager.kPrimaryColor,
                                  fontSize: FontSize.s12,
                                ),
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
                            : const Text(
                                "Save",
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
            ),
          ),
        ),
      ),
    );
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
                      return 'Required';
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
                text: 'Barcode',
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
                      return 'Required';
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
                onPressed: widget.barcode != null || isBarcodeGenerating
                    ? null
                    : generateBarcode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorManager.kPrimaryColor,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
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
            'Loading languages...',
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
            child: const Text('Retry'),
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
          'Other Language Names',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Name (${language.name})',
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
                message: 'Translate',
                child: ElevatedButton(
                  onPressed:
                      isTranslating ? null : () => _translateLanguage(language),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorManager.kPrimaryColor,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
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
                text: 'Product Unit',
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
          hintText: "Choose Product Unit",
          value: selectedUnit,
          height: size.height * 0.048,
          margin: EdgeInsets.zero,
          items: unitList?.entries.map((entry) => entry.key).toList() ?? [],
          onChanged: (String? newValue) {
            setState(() {
              selectedUnit = newValue;
            });
          },
          displayText: (item) => unitList?[item] ?? '',
          searchController: _unitSearchController,
        ),
        if (isValidatedOnce && selectedUnit == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Required',
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
                text: 'Product Category',
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
        CustomDropDownWithSearch<Category>(
          focusNode: _categoryFocusNode,
          title: "",
          hintText: "Select Category",
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
        if (isValidatedOnce && selectedCategory == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Required',
              style: TextStyle(color: Colors.red[700], fontSize: 11),
            ),
          ),
      ],
    );
  }

  // Submit form
  Future<void> _submitForm({bool keepOpen = false}) async {
    setState(() {
      isValidatedOnce = true;
    });

    bool isFormValid = formKey.currentState!.validate();
    bool isUnitValid = selectedUnit != null;
    bool isCategoryValid = selectedCategory != null;

    if (isFormValid && isUnitValid && isCategoryValid) {
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
        );

        if (result is Map<String, dynamic> && result.containsKey('data')) {
          try {
            GetProduct product = GetProduct.fromJson(result['data']);
            Provider.of<LocalProductProvider>(context, listen: false)
                .addProduct(product);
          } catch (e) {
            debugPrint("Error parsing product: $e");
          }

          if (widget.isAddToCart) {
            Provider.of<LocalProductProvider>(context, listen: false).addToCart(
              productId: result["data"]['product_id'],
              price: double.parse(_productSellingPriceController.text),
              quantity: 1,
            );
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
          showScaffold(context: context, message: 'Product added successfully');
        } else {
          String errorMessage = 'Failed to add product';
          if (result is Map<String, dynamic>) {
            if (result.containsKey('message')) {
              errorMessage = result['message'].toString();
            } else if (result.containsKey('errors')) {
              Map<String, dynamic> errors = result['errors'];
              List<String> errorMessages = [];
              errors.forEach((field, messages) {
                if (messages is List) {
                  for (var message in messages) {
                    errorMessages.add("$field: $message");
                  }
                } else {
                  errorMessages.add("$field: $messages");
                }
              });
              errorMessage = errorMessages.join('\n');
            }
          } else if (result is String) {
            try {
              final jsonResponse = json.decode(result);
              if (jsonResponse['message'] != null) {
                errorMessage = jsonResponse['message'];
              }
            } catch (e) {
              errorMessage = result;
            }
          }
          showScaffoldError(context: context, message: errorMessage);
        }
      } catch (e) {
        showScaffoldError(
          context: context,
          message: 'Error adding product: ${e.toString()}',
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
        message: 'Please fill all required fields correctly',
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
    });
  }
}
