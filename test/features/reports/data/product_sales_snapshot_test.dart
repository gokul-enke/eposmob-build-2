import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/data/product_sales_snapshot.dart';
import 'package:pos_machine/features/reports/domain/models/product_sales_report.dart';
import '../support/product_sales_fixtures.dart';

void main() {
  test('all pages and fractional values are retained', () async {
    final rows = await productSalesSnapshot(
        (page) async => productReport(page, perPage: 250));
    expect(rows.length, 3);
    expect(rows.first.totalPrice, 25.625);
    expect(rows.first.salesCount, 2.5);
  });
  test('server repeating a page fails instead of saving partial export',
      () async {
    await expectLater(productSalesSnapshot((page) async => productReport(1)),
        throwsStateError);
  });
  test('later page HTTP failure propagates without partial success', () async {
    await expectLater(productSalesSnapshot((page) async {
      if (page == 2) throw StateError('network');
      return productReport(page);
    }), throwsStateError);
  });
  test('incomplete count and changing pagination fail', () async {
    await expectLater(productSalesSnapshot((page) async {
      final data = productReport(page).data;
      return GetProductSalesReportResponse(
          status: 'success',
          message: '',
          data: ProductSalesReportData(
              entries: data.entries,
              currency: data.currency,
              summary: data.summary,
              pagination: ProductSalesReportPagination(
                  currentPage: page, lastPage: 3, perPage: 25, total: 4)));
    }), throwsStateError);
  });
}
