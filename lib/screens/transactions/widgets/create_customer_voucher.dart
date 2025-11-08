import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_voucher_provider.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class VoucherItem {
  String itemName;
  String unitAmount;
  String tax;
  String quantity;
  String totalAmount;
  bool isExpanded;

  VoucherItem({
    this.itemName = '',
    this.unitAmount = '0',
    this.tax = '0',
    this.quantity = '1',
    this.totalAmount = '0',
    this.isExpanded = false,
  });
}

class CreateCustomerVoucherScreen extends StatefulWidget {
  const CreateCustomerVoucherScreen({super.key});

  @override
  State<CreateCustomerVoucherScreen> createState() =>
      _CreateCustomerVoucherScreenState();
}

class _CreateCustomerVoucherScreenState
    extends State<CreateCustomerVoucherScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SideBarController sideBarController = Get.put(SideBarController());

  // Form controllers
  final TextEditingController totalAmountController = TextEditingController();
  final TextEditingController customerSearchController =
      TextEditingController();

  // Date controllers
  DateTime selectedVoucherDate = DateTime.now();
  DateTime selectedDueDate = DateTime.now().add(const Duration(days: 7));

  // Dropdown selections
  String? selectedType;
  String? selectedStatus;
  String? selectedPaymentMethod;
  int? selectedCustomerId;
  String? selectedCustomerName;

  // Items list
  List<VoucherItem> voucherItems = [VoucherItem()];

  // Options lists - Backend values and display names
  List<Map<String, String>> typeOptions = [
    {'value': 'order', 'display': 'Order'},
    {'value': 'discount', 'display': 'Discount'},
    {'value': 'sales_return', 'display': 'Sales Return'},
    {'value': 'other', 'display': 'Other'},
  ];
  List<Map<String, String>> statusOptions = [
    {'value': 'paid', 'display': 'Paid'},
    {'value': 'pending', 'display': 'Pending'},
    {'value': 'overdue', 'display': 'Overdue'},
  ];
  List<Map<String, String>> paymentMethods = [
    {'value': 'COD', 'display': 'Cash On Delivery'},
    {'value': 'ONLINE', 'display': 'Online Payment'},
    {'value': 'CHEQUE', 'display': 'Cheque'},
    {'value': 'UPI', 'display': 'UPI'},
    {'value': 'CASH', 'display': 'Cash'},
  ];
  List<Map<String, dynamic>> customers = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? apiKey = prefs.getString('api_key');

      if (accessToken == null || apiKey == null) return;

      final response = await http.get(
        Uri.parse(APPUrl.customerListUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Tenant': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          customers = List<Map<String, dynamic>>.from(jsonData['data'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error loading customers: $e");
    }
  }

  void _calculateTotal() {
    double total = 0;
    for (var item in voucherItems) {
      try {
        double unitAmount = double.tryParse(item.unitAmount) ?? 0;
        double quantity = double.tryParse(item.quantity) ?? 1;
        double tax = double.tryParse(item.tax) ?? 0;
        double itemTotal = (unitAmount * quantity) + tax;
        item.totalAmount = itemTotal.toStringAsFixed(2);
        total += itemTotal;
      } catch (e) {
        debugPrint("Error calculating total: $e");
      }
    }
    totalAmountController.text = total.toStringAsFixed(2);
  }

  Future<void> _submitVoucher() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedCustomerId == null) {
      showScaffoldError(context: context, message: 'Please select a customer');
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
        voucherItems.every((item) => item.itemName.isEmpty)) {
      showScaffoldError(
          context: context, message: 'Please add at least one item');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      List<Map<String, dynamic>> items = voucherItems
          .where((item) => item.itemName.isNotEmpty)
          .map((item) => {
                'item_name': item.itemName,
                'quantity': double.tryParse(item.quantity) ?? 1,
                'unit_amount': double.tryParse(item.unitAmount) ?? 0,
                'tax': double.tryParse(item.tax) ?? 0,
                'total_amount': double.tryParse(item.totalAmount) ?? 0,
              })
          .toList();

      final result =
          await Provider.of<CustomerVoucherProvider>(context, listen: false)
              .createVoucher(
        type: selectedType!,
        amount: double.tryParse(totalAmountController.text) ?? 0,
        voucherDate: DateFormat('yyyy-MM-dd').format(selectedVoucherDate),
        dueDate: DateFormat('yyyy-MM-dd').format(selectedDueDate),
        status: selectedStatus!,
        paymentMethod: selectedPaymentMethod!,
        customerId: selectedCustomerId!,
        voucherItems: items,
        accessToken: accessToken ?? '',
      );

      if (result['success']) {
        showScaffold(
          context: context,
          message: result['message'] ?? 'Voucher created successfully',
        );
        // Navigate back to voucher list
        sideBarController.index.value = 70;
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Create Voucher",
                    style: buildCustomStyle(FontWeightManager.bold,
                        FontSize.s24, 0.36, Colors.black),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => sideBarController.index.value = 70,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Main content
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
                      // Third row: Payment Method, Customer
                      Row(
                        children: [
                          Expanded(
                            child: _buildPaymentMethodDropdown(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildCustomerDropdown(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Voucher Items Section
                      Text(
                        'Voucher items',
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s16, 0.27, Colors.black),
                      ),
                      const SizedBox(height: 16),
                      // Items table header
                      _buildItemsTableHeader(),
                      const SizedBox(height: 8),
                      // Items list
                      ..._buildItemRows(),
                      const SizedBox(height: 16),
                      // Add item button
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
              // Footer buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomRoundButton(
                    title: "Cancel",
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: () => sideBarController.index.value = 70,
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
          onChanged: (String? value) => setState(() => selectedType = value),
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
          onChanged: (String? value) => setState(() => selectedStatus = value),
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
          hintText: 'Select Payment Method',
          value: selectedPaymentMethod,
          items: paymentMethods.map((m) => m['value']!).toList(),
          onChanged: (String? value) =>
              setState(() => selectedPaymentMethod = value),
          displayText: (String? value) {
            if (value == null) return 'Select Payment Method';
            final method = paymentMethods.firstWhere((m) => m['value'] == value,
                orElse: () => {'display': 'Unknown'});
            return method['display']!;
          },
          height: 45,
        ),
      ],
    );
  }

  Widget _buildCustomerDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer*',
          style: buildCustomStyle(FontWeightManager.regular, FontSize.s14, 0.27,
              Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        BuildDropDownWithSearch<int>(
          title: null,
          showName: false,
          hintText: 'Select a customer',
          value: selectedCustomerId,
          items: customers.map((c) => c['id'] as int).toList(),
          onChanged: (int? value) {
            setState(() {
              selectedCustomerId = value;
              if (value != null) {
                final customer = customers.firstWhere((c) => c['id'] == value,
                    orElse: () => {});
                selectedCustomerName = customer['name'] ?? '';
              }
            });
          },
          displayText: (int? id) {
            if (id == null) return 'Select a customer';
            final customer =
                customers.firstWhere((c) => c['id'] == id, orElse: () => {});
            return customer['name'] ?? 'Unknown';
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
                  initialValue: item.itemName,
                  onChanged: (value) => setState(() => item.itemName = value),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Item name',
                    contentPadding: const EdgeInsets.only(left: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BuildBoxShadowContainer(
                height: 45,
                circleRadius: 7,
                child: TextFormField(
                  initialValue: item.unitAmount,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() => item.unitAmount = value);
                    _calculateTotal();
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    contentPadding: const EdgeInsets.only(left: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BuildBoxShadowContainer(
                height: 45,
                circleRadius: 7,
                child: TextFormField(
                  initialValue: item.tax,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() => item.tax = value);
                    _calculateTotal();
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    contentPadding: const EdgeInsets.only(left: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BuildBoxShadowContainer(
                height: 45,
                circleRadius: 7,
                child: TextFormField(
                  initialValue: item.quantity,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() => item.quantity = value);
                    _calculateTotal();
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '1',
                    contentPadding: const EdgeInsets.only(left: 15),
                  ),
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
                    item.totalAmount,
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
    customerSearchController.dispose();
    super.dispose();
  }
}
