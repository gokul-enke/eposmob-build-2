import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/screens/transactions/transaction_list/customer_ledger_row_actions.dart';
import 'package:pos_machine/screens/transactions/widgets/common_details_dialog.dart';
import 'package:provider/provider.dart';

class DetailLabels extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        for (final language in ['en', 'ar', 'ml'])
          language: _flatten(jsonDecode(
              File('lib/resources/i18n/$language.json').readAsStringSync()))
      };

  Map<String, String> _flatten(Map<String, dynamic> source,
      [String prefix = '']) {
    final labels = <String, String>{};
    for (final entry in source.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (entry.value is Map<String, dynamic>) {
        labels.addAll(_flatten(entry.value, key));
      } else {
        labels[key] = entry.value.toString();
      }
    }
    return labels;
  }
}

class DetailMasterData extends MasterDataProvider {
  final labels = <int, String>{7: 'Card label'};
  final lookups = <int?>[];

  @override
  String? getPaymentMethodValue(int? id) {
    lookups.add(id);
    return labels[id];
  }
}

ListTransaction detailTransaction({String? payment = '7'}) => ListTransaction(
      id: 12,
      customerName: 'Test Customer',
      date: '2026-10-12',
      type: 'Credit',
      transactionType: 'receipt',
      paymentMethod: payment,
      currency: 'SAR',
      amount: '15.750',
      referenceId: '000123',
      reference: 'RCP00123',
      status: 'SUCC',
      transactionComment: 'Original comment',
      createdAt: DateTime(2026, 10, 12),
    );

class DetailHarness extends StatefulWidget {
  const DetailHarness({super.key, required this.transactions});
  final List<ListTransaction> transactions;

  @override
  State<DetailHarness> createState() => _DetailHarnessState();
}

class _DetailHarnessState extends State<DetailHarness>
    with CustomerLedgerRowActions<DetailHarness> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          for (var index = 0; index < widget.transactions.length; index++)
            TextButton(
                onPressed: () =>
                    showCustomerLedgerDetails(widget.transactions[index]),
                child: Text('View $index'))
        ]),
      );
}

Future<DetailMasterData> mountDetails(WidgetTester tester,
    {List<ListTransaction>? transactions,
    DetailMasterData? master,
    Size size = const Size(1440, 900),
    String language = 'en'}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = master ?? DetailMasterData();
  await tester.pumpWidget(ChangeNotifierProvider<MasterDataProvider>.value(
      value: provider,
      child: RepaintBoundary(
          key: const ValueKey('details-capture'),
          child: GetMaterialApp(
              translations: DetailLabels(),
              locale: Locale(language),
              home: DetailHarness(
                  transactions: transactions ?? [detailTransaction()])))));
  await tester.pumpAndSettle();
  return provider;
}

Future<void> openDetails(WidgetTester tester, [int index = 0]) async {
  await tester.tap(find.text('View $index'));
  await tester.pumpAndSettle();
}

List<String> detailValues(WidgetTester tester) => tester
    .widgetList<SelectableText>(find.descendant(
        of: find.byType(CommonDetailsDialog),
        matching: find.byType(SelectableText)))
    .map((text) => text.data!)
    .toList();

void main() {
  setUpAll(() async {
    for (final language in ['en', 'ar', 'ml']) {
      await initializeDateFormatting(language);
    }
  });
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  testWidgets('preserves every field, raw precision and leading zero reference',
      (tester) async {
    final master = await mountDetails(tester);
    await openDetails(tester);
    expect(master.lookups, [7]);
    expect(detailValues(tester), [
      'Test Customer',
      '2026-10-12',
      UiCodeLabels.documentKind('Credit'),
      UiCodeLabels.documentKind('receipt'),
      'Card label',
      'SAR 15.750',
      '000123',
      'RCP00123',
      'SUCC',
      'Original comment',
      DateHelper.formatDate(DateTime(2026, 10, 12))
    ]);
    expect(tester.takeException(), isNull);
  });

  for (final payment in <String?>[
    null,
    '',
    'cash',
    '7, 8',
    '99',
    '007',
    '-1'
  ]) {
    testWidgets('preserves payment fallback for $payment', (tester) async {
      final master = await mountDetails(tester,
          transactions: [detailTransaction(payment: payment)]);
      await openDetails(tester);
      final id = int.tryParse(payment ?? '');
      expect(master.lookups, id == null ? [] : [id]);
      final label = (id == null ? null : master.labels[id]) ??
          payment ??
          'party_accounts.na'.tr;
      expect(detailValues(tester)[4],
          label.isEmpty ? 'common_details_dialog.na'.tr : label);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('null fields keep existing translated fallbacks', (tester) async {
    await mountDetails(tester, transactions: [ListTransaction()]);
    await openDetails(tester);
    expect(detailValues(tester), [
      'party_accounts.no_name'.tr,
      'party_accounts.na'.tr,
      UiCodeLabels.documentKind('party_accounts.na'.tr),
      UiCodeLabels.documentKind('party_accounts.na'.tr),
      'party_accounts.na'.tr,
      ' ',
      'party_accounts.na'.tr,
      'party_accounts.na'.tr,
      'party_accounts.na'.tr,
      'party_accounts.na'.tr,
      'party_accounts.na'.tr,
    ]);
  });

  testWidgets('empty fields keep shared dialog fallback and amount spacing',
      (tester) async {
    await mountDetails(tester, transactions: [
      ListTransaction(
          customerName: '',
          date: '',
          type: '',
          transactionType: '',
          paymentMethod: '',
          currency: '',
          amount: '',
          referenceId: '',
          reference: '',
          status: '',
          transactionComment: '')
    ]);
    await openDetails(tester);
    expect(detailValues(tester), [
      for (var i = 0; i < 5; i++) 'common_details_dialog.na'.tr,
      ' ',
      for (var i = 0; i < 4; i++) 'common_details_dialog.na'.tr,
      'party_accounts.na'.tr,
    ]);
  });

  testWidgets('closing and opening another row uses its current payment label',
      (tester) async {
    final master = await mountDetails(tester, transactions: [
      detailTransaction(),
      ListTransaction(customerName: 'Second Customer', paymentMethod: '7')
    ]);
    await openDetails(tester);
    await tester.tap(find.text('common_details_dialog.close'.tr));
    await tester.pumpAndSettle();
    expect(find.byType(CommonDetailsDialog), findsNothing);
    master.labels[7] = 'Updated payment label';
    await openDetails(tester, 1);
    expect(detailValues(tester).first, 'Second Customer');
    expect(detailValues(tester)[4], 'Updated payment label');
    expect(find.text('Test Customer'), findsNothing);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(CommonDetailsDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('payment label is a snapshot while the dialog is open',
      (tester) async {
    final master = await mountDetails(tester);
    await openDetails(tester);
    master.labels[7] = 'Changed after opening';
    master.notifyListeners();
    await tester.pumpAndSettle();
    expect(detailValues(tester)[4], 'Card label');
    expect(master.lookups, [7]);
  });

  for (final size in [
    const Size(1440, 900),
    const Size(800, 900),
    const Size(390, 800)
  ]) {
    testWidgets('fields scroll and close at $size', (tester) async {
      await mountDetails(tester, size: size, transactions: [
        ListTransaction(
            customerName: 'Customer with a longer display name',
            paymentMethod: 'cash',
            transactionComment: 'Long comment ' * 50,
            createdAt: DateTime(2026, 10, 12))
      ]);
      await openDetails(tester);
      await tester.ensureVisible(
          find.text(DateHelper.formatDate(DateTime(2026, 10, 12))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('common_details_dialog.close'.tr));
      await tester.pumpAndSettle();
      expect(find.byType(CommonDetailsDialog), findsNothing);
    });
  }

  for (final language in ['en', 'ar', 'ml']) {
    testWidgets('preserves field translations and closing in $language',
        (tester) async {
      await mountDetails(tester, language: language);
      await openDetails(tester);
      expect(find.text('party_accounts.dialog_title'.tr), findsOneWidget);
      expect(
          find.text('${'party_accounts.customer_name'.tr}:'), findsOneWidget);
      expect(detailValues(tester)[2], UiCodeLabels.documentKind('Credit'));
      expect(detailValues(tester)[8], 'SUCC');
      await tester.tap(find.text('common_details_dialog.close'.tr));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(CommonDetailsDialog), findsNothing);
    });
  }
}
