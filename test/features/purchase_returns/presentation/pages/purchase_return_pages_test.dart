import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/features/purchase_returns/data/purchase_return_repository.dart';
import 'package:pos_machine/features/purchase_returns/domain/models/purchase_return.dart';
import 'package:pos_machine/features/purchase_returns/presentation/pages/purchase_return_list_page.dart';
import 'package:pos_machine/features/purchase_returns/presentation/pages/create_purchase_return_page.dart';
import 'package:pos_machine/features/purchase_returns/presentation/pages/purchase_return_details_page.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/models/purchase_order_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import '../../../../test_support/app_translations.dart';

final summary = PurchaseReturnData(
    id: 9,
    reference: 'RET-9',
    voucherNumber: 'PV-1',
    supplier: SimpleSupplier(name: 'Supplier'),
    returnDate: '2026-09-30',
    totalAmount: 10,
    paidAmount: 10,
    status: 'completed',
    items: [
      PurchaseReturnItemData(productName: 'Item', quantity: 2, amount: 10)
    ]);

class _Repository extends PurchaseReturnRepository {
  int? submittedVoucher;
  List<Map<String, dynamic>>? submittedItems;
  @override
  Future<ListPurchaseReturnData> fetchPage(
          {required String accessToken,
          int? page,
          String? supplierId,
          String? dateFrom,
          String? dateTo}) async =>
      ListPurchaseReturnData(
          currentPage: page ?? 1, lastPage: 2, data: [summary]);
  @override
  Future<ListPurchaseOrderData> fetchVouchers(
          {required String accessToken, int page = 1}) async =>
      ListPurchaseOrderData(currentPage: page, lastPage: 1, data: [
        PurchaseOrderData(
            id: 1,
            voucherNumber: 'PV-1',
            supplier: SimpleSupplier(name: 'Supplier'),
            purchaseDate: '2026-09-30',
            amountTotal: '10.00')
      ]);
  @override
  Future<ReturnableItemsData?> fetchItems(
          {required String accessToken,
          required int purchaseVoucherId}) async =>
      ReturnableItemsData(items: [
        ReturnableItem(
            purchaseItemId: 12,
            productName: 'Item',
            unitPrice: 5,
            returnableQuantity: 2)
      ]);
  @override
  Future<PurchaseReturnData?> fetchDetails(
          {required String accessToken, required int returnId}) async =>
      summary;
  @override
  Future<Map<String, dynamic>> create(
      {required String accessToken,
      required int purchaseVoucherId,
      required String returnDate,
      required List<Map<String, dynamic>> items,
      bool hasPayment = false,
      double? paidAmount,
      String? paymentMethod}) async {
    submittedVoucher = purchaseVoucherId;
    submittedItems = items;
    return {'status': 'success'};
  }
}

class _Purchases extends PurchaseProvider {
  _Purchases(_Repository repository)
      : super(purchaseReturnRepository: repository);
  @override
  Future<void> listAllSuppliers(
      String accessToken, String? supplierName) async {}
}

class _Settings extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

class _Master extends MasterDataProvider {
  @override
  Future<List<MasterDataValue>?> fetchPaymentMethods(
          {bool forceRefresh = false}) async =>
      [];
}

class _Roles extends RoleProvider {
  @override
  bool currentUserHasPermissionSync(String permission) => true;
}

void main() {
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({'api_key': 'tenant'});
  });
  tearDown(Get.reset);
  Future<_Repository> pump(WidgetTester tester, Widget page, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();
    final auth = AuthModel()..login('token', 1);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthModel>.value(value: auth),
          ChangeNotifierProvider<PurchaseProvider>(
              create: (_) => _Purchases(repository)),
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => _Settings()),
          ChangeNotifierProvider<MasterDataProvider>(create: (_) => _Master()),
          ChangeNotifierProvider<RoleProvider>(create: (_) => _Roles()),
        ],
        child: GetMaterialApp(
            translations: EnglishTranslations(),
            locale: const Locale('en', 'US'),
            home: Scaffold(body: page))));
    await tester.pumpAndSettle();
    return repository;
  }

  for (final size in [const Size(375, 812), const Size(1440, 900)]) {
    testWidgets('list at $size retains filters, rows, details and pagination',
        (tester) async {
      await pump(tester, const PurchaseReturnListPage(), size);
      expect(find.text('RET-9'), findsOneWidget);
      expect(find.byKey(const ValueKey('purchase-return-create-action')),
          findsOneWidget);
      final panel = find.byKey(const ValueKey('purchase-return-filters'));
      expect(panel, size.width < 600 ? findsNothing : findsOneWidget);
      await tester
          .tap(find.byKey(const ValueKey('purchase-return-filter-toggle')));
      await tester.pumpAndSettle();
      expect(panel, size.width < 600 ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
      if (size.width < 600) {
        await tester
            .tap(find.byKey(const ValueKey('purchase-return-filter-toggle')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byIcon(Icons.visibility).first);
      await tester.pumpAndSettle();
      expect(find.byType(PurchaseReturnDetailsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('voucher selector at $size has no overflow', (tester) async {
      await pump(tester, const CreatePurchaseReturnPage(), size);
      expect(find.text('#PV-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('#PV-1'));
      await tester.pumpAndSettle();
      expect(find.text('Item'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('#PV-1'), findsOneWidget);
    });
    testWidgets('details at $size retain item and amount', (tester) async {
      await pump(tester, PurchaseReturnDetailsPage(returnData: summary), size);
      expect(find.text('Item'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('create sequence keeps item payload and returns to list',
      (tester) async {
    final repository = await pump(
        tester, const CreatePurchaseReturnPage(), const Size(1440, 900));
    await tester.tap(find.text('#PV-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '2');
    await tester.enterText(find.byType(TextField).last, 'Damaged');
    await tester.tap(find.text('Add to Return'));
    await tester.pumpAndSettle();
    final submit = find.text('Create Purchase Return');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repository.submittedVoucher, 1);
    expect(repository.submittedItems, [
      {'purchase_item_id': 12, 'quantity': 2.0, 'reason': 'Damaged'}
    ]);
    expect(Get.find<SideBarController>().index.value,
        SideBarController.purchaseReturnListIndex);
    expect(tester.takeException(), isNull);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
