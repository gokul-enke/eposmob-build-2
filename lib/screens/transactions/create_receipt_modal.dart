import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
          padding: const EdgeInsets.all(20),
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

  String? selectedItemType;
  String? selectedInvoice;

  ReceiptItemCard() {
    invoiceAmountController.text = "0.00";
    balanceAmountController.text = "0.00";
    paymentDateController.text = DateTime.now().toString().split(' ')[0];
    amountController.text = "0.00";
  }
}

class _CreateReceiptModalState extends State<CreateReceiptModal> {
  final TextEditingController _receiptNumberController =
      TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _paymentReferenceController =
      TextEditingController();

  String? _selectedPaymentMethod;
  String? _selectedCustomer;
  String? _selectedStatus;

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
    _receiptNumberController.text =
        "RCT-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}";
    _totalAmountController.text = "0.00";
    _selectedPaymentMethod = "Cash";
    _selectedStatus = "Paid";

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
      print('Error loading customers: $e');
      setState(() {
        _isLoadingCustomers = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading customers: $e')),
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
      print('Error loading invoices: $e');
      setState(() {
        _isLoadingInvoices = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading invoices: $e')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Not authenticated. Please log in again.')),
      );
      return;
    }

    // Validate required fields
    if (_selectedCustomer == null || _selectedCustomer!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    if (_selectedStatus == null || _selectedStatus!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a status')),
      );
      return;
    }

    // Create receipt items list from the form data
    List<Map<String, dynamic>> receiptItems = [];
    for (var card in _receiptItemCards) {
      // Validate item fields
      if (card.selectedItemType == null || card.selectedItemType!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select an item type for all items')),
        );
        return;
      }

      receiptItems.add({
        'item_type': card.selectedItemType?.toLowerCase() ?? 'general',
        'paid_amount': double.tryParse(card.amountController.text) ?? 0.0,
        'status': _selectedStatus?.toLowerCase() ?? 'paid',
        'payment_date': card.paymentDateController.text,
        'payment_method': _selectedPaymentMethod?.toUpperCase() ?? 'CASH',
        'description': 'General Payment', // Default description
      });
    }

    try {
      // Call the addReceipt method
      final result = await invoiceProvider.addReceipt(
        customerId: _selectedCustomer!,
        receiptStatus: _selectedStatus!.toLowerCase(),
        receiptItems: receiptItems,
        accessToken: accessToken,
      );

      // Handle success
      print('Receipt created successfully: $result');
      Navigator.pop(context); // Close the modal

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt created successfully')),
      );
    } catch (e) {
      // Handle error
      print('Error creating receipt: $e');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating receipt: $e')),
      );
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
            padding: const EdgeInsets.only(left: 10.0, bottom: 20.0),
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
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                // 1st row: Receipt Number | Payment Method | Total Receipt Amount
                Row(
                  children: [
                    Expanded(
                      child: CustomTextFieldColumn(
                        size: widget.size,
                        controller: _receiptNumberController,
                        hintText: "Receipt Number",
                        title: "Receipt Number",
                        isLeft: false,
                      ),
                    ),
                    const SizedBox(width: 10),
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
                        height: widget.size.height *
                            0.07, // Match text field height
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextFieldColumn(
                        size: widget.size,
                        controller: _totalAmountController,
                        hintText: "Total Receipt Amount",
                        title: "Total Receipt Amount",
                        isLeft: false,
                        textInputType: TextInputType.number,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // 2nd row: Customer | Status | Payment Reference
                Row(
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
                        height: widget.size.height *
                            0.07, // Match text field height
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomDropDownWithSearch<String>(
                        hintText: "Status",
                        title: "Status",
                        value: _selectedStatus,
                        items: const ["Paid", "Pending"],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                        },
                        displayText: (item) => item,
                        isRequired: true,
                        height: widget.size.height *
                            0.07, // Match text field height
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextFieldColumn(
                        size: widget.size,
                        controller: _paymentReferenceController,
                        hintText: "Payment Reference",
                        title: "Payment Reference",
                        isLeft: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

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
                  padding: const EdgeInsets.all(15),
                  margin: const EdgeInsets.only(bottom: 15),
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

                      const SizedBox(height: 15),

                      // 1st row: Item Type | Invoice | Invoice Amount
                      Row(
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
                              height: widget.size.height *
                                  0.07, // Match text field height
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomDropDownWithSearch<String>(
                              hintText: _isLoadingInvoices
                                  ? "Loading invoices..."
                                  : "Select an invoice",
                              title: "Invoice",
                              value: card.selectedInvoice,
                              items: _invoiceList
                                  .map(
                                      (invoice) => invoice.id?.toString() ?? "")
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
                              height: widget.size.height *
                                  0.07, // Match text field height
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomTextFieldColumn(
                              size: widget.size,
                              controller: card.invoiceAmountController,
                              hintText: "Invoice Amount",
                              title: "Invoice Amount",
                              isLeft: false,
                              textInputType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // 2nd row: Balance Amount | Payment Date | Amount
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextFieldColumn(
                              size: widget.size,
                              controller: card.balanceAmountController,
                              hintText: "Balance Amount",
                              title: "Balance Amount",
                              isLeft: false,
                              textInputType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomTextFieldColumn(
                              size: widget.size,
                              controller: card.paymentDateController,
                              hintText: "Payment Date",
                              title: "Payment Date",
                              isLeft: false,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomTextFieldColumn(
                              size: widget.size,
                              controller: card.amountController,
                              hintText: "Amount",
                              title: "Amount",
                              isLeft: false,
                              textInputType: TextInputType.number,
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
              width: 200,
              height: 40,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 20),

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
                height: 40,
                fontSize: 14,
                boxColor: Colors.white,
                textColor: ColorManager.kPrimaryColor,
                borderColor: ColorManager.kPrimaryColor,
              ),
              const SizedBox(width: 10),
              CustomRoundButtonAdvanced(
                title: "Submit",
                fct: _submitReceipt, // Updated to call the submit function
                width: 100,
                height: 40,
                fontSize: 14,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
