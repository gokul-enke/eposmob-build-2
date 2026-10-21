import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import '../state/receipt_list_controller.dart';

class ReceiptListFilters {
  ReceiptListFilters(
      {required this.controller,
      required this.filtersKey,
      required this.statusOptions,
      required this.methodOptions,
      required this.onSelectDate});
  final ReceiptListController controller;
  final Key filtersKey;
  final List<String> statusOptions, methodOptions;
  final ValueChanged<bool> onSelectDate;
  FilterFieldDef _text(
          TextEditingController controller, String label, IconData icon,
          {TextInputType keyboardType = TextInputType.text}) =>
      TextFilterField(
          controller: controller,
          label: label,
          hint: label,
          icon: icon,
          keyboardType: keyboardType);

  FilterFieldDef _date(bool from) {
    final label = from ? 'receipt.from_date'.tr : 'receipt.to_date'.tr;
    return CustomFilterField(
        child: TextField(
            controller: from ? controller.fromDate : controller.toDate,
            readOnly: true,
            textAlignVertical: TextAlignVertical.center,
            style: AppTextStyles.input,
            decoration: AppInputDecoration.filter(
                label: label, hint: label, icon: Icons.calendar_today_outlined),
            onTap: () => onSelectDate(from)));
  }

  /// The provider's options plus the current value, without the "All"
  /// placeholder (shown as the `null` option instead).
  List<FilterOption<String?>> _options(String allLabel, List<String> values,
          String placeholder, String? current, String Function(String) label) =>
      [
        FilterOption<String?>(null, allLabel),
        for (final v in {
          ...values.where((v) => v != placeholder),
          if (current != null) current,
        })
          FilterOption<String?>(v, label(v)),
      ];

  Widget build() => FilterPanel(
          key: filtersKey,
          title: 'receipt.find'.tr,
          hint: 'receipt.filter_hint'.tr,
          resetLabel: 'list.reset'.tr,
          onSearch: controller.search.schedule,
          onSubmit: controller.search.flush,
          onReset: controller.reset,
          fields: [
            _text(controller.receiptNumber, 'receipt.receipt_no_hint'.tr,
                Icons.receipt_long_outlined),
            _text(controller.orderNumber, 'receipt.order_or_offline_receipt'.tr,
                Icons.numbers_rounded),
            _text(controller.paymentReference, 'receipt.reference_no_hint'.tr,
                Icons.tag_outlined),
            _text(
                controller.name, 'receipt.name_hint'.tr, Icons.person_outline),
            _text(
                controller.phone, 'receipt.phone_hint'.tr, Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            _text(
                controller.email, 'receipt.email_hint'.tr, Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            DropdownFilterField<String?>(
                label: 'receipt.col_status'.tr,
                icon: Icons.check_circle_outline,
                value: controller.status,
                options: _options('receipt.hint_all_status'.tr, statusOptions,
                    'All Status', controller.status, UiCodeLabels.status),
                onChanged: (v) {
                  controller.status = v;
                  controller.apply();
                }),
            DropdownFilterField<String?>(
                label: 'receipt.col_method'.tr,
                icon: Icons.payment_outlined,
                value: controller.paymentMethod,
                options: _options(
                    'receipt.hint_all_payment'.tr,
                    methodOptions,
                    'All Payment Methods',
                    controller.paymentMethod,
                    UiCodeLabels.payment),
                onChanged: (v) {
                  controller.paymentMethod = v;
                  controller.apply();
                }),
            _date(true),
            _date(false),
          ]);
}
