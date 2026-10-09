import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'proforma_labels.dart';
import '../state/proforma_list_controller.dart';

class ProformaListFilters {
  ProformaListFilters(this.controller, {required this.filtersKey});
  final ProformaListController controller;
  final Key filtersKey;
  Widget build() => FilterPanel(
        key: filtersKey,
        title: 'proforma_invoice.find'.tr,
        hint: 'proforma_invoice.filter_hint'.tr,
        resetLabel: 'list.reset'.tr,
        onSearch: controller.search.schedule,
        onSubmit: controller.search.flush,
        onReset: controller.reset,
        fields: [
          TextFilterField(
              controller: controller.invoiceNumber,
              label: 'proforma_invoice.search_invoice_number_hint'.tr,
              hint: 'proforma_invoice.search_invoice_number_hint'.tr,
              icon: Icons.receipt_long_outlined),
          TextFilterField(
              controller: controller.customerSearch,
              label: 'proforma_invoice.name_or_phone_hint'.tr,
              hint: 'proforma_invoice.name_or_phone_hint'.tr,
              icon: Icons.person_outline),
          DropdownFilterField<String>(
              label: 'proforma_invoice.status_label'.tr,
              icon: Icons.check_circle_outline,
              value: controller.status,
              options: [
                for (final status in proformaStatusOptions)
                  FilterOption(status, proformaStatusLabel(status)),
              ],
              onChanged: controller.selectStatus),
        ],
      );
}
