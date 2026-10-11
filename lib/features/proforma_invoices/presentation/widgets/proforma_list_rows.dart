import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../domain/proforma_list_query.dart';
import 'proforma_labels.dart';

class ProformaListRows {
  ProformaListRows({required this.onCopy, required this.onView});
  final void Function(String, bool) onCopy;
  final void Function(Map<String, dynamic>) onView;
  Widget _copyButton(String text, {required bool quotation}) => IconButton(
        icon: const Icon(Icons.copy_outlined, size: 16),
        color: AppColors.muted,
        tooltip: (quotation
                ? 'proforma_invoice.copy_quotation'
                : 'proforma_invoice.copy_invoice')
            .tr,
        onPressed: () => onCopy(text, quotation),
      );

  /// Table cell: the reference with a copy button (when there is one).
  Widget _reference(dynamic value, {required bool quotation}) {
    final text = proformaText(value);
    return Row(children: [
      Expanded(child: TableCells.text(text)),
      if (text != '-') _copyButton(text, quotation: quotation),
    ]);
  }

  /// Card line: label, reference and a copy button (when there is one).
  Widget _referenceInfo(String label, dynamic value,
      {required bool quotation}) {
    final text = proformaText(value);
    return InfoRow(
        label: label,
        value: text,
        trailing: text == '-' ? null : _copyButton(text, quotation: quotation));
  }

  Widget _status(String status) => AppBadge(
      label: proformaStatusLabel(status),
      tone: switch (status.toLowerCase()) {
        'paid' || 'order created' => AppBadgeTone.success,
        'overdue' => AppBadgeTone.danger,
        'pending' => AppBadgeTone.warning,
        _ => AppBadgeTone.neutral,
      });

  Widget _avatar(String name, double size) =>
      AppAvatar(name: name == '-' ? '' : name, semanticLabel: name, size: size);

  Widget card(Map<String, dynamic> invoice, int number) {
    final customer = proformaText(proformaMap(invoice['customer'])['name']);
    return AppListCard(
      title: customer,
      leading: _avatar(customer, 40),
      trailing: _status(proformaText(invoice['status'])),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _referenceInfo('proforma_invoice.invoice_number_label'.tr,
            invoice['invoice_number'],
            quotation: false),
        _referenceInfo('proforma_invoice.field_quotation_number'.tr,
            proformaMap(invoice['quotation'])['quotation_number'],
            quotation: true),
        const SizedBox(height: AppSpacing.xs),
        AppMetricStrip(metrics: [
          AppMetric(
              icon: Icons.event_outlined,
              label: 'proforma_invoice.field_invoice_date'.tr,
              value: proformaText(invoice['invoice_date'])),
          AppMetric(
              icon: Icons.event_busy_outlined,
              label: 'proforma_invoice.field_due_date'.tr,
              value: proformaText(invoice['due_date'])),
        ]),
        InfoRow(
            label: 'proforma_invoice.field_amount'.tr,
            value: proformaText(invoice['amount'])),
      ]),
      actionLabel: 'list.view'.tr,
      actionIcon: Icons.visibility_outlined,
      onAction: () => onView(invoice),
    );
  }

  List<TableColumnDef<Map<String, dynamic>>> columns() => [
        TableColumnDef(
            label: 'proforma_invoice.invoice_number_label'.tr,
            flex: 1.7,
            cellBuilder: (v, _) =>
                _reference(v['invoice_number'], quotation: false)),
        TableColumnDef(
            label: 'proforma_invoice.customer_label'.tr,
            flex: 2,
            cellBuilder: (v, _) {
              final name = proformaText(proformaMap(v['customer'])['name']);
              return TableCells.avatarName(
                  name: name, avatar: _avatar(name, 36));
            }),
        TableColumnDef(
            label: 'proforma_invoice.field_quotation_number'.tr,
            flex: 1.7,
            cellBuilder: (v, _) => _reference(
                proformaMap(v['quotation'])['quotation_number'],
                quotation: true)),
        TableColumnDef(
            label: 'proforma_invoice.field_invoice_date'.tr,
            flex: 1.3,
            cellBuilder: (v, _) =>
                TableCells.text(proformaText(v['invoice_date']))),
        TableColumnDef(
            label: 'proforma_invoice.field_due_date'.tr,
            flex: 1.3,
            cellBuilder: (v, _) =>
                TableCells.text(proformaText(v['due_date']))),
        TableColumnDef(
            label: 'proforma_invoice.field_amount'.tr,
            flex: 1.2,
            cellBuilder: (v, _) => TableCells.text(proformaText(v['amount']))),
        TableColumnDef(
            label: 'proforma_invoice.status_label'.tr,
            flex: 1.4,
            cellBuilder: (v, _) =>
                TableCells.widget(_status(proformaText(v['status'])))),
        TableColumnDef(
            label: 'proforma_invoice.col_actions'.tr,
            flex: 1.1,
            cellBuilder: (v, _) => TableCells.action(
                label: 'list.view'.tr,
                icon: Icons.visibility_outlined,
                onPressed: () => onView(v))),
      ];
}
