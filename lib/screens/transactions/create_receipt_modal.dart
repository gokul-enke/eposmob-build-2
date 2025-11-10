import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/newcomponents/custom_text_fields.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/newcomponents/custom_round_button.dart';
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
    paymentDateController.text = DateTime.now().toString().split(' ')[0];
    amountController.text = "0.00";
    descriptionController.text = "General Payment";
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

    // Load customers and invoices
    _loadCustomers();
    _loadInvoices();
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
      _receiptItemCards.add(ReceiptItemCard());
    });
  }

  void _removeReceiptItemCard(int index) {
    if (_receiptItemCards.length > 1) {
      setState(() {
        _receiptItemCards.removeAt(index);
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

  @override
  Widget build(BuildContext context) {
    Get.put(SideBarController());

    return SingleChildScrollView(
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
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ColorManager.boxShadowColor,
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: ColorManager.boxShadowColor,
                  blurRadius: 6,
                  offset: Offset(1, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // 1st row: Payment Method | Total Receipt Amount
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CustomDropDownWithSearch<String>(
                        hintText: "Payment Method",
                        title: "Payment Method*",
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
                        isRequired: true,
                        height: widget.size.height * 0.048,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomMinimalTextField(
                        size: widget.size,
                        controller: _totalAmountController,
                        title: "Total Receipt Amount",
                        hintText: "Total Receipt Amount",
                        textInputType: TextInputType.number,
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
                      child: CustomDropDownWithSearch<String>(
                        hintText: _isLoadingCustomers
                            ? "Loading customers..."
                            : "Select a customer",
                        title: "Customer",
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
                        isRequired: true,
                        height: widget.size.height * 0.048,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomMinimalTextField(
                        size: widget.size,
                        controller: _paymentReferenceController,
                        title: "Payment Reference",
                        hintText: "Payment Reference",
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
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ColorManager.boxShadowColor,
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: ColorManager.boxShadowColor,
                        blurRadius: 6,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
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
                            style: buildCustomStyle(FontWeightManager.semiBold,
                                FontSize.s16, 0.30, ColorManager.textColor),
                          ),
                          if (_receiptItemCards.length > 1)
                            IconButton(
                              onPressed: () => _removeReceiptItemCard(index),
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 1st row: Item Type | Description (for general) OR Invoice | Invoice Amount (for invoice)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CustomDropDownWithSearch<String>(
                              hintText: "Item Type",
                              title: "Item Type",
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
                              isRequired: true,
                              height: widget.size.height * 0.048,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Show Description field for General Payment
                          if (card.selectedItemType == "General Payment")
                            Expanded(
                              child: CustomMinimalTextField(
                                size: widget.size,
                                controller: card.descriptionController,
                                title: "Description",
                                hintText: "Enter payment description",
                              ),
                            ),
                          // Show Invoice dropdown for Invoice Payment
                          if (card.selectedItemType == "Invoice Payment")
                            Expanded(
                              child: CustomDropDownWithSearch<String>(
                                hintText: _isLoadingInvoices
                                    ? "Loading invoices..."
                                    : "Select an invoice",
                                title: "Invoice",
                                value: card.selectedInvoice,
                                items: _invoiceList
                                    .map((invoice) =>
                                        invoice.id?.toString() ?? "")
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    card.selectedInvoice = value;

                                    // Auto-fill invoice amount when invoice is selected
                                    if (value != null && value.isNotEmpty) {
                                      final selectedInvoice =
                                          _invoiceList.firstWhere(
                                        (inv) => inv.id?.toString() == value,
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
                                              createdAt: DateTime.now(),
                                              updatedAt: DateTime.now(),
                                            ),
                                          ),
                                        ),
                                      );
                                      card.invoiceAmountController.text =
                                          selectedInvoice.amount ?? "0.00";
                                    }
                                  });
                                },
                                displayText: (item) {
                                  if (_isLoadingInvoices) return "Loading...";
                                  // Find the invoice by ID
                                  final invoice = _invoiceList.firstWhere(
                                    (inv) => inv.id?.toString() == item,
                                    orElse: () => Invoice(
                                      id: 0,
                                      customerId: 0,
                                      invoiceNumber: "Select invoice",
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
                                          createdAt: DateTime.now(),
                                          updatedAt: DateTime.now(),
                                        ),
                                      ),
                                    ),
                                  );
                                  return "${invoice.invoiceNumber ?? 'Unknown'} (${invoice.amount ?? '0.00'})";
                                },
                                isRequired: true,
                                height: widget.size.height * 0.048,
                              ),
                            ),
                          // Show Invoice Amount only for Invoice Payment (with proper spacing)
                          if (card.selectedItemType == "Invoice Payment") ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: CustomMinimalTextField(
                                size: widget.size,
                                controller: card.invoiceAmountController,
                                title: "Invoice Amount",
                                hintText: "Invoice Amount",
                                textInputType: TextInputType.number,
                                readOnly: true,
                              ),
                            ),
                          ],
                          // Show Payment Date for General Payment (in first row)
                          if (card.selectedItemType == "General Payment") ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: CustomMinimalTextField(
                                size: widget.size,
                                controller: card.paymentDateController,
                                title: "Payment Date",
                                hintText: "Payment Date",
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
                              child: CustomMinimalTextField(
                                size: widget.size,
                                controller: card.balanceAmountController,
                                title: "Balance Amount",
                                hintText: "Balance Amount",
                                textInputType: TextInputType.number,
                                readOnly: true,
                              ),
                            ),
                          if (card.selectedItemType == "Invoice Payment")
                            const SizedBox(width: 8),
                          // For Invoice Payment: show Payment Date
                          if (card.selectedItemType == "Invoice Payment")
                            Expanded(
                              child: CustomMinimalTextField(
                                size: widget.size,
                                controller: card.paymentDateController,
                                title: "Payment Date",
                                hintText: "Payment Date",
                              ),
                            ),
                          if (card.selectedItemType == "Invoice Payment")
                            const SizedBox(width: 8),
                          // Amount field for both types
                          Expanded(
                            child: CustomMinimalTextField(
                              size: widget.size,
                              controller: card.amountController,
                              title: "Amount",
                              hintText: "Amount",
                              textInputType: TextInputType.number,
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
    );
  }
}