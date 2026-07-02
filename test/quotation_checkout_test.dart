library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/quotation_checkout.dart';

void main() {
  group('QuotationCheckout.validate', () {
    test('rejects empty cart', () {
      expect(
        QuotationCheckout.validate(
          cartIsEmpty: true,
          hasExistingCustomer: true,
          hasInlineCustomer: false,
          quotationDate: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 1, 31),
        ),
        QuotationCheckout.emptyCartMessage,
      );
    });

    test('rejects missing customer', () {
      expect(
        QuotationCheckout.validate(
          cartIsEmpty: false,
          hasExistingCustomer: false,
          hasInlineCustomer: false,
          quotationDate: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 1, 31),
        ),
        QuotationCheckout.missingCustomerMessage,
      );
    });

    test('rejects expiry before quotation date', () {
      expect(
        QuotationCheckout.validate(
          cartIsEmpty: false,
          hasExistingCustomer: true,
          hasInlineCustomer: false,
          quotationDate: DateTime(2026, 2, 1),
          expiryDate: DateTime(2026, 1, 1),
        ),
        QuotationCheckout.expiryBeforeQuotationMessage,
      );
    });

    test('accepts valid existing-customer quotation', () {
      expect(
        QuotationCheckout.validate(
          cartIsEmpty: false,
          hasExistingCustomer: true,
          hasInlineCustomer: false,
          quotationDate: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 1, 31),
        ),
        isNull,
      );
    });

    test('accepts inline customer name without id', () {
      expect(
        QuotationCheckout.validate(
          cartIsEmpty: false,
          hasExistingCustomer: false,
          hasInlineCustomer: true,
          quotationDate: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 1, 31),
        ),
        isNull,
      );
    });
  });

  group('QuotationCheckout.buildPayload', () {
    test('matches desktop shape for existing customer', () {
      final payload = QuotationCheckout.buildPayload(
        hasExistingCustomer: true,
        customerId: 42,
        customerName: 'Acme',
        customerPhone: '0500000000',
        storeId: 7,
        deliveryMethodId: 3,
        deliveryCharge: 12.5,
        quotationDate: DateTime(2026, 3, 15),
        expiryDate: DateTime(2026, 4, 15),
        discount: 5,
        comment: 'Rush quote',
        cartItems: const [],
      );

      expect(payload['customer_type'], 'existing');
      expect(payload['customer_id'], 42);
      expect(payload['store_id'], 7);
      expect(payload['delivery_method_id'], 3);
      expect(payload['shipping_cost'], 12.5);
      expect(payload['quotation_date'], '2026-03-15');
      expect(payload['expiry_date'], '2026-04-15');
      expect(payload['discount'], 5);
      expect(payload['comment'], 'Rush quote');
      expect(payload['items'], isEmpty);
      expect(payload.containsKey('customer_name'), isFalse);
    });

    test('matches desktop shape for new inline customer', () {
      final payload = QuotationCheckout.buildPayload(
        hasExistingCustomer: false,
        customerId: null,
        customerName: 'Walk-in',
        customerPhone: '0500111222',
        storeId: 1,
        deliveryMethodId: null,
        deliveryCharge: 0,
        quotationDate: DateTime(2026, 1, 1),
        expiryDate: DateTime(2026, 1, 31),
        discount: 0,
        comment: '',
        cartItems: const [],
      );

      expect(payload['customer_type'], 'new');
      expect(payload['customer_name'], 'Walk-in');
      expect(payload['customer_phone'], '0500111222');
      expect(payload.containsKey('shipping_cost'), isFalse);
      expect(payload.containsKey('discount'), isFalse);
    });
  });

  group('QuotationCheckout.extractCreatedQuotationId', () {
    test('reads nested quotation id paths', () {
      expect(
        QuotationCheckout.extractCreatedQuotationId({
          'success': true,
          'data': {'quotation': {'id': 99}},
        }),
        99,
      );
      expect(
        QuotationCheckout.extractCreatedQuotationId({
          'quotation_id': 'Q-12',
        }),
        'Q-12',
      );
    });
  });

  group('QuotationCheckout date helpers', () {
    test('normalizes expiry when before quotation date', () {
      final normalized = QuotationCheckout.normalizeExpiryDate(
        quotationDate: DateTime(2026, 5, 1),
        expiryDate: DateTime(2026, 4, 1),
      );
      expect(normalized, DateTime(2026, 5, 31));
    });
  });
}
