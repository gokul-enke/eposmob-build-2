import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/features/customers/presentation/state/customer_provider.dart';
import 'package:pos_machine/features/customers/domain/models/customer_list.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_provider.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/newcomponents/custom_round_button.dart';
import 'package:pos_machine/features/invoices/data/invoice_details_repository.dart';
import 'package:pos_machine/features/invoices/data/invoice_editor_repository.dart';
import 'package:pos_machine/features/invoices/domain/invoice_form_item.dart';
import 'package:pos_machine/features/invoices/presentation/widgets/invoice_details_dialog.dart';
import 'package:pos_machine/models/invoice_details.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/screens/transactions/create_invoice_modal.dart';

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
          flat[key] = entry.value.toString();
        }
      }
    }

    flatten(
        jsonDecode(File('lib/resources/i18n/en.json').readAsStringSync()), '');
    return {'en': flat};
  }
}

Map<String, dynamic> detailsJson(int id) => {
      'id': id,
      'invoice_number': 'INV-$id',
      'customer': {
        'id': 3,
        'user': {'name': 'Customer', 'phone': '00123'}
      },
      'amount': '15.750',
      'invoice_date': '2026-10-12',
      'due_date': '2026-11-12',
      'status': 'pending',
      'type': 'other',
      'invoice_items': [
        {
          'item_name': 'Weighted item',
          'quantity': '1.5',
          'unit_amount': '10.00',
          'tax': '5',
          'total_amount': '15.75',
        }
      ],
    };

class _Customers extends CustomerProvider {
  final pending = Completer<List<CustomerListModelData>>();
  @override
  Future<List<CustomerListModelData>> fetchAllCustomersSnapshot({
    required String accessToken,
  }) =>
      pending.future;
}

class _Methods extends MasterDataProvider {
  final pending = Completer<List<MasterDataValue>?>();
  @override
  Future<List<MasterDataValue>?> fetchPaymentMethods(
          {bool forceRefresh = false}) =>
      pending.future;
}

class _Invoices extends InvoiceProvider {
  Map<String, dynamic>? submitted;
  int calls = 0;
  dynamic response = {'status': 'success'};
  Completer<dynamic>? pending;
  @override
  Future<dynamic> createInvoice({
    required int customerId,
    required String type,
    required String dueDate,
    required String invoiceDate,
    required double amount,
    required String status,
    required int paymentMethod,
    required List<Map<String, dynamic>> invoiceItems,
    required String accessToken,
    String? couponId,
    double? flatDiscount,
    double? percentageDiscount,
    double? discountAmount,
  }) async {
    calls++;
    submitted = {
      'customerId': customerId,
      'type': type,
      'dueDate': dueDate,
      'invoiceDate': invoiceDate,
      'amount': amount,
      'status': status,
      'paymentMethod': paymentMethod,
      'invoiceItems': invoiceItems,
      'accessToken': accessToken,
      'couponId': couponId,
      'flatDiscount': flatDiscount,
      'percentageDiscount': percentageDiscount,
      'discountAmount': discountAmount,
    };
    return pending == null ? response : pending!.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Poppins')
          ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf')))
        .load();
  });
  setUp(() => SharedPreferences.setMockInitialValues(
      {'api_key': 'test-tenant', 'active_store_id': 2}));
  tearDown(Get.reset);

  test('item totals retain percentage tax and fractional quantity rules', () {
    final item = InvoiceItemCard();
    expect(item.quantityController.text, '1');
    item.unitAmountController.text = '10';
    item.taxController.text = '5';
    item.quantityController.text = '1.5';
    expect(item.totalController.text, '15.75');
    item.quantityController.clear();
    expect(item.totalController.text, '10.50');
    item.unitAmountController.text = 'invalid';
    expect(item.totalController.text, '0.00');
    item.dispose();
  });

  test('summary preserves flat, percentage and removed-item discount rules',
      () {
    final items = [
      InvoiceFormItem.fromText(
          name: 'Item',
          unitAmount: '10',
          taxPercent: '5',
          quantity: '1.5',
          totalAmount: '15.75')
    ];
    final flat = InvoiceFormTotals.calculate(items,
        flatDiscount: 2, percentageDiscount: 0);
    expect(flat.net, 15);
    expect(flat.tax, .75);
    expect(flat.payable, 13.75);
    final percentage = InvoiceFormTotals.calculate(items,
        flatDiscount: 2, percentageDiscount: 10);
    expect(percentage.discount, closeTo(1.575, .000001));
    expect(percentage.payable, closeTo(14.175, .000001));
    // Do not clamp a retained flat discount when the final item is removed.
    expect(
        InvoiceFormTotals.calculate([], flatDiscount: 2, percentageDiscount: 0)
            .payable,
        -2);
    expect(
        InvoiceFormTotals.calculate([], flatDiscount: 2, percentageDiscount: 10)
            .payable,
        0);
    expect(
        InvoiceFormItem.fromText(
                name: 'Unchanged',
                unitAmount: '',
                taxPercent: '',
                quantity: '',
                totalAmount: '')
            .toJson(),
        {
          'item_name': 'Unchanged',
          'unit_amount': 0.0,
          'tax': 0.0,
          'quantity': 1.0,
          'total_amount': 0.0
        });
  });

  test('create adapter forwards all financial and payment fields unchanged',
      () async {
    final provider = _Invoices();
    final items = [
      {
        'item_name': 'Item',
        'quantity': 1.5,
        'unit_amount': 10.0,
        'tax': 5.0,
        'total_amount': 15.75
      }
    ];
    final result = await InvoiceEditorRepository(provider).createInvoice(
      customerId: 3,
      type: 'other',
      dueDate: '2026-11-12',
      invoiceDate: '2026-10-12',
      amount: 14.175,
      status: 'pending',
      paymentMethod: 206,
      invoiceItems: items,
      accessToken: 'test-token',
      couponId: 'COUPON',
      percentageDiscount: 10,
      discountAmount: 1.575,
    );
    expect(result, {'status': 'success'});
    expect(provider.submitted, {
      'customerId': 3,
      'type': 'other',
      'dueDate': '2026-11-12',
      'invoiceDate': '2026-10-12',
      'amount': 14.175,
      'status': 'pending',
      'paymentMethod': 206,
      'invoiceItems': items,
      'accessToken': 'test-token',
      'couponId': 'COUPON',
      'flatDiscount': null,
      'percentageDiscount': 10.0,
      'discountAmount': 1.575,
    });
    provider.dispose();
  });

  test('details retain store and authentication contract', () async {
    final repository =
        InvoiceDetailsRepository(client: MockClient((request) async {
      expect(request.url.path.endsWith('/7'), isTrue);
      expect(request.url.queryParameters, {'store_id': '2'});
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.headers['X-Tenant'], 'test-tenant');
      return http.Response(jsonEncode({'data': detailsJson(7)}), 200);
    }));
    final details = await repository.fetch(id: 7, accessToken: 'test-token');
    expect(details!.invoiceNumber, 'INV-7');
    expect(details.invoiceItems.single.displayQuantity, '1.5');
  });

  test('failed or mismatched details cannot reuse previous invoice', () async {
    var requestCount = 0;
    final repository = InvoiceDetailsRepository(client: MockClient((_) async {
      requestCount++;
      if (requestCount == 2) return http.Response('failure', 500);
      return http.Response(jsonEncode({'data': detailsJson(7)}), 200);
    }));
    expect(await repository.fetch(id: 7, accessToken: 'token'), isNotNull);
    expect(await repository.fetch(id: 8, accessToken: 'token'), isNull);
    expect(await repository.fetch(id: 9, accessToken: 'token'), isNull);
  });

  test('concurrent details retain their own results', () async {
    final first = Completer<http.Response>();
    final repository =
        InvoiceDetailsRepository(client: MockClient((request) async {
      if (request.url.path.endsWith('/7')) return first.future;
      return http.Response(jsonEncode({'data': detailsJson(8)}), 200);
    }));
    final pending = repository.fetch(id: 7, accessToken: 'token');
    expect((await repository.fetch(id: 8, accessToken: 'token'))!.id, 8);
    first.complete(http.Response(jsonEncode({'data': detailsJson(7)}), 200));
    expect((await pending)!.id, 7);
  });

  test('details omit store parameter when no store is selected', () async {
    SharedPreferences.setMockInitialValues({'api_key': 'test-tenant'});
    final repository =
        InvoiceDetailsRepository(client: MockClient((request) async {
      expect(request.url.queryParameters, isEmpty);
      return http.Response(jsonEncode({'data': detailsJson(7)}), 200);
    }));
    expect(await repository.fetch(id: 7, accessToken: 'token'), isNotNull);
  });

  testWidgets('details keep customer and decimal item values visible',
      (tester) async {
    await tester.pumpWidget(GetMaterialApp(
        translations: _Translations(),
        locale: const Locale('en'),
        home: Scaffold(
            body: InvoiceDetailsDialog(
                details: InvoiceDetails.fromJson(detailsJson(7))))));
    expect(find.text('INV-7'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('00123'), findsOneWidget);
    expect(find.text('Weighted item'), findsOneWidget);
    expect(find.text('1.5'), findsOneWidget);
    expect(find.text('15.75'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing create while lookups are pending safely disposes form',
      (tester) async {
    final customers = _Customers();
    final methods = _Methods();
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<CustomerProvider>.value(value: customers),
          ChangeNotifierProvider<MasterDataProvider>.value(value: methods),
          ChangeNotifierProvider<AuthModel>(create: (_) => AuthModel()),
        ],
        child: GetMaterialApp(
            translations: _Translations(),
            locale: const Locale('en'),
            home: const Scaffold(
                body: CreateInvoiceModal(size: Size(1600, 1000))))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    customers.pending.complete([]);
    methods.pending.complete(null);
    await tester.pump();
    expect(tester.takeException(), isNull);
    customers.dispose();
    methods.dispose();
  });

  for (final width in [1920.0, 1600.0, 1280.0, 1040.0, 800.0, 390.0]) {
    testWidgets('create selected payment and status remain readable at $width',
        (tester) async {
      final size = Size(width, 1000);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final customers = _Customers()..pending.complete([]);
      final methods = _Methods()
        ..pending.complete([
          MasterDataValue(id: 206, value: 'CASH', description: 'Cash'),
          MasterDataValue(
              id: 207, value: 'COD', description: 'Cash on delivery'),
        ]);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<CustomerProvider>.value(value: customers),
          ChangeNotifierProvider<MasterDataProvider>.value(value: methods),
          ChangeNotifierProvider<AuthModel>(create: (_) => AuthModel()),
        ],
        child: GetMaterialApp(
          translations: _Translations(),
          locale: const Locale('en'),
          home: Scaffold(body: Builder(builder: (context) {
            return TextButton(
              onPressed: () => showCreateInvoiceModal(context, size),
              child: const Text('Create'),
            );
          })),
        ),
      ));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      final status = find.byKey(const ValueKey('invoice-create-status'));
      final payment =
          find.byKey(const ValueKey('invoice-create-payment-method'));
      final paymentWidget =
          tester.widget<CustomDropDownWithSearch<String>>(payment);
      expect(paymentWidget.value, 'CASH');
      final cash = find.descendant(of: payment, matching: find.text('Cash'));
      expect(tester.renderObject<RenderParagraph>(cash).didExceedMaxLines,
          isFalse);
      paymentWidget.onChanged('COD');
      await tester.pumpAndSettle();
      for (final entry in [
        (status, 'Pending'),
        (payment, 'Cash on delivery')
      ]) {
        final text =
            find.descendant(of: entry.$1, matching: find.text(entry.$2));
        expect(text, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(text);

        if (width >= 700 || entry.$2 == 'Pending') {
          expect(paragraph.didExceedMaxLines, isFalse,
              reason: '${entry.$2} must fit at viewport width $width');
        }
        // Longer methods may ellipsize on a phone, but must have usable text
        // space rather than showing only the clear button and arrow.
        expect(paragraph.size.width, greaterThan(0));
        expect(tester.getSize(entry.$1).width, greaterThanOrEqualTo(220));
      }
      expect(tester.takeException(), isNull);
      // Changing the responsive branch must retain selections and form state.
      await tester.binding
          .setSurfaceSize(Size(width >= 700 ? 640 : width * .85, 1000));
      await tester.pumpAndSettle();
      expect(tester.widget<CustomDropDownWithSearch<String>>(payment).value,
          'COD');
      expect(tester.widget<CustomDropDownWithSearch<String>>(status).value,
          'Pending');
      expect(tester.takeException(), isNull);
      if (width == 1600) {
        final cancel = tester
            .widgetList<CustomRoundButtonAdvanced>(
                find.byType(CustomRoundButtonAdvanced))
            .first;
        cancel.fct();
        await tester.pumpAndSettle();
        expect(find.byType(CreateInvoiceModal), findsNothing);
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(tester.widget<CustomDropDownWithSearch<String>>(payment).value,
            'CASH');
        expect(tester.widget<CustomDropDownWithSearch<String>>(status).value,
            'Pending');
        expect(find.byIcon(Icons.delete), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      customers.dispose();
      methods.dispose();
    });
  }

  for (final throws in [false, true]) {
    testWidgets('create lookup failure exits loading safely: throws=$throws',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final customers = _Customers();
      final methods = _Methods();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<CustomerProvider>.value(value: customers),
          ChangeNotifierProvider<MasterDataProvider>.value(value: methods),
          ChangeNotifierProvider<AuthModel>(create: (_) => AuthModel()),
        ],
        child: GetMaterialApp(
          translations: _Translations(),
          locale: const Locale('en'),
          home:
              const Scaffold(body: CreateInvoiceModal(size: Size(1600, 1000))),
        ),
      ));
      await tester.pump();
      if (throws) {
        customers.pending.completeError(StateError('customer lookup failed'));
        methods.pending.completeError(StateError('payment lookup failed'));
      } else {
        customers.pending.complete([]);
        methods.pending.complete(null);
      }
      await tester.pumpAndSettle();
      final dropdowns = tester.widgetList<CustomDropDownWithSearch<String>>(
          find.byType(CustomDropDownWithSearch<String>));
      expect(dropdowns.any((widget) => widget.hintText.contains('Loading')),
          isFalse);
      final payment = tester.widget<CustomDropDownWithSearch<String>>(
          find.byKey(const ValueKey('invoice-create-payment-method')));
      expect(payment.items, isEmpty);
      expect(payment.value, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      customers.dispose();
      methods.dispose();
    });
  }

  testWidgets(
      'create validates, retains inputs on failure, retries and returns success',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final customers = _Customers();
    // The shared listing's current page can contain only unnamed customers.
    // Create must use the complete, independent lookup snapshot instead.
    final visiblePage = [CustomerListModelData(id: 99)];
    customers.customerList = visiblePage;
    customers.pending.complete([
      CustomerListModelData(id: 99),
      CustomerListModelData(id: 3, name: 'Customer'),
    ]);
    final methods = _Methods();
    methods.pending.complete(
        [MasterDataValue(id: 206, value: 'CASH', description: 'Cash')]);
    final invoices = _Invoices();
    invoices.response = {'status': 'failure', 'message': 'Try again'};
    bool? result;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<CustomerProvider>.value(value: customers),
          ChangeNotifierProvider<MasterDataProvider>.value(value: methods),
          ChangeNotifierProvider<InvoiceProvider>.value(value: invoices),
          ChangeNotifierProvider<AuthModel>(
              create: (_) => AuthModel()..login('test-token', 1)),
          ChangeNotifierProvider<SubscriptionProvider>(
              create: (_) => SubscriptionProvider()),
        ],
        child: GetMaterialApp(
          translations: _Translations(),
          locale: const Locale('en'),
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                        child: const Text('Create'),
                        onPressed: () async {
                          result = await showCreateInvoiceModal(
                              context, const Size(1920, 1080));
                        },
                      ))),
        )));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    CustomRoundButtonAdvanced submit() => tester
        .widgetList<CustomRoundButtonAdvanced>(
            find.byType(CustomRoundButtonAdvanced))
        .last;
    await submit().fct();
    await tester.pump();
    expect(invoices.calls, 0);
    final customer = tester
        .widgetList<CustomDropDownWithSearch<String>>(
            find.byType(CustomDropDownWithSearch<String>))
        .firstWhere((w) => w.items.contains('3'));
    expect(customer.displayText('3'), 'Customer');
    expect(identical(customers.customerList, visiblePage), isTrue);
    customer.onChanged('3');
    await tester.pump();
    await submit().fct();
    expect(invoices.calls, 0); // At least one saved item is still required.
    final fields = tester
        .widgetList<TextField>(find.descendant(
            of: find.byType(CreateInvoiceModal),
            matching: find.byType(TextField)))
        .where((w) => w.controller != null)
        .toList();
    expect(fields.length, 5);
    fields[0].controller!.text = 'Weighted item';
    fields[1].controller!.text = '10';
    fields[2].controller!.text = '5';
    fields[3].controller!.text = '1.5';
    fields[3].onSubmitted!('1.5');
    await tester.pump();
    final savedFields = tester
        .widgetList<TextField>(find.descendant(
            of: find.byType(CreateInvoiceModal),
            matching: find.byType(TextField)))
        .where((w) => w.controller != null)
        .toList();
    expect(savedFields.length, 10);
    savedFields[3].controller!.text = '2';
    await tester.pump();
    expect(find.text('21.00'), findsWidgets);
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();
    expect(find.byIcon(Icons.delete), findsNothing);
    await submit().fct();
    expect(invoices.calls, 0);
    // Re-add after deleting the edited row; stale row controllers must not
    // contribute to the amount or the eventual submission.
    fields[0].controller!.text = 'Weighted item';
    fields[1].controller!.text = '10';
    fields[2].controller!.text = '5';
    fields[3].controller!.text = '1.5';
    fields[3].onSubmitted!('1.5');
    await tester.pump();
    await submit().fct();
    await tester.pump();
    expect(invoices.calls, 1);
    expect(result, isNull);
    expect(find.byType(CreateInvoiceModal), findsOneWidget);
    expect(invoices.submitted!['customerId'], 3);
    expect(invoices.submitted!['paymentMethod'], 206);
    expect(invoices.submitted!['type'], 'other');
    expect(invoices.submitted!['status'], 'pending');
    expect(invoices.submitted!['amount'], 15.75);
    expect(invoices.submitted!['invoiceItems'], [
      {
        'item_name': 'Weighted item',
        'unit_amount': 10.0,
        'tax': 5.0,
        'quantity': 1.5,
        'total_amount': 15.75
      }
    ]);
    invoices.pending = Completer<dynamic>();
    final pendingSubmit = submit().fct();
    final duplicateSubmit = submit().fct();
    await tester.pump();
    expect(invoices.calls, 2);
    invoices.pending!.complete({'status': true});
    await pendingSubmit;
    await duplicateSubmit;
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(CreateInvoiceModal), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    customers.dispose();
    methods.dispose();
    invoices.dispose();
  });
}
