import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../supplier_report_filters.dart';

String _tr(String key) => 'supplier_transaction_report.$key'.tr;
String _option(String value) =>
    {
      'All': _tr('all'),
      'Credit': 'transaction_status_labels.credit'.tr,
      'Debit': 'transaction_status_labels.debit'.tr,
      'Cash': 'transaction_status_labels.cash'.tr,
      'Card': 'transaction_status_labels.card'.tr,
      'Bank Transfer': 'transaction_status_labels.bank_transfer'.tr,
      'Cheque': 'transaction_status_labels.cheque'.tr,
      'UPI': 'transaction_status_labels.upi'.tr,
    }[value] ??
    value;

/// Stateless fields use the same choices, local predicates and date picker.
FilterPanel supplierReportDetailsFilters({
  required TextEditingController search,
  required String type,
  required String payment,
  required DateTime? from,
  required DateTime? to,
  required VoidCallback onSearch,
  required VoidCallback onReset,
  required ValueChanged<String?> onType,
  required ValueChanged<String?> onPayment,
  required ValueChanged<DateTime> onFrom,
  required ValueChanged<DateTime> onTo,
}) =>
    FilterPanel(
      key: const ValueKey('supplier-report-details-filters'),
      title: _tr('find'),
      hint: _tr('search_hint'),
      resetLabel: 'list.reset'.tr,
      onSearch: onSearch,
      onReset: onReset,
      fields: [
        TextFilterField(
            controller: search,
            label: _tr('search'),
            hint: _tr('search_hint'),
            icon: Icons.search_rounded),
        CustomFilterField(
            child: SupplierReportDateField(
                key: const ValueKey('supplier-report-details-from'),
                label: _tr('from_date'),
                value: from,
                onChanged: onFrom)),
        CustomFilterField(
            child: SupplierReportDateField(
                key: const ValueKey('supplier-report-details-to'),
                label: _tr('to_date'),
                value: to,
                onChanged: onTo)),
        DropdownFilterField<String>(
            label: _tr('transaction_type_label'),
            icon: Icons.swap_vert_rounded,
            value: type,
            options: [
              for (final value in ['All', 'Credit', 'Debit'])
                FilterOption(value, _option(value))
            ],
            onChanged: onType),
        DropdownFilterField<String>(
            label: _tr('payment_method_label'),
            icon: Icons.payments_outlined,
            value: payment,
            options: [
              for (final value in [
                'All',
                'Cash',
                'Card',
                'Bank Transfer',
                'Cheque',
                'UPI'
              ])
                FilterOption(value, _option(value))
            ],
            onChanged: onPayment),
      ],
    );
