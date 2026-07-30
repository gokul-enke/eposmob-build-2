import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/widgets/edit_stock_dialog.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/features/products/domain/variant_form_payload.dart';
import 'package:pos_machine/features/products/presentation/variant_editor_section.dart';
import 'package:pos_machine/features/billing/domain/add_product_form_helpers.dart';
import 'package:pos_machine/features/billing/presentation/widgets/product_variant_details_section.dart';
import 'package:pos_machine/providers/store_session_provider.dart';

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
  final int? selectedVariantId;
  final bool isCompact;
  final String currency;
  final VoidCallback? onAdd; // optional action button
  /// When true, Edit tab / save / stock-row edit require `billing.product.edit`.
  final bool useBillingProductPermissions;

  const ProductDetailsDialog({
    super.key,
    this.product,
    this.barcode,
    this.unitPrice,
    this.mrp,
    this.quantity,
    this.selectedStock,
    this.selectedVariantId,
    this.isCompact = false,
    this.currency = '',
    this.onAdd,
    this.useBillingProductPermissions = false,
  });

  @override
  State<ProductDetailsDialog> createState() => _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends State<ProductDetailsDialog>
    with SingleTickerProviderStateMixin {
  GetProduct? selectedProduct;
  bool isLoading = false;
  late TabController _tabController;
  bool _tabControllerReady = false;
  final ScrollController _stockScrollController = ScrollController();

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
  late TextEditingController _minMarginController;
  late TextEditingController _minMarginPriceController;
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
  final List<AddProductSaleUnitRow> _saleUnitRows = [];
  bool _showSaleUnitOptions = false;
  bool _saleUnitsTouched = false;

  final VariantEditorController _variantController = VariantEditorController();
  bool _variantPropertiesRequested = false;
  bool _isLoadingVariantProperties = false;
  bool _variantsPrefilled = false;

  bool _canEditProduct(BuildContext context) {
    final roleProvider = Provider.of<RoleProvider>(context, listen: false);
    if (widget.useBillingProductPermissions) {
      return roleProvider.currentUserHasPermissionSync('billing.product.edit');
    }
    return roleProvider.currentUserHasPermissionSync('update_product') ||
        roleProvider
            .currentUserHasPermissionSync('menu.catalog.product.list.access');
  }

  void _ensureTabController(bool canEdit) {
    final tabCount = canEdit ? 2 : 1;
    if (!_tabControllerReady) {
      _tabControllerReady = true;
      _tabController = TabController(length: tabCount, vsync: this);
      _tabController.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      return;
    }
    if (_tabController.length == tabCount) {
      return;
    }
    final previousIndex = _tabController.index.clamp(0, tabCount - 1);
    _tabController.dispose();
    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: previousIndex,
    );
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _slugController = TextEditingController();
    _barcodeController = TextEditingController();
    _unitController = TextEditingController();
    _priceController = TextEditingController();
    _mrpController = TextEditingController();
    _quantityController = TextEditingController();
    _purchasePriceController = TextEditingController();
    _minMarginController = TextEditingController();
    _minMarginPriceController = TextEditingController();
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
      _fetchVariantPropertiesAndPrefill();
    });
  }

  Future<void> _fetchVariantPropertiesAndPrefill() async {
    if (_variantPropertiesRequested) return;
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;
    if (appSettings?.productVariantEnabled != true) return;
    _variantPropertiesRequested = true;

    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    if (!productProvider.hasProductProperties) {
      final accessToken =
          Provider.of<AuthModel>(context, listen: false).token ?? '';
      if (accessToken.isNotEmpty) {
        setState(() => _isLoadingVariantProperties = true);
        try {
          await productProvider.fetchProductProperties(
              accessToken: accessToken);
        } catch (e) {
          debugPrint('⚠️ fetchProductProperties failed: $e');
        } finally {
          if (mounted) setState(() => _isLoadingVariantProperties = false);
        }
      }
    }

    if (!mounted) return;
    _prefillVariants();
  }

  void _retryFetchVariantProperties() {
    _variantPropertiesRequested = false;
    _fetchVariantPropertiesAndPrefill();
  }

  void _prefillVariants() {
    if (_variantsPrefilled) return;
    final product = selectedProduct;
    if (product == null) return;
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    _variantController.loadFromVariants(
      product.variants ?? const [],
      productProvider.productProperties,
    );
    _variantsPrefilled = true;
    if (mounted) setState(() {});
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
    _minMarginController.text =
        _formatNumericString(product.minMarginPercentage);
    _minMarginPriceController.text =
        _formatNumericString(product.minMarginPrice);

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
    _syncSaleUnitsFromProduct(product);
    _controllersInitialized = true;
  }

  void _syncSaleUnitsFromProduct(GetProduct product) {
    _clearSaleUnitRows();
    final saleUnits = (product.saleUnits ?? const <SaleUnit>[])
        .where((saleUnit) => saleUnit.unitId?.toString() != _selectedUnitId)
        .toList(growable: false);
    for (final saleUnit in saleUnits) {
      _saleUnitRows.add(AddProductSaleUnitRow(
        selectedUnitId: saleUnit.unitId?.toString(),
        conversionRate: saleUnit.conversionRate ?? '',
        barcode: saleUnit.barcode ?? '',
        price: AddProductFormHelpers.formatDynamicNumber(saleUnit.price),
      ));
    }
    _showSaleUnitOptions = saleUnits.isNotEmpty;
    _saleUnitsTouched = false;
  }

  void _clearSaleUnitRows() {
    for (final row in _saleUnitRows) {
      row.dispose();
    }
    _saleUnitRows.clear();
  }

  void _toggleSaleUnitOptions(bool enabled) {
    if (enabled && (_selectedUnitId == null || _selectedUnitId!.isEmpty)) {
      showScaffoldError(
        context: context,
        message: 'Select the product unit before enabling multi sale units.',
      );
      return;
    }

    setState(() {
      _showSaleUnitOptions = enabled;
      _saleUnitsTouched = true;
      if (!enabled) {
        _clearSaleUnitRows();
      }
    });
  }

  bool _validateSaleUnits() {
    debugPrint('[EDIT_PRODUCT] sale-unit validation '
        'enabled=$_showSaleUnitOptions baseUnitId=$_selectedUnitId '
        'mainBarcode="${_barcodeController.text.trim()}" '
        'rowCount=${_saleUnitRows.length}');
    for (var index = 0; index < _saleUnitRows.length; index++) {
      final row = _saleUnitRows[index];
      debugPrint('[EDIT_PRODUCT] sale-unit row[$index] '
          'unitId=${row.selectedUnitId} '
          'conversionRate="${row.conversionRateController.text.trim()}" '
          'barcode="${row.barcodeController.text.trim()}" '
          'price="${row.priceController.text.trim()}"');
    }
    return AddProductFormHelpers.validateSaleUnits(
      showAdvancedOptions: _showSaleUnitOptions,
      selectedUnit: _selectedUnitId,
      mainBarcode: _barcodeController.text,
      saleUnitRows: _saleUnitRows,
      onError: (message) {
        debugPrint('[EDIT_PRODUCT] sale-unit validation error: $message');
        showScaffoldError(context: context, message: message);
      },
    );
  }

  String _valueToString(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      return value.toString();
    }
    return value.toString();
  }

  // Formats a numeric-like value by trimming trailing zeros (e.g. "10.000" -> "10").
  String _formatNumericString(dynamic value) {
    final text = _valueToString(value).trim();
    if (text.isEmpty) return '';
    final parsed = num.tryParse(text);
    if (parsed == null) return text;
    return parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toString();
  }

  Future<void> _handleSave() async {
    if (!_controllersInitialized || selectedProduct == null) {
      return;
    }

    if (!_canEditProduct(context)) {
      showScaffoldError(
        context: context,
        message: 'You do not have permission to edit this product.',
      );
      return;
    }

    if (!_editFormKey.currentState!.validate()) {
      return;
    }

    final bool variantEnabled =
        Provider.of<AppSettingsProvider>(context, listen: false)
                .appSettings
                ?.productVariantEnabled ??
            false;
    List<Map<String, dynamic>>? variantsPayload;
    if (variantEnabled) {
      final variantError =
          validateVariantRows(_variantController.toEditInputs());
      if (variantError != null) {
        showScaffoldError(context: context, message: variantError);
        return;
      }
      // Send the full set + deletions whenever there is anything to sync.
      if (_variantController.hasRows ||
          _variantController.deletedVariantIds.isNotEmpty) {
        variantsPayload =
            buildEditVariantsPayload(_variantController.toEditInputs());
      }
    }

    FocusScope.of(context).unfocus();

    debugPrint(
        '[EDIT_PRODUCT] submit started productId=${selectedProduct?.productId}');

    final product = selectedProduct!;
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    final String updatedName = _nameController.text.trim();
    final String updatedSlug = _slugController.text.trim();
    final String updatedBarcode = _barcodeController.text.trim();
    final String updatedUnit = _unitController.text.trim();
    final String updatedPriceString = _priceController.text.trim();
    final String updatedMrpString = _mrpController.text.trim();
    final String updatedQuantityString = _quantityController.text.trim();
    final String updatedPurchasePrice = _purchasePriceController.text.trim();
    final String updatedMinMargin = _minMarginController.text.trim();
    final String updatedMinMarginPrice = _minMarginPriceController.text.trim();
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

    final multiSaleUnitEnabled =
        context.read<AppSettingsProvider>().multiSaleUnitEnabled;
    if (multiSaleUnitEnabled && !_validateSaleUnits()) {
      debugPrint('[EDIT_PRODUCT] validation failed; request not sent');
      return;
    }

    final saleUnitsPayload =
        multiSaleUnitEnabled && (_saleUnitsTouched || _showSaleUnitOptions)
            ? (_showSaleUnitOptions
                ? AddProductFormHelpers.buildSaleUnitsPayload(
                    showAdvancedOptions: true,
                    selectedUnit: _selectedUnitId,
                    saleUnitRows: _saleUnitRows,
                  )
                : const <Map<String, dynamic>>[])
            : null;

    debugPrint('[EDIT_PRODUCT] form normalized '
        'nameLength=${updatedName.length}, slug="$updatedSlug", '
        'barcode="$updatedBarcode", unitId=$_selectedUnitId, '
        'price=$priceForApi, mrp=$mrpForApi, quantity=$quantityForApi, '
        'categoryId=$resolvedCategoryId, saleUnits=${saleUnitsPayload?.length ?? 0}, '
        'variants=${variantsPayload?.length ?? 0}');

    setState(() {
      _isSaving = true;
    });

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

      debugPrint('[EDIT_PRODUCT] sending request id=$productId '
          'unitId=$_selectedUnitId rackId=$_selectedRackId '
          'saleUnits=${saleUnitsPayload?.length ?? 0} '
          'productNames=${productNames.length}');

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
        variants: variantsPayload,
        saleUnits: saleUnitsPayload,
        // Pass the raw text (even when empty) so an erased field is sent to the
        // server as null to clear it, rather than being omitted from the body.
        minMarginPercentage: updatedMinMargin,
        minMarginPrice: updatedMinMarginPrice,
        accessToken: accessToken,
      );

      final String successMessage = response['message']?.toString() ??
          'Product details updated successfully.';

      debugPrint('[EDIT_PRODUCT] server success id=$productId '
          'message="$successMessage" responseDataType=${response['data']?.runtimeType}');

      final responseData = response['data'];
      if (responseData is Map) {
        final responseSaleUnits = responseData['sale_units'];
        debugPrint('[EDIT_PRODUCT] response summary '
            'productId=${responseData['id'] ?? responseData['product_id']} '
            'status=${response['status']} '
            'unit=${responseData['unit']} '
            'barcode=${responseData['barcode']} '
            'saleUnitCount=${responseSaleUnits is List ? responseSaleUnits.length : 0}');
        if (responseSaleUnits is List) {
          for (var index = 0; index < responseSaleUnits.length; index++) {
            final saleUnit = responseSaleUnits[index];
            if (saleUnit is Map) {
              debugPrint('[EDIT_PRODUCT] response saleUnit[$index] '
                  'id=${saleUnit['id']} unitId=${saleUnit['unit_id']} '
                  'conversionRate=${saleUnit['conversion_rate']} '
                  'barcode=${saleUnit['barcode']} price=${saleUnit['price']}');
            }
          }
        }
      } else {
        debugPrint('[EDIT_PRODUCT] response has no map data '
            'type=${responseData.runtimeType}');
      }
      GetProduct? serverProduct;
      dynamic responseNames;
      if (responseData is Map<String, dynamic>) {
        serverProduct = GetProduct.fromJson(responseData);
        responseNames = responseData['product_names'] ?? responseData['names'];
      } else if (responseData is Map) {
        final normalizedResponseData = Map<String, dynamic>.from(responseData);
        serverProduct = GetProduct.fromJson(normalizedResponseData);
        responseNames = normalizedResponseData['product_names'] ??
            normalizedResponseData['names'];
      }

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

      final unitMap = purchaseProvider.getUnitList ?? {};

      String resolvedUnitLabel =
          updatedUnit.isEmpty ? (product.unit ?? '') : updatedUnit;
      String? resolvedUnitId = _selectedUnitId;
      if (resolvedUnitId != null) {
        final mappedLabel = unitMap[resolvedUnitId];
        if (mappedLabel != null && mappedLabel.isNotEmpty) {
          resolvedUnitLabel = mappedLabel;
        } else if (int.tryParse(resolvedUnitLabel) != null &&
            product.unit != null &&
            product.unit!.trim().isNotEmpty &&
            int.tryParse(product.unit!.trim()) == null) {
          // The edit endpoint may return the numeric unit id while the
          // existing local product still has the human-readable label.
          resolvedUnitLabel = product.unit!.trim();
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
      if (_selectedCategoryId != null &&
          categoryProvider.category != null &&
          categoryProvider.category!.isNotEmpty) {
        selectedCategory = categoryProvider.category!.firstWhere(
          (category) => category.categoryId?.toString() == _selectedCategoryId,
          orElse: () => categoryProvider.category!.first,
        );
      }

      final List<SaleUnit>? responseSaleUnits = serverProduct?.saleUnits == null
          ? null
          : serverProduct!.saleUnits!
              .where(
                  (saleUnit) => saleUnit.unitId?.toString() != resolvedUnitId)
              .map((saleUnit) => SaleUnit(
                    id: saleUnit.id,
                    unitId: saleUnit.unitId,
                    unitName: saleUnit.unitName ??
                        unitMap[saleUnit.unitId?.toString() ?? ''],
                    conversionRate: saleUnit.conversionRate,
                    barcode: saleUnit.barcode,
                    price: saleUnit.price,
                    resolvedPrice: saleUnit.resolvedPrice,
                  ))
              .toList(growable: false);

      final GetProduct updatedProduct = product.copyWith(
        categoryId: serverProduct?.categoryId ?? resolvedCategoryId,
        productName: serverProduct?.productName ?? updatedName,
        productSlug: serverProduct?.productSlug ?? updatedSlug,
        barcode: serverProduct?.barcode ?? updatedBarcode,
        category: selectedCategory != null
            ? ProductCategory(
                name: selectedCategory.categoryName,
                slug: selectedCategory.categorySlug,
              )
            : (serverProduct?.category ?? product.category),
        unit: resolvedUnitLabel.isEmpty ? product.unit : resolvedUnitLabel,
        price: updatedProductPrice,
        mrp: serverProduct?.mrp ??
            (updatedMrpString.isEmpty ? product.mrp : updatedMrpString),
        taxes: [
          ProductTax(
            rate: (double.tryParse(_taxController.text) ?? 0.0).toString(),
            name: "Tax",
            code: "TAX",
            source: "manual",
          )
        ],
        purchasePrice: updatedPurchasePrice.isEmpty
            ? product.purchasePrice
            : updatedPurchasePrice,
        minMarginPercentage: serverProduct?.minMarginPercentage ??
            (updatedMinMargin.isEmpty
                ? product.minMarginPercentage
                : num.tryParse(updatedMinMargin) ?? updatedMinMargin),
        minMarginPrice: serverProduct?.minMarginPrice ??
            (updatedMinMarginPrice.isEmpty
                ? product.minMarginPrice
                : num.tryParse(updatedMinMarginPrice) ?? updatedMinMarginPrice),
        names: responseNames ??
            (productNames.isNotEmpty ? productNames : product.names),
        // Prefer the server value even when it is an empty list: an empty list
        // is the expected result after the user removes every sale unit.
        saleUnits: responseSaleUnits != null
            ? responseSaleUnits
            : (_showSaleUnitOptions
                ? _saleUnitRows
                    .map((row) => SaleUnit(
                          unitId: int.tryParse(row.selectedUnitId ?? ''),
                          conversionRate: row.conversionRateController.text,
                          barcode: row.barcodeController.text,
                          price: double.tryParse(row.priceController.text),
                        ))
                    .toList(growable: false)
                : const <SaleUnit>[]),
      );

      final GetProduct resolvedUpdatedProduct = updatedProduct;

      debugPrint('🧩 [ProductDetailsDialog] Using product snapshot source: '
          '${serverProduct != null ? "api_response_local_merge" : "form_local_merge"}');

      localProductProvider.updateProduct(resolvedUpdatedProduct);

      debugPrint('[EDIT_PRODUCT] local product snapshot updated id=$productId '
          'saleUnits=${resolvedUpdatedProduct.saleUnits?.length ?? 0}');

      final updatedTaxValue = double.tryParse(_taxController.text) ?? 0.0;
      localProductProvider.updateProductPricingInCart(
        resolvedUpdatedProduct.productId ?? 0,
        updatedPriceValue,
        updatedMrpValue,
        updatedTaxValue,
        updatedProduct: resolvedUpdatedProduct,
      );

      debugPrint(
          '🛒 [ProductDetailsDialog] Cart and saved orders refresh requested for id=$productId '
          '(price=$updatedPriceValue, mrp=$updatedMrpValue, tax=$updatedTaxValue)');

      if (!mounted) return;
      // Deletions have been persisted; drop them so a subsequent save does not
      // re-send delete instructions for already-removed variants.
      _variantController.deletedVariantIds.clear();
      setState(() {
        selectedProduct = resolvedUpdatedProduct;
        _controllersInitialized = false;
        _initializeControllersIfNeeded();
        _isSaving = false;
        _tabController.index = 0;
      });

      showScaffold(
        context: context,
        message: successMessage,
      );
      debugPrint('[EDIT_PRODUCT] save flow completed id=$productId');
    } catch (error) {
      debugPrint('[EDIT_PRODUCT] save flow failed '
          'type=${error.runtimeType} message=$error');
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
    if (_tabControllerReady) {
      _tabController.dispose();
    }
    _nameController.dispose();
    _slugController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _quantityController.dispose();
    _taxController.dispose(); // Restore dispose
    _purchasePriceController.dispose();
    _minMarginController.dispose();
    _minMarginPriceController.dispose();
    _rackController.dispose();
    for (final controller in _languageNameControllers.values) {
      controller.dispose();
    }
    _languageNameControllers.clear();
    _languageTranslating.clear();
    _clearSaleUnitRows();
    _variantController.dispose();
    _stockScrollController.dispose();
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

  num? _availableQuantity(
    GetProduct product, {
    List<Stock>? stockRows,
  }) {
    final stocks = stockRows ?? product.stock;
    if (stocks == null) return null;
    if (stocks.isEmpty) return 0;

    num total = 0;
    var hasQuantity = false;
    for (final stock in stocks) {
      if (stock.quantity != null) {
        total += stock.quantity!;
        hasQuantity = true;
      }
    }
    return hasQuantity ? total : null;
  }

  bool _isLowStockQuantity(num? quantity, int? reorderLevel) {
    if (quantity == null || reorderLevel == null) return false;
    return quantity <= reorderLevel;
  }

  String _formatStockNumber(num value) {
    if (value is int || value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }

  Widget _buildLowStockBadge({required bool atReorderLevel}) {
    final color =
        atReorderLevel ? ColorManager.kButtonYellow : ColorManager.kOrange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        atReorderLevel ? 'At Reorder Level' : 'Low Stock',
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s11,
          0.18,
          atReorderLevel ? Colors.black87 : ColorManager.kOrange,
        ),
      ),
    );
  }

  Widget _buildStockStatusRow(
    GetProduct product, {
    required bool stockEnabled,
    List<Stock>? stockRows,
  }) {
    final availableQuantity = _availableQuantity(product, stockRows: stockRows);
    final reorderLevel = product.reorderLevel;
    final isLowStock =
        stockEnabled && _isLowStockQuantity(availableQuantity, reorderLevel);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              'Available Qty:',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s14,
                0.20,
                ColorManager.textColor,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SelectableText(
                  availableQuantity == null
                      ? 'N/A'
                      : _formatStockNumber(availableQuantity),
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s14,
                    0.20,
                    isLowStock ? ColorManager.kOrange : ColorManager.textColor,
                  ),
                ),
                if (isLowStock)
                  _buildLowStockBadge(
                    atReorderLevel: availableQuantity == reorderLevel,
                  ),
              ],
            ),
          ),
        ],
      ),
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
              '$label:',
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
              //               softWrap: true, // Enable text wrapping
              // overflow: TextOverflow
              //     .visible, // Allow text to wrap instead of truncating
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithCopy(String label, String value) {
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
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s14,
                      0.20,
                      ColorManager.textColor,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
                if (value.isNotEmpty && value != 'N/A')
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: value));
                        showScaffold(
                          context: context,
                          message: '$label copied to clipboard',
                        );
                      },
                      child: Icon(
                        Icons.copy,
                        size: 16,
                        color: ColorManager.textColor.withOpacity(0.6),
                      ),
                    ),
                  ),
              ],
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

  Widget _buildViewTab(GetProduct product, {required bool canEditProduct}) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: true);
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: true);
    final currency = appSettingsProvider.appSettings?.currency ?? 'INR';
    final itemCodeEnabled =
        appSettingsProvider.appSettings?.itemCodeEnabled ?? false;
    final stockEnabled = localProductProvider.isStockEnabled;
    int? activeStoreId;
    String? activeStoreName;
    try {
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      activeStoreId = storeSession.activeStore?.storeId;
      activeStoreName = storeSession.activeStore?.storeName;
    } on ProviderNotFoundException catch (_) {}
    final stockRows = LocalProductProvider.filterStocksForStore(
      product.stock ?? const <Stock>[],
      activeStoreId: activeStoreId,
      activeStoreName: activeStoreName,
    );

    final identityRows = <Widget>[
      _buildDetailRow('Product Name', product.productName ?? 'N/A'),
      _buildDetailRow('Slug', product.productSlug ?? 'N/A'),
      _buildDetailRow('Category', product.category?.name ?? 'N/A'),
      if (itemCodeEnabled)
        _buildDetailRowWithCopy('Item Code', product.itemCode ?? 'N/A'),
      _buildDetailRowWithCopy('Barcode', product.barcode ?? 'N/A'),
      _buildDetailRow('Unit', product.unit ?? 'N/A'),
      if (product.taxes != null && product.taxes!.isNotEmpty)
        ...product.taxes!.map((tax) => _buildDetailRow(
              tax.name ?? 'Tax',
              '${tax.rate ?? 0}%',
            )),
    ];

    final pricingRows = <Widget>[
      _buildDetailRow(
          'Price',
          product.price?.price != null
              ? '$currency ${product.price!.price}'
              : 'N/A'),
      _buildDetailRow(
          'MRP', product.mrp != null ? '$currency ${product.mrp}' : 'N/A'),
      _buildDetailRow(
        'Purchase Price',
        (product.purchasePrice != null && product.purchasePrice!.isNotEmpty
            ? '$currency ${product.purchasePrice}'
            : (product.stock != null && product.stock!.isNotEmpty
                ? (product.stock!.first.purchasePrice != null &&
                        product.stock!.first.purchasePrice!.isNotEmpty
                    ? '$currency ${product.stock!.first.purchasePrice}'
                    : 'N/A')
                : 'N/A')),
      ),
      _buildDetailRow(
          'Offer Price',
          product.offerPrice != null
              ? '$currency ${product.offerPrice}'
              : 'N/A'),
      _buildDetailRow(
          'Max Discount Percentage',
          _formatNumericString(product.minMarginPercentage).isNotEmpty
              ? '${_formatNumericString(product.minMarginPercentage)}%'
              : 'N/A'),
      _buildDetailRow(
          'Max Discount Amount',
          _formatNumericString(product.minMarginPrice).isNotEmpty
              ? '$currency ${_formatNumericString(product.minMarginPrice)}'
              : 'N/A'),
      _buildDetailRow('SKU', product.sku ?? 'Not Available'),
    ];

    final metaRows = <Widget>[
      _buildDetailRow('Rating', product.rating ?? 'N/A'),
      _buildStockStatusRow(
        product,
        stockEnabled: stockEnabled,
        stockRows: stockRows,
      ),
      _buildDetailRow(
          'Reorder Level', product.reorderLevel?.toString() ?? 'N/A'),
      _buildDetailRow('Location', product.productLocation?.toString() ?? 'N/A'),
      if (product.weightInfo != null) ...[
        _buildDetailRow(
            'Weight', product.weightInfo!.weight?.toString() ?? 'N/A'),
        _buildDetailRow('Is Weighted',
            product.weightInfo!.isWeighted == true ? 'Yes' : 'No'),
      ] else ...[
        _buildDetailRow('Weight', 'N/A'),
        _buildDetailRow('Is Weighted', 'N/A'),
      ],
    ];

    Widget detailSections;
    if (widget.isCompact) {
      detailSections = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...identityRows,
          ...pricingRows,
          ...metaRows,
        ],
      );
    } else {
      detailSections = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: identityRows)),
          const SizedBox(width: 16),
          Expanded(child: Column(children: pricingRows)),
          const SizedBox(width: 16),
          Expanded(child: Column(children: metaRows)),
        ],
      );
    }

    final nonBaseUnits = (product.saleUnits ?? []).where((u) {
      final rate = double.tryParse(u.conversionRate?.toString() ?? '0') ?? 0;
      return rate > 0;
    }).toList();

    return SelectionArea(
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children: [
          detailSections,
          if (nonBaseUnits.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Additional Sale Units',
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text('Unit',
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s14,
                                  0.20,
                                  ColorManager.textColor)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('Barcode',
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s14,
                                  0.20,
                                  ColorManager.textColor)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Price',
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s14,
                                  0.20,
                                  ColorManager.textColor)),
                        ),
                      ],
                    ),
                    ...nonBaseUnits.map((saleUnit) {
                      final resolvedPrice =
                          saleUnit.resolvedPrice ?? saleUnit.price;
                      return Column(
                        children: [
                          const Divider(),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(saleUnit.unitName ?? 'N/A',
                                    style: buildCustomStyle(
                                        FontWeightManager.regular,
                                        FontSize.s14,
                                        0.20,
                                        ColorManager.textColor)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(saleUnit.barcode ?? 'N/A',
                                          style: buildCustomStyle(
                                              FontWeightManager.regular,
                                              FontSize.s14,
                                              0.20,
                                              ColorManager.textColor)),
                                    ),
                                    if (saleUnit.barcode != null &&
                                        saleUnit.barcode!.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 8.0),
                                        child: GestureDetector(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(
                                                text: saleUnit.barcode!));
                                            showScaffold(
                                              context: context,
                                              message: 'Barcode copied',
                                            );
                                          },
                                          child: Icon(
                                            Icons.copy,
                                            size: 16,
                                            color: ColorManager.textColor
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                    resolvedPrice != null
                                        ? '$currency ${resolvedPrice.toStringAsFixed(2)}'
                                        : 'N/A',
                                    style: buildCustomStyle(
                                        FontWeightManager.regular,
                                        FontSize.s14,
                                        0.20,
                                        ColorManager.textColor)),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
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
          if (product.hasVariants) ...[
            const SizedBox(height: 16),
            ProductVariantDetailsSection(
              product: product,
              stocks: stockRows,
              currency: currency,
              activeStoreId: activeStoreId,
              selectedVariantId: widget.selectedVariantId ??
                  widget.selectedStock?.productVariantId,
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
          if (stockRows.isNotEmpty)
            Scrollbar(
              controller: _stockScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _stockScrollController,
                scrollDirection: Axis.horizontal,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Table(
                      columnWidths: _stockTableColumnWidths,
                      border: null,
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(
                            color: ColorManager.tableBGColor,
                          ),
                          children: [
                            _buildStockTableHeader('Sl No'),
                            _buildStockTableHeader('Quantity'),
                            _buildStockTableHeader('Price'),
                            _buildStockTableHeader('MRP'),
                            _buildStockTableHeader('Purchase Price'),
                            _buildStockTableHeader('Supplier'),
                            _buildStockTableHeader('Store Name'),
                            _buildStockTableHeader('Wholesale Price'),
                            _buildStockTableHeader('Min Count'),
                            _buildStockTableHeader('SKU'),
                            _buildStockTableHeader('Date'),
                            _buildStockTableHeader('Expiry Date'),
                            _buildStockTableHeader('Rack'),
                            _buildStockTableHeader('Action'),
                          ],
                        ),
                        ...stockRows.asMap().entries.map((entry) {
                          final index = entry.key;
                          final originalStock = entry.value;
                          final stock = originalStock.id != null
                              ? (_editedStockRows[originalStock.id!] ??
                                  originalStock)
                              : originalStock;
                          final isLowStock = stockEnabled &&
                              _isLowStockQuantity(
                                stock.quantity,
                                product.reorderLevel,
                              );
                          return TableRow(
                            decoration: BoxDecoration(
                              color: isLowStock
                                  ? ColorManager.kOrange.withValues(alpha: 0.06)
                                  : index % 2 == 0
                                      ? Colors.white
                                      : Colors.grey.withValues(alpha: 0.05),
                            ),
                            children: [
                              _buildStockTableCell('${index + 1}'),
                              _buildStockTableCell(
                                stock.quantity?.toString() ?? 'N/A',
                                textColor:
                                    isLowStock ? Colors.white : Colors.black,
                                bgColor: isLowStock
                                    ? ColorManager.kOrange
                                    : Colors.transparent,
                              ),
                              _buildStockTableCell(
                                  stock.price != null && stock.price!.isNotEmpty
                                      ? '$currency ${stock.price}'
                                      : 'N/A'),
                              _buildStockTableCell(
                                  stock.mrp != null && stock.mrp!.isNotEmpty
                                      ? '$currency ${stock.mrp}'
                                      : 'N/A'),
                              _buildStockTableCell(
                                  stock.purchasePrice != null &&
                                          stock.purchasePrice!.isNotEmpty
                                      ? '$currency ${stock.purchasePrice}'
                                      : 'N/A'),
                              _buildStockTableCell(stock.supplier ?? 'N/A'),
                              _buildStockTableCell(stock.storeName ?? 'N/A'),
                              _buildStockTableCell(
                                  stock.wholesalePrice != null &&
                                          stock.wholesalePrice!.isNotEmpty
                                      ? '$currency ${stock.wholesalePrice}'
                                      : 'N/A'),
                              _buildStockTableCell(
                                  stock.wholesaleMinUnit?.toString() ?? 'N/A'),
                              _buildStockTableCell(stock.sku ?? 'N/A'),
                              _buildStockTableCell(stock.date ?? 'N/A'),
                              _buildStockTableCell(stock.expiryDate ?? 'N/A'),
                              _buildStockTableCell(stock.rack ?? 'N/A'),
                              _buildRackTableCell(
                                stock,
                                canEditProduct: canEditProduct,
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
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
          if (product.attachment != null && product.attachment!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Product Images',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s16,
                0.20,
                ColorManager.kPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final sorted = [
                ...product.attachment!.where((a) => a.isPrimary == 1),
                ...product.attachment!.where((a) => a.isPrimary != 1),
              ];
              return SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        sorted[index].filePath ?? '',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.image_not_supported,
                          size: 24,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
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
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: VariantEditorSection(
            controller: _variantController,
            properties: productProvider.productProperties,
            isLoadingProperties: _isLoadingVariantProperties,
            onRetryLoadProperties: _retryFetchVariantProperties,
            onGenerateBarcode: _generateVariantBarcode,
          ),
        );
      },
    );
  }

  Future<void> _generateVariantBarcode(
    TextEditingController target,
    void Function(bool loading) setLoading,
  ) async {
    final accessToken =
        Provider.of<AuthModel>(context, listen: false).token ?? '';
    if (accessToken.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'Authentication token not found. Please log in again.',
      );
      return;
    }

    setLoading(true);
    try {
      final gridSelectionProvider =
          Provider.of<GridSelectionProvider>(context, listen: false);
      final result = await gridSelectionProvider.generateBarcodeAPI(
          accessToken: accessToken);
      if (!mounted) return;
      if (result != null &&
          result['status'] == 'success' &&
          result['data'] != null) {
        target.text = result['data']['barcode'].toString();
        showScaffold(context: context, message: 'Barcode generated');
      } else {
        showScaffoldError(
          context: context,
          message:
              result?['message']?.toString() ?? 'Failed to generate barcode',
        );
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Error generating barcode: $e',
        );
      }
    } finally {
      setLoading(false);
    }
  }

  Widget _buildSaleUnitsEditor(List<_DropdownOption> unitOptions) {
    final availableUnits = unitOptions
        .where((option) => option.id != _selectedUnitId)
        .toList(growable: false);
    final canConfigureSaleUnits =
        _selectedUnitId != null && _selectedUnitId!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Multi Sale Unit',
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s12, 0.27, ColorManager.textColor)),
              ),
              Switch(
                value: _showSaleUnitOptions,
                activeThumbColor: ColorManager.kPrimaryColor,
                onChanged: canConfigureSaleUnits
                    ? _toggleSaleUnitOptions
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Base unit is required before adding additional sale units.',
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s11,
                  0.27, Colors.black54)),
          const SizedBox(height: 12),
          if (_showSaleUnitOptions) ...[
            _buildEditBaseUnitCard(unitOptions),
            const SizedBox(height: 10),
            ...List.generate(_saleUnitRows.length, (index) {
              final row = _saleUnitRows[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildSaleUnitRowExact(row, index, availableUnits),
              );
            }),
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _saleUnitsTouched = true;
                  _saleUnitRows.add(AddProductSaleUnitRow(conversionRate: '1'));
                }),
                icon: const Icon(Icons.add),
                label: const Text('Add Sale Unit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorManager.kPrimaryColor,
                  side: BorderSide(color: ColorManager.kPrimaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.35)),
              ),
              child: const Text(
                  'Select a base unit, then enable this section to add additional sale units.'),
            ),
        ],
      ),
    );
  }

  Widget _buildEditBaseUnitCard(List<_DropdownOption> unitOptions) {
    final matchingUnits =
        unitOptions.where((option) => option.id == _selectedUnitId);
    final unitLabel = matchingUnits.isEmpty
        ? _unitController.text
        : matchingUnits.first.label;
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
          Text('$unitLabel (Base Unit)',
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s12,
                  0.27, ColorManager.textColor)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildEditInfoField('Sale Unit', unitLabel)),
              const SizedBox(width: 8),
              Expanded(child: _buildEditInfoField('Conversion Rate', '1')),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildEditInfoField(
                      'Barcode',
                      _barcodeController.text.trim().isEmpty
                          ? '-'
                          : _barcodeController.text.trim())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaleUnitRowExact(
    AddProductSaleUnitRow row,
    int index,
    List<_DropdownOption> availableUnits,
  ) {
    final selected =
        availableUnits.where((option) => option.id == row.selectedUnitId);
    final selectedOption = selected.isEmpty
        ? (row.selectedUnitId == null
            ? null
            : _DropdownOption(
                id: row.selectedUnitId!, label: row.selectedUnitId!))
        : selected.first;
    final dropdownItems = [
      if (selectedOption != null &&
          !availableUnits.any((option) => option.id == selectedOption.id))
        selectedOption,
      ...availableUnits,
    ];
    final size = MediaQuery.sizeOf(context);

    Widget inputField(String title, TextEditingController controller,
        {TextInputType keyboardType = TextInputType.text}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s12,
                  0.27, Colors.black.withOpacity(0.6))),
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
              keyboardType: keyboardType,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
    }

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
              Expanded(
                child: CustomDropDownWithSearch<String>(
                  title: 'Sale Unit *',
                  hintText: 'Select unit',
                  value: row.selectedUnitId,
                  height: size.height * 0.048,
                  margin: EdgeInsets.zero,
                  items: dropdownItems.map((option) => option.id).toList(),
                  onChanged: (value) => setState(() {
                    _saleUnitsTouched = true;
                    row.selectedUnitId = value;
                  }),
                  displayText: (item) {
                    final match =
                        availableUnits.where((option) => option.id == item);
                    return match.isEmpty ? item : match.first.label;
                  },
                  searchController: row.searchController,
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _saleUnitsTouched = true;
                  _saleUnitRows.removeAt(index).dispose();
                }),
                splashRadius: 18,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: inputField(
                  'Conversion rate *',
                  row.conversionRateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: inputField('Barcode *', row.barcodeController)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: EdgeInsets.only(top: size.height * 0.021),
                      child: SizedBox(
                        height: size.height * 0.048,
                        width: size.height * 0.048,
                        child: ElevatedButton(
                          onPressed: row.isGeneratingBarcode
                              ? null
                              : () async {
                                  setState(
                                      () => row.isGeneratingBarcode = true);
                                  await _generateSaleUnitBarcode(
                                      row.barcodeController);
                                  if (mounted) {
                                    setState(
                                        () => row.isGeneratingBarcode = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorManager.kPrimaryColor,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: row.isGeneratingBarcode
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome,
                                  size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: inputField(
                  'Price *',
                  row.priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _generateSaleUnitBarcode(TextEditingController target) async {
    final token = Provider.of<AuthModel>(context, listen: false).token ?? '';
    if (token.isEmpty) return;
    try {
      final result =
          await Provider.of<GridSelectionProvider>(context, listen: false)
              .generateBarcodeAPI(accessToken: token);
      if (!mounted) return;
      if (result?['status'] == 'success' &&
          result?['data']?['barcode'] != null) {
        target.text = result!['data']['barcode'].toString();
      } else {
        showScaffoldError(
          context: context,
          message:
              result?['message']?.toString() ?? 'Failed to generate barcode',
        );
      }
    } catch (error) {
      if (mounted) {
        showScaffoldError(
            context: context, message: 'Failed to generate barcode: $error');
      }
    }
  }

  Widget _buildEditInfoField(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: buildCustomStyle(FontWeightManager.regular, FontSize.s12,
                0.27, Colors.black.withOpacity(0.6))),
        const SizedBox(height: 4),
        CustomBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: MediaQuery.sizeOf(context).height * 0.048,
          width: double.infinity,
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // Kept for backwards compatibility with older layout experiments.
  // ignore: unused_element
  Widget _buildSaleUnitRow(
    AddProductSaleUnitRow row,
    int index,
    List<_DropdownOption> availableUnits,
  ) {
    final selected =
        availableUnits.where((option) => option.id == row.selectedUnitId);
    final selectedOption = selected.isEmpty
        ? (row.selectedUnitId == null
            ? null
            : _DropdownOption(
                id: row.selectedUnitId!, label: row.selectedUnitId!))
        : selected.first;
    final dropdownItems = [
      if (selectedOption != null &&
          !availableUnits.any((option) => option.id == selectedOption.id))
        selectedOption,
      ...availableUnits,
    ];

    Widget field(String label, TextEditingController controller) {
      return TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: ColorManager.kPrimaryColor),
          ),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: CustomDropDownWithSearch<String>(
                  title: 'Sale Unit *',
                  hintText: 'Select unit',
                  value: row.selectedUnitId,
                  height: MediaQuery.sizeOf(context).height * 0.048,
                  margin: EdgeInsets.zero,
                  items: dropdownItems.map((option) => option.id).toList(),
                  onChanged: (value) => setState(() {
                    _saleUnitsTouched = true;
                    row.selectedUnitId = value;
                  }),
                  displayText: (item) {
                    final matching =
                        availableUnits.where((option) => option.id == item);
                    return matching.isEmpty ? item : matching.first.label;
                  },
                  searchController: row.searchController,
                ),
              ),
              IconButton(
                tooltip: 'Remove sale unit',
                onPressed: () => setState(() {
                  _saleUnitsTouched = true;
                  final removed = _saleUnitRows.removeAt(index);
                  removed.dispose();
                }),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                field('Conversion rate', row.conversionRateController),
                field('Barcode', row.barcodeController),
                field('Price', row.priceController),
              ];
              if (constraints.maxWidth < 560) {
                return Column(
                  children: fields
                      .map((child) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: child,
                          ))
                      .toList(),
                );
              }
              return Row(
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 8),
                  Expanded(child: fields[1]),
                  const SizedBox(width: 8),
                  Expanded(child: fields[2]),
                ],
              );
            },
          ),
        ],
      ),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: buildColumnWidgetForTextFields(
                            controller: _minMarginController,
                            size: size,
                            title: 'Max Discount Percentage',
                            hintText: 'Enter max discount percentage',
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
                            controller: _minMarginPriceController,
                            size: size,
                            title: 'Max Discount Amount',
                            hintText: 'Enter max discount amount',
                            width: fieldWidth,
                            height: fieldHeight,
                            margin: EdgeInsets.zero,
                            readOnly: false,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                        spacing(),
                        SizedBox(width: fieldWidth),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (context
                        .watch<AppSettingsProvider>()
                        .multiSaleUnitEnabled)
                      _buildSaleUnitsEditor(unitOptions),
                    const SizedBox(height: verticalGap),
                    _buildVariantsSection(),
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

  static const Map<int, TableColumnWidth> _stockTableColumnWidths = {
    0: FixedColumnWidth(56),
    1: FixedColumnWidth(88),
    2: FixedColumnWidth(100),
    3: FixedColumnWidth(100),
    4: FixedColumnWidth(120),
    5: FixedColumnWidth(120),
    6: FixedColumnWidth(120),
    7: FixedColumnWidth(120),
    8: FixedColumnWidth(96),
    9: FixedColumnWidth(88),
    10: FixedColumnWidth(110),
    11: FixedColumnWidth(110),
    12: FixedColumnWidth(72),
    13: FixedColumnWidth(72),
  };

  Widget _buildStockTableHeader(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildStockTableCell(
    String text, {
    Color textColor = Colors.black,
    Color bgColor = Colors.transparent,
  }) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Center(
          child: Container(
            padding: bgColor == Colors.transparent
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              text,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s13,
                0.18,
                textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRackTableCell(
    Stock stock, {
    required bool canEditProduct,
  }) {
    final bool canEdit = canEditProduct && stock.id != null;

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

    showEditStockDialog(
      context: context,
      stockId: stock.id!,
      title: 'Edit Stock',
      initialRetailPrice: stock.price ?? '',
      initialMrp: stock.mrp ?? '',
      initialPurchasePrice: stock.purchasePrice ?? '',
      initialQuantity: stock.quantity?.toString() ?? '0',
      initialRack: stock.rack ?? '',
      onSuccess: (result) async {
        final num? updatedQty = num.tryParse(result.quantity) ?? stock.quantity;
        if (!mounted) return;
        setState(() {
          _editedStockRows[stock.id!] = stock.copyWith(
            quantity: updatedQty,
            price: result.retailPrice,
            mrp: result.mrp,
            purchasePrice: result.purchasePrice,
            rack: result.rack,
          );
        });
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
    final canEditProduct = _canEditProduct(context);
    _ensureTabController(canEditProduct);

    final screenSize = MediaQuery.sizeOf(context);
    final maxDialogWidth = screenSize.width * (widget.isCompact ? 0.96 : 0.9);
    final minDialogWidth =
        widget.isCompact ? 0.0 : math.min(600.0, maxDialogWidth);

    final titleStyle = TextStyle(
      fontSize: widget.isCompact ? 20 : 24,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      insetPadding: widget.isCompact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
          : null,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxDialogWidth,
          maxHeight: screenSize.height * 0.85,
          minWidth: minDialogWidth,
        ),
        padding: EdgeInsets.all(widget.isCompact ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product Details',
                  style: titleStyle,
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
              tabs: [
                const Tab(text: 'View'),
                if (canEditProduct) const Tab(text: 'Edit'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildViewTab(
                    product,
                    canEditProduct: canEditProduct,
                  ),
                  if (canEditProduct) _buildEditTab(product),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (canEditProduct && _tabController.index == 1)
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
