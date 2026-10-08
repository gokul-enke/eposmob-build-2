import 'package:pos_machine/features/reports/domain/models/product_sales_report.dart';
import 'package:pos_machine/features/reports/domain/product_sales_query.dart';

const productSalesScope =
    (token: 'token', tenant: 'tenant', storeId: 1, endpoint: 'endpoint');
const categoryOption = ProductSalesOption(id: '88', label: 'Juice');
const productOption =
    ProductSalesOption(id: '9', label: 'Apple Juice', categoryId: '88');
const customerOption = ProductSalesOption(id: '7', label: 'Test Customer');
GetProductSalesReportResponse productReport(int page,
        {int pages = 3, int perPage = 25}) =>
    GetProductSalesReportResponse(
        status: 'success',
        message: 'Product Sales',
        data: ProductSalesReportData(
            entries: [
              ProductSalesReportEntry(
                  productId: page,
                  productName: 'Product $page',
                  category: 'Category',
                  price: 10.25,
                  salesCount: 2.5,
                  totalPrice: 25.625)
            ],
            currency: 'SAR',
            summary: const ProductSalesReportSummary(
                totalRevenue: 76.875, totalQuantity: 7.5),
            pagination: ProductSalesReportPagination(
                currentPage: page,
                lastPage: pages,
                perPage: perPage,
                total: pages)));
