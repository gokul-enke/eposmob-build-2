// Retain the existing color opacity values during this architecture-only move.
// ignore_for_file: deprecated_member_use

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
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:provider/provider.dart';

import '../../data/receipt_editor_repository.dart';
import '../../domain/receipt_form_item.dart';

part '../state/receipt_create_controller.dart';
part 'receipt_item_card.dart';

Future<dynamic> showCreateReceiptModal(BuildContext context, Size size) {
  final isMobile = size.width < 768;
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
          width: isMobile ? size.width * 0.98 : size.width * 0.7,
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

  const CreateReceiptModal({super.key, required this.size});

  @override
  State<CreateReceiptModal> createState() => _CreateReceiptModalState();
}

class _CreateReceiptModalState extends _ReceiptCreateController {
  // Show dialog to add or edit a receipt item
  void _showAddEditItemDialog({ReceiptItemCard? item, int? index}) {
    // Create a temporary card for editing
    final tempCard = ReceiptItemCard(
      defaultDescription: item?.descriptionController.text ??
          "Item ${_receiptItemCards.length + 1}",
    );

    _ownedCards.add(tempCard);

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
                      item != null
                          ? 'receipt.edit_item_title'.tr
                          : 'receipt.add_item_title'.tr,
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
                              _buildLabel('receipt.item_type_label'.tr,
                                  isRequired: true),
                              const SizedBox(height: 4),
                              CustomDropDownWithSearch<String>(
                                hintText: 'receipt.select_item_type_hint'.tr,
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
                                displayText: (item) => item == "General Payment"
                                    ? 'receipt.item_type_general'.tr
                                    : 'receipt.item_type_invoice'.tr,
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
                              'receipt.description_label'.tr,
                              tempCard.descriptionController,
                              TextInputType.text,
                              widget.size,
                              placeholder: 'receipt.description_label'.tr,
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
                                _buildLabel('receipt.invoice_label'.tr,
                                    isRequired: true),
                                const SizedBox(height: 4),
                                CustomDropDownWithSearch<String>(
                                  hintText: _isLoadingInvoices
                                      ? 'receipt.loading'.tr
                                      : 'receipt.select_invoice_hint'.tr,
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
                                      return 'receipt.unknown_invoice'.tr;
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
                              'receipt.invoice_amount_label'.tr,
                              tempCard.invoiceAmountController,
                              TextInputType.number,
                              widget.size,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTextField(
                              'receipt.balance_amount_label'.tr,
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
                              _buildLabel('receipt.payment_date_label'.tr,
                                  isRequired: true),
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
                                hintText: 'receipt.select_payment_date_hint'.tr,
                                height: 48,
                                focusNode: tempCard.paymentDateFocus,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(
                            'receipt.amount_label'.tr,
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
                              _saveItemEditor(tempCard, item, index);
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
                            'general.cancel'.tr,
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
                          title: 'general.save'.tr,
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
                            _saveItemEditor(tempCard, item, index);
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    final customerColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('receipt.customer_label'.tr, isRequired: true),
        const SizedBox(height: 4),
        CustomDropDownWithSearch<String>(
          hintText: _isLoadingCustomers
              ? 'receipt.loading_customers'.tr
              : 'receipt.select_customer_hint'.tr,
          title: "",
          value: _selectedCustomer,
          items:
              _customerList.map((customer) => customer.id.toString()).toList(),
          focusNode: _customerFocus,
          onChanged: (value) {
            // Check if there are existing items and customer is changing
            if (_receiptItemCards.isNotEmpty && value != _selectedCustomer) {
              // Show confirmation dialog
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text('receipt.change_customer_title'.tr),
                  content: Text(
                    'receipt.change_customer_message'.tr,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('general.cancel'.tr),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetItemsAndChangeCustomer(value);
                      },
                      child: Text('receipt.continue_button'.tr),
                    ),
                  ],
                ),
              );
            } else {
              setState(() {
                _selectedCustomer = value;
                // Also reset the new item card's invoice selection
                _newItemCard.selectedInvoice = null;
                _newItemCard.invoiceAmountController.text = "0.00";
              });
              // Move focus to payment reference
              FocusScope.of(context).requestFocus(_paymentReferenceFocus);
            }
          },
          displayText: (item) {
            if (_isLoadingCustomers) return 'receipt.loading'.tr;
            // Find the customer by ID
            final customer = _customerList.firstWhere(
              (c) => c.id?.toString() == item,
              orElse: () => CustomerListModelData(
                  id: 0, name: 'receipt.select_customer_fallback'.tr),
            );
            // Return the customer name or a default message
            return customer.name ?? 'receipt.unnamed_customer'.tr;
          },
          showName: false,
          height: 48,
        ),
        const SizedBox(height: 4),
        if (_selectedCustomer != null && _selectedCustomer!.isNotEmpty)
          Builder(
            builder: (context) {
              final customer = _customerList.firstWhere(
                (c) => c.id?.toString() == _selectedCustomer,
                orElse: () => CustomerListModelData(id: 0),
              );

              final balance = customer.balance;
              if (balance == null) {
                return const SizedBox.shrink();
              }

              final balanceValue = double.tryParse(balance.toString());

              if (balanceValue == null) {
                return const SizedBox.shrink();
              }

              final textColor = balanceValue >= 0
                  ? Colors.green.shade700
                  : Colors.red.shade700;

              return Text(
                'receipt.balance_prefix'
                    .tr
                    .replaceAll('@balance', balanceValue.toStringAsFixed(2)),
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
    );

    final itemTypeColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('receipt.item_type_label'.tr, isRequired: true),
        const SizedBox(height: 4),
        CustomDropDownWithSearch<String>(
          hintText: 'receipt.item_type_label'.tr,
          title: "",
          value: _newItemCard.selectedItemType,
          items: const ["Invoice Payment", "General Payment"],
          focusNode: _newItemCard.itemTypeFocus,
          onChanged: (value) {
            setState(() {
              _newItemCard.selectedItemType = value;
              // Reset fields when type changes
              if (value == "General Payment") {
                _newItemCard.selectedInvoice = null;
                _newItemCard.invoiceAmountController.text = "0.00";
              }
            });
            // Move focus based on selection
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (value == "Invoice Payment") {
                FocusScope.of(context).requestFocus(_newItemCard.invoiceFocus);
              } else {
                FocusScope.of(context)
                    .requestFocus(_newItemCard.descriptionFocus);
              }
            });
          },
          displayText: (item) => item == "General Payment"
              ? 'receipt.item_type_general'.tr
              : 'receipt.item_type_invoice'.tr,
          showName: false,
          height: 48,
        ),
      ],
    );

    final paymentDateColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('receipt.payment_date_label'.tr, isRequired: true),
        const SizedBox(height: 4),
        CustomCalendarPickerTableCell(
          initialDate:
              DateTime.tryParse(_newItemCard.paymentDateController.text) ??
                  DateTime.now(),
          onDateSelected: (date) {
            setState(() {
              _newItemCard.paymentDateController.text =
                  date.toIso8601String().split('T')[0];
            });
            // Move focus to amount
            FocusScope.of(context).requestFocus(_newItemCard.amountFocus);
          },
          hintText: 'receipt.select_payment_date_hint'.tr,
          height: 48,
          focusNode: _newItemCard.paymentDateFocus,
        ),
      ],
    );

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
                    'receipt.create_receipt_title'.tr,
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
                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            customerColumn,
                            const SizedBox(height: 12),
                            itemTypeColumn,
                            const SizedBox(height: 12),
                            paymentDateColumn,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: customerColumn),
                            const SizedBox(width: 8),
                            Expanded(child: itemTypeColumn),
                            const SizedBox(width: 8),
                            Expanded(child: paymentDateColumn),
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
                    'receipt.add_item_title'.tr,
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
                            'receipt.description_label'.tr,
                            _newItemCard.descriptionController,
                            TextInputType.text,
                            widget.size,
                            placeholder: 'receipt.description_label'.tr,
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
                              _buildLabel('receipt.invoice_label'.tr,
                                  isRequired: true),
                              const SizedBox(height: 4),
                              CustomDropDownWithSearch<String>(
                                hintText: _isLoadingInvoices
                                    ? 'receipt.loading_invoices'.tr
                                    : 'receipt.select_invoice_hint'.tr,
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
                                      .map((invoice) => invoice.id.toString())
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
                                        (inv) => inv.id.toString() == value,
                                      );

                                      // Set invoice amount
                                      _newItemCard.invoiceAmountController
                                          .text = selectedInvoice.amount;

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
                                    return 'receipt.unknown_invoice'.tr;
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
                            'receipt.invoice_amount_label'.tr,
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
                            'receipt.balance_amount_label'.tr,
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
                          'receipt.amount_label'.tr,
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
                  Text(
                    'receipt.receipt_items_list_title'.tr,
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s16, 0.30, ColorManager.textColor),
                  ),
                  const SizedBox(height: 12),
                  if (_receiptItemCards.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'receipt.no_items_placeholder'.tr,
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
                            _buildTableHeader('receipt.col_no'.tr),
                            _buildTableHeader('receipt.col_type'.tr),
                            _buildTableHeader('receipt.col_details'.tr),
                            _buildTableHeader('receipt.col_date'.tr),
                            _buildTableHeader('receipt.amount_label'.tr),
                            _buildTableHeader('receipt.col_actions'.tr,
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
                              _buildTableCell(card.selectedItemType ==
                                      "Invoice Payment"
                                  ? 'receipt.item_type_invoice'.tr
                                  : card.selectedItemType == "General Payment"
                                      ? 'receipt.item_type_general'.tr
                                      : "-"),
                              _buildTableCell(
                                card.selectedItemType == "Invoice Payment"
                                    ? 'receipt.invoice_prefix'.tr.replaceAll(
                                        '@number',
                                        _getInvoiceNumber(card.selectedInvoice))
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
                        }),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            CustomBoxShadowContainer(
              circleRadius: 7,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('receipt.payment_method_label'.tr,
                                isRequired: true),
                            const SizedBox(height: 4),
                            CustomDropDownWithSearch<String>(
                              hintText: _isLoadingPaymentMethods
                                  ? 'receipt.loading'.tr
                                  : 'receipt.payment_method_label'.tr,
                              title: "",
                              value: _selectedPaymentMethod,
                              items:
                                  _paymentMethods.map((m) => m.value).toList(),
                              focusNode: _paymentMethodFocus,
                              onChanged: (value) {
                                setState(() {
                                  _selectedPaymentMethod = value;
                                });
                                // Move focus to customer
                                FocusScope.of(context)
                                    .requestFocus(_customerFocus);
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          'receipt.payment_reference_label'.tr,
                          _paymentReferenceController,
                          TextInputType.text,
                          widget.size,
                          placeholder:
                              'receipt.payment_reference_placeholder'.tr,
                          focusNode: _paymentReferenceFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            // Move focus to first receipt item's type
                            if (_receiptItemCards.isNotEmpty) {
                              FocusScope.of(context).requestFocus(
                                  _receiptItemCards[0].itemTypeFocus);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (!isMobile) ...[
                        const Expanded(child: SizedBox()),
                        const Expanded(child: SizedBox(width: 16)),
                      ],
                      Expanded(
                        flex: isMobile ? 3 : 1,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  'receipt.items_summary_label'.tr,
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
                                  'receipt.total_amount_label'.tr,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _totalAmountController.text,
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
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomRoundButtonAdvanced(
                  title: 'general.cancel'.tr,
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
                  title: 'receipt.submit_button'.tr,
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
