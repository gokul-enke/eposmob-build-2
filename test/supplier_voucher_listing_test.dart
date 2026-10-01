import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/components/export_share_button.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/core/ui/list_page/list_page_scaffold.dart';
import 'package:pos_machine/models/supplier_voucher.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/supplier_voucher_provider.dart';
import 'package:pos_machine/screens/transactions/supplier_voucher_list.dart';
import 'package:pos_machine/screens/transactions/widgets/common_details_dialog.dart';

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

Map<String, Object?> _voucher(int id) => {
      'id': id,
      'voucher_number': '000$id',
      'voucher_date': '2026-10-01',
      'due_date': '2026-11-01',
      'amount': '126.125',
      'type': id <= 25 ? 'order' : 'refund',
      'status': id <= 25 ? 'paid' : 'pending',
      'payment_method': 'cash',
      'supplier': {
        'id': id <= 25 ? 7 : 8,
        'user': {'name': id <= 25 ? 'Test Supplier' : 'Other Supplier'}
      },
    };

class _Provider extends SupplierVoucherProvider {
  int requests = 0;
  bool failSecond = false;
  bool onlyOtherSupplier = false;
  @override
  Future<void> listAllSupplierVouchers({required String accessToken}) =>
      http.runWithClient(
          () => super.listAllSupplierVouchers(accessToken: accessToken),
          () => MockClient((request) async {
                requests++;
                final page = int.parse(request.url.queryParameters['page']!);
                if (failSecond && page == 2) {
                  return http.Response('failed', 500);
                }
                if (onlyOtherSupplier) {
                  return http.Response(
                      jsonEncode({
                        'status': 'success',
                        'data': {
                          'current_page': 1,
                          'last_page': 1,
                          'data': [for (int i = 26; i <= 30; i++) _voucher(i)]
                        }
                      }),
                      200);
                }
                return http.Response(
                    jsonEncode({
                      'status': 'success',
                      'data': {
                        'current_page': page,
                        'last_page': 2,
                        'data': [
                          for (int i = page == 1 ? 1 : 21;
                              i <= (page == 1 ? 20 : 30);
                              i++)
                            _voucher(i)
                        ]
                      }
                    }),
                    200);
              }));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({'api_key': 'test'});
  });
  tearDown(() => Get.reset());

  test('all four filters and pagination use the same full cached export rows',
      () async {
    final provider = _Provider();
    await provider.listAllSupplierVouchers(accessToken: 'test');
    expect(provider.filteredVouchers.length, 30);
    expect(provider.voucherListDetails!.length, 20);
    provider.applyFilters(
        supplierId: 7, type: 'order', status: 'paid', voucherNumber: '000');
    expect(provider.filteredVouchers.length, 25);
    provider.goToPage(2);
    expect(provider.voucherListDetails!.length, 5);
    expect(provider.filteredVouchers.length, 25);
    expect(provider.requests, 2);
    provider.resetFilters();
    expect(provider.filteredVouchers.length, 30);
    expect(provider.currentPage, 1);
    expect(() => provider.filteredVouchers.clear(), throwsUnsupportedError);
  });
  test('refresh retains filters and failed later pages clear export rows',
      () async {
    final provider = _Provider();
    await provider.listAllSupplierVouchers(accessToken: 'test');
    provider.applyFilters(type: 'refund');
    await provider.listAllSupplierVouchers(accessToken: 'test');
    expect(provider.filteredVouchers.length, 5);
    provider.failSecond = true;
    await provider.listAllSupplierVouchers(accessToken: 'test');
    expect(provider.filteredVouchers, isEmpty);
    expect(provider.voucherListDetails, isEmpty);
    expect(provider.loadError, isA<HttpException>());
    expect(provider.isLoading, isFalse);
  });
  test('missing tenant releases loading and exposes the load error', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = _Provider();
    await provider.listAllSupplierVouchers(accessToken: 'test');
    expect(provider.requests, 0);
    expect(provider.isLoading, isFalse);
    expect(provider.loadError, isNotNull);
  });

  test('overlapping refreshes share a single request and loading lifetime',
      () async {
    final provider = SupplierVoucherProvider();
    final started = Completer<void>();
    final response = Completer<http.Response>();
    int requests = 0;
    await http.runWithClient(() async {
      final first = provider.listAllSupplierVouchers(accessToken: 'test');
      await started.future;
      final second = provider.listAllSupplierVouchers(accessToken: 'test');
      expect(identical(first, second), isTrue);
      expect(provider.isLoading, isTrue);
      expect(requests, 1);
      response.complete(http.Response(
          jsonEncode({
            'status': 'success',
            'data': [_voucher(1)]
          }),
          200));
      await Future.wait([first, second]);
      expect(provider.isLoading, isFalse);
      expect(provider.filteredVouchers.length, 1);
      await provider.listAllSupplierVouchers(accessToken: 'test');
      expect(requests, 2);
    },
        () => MockClient((_) {
              requests++;
              if (!started.isCompleted) started.complete();
              return response.future;
            }));
  });

  for (final entry in <String, Object?>{
    'failed response status': {
      'status': 'failed',
      'data': {
        'current_page': 2,
        'last_page': 2,
        'data': [_voucher(21)]
      }
    },
    'missing data': {'status': 'success'},
    'empty later page': {
      'status': 'success',
      'data': {'current_page': 2, 'last_page': 2, 'data': []}
    },
    'wrong page number': {
      'status': 'success',
      'data': {
        'current_page': 1,
        'last_page': 2,
        'data': [_voucher(21)]
      }
    },
    'changed page count': {
      'status': 'success',
      'data': {
        'current_page': 2,
        'last_page': 3,
        'data': [_voucher(21)]
      }
    },
    'invalid row': {
      'status': 'success',
      'data': {
        'current_page': 2,
        'last_page': 2,
        'data': ['bad']
      }
    },
    'duplicate voucher': {
      'status': 'success',
      'data': {
        'current_page': 2,
        'last_page': 2,
        'data': [_voucher(1)]
      }
    },
  }.entries) {
    test(
        'rejects HTTP 200 with ${entry.key} instead of exposing partial export',
        () async {
      final provider = SupplierVoucherProvider();
      await http.runWithClient(
          () => provider.listAllSupplierVouchers(accessToken: 'test'),
          () => MockClient((request) async => http.Response(
              jsonEncode(request.url.queryParameters['page'] == '1'
                  ? {
                      'status': 'success',
                      'data': {
                        'current_page': 1,
                        'last_page': 2,
                        'data': [_voucher(1)]
                      }
                    }
                  : entry.value),
              200)));
      expect(provider.loadError, isA<FormatException>());
      expect(provider.filteredVouchers, isEmpty);
      expect(provider.isLoading, isFalse);
    });
  }
  test('flat and paginated empty successful responses are valid', () async {
    for (final data in [
      [],
      {'current_page': 1, 'last_page': 1, 'data': []}
    ]) {
      final provider = SupplierVoucherProvider();
      await http.runWithClient(
          () => provider.listAllSupplierVouchers(accessToken: 'test'),
          () => MockClient((_) async => http.Response(
              jsonEncode({'status': 'success', 'data': data}), 200)));
      expect(provider.loadError, isNull);
      expect(provider.filteredVouchers, isEmpty);
    }
  });

  Future<_Provider> mount(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _Provider();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthModel>(
              create: (_) => AuthModel()..login('test', 1)),
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => AppSettingsProvider()),
          ChangeNotifierProvider<SupplierVoucherProvider>.value(
              value: provider),
        ],
        child: GetMaterialApp(
            translations: _Translations(),
            locale: const Locale('en'),
            home: const Scaffold(body: SupplierVoucherListScreen()))));
    await tester.pumpAndSettle();
    return provider;
  }

  for (final size in [
    const Size(1440, 900),
    const Size(800, 900),
    const Size(390, 800),
    const Size(375, 300)
  ]) {
    testWidgets('shared voucher layout, export and actions fit $size',
        (tester) async {
      await mount(tester, size);
      final layout = tester.widget<ListPageScaffold<SupplierVoucher>>(
          find.byType(ListPageScaffold<SupplierVoucher>));
      expect(layout.tableMinWidth, 1280);
      expect(find.byType(ExportShareButton), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsWidgets);
      expect(find.byIcon(Icons.print_outlined), findsWidgets);
      expect(find.byIcon(Icons.share_outlined), findsWidgets);
      if (size.width < 700) {
        await tester.tap(find.byType(FilterToggleButton));
        await tester.pumpAndSettle();
      }
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'export contains all filtered pages, numeric money and text references without fetching',
      (tester) async {
    final provider = await mount(tester, const Size(1440, 900));
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '000');
    await tester.pump(const Duration(milliseconds: 100));
    provider.goToPage(2);
    await tester.pump();
    final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('voucher-export-test-')))!;
    addTearDown(() => directory.delete(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final button =
        tester.widget<ExportShareButton>(find.byType(ExportShareButton));
    final file = await tester.runAsync(button.createFile);
    final rows =
        Excel.decodeBytes(file!.readAsBytesSync()).tables.values.single.rows;
    expect(rows.length, 26);
    expect(rows[1][0]!.value, TextCellValue('0001'));
    expect(rows[1][6]!.value, const DoubleCellValue(126.125));
    expect(provider.requests, 2);
    await tester.pump(const Duration(milliseconds: 500));
    expect(provider.currentPage, 2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(provider.filteredVouchers.length, 30);
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>).first)
            .initialValue,
        isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('refresh clears a supplier selection missing from refreshed data',
      (tester) async {
    final provider = await mount(tester, const Size(1440, 900));
    tester
        .widget<DropdownSearch<int>>(find.byType(DropdownSearch<int>))
        .onChanged!(7);
    await tester.pumpAndSettle();
    expect(provider.filteredVouchers.length, 25);
    provider.onlyOtherSupplier = true;
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DropdownSearch<int>>(find.byType(DropdownSearch<int>))
            .selectedItems,
        [0]);
    expect(provider.filteredVouchers.length, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('voucher details and filter toggle remain available',
      (tester) async {
    await mount(tester, const Size(1440, 900));
    await tester.tap(find.byType(FilterToggleButton));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byType(CommonDetailsDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
