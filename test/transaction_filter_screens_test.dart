import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/customer_voucher_provider.dart';
import 'package:pos_machine/providers/expense_provider.dart';
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

class _TestTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
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
    expect(find.byType(FilterToggleButton), findsOneWidget);

    await tester.tap(find.byType(FilterToggleButton));
    await tester.pump();

    expect(find.byKey(filterKey), findsNothing);
    expect(find.byType(FilterToggleButton), findsOneWidget);
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
}
