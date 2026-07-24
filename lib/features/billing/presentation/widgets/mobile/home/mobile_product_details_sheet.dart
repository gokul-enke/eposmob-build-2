import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/billing/domain/add_product_form_helpers.dart';
import 'package:pos_machine/features/billing/domain/product_details_helpers.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/shared/mobile_detail_row.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/shared/mobile_detail_section.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/shared/mobile_sheet_header.dart';
import 'package:pos_machine/features/billing/presentation/widgets/product_variant_details_section.dart';
import 'package:pos_machine/features/products/domain/variant_form_payload.dart';
import 'package:pos_machine/features/products/presentation/variant_editor_section.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/language.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/language_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/widgets/edit_stock_dialog.dart';
import 'package:provider/provider.dart';

class _DropdownOption {
  final String id;
  final String label;

  const _DropdownOption({required this.id, required this.label});
}

/// Near-full-screen bottom sheet for product details on mobile billing.
Future<void> showMobileProductDetailsSheet({
  required BuildContext context,
  GetProduct? product,
  String? barcode,
  double? unitPrice,
  double? mrp,
  num? quantity,
  Stock? selectedStock,
  int? selectedVariantId,
  String currency = '',
  VoidCallback? onAdd,
  bool useBillingProductPermissions = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _MobileProductDetailsSheet(
      product: product,
      barcode: barcode,
      unitPrice: unitPrice,
      mrp: mrp,
      quantity: quantity,
      selectedStock: selectedStock,
      selectedVariantId: selectedVariantId,
      currency: currency,
      onAdd: onAdd,
      useBillingProductPermissions: useBillingProductPermissions,
    ),
  );
}

class _MobileProductDetailsSheet extends StatefulWidget {
  const _MobileProductDetailsSheet({
    this.product,
    this.barcode,
    this.unitPrice,
    this.mrp,
    this.quantity,
    this.selectedStock,
    this.selectedVariantId,
    this.currency = '',
    this.onAdd,
    this.useBillingProductPermissions = false,
  });

  final GetProduct? product;
  final String? barcode;
  final double? unitPrice;
  final double? mrp;
  final num? quantity;
  final Stock? selectedStock;
  final int? selectedVariantId;
  final String currency;
  final VoidCallback? onAdd;
  final bool useBillingProductPermissions;

  @override
  State<_MobileProductDetailsSheet> createState() =>
      _MobileProductDetailsSheetState();
}

class _MobileProductDetailsSheetState extends State<_MobileProductDetailsSheet>
    with SingleTickerProviderStateMixin {
  GetProduct? selectedProduct;
  bool isLoading = false;
  late TabController _tabController;
  bool _tabControllerReady = false;

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
  late TextEditingController _taxController;
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

  final VariantEditorController _variantController = VariantEditorController();
  bool _variantPropertiesRequested = false;
  bool _isLoadingVariantProperties = false;
  bool _variantsPrefilled = false;

  final Map<TextEditingController, FocusNode> _focusNodes = {};

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
    _taxController = TextEditingController();
    _rackController = TextEditingController();

    for (final controller in [
      _nameController,
      _slugController,
      _barcodeController,
      _unitController,
      _priceController,
      _mrpController,
      _quantityController,
      _purchasePriceController,
      _minMarginController,
      _minMarginPriceController,
      _taxController,
      _rackController,
    ]) {
      _attachSelectAllOnFocus(controller);
    }

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
        final generatedBarcode = result['data']['barcode'].toString();
        final resolvedBarcode = AddProductFormHelpers.getNextAvailableBarcode(
          seedBarcode: generatedBarcode,
          productProvider:
              Provider.of<LocalProductProvider>(context, listen: false),
          mainBarcode: _barcodeController.text,
          mainBarcodeController: _barcodeController,
          saleUnitRows: const [],
          additionalBarcodeControllers:
              _variantController.rows.map((row) => row.barcodeController),
          excludeController: target,
        );
        target.text = resolvedBarcode;
        showScaffold(
          context: context,
          message: resolvedBarcode == generatedBarcode
              ? 'Barcode generated'
              : 'Barcode generated and incremented to keep it unique',
        );
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

  void _attachSelectAllOnFocus(TextEditingController controller) {
    final node = FocusNode();
    _focusNodes[controller] = node;
    node.addListener(() {
      if (node.hasFocus && controller.text.isNotEmpty) {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      }
    });
  }

  FocusNode? _focusFor(TextEditingController controller) =>
      _focusNodes[controller];

  void _ensureTabController(bool canEdit) {
    final tabCount = canEdit ? 2 : 1;
    if (!_tabControllerReady) {
      _tabControllerReady = true;
      _tabController = TabController(length: tabCount, vsync: this);
      _tabController.addListener(() {
        if (mounted) setState(() {});
      });
      return;
    }
    if (_tabController.length == tabCount) return;
    final previousIndex = _tabController.index.clamp(0, tabCount - 1);
    _tabController.dispose();
    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: previousIndex,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
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
      showScaffoldError(context: context, message: languageProvider.error!);
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
        () {
          final c = TextEditingController();
          _attachSelectAllOnFocus(c);
          return c;
        },
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

    setState(() => _languageTranslating[language.id] = true);

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
        language.id,
        () {
          final c = TextEditingController();
          _attachSelectAllOnFocus(c);
          return c;
        },
      );
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
      setState(() => _languageTranslating[language.id] = false);
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
    setState(() => isLoading = true);

    try {
      final productProvider =
          Provider.of<LocalProductProvider>(context, listen: false);

      GetProduct? product;
      try {
        product = productProvider.products.firstWhere(
          (p) =>
              p.barcode != null &&
              p.barcode!.toString().trim() == barcode.trim(),
        );
      } catch (_) {
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
      if (product != null) _prefillVariants();

      if (product == null && mounted) {
        showScaffoldError(
          context: context,
          message: 'Product with barcode "$barcode" not found',
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
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
      Provider.of<CategoryProvider>(context, listen: false)
          .ensureCategoriesLoaded();
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
      if (token == null || token.isEmpty) return;

      if (purchaseProvider.getUnitList == null ||
          purchaseProvider.getUnitList!.isEmpty) {
        await purchaseProvider.listAllUnits(token);
      }
      if (purchaseProvider.getMasterDataValues == null ||
          purchaseProvider.getMasterDataValues!.isEmpty) {
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
      if (match.key.isNotEmpty) _selectedUnitId = match.key;
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
      if (match.key.isNotEmpty) _selectedRackId = match.key;
    }
  }

  void _initializeControllersIfNeeded() {
    if (selectedProduct == null || _controllersInitialized) return;

    final product = selectedProduct!;
    _nameController.text = product.productName ?? '';
    _slugController.text = product.productSlug ?? '';
    _barcodeController.text = product.barcode ?? '';
    _unitController.text = product.unit ?? '';
    _priceController.text = productDetailsValueToString(product.price?.price);
    _mrpController.text = productDetailsValueToString(product.mrp);
    _quantityController.text = '';
    _taxController.text = productDetailsValueToString(product.totalTaxRate);
    _purchasePriceController.text = product.purchasePrice ??
        (product.stock != null && product.stock!.isNotEmpty
            ? product.stock!.first.purchasePrice
            : '') ??
        '';
    _minMarginController.text =
        formatProductDetailsNumeric(product.minMarginPercentage);
    _minMarginPriceController.text =
        formatProductDetailsNumeric(product.minMarginPrice);

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

  Future<void> _handleSave() async {
    if (!_controllersInitialized || selectedProduct == null) return;

    if (!canEditProductDetails(
      context,
      useBillingProductPermissions: widget.useBillingProductPermissions,
    )) {
      showScaffoldError(
        context: context,
        message: 'You do not have permission to edit this product.',
      );
      return;
    }

    if (!_editFormKey.currentState!.validate()) return;

    final variantEnabled =
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
      if (_variantController.hasRows ||
          _variantController.deletedVariantIds.isNotEmpty) {
        variantsPayload =
            buildEditVariantsPayload(_variantController.toEditInputs());
      }
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final product = selectedProduct!;
    final localProductProvider =
        Provider.of<LocalProductProvider>(context, listen: false);
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    final updatedName = _nameController.text.trim();
    final updatedSlug = _slugController.text.trim();
    final updatedBarcode = _barcodeController.text.trim();
    final updatedUnit = _unitController.text.trim();
    final updatedPriceString = _priceController.text.trim();
    final updatedMrpString = _mrpController.text.trim();
    final updatedQuantityString = _quantityController.text.trim();
    final updatedPurchasePrice = _purchasePriceController.text.trim();
    final updatedMinMargin = _minMarginController.text.trim();
    final updatedMinMarginPrice = _minMarginPriceController.text.trim();
    final updatedRack = _rackController.text.trim();

    final priceForApi = updatedPriceString.isEmpty
        ? double.tryParse(product.price?.price?.toString() ?? '') ?? 0
        : double.tryParse(updatedPriceString) ?? 0;
    final mrpForApi = updatedMrpString.isEmpty
        ? double.tryParse(product.mrp?.toString() ?? '') ?? 0
        : double.tryParse(updatedMrpString) ?? 0;
    final purchasePriceForApi = updatedPurchasePrice.isEmpty
        ? double.tryParse(product.purchasePrice ?? '')
        : double.tryParse(updatedPurchasePrice);
    final quantityForApi = updatedQuantityString.isEmpty
        ? null
        : num.tryParse(updatedQuantityString);

    final updatedPriceValue = priceForApi;
    final updatedMrpValue = mrpForApi;

    final resolvedCategoryId = _selectedCategoryId != null
        ? int.tryParse(_selectedCategoryId!)
        : product.categoryId;

    final rackNumber = updatedRack.isNotEmpty
        ? int.tryParse(updatedRack)
        : int.tryParse(_editableStock?.rack ?? '');

    final accessToken = Provider.of<AuthModel>(context, listen: false).token;
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final activeLanguages = languageProvider.languages
        .where((language) => language.active)
        .toList(growable: false);
    final productNames = _buildProductNamesPayload(activeLanguages);

    if (accessToken == null || accessToken.isEmpty) {
      if (mounted) {
        setState(() => _isSaving = false);
        showScaffoldError(
          context: context,
          message: 'Authentication token not found.',
        );
      }
      return;
    }

    try {
      final productId = (product.productId ?? '').toString();
      if (productId.isEmpty) {
        throw const HttpException('Product ID missing.');
      }

      final rackForApi = int.tryParse(_selectedRackId ?? '') ?? rackNumber;

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
        minMarginPercentage: updatedMinMargin,
        minMarginPrice: updatedMinMarginPrice,
        accessToken: accessToken,
      );

      final successMessage = response['message']?.toString() ??
          'Product details updated successfully.';

      final responseData = response['data'];
      GetProduct? serverProduct;
      dynamic responseNames;
      if (responseData is Map<String, dynamic>) {
        serverProduct = GetProduct.fromJson(responseData);
        responseNames = responseData['product_names'] ?? responseData['names'];
      } else if (responseData is Map) {
        final normalized = Map<String, dynamic>.from(responseData);
        serverProduct = GetProduct.fromJson(normalized);
        responseNames = normalized['product_names'] ?? normalized['names'];
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
      var resolvedUnitLabel =
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

      final updatedProduct = product.copyWith(
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
            name: 'Tax',
            code: 'TAX',
            source: 'manual',
          ),
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
        saleUnits: responseSaleUnits ?? product.saleUnits,
        variants: (serverProduct?.variants?.isNotEmpty ?? false)
            ? serverProduct!.variants
            : product.variants,
      );

      localProductProvider.updateProduct(updatedProduct);

      final updatedTaxValue = double.tryParse(_taxController.text) ?? 0.0;
      localProductProvider.updateProductPricingInCart(
        updatedProduct.productId ?? 0,
        updatedPriceValue,
        updatedMrpValue,
        updatedTaxValue,
        updatedProduct: updatedProduct,
      );

      if (!mounted) return;
      _variantController.deletedVariantIds.clear();
      setState(() {
        selectedProduct = updatedProduct;
        _controllersInitialized = false;
        _initializeControllersIfNeeded();
        _isSaving = false;
        _tabController.index = 0;
      });

      showScaffold(context: context, message: successMessage);
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        showScaffoldError(context: context, message: error.toString());
      }
    }
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
        final updatedQty = num.tryParse(result.quantity) ?? stock.quantity;
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
  void dispose() {
    _variantController.dispose();
    if (_tabControllerReady) _tabController.dispose();
    _nameController.dispose();
    _slugController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _quantityController.dispose();
    _taxController.dispose();
    _purchasePriceController.dispose();
    _minMarginController.dispose();
    _minMarginPriceController.dispose();
    _rackController.dispose();
    for (final controller in _languageNameControllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _languageNameControllers.clear();
    _languageTranslating.clear();
    _focusNodes.clear();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        color: Colors.grey.shade600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  Widget _mobileTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    ValueChanged<String?>? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: _focusFor(controller),
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      onTap: () {
        if (controller.text.isNotEmpty) {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }
      },
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: _fieldDecoration(label: label, hint: hint),
    );
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
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: atReorderLevel ? Colors.black87 : ColorManager.kOrange,
        ),
      ),
    );
  }

  Widget _buildStockCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryWithOpacity10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildStockCard({
    required int index,
    required Stock stock,
    required bool rowLowStock,
    required String currency,
    required bool canEditProduct,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rowLowStock
            ? ColorManager.kOrange.withValues(alpha: 0.05)
            : const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: rowLowStock
              ? ColorManager.kOrange.withValues(alpha: 0.4)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryWithOpacity10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColorManager.kPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Stock #${index + 1}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (canEditProduct && stock.id != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: ColorManager.kPrimaryColor,
                  tooltip: 'Edit stock',
                  onPressed: () => _showEditStockRowModal(stock),
                ),
            ],
          ),
          const SizedBox(height: 4),
          MobileDetailRow(
            label: 'Quantity',
            value: stock.quantity?.toString() ?? 'N/A',
            valueColor: rowLowStock ? ColorManager.kOrange : null,
            dense: true,
          ),
          MobileDetailRow(
            label: 'Price',
            value: stock.price != null && stock.price!.isNotEmpty
                ? '$currency ${stock.price}'
                : 'N/A',
            highlight: true,
            dense: true,
          ),
          MobileDetailRow(
            label: 'MRP',
            value: stock.mrp != null && stock.mrp!.isNotEmpty
                ? '$currency ${stock.mrp}'
                : 'N/A',
            dense: true,
          ),
          MobileDetailRow(
            label: 'Purchase Price',
            value:
                stock.purchasePrice != null && stock.purchasePrice!.isNotEmpty
                    ? '$currency ${stock.purchasePrice}'
                    : 'N/A',
            dense: true,
          ),
          MobileDetailRow(
            label: 'Wholesale Price',
            value:
                stock.wholesalePrice != null && stock.wholesalePrice!.isNotEmpty
                    ? '$currency ${stock.wholesalePrice}'
                    : 'N/A',
            dense: true,
          ),
          MobileDetailRow(
            label: 'Min Count',
            value: stock.wholesaleMinUnit?.toString() ?? 'N/A',
            dense: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1),
          ),
          MobileDetailRow(
            label: 'Supplier',
            value: stock.supplier ?? 'N/A',
            dense: true,
          ),
          MobileDetailRow(
            label: 'Store Name',
            value: stock.storeName ?? 'N/A',
            dense: true,
          ),
          MobileDetailRow(
            label: 'SKU',
            value: stock.sku ?? 'N/A',
            dense: true,
          ),
          MobileDetailRow(
            label: 'Rack',
            value: stock.rack ?? 'N/A',
            dense: true,
          ),
          MobileDetailRow(
            label: 'Date',
            value: stock.date ?? 'N/A',
            dense: true,
          ),
          MobileDetailRow(
            label: 'Expiry Date',
            value: stock.expiryDate ?? 'N/A',
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildViewTab(GetProduct product, {required bool canEditProduct}) {
    final appSettings = context.watch<AppSettingsProvider>().appSettings;
    final stockEnabled = context.watch<LocalProductProvider>().isStockEnabled;
    final currency = appSettings?.currency ?? widget.currency;
    final itemCodeEnabled = appSettings?.itemCodeEnabled ?? false;
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
    final availableQuantity = stockRows.isEmpty
        ? (product.stock == null ? null : 0)
        : stockRows.fold<num>(
            0,
            (total, stock) => total + (stock.quantity ?? 0),
          );
    final reorderLevel = product.reorderLevel;
    final isLowStock =
        stockEnabled && isProductLowStock(availableQuantity, reorderLevel);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        MobileDetailSection(
          title: 'Basic Info',
          icon: Icons.info_outline,
          initiallyExpanded: true,
          children: [
            MobileDetailRow(
              label: 'Product Name',
              value: product.productName ?? 'N/A',
            ),
            MobileDetailRow(
              label: 'Slug',
              value: product.productSlug ?? 'N/A',
            ),
            MobileDetailRow(
              label: 'Category',
              value: product.category?.name ?? 'N/A',
            ),
            if (itemCodeEnabled)
              MobileDetailRow(
                label: 'Item Code',
                value: product.itemCode ?? 'N/A',
                copyable: true,
              ),
            MobileDetailRow(
              label: 'Barcode',
              value: product.barcode ?? 'N/A',
              copyable: true,
            ),
            MobileDetailRow(
              label: 'Unit',
              value: product.unit ?? 'N/A',
            ),
            MobileDetailRow(
              label: 'SKU',
              value: product.sku ?? 'Not Available',
            ),
            MobileDetailRow(
              label: 'Rating',
              value: product.rating ?? 'N/A',
            ),
          ],
        ),
        MobileDetailSection(
          title: 'Pricing',
          icon: Icons.sell_outlined,
          initiallyExpanded: true,
          children: [
            MobileDetailRow(
              label: 'Price',
              value: product.price?.price != null
                  ? '$currency ${product.price!.price}'
                  : 'N/A',
              highlight: true,
            ),
            MobileDetailRow(
              label: 'MRP',
              value: product.mrp != null ? '$currency ${product.mrp}' : 'N/A',
              highlight: true,
            ),
            MobileDetailRow(
              label: 'Offer Price',
              value: product.offerPrice != null
                  ? '$currency ${product.offerPrice}'
                  : 'N/A',
              highlight: true,
            ),
            MobileDetailRow(
              label: 'Purchase Price',
              value: product.purchasePrice != null &&
                      product.purchasePrice!.isNotEmpty
                  ? '$currency ${product.purchasePrice}'
                  : (product.stock != null && product.stock!.isNotEmpty
                      ? (product.stock!.first.purchasePrice != null &&
                              product.stock!.first.purchasePrice!.isNotEmpty
                          ? '$currency ${product.stock!.first.purchasePrice}'
                          : 'N/A')
                      : 'N/A'),
            ),
            MobileDetailRow(
              label: 'Max Discount Percentage',
              value: formatProductDetailsNumeric(product.minMarginPercentage)
                      .isNotEmpty
                  ? '${formatProductDetailsNumeric(product.minMarginPercentage)}%'
                  : 'N/A',
            ),
            MobileDetailRow(
              label: 'Max Discount Amount',
              value: formatProductDetailsNumeric(product.minMarginPrice)
                      .isNotEmpty
                  ? '$currency ${formatProductDetailsNumeric(product.minMarginPrice)}'
                  : 'N/A',
            ),
          ],
        ),
        if (product.taxes != null && product.taxes!.isNotEmpty)
          MobileDetailSection(
            title: 'Tax',
            icon: Icons.percent_outlined,
            initiallyExpanded: false,
            children: [
              for (final tax in product.taxes!)
                MobileDetailRow(
                  label: tax.name ?? 'Tax',
                  value: '${tax.rate ?? 0}%',
                ),
            ],
          ),
        if (product.hasVariants)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ProductVariantDetailsSection(
              product: product,
              stocks: stockRows,
              currency: currency,
              activeStoreId: activeStoreId,
              selectedVariantId: widget.selectedVariantId ??
                  widget.selectedStock?.productVariantId,
            ),
          ),
        MobileDetailSection(
          title: 'Stock',
          icon: Icons.inventory_2_outlined,
          initiallyExpanded: true,
          badge: stockRows.isNotEmpty
              ? _buildStockCountBadge(stockRows.length)
              : null,
          children: [
            MobileDetailRow(
              label: 'Available Qty',
              value: availableQuantity == null
                  ? 'N/A'
                  : formatProductStockNumber(availableQuantity),
              valueColor: isLowStock ? ColorManager.kOrange : null,
              trailing: isLowStock
                  ? _buildLowStockBadge(
                      atReorderLevel: availableQuantity == reorderLevel,
                    )
                  : null,
            ),
            MobileDetailRow(
              label: 'Reorder Level',
              value: product.reorderLevel?.toString() ?? 'N/A',
            ),
            MobileDetailRow(
              label: 'Location',
              value: product.productLocation?.toString() ?? 'N/A',
            ),
            const SizedBox(height: 8),
            if (stockRows.isNotEmpty)
              for (final entry in stockRows.asMap().entries)
                _buildStockCard(
                  index: entry.key,
                  stock: entry.value.id != null
                      ? (_editedStockRows[entry.value.id!] ?? entry.value)
                      : entry.value,
                  rowLowStock: stockEnabled &&
                      isProductLowStock(entry.value.quantity, reorderLevel),
                  currency: currency,
                  canEditProduct: canEditProduct,
                )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'No stock information available',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
        if (product.weightInfo != null)
          MobileDetailSection(
            title: 'Weight',
            icon: Icons.scale_outlined,
            initiallyExpanded: false,
            children: [
              MobileDetailRow(
                label: 'Weight',
                value: product.weightInfo!.weight?.toString() ?? 'N/A',
              ),
              MobileDetailRow(
                label: 'Is Weighted',
                value: product.weightInfo!.isWeighted == true ? 'Yes' : 'No',
              ),
            ],
          ),
        if (product.description != null &&
            product.description.toString().isNotEmpty)
          MobileDetailSection(
            title: 'Description',
            icon: Icons.description_outlined,
            initiallyExpanded: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                product.description.toString(),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _translateIconButton(Language language) {
    final translating = _languageTranslating[language.id] ?? false;
    return IconButton(
      onPressed: translating ? null : () => _translateLanguage(language),
      icon: translating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.translate, size: 20),
      color: ColorManager.kPrimaryColor,
      tooltip: 'Translate from English',
    );
  }

  Widget _buildEditTab(GetProduct product) {
    final categoryProvider = context.watch<CategoryProvider>();
    final categories = (categoryProvider.category ?? [])
        .where((category) => category.categoryId != null)
        .toList();
    final languageProvider = context.watch<LanguageProvider>();
    final purchaseProvider = context.watch<PurchaseProvider>();
    final unitOptions = (purchaseProvider.getUnitList ?? {})
        .entries
        .map((entry) => _DropdownOption(id: entry.key, label: entry.value))
        .where((option) => option.label.isNotEmpty)
        .toList();

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

    _DropdownOption? findSelectedOption(
        List<_DropdownOption> options, String? id) {
      if (id == null) return null;
      try {
        return options.firstWhere((option) => option.id == id);
      } catch (_) {
        return null;
      }
    }

    final selectedUnitOption = findSelectedOption(unitOptions, _selectedUnitId);

    final languages = languageProvider.languages
        .where((lang) => lang.active)
        .toList(growable: false);
    final baseLanguage = _getBaseLanguage(languages);
    final extraLanguages = languages
        .where((lang) => baseLanguage == null || lang.id != baseLanguage.id)
        .toList(growable: false);

    for (final language in extraLanguages) {
      _languageNameControllers.putIfAbsent(
        language.id,
        () {
          final c = TextEditingController(
            text: _extractTranslatedName(selectedProduct?.names, language),
          );
          _attachSelectAllOnFocus(c);
          return c;
        },
      );
      _languageTranslating.putIfAbsent(language.id, () => false);
    }

    return Form(
      key: _editFormKey,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          MobileDetailSection(
            title: 'Basic',
            icon: Icons.info_outline,
            initiallyExpanded: true,
            children: [
              _mobileTextField(
                controller: _nameController,
                label: 'Product Name',
                hint: 'Enter product name',
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
                onChanged: (value) {
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
              const SizedBox(height: 12),
              _mobileTextField(
                controller: _slugController,
                label: 'Slug',
                hint: 'Enter slug',
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _mobileTextField(
                controller: _barcodeController,
                label: 'Barcode',
                hint: 'Enter barcode',
              ),
              const SizedBox(height: 12),
              CustomDropDownWithSearch<Category>(
                title: 'Category',
                hintText: 'Select category',
                value: selectedCategory,
                items: categories,
                height: 48,
                margin: EdgeInsets.zero,
                onChanged: (category) {
                  setState(() {
                    _selectedCategoryId = category?.categoryId?.toString();
                  });
                },
                displayText: (category) => category.categoryName ?? 'Unknown',
                isRequired: true,
                width: double.infinity,
                searchHintText: 'Search category...',
                autofocus: false,
              ),
              const SizedBox(height: 12),
              CustomDropDownWithSearch<_DropdownOption>(
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
                width: double.infinity,
                height: 48,
                margin: EdgeInsets.zero,
                searchHintText: 'Search unit...',
                autofocus: false,
              ),
            ],
          ),
          MobileDetailSection(
            title: 'Pricing & Stock',
            icon: Icons.sell_outlined,
            initiallyExpanded: true,
            children: [
              _mobileTextField(
                controller: _priceController,
                label: 'Price',
                hint: 'Enter price',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _mobileTextField(
                controller: _quantityController,
                label: 'Quantity',
                hint: 'Enter quantity',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
              ),
              const SizedBox(height: 12),
              _mobileTextField(
                controller: _mrpController,
                label: 'MRP',
                hint: 'Enter MRP',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _mobileTextField(
                controller: _purchasePriceController,
                label: 'Purchase Price',
                hint: 'Enter purchase price',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _mobileTextField(
                controller: _minMarginController,
                label: 'Max Discount Percentage',
                hint: 'Enter max discount percentage',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _mobileTextField(
                controller: _minMarginPriceController,
                label: 'Max Discount Amount',
                hint: 'Enter max discount amount',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          _buildVariantsSection(),
          MobileDetailSection(
            title: 'Translations',
            icon: Icons.translate,
            initiallyExpanded: extraLanguages.isNotEmpty,
            children: [
              if (languageProvider.isLoading &&
                  languageProvider.languages.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading languages...'),
                    ],
                  ),
                )
              else if (languageProvider.error != null &&
                  languageProvider.languages.isEmpty)
                Row(
                  children: [
                    Expanded(child: Text(languageProvider.error!)),
                    TextButton(
                      onPressed: _retryFetchLanguages,
                      child: const Text('Retry'),
                    ),
                  ],
                )
              else if (extraLanguages.isEmpty)
                Text(
                  'No additional languages configured.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                )
              else
                for (final language in extraLanguages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _mobileTextField(
                            controller: _languageNameControllers[language.id]!,
                            label: 'Name (${language.name})',
                            hint: 'Translated name',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _translateIconButton(language),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
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

  Widget _buildPillTabBar({required bool canEditProduct}) {
    final tabs = ['View', if (canEditProduct) 'Edit'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_tabController.index == i) return;
                  _tabController.index = i;
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _tabController.index == i
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _tabController.index == i
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _tabController.index == i
                          ? ColorManager.kPrimaryColor
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStickyFooter() {
    return SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _isSaving ? null : _handleSave,
                style: FilledButton.styleFrom(
                  backgroundColor: ColorManager.kPrimaryColor,
                  disabledBackgroundColor:
                      ColorManager.kPrimaryColor.withValues(alpha: 0.5),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  _isSaving ? 'Saving...' : 'Save',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              fit: FlexFit.loose,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: ColorManager.kPrimaryColor,
                  minimumSize: const Size.fromHeight(48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.92;

    if (isLoading) {
      return ColoredBox(
        color: Colors.white,
        child: SizedBox(
          height: sheetHeight,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading product details...'),
              ],
            ),
          ),
        ),
      );
    }

    if (selectedProduct == null) {
      return ColoredBox(
        color: Colors.white,
        child: SizedBox(
          height: sheetHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Product not found'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 44),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final product = selectedProduct!;
    _initializeControllersIfNeeded();
    final canEditProduct = canEditProductDetails(
      context,
      useBillingProductPermissions: widget.useBillingProductPermissions,
    );
    _ensureTabController(canEditProduct);

    final showFooter = canEditProduct && _tabController.index == 1;

    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MobileSheetHeader(
                title: product.productName ?? 'Product Details',
                subtitle: product.category?.name,
                thumbnail: buildProductThumbnail(
                  productName: product.productName,
                  attachments: product.attachment,
                ),
                onClose: () => Navigator.pop(context),
              ),
              if (_isSaving) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _buildPillTabBar(canEditProduct: canEditProduct),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildViewTab(product, canEditProduct: canEditProduct),
                      if (canEditProduct) _buildEditTab(product),
                    ],
                  ),
                ),
              ),
              if (showFooter) _buildStickyFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
