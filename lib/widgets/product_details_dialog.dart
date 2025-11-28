import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/newcomponents/custom_text_fields.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/product_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
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
  late TextEditingController _purchasePriceController;
  late TextEditingController _rackController;

  String? _selectedCategoryId;
  Stock? _editableStock;
  String? _selectedUnitId;
  String? _selectedRackId;
  bool _requestedUnitRackData = false;

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
    _purchasePriceController = TextEditingController();
    _rackController = TextEditingController();
    if (widget.product != null) {
      selectedProduct = widget.product;
      _initializeControllersIfNeeded();
      _ensureCategoriesLoaded();
      _ensureUnitAndRackLoaded();
    } else if (widget.barcode != null) {
      _fetchProductByBarcode(widget.barcode!);
    }
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
        purchasePrice: updatedPurchasePrice.isEmpty
            ? product.purchasePrice
            : updatedPurchasePrice,
        attachment: product.attachment,
        names: product.names,
        productProps: product.productProps,
        weightInfo: product.weightInfo,
        stock: product.stock,
        sku: product.sku,
        offerPrice: product.offerPrice,
        productLocation: product.productLocation,
        hsnCode: product.hsnCode,
      );

      localProductProvider.updateProduct(updatedProduct);

      localProductProvider.updateProductPricingInCart(
        updatedProduct.productId ?? 0,
        updatedPriceValue,
        updatedMrpValue,
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
    _purchasePriceController.dispose();
    _rackController.dispose();
    super.dispose();
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
                  _buildDetailRow('Currency', product.currency ?? 'N/A'),
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
                      5: FlexColumnWidth(1.5),
                      6: FlexColumnWidth(1.0),
                      7: FlexColumnWidth(1.2),
                      8: FlexColumnWidth(1.2),
                      9: FlexColumnWidth(1.0),
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
                          _buildStockTableHeader('SKU'),
                          _buildStockTableHeader('Date'),
                          _buildStockTableHeader('Expiry Date'),
                          _buildStockTableHeader('Rack'),
                        ],
                      ),
                    ],
                  ),
                ),
                ...product.stock!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final stock = entry.value;
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
                        5: FlexColumnWidth(1.5),
                        6: FlexColumnWidth(1.0),
                        7: FlexColumnWidth(1.2),
                        8: FlexColumnWidth(1.2),
                        9: FlexColumnWidth(1.0),
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
                            _buildStockTableCell(stock.sku ?? 'N/A'),
                            _buildStockTableCell(stock.date ?? 'N/A'),
                            _buildStockTableCell(stock.expiryDate ?? 'N/A'),
                            _buildStockTableCell(stock.rack ?? 'N/A'),
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
            const double verticalGap = 12;
            final double availableWidth = constraints.maxWidth;
            final double fieldWidth = availableWidth > 0
                ? (availableWidth - (horizontalGap * 2)) / 3
                : size.width / 3.5;
            final double fieldHeight = size.height * 0.05;

            Widget spacing() => const SizedBox(width: horizontalGap);

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
                  if (product.stock != null && product.stock!.isNotEmpty)
                    Text(
                      'Price and MRP changes apply to all stock entries for this product.',
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.20,
                        ColorManager.textColor.withOpacity(0.7),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
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
