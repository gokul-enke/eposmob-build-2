import 'package:pos_machine/features/reports/domain/models/consumed_stocks_report.dart';
import 'package:pos_machine/features/reports/domain/consumed_stocks_report_query.dart';

const consumedScope = (
  token: 'token',
  tenant: 'tenant',
  activeStoreId: 4,
  endpoint: 'https://example.test/consumed-stocks'
);
ConsumedStockData consumedRow(int id,
        {String product = 'Banana',
        String quantity = '1.000000',
        Object? remaining = 0}) =>
    ConsumedStockData(
        id: id,
        product: product,
        store: 'Store',
        quantityWithdrawn: quantity,
        newQuantity: remaining,
        withdrawnBy: 'Admin',
        createdAt: '2026-05-25 04:54:14');
GetConsumedStocksReportResponse consumedPage(int page,
        {int last = 1,
        int per = 1,
        int? total,
        List<ConsumedStockData>? rows}) =>
    GetConsumedStocksReportResponse(
        status: 'success',
        data: Data(
            data: rows ?? [consumedRow(page)],
            pagination: Pagination(
                currentPage: page,
                lastPage: last,
                perPage: per,
                total: total)));
typedef ConsumedCall = ({ConsumedStocksReportQuery query, int page});
