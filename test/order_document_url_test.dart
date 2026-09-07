/// Order numbers are backend-generated and today always look like
/// ORD-004429, but they reach both a URL path and a local filename. This pins
/// down that a separator in one could not rewrite the request path or send the
/// write into a directory that does not exist.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/resources/app_url.dart';

void main() {
  group('order document URLs', () {
    test('builds the expected paths for a normal order number', () {
      expect(
        APPUrl.orderDeliveryNote('ORD-004429'),
        endsWith('/api/v1/order/documents/delivery-note/ORD-004429'),
      );
      expect(
        APPUrl.orderDeliveryInvoice('ORD-004429'),
        endsWith('/api/v1/order/documents/delivery-invoice/ORD-004429'),
      );
    });

    test('encodes separators instead of extending the path', () {
      final url = APPUrl.orderDeliveryNote('2026/ORD/0044');

      expect(url, contains('2026%2FORD%2F0044'));
      expect(Uri.parse(url).pathSegments.last, '2026/ORD/0044',
          reason: 'the order number must stay one path segment');
    });

    test('keeps a fragment or query out of the URL structure', () {
      final hashed = Uri.parse(APPUrl.orderDeliveryNote('ORD#44'));
      expect(hashed.fragment, isEmpty);
      expect(hashed.pathSegments.last, 'ORD#44');

      final queried = Uri.parse(APPUrl.orderDeliveryInvoice('ORD?x=1'));
      expect(queried.query, isEmpty);
      expect(queried.pathSegments.last, 'ORD?x=1');
    });
  });
}
