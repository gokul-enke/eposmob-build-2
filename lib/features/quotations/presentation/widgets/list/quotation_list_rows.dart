import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/quotation_model.dart';
import 'quotation_list_labels.dart';

class QuotationRowActions extends StatelessWidget {
  const QuotationRowActions(
      {super.key,
      required this.row,
      required this.onView,
      required this.onConvert,
      required this.onPrint,
      this.converting = false,
      this.printing = false});
  final Quotation row;
  final ValueChanged<Quotation> onView, onConvert, onPrint;
  final bool converting, printing;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
        AppSquareIconButton(
            key: ValueKey('quotation-view-${row.id}'),
            icon: Icons.visibility_outlined,
            tooltip: 'quotations.view_tooltip'.tr,
            foreground: AppColors.primary,
            onPressed: () => onView(row)),
        AppSquareIconButton(
            key: ValueKey('quotation-convert-${row.id}'),
            icon: Icons.shopping_cart_checkout,
            tooltip: 'quotations.convert_tooltip'.tr,
            foreground: AppColors.primary,
            onPressed: converting ? null : () => onConvert(row)),
        AppSquareIconButton(
            key: ValueKey('quotation-print-${row.id}'),
            icon: Icons.print_outlined,
            tooltip: 'quotations.print_tooltip'.tr,
            foreground: AppColors.primary,
            onPressed: printing ? null : () => onPrint(row)),
      ]);
}

List<TableColumnDef<Quotation>> quotationListColumns(
        Widget Function(Quotation) actions, ValueChanged<Quotation> copy) =>
    [
      TableColumnDef(
          label: 'quotations.quotation_number_label'.tr,
          flex: 1.3,
          cellBuilder: (q, _) => TableCells.widget(Row(children: [
                Expanded(
                    child: Text(q.quotationNumber ?? '—',
                        style: AppTextStyles.input,
                        overflow: TextOverflow.ellipsis)),
                if (q.quotationNumber?.isNotEmpty ?? false)
                  AppSquareIconButton(
                      icon: Icons.copy_outlined,
                      tooltip: 'quotations.list_copy'.tr,
                      onPressed: () => copy(q))
              ]))),
      TableColumnDef(
          label: 'quotations.customer_col'.tr,
          flex: 1.3,
          cellBuilder: (q, _) => TableCells.text(q.customer ?? '—')),
      TableColumnDef(
          label: 'quotations.store_col'.tr,
          flex: 1.2,
          cellBuilder: (q, _) => TableCells.text(q.store ?? '—')),
      TableColumnDef(
          label: 'quotations.quotation_date'.tr,
          cellBuilder: (q, _) =>
              TableCells.text(quotationDateLabel(q.quotationDate))),
      TableColumnDef(
          label: 'quotations.expiry_date'.tr,
          cellBuilder: (q, _) =>
              TableCells.text(quotationDateLabel(q.expiryDate))),
      TableColumnDef(
          label: 'sales.status'.tr,
          flex: 1.1,
          cellBuilder: (q, _) => TableCells.widget(AppBadge(
              label: quotationStatusLabel(q.status ?? ''),
              tone: quotationStatusTone(q.status ?? '')))),
      TableColumnDef(
          label: 'quotations.actions_col'.tr,
          flex: 1.5,
          cellBuilder: (q, _) => TableCells.widget(actions(q))),
    ];

Widget quotationListCard(
        Quotation q, Widget actions, ValueChanged<Quotation> copy) =>
    AppListCard(
        title: q.quotationNumber ?? '—',
        subtitle: q.customer ?? '—',
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppBadge(
              label: quotationStatusLabel(q.status ?? ''),
              tone: quotationStatusTone(q.status ?? '')),
          const SizedBox(height: AppSpacing.sm),
          Text('${'quotations.store_col'.tr}: ${q.store ?? '—'}',
              style: AppTextStyles.body),
          Text(
              '${'quotations.quotation_date'.tr}: ${quotationDateLabel(q.quotationDate)}',
              style: AppTextStyles.body),
          Text(
              '${'quotations.expiry_date'.tr}: ${quotationDateLabel(q.expiryDate)}',
              style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            actions,
            if (q.quotationNumber?.isNotEmpty ?? false)
              AppSquareIconButton(
                  icon: Icons.copy_outlined,
                  tooltip: 'quotations.list_copy'.tr,
                  onPressed: () => copy(q)),
          ]),
        ]));
