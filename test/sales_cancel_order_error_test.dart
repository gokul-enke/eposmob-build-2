import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'api_key': 'test-tenant'});
  });

  SalesProvider providerReturning(http.Response response) {
    return SalesProvider(
      postRequest: (url, {headers, body, encoding}) async => response,
    );
  }

  Matcher throwsApiMessage(String message) {
    return throwsA(
      isA<SalesApiException>().having(
        (error) => SalesProvider.apiErrorMessage(
          error,
          fallback: 'unused',
        ),
        'message',
        message,
      ),
    );
  }

  group('Sales API error handling', () {
    test('cancelOrder exposes the API message', () async {
      final provider = providerReturning(
        http.Response(
          '{"message":"Confirmed orders cannot be cancelled"}',
          422,
        ),
      );

      await expectLater(
        provider.cancelOrder(accessToken: 'token', orderId: '42'),
        throwsApiMessage('Confirmed orders cannot be cancelled'),
      );
    });

    test('changeOrderStatus exposes the API message', () async {
      final provider = providerReturning(
        http.Response('{"message":"Status change is not allowed"}', 409),
      );

      await expectLater(
        provider.changeOrderStatus(
          accessToken: 'token',
          orderId: '42',
          status: 'cancelled',
        ),
        throwsApiMessage('Status change is not allowed'),
      );
    });

    test('changePaymentStatus exposes the API message', () async {
      final provider = providerReturning(
        http.Response('{"message":"Payment is already settled"}', 422),
      );

      await expectLater(
        provider.changePaymentStatus(
          accessToken: 'token',
          orderId: '42',
          status: 'paid',
          amount: 10,
        ),
        throwsApiMessage('Payment is already settled'),
      );
    });

    test('uses the fallback when the API has no message', () async {
      final provider = providerReturning(http.Response('{}', 500));

      await expectLater(
        provider.cancelOrder(accessToken: 'token', orderId: '42'),
        throwsApiMessage('Failed to cancel order'),
      );
    });

    test('accepts both success status codes', () async {
      await providerReturning(http.Response('{}', 200)).cancelOrder(
        accessToken: 'token',
        orderId: '42',
      );
      await providerReturning(http.Response('{}', 201)).cancelOrder(
        accessToken: 'token',
        orderId: '42',
      );
    });

    test('rejects string and boolean failure envelopes on HTTP 200', () {
      expect(
        () => SalesProvider.ensureSalesActionSucceeded(
          200,
          '{"status":"failed","message":"String failure"}',
          fallback: 'fallback',
        ),
        throwsApiMessage('String failure'),
      );
      expect(
        () => SalesProvider.ensureSalesActionSucceeded(
          200,
          '{"success":false,"message":"Boolean failure"}',
          fallback: 'fallback',
        ),
        throwsApiMessage('Boolean failure'),
      );
    });

    test('does not expose transport exception details', () {
      final error = TimeoutException('internal connection details');

      expect(
        SalesProvider.apiErrorMessage(
          error,
          fallback: 'Unable to contact the server',
        ),
        'Unable to contact the server',
      );
    });
  });
}
