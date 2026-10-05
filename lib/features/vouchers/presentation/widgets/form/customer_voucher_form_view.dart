import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../state/customer_voucher_form_controller.dart';
import '../../state/customer_voucher_form_item.dart';
part 'customer_voucher_form_section_0.dart';
part 'customer_voucher_form_section_1.dart';

class CustomerVoucherFormView {
  const CustomerVoucherFormView(
      {required this.context,
      required this.form,
      required this.formKey,
      required this.onSubmit,
      required this.onClose});
  final BuildContext context;
  final CustomerVoucherFormController form;
  final GlobalKey<FormState> formKey;
  final VoidCallback onSubmit, onClose;
  Widget build() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'customer_voucher.create_voucher_button'.tr,
                    style: buildCustomStyle(FontWeightManager.bold,
                        FontSize.s24, 0.36, Colors.black),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => onClose(),
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
                            child: _buildCustomerDropdown(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDateField(
                              'customer_voucher.voucher_date_label'.tr,
                              form.selectedVoucherDate,
                              (DateTime date) => form.update(
                                  () => form.selectedVoucherDate = date),
                              form.voucherDateFocus,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTypeDropdown(),
                          ),

                          // Expanded(
                          //   child: _buildTypeDropdown(),
                          // ),

                          // Expanded(
                          //   child: _buildTextField(
                          //     'Total Voucher Amount',
                          //     form.totalAmountController,
                          //     '0',
                          //     readOnly: true,
                          //   ),
                          // ),
                        ],
                      ),
                      // Second row: Voucher Date, Due Date, Status
                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: _buildDateField(
                      //         'Voucher date',
                      //         form.selectedVoucherDate,
                      //         (DateTime date) =>
                      //             form.update(() => form.selectedVoucherDate = date),
                      //       ),
                      //     ),
                      //     const SizedBox(width: 16),
                      //     Expanded(
                      //       child: _buildDateField(
                      //         'Due date',
                      //         form.selectedDueDate,
                      //         (DateTime date) =>
                      //             form.update(() => form.selectedDueDate = date),
                      //       ),
                      //     ),
                      //     const SizedBox(width: 16),
                      //     Expanded(
                      //       child: _buildStatusDropdown(),
                      //     ),
                      //   ],
                      // ),
                      // Third row: Payment Method, Customer
                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: _buildPaymentMethodDropdown(),
                      //     ),
                      //     const SizedBox(width: 16),
                      //     // Expanded(
                      //     //   child: _buildCustomerDropdown(),
                      //     // ),
                      //   ],
                      // ),
                      const SizedBox(height: 24),
                      // Voucher Items Section
                      Text(
                        'customer_voucher.voucher_items_label'.tr,
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
                      Row(
                        children: [
                          Expanded(child: _buildPaymentMethodDropdown()),
                          Expanded(flex: 2, child: const SizedBox()),
                          Expanded(
                              child: Column(
                            children: [
                              Divider(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    'customer_voucher.items_label'.tr,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    form.voucherItems.length.toString(),
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
                                    'customer_voucher.total_amount_label'.tr,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    form.totalAmountController.text
                                            .toString()
                                            .isEmpty
                                        ? '0'
                                        : form.totalAmountController.text
                                            .toString(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Add item button`
                      // Center(
                      //   child: CustomRoundButton(
                      //     title: "Add to voucher items",
                      //     boxColor: Colors.white,
                      //     textColor: ColorManager.kPrimaryColor,
                      //     borderColor: ColorManager.kPrimaryColor,
                      //     fct: () {
                      // form.update(() {
                      //   form.voucherItems.add(CustomerVoucherFormItem());
                      // });
                      //     },
                      //     height: 45,
                      //     width: 200,
                      //     fontSize: FontSize.s12,
                      //   ),
                      // ),
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
                    title: 'general.cancel'.tr,
                    boxColor: Colors.white,
                    textColor: ColorManager.kPrimaryColor,
                    borderColor: ColorManager.kPrimaryColor,
                    fct: () => onClose(),
                    height: 45,
                    width: 120,
                    fontSize: FontSize.s12,
                  ),
                  const SizedBox(width: 16),
                  CustomRoundButton(
                    title: form.isLoading
                        ? 'customer_voucher.submitting'.tr
                        : 'customer_voucher.submit_button'.tr,
                    boxColor: ColorManager.kPrimaryColor,
                    textColor: Colors.white,
                    fct: form.isLoading ? () {} : onSubmit,
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
}
