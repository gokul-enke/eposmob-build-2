import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_filter.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_totals.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_type.dart';
import 'package:pos_machine/features/general_payments/domain/models/general_payment.dart';
import 'package:pos_machine/features/reports/domain/report_period.dart';
import '../../../test_support/app_translations.dart';
import '../support/general_payment_fixtures.dart';

void main() {
  group('GeneralPayment.fromJson', () {
    test('reads a live income row: Debit A/c is the expense account', () {
      final row = GeneralPayment.fromJson({
        ...paymentJson(176,
            type: 'INCOME',
            date: '2026-09-04',
            amount: 2000,
            category: '8491',
            categoryLabel: 'Manufacturing Income',
            debitId: 12,
            debit: 'Bank Account',
            creditId: 375,
            credit: 'Direct Income Account'),
        'payment_method_label': 'CARD',
        'description': 'Scrap sold',
      });
      expect(row.id, 176);
      expect(row.referenceNumber, 'INC00176');
      expect(row.type, GeneralPaymentType.income);
      expect(row.paymentDate, DateTime(2026, 9, 4));
      expect(row.categoryId, '8491');
      expect(row.category, 'Manufacturing Income');
      expect((row.debitAccountId, row.debitAccount), ('12', 'Bank Account'));
      expect((row.creditAccountId, row.creditAccount),
          ('375', 'Direct Income Account'));
      expect(row.amount, 2000.0);
      expect(row.paymentMethod, 'CARD');
      expect(row.status, 'SUCC');
      expect(row.description, 'Scrap sold');
      expect(row.notes, isNull);
      expect(row.createdBy, 'Admin');
    });

    test('takes numeric strings and falls back to ids for missing names', () {
      final row = GeneralPayment.fromJson({
        ...paymentJson(1, amount: '1,250.50'),
        'category_label': null,
        'expense_account_name': '',
        'payment_method_label': null,
        'status': 'succ',
      });
      expect(row.amount, 1250.5);
      expect(row.category, '8192');
      expect(row.debitAccount, '15');
      expect(row.paymentMethod, '7974');
      expect(row.status, 'SUCC');
      expect(row.usefulLifeYears, isNull);
    });

    test('an asset keeps its useful life', () {
      expect(
          GeneralPayment.fromJson(
                  {...paymentJson(30, type: 'ASSET'), 'useful_life_years': '5'})
              .usefulLifeYears,
          5);
    });

    test('an unknown entry type keeps its code and label', () {
      final row = GeneralPayment.fromJson(
          {...paymentJson(1), 'entry_type': 'grant', 'entry_type_label': 'G'});
      expect(row.type, isNull);
      expect((row.typeCode, row.typeLabel), ('GRANT', 'G'));
    });

    for (final (name, change) in [
      ('reference', {'reference_number': ' '}),
      ('date', {'payment_date': 'soon'}),
      ('amount', {'amount': 'n/a'}),
      ('infinite amount', {'amount': double.infinity}),
    ]) {
      test('rejects a row with a bad $name', () {
        expect(() => GeneralPayment.fromJson({...paymentJson(1), ...change}),
            throwsFormatException);
      });
    }
  });

  test('entry types read API codes in any case', () {
    expect(GeneralPaymentType.fromCode(' loan '), GeneralPaymentType.loan);
    expect(GeneralPaymentType.fromCode('ASSET'), GeneralPaymentType.asset);
    expect(GeneralPaymentType.fromCode('OTHER'), isNull);
    expect(GeneralPaymentType.fromCode(null), isNull);
  });

  test('a loan repayment (its own LOAN_REPAY entry) is a repaid loan', () {
    final repayment = GeneralPayment.fromJson({
      ...paymentJson(189,
          type: 'LOAN_REPAY',
          reference: 'LRP00001',
          amount: 5000,
          debitId: 376,
          debit: 'Loan Account'),
      'entry_type_label': 'Loan Repayment',
    });
    expect(GeneralPaymentType.fromCode('loan_repay'), GeneralPaymentType.loan);
    expect(repayment.type, GeneralPaymentType.loan);
    expect(repayment.loan, GeneralPaymentLoan.repaid);
    expect(payment(1, type: 'LOAN').loan, GeneralPaymentLoan.received);
    expect(payment(1).loan, isNull);
    expect(
        const GeneralPaymentFilter(type: GeneralPaymentType.loan)
            .matches(repayment, DateTime(2026, 10, 30)),
        isTrue,
        reason: 'the Loan filter shows repayments too');
  });

  test('totals add each type separately and skip unknown types', () {
    final totals = GeneralPaymentTotals.of([
      ...mixedPayments(),
      payment(2, amount: 123.45),
      payment(189, type: 'LOAN_REPAY', amount: 5000),
      GeneralPayment.fromJson({...paymentJson(3), 'entry_type': 'GRANT'}),
    ]);
    expect(totals[GeneralPaymentType.expense], closeTo(2173.45, 1e-9));
    expect(totals[GeneralPaymentType.asset], 32800);
    expect(totals[GeneralPaymentType.income], 2000);
    expect(totals[GeneralPaymentType.loan], 7000,
        reason: 'loans and repayments, as the web\'s Total Loan');
    expect(GeneralPaymentTotals.zero[GeneralPaymentType.loan], 0);
  });

  group('GeneralPaymentFilter', () {
    final now = DateTime(2026, 10, 30, 15);
    final rows = mixedPayments();
    List<String> refs(GeneralPaymentFilter filter) => [
          for (final row in rows)
            if (filter.matches(row, now)) row.referenceNumber
        ];

    test('no filter matches every entry and is not active', () {
      expect(refs(GeneralPaymentFilter.none), hasLength(5));
      expect(GeneralPaymentFilter.none.isActive, isFalse);
      expect(const GeneralPaymentFilter(reference: '  ').isActive, isFalse);
    });

    test('reference matches part of the number in any case', () {
      expect(
          refs(const GeneralPaymentFilter(reference: ' inc ')), ['INC00176']);
      expect(refs(const GeneralPaymentFilter(reference: '0017')),
          ['LON00177', 'INC00176', 'EXP00175']);
    });

    test('type, category and accounts match by id', () {
      expect(refs(const GeneralPaymentFilter(type: GeneralPaymentType.expense)),
          ['EXP00184', 'EXP00175']);
      expect(
          refs(const GeneralPaymentFilter(categoryId: '8497')), ['LON00177']);
      expect(
          refs(const GeneralPaymentFilter(debitAccountId: '12')), ['INC00176']);
      expect(refs(const GeneralPaymentFilter(creditAccountId: '12')),
          ['EXP00175']);
      expect(
          refs(const GeneralPaymentFilter(
              type: GeneralPaymentType.income, creditAccountId: '11')),
          isEmpty);
    });

    test('date presets cover whole days on today\'s calendar', () {
      expect(refs(const GeneralPaymentFilter(period: ReportPeriod.thisMonth)),
          ['EXP00184']);
      expect(refs(const GeneralPaymentFilter(period: ReportPeriod.lastMonth)),
          ['LON00177', 'INC00176', 'EXP00175']);
      expect(refs(const GeneralPaymentFilter(period: ReportPeriod.today)),
          isEmpty);
      expect(refs(const GeneralPaymentFilter(period: ReportPeriod.last3Months)),
          hasLength(4));
    });

    test('Last 3 Months never rolls into the month after at month end', () {
      const filter = GeneralPaymentFilter(period: ReportPeriod.last3Months);
      for (final (today, from) in [
        (DateTime(2026, 5, 31), DateTime(2026, 2, 28)),
        (DateTime(2028, 5, 31), DateTime(2028, 2, 29)),
        (DateTime(2026, 7, 31), DateTime(2026, 4, 30)),
        (DateTime(2026, 12, 31), DateTime(2026, 9, 30)),
        (DateTime(2026, 1, 15, 18), DateTime(2025, 10, 15)),
      ]) {
        final range = filter.dateRange(today);
        expect((
          range.from,
          range.to
        ), (
          from,
          DateTime(today.year, today.month, today.day)
        ), reason: '$today');
      }
      expect(
          filter.matches(payment(1, date: '2026-02-28'), DateTime(2026, 5, 31)),
          isTrue);
      expect(
          filter.matches(payment(1, date: '2026-02-27'), DateTime(2026, 5, 31)),
          isFalse);
    });

    test('custom range includes both ends and may be open', () {
      expect(
          refs(GeneralPaymentFilter(
              period: ReportPeriod.custom,
              customFrom: DateTime(2026, 9, 4),
              customTo: DateTime(2026, 10, 3, 9))),
          ['EXP00184', 'LON00177', 'INC00176', 'EXP00175']);
      expect(
          refs(GeneralPaymentFilter(
              period: ReportPeriod.custom, customTo: DateTime(2026, 9, 3))),
          ['AST00030']);
      expect(refs(const GeneralPaymentFilter(period: ReportPeriod.custom)),
          hasLength(5));
    });

    test('an inverted custom range matches nothing', () {
      final filter = GeneralPaymentFilter(
          period: ReportPeriod.custom,
          customFrom: DateTime(2026, 10, 3),
          customTo: DateTime(2026, 9, 1));
      expect(filter.isInverted, isTrue);
      expect(refs(filter), isEmpty);
    });

    test('copyWith sets values back to null and equality is by value', () {
      const filter = GeneralPaymentFilter(
          type: GeneralPaymentType.loan, categoryId: '1', reference: 'x');
      final cleared = filter.copyWith(type: () => null, categoryId: () => null);
      expect(cleared, const GeneralPaymentFilter(reference: 'x'));
      expect(cleared.hashCode,
          const GeneralPaymentFilter(reference: 'x').hashCode);
      expect(filter.copyWith(), filter);
    });
  });

  test('labels exist in every language', () {
    const keys = [
      'title',
      'type_expense',
      'type_asset',
      'type_income',
      'type_loan',
      'total_expense',
      'total_asset',
      'total_income',
      'total_loan',
      'col_reference',
      'col_debit_account',
      'col_credit_account',
      'load_error',
      'inverted_dates',
      'count',
      'count_filtered',
    ];
    final english = translationSection('en', 'general_payments');
    for (final lang in ['en', 'ar', 'ml']) {
      final section = translationSection(lang, 'general_payments');
      expect(section.keys.toSet(), english.keys.toSet(), reason: lang);
      for (final key in keys) {
        expect(section[key], isA<String>(), reason: '$lang $key');
        expect((section[key] as String).trim(), isNotEmpty,
            reason: '$lang $key');
      }
      for (final key in ['accounts', 'general_payments']) {
        expect(translationSection(lang, 'nav')[key], isA<String>(),
            reason: '$lang nav.$key');
      }
    }
  });
}
