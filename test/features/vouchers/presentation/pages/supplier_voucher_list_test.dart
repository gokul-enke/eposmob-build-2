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
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/vouchers/domain/models/supplier_voucher.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/features/vouchers/presentation/state/supplier_voucher_provider.dart';
import 'package:pos_machine/features/vouchers/presentation/pages/supplier_voucher_list_page.dart';
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

/// Delivery stand-in: records the exported file instead of opening Save As
/// or the share sheet.
class _Delivery {
  final files = <File>[];

  Future<void> call(BuildContext context, File file,
      {required String mimeType,
      String? shareText,
      Rect? shareOrigin,
      ValueChanged<String>? onStage}) async {
    files.add(file);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({'api_key': 'test'});
  });
  tearDown(() => Get.reset());

  Future<_Provider> mount(WidgetTester tester, Size size,
      {ExportController? export}) async {
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
            home: Scaffold(body: SupplierVoucherListPage(export: export)))));
    await tester.pumpAndSettle();
    return provider;
  }

  /// Taps a header action, opening the "more" menu first on narrow headers.
  Future<void> tapHeaderAction(
      WidgetTester tester, Key key, String menuLabel) async {
    if (find.byKey(key).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(key));
    } else {
      await tester.tap(find.byKey(PageHeader.moreActionsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(menuLabel).last);
    }
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(1440, 900),
    const Size(800, 900),
    const Size(375, 812),
    const Size(375, 300)
  ]) {
    testWidgets('shared voucher layout, export and actions fit $size',
        (tester) async {
      await mount(tester, size);
      final layout = tester.widget<ListPageScaffold<SupplierVoucher>>(
          find.byType(ListPageScaffold<SupplierVoucher>));
      expect(layout.minTableWidth, 1280);
      if (size.width < PageHeader.collapseActionsBelow) {
        // Filters, Export and Refresh fold into the "more" menu.
        expect(find.byKey(PageHeader.moreActionsKey), findsOneWidget);
      } else {
        expect(find.byKey(SupplierVoucherListPage.exportKey), findsOneWidget);
        expect(
            tester
                .widget<AppSquareIconButton>(
                    find.byKey(SupplierVoucherListPage.exportKey))
                .onPressed,
            isNotNull);
      }
      expect(find.byIcon(Icons.visibility_outlined), findsWidgets);
      expect(find.byIcon(Icons.print_outlined), findsWidgets);
      expect(find.byIcon(Icons.share_outlined), findsWidgets);
      if (size.width < 700) {
        expect(find.byKey(SupplierVoucherListPage.filtersKey), findsNothing);
        await tapHeaderAction(
            tester, SupplierVoucherListPage.filterToggleKey, 'Show Filters');
      }
      expect(find.byKey(SupplierVoucherListPage.filtersKey), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'export contains all filtered pages, numeric money and text references without fetching',
      (tester) async {
    final delivery = _Delivery();
    final export = ExportController(deliver: delivery.call);
    final provider = await mount(tester, const Size(1440, 900), export: export);
    await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
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
    await tester.runAsync(() async {
      tester
          .widget<AppSquareIconButton>(
              find.byKey(SupplierVoucherListPage.exportKey))
          .onPressed!();
      // The file is written on a real isolate; wait for the export to end.
      for (var i = 0; i < 200 && export.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(delivery.files, hasLength(1));
    final rows = Excel.decodeBytes(delivery.files.single.readAsBytesSync())
        .tables
        .values
        .single
        .rows;
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
            .widget<DropdownButtonFormField<String?>>(
                find.byType(DropdownButtonFormField<String?>).first)
            .initialValue,
        isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('typing a voucher number is debounced and Enter applies it',
      (tester) async {
    final provider = await mount(tester, const Size(1440, 900));
    await tester.enterText(find.byType(TextField), '0001');
    await tester.pump(const Duration(milliseconds: 100));
    expect(provider.filteredVouchers.length, 30);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(provider.filteredVouchers.length, lessThan(30));
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
    await tester.tap(find.byKey(SupplierVoucherListPage.filterToggleKey));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(SupplierVoucherListPage.filtersKey), findsNothing);
    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byType(CommonDetailsDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
