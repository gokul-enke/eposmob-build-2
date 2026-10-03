import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

import '../../state/supplier_voucher_form_controller.dart';
import '../../state/supplier_voucher_form_item.dart';
part 'supplier_voucher_form_section_0.dart';
part 'supplier_voucher_form_section_1.dart';

class SupplierVoucherFormView {
  const SupplierVoucherFormView(
      {required this.context,
      required this.form,
      required this.formKey,
      required this.onSubmit,
      required this.onClose});
  final BuildContext context;
  final SupplierVoucherFormController form;
  final GlobalKey<FormState> formKey;
  final VoidCallback onSubmit, onClose;
  Widget build() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 700;
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
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'supplier_voucher.create_voucher_button'.tr,
                      style: buildCustomStyle(
                          FontWeightManager.bold,
                          isMobile ? FontSize.s18 : FontSize.s24,
                          0.36,
                          Colors.black),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => onClose(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First row: Type, Total Amount
                      isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSupplierDropdown(),
                                const SizedBox(height: 12),
                                _buildTypeDropdown(),
                                const SizedBox(height: 12),
                                _buildDateField(
                                  'supplier_voucher.voucher_date_label'.tr,
                                  form.selectedVoucherDate,
                                  (DateTime date) => form.update(
                                      () => form.selectedVoucherDate = date),
                                  form.voucherDateFocus,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: _buildSupplierDropdown()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildTypeDropdown()),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDateField(
                                    'supplier_voucher.voucher_date_label'.tr,
                                    form.selectedVoucherDate,
                                    (DateTime date) => form.update(
                                        () => form.selectedVoucherDate = date),
                                    form.voucherDateFocus,
                                  ),
                                ),
                              ],
                            ),
                      // const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      // Third row: Payment Method, Supplier
                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: _buildPaymentMethodDropdown(),
                      //     ),
                      //     const SizedBox(width: 16),
                      //     Expanded(
                      //       child: _buildSupplierDropdown(),
                      //     ),
                      //   ],
                      // ),
                      // const SizedBox(height: 24),
                      Text(
                        'supplier_voucher.voucher_items_label'.tr,
                        style: buildCustomStyle(FontWeightManager.semiBold,
                            FontSize.s16, 0.27, Colors.black),
                      ),
                      const SizedBox(height: 10),
                      isMobile
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: 650,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildItemsTableHeader(),
                                    const SizedBox(height: 8),
                                    ..._buildItemRows(),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildItemsTableHeader(),
                                const SizedBox(height: 8),
                                ..._buildItemRows(),
                              ],
                            ),
                      const SizedBox(height: 16),
                      isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildPaymentMethodDropdown(),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                _buildSummaryLine(
                                    'supplier_voucher.net_total_label'.tr,
                                    form.netTotalController.text),
                                _buildSummaryLine(
                                    'supplier_voucher.total_tax_label'.tr,
                                    form.totalTaxController.text),
                                _buildSummaryLine(
                                    'supplier_voucher.total_payable_label'.tr,
                                    form.totalAmountController.text),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildPaymentMethodDropdown()),
                                Expanded(flex: 2, child: const SizedBox()),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      _buildSummaryLine(
                                          'supplier_voucher.net_total_label'.tr,
                                          form.netTotalController.text),
                                      _buildSummaryLine(
                                          'supplier_voucher.total_tax_label'.tr,
                                          form.totalTaxController.text),
                                      _buildSummaryLine(
                                          'supplier_voucher.total_payable_label'
                                              .tr,
                                          form.totalAmountController.text),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                      // Center(
                      // child: CustomRoundButton(
                      //   title: "Add to voucher items",
                      //   boxColor: Colors.white,
                      //   textColor: ColorManager.kPrimaryColor,
                      //   borderColor: ColorManager.kPrimaryColor,
                      //   fct: () {
                      // form.update(() {
                      //   form.voucherItems.add(SupplierVoucherFormItem());
                      // });
                      //   },
                      //   height: 45,
                      //   width: 200,
                      //   fontSize: FontSize.s12,
                      // ),
                      // ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              isMobile
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: CustomRoundButton(
                            title: form.isLoading
                                ? 'supplier_voucher.submitting'.tr
                                : 'supplier_voucher.submit_button'.tr,
                            boxColor: ColorManager.kPrimaryColor,
                            textColor: Colors.white,
                            fct: form.isLoading ? () {} : onSubmit,
                            height: 45,
                            width: double.infinity,
                            fontSize: FontSize.s12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: CustomRoundButton(
                            title: 'general.cancel'.tr,
                            boxColor: Colors.white,
                            textColor: ColorManager.kPrimaryColor,
                            borderColor: ColorManager.kPrimaryColor,
                            fct: () => onClose(),
                            height: 45,
                            width: double.infinity,
                            fontSize: FontSize.s12,
                          ),
                        ),
                      ],
                    )
                  : Row(
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
                              ? 'supplier_voucher.submitting'.tr
                              : 'supplier_voucher.submit_button'.tr,
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
