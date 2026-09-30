import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/providers/report_provider.dart';

void main() {
  test('product sales report request matches the documented API contract', () {
    final uri = ReportsProvider.buildProductSalesReportUri(
      endpoint: 'https://example.com/api/v1/product-sales-report',
      categoryId: '88',
      page: 1,
      perPage: 25,
    );

    expect(uri.path, '/api/v1/product-sales-report');
    expect(uri.queryParameters['category_id'], '88');
    expect(uri.queryParameters['page'], '1');
    expect(uri.queryParameters['per_page'], '25');
    expect(uri.queryParameters.containsKey('store_id'), isFalse);
  });
}
