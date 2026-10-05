import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/purchases/domain/models/list_purchase.dart';
import 'package:pos_machine/features/purchases/domain/models/list_purchase_voucher.dart';
import 'package:pos_machine/features/purchases/presentation/state/legacy_purchase_list_controller.dart';
import 'package:pos_machine/models/pagination.dart';

ListPurchaseModel purchasePage(int n) => ListPurchaseModel(data: [
      ListPurchaseModelData(purchaseItems: [PurchaseItem(id: n)])
    ], pagination: Pagination(currentPage: n, lastPage: 4));
void main() {
  test('reset supersedes stale result and failed refresh preserves prior rows',
      () async {
    final old = Completer<ListPurchaseModel>();
    final queries = <String>[];
    final c = LegacyPurchaseListController(
        fetchPurchases: ({filterName, filterStore, page}) {
      queries.add('$page/$filterName/$filterStore');
      if (page == 3) return old.future;
      if (page == 4) throw StateError('offline');
      return Future.value(purchasePage(page ?? 1));
    });
    c.purchaserNameController.text = 'A';
    c.storeController.text = '8';
    final pending = c.load(3);
    await c.load(1, true);
    old.complete(purchasePage(3));
    await pending;
    expect(c.purchaseDetailsList.single.id, 1);
    expect(c.currentPage, 1);
    expect(c.purchaserNameController.text, '');
    expect(queries, ['3/A/8', '1/null/null']);
    await c.load(4);
    expect(c.currentPage, 1);
    expect(c.purchaseDetailsList.single.id, 1);
    expect(c.initLoading, false);
    c.dispose();
  });
  test('voucher load after disposal cannot notify or replace rows', () async {
    final response = Completer<ListVoucherModel>();
    var notifications = 0;
    final c = LegacyPurchaseListController(
        fetchVouchers: ({filterAmount, filterStore, page}) => response.future)
      ..addListener(() => notifications++);
    final pending = c.load();
    expect(notifications, 1);
    c.dispose();
    response.complete(ListVoucherModel(data: []));
    await pending;
    expect(notifications, 1);
  });
}
