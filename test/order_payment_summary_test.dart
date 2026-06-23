/// Tests for [formatOrderPaymentSummary] — the pure payment-summary formatter
/// extracted from `orders_tab.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/order_payment_summary.dart';

void main() {
  group('formatOrderPaymentSummary', () {
    test('null / empty → N/A', () {
      expect(formatOrderPaymentSummary(null), 'N/A');
      expect(formatOrderPaymentSummary(''), 'N/A');
    });

    test('plain method name is title-cased', () {
      expect(formatOrderPaymentSummary('CASH'), 'Cash');
      expect(formatOrderPaymentSummary('CARD'), 'Card');
      expect(formatOrderPaymentSummary('UPI'), 'Upi');
    });

    test('unknown plain value passes through unchanged', () {
      expect(formatOrderPaymentSummary('GiftCard'), 'GiftCard');
    });

    test('multi-payment JSON lists method + amount', () {
      const json =
          '{"methods":["CASH","CARD"],"amounts":{"CASH":"100","CARD":50}}';
      expect(formatOrderPaymentSummary(json), 'Cash 100.00, Card 50.00');
    });

    test('multi-payment with zero amount shows label only', () {
      const json = '{"methods":["CASH"],"amounts":{"CASH":0}}';
      expect(formatOrderPaymentSummary(json), 'Cash');
    });

    test('more than 3 methods are truncated with a +N suffix', () {
      const json =
          '{"methods":["CASH","CARD","UPI","DEBIT"],"amounts":{"CASH":1,"CARD":1,"UPI":1,"DEBIT":1}}';
      // First 3 joined, then " +1"
      expect(formatOrderPaymentSummary(json),
          'Cash 1.00, Card 1.00, Upi 1.00 +1');
    });
  });
}
