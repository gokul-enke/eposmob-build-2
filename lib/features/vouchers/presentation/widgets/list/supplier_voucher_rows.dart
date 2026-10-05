import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import '../../../domain/models/supplier_voucher.dart';

class SupplierVoucherRows {
  SupplierVoucherRows(
      {required this.currency,
      required this.onView,
      required this.onPrint,
      required this.onMore,
      required this.onCopy});
  final String currency;
  final ValueChanged<SupplierVoucher> onView, onPrint, onMore, onCopy;
  static String _orDash(String? value) =>
      value == null || value.trim().isEmpty ? '—' : value;

  static Widget _text(String? value) => TableCells.text(_orDash(value));

  Widget _copyButton(SupplierVoucher voucher) => IconButton(
        icon: const Icon(Icons.copy_outlined, size: 16),
        color: AppColors.muted,
        tooltip: 'supplier_voucher.col_voucher_number'.tr,
        onPressed: () => onCopy(voucher),
      );

  Widget _reference(SupplierVoucher voucher) => Row(children: [
        Expanded(child: _text(voucher.voucherNumber)),
        _copyButton(voucher),
      ]);

  Widget _actions(SupplierVoucher voucher) =>
      Wrap(spacing: 6, runSpacing: 6, children: [
        _action(
            Icons.visibility_outlined, 'list.view'.tr, () => onView(voucher)),
        _action(
            Icons.print_outlined, 'general.print'.tr, () => onPrint(voucher)),
        _action(Icons.share_outlined, 'supplier_voucher.share_action'.tr,
            () => onMore(voucher)),
      ]);

  Widget _action(IconData icon, String tooltip, VoidCallback onPressed) =>
      AppSquareIconButton(
        icon: icon,
        tooltip: tooltip,
        onPressed: onPressed,
        size: AppSizes.compactControl,
        iconSize: 18,
        radius: AppRadius.control,
        foreground: AppColors.primary,
      );

  String _amount(SupplierVoucher voucher) => '$currency ${voucher.amount}';

  Widget _statusBadge(String status) {
    final tone = switch (status.toUpperCase()) {
      'PAID' => AppBadgeTone.success,
      'PENDING' => AppBadgeTone.warning,
      'CANCELLED' => AppBadgeTone.danger,
      _ => AppBadgeTone.neutral,
    };
    return AppBadge(label: UiCodeLabels.status(status), tone: tone);
  }

  Widget card(SupplierVoucher voucher, int number) => AppListCard(
        leading: AppAvatar(
          name: voucher.supplier.name,
          semanticLabel: voucher.supplier.name,
          size: 42,
        ),
        title: _orDash(voucher.supplier.name),
        subtitle: UiCodeLabels.voucherType(voucher.type),
        trailing: _statusBadge(voucher.status),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppMetricStrip(metrics: [
              AppMetric(
                icon: Icons.payments_outlined,
                label: 'supplier_voucher.col_paid_amount'.tr,
                value: _amount(voucher),
              ),
              AppMetric(
                icon: Icons.account_balance_wallet_outlined,
                label: 'supplier_voucher.col_payment_method'.tr,
                value: _orDash(UiCodeLabels.payment(voucher.paymentMethod)),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            InfoRow(
              icon: Icons.receipt_long_outlined,
              label: 'supplier_voucher.col_voucher_number'.tr,
              value: _orDash(voucher.voucherNumber),
              trailing: _copyButton(voucher),
            ),
            InfoRow(
              icon: Icons.event_outlined,
              label: 'supplier_voucher.col_voucher_date'.tr,
              value: _orDash(voucher.voucherDate),
            ),
            InfoRow(
              icon: Icons.event_available_outlined,
              label: 'supplier_voucher.col_due_date'.tr,
              value: _orDash(voucher.dueDate),
            ),
            const SizedBox(height: AppSpacing.sm),
            _actions(voucher),
          ],
        ),
      );

  List<TableColumnDef<SupplierVoucher>> columns() => [
        TableColumnDef(
            label: 'supplier_voucher.col_voucher_number'.tr,
            flex: 1.6,
            cellBuilder: (v, _) => _reference(v)),
        TableColumnDef(
            label: 'supplier_voucher.col_supplier_name'.tr,
            flex: 2,
            cellBuilder: (v, _) => TableCells.avatarName(
                  name: _orDash(v.supplier.name),
                  avatar: AppAvatar(
                    name: v.supplier.name,
                    semanticLabel: v.supplier.name,
                    size: 36,
                  ),
                )),
        TableColumnDef(
            label: 'supplier_voucher.col_type'.tr,
            cellBuilder: (v, _) => _text(UiCodeLabels.voucherType(v.type))),
        TableColumnDef(
            label: 'supplier_voucher.col_voucher_date'.tr,
            flex: 1.3,
            cellBuilder: (v, _) => _text(v.voucherDate)),
        TableColumnDef(
            label: 'supplier_voucher.col_due_date'.tr,
            flex: 1.3,
            cellBuilder: (v, _) => _text(v.dueDate)),
        TableColumnDef(
            label: 'supplier_voucher.col_payment_method'.tr,
            flex: 1.2,
            cellBuilder: (v, _) =>
                _text(UiCodeLabels.payment(v.paymentMethod))),
        TableColumnDef(
            label: 'supplier_voucher.col_paid_amount'.tr,
            flex: 1.4,
            cellBuilder: (v, _) => _text(_amount(v))),
        TableColumnDef(
            label: 'supplier_voucher.col_status'.tr,
            cellBuilder: (v, _) => TableCells.widget(_statusBadge(v.status))),
        TableColumnDef(
            label: 'supplier_voucher.col_action'.tr,
            flex: 1.8,
            cellBuilder: (v, _) => TableCells.widget(_actions(v))),
      ];
}
