import 'package:flutter/material.dart';
import '../state/general_payment_form_controller.dart';
import 'general_payment_journal.dart';
import 'general_payment_results.dart' show generalPaymentMoney;

/// The journal the New Entry will post, updating as its accounts and amount
/// are filled in.
class GeneralPaymentJournalPreview extends StatelessWidget {
  const GeneralPaymentJournalPreview(
      {super.key, required this.form, required this.currency});

  final GeneralPaymentFormController form;
  final String currency;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([form, form.amount]),
      builder: (context, _) {
        final amount = form.amountValue;
        return GeneralPaymentJournal(
            key: const ValueKey('general-payment-journal'),
            debit: form.debitAccountName,
            credit: form.creditAccountName,
            amount:
                amount == null ? '—' : generalPaymentMoney(currency, amount));
      });
}
