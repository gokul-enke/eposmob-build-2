import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/newcomponents/custom_round_button.dart';
import 'package:pos_machine/newcomponents/custom_container_box.dart';
import 'package:pos_machine/newcomponents/custom_calendar_selection.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:provider/provider.dart';

Future<dynamic> showCreateInvoiceModal(BuildContext context, Size size) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.transparent,
        child: Container(
          width: size.width * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: CreateInvoiceModal(size: size),
        ),
      );
    },
  );
}

class CreateInvoiceModal extends StatefulWidget {
  final Size size;

  const CreateInvoiceModal({super.key, required this.size});

  @override
  State<CreateInvoiceModal> createState() => _CreateInvoiceModalState();
}

class InvoiceItemCard {
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

  InvoiceItemCard() {
    unitAmountController.text = "0";
    taxController.text = "0";
    quantityController.text = "1";
    totalController.text = "0";

    // Auto-calculate total when values change
    unitAmountController.addListener(_calculateTotal);
    taxController.addListener(_calculateTotal);
    quantityController.addListener(_calculateTotal);
  }

  void _calculateTotal() {
    final unitAmount = double.tryParse(unitAmountController.text) ?? 0;
    final tax = double.tryParse(taxController.text) ?? 0;
    final quantity = double.tryParse(quantityController.text) ?? 1;
    final total = (unitAmount + tax) * quantity;
    totalController.text = total.toStringAsFixed(2);
  }

  void dispose() {
    unitAmountController.removeListener(_calculateTotal);
    taxController.removeListener(_calculateTotal);
    quantityController.removeListener(_calculateTotal);

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

class _CreateInvoiceModalState extends State<CreateInvoiceModal> {
  // Controllers
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _invoiceDateController = TextEditingController();

  // Focus Nodes - Flow: Type -> Due Date -> Invoice Date -> Status -> Customer -> Item Fields
  final FocusNode _typeFocus = FocusNode();
  final FocusNode _dueDateFocus = FocusNode();
  final FocusNode _invoiceDateFocus = FocusNode();
  final FocusNode _statusFocus = FocusNode();
  final FocusNode _customerFocus = FocusNode();

  // Selected values
  String? _selectedType;
  String? _selectedStatus;
  String? _selectedCustomer;

  // Loading state
  bool _isSubmitting = false;

  // Customer data
  List<CustomerListModelData> _customerList = [];
  bool _isLoadingCustomers = false;

  // Invoice items
  final List<InvoiceItemCard> _invoiceItemCards = [];
  late InvoiceItemCard _newItemCard;

  @override
  void initState() {
    super.initState();
    // Set default values
    _totalAmountController.text = "0";
    _dueDateController.text = DateTime.now()
        .add(const Duration(days: 30))
        .toIso8601String()
        .split('T')[0];
    _invoiceDateController.text =
        DateTime.now().toIso8601String().split('T')[0];
    _selectedType = "Other";
    _selectedStatus = "Pending";

    // Initialize new item card for inline form
    _newItemCard = InvoiceItemCard();
    _newItemCard.totalController.addListener(_calculateInvoiceTotal);

    // Load customers
    _loadCustomers();

    // Auto-focus on Type dropdown when modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_typeFocus);
    });
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
    _dueDateController.dispose();
    _invoiceDateController.dispose();

    _typeFocus.dispose();
    _dueDateFocus.dispose();
    _invoiceDateFocus.dispose();
    _statusFocus.dispose();
    _customerFocus.dispose();

    _newItemCard.totalController.removeListener(_calculateInvoiceTotal);
    _newItemCard.dispose();

    for (var card in _invoiceItemCards) {
      card.totalController.removeListener(_calculateInvoiceTotal);
      card.dispose();
    }

    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoadingCustomers = true);
    try {
      final customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);
      final authModel = Provider.of<AuthModel>(context, listen: false);
      await customerProvider.fetchCustomers(
        accessToken: authModel.token ?? "",
      );
      if (mounted) {
        setState(() {
          _customerList = customerProvider.customerList ?? [];
          _isLoadingCustomers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCustomers = false);
      }
      debugPrint("Error loading customers: $e");
    }
  }

  // Get customer balance by ID
  double _getCustomerBalance(String? customerId) {
    if (customerId == null) return 0.0;
    final customer = _customerList.firstWhere(
      (c) => c.id?.toString() == customerId,
      orElse: () => CustomerListModelData(id: 0, name: "Unknown"),
    );
    return customer.balance ?? 0.0;
  }

  void _calculateInvoiceTotal() {
    double total = 0;
    for (var card in _invoiceItemCards) {
      total += double.tryParse(card.totalController.text) ?? 0;
    }
    _totalAmountController.text = total.toStringAsFixed(2);
  }

  void _addNewInvoiceItemCard() {
    // Validate new item
    if (_newItemCard.itemNameController.text.isEmpty) {
      showScaffold(context: context, message: "Please enter item name");
      return;
    }

    setState(() {
      // Create new card and copy values
      final newCard = InvoiceItemCard();
      newCard.itemNameController.text = _newItemCard.itemNameController.text;
      newCard.unitAmountController.text =
          _newItemCard.unitAmountController.text;
      newCard.taxController.text = _newItemCard.taxController.text;
      newCard.quantityController.text = _newItemCard.quantityController.text;
      newCard.totalController.text = _newItemCard.totalController.text;

      // Add listener for total calculation
      newCard.totalController.addListener(_calculateInvoiceTotal);

      _invoiceItemCards.add(newCard);

      // Reset new item card
      _newItemCard.itemNameController.clear();
      _newItemCard.unitAmountController.text = "0";
      _newItemCard.taxController.text = "0";
      _newItemCard.quantityController.text = "1";
      _newItemCard.totalController.text = "0";

      // Recalculate total
      _calculateInvoiceTotal();
    });

    // Refocus on item name for next entry
    FocusScope.of(context).requestFocus(_newItemCard.itemNameFocus);
  }

  void _removeInvoiceItemCard(int index) {
    setState(() {
      _invoiceItemCards[index]
          .totalController
          .removeListener(_calculateInvoiceTotal);
      _invoiceItemCards[index].dispose();
      _invoiceItemCards.removeAt(index);
      _calculateInvoiceTotal();
    });
  }

  // Helper method to build labels
  Widget _buildLabel(String text, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s14,
          0.27,
          ColorManager.textColor,
        ),
        children: isRequired
            ? [
                TextSpan(
                  text: '*',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s14,
                    0.27,
                    Colors.red,
                  ),
                ),
              ]
            : [],
      ),
    );
  }

  // Helper for table header
  Widget _buildTableHeader(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(
          text,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.20,
            ColorManager.textColor,
          ),
        ),
      ),
    );
  }

  // Helper for inline input cell
  Widget _buildInputCell(
    TextEditingController controller,
    FocusNode focusNode, {
    int flex = 1,
    String hintText = "",
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    Function(String)? onFieldSubmitted,
    bool readOnly = false,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: readOnly ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onFieldSubmitted: onFieldSubmitted,
            readOnly: readOnly,
            onTap: () {
              // Select all text when field is focused
              controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              );
            },
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s13,
              0.20,
              ColorManager.textColor,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s13,
                0.20,
                Colors.grey.shade400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            inputFormatters: keyboardType == TextInputType.number
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _submitInvoice() async {
    // Validate
    if (_selectedCustomer == null) {
      showScaffoldError(context: context, message: "Please select a customer");
      return;
    }
    if (_invoiceItemCards.isEmpty) {
      showScaffoldError(
          context: context, message: "Please add at least one item");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);
      final authModel = Provider.of<AuthModel>(context, listen: false);

      // Build particulars from invoice items
      final particulars = _invoiceItemCards
          .map((card) =>
              "${card.itemNameController.text} (Qty: ${card.quantityController.text}, Amount: ${card.totalController.text})")
          .join("; ");

      final response = await invoiceProvider.addVoucher(
        accountType: "invoice",
        paymentMethod: "cash",
        paymentMethodRef: "",
        amount: _totalAmountController.text,
        toUserID: _selectedCustomer!,
        type: "invoice",
        comment:
            "Type: ${_selectedType ?? 'Other'}, Invoice Date: ${_invoiceDateController.text}, Due Date: ${_dueDateController.text}, Status: ${_selectedStatus ?? 'Pending'}",
        particular: particulars,
        accessToken: authModel.token ?? "",
      );

      if (!mounted) return;

      setState(() => _isSubmitting = false);

      if (response != null && response["status"] == "success") {
        Navigator.pop(context, true);
        showScaffold(
            context: context,
            message: response["message"] ?? "Invoice created successfully");
      } else {
        showScaffoldError(
            context: context,
            message: response?["message"] ?? "Failed to create invoice");
      }
    } catch (e) {
      debugPrint("Error submitting invoice: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
        showScaffoldError(context: context, message: "Error: ${e.toString()}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Get.put(SideBarController());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Create Invoice',
                style: buildCustomStyle(FontWeightManager.semiBold,
                    FontSize.s20, 0.30, ColorManager.textColor),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                iconSize: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Invoice Details Section
          CustomBoxShadowContainer(
            circleRadius: 12,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Type | Total Invoice Amount
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Type"),
                          const SizedBox(height: 4),
                          CustomDropDownWithSearch<String>(
                            hintText: "Select type",
                            title: "",
                            value: _selectedType,
                            items: const ["Other", "Sales", "Service"],
                            focusNode: _typeFocus,
                            onChanged: (value) {
                              setState(() => _selectedType = value);
                              FocusScope.of(context)
                                  .requestFocus(_dueDateFocus);
                            },
                            displayText: (item) => item,
                            showName: false,
                            height: 48,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Total Invoice Amount"),
                          const SizedBox(height: 4),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              _totalAmountController.text.isEmpty
                                  ? "0"
                                  : _totalAmountController.text,
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s14,
                                0.27,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 2: Due Date | Invoice Date | Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Due date"),
                          const SizedBox(height: 4),
                          CustomCalendarPickerTableCell(
                            initialDate:
                                DateTime.tryParse(_dueDateController.text) ??
                                    DateTime.now()
                                        .add(const Duration(days: 30)),
                            onDateSelected: (date) {
                              setState(() {
                                _dueDateController.text =
                                    date.toIso8601String().split('T')[0];
                              });
                              FocusScope.of(context)
                                  .requestFocus(_invoiceDateFocus);
                            },
                            hintText: "Select due date",
                            height: 48,
                            focusNode: _dueDateFocus,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Invoice date"),
                          const SizedBox(height: 4),
                          CustomCalendarPickerTableCell(
                            initialDate: DateTime.tryParse(
                                    _invoiceDateController.text) ??
                                DateTime.now(),
                            onDateSelected: (date) {
                              setState(() {
                                _invoiceDateController.text =
                                    date.toIso8601String().split('T')[0];
                              });
                              FocusScope.of(context).requestFocus(_statusFocus);
                            },
                            hintText: "Select invoice date",
                            height: 48,
                            focusNode: _invoiceDateFocus,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Status"),
                          const SizedBox(height: 4),
                          CustomDropDownWithSearch<String>(
                            hintText: "Select status",
                            title: "",
                            value: _selectedStatus,
                            items: const [
                              "Pending",
                              "Paid",
                              "Overdue",
                              "Cancelled"
                            ],
                            focusNode: _statusFocus,
                            onChanged: (value) {
                              setState(() => _selectedStatus = value);
                              FocusScope.of(context)
                                  .requestFocus(_customerFocus);
                            },
                            displayText: (item) => item,
                            showName: false,
                            height: 48,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 3: Customer (with balance display)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Customer", isRequired: true),
                    const SizedBox(height: 4),
                    CustomDropDownWithSearch<String>(
                      hintText: _isLoadingCustomers
                          ? "Loading customers..."
                          : "select a customer",
                      title: "",
                      value: _selectedCustomer,
                      items: _customerList.map((c) => c.id.toString()).toList(),
                      focusNode: _customerFocus,
                      onChanged: (value) {
                        setState(() => _selectedCustomer = value);
                        FocusScope.of(context)
                            .requestFocus(_newItemCard.itemNameFocus);
                      },
                      displayText: (item) {
                        final customer = _customerList.firstWhere(
                          (c) => c.id?.toString() == item,
                          orElse: () =>
                              CustomerListModelData(id: 0, name: "Unknown"),
                        );
                        return customer.name ?? "Unknown";
                      },
                      showName: false,
                      height: 48,
                    ),
                    const SizedBox(height: 4),
                    // Display customer balance
                    Text(
                      "Balance: ${_getCustomerBalance(_selectedCustomer).toStringAsFixed(2)}",
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s12,
                        0.20,
                        Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Invoice Items Section
          Text(
            'Invoice items',
            style: buildCustomStyle(FontWeightManager.semiBold, FontSize.s16,
                0.30, ColorManager.textColor),
          ),
          const SizedBox(height: 8),

          // Added Items List
          if (_invoiceItemCards.isNotEmpty)
            CustomBoxShadowContainer(
              circleRadius: 12,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Items list
                  ..._invoiceItemCards.asMap().entries.map((entry) {
                    int index = entry.key;
                    InvoiceItemCard card = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          _buildInputCell(
                            card.itemNameController,
                            card.itemNameFocus,
                            flex: 2,
                            hintText: "",
                          ),
                          _buildInputCell(
                            card.unitAmountController,
                            card.unitAmountFocus,
                            hintText: "0",
                            keyboardType: TextInputType.number,
                          ),
                          _buildInputCell(
                            card.taxController,
                            card.taxFocus,
                            hintText: "0",
                            keyboardType: TextInputType.number,
                          ),
                          _buildInputCell(
                            card.quantityController,
                            card.quantityFocus,
                            hintText: "1",
                            keyboardType: TextInputType.number,
                          ),
                          _buildInputCell(
                            card.totalController,
                            card.totalFocus,
                            hintText: "0",
                            readOnly: true,
                          ),
                          IconButton(
                            onPressed: () => _removeInvoiceItemCard(index),
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Inline Add Form
          CustomBoxShadowContainer(
            circleRadius: 12,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    _buildTableHeader("Item name", flex: 2),
                    _buildTableHeader("Unit amount"),
                    _buildTableHeader("Tax"),
                    _buildTableHeader("Quantity"),
                    _buildTableHeader("Total"),
                  ],
                ),
                const SizedBox(height: 8),

                // Input row
                Row(
                  children: [
                    _buildInputCell(
                      _newItemCard.itemNameController,
                      _newItemCard.itemNameFocus,
                      flex: 2,
                      hintText: "",
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context)
                            .requestFocus(_newItemCard.unitAmountFocus);
                      },
                    ),
                    _buildInputCell(
                      _newItemCard.unitAmountController,
                      _newItemCard.unitAmountFocus,
                      hintText: "0",
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context)
                            .requestFocus(_newItemCard.taxFocus);
                      },
                    ),
                    _buildInputCell(
                      _newItemCard.taxController,
                      _newItemCard.taxFocus,
                      hintText: "0",
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context)
                            .requestFocus(_newItemCard.quantityFocus);
                      },
                    ),
                    _buildInputCell(
                      _newItemCard.quantityController,
                      _newItemCard.quantityFocus,
                      hintText: "1",
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        _addNewInvoiceItemCard();
                      },
                    ),
                    _buildInputCell(
                      _newItemCard.totalController,
                      _newItemCard.totalFocus,
                      hintText: "0",
                      readOnly: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Center(
                  child: CustomRoundButtonAdvanced(
                    title: "Add to invoice items",
                    fct: _addNewInvoiceItemCard,
                    width: 180,
                    height: 40,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CustomRoundButtonAdvanced(
                title: "Cancel",
                fct: _isSubmitting ? () {} : () => Navigator.pop(context),
                width: 100,
                height: 45,
                fontSize: 14,
                boxColor: Colors.white,
                textColor: _isSubmitting ? Colors.grey : ColorManager.textColor,
                borderColor: Colors.grey.shade400,
              ),
              const SizedBox(width: 10),
              CustomRoundButtonAdvanced(
                title: "Submit",
                fct: _isSubmitting ? () {} : _submitInvoice,
                width: 100,
                height: 45,
                fontSize: 14,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
