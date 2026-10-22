import 'report_period.dart';

/// Request parameters of `GET /api/v1/sales-report`. Directory filters take
/// comma-separated id lists (see [SalesReportFilter.parameter]).
abstract final class SalesReportParams {
  static const page = 'page';
  static const perPage = 'per_page';
  static const period = 'period';
  static const from = 'from';
  static const to = 'to';
  static const sortDirection = 'sort_direction';

  /// Date Range options, in the web's order; This Month is the default.
  static const periods = [
    ReportPeriod.thisMonth,
    ReportPeriod.lastMonth,
    ReportPeriod.last3Months,
    ReportPeriod.custom,
  ];

  static String periodCode(ReportPeriod period) => switch (period) {
        ReportPeriod.lastMonth => 'last_month',
        ReportPeriod.last3Months => 'last_3_months',
        ReportPeriod.custom => 'custom',
        _ => 'this_month',
      };
}

/// The directory pickers of the Sales Report, in the web's order. Each one
/// takes several ids.
enum SalesReportFilter {
  store('store_ids', 'filter_stores'),
  salesExecutive('sales_executive_ids', 'filter_sales_executives'),
  paymentMethod('payment_method_ids', 'filter_payment_methods'),
  deliveryMethod('delivery_method_ids', 'filter_delivery_modes'),
  category('category_ids', 'filter_categories'),
  product('product_ids', 'filter_products'),
  customer('customer_ids', 'filter_customers');

  const SalesReportFilter(this.parameter, this._label);

  /// API parameter of the comma-separated id list.
  final String parameter;
  final String _label;

  /// Translation key of the picker label, also used in the applied-filters
  /// summary of the export.
  String get labelKey => 'order_sales_report.$_label';
}

/// One choice of a directory filter (store, executive, customer, ...).
class SalesReportOption {
  const SalesReportOption(this.id, this.label);
  final String id, label;
}

typedef SalesReportScope = ({
  String token,
  String? tenant,
  int? activeStoreId,
  String endpoint
});
