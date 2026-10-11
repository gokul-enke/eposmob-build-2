import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/models/transaction_model.dart';

class SupplierLedgerRows {
  SupplierLedgerRows({required this.onCopy, required this.onView});
  final ValueChanged<TransactionModel> onCopy, onView;
  static String _orDash(String? value) =>
      value == null || value.trim().isEmpty ? '—' : value;

  static Widget _text(String? value) => TableCells.text(_orDash(value));

  Widget _statusBadge(String status) {
    final tone = switch (status.toUpperCase()) {
      'SUCC' || 'SUCCESS' => AppBadgeTone.success,
      'INIT' || 'INITIATED' => AppBadgeTone.warning,
      'FAIL' || 'FAILED' => AppBadgeTone.danger,
      _ => AppBadgeTone.neutral,
    };
    return AppBadge(label: UiCodeLabels.status(status), tone: tone);
  }

  Widget _typeBadge(String type) => AppBadge(
        label: UiCodeLabels.documentKind(type),
        tone: type.toLowerCase() == 'credit'
            ? AppBadgeTone.success
            : AppBadgeTone.danger,
      );

  bool _canCopyReference(TransactionModel tx) =>
      tx.reference.isNotEmpty && tx.reference != 'N/A';

  Widget _copyReferenceButton(TransactionModel tx) => IconButton(
        tooltip: 'supplier_transactions.copy_reference'.tr,
        icon: const Icon(Icons.copy_outlined, size: 16),
        color: AppColors.muted,
        onPressed: () => onCopy(tx),
      );

  Widget _reference(TransactionModel tx) => Row(children: [
        Expanded(
          child: Tooltip(message: tx.reference, child: _text(tx.reference)),
        ),
        if (_canCopyReference(tx)) _copyReferenceButton(tx),
      ]);

  Widget card(TransactionModel tx, int number) => AppListCard(
        leading: AppAvatar(
          name: tx.supplier.user.name,
          semanticLabel: tx.supplier.user.name,
          size: 42,
        ),
        title: _orDash(tx.supplier.user.name),
        subtitle: '${'supplier_transactions.col_si_no'.tr}: ${tx.siNo}',
        trailing: _statusBadge(tx.status),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppMetricStrip(metrics: [
              AppMetric(
                icon: Icons.payments_outlined,
                label: 'supplier_transactions.col_amount'.tr,
                value: '${tx.currency} ${tx.amount}',
              ),
              AppMetric(
                icon: Icons.calendar_today_outlined,
                label: 'supplier_transactions.col_date'.tr,
                value: _orDash(DateHelper.formatISODate(tx.date)),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            InfoRow(
              icon: Icons.swap_vert_rounded,
              label: 'supplier_transactions.type'.tr,
              value: _orDash(UiCodeLabels.documentKind(tx.type)),
              valueColor: tx.type.toLowerCase() == 'credit'
                  ? AppColors.green
                  : AppColors.red,
            ),
            InfoRow(
              icon: Icons.receipt_long_outlined,
              label: 'supplier_transactions.col_transaction_type'.tr,
              value: _orDash(UiCodeLabels.documentKind(tx.transactionType)),
            ),
            InfoRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'supplier_transactions.col_payment_mode'.tr,
              value: _orDash(UiCodeLabels.payment(tx.paymentMode)),
            ),
            InfoRow(
              icon: Icons.tag_rounded,
              label: 'supplier_transactions.col_reference'.tr,
              value: _orDash(tx.reference),
              trailing: _canCopyReference(tx) ? _copyReferenceButton(tx) : null,
            ),
          ],
        ),
        actionLabel: 'list.view'.tr,
        actionIcon: Icons.visibility_outlined,
        onAction: () => onView(tx),
      );

  List<TableColumnDef<TransactionModel>> columns() => [
        TableColumnDef(
            label: 'supplier_transactions.col_si_no'.tr,
            flex: .5,
            cellBuilder: (tx, _) => _text('${tx.siNo}')),
        TableColumnDef(
            label: 'supplier_transactions.supplier'.tr,
            flex: 2,
            cellBuilder: (tx, _) => TableCells.avatarName(
                  name: _orDash(tx.supplier.user.name),
                  avatar: AppAvatar(
                    name: tx.supplier.user.name,
                    semanticLabel: tx.supplier.user.name,
                    size: 36,
                  ),
                )),
        TableColumnDef(
            label: 'supplier_transactions.col_date'.tr,
            flex: 1.2,
            cellBuilder: (tx, _) => _text(DateHelper.formatISODate(tx.date))),
        TableColumnDef(
            label: 'supplier_transactions.type'.tr,
            cellBuilder: (tx, _) => TableCells.widget(_typeBadge(tx.type))),
        TableColumnDef(
            label: 'supplier_transactions.col_transaction_type'.tr,
            flex: 1.3,
            cellBuilder: (tx, _) =>
                _text(UiCodeLabels.documentKind(tx.transactionType))),
        TableColumnDef(
            label: 'supplier_transactions.col_payment_mode'.tr,
            flex: 1.2,
            cellBuilder: (tx, _) =>
                _text(UiCodeLabels.payment(tx.paymentMode))),
        TableColumnDef(
            label: 'supplier_transactions.col_amount'.tr,
            flex: 1.3,
            cellBuilder: (tx, _) => _text('${tx.currency} ${tx.amount}')),
        TableColumnDef(
            label: 'supplier_transactions.col_reference'.tr,
            flex: 1.6,
            cellBuilder: (tx, _) => _reference(tx)),
        TableColumnDef(
            label: 'supplier_transactions.status'.tr,
            flex: 1.1,
            cellBuilder: (tx, _) => TableCells.widget(_statusBadge(tx.status))),
        TableColumnDef(
            label: 'supplier_transactions.col_action'.tr,
            flex: 1.2,
            cellBuilder: (tx, _) => TableCells.action(
                  label: 'list.view'.tr,
                  icon: Icons.visibility_outlined,
                  onPressed: () => onView(tx),
                )),
      ];
}
