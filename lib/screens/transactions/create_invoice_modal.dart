import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/newcomponents/custom_text_fields.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/newcomponents/custom_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

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
          width:
              size.width * 0.7, // Increased modal width to match receipt modal
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
          child: CreateInvoiceModal(size: size),
        ),
      );
    },
  );
}

class CreateInvoiceModal extends StatefulWidget {
  final Size size;

  const CreateInvoiceModal({Key? key, required this.size}) : super(key: key);

  @override
  State<CreateInvoiceModal> createState() => _CreateInvoiceModalState();
}

class InvoiceItemCard {
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController unitAmountController = TextEditingController();
  final TextEditingController taxController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController totalController = TextEditingController();

  InvoiceItemCard() {
    unitAmountController.text = "0";
    taxController.text = "0";
    quantityController.text = "1";
    totalController.text = "0";
  }
}

class _CreateInvoiceModalState extends State<CreateInvoiceModal> {
  final TextEditingController _invoiceNumberController =
      TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _invoiceDateController = TextEditingController();

  String? _selectedType;
  String? _selectedStatus;
  String? _selectedCustomer;

  List<InvoiceItemCard> _invoiceItemCards = [InvoiceItemCard()];

  @override
  void initState() {
    super.initState();
    // Set default values
    _invoiceNumberController.text = "INV-529187";
    _totalAmountController.text = "0";
    _dueDateController.text = "2025-11-08";
    _invoiceDateController.text = "2025-11-08";
    _selectedType = "Other";
    _selectedStatus = "Pending";
  }

  void _addNewInvoiceItemCard() {
    setState(() {
      _invoiceItemCards.add(InvoiceItemCard());
    });
  }

  void _removeInvoiceItemCard(int index) {
    if (_invoiceItemCards.length > 1) {
      setState(() {
        _invoiceItemCards.removeAt(index);
      });
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
                  'Create Invoice',
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s20, 0.30, ColorManager.textColor),
                ),
              ],
            ),
          ),

          // First card for invoice details
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
                // 1st row: Invoice number | Type | Total Invoice Amount
                Row(
                  children: [
                    Expanded(
                      child: CustomTextFieldColumn(
                        size: widget.size,
                        controller: _invoiceNumberController,
                        hintText: "Invoice number",
                        title: "Invoice number",
                        isLeft: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomDropDownWithSearch<String>(
                        hintText: "Type",
                        title: "Type",
                        value: _selectedType,
                        items: const ["Other"],
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value;
                          });
                        },
                        displayText: (item) => item,
                        isRequired: false,
                        height: widget.size.height *
                            0.07, // Match text field height
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextFieldColumn(
                        size: widget.size,
                        controller: _totalAmountController,
                        hintText: "Total Invoice Amount",
                        title: "Total Invoice Amount",
                        isLeft: false,
                        textInputType: TextInputType.number,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // 2nd row: Due date | Invoice date | Status
                Row(
                  children: [
                    Expanded(
                      child: CustomTextFieldColumn(
                        size: widget.size,
                        controller: _dueDateController,
                        hintText: "Due date",
                        title: "Due date",
                        isLeft: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextFieldColumn(
                        size: widget.size,
                        controller: _invoiceDateController,
                        hintText: "Invoice date",
                        title: "Invoice date",
                        isLeft: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomDropDownWithSearch<String>(
                        hintText: "Status",
                        title: "Status",
                        value: _selectedStatus,
                        items: const ["Pending"],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                        },
                        displayText: (item) => item,
                        isRequired: false,
                        height: widget.size.height *
                            0.07, // Match text field height
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // 3rd row: Customer
                CustomDropDownWithSearch<String>(
                  hintText: "Select a customer",
                  title: "Customer*",
                  value: _selectedCustomer,
                  items: const [
                    "Customer 1",
                    "Customer 2",
                    "Customer 3"
                  ], // Replace with actual customer data
                  onChanged: (value) {
                    setState(() {
                      _selectedCustomer = value;
                    });
                  },
                  displayText: (item) => item,
                  isRequired: true,
                  height: widget.size.height * 0.07, // Match text field height
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Invoice items cards
          ..._invoiceItemCards.asMap().entries.map((entry) {
            int index = entry.key;
            InvoiceItemCard card = entry.value;

            return Column(
              children: [
                // Invoice items card
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
                            'Invoice items',
                            style: buildCustomStyle(FontWeightManager.semiBold,
                                FontSize.s16, 0.30, ColorManager.textColor),
                          ),
                          if (_invoiceItemCards.length > 1)
                            IconButton(
                              onPressed: () => _removeInvoiceItemCard(index),
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // Invoice items table header
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              "Item name*",
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s12, 0.20, ColorManager.textColor),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "Unit amount",
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s12, 0.20, ColorManager.textColor),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "Tax",
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s12, 0.20, ColorManager.textColor),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "Quantity",
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s12, 0.20, ColorManager.textColor),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "Total",
                              style: buildCustomStyle(FontWeightManager.medium,
                                  FontSize.s12, 0.20, ColorManager.textColor),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Invoice item input fields in one row
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: CustomTextFieldColumn(
                              size: widget.size,
                              controller: card.itemNameController,
                              hintText: "Item name",
                              title: "Item name",
                              isLeft: false,
                            ),
                          ),
                          Expanded(
                            child: CustomTextFieldColumn(
                              size: widget.size,
                              controller: card.unitAmountController,
                              hintText: "0",
                              title: "Unit amount",
                              isLeft: false,
                              textInputType: TextInputType.number,
                            ),
                          ),
                          Expanded(
                            child: CustomTextFieldColumn(
                              size: widget.size,
                              controller: card.taxController,
                              hintText: "0",
                              title: "Tax",
                              isLeft: false,
                              textInputType: TextInputType.number,
                            ),
                          ),
                          Expanded(
                            child: CustomTextFieldColumn(
                              size: widget.size,
                              controller: card.quantityController,
                              hintText: "1",
                              title: "Quantity",
                              isLeft: false,
                              textInputType: TextInputType.number,
                            ),
                          ),
                          Expanded(
                            child: CustomTextFieldColumn(
                              size: widget.size,
                              controller: card.totalController,
                              hintText: "0",
                              title: "Total",
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

          // "Add Item to Invoice" button
          Center(
            child: CustomRoundButtonAdvanced(
              title: "Add Item to Invoice",
              fct: _addNewInvoiceItemCard,
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
                fct: () {
                  // Handle submit logic
                  Navigator.pop(context);
                },
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
