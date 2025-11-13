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

  String? selectedItemType;
  String? selectedInvoice;

  ReceiptItemCard() {
    invoiceAmountController.text = "0.00";
    balanceAmountController.text = "0.00";
    // Set default date as today in yyyy-MM-dd format
    paymentDateController.text = DateTime.now().toIso8601String().split('T')[0];
    amountController.text = "";
    descriptionController.text = "";
    selectedItemType = "Invoice Payment";
  }
}

class _CreateReceiptModalState extends State<CreateReceiptModal> {
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _paymentReferenceController =
      TextEditingController();

  String? _selectedPaymentMethod;
  String? _selectedCustomer;

  List<ReceiptItemCard> _receiptItemCards = [ReceiptItemCard()];

  // Customer list for dropdown
  List<CustomerListModelData> _customerList = [];
  bool _isLoadingCustomers = false;

  // Invoice list for dropdown
  List<Invoice> _invoiceList = [];
  bool _isLoadingInvoices = false;

  @override
  void initState() {
    super.initState();
    // Set default values
    _totalAmountController.text = "0.00";
    _selectedPaymentMethod = "Cash";

    // Add listener to first receipt item's amount controller
    _receiptItemCards[0].amountController.addListener(_calculateTotalAmount);

    // Load customers and invoices
    _loadCustomers();
    _loadInvoices();
  }

  @override
  void dispose() {
    // Remove listeners before disposing
    for (var card in _receiptItemCards) {
      card.amountController.removeListener(_calculateTotalAmount);
    }
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
          debugPrint('📋 [Receipt Modal] Total invoices loaded: ${_invoiceList.length}');
          debugPrint('═══════════════════════════════════════════════════════════════');
          if (_invoiceList.isNotEmpty) {
            debugPrint('📋 [Receipt Modal] Detailed Invoice List:');
            for (var i = 0; i < (_invoiceList.length > 10 ? 10 : _invoiceList.length); i++) {
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
          debugPrint('═══════════════════════════════════════════════════════════════');
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
    setState(() {
      final newCard = ReceiptItemCard();
      // Add listener to new card's amount controller
      newCard.amountController.addListener(_calculateTotalAmount);
      _receiptItemCards.add(newCard);
    });
  }

  void _removeReceiptItemCard(int index) {
    if (_receiptItemCards.length > 1) {
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
        final paid = double.tryParse(card.amountController.text.trim().isEmpty ? '0' : card.amountController.text.trim()) ?? 0.0;
        final balance = double.tryParse(card.balanceAmountController.text.trim().isEmpty ? '0' : card.balanceAmountController.text.trim()) ?? 0.0;
        if (paid > balance) {
          if (mounted) {
            showScaffoldError(
              context: context,
              message: 'Paid amount (\u20B9${paid.toStringAsFixed(2)}) cannot exceed balance (\u20B9${balance.toStringAsFixed(2)}).',
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
        'payment_method': _selectedPaymentMethod?.toUpperCase() ?? 'CASH',
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

  Widget _buildTextField(String title, TextEditingController controller,
      TextInputType keyboardType, Size size,
      {FormFieldValidator<String>? validator,
      TextInputFormatter? inputFormatter,
      bool isRequired = false,
      bool readOnly = false,
      String? placeholder}) {
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
          height: size.height * .048,
          width: size.width,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatter != null ? [inputFormatter] : null,
            readOnly: readOnly,
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
                            _buildLabel("Payment Method", isRequired: true),
                            const SizedBox(height: 4),
                            CustomDropDownWithSearch<String>(
                              hintText: "Payment Method",
                              title: "",
                              value: _selectedPaymentMethod,
                              items: const [
                                "Cash",
                                "Credit",
                                "UPI",
                                "Bank Transfer",
                                "Cheque"
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedPaymentMethod = value;
                                });
                              },
                              displayText: (item) => item,
                              showName: false,
                              height: widget.size.height * 0.048,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextField(
                          "Total Receipt Amount",
                          _totalAmountController,
                          TextInputType.number,
                          widget.size,
                          readOnly: true,
                          placeholder: "Auto-calculated from items",
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 2nd row: Customer | Status | Payment Reference
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
                              onChanged: (value) {
                                setState(() {
                                  _selectedCustomer = value;
                                });
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
                              height: widget.size.height * 0.048,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextField(
                          "Payment Reference",
                          _paymentReferenceController,
                          TextInputType.text,
                          widget.size,
                          placeholder: "Enter payment reference (optional)",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Receipt items cards
            ..._receiptItemCards.asMap().entries.map((entry) {
              int index = entry.key;
              ReceiptItemCard card = entry.value;

              return Column(
                children: [
                  // Second card for receipt items
                  CustomBoxShadowContainer(
                    circleRadius: 7,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Receipt items',
                              style: buildCustomStyle(
                                  FontWeightManager.semiBold,
                                  FontSize.s16,
                                  0.30,
                                  ColorManager.textColor),
                            ),
                            if (_receiptItemCards.length > 1)
                              IconButton(
                                onPressed: () => _removeReceiptItemCard(index),
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // 1st row: Item Type | Description (for general) OR Invoice | Invoice Amount (for invoice)
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
                                    hintText: "Item Type",
                                    title: "",
                                    value: card.selectedItemType,
                                    items: const [
                                      "Invoice Payment",
                                      "General Payment"
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        card.selectedItemType = value;
                                      });
                                    },
                                    displayText: (item) => item,
                                    showName: false,
                                    height: widget.size.height * 0.048,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Show Description field for General Payment
                            if (card.selectedItemType == "General Payment")
                              Expanded(
                                child: _buildTextField(
                                  "Description",
                                  card.descriptionController,
                                  TextInputType.text,
                                  widget.size,
                                ),
                              ),
                            // Show Invoice dropdown for Invoice Payment
                            if (card.selectedItemType == "Invoice Payment")
                              Expanded(
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
                                      value: card.selectedInvoice,
                                      items: () {
                                        // Filter invoices by selected customer
                                        final filteredInvoices = _selectedCustomer != null
                                            ? _invoiceList.where((invoice) => 
                                                invoice.customerId.toString() == _selectedCustomer
                                              ).toList()
                                            : _invoiceList;
                                        
                                        debugPrint('\n🔍 [Receipt Modal] ═══ INVOICE FILTERING ═══');
                                        debugPrint('🔍 Selected Customer ID: $_selectedCustomer');
                                        debugPrint('🔍 Total invoices in list: ${_invoiceList.length}');
                                        debugPrint('🔍 Filtered invoices for this customer: ${filteredInvoices.length}');
                                        
                                        if (filteredInvoices.isNotEmpty) {
                                          debugPrint('🔍 Filtered Invoice Details:');
                                          for (var i = 0; i < (filteredInvoices.length > 5 ? 5 : filteredInvoices.length); i++) {
                                            final inv = filteredInvoices[i];
                                            debugPrint('  ${i+1}. Invoice #${inv.id}: ${inv.invoiceNumber} | Amount: ${inv.amount} | Status: ${inv.status}');
                                          }
                                          if (filteredInvoices.length > 5) {
                                            debugPrint('  ... and ${filteredInvoices.length - 5} more');
                                          }
                                        } else {
                                          debugPrint('⚠️ No invoices found for customer ID: $_selectedCustomer');
                                          debugPrint('💡 Checking all invoice customer IDs:');
                                          for (var inv in _invoiceList.take(5)) {
                                            debugPrint('  - Invoice ${inv.invoiceNumber}: customerId = ${inv.customerId} (type: ${inv.customerId.runtimeType})');
                                          }
                                        }
                                        debugPrint('═══════════════════════════════════════════════════');
                                        
                                        return filteredInvoices
                                            .map((invoice) => invoice.id?.toString() ?? "")
                                            .toList();
                                      }(),
                                      onChanged: (value) {
                                        setState(() {
                                          card.selectedInvoice = value;
                                          
                                          debugPrint('\n✅ [Receipt Modal] Invoice Selected: $value');

                                          // Auto-fill invoice amount and balance when invoice is selected
                                          if (value != null &&
                                              value.isNotEmpty) {
                                            final selectedInvoice =
                                                _invoiceList.firstWhere(
                                              (inv) =>
                                                  inv.id?.toString() == value,
                                              orElse: () => Invoice(
                                                id: 0,
                                                customerId: 0,
                                                invoiceNumber: "",
                                                type: "",
                                                companyId: 0,
                                                amount: "0.00",
                                                invoiceDate: "",
                                                dueDate: "",
                                                status: "",
                                                createdBy: 0,
                                                createdAt: DateTime.now(),
                                                updatedAt: DateTime.now(),
                                                customer: Customer(
                                                  id: 0,
                                                  createdAt: DateTime.now(),
                                                  updatedAt: DateTime.now(),
                                                  user: User(
                                                    id: 0,
                                                    name: "",
                                                    email: "",
                                                    phone: "",
                                                    phoneVerified: 0,
                                                    isAdmin: false,
                                                    createdAt: DateTime.now(),
                                                    updatedAt: DateTime.now(),
                                                  ),
                                                ),
                                              ),
                                            );
                                            
                                            // Set invoice amount
                                            card.invoiceAmountController.text =
                                                selectedInvoice.amount ??
                                                    "0.00";
                                            
                                            // Set invoice balance (use invoice's balance_amount, not customer's global balance)
                                            final invoiceBalance = selectedInvoice.balanceAmount;
                                            if (invoiceBalance is num) {
                                              card.balanceAmountController.text = invoiceBalance.toStringAsFixed(2);
                                            } else if (invoiceBalance != null) {
                                              card.balanceAmountController.text = invoiceBalance.toString();
                                            } else {
                                              card.balanceAmountController.text = "0.00";
                                            }

                                            debugPrint('💰 [Receipt Modal] Invoice Balance: ${card.balanceAmountController.text}');
                                            debugPrint('📄 [Receipt Modal] Invoice Amount: ${selectedInvoice.amount}');
                                          }
                                        });
                                      },
                                      displayText: (item) {
                                        if (_isLoadingInvoices)
                                          return "Loading...";
                                        
                                        // Filter by selected customer first
                                        final filteredInvoices = _selectedCustomer != null
                                            ? _invoiceList.where((invoice) => 
                                                invoice.customerId.toString() == _selectedCustomer
                                              ).toList()
                                            : _invoiceList;
                                        
                                        // Find the invoice by ID
                                        final invoice = filteredInvoices.firstWhere(
                                          (inv) => inv.id?.toString() == item,
                                          orElse: () => Invoice(
                                            id: 0,
                                            customerId: 0,
                                            invoiceNumber: "Select invoice",
                                            type: "",
                                            companyId: 0,
                                            amount: "",
                                            invoiceDate: "",
                                            dueDate: "",
                                            status: "",
                                            createdBy: 0,
                                            createdAt: DateTime.now(),
                                            updatedAt: DateTime.now(),
                                            customer: Customer(
                                              id: 0,
                                              createdAt: DateTime.now(),
                                              updatedAt: DateTime.now(),
                                              user: User(
                                                id: 0,
                                                name: "",
                                                email: "",
                                                phone: "",
                                                phoneVerified: 0,
                                                isAdmin: false,
                                                createdAt: DateTime.now(),
                                                updatedAt: DateTime.now(),
                                              ),
                                            ),
                                          ),
                                        );
                                        return "${invoice.invoiceNumber ?? 'Unknown'} (${invoice.amount ?? '0.00'})";
                                      },
                                      showName: false,
                                      height: widget.size.height * 0.048,
                                    ),
                                  ],
                                ),
                              ),
                            // Show Invoice Amount only for Invoice Payment (with proper spacing)
                            if (card.selectedItemType == "Invoice Payment") ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTextField(
                                  "Invoice Amount",
                                  card.invoiceAmountController,
                                  TextInputType.number,
                                  widget.size,
                                  readOnly: true,
                                ),
                              ),
                            ],
                            // Show Payment Date for General Payment (in first row)
                            if (card.selectedItemType == "General Payment") ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Payment Date",
                                        isRequired: true),
                                    const SizedBox(height: 4),
                                    CustomBoxShadowContainer(
                                      circleRadius: 7,
                                      alignment: Alignment.centerLeft,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 0, vertical: 0),
                                      padding: const EdgeInsets.only(left: 0),
                                      height: widget.size.height * .048,
                                      width: widget.size.width,
                                      child: CustomCalendarPickerTableCell(
                                        initialDate: DateTime.tryParse(card
                                                .paymentDateController.text) ??
                                            DateTime.now(),
                                        onDateSelected: (date) {
                                          setState(() {
                                            card.paymentDateController.text =
                                                date
                                                    .toIso8601String()
                                                    .split('T')[0];
                                          });
                                        },
                                        hintText: "Select payment date",
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 20),

                        // 2nd row: Amount (for general) OR Balance Amount | Payment Date | Amount (for invoice)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // For Invoice Payment: show Balance Amount
                            if (card.selectedItemType == "Invoice Payment")
                              Expanded(
                                child: _buildTextField(
                                  "Balance Amount",
                                  card.balanceAmountController,
                                  TextInputType.number,
                                  widget.size,
                                  readOnly: true,
                                ),
                              ),
                            if (card.selectedItemType == "Invoice Payment")
                              const SizedBox(width: 8),
                            // For Invoice Payment: show Payment Date
                            if (card.selectedItemType == "Invoice Payment")
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Payment Date",
                                        isRequired: true),
                                    const SizedBox(height: 4),
                                    CustomBoxShadowContainer(
                                      circleRadius: 7,
                                      alignment: Alignment.centerLeft,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 0, vertical: 0),
                                      padding: const EdgeInsets.only(left: 0),
                                      height: widget.size.height * .048,
                                      width: widget.size.width,
                                      child: CustomCalendarPickerTableCell(
                                        initialDate: DateTime.tryParse(card
                                                .paymentDateController.text) ??
                                            DateTime.now(),
                                        onDateSelected: (date) {
                                          setState(() {
                                            card.paymentDateController.text =
                                                date
                                                    .toIso8601String()
                                                    .split('T')[0];
                                          });
                                        },
                                        hintText: "Select payment date",
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (card.selectedItemType == "Invoice Payment")
                              const SizedBox(width: 8),
                            // Amount field for both types
                            Expanded(
                              child: _buildTextField(
                                "Amount",
                                card.amountController,
                                TextInputType.number,
                                widget.size,
                                isRequired: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),

            // "Add to receipt items" button
            Center(
              child: CustomRoundButtonAdvanced(
                title: "Add to receipt items",
                fct: _addNewReceiptItemCard,
                width: 180,
                height: 45,
                fontSize: 14,
              ),
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
