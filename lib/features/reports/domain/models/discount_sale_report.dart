import '../discount_sale_report_query.dart';
import '../report_values.dart';

/// One discounted order of the Discount Sale Report.
class DiscountSaleReportRow {
  const DiscountSaleReportRow(
      {required this.orderId,
      required this.orderNumber,
      this.orderDate,
      this.offlineReceiptNumber,
      this.salesExecutive,
      this.salesExecutiveId,
      this.customer,
      this.discountTypeText,
      this.cartItemsDiscount,
      this.overallOrderDiscount,
      this.discountAmount,
      this.store});

  final int orderId;
  final String orderNumber;
  final DateTime? orderDate;
  final String? offlineReceiptNumber, salesExecutive, customer, store;
  final int? salesExecutiveId;

  /// As the API sent it; [discountType] is its known meaning.
  final String? discountTypeText;
  final double? cartItemsDiscount, overallOrderDiscount, discountAmount;

  DiscountType? get discountType => DiscountType.fromCode(discountTypeText);

  /// Field names of the API (`item_discount`, `discount`, `total_discount`,
  /// `executive_name`), with the descriptive names as fallbacks.
  factory DiscountSaleReportRow.fromJson(Map<String, dynamic> json) {
    final id = reportInt(reportField(json, const ['order_id', 'id']));
    if (id == null || id <= 0) {
      throw const FormatException('Discount report row without order id');
    }
    return DiscountSaleReportRow(
      orderId: id,
      orderNumber: reportText(json['order_number']) ?? '#$id',
      // `...Z` timestamps are shown on the local calendar day.
      orderDate: DateTime.tryParse(reportText(
                  reportField(json, const ['order_date', 'created_at'])) ??
              '')
          ?.toLocal(),
      offlineReceiptNumber: reportText(json['offline_receipt_number']),
      salesExecutive: reportText(reportField(json,
          const ['executive_name', 'sales_executive_name', 'sales_executive'])),
      salesExecutiveId: reportInt(
          reportField(json, const ['executive_id', 'sales_executive_id'])),
      customer:
          reportText(reportField(json, const ['customer_name', 'customer'])),
      discountTypeText: reportText(json['discount_type']),
      cartItemsDiscount: reportAmount(
          reportField(json, const ['item_discount', 'cart_items_discount'])),
      overallOrderDiscount: reportAmount(
          reportField(json, const ['discount', 'overall_order_discount'])),
      discountAmount: reportAmount(
          reportField(json, const ['total_discount', 'discount_amount'])),
      store: reportText(reportField(json, const ['store_name', 'store'])),
    );
  }
}

/// One server page of the report.
class DiscountSaleReportResponse {
  const DiscountSaleReportResponse(
      {required this.rows,
      required this.currentPage,
      required this.lastPage,
      required this.perPage,
      this.total,
      this.summary = const {}});
  final List<DiscountSaleReportRow> rows;
  final int currentPage, lastPage, perPage;
  final int? total;

  /// Totals over every matching row (not just this page), as the API sends
  /// them in `data.summary`; values that are not numbers are left out.
  final Map<String, double> summary;

  /// Reads `{status, data: [...], pagination|meta: {...}}` or a Laravel
  /// paginator `{status, data: {data: [...], pagination|current_page, ...,
  /// summary}}`. A missing pagination block means everything came on one page.
  static DiscountSaleReportResponse parse(Object? json) {
    if (json is! Map || json['status'] != 'success') {
      throw const FormatException('Invalid report envelope');
    }
    final data = json['data'];
    List? list;
    Map? meta;
    Object? summary;
    if (data is List) {
      list = data;
      final m = json['pagination'] ?? json['meta'];
      meta = m is Map ? m : null;
      summary = json['summary'];
    } else if (data is Map && data['data'] is List) {
      list = data['data'] as List;
      final m = data['pagination'] ?? data['meta'];
      meta = m is Map ? m : data;
      summary = data['summary'];
    }
    if (list == null) throw const FormatException('Invalid report rows');
    final rows = [
      for (final item in list)
        if (item is Map<String, dynamic>)
          DiscountSaleReportRow.fromJson(item)
        else
          throw const FormatException('Invalid report row')
    ];
    final totals = <String, double>{
      if (summary is Map)
        for (final entry in summary.entries)
          if (reportAmount(entry.value) case final double value)
            '${entry.key}': value
    };
    if (meta == null || meta['current_page'] == null) {
      return DiscountSaleReportResponse(
          rows: rows,
          currentPage: 1,
          lastPage: 1,
          perPage: rows.isEmpty ? 1 : rows.length,
          total: rows.length,
          summary: totals);
    }
    final current = reportInt(meta['current_page']),
        last = reportInt(meta['last_page']),
        per = reportInt(meta['per_page']);
    if (current == null || last == null || per == null || per < 1) {
      throw const FormatException('Invalid report pagination');
    }
    return DiscountSaleReportResponse(
        rows: rows,
        currentPage: current,
        lastPage: last < 1 ? 1 : last,
        perPage: per,
        total: reportInt(meta['total']),
        summary: totals);
  }
}
