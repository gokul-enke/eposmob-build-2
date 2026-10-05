import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/purchases/data/purchase_api.dart';
import 'package:pos_machine/features/purchases/data/purchase_repository.dart';
import 'fixed_session.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'package:pos_machine/providers/stock_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:provider/provider.dart';

import '../../../test_support/app_translations.dart';

final purchaseDetailPayload = <String, dynamic>{
  'id': 101,
  'voucher_number': 'PO-101',
  'invoice_ref': 'REF-101',
  'purchase_date': '2026-10-03',
  'payment_status': 'paid',
  'amount_total': '12.000',
  'store': {'id': 4, 'name': 'Shop'},
  'supplier': {'id': 7, 'name': 'Supplier'},
  'purchase_items': [
    {
      'id': 11,
      'product_id': 9,
      'product_name': 'Rice',
      'quantity': '2',
      'unit_price': '6',
      'retail_price': '7',
      'mrp': '7',
      'wholesale_price': '6',
      'wholesale_min_unit': '1',
      'unit': 'PC',
      'status': 'pending',
      'is_received': false
    }
  ]
};

class PagePurchases extends PurchaseProvider {
  PagePurchases()
      : super(
            repository: PurchaseRepository(
                api: PurchaseApi(
                    session: const FixedSession(),
                    httpGet: (url, {headers}) async => http.Response(
                        jsonEncode({
                          'status': 'success',
                          'data': {
                            'current_page': 1,
                            'last_page': 1,
                            'data': []
                          }
                        }),
                        200)))) {
    storeList = [GetStoreModelData(id: 4, name: 'Shop')];
    supplierList = [GetSuppliersModelData(id: 7, name: 'Supplier')];
    unitList = {'PC': 'Piece'};
    masterDataValues = {};
    activePurchaseOrderDetails = Map.of(purchaseDetailPayload);
  }
  @override
  Future<dynamic> listAllPurchaseItems(String token) async =>
      {'status': 'success', 'data': []};
  @override
  Future<void> listAllStores(String a, String? b) async {}
  @override
  Future<void> listAllSuppliers(String a, String? b) async {}
}

class PageCatalog extends ChangeNotifier implements LocalProductProvider {
  @override
  List<GetProduct> get products => [
        GetProduct.fromJson({'id': 9, 'product_name': 'Rice', 'unit': 'PC'})
      ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PageGrid extends ChangeNotifier implements GridSelectionProvider {
  @override
  List<GetProduct>? get getProducts => [];
  @override
  String? productName(int id) => 'Rice';
  @override
  List<GetProduct>? get getCategoryProductList => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PageMaster extends MasterDataProvider {
  @override
  Future<List<MasterDataValue>?> fetchPaymentMethods(
          {bool forceRefresh = false}) async =>
      [];
}

class PageSettings extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

class PageRole extends RoleProvider {
  @override
  bool currentUserHasPermissionSync(String permission) => true;
}

Widget wrapPurchasePage(Widget page, {Key? captureKey}) => MultiProvider(
        providers: [
          ChangeNotifierProvider<PurchaseProvider>(
              create: (_) => PagePurchases()),
          ChangeNotifierProvider<AuthModel>(
              create: (_) => AuthModel()..login('token', 1)),
          ChangeNotifierProvider<CategoryProvider>(
              create: (_) => CategoryProvider()..categoryList = []),
          ChangeNotifierProvider<GridSelectionProvider>(
              create: (_) => PageGrid()),
          ChangeNotifierProvider<LocalProductProvider>(
              create: (_) => PageCatalog()),
          ChangeNotifierProvider<MasterDataProvider>(
              create: (_) => PageMaster()),
          ChangeNotifierProvider<StoreSessionProvider>(
              create: (_) => StoreSessionProvider()),
          ChangeNotifierProvider<StockProvider>(create: (_) => StockProvider()),
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => PageSettings()),
          ChangeNotifierProvider<RoleProvider>(create: (_) => PageRole())
        ],
        child: GetMaterialApp(
            translations: EnglishTranslations(),
            locale: const Locale('en'),
            home:
                RepaintBoundary(key: captureKey, child: Scaffold(body: page))));
