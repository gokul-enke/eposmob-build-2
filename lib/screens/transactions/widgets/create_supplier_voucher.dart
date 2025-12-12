import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/supplier_voucher_provider.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class VoucherItem {
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController unitAmountController = TextEditingController();
  final TextEditingController taxController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController totalController = TextEditingController();

  final FocusNode itemNameFocus = FocusNode();
  final FocusNode unitAmountFocus = FocusNode();
  final FocusNode taxFocus = FocusNode();
  final FocusNode quantityFocus = FocusNode();
  final FocusNode totalFocus = FocusNode();

  VoucherItem() {
    unitAmountController.text = "0";
    taxController.text = "0";
    quantityController.text = "1";
    totalController.text = "0";
  }

  void dispose() {
    itemNameController.dispose();
    unitAmountController.dispose();
    taxController.dispose();
    quantityController.dispose();
    totalController.dispose();

    itemNameFocus.dispose();
    unitAmountFocus.dispose();
    taxFocus.dispose();
    quantityFocus.dispose();
    totalFocus.dispose();
  }
}

class CreateSupplierVoucherScreen extends StatefulWidget {
  const CreateSupplierVoucherScreen({super.key});

  @override
  State<CreateSupplierVoucherScreen> createState() =>
      _CreateSupplierVoucherScreenState();
}

class _CreateSupplierVoucherScreenState
    extends State<CreateSupplierVoucherScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SideBarController sideBarController = Get.put(SideBarController());

  // Form controllers
  final TextEditingController totalAmountController = TextEditingController();

  // Date controllers
  DateTime selectedVoucherDate = DateTime.now();
  DateTime selectedDueDate = DateTime.now(); // Changed to today's date

  // Dropdown selections
  String? selectedType;
  String? selectedStatus = 'paid'; // Default to 'paid'
  String? selectedPaymentMethod;
  int? selectedSupplierId;
  String? selectedSupplierName;

  // Focus Nodes
  final FocusNode _typeFocus = FocusNode();
  final FocusNode _voucherDateFocus = FocusNode();
  final FocusNode _dueDateFocus = FocusNode();
  final FocusNode _statusFocus = FocusNode();
  final FocusNode _paymentMethodFocus = FocusNode();
  final FocusNode _supplierFocus = FocusNode();

  // Items list
  List<VoucherItem> voucherItems = [VoucherItem()];

  // Options lists - Backend values and display names
  List<Map<String, String>> typeOptions = [
    {'value': 'order', 'display': 'Order'},
    {'value': 'discount', 'display': 'Discount'},
    {'value': 'other', 'display': 'Other'},
  ];
  List<Map<String, String>> statusOptions = [
    {'value': 'paid', 'display': 'Paid'},
    {'value': 'pending', 'display': 'Pending'},
    {'value': 'overdue', 'display': 'Overdue'},
  ];
  // Payment methods from API
  List<MasterDataValue> _paymentMethods = [];
  bool _isLoadingPaymentMethods = false;
  List<Map<String, dynamic>> suppliers = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    // Auto-focus on Type dropdown when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_typeFocus);
    });
  }

  Future<void> _loadInitialData() async {
    await _loadSuppliers();
    await _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() {
      _isLoadingPaymentMethods = true;
    });

    try {
      final masterDataProvider =
          Provider.of<MasterDataProvider>(context, listen: false);

      final paymentMethods = await masterDataProvider.fetchPaymentMethods();

      if (mounted && paymentMethods != null) {
        setState(() {
          _paymentMethods = paymentMethods;
          _isLoadingPaymentMethods = false;
          // Set default payment method if available and not already set
          if (_paymentMethods.isNotEmpty && selectedPaymentMethod == null) {
            final cashMethod =
                _paymentMethods.where((m) => m.value == 'CASH').firstOrNull;
            final codMethod =
                _paymentMethods.where((m) => m.value == 'COD').firstOrNull;
            if (cashMethod != null) {
              selectedPaymentMethod = 'CASH';
            } else if (codMethod != null) {
              selectedPaymentMethod = 'COD';
            } else {
              selectedPaymentMethod = _paymentMethods.first.value;
            }
          }
        });
        debugPrint(
            '📋 [Supplier Voucher] Payment methods loaded: $_paymentMethods');
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error loading payment methods: $e');
      setState(() {
        _isLoadingPaymentMethods = false;
      });
    }
  }

  Future<void> _loadSuppliers() async {
    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (accessToken == null || apiKey == null) return;

      final response = await http.get(
        Uri.parse(APPUrl.getSuppliers),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          suppliers = List<Map<String, dynamic>>.from(jsonData['data'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error loading suppliers: $e");
    }
  }

  void _calculateTotal() {
    double total = 0;
    for (var item in voucherItems) {
      try {
        double unitAmount =
            double.tryParse(item.unitAmountController.text) ?? 0;
        double quantity = double.tryParse(item.quantityController.text) ?? 1;
        double tax = double.tryParse(item.taxController.text) ?? 0;
        double itemTotal = (unitAmount * quantity) + tax;
        item.totalController.text = itemTotal.toStringAsFixed(2);
        total += itemTotal;
      } catch (e) {
        debugPrint("Error calculating total: $e");
      }
    }
    totalAmountController.text = total.toStringAsFixed(2);
  }

  Future<void> _submitVoucher() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedSupplierId == null) {
      showScaffoldError(context: context, message: 'Please select a supplier');
      return;
    }
    if (selectedType == null) {
      showScaffoldError(context: context, message: 'Please select a type');
      return;
    }
    if (selectedStatus == null) {
      showScaffoldError(context: context, message: 'Please select a status');
      return;
    }
    if (selectedPaymentMethod == null) {
      showScaffoldError(
          context: context, message: 'Please select a payment method');
      return;
    }
    if (voucherItems.isEmpty ||
        voucherItems.every((item) => item.itemNameController.text.isEmpty)) {
      showScaffoldError(
          context: context, message: 'Please add at least one item');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      List<Map<String, dynamic>> items = voucherItems
          .where((item) => item.itemNameController.text.isNotEmpty)
          .map((item) => {
                'item_name': item.itemNameController.text,
                'quantity': double.tryParse(item.quantityController.text) ?? 1,
                'unit_amount':
                    double.tryParse(item.unitAmountController.text) ?? 0,
                'tax': double.tryParse(item.taxController.text) ?? 0,
                'total_amount': double.tryParse(item.totalController.text) ?? 0,
              })
          .toList();

      final result =
          await Provider.of<SupplierVoucherProvider>(context, listen: false)
              .createVoucher(
        supplierId: selectedSupplierId!,
        type: selectedType!,
        amount: double.tryParse(totalAmountController.text) ?? 0,
        voucherDate: DateFormat('yyyy-MM-dd').format(selectedVoucherDate),
        dueDate: DateFormat('yyyy-MM-dd').format(selectedDueDate),
        status: selectedStatus!,
        paymentMethodId: _getPaymentMethodId(selectedPaymentMethod),
        voucherItems: items,
        accessToken: accessToken ?? '',
      );

      if (result['success']) {
        showScaffold(
          context: context,
          message: result['message'] ?? 'Voucher created successfully',
        );
        sideBarController.index.value =
            (sideBarController.index.value == 76) ? 75 : 72;
      } else {
        showScaffoldError(
          context: context,
          message: result['message'] ?? 'Failed to create voucher',
        );
      }
    } catch (e) {
      showScaffoldError(context: context, message: 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: ColorManager.boxShadowColor,
              blurRadius: 6,
              offset: Offset(1, 1),
            ),
          ],
          color: Colors.white,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Create Supplier Voucher",
                    style: buildCustomStyle(FontWeightManager.bold,
                        FontSize.s24, 0.36, Colors.black),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => sideBarController.index.value =
                        (sideBarController.index.value == 76) ? 75 : 72,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First row: Type, Total Amount
                      Row(
                        children: [
                          Expanded(
                            child: _buildTypeDropdown(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              'Total Voucher Amount',
                              totalAmountController,
                              '0',
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Second row: Voucher Date, Due Date, Status
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              'Voucher date',
                              selectedVoucherDate,
                              (DateTime date) =>
                                  setState(() => selectedVoucherDate = date),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDateField(
                              'Due date',
                              selectedDueDate,
                              (DateTime date) =>
                                  setState(() => selectedDueDate = date),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatusDropdown(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Third row: Payment Method, Supplier
                      Row(
                        children: [
                          Expanded(
                            child: _buildPaymentMethodDropdown(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSupplierDropdown(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Voucher items',
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s16, 0.27, Colors.black),
                      ),
                      const SizedBox(height: 16),
                      _buildItemsTableHeader(),
                      const SizedBox(height: 8),
                      ..._buildItemRows(),
                      const SizedBox(height: 16),
                      Center(
                        child: CustomRoundButton(
                          title: "Add to voucher items",
                          boxColor: Colors.white,
                          textColor: ColorManager.kPrimaryColor,
                          borderColor: ColorManager.kPrimaryColor,
                          fct: () {
                            setState(() {
                              voucherItems.add(VoucherItem());
                            });
                          },
                          height: 45,
                          width: 200,
                          fontSize: FontSize.s12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomRoundButton(
                    title: "Cancel",
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: () => sideBarController.index.value =
                        (sideBarController.index.value == 76) ? 75 : 72,
                    height: 45,
                    width: 120,
                    fontSize: FontSize.s12,
                  ),
                  const SizedBox(width: 16),
                  CustomRoundButton(
                    title: _isLoading ? "Submitting..." : "Submit",
                    boxColor: ColorManager.kPrimaryColor,
                    textColor: Colors.white,
                    fct: _isLoading ? () {} : _submitVoucher,
                    height: 45,
                    width: 120,
                    fontSize: FontSize.s12,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildBoxShadowContainer(
          height: 45,
          circleRadius: 7,
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: buildCustomStyle(FontWeightManager.medium,
                  FontSize.s12, 0.27, ColorManager.textColor.withOpacity(.5)),
              contentPadding: const EdgeInsets.only(left: 15),
            ),
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                0.27, ColorManager.textColor),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'This field is required';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type',
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<String>(
          title: null,
          showName: false,
          hintText: 'Select Type',
          value: selectedType,
          items: typeOptions.map((t) => t['value']!).toList(),
          onChanged: (String? value) {
            setState(() => selectedType = value);
            // Navigate to next field after selection
          },
          displayText: (String? value) {
            if (value == null) return 'Select Type';
            final type = typeOptions.firstWhere((t) => t['value'] == value,
                orElse: () => {'display': 'Unknown'});
            return type['display']!;
          },
          height: 45,
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<String>(
          title: null,
          showName: false,
          hintText: 'Select Status',
          value: selectedStatus,
          items: statusOptions.map((s) => s['value']!).toList(),
          onChanged: (String? value) {
            setState(() => selectedStatus = value);
            // Navigate to next field after selection
          },
          displayText: (String? value) {
            if (value == null) return 'Select Status';
            final status = statusOptions.firstWhere((s) => s['value'] == value,
                orElse: () => {'display': 'Unknown'});
            return status['display']!;
          },
          height: 45,
        ),
      ],
    );
  }

  Widget _buildDateField(
    String label,
    DateTime selectedDate,
    Function(DateTime) onDateSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 45,
          child: CalendarPickerTableCell(
            onDateSelected: onDateSelected,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment method',
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<String>(
          title: null,
          showName: false,
          hintText:
              _isLoadingPaymentMethods ? 'Loading...' : 'Select Payment Method',
          value: selectedPaymentMethod,
          items: _paymentMethods.map((m) => m.value).toList(),
          onChanged: (String? value) {
            setState(() => selectedPaymentMethod = value);
            // Navigate to next field after selection
          },
          displayText: (String? value) {
            if (value == null) return 'Select Payment Method';
            try {
              return _paymentMethods
                  .firstWhere((m) => m.value == value)
                  .description;
            } catch (e) {
              return value;
            }
          },
          height: 45,
        ),
      ],
    );
  }

  // Helper method to get payment method ID for API
  int? _getPaymentMethodId(String? paymentMethodValue) {
    if (paymentMethodValue == null || _paymentMethods.isEmpty) return null;
    try {
      return _paymentMethods
          .firstWhere((m) => m.value == paymentMethodValue)
          .id;
    } catch (e) {
      return null;
    }
  }

  Widget _buildSupplierDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supplier*',
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<int>(
          title: null,
          showName: false,
          hintText: 'Select a supplier',
          value: selectedSupplierId,
          items: suppliers.map((c) => c['id'] as int).toList(),
          onChanged: (int? value) {
            setState(() {
              selectedSupplierId = value;
              if (value != null) {
                final supplier = suppliers.firstWhere((c) => c['id'] == value,
                    orElse: () => {});
                selectedSupplierName =
                    supplier['name'] ?? supplier['user']?['name'] ?? '';
              }
            });
            // Focus will move to first item name field
          },
          displayText: (int? id) {
            if (id == null) return 'Select a supplier';
            final supplier =
                suppliers.firstWhere((c) => c['id'] == id, orElse: () => {});
            return supplier['name'] ?? supplier['user']?['name'] ?? 'Unknown';
          },
          height: 45,
        ),
      ],
    );
  }

  Widget _buildItemsTableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: ColorManager.tableBGColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Item name*',
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s11, 0.18, ColorManager.kPrimaryColor),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Unit amount*',
                textAlign: TextAlign.center,
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s11, 0.18, ColorManager.kPrimaryColor),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Tax',
                textAlign: TextAlign.center,
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s11, 0.18, ColorManager.kPrimaryColor),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Quantity',
                textAlign: TextAlign.center,
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s11, 0.18, ColorManager.kPrimaryColor),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Total',
                textAlign: TextAlign.center,
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s11, 0.18, ColorManager.kPrimaryColor),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  List<Widget> _buildItemRows() {
    return voucherItems.asMap().entries.map((entry) {
      int index = entry.key;
      VoucherItem item = entry.value;
      bool isLastItem = index == voucherItems.length - 1;

      // Add auto-calculation listeners
      if (!item.unitAmountController.hasListeners) {
        item.unitAmountController.addListener(_calculateTotal);
        item.taxController.addListener(_calculateTotal);
        item.quantityController.addListener(_calculateTotal);
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: BuildBoxShadowContainer(
                height: 45,
                circleRadius: 7,
                child: TextFormField(
                  controller: item.itemNameController,
                  focusNode: item.itemNameFocus,
                  textInputAction: TextInputAction.next,
                  onTap: () {
                    // Select all text when field is focused
                    item.itemNameController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: item.itemNameController.text.length,
                    );
                  },
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(item.unitAmountFocus);
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Item name',
                    contentPadding: EdgeInsets.only(left: 15),
                  ),
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s12, 0.27, ColorManager.textColor),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BuildBoxShadowContainer(
                height: 45,
                circleRadius: 7,
                child: TextFormField(
                  controller: item.unitAmountController,
                  focusNode: item.unitAmountFocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onTap: () {
                    // Select all text when field is focused
                    item.unitAmountController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: item.unitAmountController.text.length,
                    );
                  },
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(item.taxFocus);
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    contentPadding: EdgeInsets.only(left: 15),
                  ),
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s12, 0.27, ColorManager.textColor),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BuildBoxShadowContainer(
                height: 45,
                circleRadius: 7,
                child: TextFormField(
                  controller: item.taxController,
                  focusNode: item.taxFocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onTap: () {
                    // Select all text when field is focused
                    item.taxController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: item.taxController.text.length,
                    );
                  },
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(item.quantityFocus);
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    contentPadding: EdgeInsets.only(left: 15),
                  ),
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s12, 0.27, ColorManager.textColor),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BuildBoxShadowContainer(
                height: 45,
                circleRadius: 7,
                child: TextFormField(
                  controller: item.quantityController,
                  focusNode: item.quantityFocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onTap: () {
                    // Select all text when field is focused
                    item.quantityController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: item.quantityController.text.length,
                    );
                  },
                  onFieldSubmitted: (_) {
                    // When Enter is pressed on quantity field, add new item and focus on its name field
                    if (isLastItem && item.itemNameController.text.isNotEmpty) {
                      setState(() {
                        voucherItems.add(VoucherItem());
                      });
                      // Focus on the new item's name field after a short delay
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (voucherItems.length > index + 1) {
                          FocusScope.of(context).requestFocus(
                              voucherItems[index + 1].itemNameFocus);
                        }
                      });
                    }
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '1',
                    contentPadding: EdgeInsets.only(left: 15),
                  ),
                  style: buildCustomStyle(FontWeightManager.medium,
                      FontSize.s12, 0.27, ColorManager.textColor),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BuildBoxShadowContainer(
                height: 45,
                circleRadius: 7,
                child: Center(
                  child: Text(
                    item.totalController.text,
                    style: buildCustomStyle(FontWeightManager.medium,
                        FontSize.s12, 0.27, Colors.black),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                setState(() {
                  // Clean up listeners before removing
                  item.unitAmountController.removeListener(_calculateTotal);
                  item.taxController.removeListener(_calculateTotal);
                  item.quantityController.removeListener(_calculateTotal);
                  item.dispose();
                  voucherItems.removeAt(index);
                  _calculateTotal();
                });
              },
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    totalAmountController.dispose();

    // Dispose focus nodes
    _typeFocus.dispose();
    _voucherDateFocus.dispose();
    _dueDateFocus.dispose();
    _statusFocus.dispose();
    _paymentMethodFocus.dispose();
    _supplierFocus.dispose();

    // Dispose all voucher items
    for (var item in voucherItems) {
      item.unitAmountController.removeListener(_calculateTotal);
      item.taxController.removeListener(_calculateTotal);
      item.quantityController.removeListener(_calculateTotal);
      item.dispose();
    }

    super.dispose();
  }
}
