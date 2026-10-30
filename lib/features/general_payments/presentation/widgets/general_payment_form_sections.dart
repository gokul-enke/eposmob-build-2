import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import '../../../reports/presentation/widgets/report_error_bar.dart';
import '../../domain/general_payment_entry.dart';
import '../../domain/general_payment_type.dart';
import '../state/general_payment_form_controller.dart';
import 'general_payment_journal_preview.dart';
import 'general_payment_picker.dart';

String _tr(String key) => 'general_payments.$key'.tr;

/// Labels that follow the kind of entry, in accounting terms: the debit is
/// the account that receives the value, the credit the one that gives it.
typedef GeneralPaymentLabels = ({
  String date,
  String category,
  String description,
  String descriptionHint,
  String debit,
  String credit,
});

GeneralPaymentLabels generalPaymentLabels(
    GeneralPaymentType type, GeneralPaymentLoan? loan) {
  final (date, category, description, hint, debit, credit) = switch (type) {
    GeneralPaymentType.expense => (
        'date_payment',
        'category_expense',
        'field_description',
        'hint_description',
        'debit_expense',
        'credit_paid_from'
      ),
    GeneralPaymentType.asset => (
        'date_purchase',
        'category_asset',
        'field_description',
        'hint_description_asset',
        'debit_asset',
        'credit_paid_from'
      ),
    GeneralPaymentType.income => (
        'date_received',
        'category_income',
        'field_description',
        'hint_description_income',
        'debit_received_in',
        'credit_income'
      ),
    GeneralPaymentType.loan when loan == GeneralPaymentLoan.repaid => (
        'date_repayment',
        'category_loan',
        'field_lender',
        'hint_lender',
        'debit_loan',
        'credit_paid_from'
      ),
    GeneralPaymentType.loan => (
        'date_disbursement',
        'category_loan',
        'field_lender',
        'hint_lender',
        'debit_received_in',
        'credit_loan'
      ),
  };
  return (
    date: _tr(date),
    category: _tr(category),
    description: _tr(description),
    descriptionHint: _tr(hint),
    debit: _tr(debit),
    credit: _tr(credit),
  );
}

/// The New Entry form's sections: what kind of entry, its details, and the
/// accounts and amount with the journal it will post. Reads the controller's
/// values and calls its methods; no provider access.
class GeneralPaymentFormSections extends StatelessWidget {
  const GeneralPaymentFormSections({
    super.key,
    required this.form,
    required this.currency,
    required this.onPickDate,
  });

  static const amountKey = ValueKey('general-payment-amount');

  final GeneralPaymentFormController form;
  final String currency;
  final VoidCallback onPickDate;

  Widget _choice(
          {required Key key,
          required String label,
          required List<GeneralPaymentOption> options,
          required String? value,
          required bool loading,
          required ValueChanged<String?> onChanged}) =>
      GeneralPaymentPicker(
          fieldKey: key,
          label: label,
          options: options,
          value: value,
          loading: loading,
          onChanged: onChanged);

  @override
  Widget build(BuildContext context) {
    final labels = generalPaymentLabels(form.type, form.loan);
    const gap = SizedBox(height: AppSpacing.lg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (form.optionsFailed) ...[
          ReportErrorBar(
              message: _tr('options_unavailable'),
              retryLabel: _tr('retry'),
              onRetry: form.retryOptions,
              retryEnabled: !form.loadingAccounts && !form.loadingCategories),
          gap,
        ],
        SectionCard(
          title: _tr('section_type'),
          subtitle: _tr('section_type_hint'),
          icon: Icons.swap_horiz_rounded,
          child: ResponsiveFieldGrid(maxColumns: 2, children: [
            AppRadioGroupField<GeneralPaymentType>(
                key: const ValueKey('general-payment-type'),
                label: _tr('filter_entry_type'),
                required: true,
                value: form.type,
                options: GeneralPaymentType.values,
                optionLabel: (type) => type.labelKey.tr,
                onChanged: form.busy ? null : form.setType),
            if (form.type == GeneralPaymentType.loan)
              AppRadioGroupField<GeneralPaymentLoan>(
                  key: const ValueKey('general-payment-loan'),
                  label: _tr('loan_transaction'),
                  required: true,
                  value: form.loan,
                  options: GeneralPaymentLoan.values,
                  optionLabel: (loan) => loan.labelKey.tr,
                  onChanged: form.busy ? null : form.setLoan),
          ]),
        ),
        gap,
        SectionCard(
          title: _tr('section_details'),
          icon: Icons.description_outlined,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ResponsiveFieldGrid(maxColumns: 2, children: [
              AppTextField(
                  fieldKey: const ValueKey('general-payment-reference'),
                  controller: form.reference,
                  label: _tr('field_reference'),
                  hint: _tr('reference_on_save'),
                  icon: Icons.tag_rounded,
                  readOnly: true),
              AppTextField(
                  fieldKey: const ValueKey('general-payment-date'),
                  controller: form.dateText,
                  label: labels.date,
                  icon: Icons.calendar_today_outlined,
                  required: true,
                  readOnly: true,
                  onTap: onPickDate),
              _choice(
                  key: const ValueKey('general-payment-category'),
                  label: labels.category,
                  options: form.categories,
                  value: form.categoryId,
                  loading: form.loadingCategories,
                  onChanged: form.setCategory),
              AppTextField(
                  fieldKey: const ValueKey('general-payment-description'),
                  controller: form.description,
                  label: labels.description,
                  hint: labels.descriptionHint,
                  textInputAction: TextInputAction.next),
              if (form.type == GeneralPaymentType.asset)
                AppTextField(
                    fieldKey: const ValueKey('general-payment-useful-life'),
                    controller: form.usefulLife,
                    label: _tr('field_useful_life'),
                    hint: _tr('hint_useful_life'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (text) =>
                        generalPaymentUsefulLifeError(text)?.tr,
                    textInputAction: TextInputAction.next),
            ]),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
                fieldKey: const ValueKey('general-payment-notes'),
                controller: form.notes,
                label: _tr('col_notes'),
                hint: _tr('hint_notes'),
                keyboardType: TextInputType.multiline,
                maxLines: 3),
          ]),
        ),
        gap,
        SectionCard(
          title: _tr('section_accounts'),
          subtitle: _tr('section_accounts_hint'),
          icon: Icons.account_balance_outlined,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ResponsiveFieldGrid(maxColumns: 2, children: [
              _choice(
                  key: const ValueKey('general-payment-debit'),
                  label: labels.debit,
                  options: form.debitOptions,
                  value: form.debitAccountId,
                  loading: form.loadingAccounts,
                  onChanged: form.setDebitAccount),
              _choice(
                  key: const ValueKey('general-payment-credit'),
                  label: labels.credit,
                  options: form.creditOptions,
                  value: form.creditAccountId,
                  loading: form.loadingAccounts,
                  onChanged: form.setCreditAccount),
              AppTextField(
                  fieldKey: amountKey,
                  controller: form.amount,
                  label: currency.isEmpty
                      ? _tr('col_amount')
                      : '${_tr('col_amount')} ($currency)',
                  hint: '0.00',
                  required: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}$'))
                  ],
                  validator: (text) => generalPaymentAmountError(text)?.tr,
                  // On to the payment method; saving is the Create button.
                  textInputAction: TextInputAction.next),
              _choice(
                  key: const ValueKey('general-payment-method'),
                  label: _tr('col_payment_method'),
                  options: form.paymentMethods,
                  value: form.paymentMethodId,
                  loading: form.loadingPaymentMethods,
                  onChanged: form.setPaymentMethod),
            ]),
            const SizedBox(height: AppSpacing.lg),
            GeneralPaymentJournalPreview(form: form, currency: currency),
          ]),
        ),
      ],
    );
  }
}
