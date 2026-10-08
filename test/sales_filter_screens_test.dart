import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/models/day_close_pending_status.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/app_translations.dart';
import 'package:pos_machine/resources/localization_service.dart';
import 'package:pos_machine/screens/sales/daily_sales_close_list.dart';
import 'package:pos_machine/screens/sales/sales.dart';
import 'package:pos_machine/features/sales/presentation/pages/sales_list_page.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSalesProvider extends SalesProvider {
  @override
  Future<void> fetchOrders({
    required String accessToken,
    int? storeId,
    String? orderNumber,
    String? filterName,
    String? date,
    String? from,
    String? until,
    String? businessDate,
    int? customerId,
    int? productId,
    String? filterStatus,
    String? filterPrice,
    String? filterEmail,
    String? filterPhone,
    String? filterStore,
    String? filterCreatedBy,
    int? page,
    bool? filterOnlineSales,
  }) async {}

  @override
  Future<void> fetchDailySalesClose({
    required String accessToken,
    String? startDate,
    String? endDate,
    int page = 1,
    int? userId,
    required int storeId,
  }) async {}

  @override
  Future<DayClosePendingStatus?> fetchDayClosePendingStatus({
    required String accessToken,
    required int storeId,
    required int userId,
  }) async =>
      null;
}

void main() {
  setUpAll(() {
    Get.testMode = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrapScreen(Widget screen) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthModel()),
        ChangeNotifierProvider<SalesProvider>(
          create: (_) => _FakeSalesProvider(),
        ),
        ChangeNotifierProvider(create: (_) => StoreSessionProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => MasterDataProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
      ],
      child: GetMaterialApp(
        translations: AppTranslations(LocalizationService.translations),
        locale: const Locale('en'),
        fallbackLocale: LocalizationService.fallbackLocale,
        home: Scaffold(body: screen),
      ),
    );
  }

  Future<void> verifyMobileToggle(
    WidgetTester tester, {
    required Widget screen,
    required Key toggleKey,
    required Key filtersKey,
  }) async {
    tester.view.physicalSize = const Size(390, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapScreen(screen));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(toggleKey), findsOneWidget);
    expect(find.byType(FilterToggleButton), findsOneWidget);
    expect(find.byKey(filtersKey), findsNothing);

    await tester.tap(find.byKey(toggleKey));
    await tester.pump();

    expect(find.byKey(filtersKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  Future<void> verifyDesktopToggle(
    WidgetTester tester, {
    required Widget screen,
    required Key toggleKey,
    required Key filtersKey,
  }) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapScreen(screen));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(toggleKey), findsOneWidget);
    expect(find.byType(FilterToggleButton), findsOneWidget);
    expect(find.byKey(filtersKey), findsOneWidget);

    await tester.tap(find.byKey(toggleKey));
    await tester.pump();

    expect(find.byKey(filtersKey), findsNothing);
    expect(tester.takeException(), isNull);
  }

  for (final online in [false, true]) {
    for (final width in [390.0, 1600.0]) {
      testWidgets(
          'Sales compatibility entry uses shared filters online=$online width=$width',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(wrapScreen(SalesScreen(isOnlineSales: online)));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<SalesListPage>(find.byType(SalesListPage))
                .isOnlineSales,
            online);
        final scaffold = find.byWidgetPredicate((w) => w is ListPageScaffold);
        expect(scaffold, findsOneWidget);
        final header = find.byKey(SalesListPage.filterKey);
        expect(find.byType(FilterToggleButton), findsNothing);
        if (width < 700) {
          expect(find.byType(CollapsibleFilterTile), findsNothing);
          await tester.tap(find.byKey(PageHeader.moreActionsKey));
          await tester.pumpAndSettle();
          await tester.tap(find.byWidgetPredicate(
              (w) => w is PopupMenuItem<int> && w.value == 0));
          await tester.pumpAndSettle();
          expect(find.byType(CollapsibleFilterTile), findsOneWidget);
          await tester.tap(find.byType(ExpansionTile));
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsNWidgets(4));
        } else {
          expect(find.byType(FilterPanel), findsOneWidget);
          await tester.tap(header);
          await tester.pumpAndSettle();
          expect(find.byType(FilterPanel), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('Day Close uses the shared filter toggle on mobile',
      (tester) async {
    await verifyMobileToggle(
      tester,
      screen: const DailySalesCloseListScreen(),
      toggleKey: const ValueKey('day-close-filter-toggle'),
      filtersKey: const ValueKey('day-close-filters'),
    );
  });

  testWidgets('Day Close uses the shared filter toggle on desktop',
      (tester) async {
    await verifyDesktopToggle(
      tester,
      screen: const DailySalesCloseListScreen(),
      toggleKey: const ValueKey('day-close-filter-toggle'),
      filtersKey: const ValueKey('day-close-filters'),
    );
  });
}
