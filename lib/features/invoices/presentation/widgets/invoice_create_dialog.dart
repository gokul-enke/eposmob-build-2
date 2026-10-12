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
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/features/billing/presentation/widgets/coupon_modal.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_action_guard.dart';

import '../../data/invoice_editor_repository.dart';
import '../../domain/invoice_form_item.dart';

part '../state/invoice_create_controller.dart';
part 'invoice_item_card.dart';

Future<dynamic> showCreateInvoiceModal(BuildContext context, Size size) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: size.width < 700 ? 16 : 40,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        child: Container(
          width: size.width < 700 ? size.width * 0.95 : size.width * 0.7,
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

class _CreateInvoiceModalState extends _InvoiceCreateController {
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
        padding: const EdgeInsets.symmetric(horizontal: 4),
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

  /// Builds a standard summary row with dimmed labels and medium values.
  Widget _buildSummaryRow(
    String label,
    double value, {
    bool isDiscount = false,
  }) {
    return Row(
      children: [
        Expanded(
            child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDiscount ? Colors.green[400] : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        )),
        const SizedBox(width: 12),
        Expanded(
            child: Text(
          value.toStringAsFixed(2),
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 14,
            color: isDiscount ? Colors.green[400] : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        )),
      ],
    );
  }

  /// Builds the highlighted final total row.
  Widget _buildNetTotalRow(String label, double value) {
    return Row(
      children: [
        Expanded(
            child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        )),
        const SizedBox(width: 12),
        Expanded(
            child: Text(
          value.toStringAsFixed(2),
          textAlign: TextAlign.end,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent, // Or use your brand color
          ),
        )),
      ],
    );
  }

  Widget _buildPaymentControls(double width) {
    final fieldWidth = width >= 900
        ? (width - 180 - 24) / 2
        : width >= 600
            ? (width - 12) / 2
            : width;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        SizedBox(
            width: fieldWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLabel('invoice.status_label'.tr),
                const SizedBox(height: 4),
                CustomDropDownWithSearch<String>(
                  key: const ValueKey('invoice-create-status'),
                  contentPadding: EdgeInsets.zero,
                  hintText: 'invoice.select_status_hint'.tr,
                  title: "",
                  value: _selectedStatus,
                  items: const ["Paid", "Pending"],
                  focusNode: _statusFocus,
                  onChanged: (value) {
                    setState(() => _selectedStatus = value);
                    FocusScope.of(
                      context,
                    ).requestFocus(_paymentMethodFocus);
                  },
                  displayText: (item) => item == 'Paid'
                      ? 'invoice.status_paid'.tr
                      : 'invoice.status_pending'.tr,
                  showName: false,
                  height: 48,
                ),
              ],
            )),
        SizedBox(
            width: fieldWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLabel('invoice.payment_method_label'.tr),
                const SizedBox(height: 4),
                CustomDropDownWithSearch<String>(
                  key: const ValueKey('invoice-create-payment-method'),
                  contentPadding: EdgeInsets.zero,
                  hintText: _isLoadingPaymentMethods
                      ? 'invoice.loading'.tr
                      : 'invoice.payment_method_label'.tr,
                  title: "",
                  value: _selectedPaymentMethod,
                  items: _paymentMethods.map((m) => m.value).toList(),
                  focusNode: _paymentMethodFocus,
                  onChanged: (value) =>
                      setState(() => _selectedPaymentMethod = value),
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
            )),
        InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => CouponModal(
                subTotal: _netTotal + _totalTax,
                initialFlatDiscount: _discount,
                initialPercentageDiscount: _discountPercentage,
                initialCouponCode: _couponCode,
                isCouponApplied: _isCouponApplied,
                onCouponAction: (
                  couponCode,
                  shouldApply, {
                  double? flatDiscount,
                  double? percentageDiscount,
                }) async {
                  if (shouldApply) {
                    setState(() {
                      _couponCode = couponCode;
                      _isCouponApplied = true;
                      if (percentageDiscount != null &&
                          percentageDiscount > 0) {
                        _discountPercentage = percentageDiscount;
                        _discount = 0;
                      } else {
                        _discountPercentage = 0;
                        _discount = flatDiscount ?? 0;
                      }
                    });
                    _calculateInvoiceTotal();
                  } else {
                    setState(() {
                      _couponCode = "";
                      _isCouponApplied = false;
                      _discount = 0;
                      _discountPercentage = 0;
                    });
                    _calculateInvoiceTotal();
                  }
                },
              ),
            );
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.discount_outlined,
                  size: 18,
                  color: Colors.blue,
                ),
                const SizedBox(width: 10),
                Text(
                  'invoice.discount'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s14,
                    0.14,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceSummary() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummaryRow('invoice.total_amount'.tr, _netTotal),
          const SizedBox(height: 5),
          _buildSummaryRow('invoice.all_tax_amount'.tr, _totalTax),
          const SizedBox(height: 5),
          _buildSummaryRow(
            'invoice.discount'.tr,
            _discount,
            isDiscount: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Divider(thickness: 1, height: 1),
          ),
          _buildNetTotalRow(
            'invoice.total_payable'.tr,
            _totalPayable,
          ),
        ],
      );

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
        child: ListenableBuilder(
          listenable: focusNode,
          builder: (context, _) {
            final hasFocus = focusNode.hasFocus;
            return Container(
              height: 40,
              decoration: BoxDecoration(
                color: readOnly ? Colors.grey.shade100 : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: hasFocus
                      ? ColorManager.kPrimaryColor
                      : Colors.grey.shade300,
                  width: hasFocus ? 1.2 : 1,
                ),
                boxShadow: hasFocus
                    ? [
                        BoxShadow(
                          color: ColorManager.kPrimaryColor
                              .withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
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
            );
          },
        ),
      ),
    );
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
              Expanded(
                child: Text(
                  'invoice.create_title'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s20,
                    0.30,
                    ColorManager.textColor,
                  ),
                ),
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 500;
                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('invoice.type_label'.tr),
                          const SizedBox(height: 4),
                          CustomDropDownWithSearch<String>(
                            hintText: 'invoice.select_type_hint'.tr,
                            title: "",
                            value: _selectedType,
                            items: const ["order", "other"],
                            focusNode: _typeFocus,
                            onChanged: (value) {
                              setState(() => _selectedType = value);
                              FocusScope.of(
                                context,
                              ).requestFocus(_dueDateFocus);
                            },
                            displayText: (item) => item == 'order'
                                ? 'invoice.type_order'.tr
                                : 'invoice.type_other'.tr,
                            showName: false,
                            height: 48,
                          ),
                          const SizedBox(height: 10),
                          _buildLabel('invoice.due_date'.tr),
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
                              FocusScope.of(
                                context,
                              ).requestFocus(_invoiceDateFocus);
                            },
                            hintText: 'invoice.select_due_date_hint'.tr,
                            height: 48,
                            focusNode: _dueDateFocus,
                          ),
                          const SizedBox(height: 10),
                          _buildLabel('invoice.invoice_date'.tr),
                          const SizedBox(height: 4),
                          CustomCalendarPickerTableCell(
                            initialDate: DateTime.tryParse(
                                  _invoiceDateController.text,
                                ) ??
                                DateTime.now(),
                            onDateSelected: (date) {
                              setState(() {
                                _invoiceDateController.text =
                                    date.toIso8601String().split('T')[0];
                              });
                              FocusScope.of(context).requestFocus(_statusFocus);
                            },
                            hintText: 'invoice.select_invoice_date_hint'.tr,
                            height: 48,
                            focusNode: _invoiceDateFocus,
                          ),
                        ],
                      );
                    }
                    // original desktop Row unchanged below
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('invoice.type_label'.tr),
                              const SizedBox(height: 4),
                              CustomDropDownWithSearch<String>(
                                hintText: 'invoice.select_type_hint'.tr,
                                title: "",
                                value: _selectedType,
                                items: const ["order", "other"],
                                focusNode: _typeFocus,
                                onChanged: (value) {
                                  setState(() => _selectedType = value);
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(_dueDateFocus);
                                },
                                displayText: (item) => item == "order"
                                    ? 'invoice.type_order'.tr
                                    : 'invoice.type_other'.tr,
                                showName: false,
                                height: 48,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('invoice.due_date'.tr),
                                    const SizedBox(height: 4),
                                    CustomCalendarPickerTableCell(
                                      initialDate: DateTime.tryParse(
                                            _dueDateController.text,
                                          ) ??
                                          DateTime.now().add(
                                            const Duration(days: 30),
                                          ),
                                      onDateSelected: (date) {
                                        setState(() {
                                          _dueDateController.text = date
                                              .toIso8601String()
                                              .split('T')[0];
                                        });
                                        FocusScope.of(
                                          context,
                                        ).requestFocus(_invoiceDateFocus);
                                      },
                                      hintText:
                                          'invoice.select_due_date_hint'.tr,
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
                                    _buildLabel('invoice.invoice_date'.tr),
                                    const SizedBox(height: 4),
                                    CustomCalendarPickerTableCell(
                                      initialDate: DateTime.tryParse(
                                            _invoiceDateController.text,
                                          ) ??
                                          DateTime.now(),
                                      onDateSelected: (date) {
                                        setState(() {
                                          _invoiceDateController.text = date
                                              .toIso8601String()
                                              .split('T')[0];
                                        });
                                        FocusScope.of(
                                          context,
                                        ).requestFocus(_statusFocus);
                                      },
                                      hintText:
                                          'invoice.select_invoice_date_hint'.tr,
                                      height: 48,
                                      focusNode: _invoiceDateFocus,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                const SizedBox(height: 12),

                // Row 3: Customer (with balance display)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('invoice.customer_label'.tr, isRequired: true),
                    const SizedBox(height: 4),
                    CustomDropDownWithSearch<String>(
                      hintText: _isLoadingCustomers
                          ? 'invoice.loading_customers'.tr
                          : 'invoice.select_customer_hint'.tr,
                      title: "",
                      value: _selectedCustomer,
                      items: _customerList.map((c) => c.id.toString()).toList(),
                      focusNode: _customerFocus,
                      onChanged: (value) {
                        setState(() => _selectedCustomer = value);
                        _calculateInvoiceTotal(); // Recalculate with new balance
                        FocusScope.of(
                          context,
                        ).requestFocus(_newItemCard.itemNameFocus);
                      },
                      displayText: (item) {
                        final customer = _customerList.firstWhere(
                          (c) => c.id?.toString() == item,
                          orElse: () => CustomerListModelData(
                            id: 0,
                            name: 'general.unknown'.tr,
                          ),
                        );
                        return customer.name ?? 'general.unknown'.tr;
                      },
                      showName: false,
                      height: 48,
                    ),
                    const SizedBox(height: 4),
                    // Display customer balance with color coding
                    Builder(
                      builder: (context) {
                        final balance = _getCustomerBalance(_selectedCustomer);
                        Color balanceColor;
                        if (balance > 0) {
                          balanceColor = Colors.green;
                        } else if (balance < 0) {
                          balanceColor = Colors.red;
                        } else {
                          balanceColor = Colors.grey;
                        }
                        return Text(
                          'invoice.balance_prefix'.tr.replaceAll(
                                '@balance',
                                balance.toStringAsFixed(2),
                              ),
                          style: buildCustomStyle(
                            FontWeightManager.medium,
                            FontSize.s12,
                            0.20,
                            balanceColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Invoice Items Section
          Text(
            'invoice.items_section_title'.tr,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.30,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 8),

          const SizedBox(height: 5),

          // Added Items List
          CustomBoxShadowContainer(
            circleRadius: 12,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 500;
                const tableMinWidth = 560.0;
                final tableContent = Column(
                  children: [
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _buildTableHeader('invoice.col_item_name'.tr, flex: 2),
                        _buildTableHeader('invoice.col_unit_amount'.tr),
                        _buildTableHeader('invoice.col_tax_percent'.tr),
                        _buildTableHeader('invoice.col_quantity'.tr),
                        _buildTableHeader('invoice.col_total'.tr),
                      ],
                    ),
                    const SizedBox(height: 5),
                    if (_invoiceItemCards.isNotEmpty)
                      Column(
                        children: [
                          // Items list
                          ..._invoiceItemCards.asMap().entries.map((entry) {
                            int index = entry.key;
                            InvoiceItemCard card = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(top: 5),
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
                                  SizedBox(
                                    height: 40,
                                    width: 40,
                                    child: IconButton(
                                      onPressed: () =>
                                          _removeInvoiceItemCard(index),
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 18,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(_newItemCard.unitAmountFocus);
                                },
                              ),
                              _buildInputCell(
                                _newItemCard.unitAmountController,
                                _newItemCard.unitAmountFocus,
                                hintText: "0",
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) {
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(_newItemCard.taxFocus);
                                },
                              ),
                              _buildInputCell(
                                _newItemCard.taxController,
                                _newItemCard.taxFocus,
                                hintText: "0",
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) {
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(_newItemCard.quantityFocus);
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
                              InkWell(
                                onTap: () {
                                  _addNewInvoiceItemCard();
                                },
                                child: Container(
                                  height: 40,
                                  width: 40,
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
                              ),
                            ],
                          ),
                          // const SizedBox(height: 12),

                          // Center(
                          //   child: CustomRoundButtonAdvanced(
                          //     title: "Add to invoice items",
                          //     fct: _addNewInvoiceItemCard,
                          //     width: 180,
                          //     height: 40,
                          //     fontSize: 14,
                          //   ),
                          // ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ],
                );
                if (isMobile) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: tableMinWidth, child: tableContent),
                  );
                }
                return tableContent;
              },
            ),
          ),

          const SizedBox(height: 8),

          CustomBoxShadowContainer(
            circleRadius: 12,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Leave room for selected text plus the clear and arrow icons.
                // Wrap controls and move totals below on smaller dialogs.
                if (constraints.maxWidth < 1240) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPaymentControls(constraints.maxWidth),
                      const SizedBox(height: 20),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: SizedBox(
                          width: constraints.maxWidth < 340
                              ? constraints.maxWidth
                              : 340,
                          child: _buildInvoiceSummary(),
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child:
                            _buildPaymentControls(constraints.maxWidth - 364)),
                    const SizedBox(width: 24),
                    SizedBox(width: 340, child: _buildInvoiceSummary()),
                  ],
                );
              },
            ),
          ),

          // Inline Add Form
          // CustomBoxShadowContainer(
          //   circleRadius: 12,
          //   padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          //   child:
          // ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CustomRoundButtonAdvanced(
                title: 'general.cancel'.tr,
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
                title: _isSubmitting
                    ? 'invoice.submitting'.tr
                    : 'invoice.submit'.tr,
                fct: _isSubmitting ? () {} : _submitInvoice,
                width: _isSubmitting ? 130 : 100,
                height: 45,
                fontSize: 14,
                boxColor: _isSubmitting ? Colors.grey.shade400 : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
