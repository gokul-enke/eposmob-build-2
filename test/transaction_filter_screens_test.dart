import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_voucher_provider.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_provider.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/quotations_provider.dart';
import 'package:pos_machine/providers/supplier_voucher_provider.dart';
import 'package:pos_machine/screens/transactions/customer_voucher_list.dart';
import 'package:pos_machine/screens/transactions/expense_list_screen.dart';
import 'package:pos_machine/screens/transactions/invoice_list.dart';
import 'package:pos_machine/screens/transactions/proforma_invoice_list.dart';
import 'package:pos_machine/screens/transactions/receipt_list.dart';
import 'package:pos_machine/screens/transactions/supplier_voucher_list.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/header_actions.dart';

class _FakeQuotationsProvider extends QuotationsProvider {
  @override
  Future<Map<String, dynamic>> fetchProformaInvoices({
    required String accessToken,
    Map<String, String>? filters,
  }) async {
    return {
      'data': {
        'data': <Map<String, dynamic>>[],
        'current_page': 1,
        'last_page': 1,
      },
    };
  }
}

Map<String, String> _englishTranslations() {
  final result = <String, String>{};
  void flatten(Map<String, dynamic> data, String prefix) {
    for (final entry in data.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (entry.value is Map<String, dynamic>) {
        flatten(entry.value, key);
      } else {
        result[key] = entry.value.toString();
      }
    }
  }

  flatten(
      jsonDecode(File('lib/resources/i18n/en.json').readAsStringSync()), '');
  return result;
}

class _TestTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
          ..._englishTranslations(),
          'proforma_invoice.title': 'Proforma Invoice',
          'proforma_invoice.invoice_number_label': 'Invoice Number',
          'proforma_invoice.customer_label': 'Customer',
          'proforma_invoice.status_label': 'Status',
          'proforma_invoice.search_invoice_number_hint': 'Invoice Number',
          'proforma_invoice.name_or_phone_hint': 'Name or Phone',
          'proforma_invoice.hint_all': 'All',
          'proforma_invoice.no_invoices_found': 'No invoices found',
          'proforma_invoice.page_of': 'Page @current of @last',
          'proforma_invoice.show_filters': 'Show Filters',
          'proforma_invoice.hide_filters': 'Hide Filters',
          'general.reset': 'Reset',
          'general.more': 'More',
          'general.print': 'Print',
          'pagination.previous': 'Previous',
          'pagination.page': 'Page',
          'pagination.of': 'of',
          'pagination.next': 'Next',
          'invoice.mobile_list_title': 'Invoice List',
          'invoice.create': 'Create',
          'invoice.filters': 'Filters',
          'invoice.invoice_no': 'Invoice No',
          'invoice.name': 'Name',
          'invoice.phone': 'Phone',
          'invoice.all_zatca_status': 'All ZATCA',
          'invoice.all_status': 'All Status',
          'invoice.no_invoices_found': 'No invoices found',
          'invoice.adjust_search': 'Adjust your filters',
          'receipt.list_title': 'Receipt List',
          'receipt.mobile_create_button': 'Create',
          'receipt.show_filters': 'Show Filters',
          'receipt.hide_filters': 'Hide Filters',
          'receipt.receipt_no_hint': 'Receipt No',
          'receipt.reference_no_hint': 'Reference No',
          'receipt.name_hint': 'Name',
          'receipt.email_hint': 'Email',
          'receipt.phone_hint': 'Phone',
          'receipt.hint_all_status': 'All Status',
          'receipt.hint_all_payment': 'All Payments',
          'receipt.reset_filters_button': 'Reset',
          'receipt.no_receipts_found': 'No receipts found',
          'receipt.try_adjusting_filters': 'Adjust your filters',
          'customer_voucher.mobile_list_title': 'Customer Vouchers',
          'customer_voucher.mobile_create_button': 'Create',
          'customer_voucher.show_filters': 'Show Filters',
          'customer_voucher.hide_filters': 'Hide Filters',
          'customer_voucher.mobile_voucher_no_hint': 'Voucher No',
          'customer_voucher.customer_name_hint': 'Customer',
          'customer_voucher.hint_all_types': 'All Types',
          'customer_voucher.hint_all_status': 'All Status',
          'customer_voucher.reset_filters_button': 'Reset',
          'customer_voucher.no_vouchers_found': 'No vouchers found',
          'customer_voucher.try_adjusting_filters': 'Adjust your filters',
          'supplier_voucher.mobile_header_title': 'Supplier Vouchers',
          'supplier_voucher.mobile_create_button': 'Create',
          'supplier_voucher.show_filters': 'Show Filters',
          'supplier_voucher.hide_filters': 'Hide Filters',
          'supplier_voucher.mobile_voucher_no_hint': 'Voucher No',
          'supplier_voucher.all_suppliers_hint': 'All Suppliers',
          'supplier_voucher.hint_all_types': 'All Types',
          'supplier_voucher.hint_all_status': 'All Status',
          'supplier_voucher.reset_filters_button': 'Reset',
          'supplier_voucher.no_vouchers_found': 'No vouchers found',
          'supplier_voucher.try_adjusting_filters': 'Adjust your filters',
        },
      };
}

void main() {
  setUpAll(() {
    Get.testMode = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() {
    Get.reset();
  });

  Future<void> verifyDesktopFiltersCollapse(
    WidgetTester tester, {
    required Widget screen,
    required Key filterKey,
    Size surfaceSize = const Size(1440, 900),
  }) async {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    if (!Get.isRegistered<SideBarController>()) {
      Get.put(SideBarController());
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthModel()),
          ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
          ChangeNotifierProvider(create: (_) => InvoiceProvider()),
          ChangeNotifierProvider(create: (_) => CustomerVoucherProvider()),
          ChangeNotifierProvider(create: (_) => SupplierVoucherProvider()),
          ChangeNotifierProvider(create: (_) => ExpenseProvider()),
          ChangeNotifierProvider(create: (_) => MasterDataProvider()),
          ChangeNotifierProvider<QuotationsProvider>(
            create: (_) => _FakeQuotationsProvider(),
          ),
        ],
        child: GetMaterialApp(
          translations: _TestTranslations(),
          locale: const Locale('en', 'US'),
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(filterKey), findsOneWidget);
    expect(hasFilterToggle(), isTrue);

    await tapFilterToggle(tester);
    await tester.pump();

    expect(find.byKey(filterKey), findsNothing);
    expect(hasFilterToggle(), isTrue);
  }

  testWidgets('Invoice List collapses its real desktop filter panel',
      (tester) async {
    await verifyDesktopFiltersCollapse(
      tester,
      screen: const InvoiceListScreen(),
      filterKey: const ValueKey('invoice-desktop-filters'),
    );
  });

  testWidgets('Receipt List collapses its real desktop filter panel',
      (tester) async {
    await verifyDesktopFiltersCollapse(
      tester,
      screen: const ReceiptListScreen(),
      filterKey: const ValueKey('receipt-desktop-filters'),
    );
  });

  testWidgets('Customer Voucher collapses its real desktop filter panel',
      (tester) async {
    await verifyDesktopFiltersCollapse(
      tester,
      screen: const CustomerVoucherListScreen(),
      filterKey: const ValueKey('customer-voucher-desktop-filters'),
    );
  });

  testWidgets('Supplier Voucher collapses its real desktop filter panel',
      (tester) async {
    await verifyDesktopFiltersCollapse(
      tester,
      screen: const SupplierVoucherListScreen(),
      filterKey: const ValueKey('supplier-voucher-desktop-filters'),
    );
  });

  testWidgets('Proforma keeps desktop filters usable at 800 px',
      (tester) async {
    await verifyDesktopFiltersCollapse(
      tester,
      screen: const ProformaInvoiceListScreen(),
      filterKey: const ValueKey('proforma-desktop-filters'),
      surfaceSize: const Size(800, 900),
    );
  });

  testWidgets('Expense List collapses its real desktop filter panel',
      (tester) async {
    await verifyDesktopFiltersCollapse(
      tester,
      screen: const ExpenseListScreen(),
      filterKey: const ValueKey('expense-desktop-filters'),
    );
  });

  testWidgets('mobile transaction filters expand without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final screens = <Widget>[
      const InvoiceListScreen(),
      const ReceiptListScreen(),
      const CustomerVoucherListScreen(),
      const SupplierVoucherListScreen(),
    ];
    final failures = <String>[];

    for (final screen in screens) {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthModel()),
            ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
            ChangeNotifierProvider(create: (_) => InvoiceProvider()),
            ChangeNotifierProvider(create: (_) => CustomerVoucherProvider()),
            ChangeNotifierProvider(create: (_) => SupplierVoucherProvider()),
            ChangeNotifierProvider(create: (_) => ExpenseProvider()),
            ChangeNotifierProvider(create: (_) => MasterDataProvider()),
            ChangeNotifierProvider<QuotationsProvider>(
              create: (_) => _FakeQuotationsProvider(),
            ),
          ],
          child: GetMaterialApp(
            translations: _TestTranslations(),
            locale: const Locale('en', 'US'),
            home: Scaffold(body: screen),
          ),
        ),
      );
      await tester.pump();

      if (hasFilterToggle()) {
        expect(hasFilterToggle(), isTrue);
        await tapFilterToggle(tester);
      } else {
        expect(find.byType(ExpansionTile), findsOneWidget);
        await tester.tap(find.byType(ExpansionTile));
      }
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      if (exception != null) {
        failures.add('${screen.runtimeType}: $exception');
      }
    }

    expect(failures, isEmpty);
  });
}
