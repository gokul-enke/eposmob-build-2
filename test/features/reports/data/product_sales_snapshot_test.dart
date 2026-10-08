import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/data/product_sales_snapshot.dart';
import 'package:pos_machine/features/reports/domain/models/product_sales_report.dart';
import '../support/product_sales_fixtures.dart';

GetProductSalesReportResponse _withPagination(int page,
    ProductSalesReportPagination Function(int page) pagination,
    {int rows = 1}) {
  final data = productReport(page).data;
  return GetProductSalesReportResponse(
      status: 'success',
      message: '',
      data: ProductSalesReportData(
          entries: List.filled(rows, data.entries.first),
          currency: data.currency,
          summary: data.summary,
          pagination: pagination(page)));
}

void main() {
  test('all pages and fractional values are retained', () async {
    final rows = await productSalesSnapshot(
        (page) async => productReport(page, perPage: 250),
        pageSize: 250);
    expect(rows.length, 3);
    expect(rows.first.totalPrice, 25.625);
    expect(rows.first.salesCount, 2.5);
  });
  test('server repeating a page fails instead of saving partial export',
      () async {
    await expectLater(
        productSalesSnapshot((page) async => productReport(1), pageSize: 250),
        throwsStateError);
  });
  test('later page HTTP failure propagates without partial success', () async {
    await expectLater(productSalesSnapshot((page) async {
      if (page == 2) throw StateError('network');
      return productReport(page);
    }, pageSize: 250), throwsStateError);
  });
  test('incomplete count and changing pagination fail', () async {
    await expectLater(
        productSalesSnapshot(
            (page) async => _withPagination(
                page,
                (page) => ProductSalesReportPagination(
                    currentPage: page, lastPage: 3, perPage: 25, total: 4)),
            pageSize: 250),
        throwsStateError);
  });
  test('missing total (parsed as 0) does not block a complete export',
      () async {
    final rows = await productSalesSnapshot(
        (page) async => _withPagination(
            page,
            (page) => ProductSalesReportPagination(
                currentPage: page, lastPage: 2, perPage: 250, total: 0)),
        pageSize: 250);
    expect(rows.length, 2);
  });
  test('missing per_page (parsed as 25) allows up to the requested page size',
      () async {
    final rows = await productSalesSnapshot(
        (page) async => _withPagination(
            page,
            (page) => ProductSalesReportPagination(
                currentPage: page, lastPage: 1, perPage: 25, total: 0),
            rows: 120),
        pageSize: 250);
    expect(rows.length, 120);
  });
  test('more rows than requested still fails', () async {
    await expectLater(
        productSalesSnapshot(
            (page) async => _withPagination(
                page,
                (page) => ProductSalesReportPagination(
                    currentPage: page, lastPage: 1, perPage: 250, total: 300),
                rows: 300),
            pageSize: 250),
        throwsStateError);
  });
}
