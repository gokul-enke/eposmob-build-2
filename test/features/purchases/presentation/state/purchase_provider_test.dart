import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/purchases/data/purchase_api.dart';
import 'package:pos_machine/features/purchases/data/purchase_repository.dart';
import 'package:pos_machine/features/purchase_returns/data/purchase_return_repository.dart';
import 'package:pos_machine/features/purchases/domain/models/list_purchase.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';

import '../../support/fixed_session.dart';

/// Records what PurchaseProvider forwards to the purchase-return repository.
class _RecordingReturnRepository extends PurchaseReturnRepository {
  final calls = <Map<String, Object?>>[];

  @override
  Future<Map<String, dynamic>> create(
      {required String accessToken,
      required int purchaseVoucherId,
      required String returnDate,
      required List<Map<String, dynamic>> items,
      bool hasPayment = false,
      double? paidAmount,
      String? paymentMethod}) async {
    calls.add({
      'hasPayment': hasPayment,
      'paidAmount': paidAmount,
      'paymentMethod': paymentMethod,
    });
    return {'status': 'success'};
  }
}

void main() {
  test('a legacy page loaded by the list feeds the View details', () {
    final provider = PurchaseProvider();
    final page = ListPurchaseModel.fromJson({
      'status': 'success',
      'data': {
        'current_page': 2,
        'last_page': 3,
        'data': [
          {
            'id': 101,
            'purchase_items': [
              {'id': 11, 'purchase_id': 101, 'quantity': 2, 'unit_price': 6}
            ]
          },
          {
            'id': 102,
            'purchase_items': [
              {'id': 12, 'purchase_id': 102, 'quantity': 1, 'unit_price': 9}
            ]
          }
        ]
      }
    });
    var notifications = 0;
    provider.addListener(() => notifications++);

    provider.rememberLegacyPurchases(page);
    provider.callVoucherDetails(voucherId: 0, purchaseId: 101);

    expect(provider.purchaseItemListAllPurchase.map((i) => i.id), [11, 12]);
    expect(provider.getlistPurchaseItemView!.map((i) => i.id), [11, 12]);
    expect(provider.getListPurchaseModelDataDetails?.id, 101);
    expect(provider.currentPage, 2);
    expect(provider.totalPages, 3);
    expect(notifications, greaterThanOrEqualTo(1));
    provider.dispose();
  });

  test('createPurchaseReturn passes the payment through', () async {
    final returns = _RecordingReturnRepository();
    final provider = PurchaseProvider(purchaseReturnRepository: returns);
    await provider.createPurchaseReturn(
        accessToken: 'token',
        purchaseVoucherId: 7,
        returnDate: '2026-10-05',
        items: const [],
        hasPayment: true,
        paidAmount: 25,
        paymentMethod: 'CASH');
    await provider.createPurchaseReturn(
        accessToken: 'token',
        purchaseVoucherId: 7,
        returnDate: '2026-10-05',
        items: const []);
    expect(returns.calls, [
      {'hasPayment': true, 'paidAmount': 25.0, 'paymentMethod': 'CASH'},
      {'hasPayment': false, 'paidAmount': null, 'paymentMethod': null},
    ]);
    provider.dispose();
  });

  test('unit and legacy item reads keep values and single notifications',
      () async {
    dynamic payload = {
      'status': 'success',
      'data': {'1': 'PC'},
      'labels': {'1': 'Piece'}
    };
    final provider = PurchaseProvider(
        repository: PurchaseRepository(
            api: PurchaseApi(
                session: const FixedSession(),
                httpGet: (url, {headers}) async =>
                    http.Response(jsonEncode(payload), 200))));
    var notifications = 0;
    provider.addListener(() => notifications++);
    await provider.listAllUnits('token');
    expect(provider.getUnitList, {'1': 'PC'});
    expect(provider.getUnitLabels, {'1': 'Piece'});
    expect(notifications, 1);
    payload = {
      'status': 'success',
      'data': [
        {'id': 11, 'purchase_id': 101, 'quantity': 2, 'unit_price': 6}
      ]
    };
    final result = await provider.listAllPurchaseItems('token');
    expect(result, payload);
    expect(provider.purchaseItems.single.id, 11);
    expect(notifications, 2);
    provider.dispose();
  });
  test(
      'details retain loading notifications and preserve previous data on HTTP error',
      () async {
    var code = 200;
    final payload = {
      'status': 'success',
      'data': {
        'id': 101,
        'purchase_items': [
          {'id': 11, 'purchase_id': 101, 'quantity': 2, 'unit_price': 6}
        ]
      }
    };
    final provider = PurchaseProvider(
        repository: PurchaseRepository(
            api: PurchaseApi(
                session: const FixedSession(),
                httpGet: (url, {headers}) async =>
                    http.Response(jsonEncode(payload), code))));
    final loading = <bool>[];
    provider.addListener(() => loading.add(provider.isLoading));
    await provider.fetchPurchaseOrderDetails(
        accessToken: 'token', purchaseId: '101');
    expect(loading, [true, false]);
    expect(provider.getlistPurchaseItemView!.single.id, 11);
    expect(provider.activePurchaseOrderDetails!['id'], 101);
    code = 500;
    await provider.fetchPurchaseOrderDetails(
        accessToken: 'token', purchaseId: '102');
    expect(loading, [true, false, true, false]);
    expect(provider.activePurchaseOrderDetails!['id'], 101);
    provider.dispose();
  });
}
