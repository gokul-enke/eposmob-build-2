import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pos_machine/features/sales/presentation/pages/admin_daily_sales_close_list_page.dart';
import 'package:pos_machine/features/sales/presentation/pages/daily_sales_close_detail_page.dart';
import 'package:pos_machine/features/sales/presentation/pages/sales_order_details_page.dart';
import 'package:pos_machine/features/sales/presentation/widgets/closing/open_shift_modal.dart';
import 'package:pos_machine/features/sales/presentation/widgets/closing/day_close_modal.dart';
import 'package:pos_machine/features/sales/domain/models/daily_sales_close.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pos_machine/components/filter_toggle_button.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_provider.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';
import 'package:pos_machine/features/sales/domain/models/day_close_pending_status.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/features/sales/presentation/pages/daily_sales_close_list_page.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/features/sales/presentation/pages/sales_list_page.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/app_translations.dart';
import 'package:pos_machine/resources/localization_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMaster extends MasterDataProvider {
  @override
  Future<List<MasterDataValue>?> fetchCashDenominations(
          {bool forceRefresh = false}) async =>
      [];
}

class _FakeExecutives extends SalesExecutiveProvider {
  @override
  Future<void> fetchSalesExecutives(BuildContext context) async {}
}

class _FakeSalesProvider extends SalesProvider {
  _FakeSalesProvider([this.rows = const []]);
  final List<ListOrderModelData> rows;
  @override
  Future<dynamic> listOrderDetails(
          BuildContext context, String orderNumber, String accessToken) async =>
      {'status': 'failed', 'message': 'Order unavailable'};
  @override
  Future<DailySalesCloseSummary?> fetchDailySalesCloseSummary(
          {required String accessToken,
          required int storeId,
          String? businessDate}) async =>
      DailySalesCloseSummary();
  @override
  List<ListOrderModelData> get orders => rows;

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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting();
    await LocalizationService.init();
    final poppins = FontLoader('Poppins');
    for (final file in ['Regular', 'Medium', 'SemiBold']) {
      poppins.addFont(rootBundle.load('assets/fonts/Poppins-$file.ttf'));
    }
    await poppins.load();
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final packages = config['packages'] as List<dynamic>;
    final flutter = packages
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['name'] == 'flutter');
    final packageRoot = configFile.uri.resolve('${flutter['rootUri']}/');
    final fontRoot =
        packageRoot.resolve('../../bin/cache/artifacts/material_fonts/');
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf'
    }.entries) {
      final loader = FontLoader(entry.key);
      loader.addFont(File.fromUri(fontRoot.resolve(entry.value))
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)));
      await loader.load();
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrapScreen(Widget screen, {List<ListOrderModelData> rows = const []}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthModel()),
        ChangeNotifierProvider<SalesProvider>(
          create: (_) => _FakeSalesProvider(rows),
        ),
        ChangeNotifierProvider(create: (_) => StoreSessionProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider<MasterDataProvider>(
            create: (_) => _FakeMaster()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider<SalesExecutiveProvider>(
            create: (_) => _FakeExecutives()),
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
    tester.view.physicalSize = const Size(375, 812);
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
    tester.view.physicalSize = const Size(1440, 900);
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
          'Sales list uses shared filters online=$online width=$width',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(wrapScreen(SalesListPage(isOnlineSales: online)));
        await tester.pumpAndSettle();
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
          expect(find.byType(TextField), findsNWidgets(5));
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
      screen: const DailySalesCloseListPage(),
      toggleKey: const ValueKey('day-close-filter-toggle'),
      filtersKey: const ValueKey('day-close-filters'),
    );
  });

  testWidgets('Day Close uses the shared filter toggle on desktop',
      (tester) async {
    await verifyDesktopToggle(
      tester,
      screen: const DailySalesCloseListPage(),
      toggleKey: const ValueKey('day-close-filter-toggle'),
      filtersKey: const ValueKey('day-close-filters'),
    );
  });
  for (final width in [375.0, 1440.0]) {
    final screens = <String, Widget Function()>{
      'admin closing list': () => const AdminDailySalesCloseListPage(),
      'empty closing detail': () => const DailySalesCloseDetailPage(),
      'failed order detail': () => const SalesOrderDetailsPage(),
      'open shift form': () => OpenShiftModal(onSuccess: () {}),
      'day close form': () => DayCloseModal(onSuccess: () {}),
    };
    for (final entry in screens.entries) {
      testWidgets('${entry.key} mounts and disposes at $width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(wrapScreen(entry.value()));
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
