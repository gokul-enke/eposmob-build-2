import 'report_period.dart';

/// Request parameters of `GET /api/v1/discount-sales-report`. Every picker
/// takes a single id (lists are ignored by the API).
abstract final class DiscountSaleReportParams {
  static const page = 'page';
  static const perPage = 'per_page';
  static const dateRange = 'sales_date_range';
  static const from = 'from';
  static const to = 'to';
  static const discountType = 'discount_type';

  /// Matches the order number or the offline receipt number, partially.
  static const orderNumber = 'order_number';

  /// Date Range options of the web report; This Month is the default.
  static const periods = [
    ReportPeriod.today,
    ReportPeriod.thisWeek,
    ReportPeriod.thisMonth,
    ReportPeriod.custom,
  ];

  static String periodCode(ReportPeriod period) => switch (period) {
        ReportPeriod.today => 'today',
        ReportPeriod.thisWeek => 'week',
        ReportPeriod.custom => 'custom',
        _ => 'month',
      };
}

/// Discount Type filter of the web report.
enum DiscountType {
  all(''),
  cartItems('items'),
  overallOrder('order');

  const DiscountType(this.code);

  /// Value sent to the API; empty for All (not sent).
  final String code;

  String get labelKey => switch (this) {
        DiscountType.all => 'discount_sale_report.type_all',
        DiscountType.cartItems => 'discount_sale_report.type_cart_items',
        DiscountType.overallOrder => 'discount_sale_report.type_overall_order',
      };

  /// Reads the API's text ("Cart items level", "Overall order level") or
  /// code; unknown text gives null (shown as sent).
  static DiscountType? fromCode(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return null;
    if (value == 'items' || value.startsWith('cart')) return cartItems;
    if (value == 'order' || value.startsWith('overall')) return overallOrder;
    return null;
  }
}

/// The single-choice pickers of the report, in the order the export's
/// applied filters list them.
enum DiscountSaleReportFilter {
  store('store_id', 'discount_sale_report.filter_store'),
  salesExecutive('executive_id', 'discount_sale_report.filter_executive'),
  customer('customer_id', 'discount_sale_report.filter_customer');

  const DiscountSaleReportFilter(this.parameter, this.labelKey);

  /// The API parameter that takes the picked id. `store_id` *is* the Store
  /// filter: the session's active store is never sent.
  final String parameter;

  /// Translation key of the picker label.
  final String labelKey;
}

/// One choice of a picker (store, executive, customer).
class DiscountSaleReportOption {
  const DiscountSaleReportOption(this.id, this.label);
  final String id, label;
}

typedef DiscountSaleReportScope = ({
  String token,
  String? tenant,
  int? activeStoreId,
  String endpoint
});
