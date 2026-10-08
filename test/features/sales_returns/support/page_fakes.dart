import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/features/sales_returns/data/sales_return_api.dart';
import 'package:pos_machine/features/sales_returns/data/sales_return_repository.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return_items.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:provider/provider.dart';

import '../../../test_support/app_translations.dart';
import '../../../test_support/network_fakes.dart';
import 'return_fixtures.dart';

final returnItemBody = {
  'status': 'success',
  'message': 'ok',
  'order': {'id': 100, 'shipping_cost': '0'},
  'data': [
    {
      'cart_item_id': 40,
      'product_name': 'Rice',
      'product_unit': 'KG',
      'quantity': '2',
      'unit_price': '10',
      'total_price': '20',
      'returned_quantity': 1,
      'returned_total': '10',
      'is_returned': false
    }
  ]
};

SalesReturnRepository pageRepository() => SalesReturnRepository(
    api: SalesReturnApi(
        session: const FakeTenantSession(),
        get: (uri, {headers}) async => http.Response(
            jsonEncode(uri.queryParameters.containsKey('order_number')
                ? returnItemBody
                : returnListBody()),
            200),
        post: (uri, {headers, body, encoding}) async => http.Response(
            jsonEncode({
              'status': 'success',
              'message': 'ok',
              'data': {'id': 75}
            }),
            200)));

class ReturnPageSales extends SalesProvider {
  ReturnPageSales({this.selected = true})
      : super(salesReturnRepository: pageRepository());
  final bool selected;
  @override
  String get getOrderNumber => selected ? 'INV-100' : '';
  @override
  String get getOrderId => selected ? '100' : '';
  @override
  List<ListOrderModelData> get orders => selected
      ? [
          ListOrderModelData.fromJson({
            'id': 100,
            'order_number': 'INV-100',
            'order_date': '2026-10-01',
            'total_price': '20',
            'status': 'CONFIRMED'
          })
        ]
      : [];
  @override
  List<SalesReturnCart> get salesReturnItems =>
      SalesReturnItemsResponse.fromJson(returnItemBody).data;
  @override
  List<SalesReturnOrder> get salesReturnOrders => returnPage().data.data;
  @override
  Future<void> fetchSalesReturn(
      {required String accessToken, int? page}) async {}
  @override
  Future<void> fetchSalesReturnItems(
      {required String accessToken,
      required String orderId,
      int? page}) async {}
  @override
  Future<dynamic> listOrderDetails(
          BuildContext context, String orderNumber, String accessToken) async =>
      {
        'status': 'success',
        'data': {
          'id': 100,
          'order_number': 'INV-100',
          'delivery_charge': 0,
          'cart_items': []
        }
      };
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
  }) async {
    notifyListeners();
  }
}

class ReturnPageGrid extends ChangeNotifier implements GridSelectionProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ReturnPageSettings extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

Widget wrapReturnPage(Widget page, {ReturnPageSales? sales, Key? captureKey}) =>
    MultiProvider(
        providers: [
          ChangeNotifierProvider<SalesProvider>(
              create: (_) => sales ?? ReturnPageSales()),
          ChangeNotifierProvider<AuthModel>(
              create: (_) => AuthModel()..login('token', 1)),
          ChangeNotifierProvider<AppSettingsProvider>(
              create: (_) => ReturnPageSettings()),
          ChangeNotifierProvider<GridSelectionProvider>(
              create: (_) => ReturnPageGrid()),
        ],
        child: GetMaterialApp(
            translations: EnglishTranslations(),
            locale: const Locale('en'),
            home:
                RepaintBoundary(key: captureKey, child: Scaffold(body: page))));
