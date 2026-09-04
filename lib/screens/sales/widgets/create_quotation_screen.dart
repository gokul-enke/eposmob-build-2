import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/executive.dart';

class QuotationItem {
  final GetProduct product;
  double quantity;
  double unitPrice;
  double purchasePrice;
  ProductTax? selectedTax;

  QuotationItem({
    required this.product,
    this.quantity = 1.0,
    this.purchasePrice = 0.0,
    this.selectedTax,
  }) : unitPrice =
            double.tryParse(product.price?.price?.toString() ?? '0') ?? 0.0 {
    selectedTax = (product.taxes != null && product.taxes!.isNotEmpty)
        ? product.taxes!.first
        : null;
    purchasePrice = double.tryParse(product.purchasePrice ?? '0') ?? 0.0;
  }

  double get taxRate => double.tryParse(selectedTax?.rate ?? '0') ?? 0.0;
  double get subTotal => unitPrice * quantity;
  double get totalTax => subTotal * taxRate / 100;
  double get totalPrice => subTotal + totalTax;
}

class CreateQuotationScreen extends StatefulWidget {
  const CreateQuotationScreen({super.key});

  @override
  State<CreateQuotationScreen> createState() => _CreateQuotationScreenState();
}

class _CreateQuotationScreenState extends State<CreateQuotationScreen> {
  GetProduct? _selectedProduct;
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _purchasePriceController =
      TextEditingController();
  final TextEditingController _quotationNoController = TextEditingController();
  ProductTax? _entryTax;

  final TextEditingController _storeSearchController = TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();
  final TextEditingController _inlineCustomerNameController =
      TextEditingController();
  final TextEditingController _inlineCustomerPhoneController =
      TextEditingController();
  bool _useInlineCustomer = false;

  DateTime _quotationDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  final TextEditingController _quotationDateController =
      TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();

  final List<QuotationItem> _items = [];
  final TextEditingController _commentController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _updateDateControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CustomerSelectionProvider>(context, listen: false)
          .clearSelectedCustomer();
    });
  }

  void _updateDateControllers() {
    _quotationDateController.text =
        DateFormat('yyyy-MM-dd').format(_quotationDate);
    _expiryDateController.text = DateFormat('yyyy-MM-dd').format(_expiryDate);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _purchasePriceController.dispose();
    _commentController.dispose();
    _storeSearchController.dispose();
    _productSearchController.dispose();
    _customerSearchController.dispose();
    _inlineCustomerNameController.dispose();
    _inlineCustomerPhoneController.dispose();
    _quotationDateController.dispose();
    _expiryDateController.dispose();
    _quotationNoController.dispose();
    super.dispose();
  }

  void _onProductSelected(GetProduct product) {
    setState(() {
      _selectedProduct = product;
      final price =
          double.tryParse(product.price?.price?.toString() ?? '0') ?? 0.0;
      _priceController.text = price.toStringAsFixed(2);
      final purchasePrice =
          double.tryParse(product.purchasePrice ?? '0') ?? 0.0;
      _purchasePriceController.text = purchasePrice.toStringAsFixed(2);
      _entryTax = (product.taxes != null && product.taxes!.isNotEmpty)
          ? product.taxes!.first
          : null;
    });
  }

  void _addItem() {
    if (_selectedProduct == null) return;
    final qty = double.tryParse(_qtyController.text) ?? 1.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;

    setState(() {
      final existingIndex = _items.indexWhere(
          (i) => i.product.productId == _selectedProduct!.productId);
      if (existingIndex >= 0) {
        _items[existingIndex].quantity += qty;
        _items[existingIndex].unitPrice = price;
        _items[existingIndex].purchasePrice = purchasePrice;
        _items[existingIndex].selectedTax = _entryTax;
      } else {
        final item = QuotationItem(
          product: _selectedProduct!,
          quantity: qty,
          purchasePrice: purchasePrice,
          selectedTax: _entryTax,
        )..unitPrice = price;
        _items.add(item);
      }
      _selectedProduct = null;
      _qtyController.text = '1';
      _priceController.clear();
      _purchasePriceController.clear();
      _entryTax = null;
      _productSearchController.clear();
    });
  }

  void _removeItem(int index) => setState(() => _items.removeAt(index));

  double get _subTotal => _items.fold(0.0, (s, i) => s + i.subTotal);
  double get _totalTax => _items.fold(0.0, (s, i) => s + i.totalTax);
  double get _grandTotal => _subTotal + _totalTax;

  Future<void> _saveQuotation() async {
    final customerProvider =
        Provider.of<CustomerSelectionProvider>(context, listen: false);
    final storeProvider =
        Provider.of<StoreSessionProvider>(context, listen: false);

    debugPrint('🚀 SAVE QUOTATION TRIGGERED');
    debugPrint(
        '   - Has Selected Customer: ${customerProvider.hasSelectedCustomer}');
    debugPrint(
        '   - Selected Customer ID: ${customerProvider.selectedCustomerID}');
    debugPrint('   - Active Store ID: ${storeProvider.activeStore?.storeId}');
    debugPrint('   - Items Count: ${_items.length}');

    final hasInlineCustomer =
        _inlineCustomerNameController.text.trim().isNotEmpty &&
            _inlineCustomerPhoneController.text.trim().isNotEmpty;
    if (!_useInlineCustomer && !customerProvider.hasSelectedCustomer) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('create_quotation.msg_select_customer'.tr)));
      return;
    }
    if (_useInlineCustomer && !hasInlineCustomer) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('create_quotation.msg_enter_customer_info'.tr)));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('create_quotation.msg_add_item'.tr)));
      return;
    }

    setState(() => _isSaving = true);
    final payload = {
      if (_useInlineCustomer) ...{
        'customer_type': 'new',
        'customer_name': _inlineCustomerNameController.text.trim(),
        'customer_phone': _inlineCustomerPhoneController.text.trim(),
      } else ...{
        'customer_type': 'existing',
        'customer_id': customerProvider.selectedCustomerID,
      },
      'store_id': storeProvider.activeStore?.storeId,
      'quotation_date': DateFormat('yyyy-MM-dd').format(_quotationDate),
      'expiry_date': DateFormat('yyyy-MM-dd').format(_expiryDate),
      'quotation_number': _quotationNoController.text,
      'comment': _commentController.text,
      'items': _items.map((i) {
        final saleUnitId = (i.product.saleUnits?.isNotEmpty ?? false)
            ? i.product.saleUnits!.first.id
            : null;
        final itemMap = <String, dynamic>{
          'product_id': i.product.productId,
          'quantity': i.quantity,
          'price': i.unitPrice,
        };
        if (saleUnitId != null) {
          itemMap['product_sale_unit_id'] = saleUnitId;
        }
        return itemMap;
      }).toList(),
    };

    debugPrint('📤 QUOTATION PAYLOAD: ${json.encode(payload)}');

    try {
      final authProvider = Provider.of<AuthModel>(context, listen: false);
      final quotationProvider =
          Provider.of<QuotationsProvider>(context, listen: false);
      final response = await quotationProvider.createQuotation(
          accessToken: authProvider.token ?? '', data: payload);

      debugPrint('📥 QUOTATION API RESPONSE: $response');

      if (!mounted) return;
      if (response['success'] == true || response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('create_quotation.msg_success'.tr)));
        Get.find<SideBarController>().index.value = 87;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                response['message'] ?? 'create_quotation.msg_failed'.tr)));
      }
    } catch (e) {
      debugPrint('💥 QUOTATION ERROR: $e');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final currency = Provider.of<AppSettingsProvider>(context, listen: false)
            .appSettings
            ?.currency ??
        '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildTopSection(size),
                      const SizedBox(height: 24),
                      _buildProductEntryCard(size),
                      if (_items.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildItemsTable(currency),
                        const SizedBox(height: 24),
                        _buildSummarySection(size, currency),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.find<SideBarController>().index.value = 87,
            icon: const Icon(Icons.arrow_back_ios_new,
                color: ColorManager.kPrimaryColor, size: 20),
          ),
          Text('create_quotation.title'.tr,
              style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s18,
                  0.2, ColorManager.textColor)),
        ],
      ),
    );
  }

  Widget _buildTopSection(Size size) {
    return BuildBoxShadowContainer(
      padding: const EdgeInsets.all(16),
      circleRadius: 15,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 20, color: ColorManager.kPrimaryColor),
              const SizedBox(width: 8),
              Text('create_quotation.section_details'.tr,
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s15, 0.1, ColorManager.textColor)),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: _buildFieldColumn(
                          'create_quotation.field_quotation_no'.tr,
                          _simpleEntryField(
                              controller: _quotationNoController,
                              hint: 'Auto Generated'))),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildFieldColumn(
                          'create_quotation.field_quotation_date'.tr,
                          _buildDateField(true))),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildFieldColumn(
                          'create_quotation.field_expiry_date'.tr,
                          _buildDateField(false))),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildFieldColumn(
                          'create_quotation.field_store'.tr,
                          _buildStoreDropdown())),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _buildFieldColumn(
                          'create_quotation.field_customer'.tr,
                          _buildCustomerSelector())),
                  const Expanded(
                      flex: 3,
                      child: SizedBox()), // Fill remaining 3/4 of the row
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSelector() {
    return Column(
      children: [
        Row(
          children: [
            Switch(
              value: _useInlineCustomer,
              onChanged: (value) {
                setState(() => _useInlineCustomer = value);
                if (value) {
                  Provider.of<CustomerSelectionProvider>(context, listen: false)
                      .clearSelectedCustomer();
                }
              },
            ),
            const SizedBox(width: 8),
            Text(
              _useInlineCustomer
                  ? 'create_quotation.toggle_quote_only'.tr
                  : 'create_quotation.toggle_existing'.tr,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_useInlineCustomer) ...[
          _simpleEntryField(
            controller: _inlineCustomerNameController,
            hint: 'create_quotation.hint_customer_name'.tr,
          ),
          const SizedBox(height: 8),
          _simpleEntryField(
            controller: _inlineCustomerPhoneController,
            hint: 'create_quotation.hint_customer_phone'.tr,
            type: TextInputType.phone,
          ),
        ] else
          _buildCustomerDropdown(),
      ],
    );
  }

  Widget _buildFieldColumn(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label,
              style: buildCustomStyle(
                  FontWeightManager.medium, FontSize.s13, 0.1, Colors.black54)),
        ),
        field,
      ],
    );
  }

  Widget _buildDateField(bool isQuotation) {
    return _inputBox(
      child: InkWell(
        onTap: () => _selectDate(isQuotation),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 18, color: ColorManager.kPrimaryColor),
            const SizedBox(width: 10),
            Text(
                isQuotation
                    ? _quotationDateController.text
                    : _expiryDateController.text,
                style: buildCustomStyle(FontWeightManager.medium, FontSize.s14,
                    0.1, Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreDropdown() {
    return Consumer<StoreSessionProvider>(builder: (context, prov, _) {
      final List<Store> list = prov.availableStores;
      final Store? sel =
          list.firstWhereOrNull((s) => s.storeId == prov.activeStore?.storeId);
      return BuildDropDownWithSearch<Store>(
        title: null,
        showName: false,
        hintText: 'create_quotation.hint_select_store'.tr,
        value: sel,
        items: list,
        onChanged: (v) {},
        displayText: (v) => v.storeName ?? "",
        searchController: _storeSearchController,
        height: 45,
      );
    });
  }

  Widget _buildCustomerDropdown() {
    return Consumer<CustomerProvider>(builder: (context, prov, _) {
      final cp = Provider.of<CustomerSelectionProvider>(context, listen: false);
      return BuildDropDownWithSearch<CustomerListModelData>(
        title: null,
        showName: false,
        hintText: 'create_quotation.hint_select_customer'.tr,
        value: cp.selectedCustomer,
        items: prov.allCustomers ?? [],
        onChanged: (v) {
          if (v != null) cp.setSelectedCustomer(v);
        },
        displayText: (v) => "${v.name} (${v.phone})",
        searchController: _customerSearchController,
        height: 45,
      );
    });
  }

  Widget _buildProductEntryCard(Size size) {
    return BuildBoxShadowContainer(
      padding: const EdgeInsets.all(16),
      circleRadius: 15,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart_outlined,
                  size: 20, color: ColorManager.kPrimaryColor),
              const SizedBox(width: 8),
              Text('create_quotation.section_products'.tr,
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s15, 0.1, ColorManager.textColor)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: _buildFieldColumn('create_quotation.field_product'.tr, _buildProductSelector()),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _buildFieldColumn(
                    'create_quotation.field_qty'.tr,
                    _simpleEntryField(
                      controller: _qtyController,
                      hint: '1',
                      type: TextInputType.number,
                      onChanged: (val) => setState(() {}),
                    )),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _buildFieldColumn(
                    'create_quotation.field_price'.tr,
                    _simpleEntryField(
                      controller: _priceController,
                      hint: '0.00',
                      type: TextInputType.number,
                      onChanged: (val) => setState(() {}),
                    )),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _buildFieldColumn('create_quotation.field_tax'.tr, _buildTaxDropdown()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 1,
                child: _buildFieldColumn(
                    'create_quotation.field_total'.tr,
                    _simpleEntryField(
                      controller: TextEditingController(text: _calcItemTotal()),
                      readOnly: true,
                      boxColor: Colors.grey.shade50,
                    )),
              ),
              const SizedBox(width: 12),
              const Spacer(flex: 2),
              CustomRoundButton(
                title: 'create_quotation.btn_add_to_list'.tr,
                fct: _selectedProduct == null ? () {} : _addItem,
                height: 45,
                width: 160,
                fontSize: 14,
                boxColor: _selectedProduct == null
                    ? Colors.grey.shade300
                    : ColorManager.kPrimaryColor,
                textColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _calcItemTotal() {
    final qtyVal = double.tryParse(_qtyController.text) ?? 0;
    final pVal = double.tryParse(_priceController.text) ?? 0;
    final rVal = double.tryParse(_entryTax?.rate ?? '0') ?? 0;
    return (qtyVal * pVal * (1 + rVal / 100)).toStringAsFixed(2);
  }

  Widget _buildProductSelector() {
    return Consumer<LocalProductProvider>(builder: (context, prov, _) {
      return BuildDropDownWithSearch<GetProduct>(
        title: null,
        showName: false,
        hintText: 'create_quotation.hint_search_product'.tr,
        value: _selectedProduct,
        items: prov.products,
        onChanged: (v) {
          if (v != null) _onProductSelected(v);
        },
        displayText: (v) => v.productName ?? "",
        searchController: _productSearchController,
        height: 45,
      );
    });
  }

  Widget _buildTaxDropdown() {
    return _inputBox(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProductTax>(
          value: _entryTax,
          isExpanded: true,
          hint: Text('ui_codes.no_tax'.tr, style: const TextStyle(fontSize: 12)),
          items: (_selectedProduct?.taxes ?? [])
              .map((t) => DropdownMenuItem(value: t, child: Text('${t.rate}%')))
              .toList(),
          onChanged: (v) => setState(() => _entryTax = v),
        ),
      ),
    );
  }

  Widget _inputBox({required Widget child}) {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorManager.kPrimaryColor.withOpacity(0.2)),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  Widget _simpleEntryField({
    TextEditingController? controller,
    String? hint,
    IconData? icon,
    TextInputType? type,
    bool readOnly = false,
    Color? boxColor,
    Function(String)? onChanged,
  }) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: boxColor ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorManager.kPrimaryColor.withOpacity(0.15)),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: type,
        onChanged: onChanged,
        style: buildCustomStyle(
            FontWeightManager.medium, FontSize.s14, 0.1, Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          prefixIcon: icon != null
              ? Icon(icon, size: 18, color: ColorManager.kPrimaryColor)
              : null,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildItemsTable(String currency) {
    return BuildBoxShadowContainer(
      padding: EdgeInsets.zero,
      circleRadius: 12,
      child: Column(
        children: [
          _tblHeader(),
          ..._items
              .asMap()
              .entries
              .map((e) => _tblRow(e.value, e.key, currency)),
        ],
      ),
    );
  }

  Widget _tblHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: ColorManager.kPrimaryColor.withOpacity(0.05),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
      child: Row(children: [
        Expanded(
            flex: 3,
            child: Text('create_quotation.col_product'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(
            child: Text('create_quotation.col_qty'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(
            flex: 2,
            child: Text('create_quotation.col_price'.tr,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(
            flex: 2,
            child: Text('create_quotation.col_total'.tr,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        const SizedBox(width: 40),
      ]),
    );
  }

  Widget _tblRow(QuotationItem item, int idx, String curr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(children: [
        Expanded(
            flex: 3,
            child: Text(item.product.productName ?? "",
                style: const TextStyle(fontSize: 13))),
        Expanded(
            child: Text(item.quantity.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13))),
        Expanded(
            flex: 2,
            child: Text(item.unitPrice.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13))),
        Expanded(
            flex: 2,
            child: Text(item.totalPrice.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13))),
        IconButton(
            onPressed: () => _removeItem(idx),
            icon:
                const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
      ]),
    );
  }

  Widget _buildSummarySection(Size size, String curr) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: _buildFieldColumn(
                'create_quotation.field_comment'.tr,
                _simpleEntryField(
                    controller: _commentController,
                    hint: 'create_quotation.hint_notes'.tr))),
        const SizedBox(width: 40),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _sumLine('create_quotation.sum_subtotal'.tr, _subTotal, curr),
            _sumLine('create_quotation.sum_tax'.tr, _totalTax, curr),
            const SizedBox(height: 8),
            Container(width: 200, height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 8),
            _sumLine('create_quotation.sum_grand_total'.tr, _grandTotal, curr,
                isTotal: true),
            const SizedBox(height: 20),
            Row(children: [
              CustomRoundButton(
                  title: 'create_quotation.btn_clear'.tr,
                  fct: () => setState(() => _items.clear()),
                  height: 45,
                  width: 100,
                  fontSize: 14,
                  boxColor: Colors.red.shade400,
                  textColor: Colors.white),
              const SizedBox(width: 12),
              CustomRoundButton(
                  title: 'create_quotation.btn_save'.tr,
                  fct: _saveQuotation,
                  height: 45,
                  width: 160,
                  fontSize: 14,
                  boxColor: ColorManager.kButtonGreen,
                  isLoading: _isSaving,
                  textColor: Colors.white),
            ]),
          ],
        ),
      ],
    );
  }

  Widget _sumLine(String lbl, double amt, String curr, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('$lbl: $curr ${amt.toStringAsFixed(2)}',
          style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? ColorManager.kPrimaryColor : Colors.black87)),
    );
  }

  Future<void> _selectDate(bool isQuotation) async {
    final picked = await showDatePicker(
        context: context,
        initialDate: isQuotation ? _quotationDate : _expiryDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (picked != null) {
      setState(() {
        if (isQuotation) {
          _quotationDate = picked;
          _quotationDateController.text =
              DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _expiryDate = picked;
          _expiryDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }
}
