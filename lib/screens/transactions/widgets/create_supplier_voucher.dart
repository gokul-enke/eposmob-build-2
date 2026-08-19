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
  final FocusNode plusFocus = FocusNode();

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
    plusFocus.dispose();
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
  final TextEditingController netTotalController = TextEditingController();
  final TextEditingController totalTaxController = TextEditingController();
  final TextEditingController totalAmountController = TextEditingController();

  // Date controllers
  DateTime selectedVoucherDate = DateTime.now();
  DateTime selectedDueDate = DateTime.now(); // Changed to today's date

  // Focus Nodes for keyboard navigation
  final FocusNode typeFocus = FocusNode();
  final FocusNode voucherDateFocus = FocusNode();
  final FocusNode dueDateFocus = FocusNode();
  final FocusNode statusFocus = FocusNode();
  final FocusNode paymentMethodFocus = FocusNode();
  final FocusNode supplierFocus = FocusNode();

  // Dropdown selections
  String? selectedType;
  String? selectedStatus = 'paid'; // Default to 'paid'
  String? selectedPaymentMethod;
  int? selectedSupplierId;
  String? selectedSupplierName;

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

    // Add listeners to initial item
    for (var item in voucherItems) {
      _addItemListeners(item);
    }
  }

  void _addItemListeners(VoucherItem item) {
    item.unitAmountController.addListener(_calculateTotal);
    item.taxController.addListener(_calculateTotal);
    item.quantityController.addListener(_calculateTotal);
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
      final int? activeStoreId = prefs.getInt('active_store_id');

      if (accessToken == null || apiKey == null) return;

      final Map<String, String> queryParameters = {};
      if (activeStoreId != null) {
        queryParameters['store_id'] = activeStoreId.toString();
      }
      final url = Uri.parse(APPUrl.getSuppliers)
          .replace(queryParameters: queryParameters);

      final response = await http.get(
        url,
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
    double netTotal = 0;
    double totalTax = 0;
    double total = 0;
    for (var item in voucherItems) {
      try {
        double unitAmount =
            double.tryParse(item.unitAmountController.text) ?? 0;
        double quantity = double.tryParse(item.quantityController.text) ?? 1;
        double taxRate = double.tryParse(item.taxController.text) ?? 0;
        double itemNetTotal = unitAmount * quantity;
        double itemTax = itemNetTotal * (taxRate / 100);
        double itemTotal = itemNetTotal + itemTax;
        item.totalController.text = itemTotal.toStringAsFixed(2);
        netTotal += itemNetTotal;
        totalTax += itemTax;
        total += itemTotal;
      } catch (e) {
        debugPrint("Error calculating total: $e");
      }
    }
    netTotalController.text = netTotal.toStringAsFixed(2);
    totalTaxController.text = totalTax.toStringAsFixed(2);
    totalAmountController.text = total.toStringAsFixed(2);

    // Trigger rebuild to update summary text fields
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submitVoucher() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedSupplierId == null) {
      showScaffoldError(context: context, message: 'supplier_voucher.select_supplier_required'.tr);
      return;
    }
    if (selectedType == null) {
      showScaffoldError(context: context, message: 'supplier_voucher.select_type_required'.tr);
      return;
    }
    if (selectedStatus == null) {
      showScaffoldError(context: context, message: 'supplier_voucher.select_status_required'.tr);
      return;
    }
    if (selectedPaymentMethod == null) {
      showScaffoldError(
          context: context, message: 'supplier_voucher.select_payment_method_required'.tr);
      return;
    }
    if (voucherItems.isEmpty ||
        voucherItems.every((item) => item.itemNameController.text.isEmpty)) {
      showScaffoldError(
          context: context, message: 'supplier_voucher.add_at_least_one_item_required'.tr);
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
        dueDate: DateFormat('yyyy-MM-dd')
            .format(selectedVoucherDate), //only voucher date
        status: selectedStatus!,
        paymentMethodId: _getPaymentMethodId(selectedPaymentMethod),
        voucherItems: items,
        accessToken: accessToken ?? '',
      );

      if (result['success']) {
        showScaffold(
          context: context,
          message: result['message'] ?? 'supplier_voucher.created_successfully'.tr,
        );
        sideBarController.index.value =
            (sideBarController.index.value == 76) ? 75 : 72;
      } else {
        showScaffoldError(
          context: context,
          message: result['message'] ?? 'supplier_voucher.create_failed'.tr,
        );
      }
    } catch (e) {
      showScaffoldError(context: context, message: 'supplier_voucher.error_generic'.tr.replaceAll('@error', e.toString()));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 700;
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
                  Expanded(
                    child: Text(
                      'supplier_voucher.create_voucher_button'.tr,
                      style: buildCustomStyle(FontWeightManager.bold,
                          isMobile ? FontSize.s18 : FontSize.s24, 0.36, Colors.black),
                      overflow: TextOverflow.ellipsis,
                    ),
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
                      isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSupplierDropdown(),
                                const SizedBox(height: 12),
                                _buildTypeDropdown(),
                                const SizedBox(height: 12),
                                _buildDateField(
                                  'supplier_voucher.voucher_date_label'.tr,
                                  selectedVoucherDate,
                                  (DateTime date) =>
                                      setState(() => selectedVoucherDate = date),
                                  voucherDateFocus,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: _buildSupplierDropdown()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildTypeDropdown()),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDateField(
                                    'supplier_voucher.voucher_date_label'.tr,
                                    selectedVoucherDate,
                                    (DateTime date) =>
                                        setState(() => selectedVoucherDate = date),
                                    voucherDateFocus,
                                  ),
                                ),
                              ],
                            ),
                      // const SizedBox(height: 16),
                      // Second row: Voucher Date, Due Date, Status
                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: _buildDateField(
                      //         'Voucher date',
                      //         selectedVoucherDate,
                      //         (DateTime date) =>
                      //             setState(() => selectedVoucherDate = date),
                      //       ),
                      //     ),
                      //     const SizedBox(width: 16),
                      //     Expanded(
                      //       child: _buildDateField(
                      //         'Due date',
                      //         selectedDueDate,
                      //         (DateTime date) =>
                      //             setState(() => selectedDueDate = date),
                      //       ),
                      //     ),
                      //     const SizedBox(width: 16),
                      //     Expanded(
                      //       child: _buildStatusDropdown(),
                      //     ),
                      //   ],
                      // ),
                      const SizedBox(height: 16),
                      // Third row: Payment Method, Supplier
                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: _buildPaymentMethodDropdown(),
                      //     ),
                      //     const SizedBox(width: 16),
                      //     Expanded(
                      //       child: _buildSupplierDropdown(),
                      //     ),
                      //   ],
                      // ),
                      // const SizedBox(height: 24),
                      Text(
                        'supplier_voucher.voucher_items_label'.tr,
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s16, 0.27, Colors.black),
                      ),
                      const SizedBox(height: 10),
                      isMobile
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: 650,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildItemsTableHeader(),
                                    const SizedBox(height: 8),
                                    ..._buildItemRows(),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildItemsTableHeader(),
                                const SizedBox(height: 8),
                                ..._buildItemRows(),
                              ],
                            ),
                      const SizedBox(height: 16),
                     isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildPaymentMethodDropdown(),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                _buildSummaryLine('supplier_voucher.net_total_label'.tr, netTotalController.text),
                                _buildSummaryLine('supplier_voucher.total_tax_label'.tr, totalTaxController.text),
                                _buildSummaryLine('supplier_voucher.total_payable_label'.tr, totalAmountController.text),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildPaymentMethodDropdown()),
                                Expanded(flex: 2, child: const SizedBox()),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      _buildSummaryLine('supplier_voucher.net_total_label'.tr, netTotalController.text),
                                      _buildSummaryLine('supplier_voucher.total_tax_label'.tr, totalTaxController.text),
                                      _buildSummaryLine('supplier_voucher.total_payable_label'.tr, totalAmountController.text),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                      // Center(
                      // child: CustomRoundButton(
                      //   title: "Add to voucher items",
                      //   boxColor: Colors.white,
                      //   textColor: ColorManager.kPrimaryColor,
                      //   borderColor: ColorManager.kPrimaryColor,
                      //   fct: () {
                      // setState(() {
                      //   voucherItems.add(VoucherItem());
                      // });
                      //   },
                      //   height: 45,
                      //   width: 200,
                      //   fontSize: FontSize.s12,
                      // ),
                      // ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              isMobile
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: CustomRoundButton(
                            title: _isLoading ? 'supplier_voucher.submitting'.tr : 'supplier_voucher.submit_button'.tr,
                            boxColor: ColorManager.kPrimaryColor,
                            textColor: Colors.white,
                            fct: _isLoading ? () {} : _submitVoucher,
                            height: 45,
                            width: double.infinity,
                            fontSize: FontSize.s12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: CustomRoundButton(
                            title: 'general.cancel'.tr,
                            boxColor: Colors.white,
                            textColor: ColorManager.kPrimaryColor,
                            borderColor: ColorManager.kPrimaryColor,
                            fct: () => sideBarController.index.value =
                                (sideBarController.index.value == 76) ? 75 : 72,
                            height: 45,
                            width: double.infinity,
                            fontSize: FontSize.s12,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CustomRoundButton(
                          title: 'general.cancel'.tr,
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
                          title: _isLoading ? 'supplier_voucher.submitting'.tr : 'supplier_voucher.submit_button'.tr,
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

  Widget _buildSummaryLine(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value.isEmpty ? '0' : value,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
          'supplier_voucher.type_label'.tr,
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<String>(
          focusNode: typeFocus,
          title: null,
          showName: false,
          hintText: 'supplier_voucher.select_type_hint'.tr,
          value: selectedType,
          items: typeOptions.map((t) => t['value']!).toList(),
          onChanged: (String? value) {
            setState(() => selectedType = value);
            // Navigate to next field after selection
          },
          displayText: (String? value) {
            if (value == null) return 'supplier_voucher.select_type_hint'.tr;
            switch (value) {
              case 'order':
                return 'supplier_voucher.type_order'.tr;
              case 'discount':
                return 'supplier_voucher.type_discount'.tr;
              case 'other':
                return 'supplier_voucher.type_other'.tr;
              default:
                return 'general.unknown'.tr;
            }
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
          focusNode: statusFocus,
          title: null,
          showName: false,
          hintText: 'supplier_voucher.hint_select_status'.tr,
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
    FocusNode focusNode,
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
            focusNode: focusNode,
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
          'supplier_voucher.payment_method_label'.tr,
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<String>(
          focusNode: paymentMethodFocus,
          title: null,
          showName: false,
          hintText:
              _isLoadingPaymentMethods ? 'supplier_voucher.loading'.tr : 'supplier_voucher.select_payment_method_hint'.tr,
          value: selectedPaymentMethod,
          items: _paymentMethods.map((m) => m.value).toList(),
          onChanged: (String? value) {
            setState(() => selectedPaymentMethod = value);
            // Navigate to next field after selection
          },
          displayText: (String? value) {
            if (value == null) return 'supplier_voucher.select_payment_method_hint'.tr;
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
          'supplier_voucher.supplier_label'.tr,
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<int>(
          focusNode: supplierFocus,
          title: null,
          showName: false,
          hintText: 'supplier_voucher.select_supplier_hint'.tr,
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
            if (id == null) return 'supplier_voucher.select_supplier_hint'.tr;
            final supplier =
                suppliers.firstWhere((c) => c['id'] == id, orElse: () => {});
            return supplier['name'] ?? supplier['user']?['name'] ?? 'general.unknown'.tr;
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
                'supplier_voucher.col_item_name_required'.tr,
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s11, 0.18, ColorManager.kPrimaryColor),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'supplier_voucher.col_unit_amount_required'.tr,
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
                'supplier_voucher.col_tax_percent'.tr,
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
                'supplier_voucher.col_quantity'.tr,
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
                'supplier_voucher.col_total'.tr,
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

      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ListenableBuilder(
                listenable: item.itemNameFocus,
                builder: (context, _) {
                  final hasFocus = item.itemNameFocus.hasFocus;
                  return BuildBoxShadowContainer(
                    height: 45,
                    circleRadius: 7,
                    border: hasFocus
                        ? Border.all(color: ColorManager.kPrimaryColor, width: 1.2)
                        : null,
                    showShadow: !hasFocus,
                    boxShadow: hasFocus ? [
                      BoxShadow(
                        color: ColorManager.kPrimaryColor.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1.5,
                      ),
                    ] : null,
                    child: TextFormField(
                      controller: item.itemNameController,
                      focusNode: item.itemNameFocus,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(item.unitAmountFocus);
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'supplier_voucher.item_name_hint'.tr,
                        contentPadding: const EdgeInsets.only(left: 15),
                      ),
                      style: buildCustomStyle(FontWeightManager.medium,
                          FontSize.s12, 0.27, ColorManager.textColor),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: item.unitAmountFocus,
                builder: (context, _) {
                  final hasFocus = item.unitAmountFocus.hasFocus;
                  return BuildBoxShadowContainer(
                    height: 45,
                    circleRadius: 7,
                    border: hasFocus
                        ? Border.all(color: ColorManager.kPrimaryColor, width: 1.2)
                        : null,
                    showShadow: !hasFocus,
                    boxShadow: hasFocus ? [
                      BoxShadow(
                        color: ColorManager.kPrimaryColor.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1.5,
                      ),
                    ] : null,
                    child: TextFormField(
                      controller: item.unitAmountController,
                      focusNode: item.unitAmountFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
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
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: item.taxFocus,
                builder: (context, _) {
                  final hasFocus = item.taxFocus.hasFocus;
                  return BuildBoxShadowContainer(
                    height: 45,
                    circleRadius: 7,
                    border: hasFocus
                        ? Border.all(color: ColorManager.kPrimaryColor, width: 1.2)
                        : null,
                    showShadow: !hasFocus,
                    boxShadow: hasFocus ? [
                      BoxShadow(
                        color: ColorManager.kPrimaryColor.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1.5,
                      ),
                    ] : null,
                    child: TextFormField(
                      controller: item.taxController,
                      focusNode: item.taxFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
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
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: item.quantityFocus,
                builder: (context, _) {
                  final hasFocus = item.quantityFocus.hasFocus;
                  return BuildBoxShadowContainer(
                    height: 45,
                    circleRadius: 7,
                    border: hasFocus
                        ? Border.all(color: ColorManager.kPrimaryColor, width: 1.2)
                        : null,
                    showShadow: !hasFocus,
                    boxShadow: hasFocus ? [
                      BoxShadow(
                        color: ColorManager.kPrimaryColor.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1.5,
                      ),
                    ] : null,
                    child: TextFormField(
                      controller: item.quantityController,
                      focusNode: item.quantityFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        // When Enter is pressed on quantity field, add new item and focus on its name field
                        if (isLastItem && item.itemNameController.text.isNotEmpty) {
                          setState(() {
                            var newItem = VoucherItem();
                            _addItemListeners(newItem);
                            voucherItems.add(newItem);
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
                  );
                },
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
            voucherItems.length <= 1 || voucherItems.length == index + 1
                ? ListenableBuilder(
                    listenable: item.plusFocus,
                    builder: (context, _) {
                      final hasFocus = item.plusFocus.hasFocus;
                      return InkWell(
                        focusNode: item.plusFocus,
                        onTap: () {
                          setState(() {
                            var newItem = VoucherItem();
                            _addItemListeners(newItem);
                            voucherItems.add(newItem);
                          });
                        },
                        child: Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: ColorManager.kPrimaryColor,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: hasFocus ? Colors.white : Colors.transparent,
                              width: hasFocus ? 2 : 1,
                            ),
                            boxShadow: [
                              if (hasFocus)
                                BoxShadow(
                                  color: ColorManager.kPrimaryColor.withOpacity(0.55),
                                  blurRadius: 8,
                                  spreadRadius: 2.5,
                                )
                              else
                                const BoxShadow(
                                  color: ColorManager.boxShadowColor,
                                  blurRadius: 3,
                                  offset: Offset(1, 1),
                                ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  )
                : IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        // Clean up listeners before removing
                        item.unitAmountController
                            .removeListener(_calculateTotal);
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
    netTotalController.dispose();
    totalTaxController.dispose();
    totalAmountController.dispose();
    typeFocus.dispose();
    voucherDateFocus.dispose();
    dueDateFocus.dispose();
    statusFocus.dispose();
    paymentMethodFocus.dispose();
    supplierFocus.dispose();

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
