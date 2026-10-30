import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import '../../domain/general_payment_type.dart';
import '../../domain/models/general_payment.dart';
import '../state/general_payment_list_controller.dart';

String _tr(String key, [Map<String, String> params = const {}]) =>
    'general_payments.$key'.trParams(params);
String _text(String? value) =>
    value == null || value.trim().isEmpty ? '—' : value;

String generalPaymentMoney(String currency, double value) =>
    '${currency.isEmpty ? '' : '$currency '}${AmountHelper.formatAmount(value)}';

String generalPaymentDate(GeneralPayment row) =>
    DateHelper.formatYearMonthDay(row.paymentDate);

/// Translated entry type ("Loan repayment" for a repaid loan); a type this
/// app does not know is shown as sent.
String generalPaymentTypeLabel(GeneralPayment row) =>
    row.loan == GeneralPaymentLoan.repaid
        ? GeneralPaymentLoan.repaid.labelKey.tr
        : row.type?.labelKey.tr ?? _text(row.typeLabel ?? row.typeCode);

/// Translated status; unknown codes are shown as sent.
String generalPaymentStatusLabel(GeneralPayment row) =>
    _statusOf(row.status).$1;

(String, AppBadgeTone) _statusOf(String code) => switch (code) {
      'SUCC' || 'SUCCESS' || 'PAID' => (
          _tr('status_success'),
          AppBadgeTone.success
        ),
      'PEND' || 'PENDING' || 'WAIT' => (
          _tr('status_pending'),
          AppBadgeTone.warning
        ),
      'FAIL' || 'FAILED' || 'REJ' || 'CANCELLED' => (
          _tr('status_failed'),
          AppBadgeTone.danger
        ),
      '' => ('—', AppBadgeTone.neutral),
      _ => (code, AppBadgeTone.neutral),
    };

/// Entry type chip, coloured as on the web: Expense amber, Income green,
/// Loan blue; Asset and unknown types grey.
Widget generalPaymentTypeBadge(GeneralPayment row) => AppBadge(
    label: generalPaymentTypeLabel(row),
    tone: switch (row.type) {
      GeneralPaymentType.expense => AppBadgeTone.warning,
      GeneralPaymentType.income => AppBadgeTone.success,
      GeneralPaymentType.loan => AppBadgeTone.info,
      GeneralPaymentType.asset || null => AppBadgeTone.neutral,
    });

Widget generalPaymentStatusBadge(GeneralPayment row) {
  final (label, tone) = _statusOf(row.status);
  return AppBadge(label: label, tone: tone);
}

/// "134 entries", or "7 of 134 entries" while filtered.
String generalPaymentCountLabel(GeneralPaymentListController list) =>
    list.hasActiveFilters
        ? _tr('count_filtered',
            {'count': '${list.matchCount}', 'total': '${list.totalCount}'})
        : _tr('count', {'count': '${list.matchCount}'});

/// The web's columns: Reference number, Entry type, Payment date, Category,
/// Debit A/c, Credit A/c, Amount and Status, then View.
List<TableColumnDef<GeneralPayment>> generalPaymentColumns(String currency,
        {required ValueChanged<GeneralPayment> onView}) =>
    [
      TableColumnDef(
          label: _tr('col_reference'),
          flex: 1.1,
          // Plain, not selectable: selecting text would take the tap that
          // opens the row (the dialog shows the number again).
          cellBuilder: (r, _) =>
              TableCells.text(r.referenceNumber, weight: FontWeight.w600)),
      TableColumnDef(
          label: _tr('col_entry_type'),
          // Room for "Loan repayment" on one line.
          flex: 1.2,
          cellBuilder: (r, _) => TableCells.widget(generalPaymentTypeBadge(r))),
      TableColumnDef(
          label: _tr('col_payment_date'),
          flex: .9,
          cellBuilder: (r, _) => TableCells.text(generalPaymentDate(r))),
      TableColumnDef(
          label: _tr('col_category'),
          flex: 1.2,
          cellBuilder: (r, _) => TableCells.text(_text(r.category))),
      TableColumnDef(
          label: _tr('col_debit_account'),
          flex: 1.3,
          cellBuilder: (r, _) => TableCells.text(_text(r.debitAccount))),
      TableColumnDef(
          label: _tr('col_credit_account'),
          flex: 1.3,
          cellBuilder: (r, _) => TableCells.text(_text(r.creditAccount))),
      TableColumnDef(
          label: _tr('col_amount'),
          align: TextAlign.right,
          cellBuilder: (r, _) => TableCells.text(
              generalPaymentMoney(currency, r.amount),
              weight: FontWeight.w700,
              align: TextAlign.right)),
      TableColumnDef(
          label: _tr('col_status'),
          flex: .8,
          cellBuilder: (r, _) =>
              TableCells.widget(generalPaymentStatusBadge(r))),
      TableColumnDef(
          label: 'list.view'.tr,
          flex: .8,
          cellBuilder: (r, _) => TableCells.action(
              label: 'list.view'.tr,
              icon: Icons.visibility_outlined,
              onPressed: () => onView(r))),
    ];

/// One entry on narrow screens.
class GeneralPaymentCard extends StatelessWidget {
  const GeneralPaymentCard(
      {super.key,
      required this.row,
      required this.currency,
      required this.onView});
  final GeneralPayment row;
  final String currency;
  final ValueChanged<GeneralPayment> onView;

  @override
  Widget build(BuildContext context) => AppListCard(
      title: row.referenceNumber,
      subtitle: '${generalPaymentDate(row)} · ${_text(row.category)}',
      trailing: generalPaymentTypeBadge(row),
      actionLabel: 'list.view'.tr,
      actionIcon: Icons.visibility_outlined,
      onAction: () => onView(row),
      onTap: () => onView(row),
      body: InfoGrid(minColumnWidth: 130, maxColumns: 2, children: [
        InfoRow(
            label: _tr('col_amount'),
            value: generalPaymentMoney(currency, row.amount)),
        InfoRow(
            label: _tr('col_status'), value: generalPaymentStatusLabel(row)),
        InfoRow(
            label: _tr('col_debit_account'), value: _text(row.debitAccount)),
        InfoRow(
            label: _tr('col_credit_account'), value: _text(row.creditAccount)),
      ]));
}
