import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';

void main() {
  group('BillingMobileErrorMessages', () {
    test('insufficientStock includes unit label', () {
      expect(
        BillingMobileErrorMessages.insufficientStock('kg'),
        'Insufficient stock for kg',
      );
    });

    test('couponInvalid includes coupon name', () {
      expect(
        BillingMobileErrorMessages.couponInvalid('SUMMER10'),
        'Cannot apply SUMMER10: coupon is not valid',
      );
    });

    test('pineLabsPaymentFailed appends alternate payment hint', () {
      expect(
        BillingMobileErrorMessages.pineLabsPaymentFailed(),
        contains('Choose another payment method'),
      );
      expect(
        BillingMobileErrorMessages.pineLabsPaymentFailed('Declined'),
        'Declined. Choose another payment method or tap Pay with Pine Labs to retry.',
      );
    });

    test('userFacingException strips Exception prefix', () {
      expect(
        BillingMobileErrorMessages.userFacingException(
          Exception('Network timeout'),
        ),
        'Network timeout',
      );
      expect(
        BillingMobileErrorMessages.userFacingException(
          const HttpException('API key not found'),
        ),
        'API key not found',
      );
    });

    test('userFacingException uses fallback for empty text', () {
      expect(
        BillingMobileErrorMessages.userFacingException(
          '',
          fallback: 'Fallback message',
        ),
        'Fallback message',
      );
    });

    test('orderApiFailure prefers API message', () {
      expect(
        BillingMobileErrorMessages.orderApiFailure(
          {'message': 'Duplicate order'},
        ),
        'Duplicate order',
      );
      expect(
        BillingMobileErrorMessages.orderApiFailure({}),
        BillingMobileErrorMessages.confirmOrderFailed,
      );
      expect(
        BillingMobileErrorMessages.orderApiFailure(
          {'message': 'Server busy'},
          fallback: BillingMobileErrorMessages.createOrderFailed,
        ),
        'Server busy',
      );
    });

    test('checkoutException preserves cart and includes operation', () {
      final message = BillingMobileErrorMessages.checkoutException(
        Exception('SocketException: timed out'),
        operation: 'confirm order',
      );
      expect(message, contains('confirm order'));
      expect(message, contains('timed out'));
      expect(message, contains('cart is unchanged'));
    });

    test('print retry messages are actionable', () {
      expect(
        BillingMobileErrorMessages.printRetryPrompt,
        contains('Retry'),
      );
      expect(
        BillingMobileErrorMessages.printRetryFailedAgain,
        contains('Retry'),
      );
    });

    test('customer load messages mention retry', () {
      expect(
        BillingMobileErrorMessages.loadCustomersFailed,
        contains('Retry'),
      );
      expect(
        BillingMobileErrorMessages.customersUnavailable,
        contains('Retry'),
      );
    });
  });
}
