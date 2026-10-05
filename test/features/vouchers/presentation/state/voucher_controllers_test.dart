import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/features/vouchers/presentation/state/customer_voucher_form_controller.dart';
import 'package:pos_machine/features/vouchers/presentation/state/supplier_voucher_form_controller.dart';
import 'package:pos_machine/features/vouchers/presentation/state/voucher_list_controller.dart';

MasterDataValue payment(int id, String value) =>
    MasterDataValue(id: id, value: value, description: value);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'customer initialization keeps choices, paid default, CASH priority and method ID',
      () async {
    final form = CustomerVoucherFormController(
        loadChoices: () async => [
              {'id': 7, 'name': 'Test'}
            ],
        loadPayments: () async =>
            [payment(3, 'CARD'), payment(2, 'COD'), payment(1, 'CASH')]);
    addTearDown(form.dispose);
    await form.initialize();
    expect(form.customers.single['id'], 7);
    expect(form.selectedStatus, 'paid');
    expect(form.selectedPaymentMethod, 'CASH');
    expect(form.getPaymentMethodId('CASH'), 1);
    expect(form.getPaymentMethodId('missing'), isNull);
    expect(form.isLoadingPaymentMethods, isFalse);
    final item = form.voucherItems.single;
    item.unitAmount = '12.50';
    item.quantity = '2';
    item.tax = '3';
    form.calculateTotal();
    expect(item.totalAmount, '28.00');
    expect(form.totalAmountController.text, '28.00');
  });
  test('supplier keeps percentage tax calculation and controller listeners',
      () async {
    final form = SupplierVoucherFormController(
        loadChoices: () async => [],
        loadPayments: () async => [payment(2, 'COD')]);
    addTearDown(form.dispose);
    await form.initialize();
    expect(form.selectedPaymentMethod, 'COD');
    final item = form.voucherItems.single;
    item.unitAmountController.text = '12.50';
    item.quantityController.text = '2';
    item.taxController.text = '15';
    expect(item.totalController.text, '28.75');
    expect(form.netTotalController.text, '25.00');
    expect(form.totalTaxController.text, '3.75');
    expect(form.totalAmountController.text, '28.75');
  });
  test('disposing during choices prevents payment fetch and notifications',
      () async {
    final pending = Completer<List<Map<String, dynamic>>?>();
    var payments = 0;
    final form = CustomerVoucherFormController(
        loadChoices: () => pending.future,
        loadPayments: () async {
          payments++;
          return [];
        });
    final work = form.initialize();
    form.dispose();
    pending.complete([
      {'id': 1}
    ]);
    await work;
    expect(payments, 0);
    expect(form.customers, isEmpty);
  });
  test('disposing during supplier payment fetch ignores its completion',
      () async {
    final pending = Completer<List<MasterDataValue>?>();
    final form = SupplierVoucherFormController(
        loadChoices: () async => [], loadPayments: () => pending.future);
    final work = form.initialize();
    await Future<void>.delayed(Duration.zero);
    form.dispose();
    pending.complete([payment(1, 'CASH')]);
    await work;
    expect(form.paymentMethods, isEmpty);
  });
  test(
      'null payment results clear loading and preserve manually selected method',
      () async {
    final form = CustomerVoucherFormController(
        loadChoices: () async => [], loadPayments: () async => null);
    addTearDown(form.dispose);
    form.selectedPaymentMethod = 'CARD';
    await form.initialize();
    expect(form.selectedPaymentMethod, 'CARD');
    expect(form.isLoadingPaymentMethods, isFalse);
  });
  test('list reset cancels pending search and never disposes borrowed export',
      () async {
    var calls = 0;
    final export = ExportController();
    addTearDown(export.dispose);
    final list = VoucherListController(search: () => calls++, export: export);
    list.searchTextController.text = 'Test';
    list.selectedType = 'order';
    list.debouncer.schedule();
    expect(list.hasActiveFilters, isTrue);
    list.reset();
    expect(list.hasActiveFilters, isFalse);
    list.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(calls, 0);
    var notified = false;
    export.addListener(() => notified = true);
    export.notifyListeners();
    expect(notified, isTrue);
  });
}
