import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/domain/models/product_sales_report.dart';

void main() {
  test('parses the documented product sales report response', () {
    final response = GetProductSalesReportResponse.fromJson({
      'status': 'success',
      'message': 'Product Sales Report',
      'data': {
        'data': [
          {
            'product_id': 3,
            'product_name': 'Chocolate Cake',
            'category': 'Birthday cakes',
            'price': 800,
            'sales_count': 46,
            'total_price': 44600,
          },
        ],
        'currency': 'INR',
        'summary': {
          'total_revenue': 94725,
          'total_quantity': 121,
        },
        'pagination': {
          'current_page': 1,
          'last_page': 2,
          'per_page': 25,
          'total': 26,
        },
      },
    });

    expect(response.status, 'success');
    expect(response.data.currency, 'INR');
    expect(response.data.entries, hasLength(1));
    expect(response.data.entries.single.productName, 'Chocolate Cake');
    expect(response.data.entries.single.price, 800);
    expect(response.data.entries.single.salesCount, 46);
    expect(response.data.entries.single.totalPrice, 44600);
    expect(response.data.summary.totalRevenue, 94725);
    expect(response.data.summary.totalQuantity, 121);
    expect(response.data.pagination.lastPage, 2);
    expect(response.data.pagination.total, 26);
  });

  test('accepts numeric report values returned as strings', () {
    final entry = ProductSalesReportEntry.fromJson({
      'product_id': '7',
      'product_name': 'Vancho',
      'category': 'Birthday cakes',
      'price': '850.50',
      'sales_count': '1.000',
      'total_price': '850.50',
    });

    expect(entry.productId, 7);
    expect(entry.price, 850.5);
    expect(entry.salesCount, 1);
    expect(entry.totalPrice, 850.5);
  });
}
