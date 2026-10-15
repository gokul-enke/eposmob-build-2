import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'customer_ledger_labels.dart';

class CustomerLedgerRows {
  CustomerLedgerRows({required this.onCopy, required this.onView});
  final void Function(String) onCopy;
  final void Function(ListTransaction) onView;
  Widget _typeBadge(ListTransaction r) => AppBadge(
      label: ledgerTypeLabel(r.type),
      tone: switch (r.type?.toLowerCase()) {
        'credit' => AppBadgeTone.success,
        'debit' => AppBadgeTone.danger,
        _ => AppBadgeTone.neutral
      });
  Widget _statusBadge(ListTransaction r) => AppBadge(
      label: ledgerStatusLabel(r.status),
      tone: switch (r.status?.toUpperCase()) {
        'SUCC' || 'SUCCESS' => AppBadgeTone.success,
        'FAIL' || 'FAILED' => AppBadgeTone.danger,
        'INIT' || 'INITIATED' => AppBadgeTone.warning,
        _ => AppBadgeTone.neutral
      });
  String _money(ListTransaction r) =>
      '${r.currency ?? ''} ${double.parse(r.amount!).toStringAsFixed(3)}'
          .trim();

  /// Blank values show as a dash, as in the other list columns.
  static String _orDash(String? value) =>
      value == null || value.trim().isEmpty ? '—' : value;

  Widget? _copyButton(ListTransaction r) => r.referenceId?.isNotEmpty == true
      ? IconButton(
          tooltip: 'party_accounts.ref_copied'.tr,
          icon: const Icon(Icons.copy_outlined, size: 16),
          onPressed: () => onCopy(r.referenceId!),
        )
      : null;

  Widget _ref(ListTransaction r) {
    final copy = _copyButton(r);
    return Row(children: [
      Expanded(child: TableCells.text(_orDash(r.referenceId))),
      if (copy != null) copy,
    ]);
  }

  Widget card(ListTransaction r, int index) => AppListCard(
        leading: AppAvatar(
            name: r.customerName ?? '',
            semanticLabel: r.customerName ?? 'party_accounts.no_name'.tr,
            size: 42),
        title: r.customerName ?? 'party_accounts.no_name'.tr,
        subtitle: '#$index · ${_orDash(r.date)}',
        trailing: _statusBadge(r),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppMetricStrip(metrics: [
              AppMetric(
                  icon: Icons.payments_outlined,
                  label: 'party_accounts.amount'.tr,
                  value: _money(r)),
              AppMetric(
                  icon: Icons.swap_vert,
                  label: 'party_accounts.type'.tr,
                  value: ledgerTypeLabel(r.type)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            InfoRow(
                icon: Icons.tag,
                label: 'party_accounts.reference_id'.tr,
                value: _orDash(r.referenceId),
                trailing: _copyButton(r)),
          ],
        ),
        actionLabel: 'list.view'.tr,
        actionIcon: Icons.visibility_outlined,
        onAction: () => onView(r),
      );

  List<TableColumnDef<ListTransaction>> get columns => [
        TableColumnDef(
            label: 'party_accounts.col_no'.tr,
            flex: .5,
            align: TextAlign.center,
            cellBuilder: (_, i) => TableCells.number(i)),
        TableColumnDef(
            label: 'party_accounts.col_name'.tr,
            flex: 2,
            cellBuilder: (r, _) => TableCells.avatarName(
                name: r.customerName ?? 'party_accounts.no_name'.tr,
                avatar: AppAvatar(
                    name: r.customerName ?? '',
                    semanticLabel:
                        r.customerName ?? 'party_accounts.no_name'.tr,
                    size: 36))),
        TableColumnDef(
            label: 'party_accounts.date'.tr,
            cellBuilder: (r, _) => TableCells.text(_orDash(r.date))),
        TableColumnDef(
            label: 'party_accounts.amount'.tr,
            flex: 1.2,
            cellBuilder: (r, _) => TableCells.text(_money(r))),
        TableColumnDef(
            label: 'party_accounts.reference_id'.tr,
            flex: 1.8,
            cellBuilder: (r, _) => _ref(r)),
        TableColumnDef(
            label: 'party_accounts.type'.tr,
            cellBuilder: (r, _) => TableCells.widget(_typeBadge(r))),
        TableColumnDef(
            label: 'party_accounts.status'.tr,
            cellBuilder: (r, _) => TableCells.widget(_statusBadge(r))),
        TableColumnDef(
            label: 'party_accounts.col_action'.tr,
            cellBuilder: (r, _) => TableCells.action(
                label: 'list.view'.tr,
                icon: Icons.visibility_outlined,
                onPressed: () => onView(r))),
      ];
}
