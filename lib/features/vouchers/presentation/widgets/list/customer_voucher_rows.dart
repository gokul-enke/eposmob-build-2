import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import '../../../domain/models/customer_voucher.dart';

class CustomerVoucherRows {
  CustomerVoucherRows(
      {required this.currency,
      required this.onView,
      required this.onPrint,
      required this.onMore,
      required this.onCopy});
  final String currency;
  final ValueChanged<CustomerVoucher> onView, onPrint, onMore, onCopy;

  /// Blank values show as a dash, as in the other list columns.
  static String _orDash(String value) => value.trim().isEmpty ? '—' : value;

  Widget _statusBadge(String status) => AppBadge(
        label: UiCodeLabels.status(status),
        tone: switch (status.toLowerCase()) {
          'paid' => AppBadgeTone.success,
          'pending' => AppBadgeTone.warning,
          'cancelled' => AppBadgeTone.danger,
          _ => AppBadgeTone.neutral,
        },
      );

  Widget _copyButton(CustomerVoucher voucher) => IconButton(
      icon: const Icon(Icons.copy_outlined, size: 16),
      tooltip: 'customer_voucher.copy_voucher_number'.tr,
      onPressed: () => onCopy(voucher));
  Widget _referenceCell(CustomerVoucher voucher) => Row(children: [
        Expanded(child: TableCells.text(_orDash(voucher.voucherNumber))),
        _copyButton(voucher),
      ]);

  /// View, Print and More — the same in the table and on cards.
  Widget _actions(CustomerVoucher voucher) => Wrap(
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
                onPressed: () => onView(voucher)),
            _iconAction(Icons.print_outlined, 'general.print'.tr,
                () => onPrint(voucher)),
            _iconAction(
                Icons.more_vert,
                'customer_voucher.more_options_title'.tr,
                () => onMore(voucher)),
          ]);

  Widget _iconAction(IconData icon, String tooltip, VoidCallback onPressed) =>
      AppSquareIconButton(
          icon: icon,
          tooltip: tooltip,
          onPressed: onPressed,
          size: AppSizes.compactControl,
          iconSize: 18,
          radius: AppRadius.tile,
          foreground: AppColors.primary);

  String _amount(CustomerVoucher voucher) => '$currency ${voucher.amount}';

  Widget card(CustomerVoucher voucher, int number) => AppListCard(
        leading: AppAvatar(
            name: voucher.customer.user.name,
            semanticLabel: voucher.customer.user.name,
            size: 42),
        title: _orDash(voucher.customer.user.name),
        subtitle: '#$number',
        trailing: _statusBadge(voucher.status),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppMetricStrip(metrics: [
              AppMetric(
                  icon: Icons.payments_outlined,
                  label: 'customer_voucher.col_paid_amount'.tr,
                  value: _amount(voucher)),
              AppMetric(
                  icon: Icons.event_outlined,
                  label: 'customer_voucher.col_voucher_date'.tr,
                  value: _orDash(voucher.voucherDate)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            InfoRow(
                icon: Icons.receipt_long_outlined,
                label: 'customer_voucher.col_voucher_number'.tr,
                value: _orDash(voucher.voucherNumber),
                trailing: _copyButton(voucher)),
            InfoRow(
                icon: Icons.swap_vert,
                label: 'customer_voucher.col_type'.tr,
                value: _orDash(UiCodeLabels.voucherType(voucher.type))),
            InfoRow(
                icon: Icons.event_busy_outlined,
                label: 'customer_voucher.col_due_date'.tr,
                value: _orDash(voucher.dueDate)),
            InfoRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'customer_voucher.col_payment_method'.tr,
                value: _orDash(UiCodeLabels.payment(voucher.paymentMethod))),
            const SizedBox(height: AppSpacing.sm),
            _actions(voucher),
          ],
        ),
      );

  List<TableColumnDef<CustomerVoucher>> get columns => [
        TableColumnDef(
            label: 'customer_voucher.col_voucher_number'.tr,
            flex: 1.6,
            cellBuilder: (v, _) => _referenceCell(v)),
        TableColumnDef(
            label: 'customer_voucher.col_customer_name'.tr,
            flex: 2,
            cellBuilder: (v, _) => TableCells.avatarName(
                name: _orDash(v.customer.user.name),
                avatar: AppAvatar(
                    name: v.customer.user.name,
                    semanticLabel: v.customer.user.name,
                    size: 36))),
        TableColumnDef(
            label: 'customer_voucher.col_type'.tr,
            cellBuilder: (v, _) =>
                TableCells.text(_orDash(UiCodeLabels.voucherType(v.type)))),
        TableColumnDef(
            label: 'customer_voucher.col_voucher_date'.tr,
            flex: 1.3,
            cellBuilder: (v, _) => TableCells.text(_orDash(v.voucherDate))),
        TableColumnDef(
            label: 'customer_voucher.col_due_date'.tr,
            flex: 1.3,
            cellBuilder: (v, _) => TableCells.text(_orDash(v.dueDate))),
        TableColumnDef(
            label: 'customer_voucher.col_payment_method'.tr,
            flex: 1.2,
            cellBuilder: (v, _) => TableCells.text(
                _orDash(UiCodeLabels.payment(v.paymentMethod)))),
        TableColumnDef(
            label: 'customer_voucher.col_paid_amount'.tr,
            flex: 1.4,
            cellBuilder: (v, _) => TableCells.text(_amount(v))),
        TableColumnDef(
            label: 'customer_voucher.col_status'.tr,
            cellBuilder: (v, _) => TableCells.widget(_statusBadge(v.status))),
        TableColumnDef(
            label: 'customer_voucher.col_action'.tr,
            flex: 2.5,
            cellBuilder: (v, _) => TableCells.widget(_actions(v))),
      ];
}
