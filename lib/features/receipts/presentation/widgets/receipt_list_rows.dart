import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/list_receipt.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import '../../domain/receipt_list_query.dart';

class ReceiptListRows {
  ReceiptListRows(
      {required this.onCopy, required this.onView, required this.onShare});
  final ValueChanged<String> onCopy;
  final ValueChanged<Receipt> onView, onShare;
  static String _orDash(String value) => value.trim().isEmpty ? '—' : value;

  Widget _status(Receipt r) => AppBadge(
      label: UiCodeLabels.status(r.receiptStatus),
      tone: switch (r.receiptStatus.toLowerCase()) {
        'paid' => AppBadgeTone.success,
        'pending' => AppBadgeTone.warning,
        'fail' || 'failed' => AppBadgeTone.danger,
        _ => AppBadgeTone.neutral,
      });

  String _type(Receipt r) => receiptTypeKey(r).tr;

  Widget _typeBadge(Receipt r) {
    final invoice = r.receiptPayments.any((p) => p.invoiceId != null);
    final general = r.receiptPayments.any((p) => p.invoiceId == null);
    return AppBadge(
        label: _type(r),
        tone: invoice
            ? (general ? AppBadgeTone.warning : AppBadgeTone.info)
            : AppBadgeTone.success);
  }

  Widget _copyButton(String text) => IconButton(
      icon: const Icon(Icons.copy_outlined, size: 16),
      color: AppColors.muted,
      tooltip: 'receipt.copy'.tr,
      onPressed: () => onCopy(text));

  /// Table cell: the value with a copy button (when there is a value).
  Widget _copyCell(String text) => Row(children: [
        Expanded(child: TableCells.text(_orDash(text))),
        if (text.isNotEmpty) _copyButton(text),
      ]);

  /// Card line: label, value and a copy button (when there is a value).
  Widget _copyInfo(String label, String text) => InfoRow(
      label: label,
      value: _orDash(text),
      trailing: text.isEmpty ? null : _copyButton(text));

  Widget _actionButtons(Receipt r) => Wrap(
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
                onPressed: () => onView(r)),
            AppSquareIconButton(
                icon: Icons.share_outlined,
                tooltip: 'receipt.share_action'.tr,
                size: AppSizes.compactControl,
                iconSize: 18,
                radius: AppRadius.tile,
                foreground: AppColors.primary,
                onPressed: () => onShare(r)),
          ]);

  Widget card(Receipt r) => AppListCard(
      title: _orDash(r.customer.user.name),
      leading: AppAvatar(
          name: r.customer.user.name, semanticLabel: r.customer.user.name),
      trailing: _status(r),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _copyInfo('receipt.col_receipt_number'.tr, r.receiptNumber),
        InfoRow(label: 'receipt.field_amount'.tr, value: _orDash(r.amount)),
        _copyInfo('receipt.col_payment_reference'.tr, r.paymentReference),
        const SizedBox(height: AppSpacing.sm),
        _typeBadge(r),
        const SizedBox(height: AppSpacing.md),
        _actionButtons(r),
      ]));

  List<TableColumnDef<Receipt>> columns() => [
        TableColumnDef(
            label: 'receipt.col_receipt_number'.tr,
            flex: 1.6,
            cellBuilder: (r, _) => _copyCell(r.receiptNumber)),
        TableColumnDef(
            label: 'receipt.col_customer_name'.tr,
            flex: 1.8,
            cellBuilder: (r, _) => TableCells.avatarName(
                name: _orDash(r.customer.user.name),
                avatar: AppAvatar(
                    name: r.customer.user.name,
                    semanticLabel: r.customer.user.name,
                    size: 36))),
        TableColumnDef(
            label: 'receipt.field_amount'.tr,
            cellBuilder: (r, _) => TableCells.text(_orDash(r.amount))),
        TableColumnDef(
            label: 'receipt.col_type'.tr,
            flex: 1.6,
            cellBuilder: (r, _) => TableCells.widget(_typeBadge(r))),
        TableColumnDef(
            label: 'receipt.col_status'.tr,
            cellBuilder: (r, _) => TableCells.widget(_status(r))),
        TableColumnDef(
            label: 'receipt.col_payment_reference'.tr,
            flex: 1.6,
            cellBuilder: (r, _) => _copyCell(r.paymentReference)),
        TableColumnDef(
            label: 'receipt.col_action'.tr,
            flex: 1.6,
            cellBuilder: (r, _) => Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _actionButtons(r)))),
      ];
}
