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
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:provider/provider.dart';

Future<dynamic> showCreateReceiptModal(BuildContext context, Size size) {
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
          width: size.width * 0.7, // Increased modal width from 60% to 70%
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
          padding: const EdgeInsets.all(16),
          child: CreateReceiptModal(size: size),
        ),
      );
    },
  );
}

class CreateReceiptModal extends StatefulWidget {
  final Size size;

  const CreateReceiptModal({Key? key, required this.size}) : super(key: key);

  @override
  State<CreateReceiptModal> createState() => _CreateReceiptModalState();
}

class ReceiptItemCard {
  final TextEditingController itemTypeController = TextEditingController();
  final TextEditingController invoiceController = TextEditingController();
  final TextEditingController invoiceAmountController = TextEditingController();
  final TextEditingController balanceAmountController = TextEditingController();
  final TextEditingController paymentDateController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final FocusNode itemTypeFocus = FocusNode();
  final FocusNode invoiceFocus = FocusNode();
  final FocusNode descriptionFocus = FocusNode();
  final FocusNode paymentDateFocus = FocusNode();
  final FocusNode amountFocus = FocusNode();

  String? selectedItemType;
  String? selectedInvoice;

  ReceiptItemCard({String defaultDescription = ""}) {
    invoiceAmountController.text = "0.00";
    balanceAmountController.text = "0.00";
    // Set default date as today in yyyy-MM-dd format
    paymentDateController.text = DateTime.now().toIso8601String().split('T')[0];
    amountController.text = "";
    descriptionController.text = defaultDescription;
    selectedItemType = "General Payment";

    // Select all text when description field gets focus
    descriptionFocus.addListener(() {
      if (descriptionFocus.hasFocus) {
        descriptionController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: descriptionController.text.length,
        );
      }
    });
  }

  void dispose() {
    itemTypeController.dispose();
    invoiceController.dispose();
    invoiceAmountController.dispose();
    balanceAmountController.dispose();
    paymentDateController.dispose();
    amountController.dispose();
    descriptionController.dispose();

    itemTypeFocus.dispose();
    invoiceFocus.dispose();
    descriptionFocus.dispose();
    paymentDateFocus.dispose();
    amountFocus.dispose();
  }
}

class _CreateReceiptModalState extends State<CreateReceiptModal> {
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _paymentReferenceController =
      TextEditingController();

  final FocusNode _paymentMethodFocus = FocusNode();
  final FocusNode _customerFocus = FocusNode();
  final FocusNode _paymentReferenceFocus = FocusNode();

  String? _selectedPaymentMethod;
  String? _selectedCustomer;

  List<ReceiptItemCard> _receiptItemCards = [];
  late ReceiptItemCard _newItemCard;

  // Customer list for dropdown
  List<CustomerListModelData> _customerList = [];
  bool _isLoadingCustomers = false;

  // Invoice list for dropdown
  List<Invoice> _invoiceList = [];
  bool _isLoadingInvoices = false;

  // Payment methods from API
  List<MasterDataValue> _paymentMethods = [];
  bool _isLoadingPaymentMethods = false;

  @override
  void initState() {
    super.initState();
    // Set default values
    _totalAmountController.text = "0.00";
    // Payment method will be set dynamically in _loadPaymentMethods

    // Initialize new item card
    _newItemCard = ReceiptItemCard(defaultDescription: "");

    // Add listener to new item card's amount controller
    _newItemCard.amountController.addListener(_calculateTotalAmount);

    // Load customers, invoices, and payment methods
    _loadCustomers();
    _loadInvoices();
    _loadPaymentMethods();

    // Focus on Payment Method field on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_paymentMethodFocus);
    });
  }

  @override
  void dispose() {
    // Remove listeners before disposing
    for (var card in _receiptItemCards) {
      card.amountController.removeListener(_calculateTotalAmount);
      card.amountController.removeListener(_calculateTotalAmount);
      card.dispose();
    }
    _newItemCard.amountController.removeListener(_calculateTotalAmount);
    _newItemCard.dispose();
    _paymentMethodFocus.dispose();
    _customerFocus.dispose();
    _paymentReferenceFocus.dispose();
    super.dispose();
  }

  // Calculate total amount from all receipt items
  void _calculateTotalAmount() {
    double total = 0.0;
    for (var card in _receiptItemCards) {
      final amount = double.tryParse(card.amountController.text) ?? 0.0;
      total += amount;
    }
    _totalAmountController.text = total.toStringAsFixed(2);
  }

  // Load customers from API
  void _loadCustomers() async {
    setState(() {
      _isLoadingCustomers = true;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);

      if (authModel.token != null && authModel.token!.isNotEmpty) {
        await customerProvider.fetchCustomers(
          accessToken: authModel.token!,
          listAll: true,
        );

        setState(() {
          _customerList = customerProvider.allCustomers ?? [];
          _isLoadingCustomers = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('Error loading customers: $e');
      setState(() {
        _isLoadingCustomers = false;
      });

      showScaffoldError(
        context: context,
        message: 'Error loading customers: $e',
      );
    }
  }

  // Load payment methods from API
  void _loadPaymentMethods() async {
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
          // Set default payment method if available
          if (_paymentMethods.isNotEmpty && _selectedPaymentMethod == null) {
            // Try to set CASH or COD as default, otherwise use first available
            final cashMethod =
                _paymentMethods.where((m) => m.value == 'CASH').firstOrNull;
            final codMethod =
                _paymentMethods.where((m) => m.value == 'COD').firstOrNull;
            if (cashMethod != null) {
              _selectedPaymentMethod = 'CASH';
            } else if (codMethod != null) {
              _selectedPaymentMethod = 'COD';
            } else {
              _selectedPaymentMethod = _paymentMethods.first.value;
            }
          }
        });
        debugPrint(
            '📋 [Receipt Modal] Payment methods loaded: $_paymentMethods');
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error loading payment methods: $e');
      setState(() {
        _isLoadingPaymentMethods = false;
      });
    }
  }

  // Load invoices from API
  void _loadInvoices() async {
    setState(() {
      _isLoadingInvoices = true;
    });

    try {
      final authModel = Provider.of<AuthModel>(context, listen: false);
      final invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);

      if (authModel.token != null && authModel.token!.isNotEmpty) {
        await invoiceProvider.listAllInvoices(
          accessToken: authModel.token!,
        );

        setState(() {
          _invoiceList = invoiceProvider.allInvoices ?? [];
          _isLoadingInvoices = false;

          // Debug print invoice list
          debugPrint(
              '📋 [Receipt Modal] Total invoices loaded: ${_invoiceList.length}');
          debugPrint(
              '═══════════════════════════════════════════════════════════════');
          if (_invoiceList.isNotEmpty) {
            debugPrint('📋 [Receipt Modal] Detailed Invoice List:');
            for (var i = 0;
                i < (_invoiceList.length > 10 ? 10 : _invoiceList.length);
                i++) {
              final inv = _invoiceList[i];
              debugPrint('\n🧾 Invoice #$i:');
              debugPrint('  ├─ ID: ${inv.id}');
              debugPrint('  ├─ Invoice Number: ${inv.invoiceNumber}');
              debugPrint('  ├─ Type: ${inv.type}');
              debugPrint('  ├─ Amount: ${inv.amount}');
              debugPrint('  ├─ Status: ${inv.status}');
              debugPrint('  ├─ Invoice Date: ${inv.invoiceDate}');
              debugPrint('  ├─ Due Date: ${inv.dueDate}');
              debugPrint('  ├─ Customer ID: ${inv.customerId}');
              debugPrint('  ├─ Customer Name: ${inv.customer.user.name}');
              debugPrint('  ├─ Customer Email: ${inv.customer.user.email}');
              debugPrint('  ├─ Customer Phone: ${inv.customer.user.phone}');
              debugPrint('  ├─ Company ID: ${inv.companyId}');
              debugPrint('  ├─ Created By: ${inv.createdBy}');
              debugPrint('  ├─ Created At: ${inv.createdAt}');
              debugPrint('  ├─ Updated At: ${inv.updatedAt}');
              debugPrint('  ├─ User ID: ${inv.userId}');
              debugPrint('  └─ ZATCA Status: ${inv.zatcaStatus ?? "null"}');
            }
            if (_invoiceList.length > 10) {
              debugPrint('\n... and ${_invoiceList.length - 10} more invoices');
            }
          } else {
            debugPrint('⚠️ [Receipt Modal] No invoices found!');
          }
          debugPrint(
              '═══════════════════════════════════════════════════════════════');
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('Error loading invoices: $e');
      setState(() {
        _isLoadingInvoices = false;
      });

      showScaffoldError(
        context: context,
        message: 'Error loading invoices: $e',
      );
    }
  }

  void _addNewReceiptItemCard() {
    // Validate inputs
    if (_newItemCard.amountController.text.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'Please enter an amount',
      );
      return;
    }

    if (_newItemCard.selectedItemType == "Invoice Payment" &&
        (_newItemCard.selectedInvoice == null ||
            _newItemCard.selectedInvoice!.isEmpty)) {
      showScaffoldError(
        context: context,
        message: 'Please select an invoice',
      );
      return;
    }

    // Validation: For invoice payments, paid amount cannot exceed balance amount
    if (_newItemCard.selectedItemType == "Invoice Payment") {
      final paid = double.tryParse(
              _newItemCard.amountController.text.trim().isEmpty
                  ? '0'
                  : _newItemCard.amountController.text.trim()) ??
          0.0;
      final balance = double.tryParse(
              _newItemCard.balanceAmountController.text.trim().isEmpty
                  ? '0'
                  : _newItemCard.balanceAmountController.text.trim()) ??
          0.0;
      if (paid > balance) {
        showScaffoldError(
          context: context,
          message:
              'Paid amount (${paid.toStringAsFixed(2)}) cannot exceed balance (${balance.toStringAsFixed(2)}).',
        );
        return;
      }
    }

    setState(() {
      // Add a copy of the new item card to the list
      final addedCard = ReceiptItemCard(
        defaultDescription: _newItemCard.descriptionController.text,
      );
      addedCard.selectedItemType = _newItemCard.selectedItemType;
      addedCard.selectedInvoice = _newItemCard.selectedInvoice;
      addedCard.itemTypeController.text = _newItemCard.itemTypeController.text;
      addedCard.invoiceController.text = _newItemCard.invoiceController.text;
      addedCard.invoiceAmountController.text =
          _newItemCard.invoiceAmountController.text;
      addedCard.balanceAmountController.text =
          _newItemCard.balanceAmountController.text;
      addedCard.paymentDateController.text =
          _newItemCard.paymentDateController.text;
      addedCard.amountController.text = _newItemCard.amountController.text;
      addedCard.descriptionController.text =
          _newItemCard.descriptionController.text;

      // Add listener to the new card's amount controller
      addedCard.amountController.addListener(_calculateTotalAmount);

      _receiptItemCards.add(addedCard);

      // Reset the new item card
      _newItemCard.amountController.clear();
      _newItemCard.descriptionController.text =
          "Item ${_receiptItemCards.length + 1}";
      _newItemCard.selectedItemType = "General Payment";
      _newItemCard.selectedInvoice = null;
      _newItemCard.invoiceAmountController.text = "0.00";
      _newItemCard.balanceAmountController.text = "0.00";
      _newItemCard.paymentDateController.text =
          DateTime.now().toIso8601String().split('T')[0];

      // Recalculate total
      _calculateTotalAmount();

      // Refocus on Item Type field
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_newItemCard.itemTypeFocus);
      });
    });
  }

  void _removeReceiptItemCard(int index) {
    setState(() {
      // Remove listener before removing card
      _receiptItemCards[index]
          .amountController
          .removeListener(_calculateTotalAmount);
      _receiptItemCards.removeAt(index);
      // Recalculate total after removing
      _calculateTotalAmount();
    });
  }

  // Reset all items and change customer
  void _resetItemsAndChangeCustomer(String? newCustomer) {
    setState(() {
      // Remove listeners and dispose all existing cards
      for (var card in _receiptItemCards) {
        card.amountController.removeListener(_calculateTotalAmount);
        card.dispose();
      }
      _receiptItemCards.clear();

      // Reset the new item card
      _newItemCard.selectedInvoice = null;
      _newItemCard.invoiceAmountController.text = "0.00";
      _newItemCard.balanceAmountController.text = "0.00";
      _newItemCard.amountController.clear();
      _newItemCard.descriptionController.text = "Item 1";
      _newItemCard.selectedItemType = "General Payment";

      // Update customer
      _selectedCustomer = newCustomer;

      // Recalculate total (will be 0)
      _calculateTotalAmount();
    });

    // Move focus to payment reference
    FocusScope.of(context).requestFocus(_paymentReferenceFocus);
  }

  // Submit the receipt data
  void _submitReceipt() async {
    // Get the InvoiceProvider and AuthModel instances
    final invoiceProvider =
        Provider.of<InvoiceProvider>(context, listen: false);
    final authModel = Provider.of<AuthModel>(context, listen: false);
    final accessToken = authModel.token;

    // Check if we have an access token
    if (accessToken == null || accessToken.isEmpty) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Not authenticated. Please log in again.',
        );
      }
      return;
    }

    // Validate required fields
    if (_selectedCustomer == null || _selectedCustomer!.isEmpty) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Please select a customer',
        );
      }
      return;
    }

    // Create receipt items list from the form data
    List<Map<String, dynamic>> receiptItems = [];
    for (var card in _receiptItemCards) {
      // Validate item fields
      if (card.selectedItemType == null || card.selectedItemType!.isEmpty) {
        if (mounted) {
          showScaffoldError(
            context: context,
            message: 'Please select an item type for all items',
          );
        }
        return;
      }

      final itemType = card.selectedItemType?.toLowerCase() ?? 'general';

      // Map dropdown values to backend expected values
      String apiItemType;
      if (itemType.contains('invoice')) {
        apiItemType = 'invoice';
      } else {
        apiItemType = 'general';
      }

      // Validation: For invoice payments, paid amount cannot exceed balance amount
      if (apiItemType == 'invoice') {
        final paid = double.tryParse(card.amountController.text.trim().isEmpty
                ? '0'
                : card.amountController.text.trim()) ??
            0.0;
        final balance = double.tryParse(
                card.balanceAmountController.text.trim().isEmpty
                    ? '0'
                    : card.balanceAmountController.text.trim()) ??
            0.0;
        if (paid > balance) {
          if (mounted) {
            showScaffoldError(
              context: context,
              message:
                  'Paid amount (\u20B9${paid.toStringAsFixed(2)}) cannot exceed balance (\u20B9${balance.toStringAsFixed(2)}).',
            );
          }
          return;
        }
      }

      final Map<String, dynamic> receiptItem = {
        'item_type': apiItemType,
        'paid_amount': double.tryParse(card.amountController.text) ?? 0.0,
        'status': 'paid',
        'payment_date': card.paymentDateController.text,
        'payment_method': _getPaymentMethodId(_selectedPaymentMethod),
        'description': card.descriptionController.text.isNotEmpty
            ? card.descriptionController.text
            : 'General Payment',
      };

      // Add invoice_id if item type is invoice payment
      if (apiItemType == 'invoice' &&
          card.selectedInvoice != null &&
          card.selectedInvoice!.isNotEmpty) {
        receiptItem['invoice_id'] = card.selectedInvoice;
      }

      receiptItems.add(receiptItem);
    }

    try {
      debugPrint(
          '🧾 Submitting receipt for customer $_selectedCustomer with ${receiptItems.length} item(s) and status paid');
      debugPrint(
          '📦 Receipt payload preview: ${receiptItems.map((item) => '{type: ${item['item_type']}, paid_amount: ${item['paid_amount']}, payment_date: ${item['payment_date']}}').toList()}');
      if (_paymentReferenceController.text.isNotEmpty) {
        debugPrint('💳 Payment Reference: ${_paymentReferenceController.text}');
      }

      // Call the addReceipt method
      final result = await invoiceProvider.addReceipt(
        customerId: _selectedCustomer!,
        receiptStatus: 'paid',
        receiptItems: receiptItems,
        accessToken: accessToken,
        paymentReference: _paymentReferenceController.text.isNotEmpty
            ? _paymentReferenceController.text
            : null,
      );

      // Handle success
      debugPrint('✅ Receipt created successfully: $result');
      if (mounted) {
        showScaffold(
          context: context,
          message: 'Receipt created successfully',
        );
        Navigator.pop(context, true); // Close the modal and return success
      }
    } catch (e) {
      // Handle error
      debugPrint('❌ Error creating receipt: $e');
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Error creating receipt: $e',
        );
      }
    }
  }

  // Show dialog to add or edit a receipt item
  void _showAddEditItemDialog({ReceiptItemCard? item, int? index}) {
    // Create a temporary card for editing
    final tempCard = ReceiptItemCard(
      defaultDescription: item?.descriptionController.text ??
          "Item ${_receiptItemCards.length + 1}",
    );

    // If editing, populate fields
    if (item != null) {
      tempCard.selectedItemType = item.selectedItemType;
      tempCard.selectedInvoice = item.selectedInvoice;
      tempCard.itemTypeController.text = item.itemTypeController.text;
      tempCard.invoiceController.text = item.invoiceController.text;
      tempCard.invoiceAmountController.text = item.invoiceAmountController.text;
      tempCard.balanceAmountController.text = item.balanceAmountController.text;
      tempCard.paymentDateController.text = item.paymentDateController.text;
      tempCard.amountController.text = item.amountController.text;
      tempCard.descriptionController.text = item.descriptionController.text;
    } else {
      // If new, set default type
      tempCard.selectedItemType = "General Payment";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: widget.size.width * 0.6,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item != null ? 'Edit Item' : 'Add Item',
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s18,
                        0.30,
                        ColorManager.textColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Item Type", isRequired: true),
                              const SizedBox(height: 4),
                              CustomDropDownWithSearch<String>(
                                hintText: "Select Item Type",
                                title: "",
                                value: tempCard.selectedItemType,
                                items: const [
                                  "General Payment",
                                  "Invoice Payment"
                                ],
                                focusNode: tempCard.itemTypeFocus,
                                onChanged: (value) {
                                  setState(() {
                                    tempCard.selectedItemType = value;
                                    if (value == "Invoice Payment") {
                                      FocusScope.of(context)
                                          .requestFocus(tempCard.invoiceFocus);
                                    } else {
                                      FocusScope.of(context).requestFocus(
                                          tempCard.descriptionFocus);
                                    }
                                  });
                                },
                                displayText: (item) => item,
                                showName: false,
                                height: 48,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Show Description field for General Payment
                        if (tempCard.selectedItemType == "General Payment")
                          Expanded(
                            child: _buildTextField(
                              "Description",
                              tempCard.descriptionController,
                              TextInputType.text,
                              widget.size,
                              placeholder: "Description",
                              focusNode: tempCard.descriptionFocus,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context)
                                    .requestFocus(tempCard.paymentDateFocus);
                              },
                            ),
                          )
                        else
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Invoice", isRequired: true),
                                const SizedBox(height: 4),
                                CustomDropDownWithSearch<String>(
                                  hintText: _isLoadingInvoices
                                      ? "Loading..."
                                      : "Select an invoice",
                                  title: "",
                                  value: tempCard.selectedInvoice,
                                  items: _invoiceList
                                      .where((inv) =>
                                          _selectedCustomer != null &&
                                          inv.customerId.toString() ==
                                              _selectedCustomer)
                                      .map((inv) => inv.id.toString())
                                      .toList(),
                                  focusNode: tempCard.invoiceFocus,
                                  onChanged: (value) {
                                    setState(() {
                                      tempCard.selectedInvoice = value;
                                      final invoice = _invoiceList.firstWhere(
                                        (inv) => inv.id.toString() == value,
                                      );
                                      tempCard.invoiceAmountController.text =
                                          invoice.amount;

                                      // Set invoice balance
                                      final invoiceBalance =
                                          invoice.balanceAmount;
                                      if (invoiceBalance is num) {
                                        tempCard.balanceAmountController.text =
                                            invoiceBalance.toStringAsFixed(2);
                                      } else if (invoiceBalance != null) {
                                        tempCard.balanceAmountController.text =
                                            invoiceBalance.toString();
                                      } else {
                                        tempCard.balanceAmountController.text =
                                            "0.00";
                                      }

                                      // Move focus to payment date
                                      FocusScope.of(context).requestFocus(
                                          tempCard.paymentDateFocus);
                                    });
                                  },
                                  displayText: (item) {
                                    try {
                                      final invoice = _invoiceList.firstWhere(
                                        (inv) => inv.id.toString() == item,
                                      );
                                      return "${invoice.invoiceNumber} (${invoice.amount})";
                                    } catch (e) {
                                      return "Unknown Invoice";
                                    }
                                  },
                                  showName: false,
                                  height: 48,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (tempCard.selectedItemType == "Invoice Payment") ...[
                          Expanded(
                            child: _buildTextField(
                              "Invoice Amount",
                              tempCard.invoiceAmountController,
                              TextInputType.number,
                              widget.size,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTextField(
                              "Balance Amount",
                              tempCard.balanceAmountController,
                              TextInputType.number,
                              widget.size,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Payment Date", isRequired: true),
                              const SizedBox(height: 4),
                              CustomCalendarPickerTableCell(
                                initialDate: DateTime.tryParse(
                                        tempCard.paymentDateController.text) ??
                                    DateTime.now(),
                                onDateSelected: (date) {
                                  setState(() {
                                    tempCard.paymentDateController.text =
                                        date.toIso8601String().split('T')[0];
                                  });
                                  // Move focus to amount
                                  FocusScope.of(context)
                                      .requestFocus(tempCard.amountFocus);
                                },
                                hintText: "Select payment date",
                                height: 48,
                                focusNode: tempCard.paymentDateFocus,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(
                            "Amount",
                            tempCard.amountController,
                            TextInputType.number,
                            widget.size,
                            isRequired: true,
                            focusNode: tempCard.amountFocus,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              // Trigger save
                              // Validation
                              if (tempCard.selectedItemType == null) {
                                // Show error
                                return;
                              }
                              if (tempCard.amountController.text.isEmpty) {
                                // Show error
                                return;
                              }

                              // Update main state
                              this.setState(() {
                                if (item != null && index != null) {
                                  // Update existing
                                  final existing = _receiptItemCards[index];
                                  existing.selectedItemType =
                                      tempCard.selectedItemType;
                                  existing.selectedInvoice =
                                      tempCard.selectedInvoice;
                                  existing.descriptionController.text =
                                      tempCard.descriptionController.text;
                                  existing.paymentDateController.text =
                                      tempCard.paymentDateController.text;
                                  existing.amountController.text =
                                      tempCard.amountController.text;
                                  existing.invoiceAmountController.text =
                                      tempCard.invoiceAmountController.text;
                                } else {
                                  // Add new
                                  _receiptItemCards.add(tempCard);
                                  tempCard.amountController
                                      .addListener(_calculateTotalAmount);
                                }
                                _calculateTotalAmount();
                              });
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            "Cancel",
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s14,
                              0.27,
                              Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        CustomRoundButtonAdvanced(
                          title: "Save",
                          fct: () {
                            // Validation
                            if (tempCard.selectedItemType == null) {
                              // Show error
                              return;
                            }
                            if (tempCard.amountController.text.isEmpty) {
                              // Show error
                              return;
                            }

                            // Update main state
                            this.setState(() {
                              if (item != null && index != null) {
                                // Update existing
                                final existing = _receiptItemCards[index];
                                existing.selectedItemType =
                                    tempCard.selectedItemType;
                                existing.selectedInvoice =
                                    tempCard.selectedInvoice;
                                existing.descriptionController.text =
                                    tempCard.descriptionController.text;
                                existing.paymentDateController.text =
                                    tempCard.paymentDateController.text;
                                existing.amountController.text =
                                    tempCard.amountController.text;
                                existing.invoiceAmountController.text =
                                    tempCard.invoiceAmountController.text;
                              } else {
                                // Add new
                                _receiptItemCards.add(tempCard);
                                tempCard.amountController
                                    .addListener(_calculateTotalAmount);
                              }
                              _calculateTotalAmount();
                            });
                            Navigator.pop(context);
                          },
                          height: 40,
                          width: 100,
                          fontSize: FontSize.s14,
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

  Widget _buildTableHeader(String title, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        title,
        textAlign: align,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s12,
          0.27,
          ColorManager.textColor,
        ),
      ),
    );
  }

  Widget _buildTableCell(String content, {TextAlign align = TextAlign.left}) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          content,
          textAlign: align,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            ColorManager.textColor,
          ),
        ),
      ),
    );
  }

  String _getInvoiceNumber(String? invoiceId) {
    if (invoiceId == null) return "-";
    try {
      final invoice = _invoiceList.firstWhere(
        (inv) => inv.id.toString() == invoiceId,
      );
      return invoice.invoiceNumber;
    } catch (e) {
      return "-";
    }
  }

  Widget _buildTextField(String title, TextEditingController controller,
      TextInputType keyboardType, Size size,
      {FormFieldValidator<String>? validator,
      TextInputFormatter? inputFormatter,
      bool isRequired = false,
      bool readOnly = false,
      String? placeholder,
      FocusNode? focusNode,
      ValueChanged<String>? onFieldSubmitted,
      TextInputAction? textInputAction}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use simple Text widget to match dropdown label styling
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
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        CustomBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          padding: const EdgeInsets.only(left: 12),
          height: 48,
          width: size.width,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatter != null ? [inputFormatter] : null,
            readOnly: readOnly,
            focusNode: focusNode,
            onFieldSubmitted: onFieldSubmitted,
            textInputAction: textInputAction,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              hintText: placeholder,
              hintStyle: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s11,
                0.27,
                ColorManager.textColor.withOpacity(.3),
              ),
            ),
            validator: validator,
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s11,
                0.27, ColorManager.textColor.withOpacity(.5)),
          ),
        ),
      ],
    );
  }

  // Helper method to get payment method ID for API
  // Finds the ID for the given payment method value
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

  // Helper method to render label for dropdowns
  Widget _buildLabel(String title, {bool isRequired = false}) {
    return Text.rich(
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
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    Get.put(SideBarController());

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 0, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Receipt',
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                ],
              ),
            ),

            // First card for receipt details
            CustomBoxShadowContainer(
              circleRadius: 7,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // 1st row: Payment Method | Total Receipt Amount
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Customer", isRequired: true),
                            const SizedBox(height: 4),
                            CustomDropDownWithSearch<String>(
                              hintText: _isLoadingCustomers
                                  ? "Loading customers..."
                                  : "Select a customer",
                              title: "",
                              value: _selectedCustomer,
                              items: _customerList
                                  .map((customer) => customer.id.toString())
                                  .toList(),
                              focusNode: _customerFocus,
                              onChanged: (value) {
                                // Check if there are existing items and customer is changing
                                if (_receiptItemCards.isNotEmpty &&
                                    value != _selectedCustomer) {
                                  // Show confirmation dialog
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: Colors.white,
                                      title: const Text('Change Customer?'),
                                      content: const Text(
                                        'Changing the customer will clear all added items. Do you want to continue?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _resetItemsAndChangeCustomer(value);
                                          },
                                          child: const Text('Continue'),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  setState(() {
                                    _selectedCustomer = value;
                                    // Also reset the new item card's invoice selection
                                    _newItemCard.selectedInvoice = null;
                                    _newItemCard.invoiceAmountController.text =
                                        "0.00";
                                  });
                                  // Move focus to payment reference
                                  FocusScope.of(context)
                                      .requestFocus(_paymentReferenceFocus);
                                }
                              },
                              displayText: (item) {
                                if (_isLoadingCustomers) return "Loading...";
                                // Find the customer by ID
                                final customer = _customerList.firstWhere(
                                  (c) => c.id?.toString() == item,
                                  orElse: () => CustomerListModelData(
                                      id: 0, name: "Select customer"),
                                );
                                // Return the customer name or a default message
                                return customer.name ?? "Unnamed customer";
                              },
                              showName: false,
                              height: 48,
                            ),
                            const SizedBox(height: 4),
                            if (_selectedCustomer != null &&
                                _selectedCustomer!.isNotEmpty)
                              Builder(
                                builder: (context) {
                                  final customer = _customerList.firstWhere(
                                    (c) =>
                                        c.id?.toString() == _selectedCustomer,
                                    orElse: () => CustomerListModelData(id: 0),
                                  );

                                  final balance = customer.balance;
                                  if (balance == null) {
                                    return const SizedBox.shrink();
                                  }

                                  final balanceValue =
                                      double.tryParse(balance.toString());

                                  if (balanceValue == null) {
                                    return const SizedBox.shrink();
                                  }

                                  final textColor = balanceValue >= 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700;

                                  return Text(
                                    'Balance: ${balanceValue.toStringAsFixed(2)}',
                                    style: buildCustomStyle(
                                      FontWeightManager.medium,
                                      FontSize.s11,
                                      0.27,
                                      textColor,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Item Type", isRequired: true),
                            const SizedBox(height: 4),
                            CustomDropDownWithSearch<String>(
                              hintText: "Item Type",
                              title: "",
                              value: _newItemCard.selectedItemType,
                              items: const [
                                "Invoice Payment",
                                "General Payment"
                              ],
                              focusNode: _newItemCard.itemTypeFocus,
                              onChanged: (value) {
                                setState(() {
                                  _newItemCard.selectedItemType = value;
                                  // Reset fields when type changes
                                  if (value == "General Payment") {
                                    _newItemCard.selectedInvoice = null;
                                    _newItemCard.invoiceAmountController.text =
                                        "0.00";
                                  }
                                });
                                // Move focus based on selection
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (value == "Invoice Payment") {
                                    FocusScope.of(context).requestFocus(
                                        _newItemCard.invoiceFocus);
                                  } else {
                                    FocusScope.of(context).requestFocus(
                                        _newItemCard.descriptionFocus);
                                  }
                                });
                              },
                              displayText: (item) => item,
                              showName: false,
                              height: 48,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Payment Date", isRequired: true),
                            const SizedBox(height: 4),
                            CustomCalendarPickerTableCell(
                              initialDate: DateTime.tryParse(_newItemCard
                                      .paymentDateController.text) ??
                                  DateTime.now(),
                              onDateSelected: (date) {
                                setState(() {
                                  _newItemCard.paymentDateController.text =
                                      date.toIso8601String().split('T')[0];
                                });
                                // Move focus to amount
                                FocusScope.of(context)
                                    .requestFocus(_newItemCard.amountFocus);
                              },
                              hintText: "Select payment date",
                              height: 48,
                              focusNode: _newItemCard.paymentDateFocus,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Expanded(
                      //   child: Column(
                      //     crossAxisAlignment: CrossAxisAlignment.start,
                      //     children: [
                      //       _buildLabel("Payment Method", isRequired: true),
                      //       const SizedBox(height: 4),
                      //       CustomDropDownWithSearch<String>(
                      //         hintText: _isLoadingPaymentMethods
                      //             ? "Loading..."
                      //             : "Payment Method",
                      //         title: "",
                      //         value: _selectedPaymentMethod,
                      //         items:
                      //             _paymentMethods.map((m) => m.value).toList(),
                      //         focusNode: _paymentMethodFocus,
                      //         onChanged: (value) {
                      //           setState(() {
                      //             _selectedPaymentMethod = value;
                      //           });
                      //           // Move focus to customer
                      //           FocusScope.of(context)
                      //               .requestFocus(_customerFocus);
                      //         },
                      //         displayText: (item) {
                      //           try {
                      //             return _paymentMethods
                      //                 .firstWhere((m) => m.value == item)
                      //                 .description;
                      //           } catch (e) {
                      //             return item;
                      //           }
                      //         },
                      //         showName: false,
                      //         height: 48,
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      // const SizedBox(width: 8),
                      // Expanded(
                      //   child: _buildTextField(
                      //     "Total Receipt Amount",
                      //     _totalAmountController,
                      //     TextInputType.number,
                      //     widget.size,
                      //     readOnly: true,
                      //     placeholder: "Auto-calculated from items",
                      //   ),
                      // ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Receipt items table
            // Inline Add Item Form
            CustomBoxShadowContainer(
              circleRadius: 7,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Item',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s16,
                      0.30,
                      ColorManager.textColor,
                    ),
                  ),

                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_newItemCard.selectedItemType == "General Payment")
                        Expanded(
                          flex: 4,
                          child: _buildTextField(
                            "Description",
                            _newItemCard.descriptionController,
                            TextInputType.text,
                            widget.size,
                            placeholder: "Description",
                            focusNode: _newItemCard.descriptionFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) {
                              FocusScope.of(context)
                                  .requestFocus(_newItemCard.paymentDateFocus);
                            },
                          ),
                        )
                      // Show Invoice dropdown for Invoice Payment
                      else
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Invoice", isRequired: true),
                              const SizedBox(height: 4),
                              CustomDropDownWithSearch<String>(
                                hintText: _isLoadingInvoices
                                    ? "Loading invoices..."
                                    : "Select an invoice",
                                title: "",
                                value: _newItemCard.selectedInvoice,
                                items: () {
                                  // Filter invoices by selected customer
                                  final filteredInvoices = _selectedCustomer !=
                                          null
                                      ? _invoiceList
                                          .where((invoice) =>
                                              invoice.customerId.toString() ==
                                              _selectedCustomer)
                                          .toList()
                                      : _invoiceList;
                                  return filteredInvoices
                                      .map((invoice) =>
                                          invoice.id?.toString() ?? "")
                                      .toList();
                                }(),
                                focusNode: _newItemCard.invoiceFocus,
                                onChanged: (value) {
                                  setState(() {
                                    _newItemCard.selectedInvoice = value;

                                    // Move focus to payment date
                                    FocusScope.of(context).requestFocus(
                                        _newItemCard.paymentDateFocus);

                                    // Auto-fill invoice amount and balance when invoice is selected
                                    if (value != null && value.isNotEmpty) {
                                      final selectedInvoice =
                                          _invoiceList.firstWhere(
                                        (inv) => inv.id?.toString() == value,
                                      );

                                      // Set invoice amount
                                      _newItemCard
                                              .invoiceAmountController.text =
                                          selectedInvoice.amount ?? "0.00";

                                      // Set invoice balance
                                      final invoiceBalance =
                                          selectedInvoice.balanceAmount;
                                      if (invoiceBalance is num) {
                                        _newItemCard
                                                .balanceAmountController.text =
                                            invoiceBalance.toStringAsFixed(2);
                                      } else if (invoiceBalance != null) {
                                        _newItemCard.balanceAmountController
                                            .text = invoiceBalance.toString();
                                      } else {
                                        _newItemCard.balanceAmountController
                                            .text = "0.00";
                                      }
                                    }
                                  });
                                },
                                displayText: (item) {
                                  try {
                                    final invoice = _invoiceList.firstWhere(
                                      (inv) => inv.id.toString() == item,
                                    );
                                    return "${invoice.invoiceNumber} (${invoice.amount})";
                                  } catch (e) {
                                    return "Unknown Invoice";
                                  }
                                },
                                showName: false,
                                height: 48,
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      // Show Invoice Amount and Balance Amount only for Invoice Payment
                      if (_newItemCard.selectedItemType ==
                          "Invoice Payment") ...[
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            "Invoice Amount",
                            _newItemCard.invoiceAmountController,
                            TextInputType.number,
                            widget.size,
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            "Balance Amount",
                            _newItemCard.balanceAmountController,
                            TextInputType.number,
                            widget.size,
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          "Amount",
                          _newItemCard.amountController,
                          TextInputType.number,
                          widget.size,
                          isRequired: true,
                          focusNode: _newItemCard.amountFocus,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            _addNewReceiptItemCard();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          _addNewReceiptItemCard();
                        },
                        child: Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: ColorManager.kPrimaryColor,
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: const [
                              BoxShadow(
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
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Center(
                  //   child: CustomRoundButtonAdvanced(
                  //     title: "Add to List",
                  //     fct: _addNewReceiptItemCard,
                  //     width: 150,
                  //     height: 40,
                  //     fontSize: 14,
                  //   ),
                  // ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Receipt items table
            CustomBoxShadowContainer(
              circleRadius: 7,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Receipt Items List',
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s16, 0.30, ColorManager.textColor),
                  ),
                  const SizedBox(height: 12),
                  if (_receiptItemCards.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          "No items added yet. Click '+ Add Item' to start.",
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s14,
                            0.27,
                            Colors.grey,
                          ),
                        ),
                      ),
                    )
                  else
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(0.5), // #
                        1: FlexColumnWidth(1.5), // Type
                        2: FlexColumnWidth(2.5), // Details
                        3: FlexColumnWidth(1.5), // Date
                        4: FlexColumnWidth(1.5), // Amount
                        5: FlexColumnWidth(1.0), // Actions
                      },
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      children: [
                        // Header Row
                        TableRow(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          children: [
                            _buildTableHeader("#"),
                            _buildTableHeader("Type"),
                            _buildTableHeader("Details"),
                            _buildTableHeader("Date"),
                            _buildTableHeader("Amount"),
                            _buildTableHeader("Actions",
                                align: TextAlign.center),
                          ],
                        ),
                        // Data Rows
                        ..._receiptItemCards.asMap().entries.map((entry) {
                          int index = entry.key;
                          ReceiptItemCard card = entry.value;
                          return TableRow(
                            children: [
                              _buildTableCell((index + 1).toString()),
                              _buildTableCell(card.selectedItemType ?? "-"),
                              _buildTableCell(
                                card.selectedItemType == "Invoice Payment"
                                    ? "Inv: ${_getInvoiceNumber(card.selectedInvoice)}"
                                    : card.descriptionController.text,
                              ),
                              _buildTableCell(card.paymentDateController.text),
                              _buildTableCell(card.amountController.text),
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      InkWell(
                                        onTap: () => _showAddEditItemDialog(
                                            item: card, index: index),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(Icons.edit,
                                              size: 18, color: Colors.blue),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () =>
                                            _removeReceiptItemCard(index),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(Icons.delete,
                                              size: 18, color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Payment Method", isRequired: true),
                      const SizedBox(height: 4),
                      CustomDropDownWithSearch<String>(
                        hintText: _isLoadingPaymentMethods
                            ? "Loading..."
                            : "Payment Method",
                        title: "",
                        value: _selectedPaymentMethod,
                        items: _paymentMethods.map((m) => m.value).toList(),
                        focusNode: _paymentMethodFocus,
                        onChanged: (value) {
                          setState(() {
                            _selectedPaymentMethod = value;
                          });
                          // Move focus to customer
                          FocusScope.of(context).requestFocus(_customerFocus);
                        },
                        displayText: (item) {
                          try {
                            return _paymentMethods
                                .firstWhere((m) => m.value == item)
                                .description;
                          } catch (e) {
                            return item;
                          }
                        },
                        showName: false,
                        height: 48,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    "Payment Reference",
                    _paymentReferenceController,
                    TextInputType.text,
                    widget.size,
                    placeholder: "Enter payment reference (optional)",
                    focusNode: _paymentReferenceFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      // Move focus to first receipt item's type
                      if (_receiptItemCards.isNotEmpty) {
                        FocusScope.of(context)
                            .requestFocus(_receiptItemCards[0].itemTypeFocus);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: SizedBox()),
                Expanded(child: SizedBox(width: 16)),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Items',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "${_receiptItemCards.length}",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "${_totalAmountController.text}",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomRoundButtonAdvanced(
                  title: "Cancel",
                  fct: () {
                    Navigator.pop(context);
                  },
                  width: 100,
                  height: 45,
                  fontSize: 14,
                  boxColor: Colors.white,
                  textColor: ColorManager.kPrimaryColor,
                  borderColor: ColorManager.kPrimaryColor,
                ),
                const SizedBox(width: 8),
                CustomRoundButtonAdvanced(
                  title: "Submit",
                  fct: _submitReceipt, // Updated to call the submit function
                  width: 100,
                  height: 45,
                  fontSize: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
