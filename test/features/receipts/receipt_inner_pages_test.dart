import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/features/receipts/data/receipt_editor_repository.dart';
import 'package:pos_machine/features/receipts/domain/receipt_form_item.dart';
import 'package:pos_machine/features/receipts/presentation/widgets/receipt_details_dialog.dart';
import 'package:pos_machine/screens/transactions/create_receipt_modal.dart';
import 'package:pos_machine/models/list_invoice.dart';
import 'package:pos_machine/models/list_receipt.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/newcomponents/custom_round_button.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';

class _Translations extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final flat = <String, String>{};
    void flatten(Map<String, dynamic> data, String prefix) {
      for (final entry in data.entries) {
        final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
        if (entry.value is Map<String, dynamic>) {
          flatten(entry.value, key);
        } else {
          flat[key] = '${entry.value}';
        }
      }
    }

    flatten(
        jsonDecode(File('lib/resources/i18n/en.json').readAsStringSync()), '');
    return {'en': flat};
  }
}

class _Customers extends CustomerProvider {
  Completer<void>? pending;
  Object? error;
  bool? listAllRequested;
  String? token;
  final directory = [
    CustomerListModelData(id: 1, name: 'Alice', balance: 20),
    CustomerListModelData(id: 2, name: 'Bob', balance: -10),
  ];
  @override
  List<CustomerListModelData> get allCustomers => directory;
  @override
  Future<void> fetchCustomers(
      {required String accessToken,
      String? customerName,
      bool listAll = true}) async {
    listAllRequested = listAll;
    token = accessToken;
    if (pending != null) await pending!.future;
    if (error != null) throw error!;
  }
}

class _Methods extends MasterDataProvider {
  Completer<List<MasterDataValue>?>? pending;
  List<MasterDataValue>? values = [
    MasterDataValue(id: 7, value: 'CARD', description: 'Card'),
    MasterDataValue(id: 8, value: 'COD', description: 'Cash on delivery'),
    MasterDataValue(id: 9, value: 'CASH', description: 'Cash'),
  ];
  @override
  Future<List<MasterDataValue>?> fetchPaymentMethods(
          {bool forceRefresh = false}) async =>
      pending == null ? values : await pending!.future;
}

Invoice invoice(int id, int customer, {dynamic balance = '20.00'}) =>
    Invoice.fromJson({
      'id': id,
      'customer_id': customer,
      'invoice_number': 'INV-$id',
      'amount': '30.00',
      'balance_amount': balance,
      'created_at': '2026-10-01',
      'updated_at': '2026-10-01',
    });

class _Invoices extends InvoiceProvider {
  Completer<List<Invoice>>? pending;
  Completer<dynamic>? submission;
  Object? createError;
  int snapshotCalls = 0, createCalls = 0;
  String? customer, status, token, reference;
  List<Map<String, dynamic>>? items;
  @override
  Future<List<Invoice>> fetchAllInvoicesSnapshot(
      {required String accessToken,
      int perPage = 1000,
      http.Client? client}) async {
    snapshotCalls++;
    return pending == null
        ? [invoice(11, 1), invoice(22, 2)]
        : await pending!.future;
  }

  @override
  Future<dynamic> addReceipt(
      {required String customerId,
      required String receiptStatus,
      required List<Map<String, dynamic>> receiptItems,
      required String accessToken,
      String? paymentReference}) async {
    createCalls++;
    customer = customerId;
    status = receiptStatus;
    token = accessToken;
    reference = paymentReference;
    items = receiptItems;
    if (createError != null) throw createError!;
    return submission == null ? {'status': 'success'} : submission!.future;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  ReceiptFormItem form(
          {String? type = 'General Payment',
          String? invoiceId,
          String amount = '12.50',
          String description = ''}) =>
      ReceiptFormItem(
          selectedItemType: type,
          invoiceId: invoiceId,
          amount: amount,
          paymentDate: '2026-10-12',
          description: description);
  test('general row preserves API types, null method and default description',
      () {
    expect(form(invoiceId: '11').toApi(paymentMethodId: null), {
      'item_type': 'general',
      'paid_amount': 12.5,
      'status': 'paid',
      'payment_date': '2026-10-12',
      'payment_method': null,
      'description': 'General Payment',
    });
  });
  test('invoice row keeps string ID and exact description', () {
    expect(
        form(type: 'Invoice Payment', invoiceId: '0011', description: '  ref  ')
            .toApi(paymentMethodId: 9),
        {
          'item_type': 'invoice',
          'paid_amount': 12.5,
          'status': 'paid',
          'payment_date': '2026-10-12',
          'payment_method': 9,
          'description': '  ref  ',
          'invoice_id': '0011',
        });
  });
  test('legacy malformed amount and absent invoice mapping is unchanged', () {
    expect(
        form(type: 'Invoice Payment', amount: 'invalid', invoiceId: '')
            .toApi(paymentMethodId: 7)['paid_amount'],
        0.0);
    expect(
        form(type: 'Invoice Payment', invoiceId: '')
            .toApi(paymentMethodId: 7)
            .containsKey('invoice_id'),
        false);
  });
  test(
      'repository uses full customer directory and independent invoice snapshot',
      () async {
    final customers = _Customers(),
        invoices = _Invoices(),
        methods = _Methods();
    final repository = ReceiptEditorRepository(
        invoices: invoices, customers: customers, masterData: methods);
    expect((await repository.loadCustomers('auth')).map((c) => c.name),
        ['Alice', 'Bob']);
    expect(customers.listAllRequested, true);
    expect(customers.token, 'auth');
    expect((await repository.loadInvoices('auth')).map((i) => i.id), [11, 22]);
    expect(invoices.snapshotCalls, 1);
    expect(
        (await repository.loadPaymentMethods())!.map((m) => m.id), [7, 8, 9]);
    await repository.createReceipt(
        customerId: '1',
        receiptStatus: 'paid',
        receiptItems: [form().toApi(paymentMethodId: 9)],
        accessToken: 'auth',
        paymentReference: 'REF');
    expect(invoices.customer, '1');
    expect(invoices.reference, 'REF');
    expect(invoices.token, 'auth');
    expect(invoices.status, 'paid');
  });

  Future<void> mount(WidgetTester tester, _Customers customers,
      _Methods methods, _Invoices invoices,
      {bool authenticated = true, Size size = const Size(1440, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthModel();
    if (authenticated) auth.login('auth', 1);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthModel>.value(value: auth),
          ChangeNotifierProvider<CustomerProvider>.value(value: customers),
          ChangeNotifierProvider<MasterDataProvider>.value(value: methods),
          ChangeNotifierProvider<InvoiceProvider>.value(value: invoices),
        ],
        child: GetMaterialApp(
            locale: const Locale('en'),
            translations: _Translations(),
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () => showCreateReceiptModal(context, size),
                        child: const Text('Open')))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  CustomDropDownWithSearch<String> dropdown(WidgetTester tester, int index) =>
      tester
          .widgetList<CustomDropDownWithSearch<String>>(
              find.byType(CustomDropDownWithSearch<String>))
          .elementAt(index);
  void button(WidgetTester tester, String title) => tester
      .widgetList<CustomRoundButtonAdvanced>(
          find.byType(CustomRoundButtonAdvanced))
      .firstWhere((w) => w.title == title.tr)
      .fct();
  Future<void> addGeneral(WidgetTester tester, String amount,
      {String description = 'QA Payment'}) async {
    final fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    fields[0].controller!.text = description;
    fields[1].controller!.text = amount;
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'customer names and CASH default; draft excluded, saved rows sum, edit, remove, payload',
      (tester) async {
    final invoices = _Invoices();
    await mount(tester, _Customers(), _Methods(), invoices);
    expect(dropdown(tester, 0).displayText('1'), 'Alice');
    expect(dropdown(tester, 0).displayText('2'), 'Bob');
    expect(dropdown(tester, 2).value, 'CASH');
    dropdown(tester, 0).onChanged('1');
    await tester.pumpAndSettle();
    await addGeneral(tester, '10.25', description: 'First');
    await addGeneral(tester, '5.50', description: 'Second');
    expect(find.text('15.75'), findsOneWidget);
    final draft =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    draft[1].controller!.text = '100';
    await tester.pumpAndSettle();
    expect(find.text('15.75'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    final editors =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    editors.last.controller!.text = '12.25';
    button(tester, 'general.save');
    await tester.pumpAndSettle();
    expect(find.text('17.75'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete).last);
    await tester.pumpAndSettle();
    expect(find.text('12.25'), findsWidgets);
    final reference =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).last;
    reference.controller!.text = 'QA-REF';
    button(tester, 'receipt.submit_button');
    await tester.pumpAndSettle();
    expect(invoices.items, [
      {
        'item_type': 'general',
        'paid_amount': 12.25,
        'status': 'paid',
        'payment_date': DateTime.now().toIso8601String().split('T')[0],
        'payment_method': 9,
        'description': 'First'
      }
    ]);
    expect(invoices.reference, 'QA-REF');
    expect(find.byType(CreateReceiptModal), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'invoice selection filters by customer, fills balance and blocks overpayment',
      (tester) async {
    final invoices = _Invoices();
    await mount(tester, _Customers(), _Methods(), invoices);
    dropdown(tester, 0).onChanged('1');
    await tester.pumpAndSettle();
    dropdown(tester, 1).onChanged('Invoice Payment');
    await tester.pumpAndSettle();
    expect(dropdown(tester, 2).items, ['11']);
    dropdown(tester, 2).onChanged('11');
    await tester.pumpAndSettle();
    final fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields[0].controller!.text, '30.00');
    expect(fields[1].controller!.text, '20.00');
    fields[2].controller!.text = '21';
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit), findsNothing);
    fields[2].controller!.text = '15.5';
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit), findsOneWidget);
    button(tester, 'receipt.submit_button');
    await tester.pumpAndSettle();
    expect(invoices.items!.single['invoice_id'], '11');
    expect(invoices.items!.single['paid_amount'], 15.5);
    expect(invoices.items!.single['item_type'], 'invoice');
    expect(invoices.reference, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'customer change Cancel preserves rows, Continue clears rows and total',
      (tester) async {
    await mount(tester, _Customers(), _Methods(), _Invoices());
    dropdown(tester, 0).onChanged('1');
    await tester.pumpAndSettle();
    await addGeneral(tester, '10');
    dropdown(tester, 0).onChanged('2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('general.cancel'.tr).last);
    await tester.pumpAndSettle();
    expect(dropdown(tester, 0).value, '1');
    expect(find.byIcon(Icons.edit), findsOneWidget);
    dropdown(tester, 0).onChanged('2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('receipt.continue_button'.tr));
    await tester.pumpAndSettle();
    expect(dropdown(tester, 0).value, '2');
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.text('0.00'), findsOneWidget);
    button(tester, 'general.cancel');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'edit Cancel preserves saved amount; keyboard Save matches button Save',
      (tester) async {
    await mount(tester, _Customers(), _Methods(), _Invoices());
    await addGeneral(tester, '10');
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .last
        .controller!
        .text = '12';
    await tester.tap(find.text('general.cancel'.tr).last);
    await tester.pumpAndSettle();
    expect(find.text('10.00'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    final field =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).last;
    field.controller!.text = '12';
    tester
        .widgetList<TextField>(find.byType(TextField))
        .last
        .onSubmitted!('12');
    await tester.pumpAndSettle();
    expect(find.text('12.00'), findsOneWidget);
    button(tester, 'general.cancel');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('provider rejection retains form for retry', (tester) async {
    final invoices = _Invoices()..createError = StateError('demo failure');
    await mount(tester, _Customers(), _Methods(), invoices);
    dropdown(tester, 0).onChanged('1');
    await tester.pumpAndSettle();
    await addGeneral(tester, '10');
    button(tester, 'receipt.submit_button');
    await tester.pumpAndSettle();
    expect(find.byType(CreateReceiptModal), findsOneWidget);
    expect(find.text('10.00'), findsOneWidget);
    invoices.createError = null;
    button(tester, 'receipt.submit_button');
    await tester.pumpAndSettle();
    expect(invoices.createCalls, 2);
    expect(find.byType(CreateReceiptModal), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing authentication and missing customer block submission',
      (tester) async {
    final invoices = _Invoices();
    await mount(tester, _Customers(), _Methods(), invoices,
        authenticated: false);
    button(tester, 'receipt.submit_button');
    await tester.pumpAndSettle();
    expect(invoices.createCalls, 0);
    button(tester, 'general.cancel');
    await tester.pumpAndSettle();
    await mount(tester, _Customers(), _Methods(), invoices);
    button(tester, 'receipt.submit_button');
    await tester.pumpAndSettle();
    expect(invoices.createCalls, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('late lookup completion after Cancel cannot update disposed form',
      (tester) async {
    final customers = _Customers()..pending = Completer<void>();
    final invoices = _Invoices()..pending = Completer<List<Invoice>>();
    final methods = _Methods()..pending = Completer<List<MasterDataValue>?>();
    await mount(tester, customers, methods, invoices);
    button(tester, 'general.cancel');
    await tester.pumpAndSettle();
    customers.pending!.complete();
    invoices.pending!.complete([invoice(11, 1)]);
    methods.pending!.complete(methods.values);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('late submission after Cancel does not pop the underlying page',
      (tester) async {
    final invoices = _Invoices()..submission = Completer<dynamic>();
    await mount(tester, _Customers(), _Methods(), invoices);
    dropdown(tester, 0).onChanged('1');
    await tester.pumpAndSettle();
    await addGeneral(tester, '10');
    button(tester, 'receipt.submit_button');
    await tester.pump();
    button(tester, 'general.cancel');
    await tester.pumpAndSettle();
    invoices.submission!.complete({'status': 'success'});
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final values in [
    [MasterDataValue(id: 8, value: 'COD', description: 'Cash on delivery')],
    [MasterDataValue(id: 7, value: 'CARD', description: 'Card')],
    <MasterDataValue>[],
  ]) {
    testWidgets('payment default fallback ${values.map((v) => v.value).join()}',
        (tester) async {
      await mount(
          tester, _Customers(), _Methods()..values = values, _Invoices());
      expect(dropdown(tester, 2).value,
          values.isEmpty ? null : values.first.value);
      button(tester, 'general.cancel');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('narrow create layout keeps existing fields and saved totals',
      (tester) async {
    await mount(tester, _Customers(), _Methods(), _Invoices(),
        size: const Size(740, 1000));
    expect(dropdown(tester, 0).displayText('1'), 'Alice');
    await tester.ensureVisible(find.byIcon(Icons.add));
    await addGeneral(tester, '5.25');
    expect(find.text('5.25'), findsWidgets);
    button(tester, 'general.cancel');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'details preserves metadata, invoice reference and date/description fallbacks',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final receipt = Receipt.fromJson({
      'receipt_number': 'RCP-QA',
      'amount': '15.750',
      'receipt_status': 'paid',
      'payment_reference': 'QA-REF',
      'created_at': '2026-10-01',
      'updated_at': '2026-10-01',
      'customer': {
        'user': {'name': 'Alice'}
      },
      'company': {'name': 'Demo Company'},
      'receipt_payments': [
        {
          'invoice_id': 11,
          'paid_amount': '10.250',
          'payment_method': 'Cash',
          'payment_date': '2026-10-12'
        },
        {
          'paid_amount': '5.500',
          'payment_method': 'Card',
          'payment_date': 'bad',
          'description': 'QA general'
        },
        {'paid_amount': '0', 'payment_method': 'COD', 'payment_date': ''},
      ]
    });
    await tester.pumpWidget(GetMaterialApp(
        locale: const Locale('en'),
        translations: _Translations(),
        home: Scaffold(body: ReceiptDetailsDialog(receipt: receipt))));
    await tester.pumpAndSettle();
    for (final text in [
      'RCP-QA',
      'Alice',
      'Demo Company',
      '15.750',
      'paid',
      'QA-REF',
      'INV-11',
      'QA general',
      'Cash',
      'Card',
      '10.250',
      '5.500',
      'receipt.type_general_payment'.tr
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(tester.takeException(), isNull);
  });
}
