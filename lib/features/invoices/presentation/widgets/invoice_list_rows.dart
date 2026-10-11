import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/screens/transactions/invoice_list/invoice_list_cells.dart';

class InvoiceListRows {
  InvoiceListRows(
      {required this.selectedInvoiceIds,
      required this.isBulkSending,
      required this.onSelect,
      required this.onCopy,
      required this.onView,
      required this.onMore});
  final Set<int> selectedInvoiceIds;
  final bool isBulkSending;
  final void Function(int, bool) onSelect;
  final ValueChanged<Invoice> onCopy, onView, onMore;
  Widget _selection(Invoice invoice) => Checkbox(
      value: selectedInvoiceIds.contains(invoice.id),
      onChanged: isBulkSending
          ? null
          : (value) => onSelect(invoice.id, value == true));

  Widget _copyButton(Invoice invoice) => IconButton(
      icon: const Icon(Icons.copy_outlined, size: 16),
      color: AppColors.muted,
      tooltip: 'invoice.field_invoice_number'.tr,
      onPressed: () => onCopy(invoice));

  Widget _reference(Invoice invoice) => Row(children: [
        Expanded(
            child: TableCells.text(
                InvoiceListLabels.orDash(invoice.invoiceNumber))),
        _copyButton(invoice),
      ]);

  Widget _avatar(Invoice invoice, double size) => AppAvatar(
      name: invoice.customer.user.name,
      semanticLabel: invoice.customer.user.name,
      size: size);

  Widget _actions(Invoice invoice) => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppOutlinedButton(
              label: 'list.view'.tr,
              icon: Icons.visibility_outlined,
              iconSize: 15,
              height: AppSizes.compactControl,
              radius: AppRadius.tile,
              onPressed: () => onView(invoice)),
          AppSquareIconButton(
              icon: Icons.more_vert,
              tooltip: 'general.more'.tr,
              size: AppSizes.compactControl,
              iconSize: 18,
              radius: AppRadius.tile,
              foreground: AppColors.primary,
              onPressed: () => onMore(invoice)),
        ],
      );

  Widget card(Invoice invoice, bool showZatca) => AppListCard(
      title: InvoiceListLabels.orDash(invoice.customer.user.name),
      leading: _avatar(invoice, 40),
      trailing: showZatca ? _selection(invoice) : null,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InfoRow(
            label: 'invoice.field_invoice_number'.tr,
            value: InvoiceListLabels.orDash(invoice.invoiceNumber),
            trailing: _copyButton(invoice)),
        const SizedBox(height: AppSpacing.xs),
        AppMetricStrip(metrics: [
          AppMetric(
              icon: Icons.payments_outlined,
              label: 'invoice.col_amount'.tr,
              value: InvoiceListLabels.orDash(invoice.amount)),
          AppMetric(
              icon: Icons.event_outlined,
              label: 'invoice.field_invoice_date'.tr,
              value: InvoiceListLabels.orDash(invoice.invoiceDate)),
        ]),
        InfoRow(
            label: 'invoice.field_due_date'.tr,
            value: InvoiceListLabels.orDash(invoice.dueDate)),
        InfoRow(
            label: 'invoice.field_type'.tr,
            value:
                InvoiceListLabels.orDash(InvoiceListLabels.type(invoice.type))),
        const SizedBox(height: AppSpacing.xs),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          InvoiceListLabels.statusBadge(invoice.status),
          if (showZatca) InvoiceListLabels.zatcaBadge(invoice),
        ]),
        const SizedBox(height: AppSpacing.md),
        _actions(invoice),
      ]));

  List<TableColumnDef<Invoice>> columns(bool showZatca) => [
        if (showZatca)
          TableColumnDef(
              label: '',
              flex: .5,
              cellBuilder: (v, _) => TableCells.widget(_selection(v))),
        TableColumnDef(
            label: 'invoice.field_invoice_number'.tr,
            flex: 1.7,
            cellBuilder: (v, _) => _reference(v)),
        TableColumnDef(
            label: 'invoice.col_amount'.tr,
            cellBuilder: (v, _) =>
                TableCells.text(InvoiceListLabels.orDash(v.amount))),
        TableColumnDef(
            label: 'invoice.col_name'.tr,
            flex: 1.8,
            cellBuilder: (v, _) => TableCells.avatarName(
                name: InvoiceListLabels.orDash(v.customer.user.name),
                avatar: _avatar(v, 36))),
        TableColumnDef(
            label: 'invoice.field_invoice_date'.tr,
            flex: 1.3,
            cellBuilder: (v, _) =>
                TableCells.text(InvoiceListLabels.orDash(v.invoiceDate))),
        TableColumnDef(
            label: 'invoice.field_type'.tr,
            cellBuilder: (v, _) => TableCells.text(
                InvoiceListLabels.orDash(InvoiceListLabels.type(v.type)))),
        TableColumnDef(
            label: 'invoice.field_due_date'.tr,
            flex: 1.3,
            cellBuilder: (v, _) =>
                TableCells.text(InvoiceListLabels.orDash(v.dueDate))),
        TableColumnDef(
            label: 'invoice.field_status'.tr,
            cellBuilder: (v, _) =>
                TableCells.widget(InvoiceListLabels.statusBadge(v.status))),
        if (showZatca)
          TableColumnDef(
              label: 'invoice.col_zatca_status'.tr,
              flex: 1.4,
              cellBuilder: (v, _) =>
                  TableCells.widget(InvoiceListLabels.zatcaBadge(v))),
        TableColumnDef(
            label: 'invoice.col_action'.tr,
            flex: 1.6,
            cellBuilder: (v, _) => Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _actions(v)))),
      ];
}
