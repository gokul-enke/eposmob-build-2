import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/purchase_returns/data/purchase_return_api.dart';
import 'package:pos_machine/features/purchase_returns/data/purchase_return_repository.dart';
import 'package:pos_machine/features/purchase_returns/domain/models/purchase_return.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';
import '../../../../test_support/network_fakes.dart';

void main() {
  test('legacy adapter forwards notifications and return state once', () async {
    final provider = PurchaseProvider(
        purchaseReturnRepository: PurchaseReturnRepository(
            api: PurchaseReturnApi(
                session: const FakeTenantSession(),
                httpGet: (url, {headers}) async => jsonResponse({
                      'status': 'success',
                      'data': {
                        'current_page': 2,
                        'last_page': 3,
                        'data': [
                          {'id': 9}
                        ]
                      }
                    }))));
    addTearDown(provider.dispose);
    var notifications = 0;
    provider.addListener(() => notifications++);
    await provider.listPurchaseReturns(accessToken: 't', page: 2);
    expect(provider.purchaseReturnsList.single.id, 9);
    expect(provider.purchaseReturnCurrentPage, 2);
    expect(provider.purchaseReturnTotalPages, 3);
    expect(notifications, 1);
    provider.purchaseReturnsList = [];
    expect(provider.purchaseReturnProvider.purchaseReturnsList, isEmpty);
  });
  test('request-local list, items and vouchers do not overwrite shared state',
      () async {
    final provider = PurchaseProvider(
        purchaseReturnRepository: PurchaseReturnRepository(
            api: PurchaseReturnApi(
                session: const FakeTenantSession(),
                httpGet: (url, {headers}) async => jsonResponse({
                      'status': 'success',
                      'data': {
                        'current_page': 1,
                        'last_page': 2,
                        'data': [
                          {'id': 9}
                        ],
                        'items': [
                          {'purchase_item_id': 12}
                        ]
                      }
                    }))));
    addTearDown(provider.dispose);
    var notifications = 0;
    provider.addListener(() => notifications++);
    provider.purchaseReturnsList = [PurchaseReturnData(id: 100)];
    provider.returnableItemsList = [ReturnableItem(purchaseItemId: 101)];
    await provider.purchaseReturnProvider.fetchPage(accessToken: 't');
    await provider.purchaseReturnProvider
        .fetchItems(accessToken: 't', purchaseVoucherId: 1);
    await provider.purchaseReturnProvider.repository
        .fetchVouchers(accessToken: 't');
    expect(provider.purchaseReturnsList.single.id, 100);
    expect(provider.returnableItemsList.single.purchaseItemId, 101);
    expect(notifications, 0);
    expect(provider.purchaseOrdersList, isEmpty);
  });
  test(
      'legacy load errors clear state and notify; missing tenant preserves state',
      () async {
    for (final tenant in ['tenant', null]) {
      final provider = PurchaseProvider(
          purchaseReturnRepository: PurchaseReturnRepository(
              api: PurchaseReturnApi(
                  session: FakeTenantSession(key: tenant),
                  httpGet: (url, {headers}) async => jsonResponse({}, 500))));
      var notifications = 0;
      provider.addListener(() => notifications++);
      provider.purchaseReturnsList = [PurchaseReturnData(id: 9)];
      provider.purchaseReturnCurrentPage = 3;
      provider.returnableItemsList = [ReturnableItem(purchaseItemId: 10)];
      await expectLater(provider.listPurchaseReturns(accessToken: 't'),
          throwsA(isA<HttpException>()));
      await expectLater(
          provider.fetchReturnableItems(accessToken: 't', purchaseVoucherId: 1),
          throwsA(isA<HttpException>()));
      expect(provider.purchaseReturnsList,
          tenant == null ? hasLength(1) : isEmpty);
      expect(provider.returnableItemsList,
          tenant == null ? hasLength(1) : isEmpty);
      expect(notifications, tenant == null ? 0 : 2);
      expect(provider.purchaseReturnCurrentPage, tenant == null ? 3 : 1);
      provider.dispose();
    }
  });
}
