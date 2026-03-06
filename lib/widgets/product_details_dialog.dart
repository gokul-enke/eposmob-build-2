import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/language.dart';
import 'package:pos_machine/newcomponents/custom_container_box.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/newcomponents/custom_text_fields.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/language_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';

class _DropdownOption {
  final String id;
  final String label;

  const _DropdownOption({required this.id, required this.label});
}

class ProductDetailsDialog extends StatefulWidget {
  final GetProduct? product;
  final String? barcode; // barcode to fetch product details
  final double? unitPrice; // cart unit price (if any)
  final double? mrp; // cart mrp (if any)
  final num? quantity; // cart quantity (if any)
  final Stock? selectedStock; // selected stock (if any)
  final bool isCompact;
  final String currency;
  final VoidCallback? onAdd; // optional action button

  const ProductDetailsDialog({
    super.key,
    this.product,
    this.barcode,
    this.unitPrice,
    this.mrp,
    this.quantity,
    this.selectedStock,
    this.isCompact = false,
    this.currency = '',
    this.onAdd,
  });

  @override
  State<ProductDetailsDialog> createState() => _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends State<ProductDetailsDialog>
    with SingleTickerProviderStateMixin {
  GetProduct? selectedProduct;
  bool isLoading = false;
  late TabController _tabController;

  final GlobalKey<FormState> _editFormKey = GlobalKey<FormState>();
  bool _controllersInitialized = false;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _slugController;
  late TextEditingController _barcodeController;
  late TextEditingController _unitController;
  late TextEditingController _priceController;
  late TextEditingController _mrpController;
  late TextEditingController _quantityController;
  late TextEditingController _taxController; // Restore tax controller
  late TextEditingController _purchasePriceController;
  late TextEditingController _rackController;
  final Map<int, TextEditingController> _languageNameControllers = {};
  final Map<int, bool> _languageTranslating = {};
  bool _languagesRequested = false;

  String? _selectedCategoryId;
  Stock? _editableStock;
  String? _selectedUnitId;
  String? _selectedRackId;
  bool _requestedUnitRackData = false;
  final Map<int, Stock> _editedStockRows = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _nameController = TextEditingController();
    _slugController = TextEditingController();
    _barcodeController = TextEditingController();
    _unitController = TextEditingController();
    _priceController = TextEditingController();
    _mrpController = TextEditingController();
    _quantityController = TextEditingController();
    _purchasePriceController = TextEditingController();
    _taxController = TextEditingController(); // Init tax controller
    _rackController = TextEditingController();
    if (widget.product != null) {
      selectedProduct = widget.product;
      _initializeControllersIfNeeded();
      _ensureCategoriesLoaded();
      _ensureUnitAndRackLoaded();
    } else if (widget.barcode != null) {
      _fetchProductByBarcode(widget.barcode!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLanguages();
    });
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

    _syncLanguageNameControllersFromProduct();
    setState(() {});
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

  String _extractTranslatedName(dynamic names, Language language) {
    if (names == null) return '';
    final String targetCode = language.code.toLowerCase();

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

  void _syncLanguageNameControllersFromProduct() {
    if (selectedProduct == null) return;
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final activeLanguages = languageProvider.languages
        .where((language) => language.active)
        .toList(growable: false);

    for (final language in activeLanguages) {
      final controller = _languageNameControllers.putIfAbsent(
        language.id,
        () => TextEditingController(),
      );
      final translatedName =
          _extractTranslatedName(selectedProduct!.names, language);
      if (translatedName.isNotEmpty || controller.text.isEmpty) {
        controller.text = translatedName;
      }
      _languageTranslating.putIfAbsent(language.id, () => false);
    }
  }

  Future<void> _translateLanguage(Language language) async {
    final baseText = _nameController.text.trim();
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
      _languageNameControllers.putIfAbsent(
          language.id, () => TextEditingController());
      _languageNameControllers[language.id]!.text = translated;
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

  List<Map<String, dynamic>> _buildProductNamesPayload(
      List<Language> languages) {
    final payload = <Map<String, dynamic>>[];
    for (final language in languages) {
      final text = _languageNameControllers[language.id]?.text.trim() ?? '';
      if (text.isNotEmpty) {
        payload.add({
          'language_id': language.id,
          'name': text,
        });
      }
    }
    return payload;
  }

  Future<void> _fetchProductByBarcode(String barcode) async {
    setState(() {
      isLoading = true;
    });

    try {
      final productProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      // Search for product by barcode in the products list
      GetProduct? product;
      try {
        product = productProvider.products.firstWhere(
          (p) =>
              p.barcode != null &&
              p.barcode!.toString().trim() == barcode.trim(),
        );
      } catch (e) {
        // Product not found
        product = null;
      }

      setState(() {
        selectedProduct = product;
        isLoading = false;
        _controllersInitialized = false;
      });
      _initializeControllersIfNeeded();
      _ensureCategoriesLoaded();
      _ensureUnitAndRackLoaded();

      if (product == null && mounted) {
        showScaffoldError(
          context: context,
          message: 'Product with barcode "$barcode" not found',
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Error fetching product: $e',
        );
      }
    }
  }

  void _ensureCategoriesLoaded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      categoryProvider.ensureCategoriesLoaded();
    });
  }

  void _ensureUnitAndRackLoaded() {
    if (_requestedUnitRackData) return;
    _requestedUnitRackData = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final purchaseProvider =
          Provider.of<PurchaseProvider>(context, listen: false);
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final token = authModel.token;
      if (token == null || token.isEmpty) {
        return;
      }

      if ((purchaseProvider.getUnitList == null ||
          purchaseProvider.getUnitList!.isEmpty)) {
        await purchaseProvider.listAllUnits(token);
      }
      if ((purchaseProvider.getMasterDataValues == null ||
          purchaseProvider.getMasterDataValues!.isEmpty)) {
        await purchaseProvider.listMasterDataValues(token, 'RACKS');
      }
      if (!mounted) return;
      setState(_resolveUnitAndRackSelection);
    });
  }

  void _resolveUnitAndRackSelection() {
    final purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    final unitMap = purchaseProvider.getUnitList ?? {};
    if (_selectedUnitId != null && !unitMap.containsKey(_selectedUnitId)) {
      _selectedUnitId = null;
    }
    if (_selectedUnitId == null && _unitController.text.isNotEmpty) {
      final match = unitMap.entries.firstWhere(
        (entry) =>
            entry.value.toLowerCase() == _unitController.text.toLowerCase(),
        orElse: () => const MapEntry('', ''),
      );
      if (match.key.isNotEmpty) {
        _selectedUnitId = match.key;
      }
    }

    final rackMap = purchaseProvider.getMasterDataValues ?? {};
    if (_selectedRackId != null && !rackMap.containsKey(_selectedRackId)) {
      _selectedRackId = null;
    }
    if (_selectedRackId == null && _rackController.text.isNotEmpty) {
      final match = rackMap.entries.firstWhere(
        (entry) =>
            entry.value.toLowerCase() == _rackController.text.toLowerCase(),
        orElse: () => const MapEntry('', ''),
      );
      if (match.key.isNotEmpty) {
        _selectedRackId = match.key;
      }
    }
  }

  void _initializeControllersIfNeeded() {
    if (selectedProduct == null || _controllersInitialized) {
      return;
    }

    final product = selectedProduct!;
    _nameController.text = product.productName ?? '';
    _slugController.text = product.productSlug ?? '';
    _barcodeController.text = product.barcode ?? '';
    _unitController.text = product.unit ?? '';
    _priceController.text = _valueToString(product.price?.price);
    _mrpController.text = _valueToString(product.mrp);
    _quantityController.text = '';
    // 🔧 FIX: Revert to Tax Rate (Percentage) as requested
    // We display the static rate, no longer the calculated amount
    _taxController.text = _valueToString(product.totalTaxRate);
    _purchasePriceController.text = product.purchasePrice ??
        (product.stock != null && product.stock!.isNotEmpty
            ? product.stock!.first.purchasePrice
            : '') ??
        '';

    _editableStock = widget.selectedStock ??
        (product.stock != null && product.stock!.isNotEmpty
            ? product.stock!.first
            : null);
    _rackController.text = _editableStock?.rack ?? '';

    _selectedCategoryId = product.categoryId?.toString();
    _selectedUnitId = null;
    _selectedRackId = null;

    _resolveUnitAndRackSelection();
    _syncLanguageNameControllersFromProduct();
    _controllersInitialized = true;
  }

  String _valueToString(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      return value.toString();
    }
    return value.toString();
  }

  Future<void> _handleSave() async {
    if (!_controllersInitialized || selectedProduct == null) {
      return;
    }

    if (!_editFormKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    final product = selectedProduct!;
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);

    final String updatedName = _nameController.text.trim();
    final String updatedSlug = _slugController.text.trim();
    final String updatedBarcode = _barcodeController.text.trim();
    final String updatedUnit = _unitController.text.trim();
    final String updatedPriceString = _priceController.text.trim();
    final String updatedMrpString = _mrpController.text.trim();
    final String updatedQuantityString = _quantityController.text.trim();
    final String updatedPurchasePrice = _purchasePriceController.text.trim();
    final String updatedRack = _rackController.text.trim();

    final double priceForApi = updatedPriceString.isEmpty
        ? double.tryParse(product.price?.price?.toString() ?? '') ?? 0
        : double.tryParse(updatedPriceString) ?? 0;

    final double mrpForApi = updatedMrpString.isEmpty
        ? double.tryParse(product.mrp?.toString() ?? '') ?? 0
        : double.tryParse(updatedMrpString) ?? 0;
    final double? purchasePriceForApi = updatedPurchasePrice.isEmpty
        ? double.tryParse(product.purchasePrice ?? '')
        : double.tryParse(updatedPurchasePrice);
    final num? quantityForApi = updatedQuantityString.isEmpty
        ? null
        : num.tryParse(updatedQuantityString);

    final double updatedPriceValue = priceForApi;
    final double updatedMrpValue = mrpForApi;

    final int? resolvedCategoryId = _selectedCategoryId != null
        ? int.tryParse(_selectedCategoryId!)
        : product.categoryId;

    final int? rackNumber = updatedRack.isNotEmpty
        ? int.tryParse(updatedRack)
        : int.tryParse(_editableStock?.rack ?? '');

    final authModel = Provider.of<AuthModel>(context, listen: false);
    final String? accessToken = authModel.token;
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final activeLanguages = languageProvider.languages
        .where((language) => language.active)
        .toList(growable: false);
    final productNames = _buildProductNamesPayload(activeLanguages);

    if (accessToken == null || accessToken.isEmpty) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        showScaffoldError(
          context: context,
          message: 'Authentication token not found.',
        );
      }
      return;
    }

    try {
      final String productId = (product.productId ?? '').toString();
      if (productId.isEmpty) {
        throw const HttpException('Product ID missing.');
      }

      final int? rackForApi = int.tryParse(_selectedRackId ?? '') ?? rackNumber;

      final response = await productProvider.editProduct(
        productId: int.parse(productId),
        name: updatedName,
        slug: updatedSlug,
        barcode: updatedBarcode,
        unit: updatedUnit.isEmpty
            ? (_selectedUnitId ?? product.unit ?? '')
            : (_selectedUnitId ?? updatedUnit),
        unitId: _selectedUnitId,
        price: priceForApi,
        mrp: mrpForApi,
        purchasePrice: purchasePriceForApi,
        categoryId: resolvedCategoryId,
        rackNumber: rackForApi,
        quantity: quantityForApi,
        productNames: productNames.isNotEmpty ? productNames : null,
        accessToken: accessToken,
      );

      final String successMessage = response['message']?.toString() ??
          'Product details updated successfully.';

      ProductPrice? updatedProductPrice;
      if (product.price != null) {
        updatedProductPrice = ProductPrice(
          oldPrice: product.price!.oldPrice,
          price: updatedPriceString.isEmpty
              ? product.price!.price
              : updatedPriceString,
          percentage: product.price!.percentage,
          totalPrice: product.price!.totalPrice,
        );
      } else if (updatedPriceString.isNotEmpty) {
        updatedProductPrice = ProductPrice(price: updatedPriceString);
      }

      final purchaseProvider =
          Provider.of<PurchaseProvider>(context, listen: false);
      final unitMap = purchaseProvider.getUnitList ?? {};

      String resolvedUnitLabel =
          updatedUnit.isEmpty ? (product.unit ?? '') : updatedUnit;
      String? resolvedUnitId = _selectedUnitId;
      if (resolvedUnitId != null) {
        final mappedLabel = unitMap[resolvedUnitId];
        if (mappedLabel != null && mappedLabel.isNotEmpty) {
          resolvedUnitLabel = mappedLabel;
        }
      } else if (resolvedUnitLabel.isNotEmpty) {
        final match = unitMap.entries.firstWhere(
          (entry) =>
              entry.value.toLowerCase() == resolvedUnitLabel.toLowerCase(),
          orElse: () => const MapEntry('', ''),
        );
        if (match.key.isNotEmpty) {
          resolvedUnitId = match.key;
          resolvedUnitLabel = match.value;
        }
      }

      Category? selectedCategory;
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      if (_selectedCategoryId != null &&
          categoryProvider.category != null &&
          categoryProvider.category!.isNotEmpty) {
        selectedCategory = categoryProvider.category!.firstWhere(
          (category) => category.categoryId?.toString() == _selectedCategoryId,
          orElse: () => categoryProvider.category!.first,
        );
      }

      final GetProduct updatedProduct = GetProduct(
        productId: product.productId,
        categoryId: resolvedCategoryId,
        productName: updatedName,
        productSlug: updatedSlug,
        barcode: updatedBarcode,
        category: selectedCategory != null
            ? ProductCategory(
                name: selectedCategory.categoryName,
                slug: selectedCategory.categorySlug,
              )
            : product.category,
        numberOfProductsAvailable: product.numberOfProductsAvailable,
        rating: product.rating,
        unit: resolvedUnitLabel.isEmpty ? product.unit : resolvedUnitLabel,
        currency: product.currency,
        description: product.description,
        price: updatedProductPrice,
        mrp: updatedMrpString.isEmpty ? product.mrp : updatedMrpString,
        taxes: [
          ProductTax(
              rate: (double.tryParse(_taxController.text) ?? 0.0).toString(),
              name: "Tax",
              code: "TAX",
              source: "manual")
        ],
        purchasePrice: updatedPurchasePrice.isEmpty
            ? product.purchasePrice
            : updatedPurchasePrice,
        attachment: product.attachment,
        names: productNames.isNotEmpty ? productNames : product.names,
        productProps: product.productProps,
        weightInfo: product.weightInfo,
        stock: product.stock,
        sku: product.sku,
        offerPrice: product.offerPrice,
        productLocation: product.productLocation,
        hsnCode: product.hsnCode,
      );

      localProductProvider.updateProduct(updatedProduct);

      final updatedTaxValue = double.tryParse(_taxController.text) ?? 0.0;
      localProductProvider.updateProductPricingInCart(
        updatedProduct.productId ?? 0,
        updatedPriceValue,
        updatedMrpValue,
        updatedTaxValue,
      );

      if (!mounted) return;
      setState(() {
        selectedProduct = updatedProduct;
        _controllersInitialized = false;
        _initializeControllersIfNeeded();
        _isSaving = false;
        _tabController.index = 0;
      });

      showScaffold(
        context: context,
        message: successMessage,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        showScaffoldError(
          context: context,
          message: error.toString(),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _slugController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _quantityController.dispose();
    _taxController.dispose(); // Restore dispose
    _purchasePriceController.dispose();
    _rackController.dispose();
    for (final controller in _languageNameControllers.values) {
      controller.dispose();
    }
    _languageNameControllers.clear();
    _languageTranslating.clear();
    super.dispose();
  }

  Widget _buildLanguageFields(
    Size size,
    double fieldHeight,
    double fieldWidth,
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
              0.20,
              ColorManager.textColor.withOpacity(0.7),
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
                0.20,
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
    final baseLanguage = _getBaseLanguage(languages);
    final extraLanguages = languages
        .where((lang) => baseLanguage == null || lang.id != baseLanguage.id)
        .toList(growable: false);

    if (extraLanguages.isEmpty) {
      return const SizedBox.shrink();
    }

    // Initialize controllers for all languages
    for (final language in extraLanguages) {
      _languageNameControllers.putIfAbsent(
        language.id,
        () => TextEditingController(
          text: _extractTranslatedName(selectedProduct?.names, language),
        ),
      );
      _languageTranslating.putIfAbsent(language.id, () => false);
    }

    if (extraLanguages.isEmpty) {
      return const SizedBox.shrink();
    }

    const double horizontalGap = 12;

    // Group languages into rows of 3
    final List<Widget> rows = [];
    for (int i = 0; i < extraLanguages.length; i += 3) {
      final end = (i + 3).clamp(0, extraLanguages.length);
      final rowLanguages = extraLanguages.sublist(i, end);

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...rowLanguages.asMap().entries.map((entry) {
                final idx = entry.key;
                final language = entry.value;
                final controller = _languageNameControllers[language.id]!;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: idx > 0 ? horizontalGap : 0),
                    child: _buildEditLanguageField(
                      size,
                      language,
                      controller,
                      fieldHeight,
                    ),
                  ),
                );
              }),
              // Padding for incomplete rows
              ...List.generate(
                3 - rowLanguages.length,
                (i) => const Expanded(child: SizedBox.shrink()),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ...rows,
      ],
    );
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
              softWrap: true, // Enable text wrapping
              overflow: TextOverflow
                  .visible, // Allow text to wrap instead of truncating
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditLanguageField(
    Size size,
    Language language,
    TextEditingController controller,
    double fieldHeight,
  ) {
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
                height: fieldHeight,
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
            const SizedBox(width: 6),
            SizedBox(
              height: fieldHeight,
              width: fieldHeight,
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

  Widget _buildViewTab(GetProduct product) {
    final currency = Provider.of<AppSettingsProvider>(context, listen: true)
            .appSettings
            ?.currency ??
        'INR';
    return ListView(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildDetailRow('Product Name', product.productName ?? 'N/A'),
                  _buildDetailRow('Slug', product.productSlug ?? 'N/A'),
                  _buildDetailRow('Category', product.category?.name ?? 'N/A'),
                  _buildDetailRow('Barcode', product.barcode ?? 'N/A'),
                  _buildDetailRow('Unit', product.unit ?? 'N/A'),
                  if (product.taxes != null && product.taxes!.isNotEmpty)
                    ...product.taxes!.map((tax) => _buildDetailRow(
                          tax.name ?? 'Tax',
                          '${tax.rate ?? 0}%',
                        )),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  _buildDetailRow(
                      'Price',
                      product.price?.price != null
                          ? '$currency ${product.price!.price}'
                          : 'N/A'),
                  _buildDetailRow('MRP',
                      product.mrp != null ? '$currency ${product.mrp}' : 'N/A'),
                  _buildDetailRow(
                    'Purchase Price',
                    (product.purchasePrice != null &&
                            product.purchasePrice!.isNotEmpty
                        ? '$currency ${product.purchasePrice}'
                        : (product.stock != null && product.stock!.isNotEmpty
                            ? (product.stock!.first.purchasePrice != null &&
                                    product
                                        .stock!.first.purchasePrice!.isNotEmpty
                                ? '$currency ${product.stock!.first.purchasePrice}'
                                : 'N/A')
                            : 'N/A')),
                  ),
                  _buildDetailRow(
                      'Offer Price',
                      product.offerPrice != null
                          ? '$currency ${product.offerPrice}'
                          : 'N/A'),
                  _buildDetailRow('SKU', product.sku ?? 'Not Available'),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  _buildDetailRow('Rating', product.rating ?? 'N/A'),
                  _buildDetailRow('Available Qty',
                      product.numberOfProductsAvailable ?? 'N/A'),
                  _buildDetailRow(
                      'Location', product.productLocation?.toString() ?? 'N/A'),
                  if (product.weightInfo != null) ...[
                    _buildDetailRow('Weight',
                        product.weightInfo!.weight?.toString() ?? 'N/A'),
                    _buildDetailRow('Is Weighted',
                        product.weightInfo!.isWeighted == true ? 'Yes' : 'No'),
                  ] else ...[
                    _buildDetailRow('Weight', 'N/A'),
                    _buildDetailRow('Is Weighted', 'N/A'),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (product.description != null &&
            product.description.toString().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Description',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.20,
              ColorManager.kPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Text(
              product.description.toString(),
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
        ],
        if (product.productProps != null &&
            product.productProps!.isNotEmpty &&
            product.productProps!.any((prop) =>
                (prop.label?.isNotEmpty ?? false) ||
                (prop.masterValue?.isNotEmpty ?? false))) ...[
          const SizedBox(height: 16),
          Text(
            'Product Properties',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.20,
              ColorManager.kPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: product.productProps!
                  .where((prop) =>
                      (prop.label?.isNotEmpty ?? false) ||
                      (prop.masterValue?.isNotEmpty ?? false))
                  .map((prop) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ColorManager.kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: ColorManager.kPrimaryColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${prop.label ?? ''}: ${prop.masterValue ?? ''}',
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.18,
                      ColorManager.kPrimaryColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Stock Information',
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s16,
            0.20,
            ColorManager.kPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        if (product.stock != null && product.stock!.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: ColorManager.tableBGColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(0.6),
                      1: FlexColumnWidth(1.2),
                      2: FlexColumnWidth(1.2),
                      3: FlexColumnWidth(1.2),
                      4: FlexColumnWidth(1.2),
                      5: FlexColumnWidth(1.4),
                      6: FlexColumnWidth(1.4),
                      7: FlexColumnWidth(1.0),
                      8: FlexColumnWidth(1.2),
                      9: FlexColumnWidth(1.2),
                      10: FlexColumnWidth(1.0),
                      11: FlexColumnWidth(0.8),
                    },
                    border: null,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        children: [
                          _buildStockTableHeader('Sl No'),
                          _buildStockTableHeader('Quantity'),
                          _buildStockTableHeader('Price'),
                          _buildStockTableHeader('MRP'),
                          _buildStockTableHeader('Purchase Price'),
                          _buildStockTableHeader('Supplier'),
                          _buildStockTableHeader('Store Name'),
                          _buildStockTableHeader('SKU'),
                          _buildStockTableHeader('Date'),
                          _buildStockTableHeader('Expiry Date'),
                          _buildStockTableHeader('Rack'),
                          _buildStockTableHeader('Action'),
                        ],
                      ),
                    ],
                  ),
                ),
                ...product.stock!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final originalStock = entry.value;
                  final stock = originalStock.id != null
                      ? (_editedStockRows[originalStock.id!] ?? originalStock)
                      : originalStock;
                  return Container(
                    decoration: BoxDecoration(
                      color: index % 2 == 0
                          ? Colors.white
                          : Colors.grey.withOpacity(0.05),
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(0.6),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(1.2),
                        5: FlexColumnWidth(1.4),
                        6: FlexColumnWidth(1.4),
                        7: FlexColumnWidth(1.0),
                        8: FlexColumnWidth(1.2),
                        9: FlexColumnWidth(1.2),
                        10: FlexColumnWidth(1.0),
                        11: FlexColumnWidth(0.8),
                      },
                      border: null,
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          children: [
                            _buildStockTableCell('${index + 1}'),
                            _buildStockTableCell(
                                stock.quantity?.toString() ?? 'N/A'),
                            _buildStockTableCell(
                                stock.price != null && stock.price!.isNotEmpty
                                    ? '$currency ${stock.price}'
                                    : 'N/A'),
                            _buildStockTableCell(
                                stock.mrp != null && stock.mrp!.isNotEmpty
                                    ? '$currency ${stock.mrp}'
                                    : 'N/A'),
                            _buildStockTableCell(stock.purchasePrice != null &&
                                    stock.purchasePrice!.isNotEmpty
                                ? '$currency ${stock.purchasePrice}'
                                : 'N/A'),
                            _buildStockTableCell(stock.supplier ?? 'N/A'),
                            _buildStockTableCell(stock.storeName ?? 'N/A'),
                            _buildStockTableCell(stock.sku ?? 'N/A'),
                            _buildStockTableCell(stock.date ?? 'N/A'),
                            _buildStockTableCell(stock.expiryDate ?? 'N/A'),
                            _buildStockTableCell(stock.rack ?? 'N/A'),
                            _buildRackTableCell(stock),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                'No stock information available',
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s14,
                  0.20,
                  Colors.grey[600]!,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEditTab(GetProduct product) {
    final size = MediaQuery.of(context).size;
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final categories = (categoryProvider.category ?? [])
        .where((category) => category.categoryId != null)
        .toList();
    final languageProvider = Provider.of<LanguageProvider>(context);
    final purchaseProvider = Provider.of<PurchaseProvider>(context);
    final unitOptions = (purchaseProvider.getUnitList ?? {})
        .entries
        .map((entry) => _DropdownOption(id: entry.key, label: entry.value))
        .where((option) => option.label.isNotEmpty)
        .toList();
    // final rackOptions = (purchaseProvider.getMasterDataValues ?? {})
    //     .entries
    //     .map((entry) => _DropdownOption(id: entry.key, label: entry.value))
    //     .where((option) => option.label.isNotEmpty)
    //     .toList();

    Category? selectedCategory;
    if (_selectedCategoryId != null) {
      try {
        selectedCategory = categories.firstWhere(
          (category) => category.categoryId?.toString() == _selectedCategoryId,
        );
      } catch (_) {
        selectedCategory = null;
      }
    }

    _DropdownOption? _findSelectedOption(
        List<_DropdownOption> options, String? id) {
      if (id == null) return null;
      try {
        return options.firstWhere((option) => option.id == id);
      } catch (_) {
        return null;
      }
    }

    final _DropdownOption? selectedUnitOption =
        _findSelectedOption(unitOptions, _selectedUnitId);
    // final _DropdownOption? selectedRackOption =
    //     _findSelectedOption(rackOptions, _selectedRackId);

    return Form(
      key: _editFormKey,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double horizontalGap = 12;
            const double verticalGap = 2;
            const double contentHorizontalPadding = 16;
            final double availableWidth =
                constraints.maxWidth > contentHorizontalPadding
                    ? constraints.maxWidth - contentHorizontalPadding
                    : constraints.maxWidth;
            final double fieldWidth = availableWidth > 0
                ? (availableWidth - (horizontalGap * 2)) / 3
                : size.width / 3.5;
            final double fieldHeight = size.height * 0.05;

            Widget spacing() => const SizedBox(width: horizontalGap);

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: buildColumnWidgetForTextFields(
                            controller: _nameController,
                            size: size,
                            title: 'Product Name',
                            hintText: 'Enter product name',
                            width: fieldWidth,
                            height: fieldHeight,
                            margin: EdgeInsets.zero,
                            readOnly: false,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Required'
                                    : null,
                            onchanged: (value) {
                              if (value == null) return;
                              final slug = value
                                  .trim()
                                  .toLowerCase()
                                  .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                                  .replaceAll(RegExp(r'-+'), '-')
                                  .replaceAll(RegExp(r'^-|-$'), '');
                              _slugController.text = slug;
                            },
                          ),
                        ),
                        spacing(),
                        SizedBox(
                          width: fieldWidth,
                          child: buildColumnWidgetForTextFields(
                            controller: _slugController,
                            size: size,
                            title: 'Slug',
                            hintText: 'Enter slug',
                            width: fieldWidth,
                            height: fieldHeight,
                            margin: EdgeInsets.zero,
                            readOnly: false,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Required'
                                    : null,
                          ),
                        ),
                        spacing(),
                        SizedBox(
                          width: fieldWidth,
                          child: buildColumnWidgetForTextFields(
                            controller: _barcodeController,
                            size: size,
                            title: 'Barcode',
                            hintText: 'Enter barcode',
                            width: fieldWidth,
                            height: fieldHeight,
                            margin: EdgeInsets.zero,
                            readOnly: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: verticalGap),
                    _buildLanguageFields(
                      size,
                      fieldHeight,
                      fieldWidth,
                      languageProvider,
                    ),
                    const SizedBox(height: verticalGap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: CustomDropDownWithSearch<Category>(
                            title: 'Category',
                            hintText: 'Select category',
                            value: selectedCategory,
                            items: categories,
                            height: fieldHeight,
                            margin: EdgeInsets.zero,
                            onChanged: (category) {
                              setState(() {
                                _selectedCategoryId =
                                    category?.categoryId?.toString();
                              });
                            },
                            displayText: (category) =>
                                category.categoryName ?? 'Unknown',
                            isRequired: true,
                            width: fieldWidth,
                            searchHintText: 'Search category...',
                            autofocus: false,
                          ),
                        ),
                        spacing(),
                        SizedBox(
                          width: fieldWidth,
                          child: CustomDropDownWithSearch<_DropdownOption>(
                            title: 'Unit',
                            hintText: 'Select unit',
                            value: selectedUnitOption,
                            items: unitOptions,
                            onChanged: (option) {
                              setState(() {
                                _selectedUnitId = option?.id;
                                _unitController.text = option?.label ?? '';
                              });
                            },
                            displayText: (option) => option.label,
                            isRequired: true,
                            width: fieldWidth,
                            height: fieldHeight,
                            margin: EdgeInsets.zero,
                            searchHintText: 'Search unit...',
                            autofocus: false,
                          ),
                        ),
                        spacing(),
                        SizedBox(
                          width: fieldWidth,
                          child: buildColumnWidgetForTextFields(
                            controller: _priceController,
                            size: size,
                            title: 'Price',
                            hintText: 'Enter price',
                            width: fieldWidth,
                            height: fieldHeight,
                            margin: EdgeInsets.zero,
                            readOnly: false,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: verticalGap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: buildColumnWidgetForTextFields(
                            controller: _quantityController,
                            size: size,
                            title: 'Quantity',
                            hintText: 'Enter quantity',
                            width: fieldWidth,
                            height: fieldHeight,
                            margin: EdgeInsets.zero,
                            readOnly: false,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: false,
                            ),
                          ),
                        ),
                        spacing(),
                        SizedBox(
                          width: fieldWidth,
                          child: buildColumnWidgetForTextFields(
                            controller: _mrpController,
                            size: size,
                            title: 'MRP',
                            hintText: 'Enter MRP',
                            width: fieldWidth,
                            height: fieldHeight,
                            margin: EdgeInsets.zero,
                            readOnly: false,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                        spacing(),
                        SizedBox(
                          width: fieldWidth,
                          child: buildColumnWidgetForTextFields(
                            controller: _purchasePriceController,
                            size: size,
                            title: 'Purchase Price',
                            hintText: 'Enter purchase price',
                            width: fieldWidth,
                            height: fieldHeight,
                            margin: EdgeInsets.zero,
                            readOnly: false,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                        spacing(),
                        // SizedBox(
                        //   width: fieldWidth,
                        //   child: CustomDropDownWithSearch<_DropdownOption>(
                        //     title: 'Rack',
                        //     hintText: 'Select rack',
                        //     value: selectedRackOption,
                        //     items: rackOptions,
                        //     onChanged: (option) {
                        //       setState(() {
                        //         _selectedRackId = option?.id;
                        //         _rackController.text = option?.label ?? '';
                        //       });
                        //     },
                        //     displayText: (option) => option.label,
                        //     isRequired: false,
                        //     width: fieldWidth,
                        //     height: fieldHeight,
                        //     margin: EdgeInsets.zero,
                        //     searchHintText: 'Search rack...',
                        //     autofocus: false,
                        //   ),
                        // ),
                      ],
                    ),
                    const SizedBox(height: verticalGap),
                    // if (product.stock != null && product.stock!.isNotEmpty)
                    //   Text(
                    //     'Price and MRP changes apply to all stock entries for this product.',
                    //     style: buildCustomStyle(
                    //       FontWeightManager.medium,
                    //       FontSize.s12,
                    //       0.20,
                    //       ColorManager.textColor.withOpacity(0.7),
                    //     ),
                    //   ),
                    // const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStockTableHeader(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Center(
          child: Text(
            text,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s14,
              0.18,
              ColorManager.kPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockTableCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Center(
          child: Text(
            text,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s13,
              0.18,
              Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockEditField(
    String label,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.20,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 4),
        CustomBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 45,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Enter $label',
              hintStyle: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s11,
                0.20,
                ColorManager.textColor.withOpacity(0.5),
              ),
            ),
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.20,
              ColorManager.textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRackTableCell(Stock stock) {
    final bool canEdit = stock.id != null;

    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        child: Center(
          child: InkWell(
            onTap: canEdit ? () => _showEditStockRowModal(stock) : null,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color:
                    canEdit ? ColorManager.kPrimaryColor : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.edit,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditStockRowModal(Stock stock) {
    if (stock.id == null) {
      showScaffoldError(
        context: context,
        message: 'Stock id missing. Unable to edit this row.',
      );
      return;
    }

    final TextEditingController retailPriceController =
        TextEditingController(text: stock.price ?? '');
    final TextEditingController mrpController =
        TextEditingController(text: stock.mrp ?? '');
    final TextEditingController purchasePriceController =
        TextEditingController(text: stock.purchasePrice ?? '');
    final TextEditingController quantityController =
        TextEditingController(text: stock.quantity?.toString() ?? '0');
    final TextEditingController rackController =
        TextEditingController(text: stock.rack ?? '');

    final purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    final rackMap = purchaseProvider.getMasterDataValues ?? {};
    String? selectedRackId;

    if ((stock.rack ?? '').isNotEmpty && rackMap.isNotEmpty) {
      final match = rackMap.entries.firstWhere(
        (entry) =>
            entry.value.toLowerCase() == stock.rack!.toLowerCase() ||
            entry.key == stock.rack,
        orElse: () => const MapEntry('', ''),
      );
      if (match.key.isNotEmpty) {
        selectedRackId = match.key;
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 8,
              backgroundColor: Colors.white,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.55,
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Stock',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s20,
                            0.20,
                            Colors.black,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStockEditField(
                                    'Retail Price',
                                    retailPriceController,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStockEditField(
                                    'MRP',
                                    mrpController,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStockEditField(
                                    'Purchase Price',
                                    purchasePriceController,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStockEditField(
                                    'Quantity',
                                    quantityController,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rack',
                                  style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s12,
                                    0.20,
                                    ColorManager.textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (rackMap.isNotEmpty)
                                  CustomDropDownWithSearch<_DropdownOption>(
                                    hintText: 'Select rack',
                                    value: selectedRackId != null
                                        ? _DropdownOption(
                                            id: selectedRackId!,
                                            label:
                                                rackMap[selectedRackId] ?? '',
                                          )
                                        : null,
                                    items: rackMap.entries
                                        .map((entry) => _DropdownOption(
                                              id: entry.key,
                                              label: entry.value,
                                            ))
                                        .toList(),
                                    onChanged: (option) {
                                      setDialogState(() {
                                        selectedRackId = option?.id;
                                        rackController.text =
                                            option?.label ?? '';
                                      });
                                    },
                                    displayText: (option) => option.label,
                                    isRequired: false,
                                    width: double.infinity,
                                    height: 45,
                                    margin: EdgeInsets.zero,
                                    searchHintText: 'Search rack...',
                                    autofocus: false,
                                  )
                                else
                                  _buildStockEditField('Rack', rackController),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CustomRoundButton(
                          title: 'Cancel',
                          boxColor: Colors.white,
                          textColor: ColorManager.kPrimaryColor,
                          borderColor: ColorManager.kPrimaryColor,
                          fct: () => Navigator.pop(dialogContext),
                          height: 42,
                          width: 110,
                          fontSize: FontSize.s12,
                        ),
                        const SizedBox(width: 12),
                        CustomRoundButton(
                          title: 'Update',
                          boxColor: ColorManager.kPrimaryColor,
                          textColor: Colors.white,
                          fct: () async {
                            final String? accessToken =
                                Provider.of<AuthModel>(context, listen: false)
                                    .token;
                            if (accessToken == null || accessToken.isEmpty) {
                              showScaffoldError(
                                context: context,
                                message: 'Authentication token is missing',
                              );
                              return;
                            }

                            showDialog(
                              context: dialogContext,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            final bool success =
                                await Provider.of<StockProvider>(
                              context,
                              listen: false,
                            ).updateStockDetails(
                              stockId: stock.id!,
                              retailPrice: retailPriceController.text.trim(),
                              mrp: mrpController.text.trim(),
                              purchasePrice:
                                  purchasePriceController.text.trim(),
                              quantity: quantityController.text.trim(),
                              rack: rackController.text.trim(),
                              accessToken: accessToken,
                            );

                            if (mounted) {
                              Navigator.of(dialogContext, rootNavigator: true)
                                  .pop();
                            }

                            if (!mounted) return;

                            if (success) {
                              final num? updatedQty = num.tryParse(
                                      quantityController.text.trim()) ??
                                  stock.quantity;
                              setState(() {
                                _editedStockRows[stock.id!] = Stock(
                                  id: stock.id,
                                  productId: stock.productId,
                                  storeName: stock.storeName,
                                  supplier: stock.supplier,
                                  quantity: updatedQty,
                                  price: retailPriceController.text.trim(),
                                  sku: stock.sku,
                                  mrp: mrpController.text.trim(),
                                  unit: stock.unit,
                                  purchasePrice:
                                      purchasePriceController.text.trim(),
                                  date: stock.date,
                                  expiryDate: stock.expiryDate,
                                  rack: rackController.text.trim(),
                                  hsnCode: stock.hsnCode,
                                );
                              });
                              Navigator.pop(dialogContext);
                              showScaffold(
                                context: context,
                                message: 'Stock updated successfully',
                              );
                            } else {
                              showScaffoldError(
                                context: context,
                                message: 'Failed to update stock',
                              );
                            }
                          },
                          height: 42,
                          width: 110,
                          fontSize: FontSize.s12,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading product details...'),
            ],
          ),
        ),
      );
    }

    if (selectedProduct == null) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Product not found'),
              const SizedBox(height: 16),
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
        ),
      );
    }

    final product = selectedProduct!;
    _initializeControllersIfNeeded();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width *
              0.9, // Increased from 0.8 to 0.9
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          minWidth: 600, // Add minimum width to ensure adequate space
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
                  'Product Details',
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
            if (_isSaving) const SizedBox(height: 12),
            if (_isSaving) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              labelColor: ColorManager.kPrimaryColor,
              unselectedLabelColor: ColorManager.textColor.withOpacity(0.6),
              indicatorColor: ColorManager.kPrimaryColor,
              tabs: const [
                Tab(text: 'View'),
                Tab(text: 'Edit'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildViewTab(product),
                  _buildEditTab(product),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_tabController.index == 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: CustomRoundButton(
                      title: _isSaving ? "Saving..." : "Save",
                      fct: _isSaving ? () {} : _handleSave,
                      height: 45,
                      width: 140,
                      fontSize: FontSize.s12,
                      boxColor: ColorManager.kPrimaryColor,
                      textColor: Colors.white,
                    ),
                  ),
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
    );
  }
}
