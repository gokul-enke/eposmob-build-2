import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/screens/transactions/proforma_invoice_list/proforma_row_actions.dart';
import 'package:pos_machine/screens/transactions/widgets/common_details_dialog.dart';
import 'package:provider/provider.dart';

class _Translations extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final result = <String, Map<String, String>>{};
    for (final locale in ['en', 'ar', 'ml']) {
      final flat = <String, String>{};
      void flatten(Map<String, dynamic> map, String prefix) {
        for (final entry in map.entries) {
          final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
          if (entry.value is Map<String, dynamic>) {
            flatten(entry.value, key);
          } else {
            flat[key] = entry.value.toString();
          }
        }
      }

      flatten(
          jsonDecode(
              File('lib/resources/i18n/$locale.json').readAsStringSync()),
          '');
      result[locale] = flat;
    }
    return result;
  }
}

Map<String, dynamic> _details() => {
      'invoice_number': 'PF-00042',
      'status': 'pending',
      'amount': '15.750',
      'invoice_date': '2026-10-12',
      'due_date': '2026-11-11',
      'customer': {'name': 'Demo customer', 'phone': '0123456789'},
      'quotation': {'quotation_number': 'Q-00021'},
      'items': [
        {
          'item_name': 'Demo item',
          'quantity': 1.5,
          'unit_amount': '10.000',
          'total_amount': '15.750'
        }
      ],
    };

class _Provider extends QuotationsProvider {
  final calls = <({String token, dynamic id})>[];
  Future<Map<String, dynamic>> Function()? handler;

  @override
  Future<Map<String, dynamic>> fetchProformaInvoiceDetails(
      {required String accessToken, required dynamic invoiceId}) {
    calls.add((token: accessToken, id: invoiceId));
    return handler?.call() ?? Future.value({'data': _details()});
  }
}

class _Host extends StatefulWidget {
  const _Host({this.id = '00042'});
  final dynamic id;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with ProformaRowActions<_Host> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          onPressed: () => showProformaDetails({'id': widget.id}),
          child: const Text('Open details'),
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<_Provider> mount(WidgetTester tester,
      {_Provider? provider,
      dynamic id = '00042',
      String? token = 'demo-token',
      Size size = const Size(1440, 900),
      String locale = 'en'}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = provider ?? _Provider();
    final auth = AuthModel();
    if (token != null) auth.login(token, 1);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider<QuotationsProvider>.value(value: p)
      ],
      child: GetMaterialApp(
          translations: _Translations(),
          locale: Locale(locale),
          home: _Host(id: id)),
    ));
    await tester.pumpAndSettle();
    return p;
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'View preserves token, string ID, response values and close/reopen',
      (tester) async {
    final p = await mount(tester);
    await open(tester);
    expect(p.calls.single, (token: 'demo-token', id: '00042'));
    expect(find.byType(CommonDetailsDialog), findsOneWidget);
    for (final text in [
      'PF-00042',
      'Demo customer',
      '0123456789',
      'Q-00021',
      '2026-10-12',
      '2026-11-11',
      '1.5',
      '10.000',
      'Demo item'
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.text('15.750'), findsNWidgets(2));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(CommonDetailsDialog), findsNothing);
    await open(tester);
    expect(p.calls.length, 2);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(CommonDetailsDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing ID gives feedback without requesting details',
      (tester) async {
    final p = await mount(tester, id: null);
    await open(tester);
    expect(p.calls, isEmpty);
    expect(
        find.text('proforma_invoice.invoice_id_not_found'.tr), findsOneWidget);
    expect(find.byType(CommonDetailsDialog), findsNothing);
  });

  testWidgets('missing token retains the empty token provider contract',
      (tester) async {
    final p = await mount(tester, token: null, id: 42);
    await open(tester);
    expect(p.calls.single, (token: '', id: 42));
  });

  for (final value in [null, [], 'invalid']) {
    testWidgets('invalid details payload shows existing feedback: $value',
        (tester) async {
      final p = _Provider()..handler = () async => {'data': value};
      await mount(tester, provider: p);
      await open(tester);
      expect(
          find.text('proforma_invoice.details_not_found'.tr), findsOneWidget);
      expect(find.byType(CommonDetailsDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('provider failure gives feedback and subsequent View recovers',
      (tester) async {
    final p = _Provider()..handler = () async => throw StateError('failed');
    await mount(tester, provider: p);
    await open(tester);
    expect(
        find.text('proforma_invoice.failed_load_details'.tr), findsOneWidget);
    p.handler = null;
    await open(tester);
    expect(find.byType(CommonDetailsDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final failure in [false, true]) {
    testWidgets('completion after leaving page is ignored: failure=$failure',
        (tester) async {
      final result = Completer<Map<String, dynamic>>();
      final p = _Provider()..handler = () => result.future;
      await mount(tester, provider: p);
      await tester.tap(find.text('Open details'));
      await tester.pump();
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Other page'))));
      if (failure) {
        result.completeError(StateError('failed'));
      } else {
        result.complete({'data': _details()});
      }
      await tester.pumpAndSettle();
      expect(find.byType(CommonDetailsDialog), findsNothing);
      expect(find.text('Other page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('generic maps and missing sections retain fallback values',
      (tester) async {
    final p = _Provider()
      ..handler = () async => {
            'data': <dynamic, dynamic>{
              'invoice_number': ' PF-00042 ',
              'customer': null,
              'quotation': false,
              'items': 'not a list'
            }
          };
    await mount(tester, provider: p);
    await open(tester);
    expect(find.text('PF-00042'), findsOneWidget);
    expect(find.text('-'), findsWidgets);
    expect(find.text('proforma_invoice.no_items_found'.tr), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-map item retains blank row fallback', (tester) async {
    final p = _Provider()
      ..handler = () async => {
            'data': {
              ..._details(),
              'items': [
                null,
                {'item_name': 'Valid item'}
              ]
            }
          };
    await mount(tester, provider: p);
    await open(tester);
    expect(find.text('Valid item'), findsOneWidget);
    expect(find.text('-'), findsNWidgets(7));
    expect(tester.takeException(), isNull);
  });

  for (final section in ['customer', 'quotation', 'data']) {
    testWidgets('non-string map keys follow existing error path: $section',
        (tester) async {
      final badMap = <dynamic, dynamic>{42: 'bad key'};
      final p = _Provider()
        ..handler = () async => {
              'data':
                  section == 'data' ? badMap : {..._details(), section: badMap}
            };
      await mount(tester, provider: p);
      await open(tester);
      expect(
          find.text('proforma_invoice.failed_load_details'.tr), findsOneWidget);
      expect(find.byType(CommonDetailsDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(1440, 900),
    const Size(800, 900),
    const Size(390, 800)
  ]) {
    testWidgets('details fields and item table fit $size', (tester) async {
      await mount(tester, size: size);
      await open(tester);
      expect(find.byType(CommonDetailsDialog), findsOneWidget);
      expect(find.text('Demo item'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('many items remain scrollable and Close stays available',
      (tester) async {
    final p = _Provider()
      ..handler = () async => {
            'data': {
              ..._details(),
              'items': List.generate(
                  40,
                  (i) => {
                        'item_name': 'Item $i',
                        'quantity': 1,
                        'unit_amount': '2.000',
                        'total_amount': '2.000'
                      })
            }
          };
    await mount(tester, provider: p);
    await open(tester);
    // Reveal the last row through both nested scrollable regions.
    await tester.ensureVisible(find.text('Item 39'));
    await tester.pumpAndSettle();
    expect(find.text('Item 39').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(CommonDetailsDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['en', 'ar', 'ml']) {
    testWidgets('existing details labels render in $locale', (tester) async {
      await mount(tester, locale: locale);
      await open(tester);
      expect(find.text('proforma_invoice.details_title'.tr), findsOneWidget);
      expect(find.text('common_details_dialog.close'.tr), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
