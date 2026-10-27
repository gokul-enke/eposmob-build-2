import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/reports/presentation/export/discount_sale_report_export.dart';
import 'package:pos_machine/features/reports/presentation/export/sales_report_export.dart';

/// The workbooks' Applied Filters text: labels and keyed values are
/// translated, names and typed text are kept as they are, even when they
/// happen to equal a translation key (en.json has a top-level "free").
void main() {
  setUp(() {
    Get.testMode = true;
    Get.addTranslations({
      'ar': {
        'free': 'مجاني',
        'report_period.thisMonth': 'هذا الشهر',
        'order_sales_report.date_range': 'النطاق',
        'order_sales_report.filter_products': 'المنتجات',
        'discount_sale_report.date_range': 'النطاق',
        'discount_sale_report.filter_order_number': 'رقم الطلب',
      }
    });
    Get.locale = const Locale('ar');
  });
  tearDown(Get.reset);

  test('Sales: a product named like a translation key stays as named', () {
    expect(
        SalesReportExport.describe([
          (
            'order_sales_report.date_range',
            'report_period.thisMonth',
            translate: true
          ),
          ('order_sales_report.filter_products', 'free', translate: false),
        ]),
        'النطاق: هذا الشهر; المنتجات: free');
  });

  test('Discount: a typed order number stays as typed', () {
    expect(
        DiscountSaleReportExport.describe([
          (
            'discount_sale_report.date_range',
            'report_period.thisMonth',
            translate: true
          ),
          (
            'discount_sale_report.filter_order_number',
            'free',
            translate: false
          ),
        ]),
        'النطاق: هذا الشهر; رقم الطلب: free');
  });
}
