import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/transaction_model.dart';
import 'package:pos_machine/screens/transactions/supplier_transactions/supplier_ledger_row_actions.dart';
import 'package:pos_machine/screens/transactions/widgets/common_details_dialog.dart';

class _Translations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        for (final locale in ['en', 'ar', 'ml']) locale: _load(locale),
      };

  Map<String, String> _load(String locale) {
    final flat = <String, String>{};
    void flatten(Map<String, dynamic> json, String prefix) {
      for (final entry in json.entries) {
        final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
        if (entry.value is Map<String, dynamic>) {
          flatten(entry.value, key);
        } else {
          flat[key] = entry.value.toString();
        }
      }
    }

    flatten(
        jsonDecode(File('lib/resources/i18n/$locale.json').readAsStringSync()),
        '');
    return flat;
  }
}

TransactionModel _record([Map<String, dynamic> overrides = const {}]) =>
    TransactionModel.fromJson({
      'id': 1,
      'supplier_id': 7,
      'date': '2026-10-01',
      'type': 'Credit',
      'transaction_type': 'Invoice',
      'payment_mode': 'CASH',
      'amount': '250.000',
      'tax_amount': '12.500',
      'currency': 'SAR',
      'reference': '000017',
      'transaction_comment': 'Demo supplier payment',
      'status': 'SUCCESS',
      'user_id': 1,
      'created_at': '',
      'updated_at': '',
      'supplier': {
        'id': 7,
        'user_id': 1,
        'balance': '250.00',
        'created_at': '',
        'updated_at': '',
        'user': {
          'id': 1,
          'name': 'Test Supplier',
          'email': '',
          'phone': '',
          'phone_verified': 0,
          'company_id': 1,
          'created_at': '',
          'updated_at': '',
        },
      },
      ...overrides,
    });

// Exercise the public legacy import as well as the feature-owned launcher.
class _Harness extends StatefulWidget {
  const _Harness(this.records);
  final List<TransactionModel> records;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness>
    with SupplierLedgerRowActions<_Harness> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          for (var i = 0; i < widget.records.length; i++)
            TextButton(
              onPressed: () => showTransactionDetails(widget.records[i]),
              child: Text('Open $i'),
            ),
        ]),
      );
}

Future<void> _open(WidgetTester tester,
    {List<TransactionModel>? records,
    Size size = const Size(1440, 900),
    String locale = 'en'}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(GetMaterialApp(
    translations: _Translations(),
    locale: Locale(locale),
    fallbackLocale: const Locale('en'),
    home: _Harness(records ?? [_record()]),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open 0'));
  await tester.pumpAndSettle();
}

Finder _value(String value) => find.descendant(
      of: find.byType(CommonDetailsDialog),
      matching: find.text(value),
    );

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  testWidgets('all fields retain raw money, reference and status',
      (tester) async {
    await _open(tester);
    for (final value in [
      'Test Supplier',
      '01-10-2026',
      'Credit',
      'Invoice',
      'Cash',
      'SAR 250.000',
      '12.500',
      '000017',
      'SUCCESS',
      'Demo supplier payment',
    ]) {
      expect(_value(value), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  for (final missing in [null, '']) {
    testWidgets('optional fields preserve fallback for $missing',
        (tester) async {
      await _open(tester, records: [
        _record({
          'tax_amount': missing,
          'transaction_comment': missing,
        })
      ]);
      expect(_value('N/A'), findsNWidgets(2));
      expect(_value('SAR 250.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final payment in {
    'CARD': 'Card',
    'BANK_TRANSFER': 'Bank Transfer',
    'COD': 'Cash on delivery',
    ' custom method ': 'custom method',
  }.entries) {
    testWidgets('payment label preserves ${payment.key}', (tester) async {
      await _open(tester, records: [
        _record({
          'type': 'Debit',
          'transaction_type': 'Voucher',
          'payment_mode': payment.key,
        })
      ]);
      expect(_value(payment.value), findsOneWidget);
      expect(_value('Debit'), findsOneWidget);
      expect(_value('Voucher'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unknown codes and invalid date remain visible', (tester) async {
    await _open(tester, records: [
      _record({
        'date': 'invalid-date',
        'type': 'custom debit',
        'transaction_type': 'custom document',
        'status': 'future_status',
        'amount': '-250.125',
        'currency': 'INR',
      })
    ]);
    for (final value in [
      'invalid-date',
      'custom debit',
      'custom document',
      'future_status',
      'INR -250.125',
    ]) {
      expect(_value(value), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('footer and header close allow opening a different record',
      (tester) async {
    await _open(tester, records: [
      _record(),
      _record({'id': 2, 'reference': 'SECOND', 'amount': '9.500'}),
    ]);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(CommonDetailsDialog), findsNothing);
    await tester.tap(find.text('Open 1'));
    await tester.pumpAndSettle();
    expect(_value('SECOND'), findsOneWidget);
    expect(_value('000017'), findsNothing);
    expect(_value('SAR 9.500'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(CommonDetailsDialog), findsNothing);
    await tester.tap(find.text('Open 0'));
    await tester.pumpAndSettle();
    expect(_value('000017'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('barrier dismissal leaves the launching screen usable',
      (tester) async {
    await _open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(CommonDetailsDialog), findsNothing);
    await tester.tap(find.text('Open 0'));
    await tester.pumpAndSettle();
    expect(_value('000017'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['en', 'ar', 'ml']) {
    for (final size in [const Size(1440, 900), const Size(390, 800)]) {
      testWidgets('translated details open and close at $locale $size',
          (tester) async {
        await _open(tester, locale: locale, size: size);
        expect(
            find.text('supplier_transactions.dialog_title'.tr), findsOneWidget);
        expect(_value('transaction_status_labels.credit'.tr), findsOneWidget);
        expect(_value('transaction_status_labels.cash'.tr), findsOneWidget);
        expect(_value('SUCCESS'), findsOneWidget);
        expect(_value('000017'), findsOneWidget);
        await tester.tap(find.text('common_details_dialog.close'.tr));
        await tester.pumpAndSettle();
        expect(find.byType(CommonDetailsDialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('long comments scroll while close remains usable',
      (tester) async {
    final comment = List.filled(30, 'Long supplier comment').join('\n');
    await _open(tester, size: const Size(390, 800), records: [
      _record({'transaction_comment': '$comment\nEND OF COMMENT'}),
    ]);
    expect(_value('$comment\nEND OF COMMENT'), findsOneWidget);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(CommonDetailsDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
