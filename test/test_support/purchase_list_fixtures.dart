import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:pos_machine/features/purchases/data/purchase_api.dart';
import 'package:pos_machine/features/purchases/data/purchase_repository.dart';
import 'package:pos_machine/features/purchase_returns/data/purchase_return_api.dart';
import 'package:pos_machine/features/purchase_returns/data/purchase_return_repository.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/role_provider.dart';
import 'app_translations.dart';

class PurchaseListFixture {
  final requests = <Uri>[];
  bool duplicate = false;
  bool fail = false;
  Future<void> Function()? beforeResponse;
  late final purchases = _Purchases(this);
  final auth = AuthModel()..login('fixture-token', 1);
  final roles = PurchaseListRoles();

  Future<http.Response> response(Uri url,
      {Map<String, String>? headers}) async {
    requests.add(url);
    await beforeResponse?.call();
    if (fail) return http.Response('failure', 500);
    final page = int.parse(url.queryParameters['page'] ?? '1');
    final returns = url.path.contains('return');
    return http.Response(
        jsonEncode({
          'status': 'success',
          'data': {
            'current_page': page,
            'last_page': 2,
            'data': List.generate(page == 1 ? 15 : 2, (i) {
              final id = duplicate ? i + 1 : (page - 1) * 15 + i + 1;
              return {
                'id': id,
                'reference': 'PR-$id',
                'voucher_number': 'PV-$id',
                'purchase_date': '2026-09-25',
                'return_date': '2026-09-25',
                'amount_total': '126.125',
                'total_amount': 126.125,
                'supplier': {'id': 7, 'name': 'Supplier Funzcart'},
                'store': {'id': 4, 'name': 'Main Store'},
                'items_received': i.isEven ? '3 / 3' : '0 / 1',
                'status':
                    returns ? (i.isEven ? 'completed' : 'pending') : 'success',
              };
            }),
          }
        }),
        200);
  }

  Widget wrap(Widget page) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthModel>.value(value: auth),
            ChangeNotifierProvider<PurchaseProvider>.value(value: purchases),
            ChangeNotifierProvider<RoleProvider>.value(value: roles),
            ChangeNotifierProvider<AppSettingsProvider>(
                create: (_) => _Settings()),
          ],
          child: GetMaterialApp(
              translations: EnglishTranslations(),
              locale: const Locale('en'),
              theme: ThemeData(fontFamily: 'Poppins'),
              home: Scaffold(body: page)));
}

class _Purchases extends PurchaseProvider {
  _Purchases(PurchaseListFixture fixture)
      : super(
          repository:
              PurchaseRepository(api: PurchaseApi(httpGet: fixture.response)),
          purchaseReturnRepository: PurchaseReturnRepository(
              api: PurchaseReturnApi(httpGet: fixture.response)),
        ) {
    storeList = [
      GetStoreModelData(id: 4, name: 'Main Store'),
      GetStoreModelData(id: 5, name: 'Second Store')
    ];
    supplierList = [
      GetSuppliersModelData(id: 7, name: 'Supplier Funzcart'),
      GetSuppliersModelData(id: 8, name: 'Other Supplier')
    ];
  }
  @override
  Future<void> listAllStores(String token, String? name) async {}
  @override
  Future<void> listAllSuppliers(String token, String? name) async {}
}

class _Settings extends AppSettingsProvider {
  @override
  Future<void> fetchAppSettings() async {}
}

class PurchaseListRoles extends RoleProvider {
  bool allowed = true;
  @override
  bool currentUserHasPermissionSync(String permission) => allowed;
}
