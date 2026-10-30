import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../domain/models/general_payment.dart';
import 'general_payment_journal.dart';
import 'general_payment_results.dart';

String _tr(String key) => 'general_payments.$key'.tr;
String _text(String? value) =>
    value == null || value.trim().isEmpty ? '—' : value;

/// Every detail of one entry (View): its amount and status, the journal it
/// posted and the rest of its fields. Opens over the list, so the list keeps
/// its filters and page.
Future<void> showGeneralPaymentDetails(
        BuildContext context, GeneralPayment row, String currency) =>
    AppDialog.show<void>(context,
        title: row.referenceNumber,
        subtitle:
            '${generalPaymentTypeLabel(row)} · ${generalPaymentDate(row)}',
        maxWidth: 560,
        child: GeneralPaymentDetails(row: row, currency: currency));

class GeneralPaymentDetails extends StatelessWidget {
  const GeneralPaymentDetails(
      {super.key, required this.row, required this.currency});

  final GeneralPayment row;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final money = generalPaymentMoney(currency, row.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(
              child: Text(money,
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 18))),
          generalPaymentStatusBadge(row),
        ]),
        const SizedBox(height: AppSpacing.md),
        GeneralPaymentJournal(
            key: const ValueKey('general-payment-details-journal'),
            // A saved entry missing an account shows "—", not the form's
            // "Choose an account".
            debit: _text(row.debitAccount),
            credit: _text(row.creditAccount),
            amount: money),
        const SizedBox(height: AppSpacing.md),
        InfoGrid(minColumnWidth: 200, maxColumns: 2, children: [
          InfoRow(
              label: _tr('col_entry_type'),
              value: generalPaymentTypeLabel(row)),
          InfoRow(
              label: _tr('col_payment_date'), value: generalPaymentDate(row)),
          InfoRow(label: _tr('col_category'), value: _text(row.category)),
          InfoRow(
              label: _tr('col_payment_method'),
              value: _text(row.paymentMethod)),
          if (row.usefulLifeYears case final years?)
            InfoRow(label: _tr('field_useful_life'), value: '$years'),
          InfoRow(label: _tr('col_description'), value: _text(row.description)),
          InfoRow(label: _tr('col_notes'), value: _text(row.notes)),
          InfoRow(label: _tr('col_created_by'), value: _text(row.createdBy)),
        ]),
      ],
    );
  }
}
