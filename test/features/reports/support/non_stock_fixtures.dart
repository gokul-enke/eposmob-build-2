import 'package:pos_machine/features/reports/domain/models/non_stock_report.dart';
import 'package:pos_machine/features/reports/domain/models/non_stock_report_pagination.dart';
import 'package:pos_machine/features/reports/domain/non_stock_report_query.dart';

const nonStockScope = (
  token: 'test',
  tenant: 'tenant',
  activeStoreId: 4,
  endpoint: 'https://example.test/non-stock-report'
);
NonStockReportData nonStockRow(int id,
        {String store = 'Store', String status = 'Out of Stock'}) =>
    NonStockReportData(
        id: id,
        name: 'Product $id',
        store: store,
        status: status,
        barcode: '001$id',
        categoryName: 'Category',
        totalQuantity: '0.125',
        reorderLevel: 5,
        unit: 'PC');
GetNonStockReportResponse nonStockPage(int page,
        {int last = 1,
        int perPage = 1,
        int? total,
        List<NonStockReportData>? rows}) =>
    GetNonStockReportResponse(
        status: 'success',
        message: '',
        data: rows ?? [nonStockRow(page)],
        pagination: NonStockReportPagination(
            currentPage: page, lastPage: last, perPage: perPage, total: total));
typedef NonStockCall = ({NonStockReportQuery query, int page});
