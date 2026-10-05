import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/features/purchases/data/purchase_api.dart';
import 'package:pos_machine/features/purchases/data/purchase_repository.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_provider.dart';

import '../../support/fixed_session.dart';

void main() {
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
