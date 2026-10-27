import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/display/app_badge.dart';
import 'package:pos_machine/features/sales/data/sales_list_repository.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/features/sales/domain/sales_list_query.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_list_controller.dart';
import 'package:pos_machine/features/sales/presentation/widgets/sales_list_rows.dart';

class _NoopSource implements SalesListSource {
  @override
  Future<SalesListPageData> fetch(
          String token, SalesListQuery query, int page) =>
      throw UnimplementedError();
  @override
  Future<List<ListOrderModelData>> snapshot(String token, SalesListQuery query,
          {void Function(int page, int last)? progress}) =>
      throw UnimplementedError();
}

void main() {
  test(
      'payment status and min/max amount are sent for orders and online orders',
      () {
    for (final online in [false, true]) {
      final params = SalesListQuery(
              paymentStatus: 'pending',
              minAmount: ' 10 ',
              maxAmount: '15.5',
              isOnlineSales: online)
          .parameters(1, null);

      expect(params['filter_payment_status'], 'pending');
      expect(params['filter_min_amount'], '10');
      expect(params['filter_max_amount'], '15.5');
      expect(params.containsKey('filter_online_sales'), online);
    }
  });

  test('"all", empty and invalid amounts are not sent', () {
    for (final bad in ['', '  ', 'abc', '-5', 'NaN', 'Infinity']) {
      final params =
          SalesListQuery(minAmount: bad, maxAmount: bad).parameters(1, null);
      expect(params.containsKey('filter_min_amount'), isFalse, reason: bad);
      expect(params.containsKey('filter_max_amount'), isFalse, reason: bad);
    }
    final params = const SalesListQuery().parameters(1, null);
    expect(params.containsKey('filter_payment_status'), isFalse);
  });

  test('new filters count as active and change the applied query', () {
    expect(const SalesListQuery().active, isFalse);
    expect(const SalesListQuery(paymentStatus: 'paid').active, isTrue);
    expect(const SalesListQuery(minAmount: '0').active, isTrue);
    expect(const SalesListQuery(maxAmount: 'abc').active, isFalse);
    expect(
        const SalesListQuery(minAmount: '10')
            .sameAs(const SalesListQuery(minAmount: '20')),
        isFalse);
  });

  test('reset clears payment status and min/max amount', () {
    final controller = SalesListController(_NoopSource(), () => 'token');
    controller.paymentStatus = 'refunded';
    controller.minAmount.text = '5';
    controller.maxAmount.text = '50';

    controller.clearFilters();

    expect(controller.paymentStatus, 'all');
    expect(controller.minAmount.text, isEmpty);
    expect(controller.maxAmount.text, isEmpty);
    expect(controller.query.active, isFalse);
    controller.dispose();
  });

  test('payment status shows like the admin panel', () {
    String code(String? raw) =>
        ListOrderModelData(paymentStatus: raw).paymentStatusCode;
    expect(code('paid'), 'paid');
    expect(code(' PAID '), 'paid');
    expect(code('refunded'), 'refunded');
    // Update Payment Status can set Failed; it must not read as Pending.
    expect(code('failed'), 'failed');
    expect(code(' FAILED '), 'failed');
    for (final pending in [
      null,
      '',
      'pending',
      'unpaid',
      'partial',
      'partially_paid'
    ]) {
      expect(code(pending), 'pending', reason: '$pending');
    }
  });

  testWidgets('payment status badge uses the payment label', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: salesPaymentStatus(
                ListOrderModelData(paymentStatus: 'paid')))));
    expect(find.text('sales.payment_paid'.tr), findsOneWidget);
  });

  testWidgets('a failed payment shows a red Failed badge', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: salesPaymentStatus(
                ListOrderModelData(paymentStatus: 'failed')))));
    final label = 'sales.payment_failed'.tr;
    expect(label, 'Failed');
    expect(find.text(label), findsOneWidget);
    expect(tester.widget<AppBadge>(find.byType(AppBadge)).tone,
        AppBadgeTone.danger);
  });

  test('Arabic-Indic digits are accepted and inverted ranges are swapped', () {
    expect(SalesListQuery.amount('١٠'), '10');
    expect(SalesListQuery.amount('۱۵٫۵'), '15.5');
    expect(SalesListQuery.amount('١٬٠٠٠'), '1000');
    final params = const SalesListQuery(minAmount: '50', maxAmount: '10')
        .parameters(1, null);
    expect(params['filter_min_amount'], '10');
    expect(params['filter_max_amount'], '50');
    final oneSided = const SalesListQuery(minAmount: '50', maxAmount: 'abc')
        .parameters(1, null);
    expect(oneSided['filter_min_amount'], '50');
    expect(oneSided.containsKey('filter_max_amount'), isFalse);
  });
}
