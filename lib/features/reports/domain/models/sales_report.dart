import '../report_values.dart';

/// One order of the Sales Report (as the web: Order#, Order Date, Order Value,
/// Payment Methods, Delivery Method, Sales Exe).
class SalesReportRow {
  const SalesReportRow(
      {required this.orderId,
      required this.orderNumber,
      this.orderDate,
      this.orderValue,
      this.paymentMethods,
      this.deliveryMethod,
      this.salesExecutive,
      this.salesExecutiveId,
      this.customer,
      this.store});

  /// Identifies the row, so the export detects a page read twice.
  final int orderId;
  final String orderNumber;
  final DateTime? orderDate;
  final double? orderValue;
  final String? paymentMethods, deliveryMethod, salesExecutive, customer, store;
  final int? salesExecutiveId;

  /// Accepts the field names the web report and the order APIs use.
  factory SalesReportRow.fromJson(Map<String, dynamic> json) {
    final id = reportInt(reportField(json, const ['order_id', 'id']));
    if (id == null || id <= 0) {
      throw const FormatException('Sales report row without order id');
    }
    return SalesReportRow(
      orderId: id,
      orderNumber: reportText(json['order_number']) ?? '#$id',
      // `...Z` timestamps are shown on the local calendar day.
      orderDate: DateTime.tryParse(reportText(
                  reportField(json, const ['order_date', 'created_at'])) ??
              '')
          ?.toLocal(),
      orderValue: reportAmount(reportField(
          json, const ['order_value', 'total_price', 'grand_total', 'total'])),
      paymentMethods: reportText(
          reportField(json, const ['payment_methods', 'payment_method'])),
      deliveryMethod: reportText(
          reportField(json, const ['delivery_method', 'delivery_mode'])),
      salesExecutive: reportText(
          reportField(json, const ['sales_executive_name', 'sales_executive'])),
      salesExecutiveId: reportInt(json['sales_executive_id']),
      customer: reportText(reportField(json, const ['customer_name'])),
      store: reportText(reportField(json, const ['store_name', 'store'])),
    );
  }
}

/// One server page of the Sales Report.
class SalesReportResponse {
  const SalesReportResponse(
      {required this.rows,
      required this.currentPage,
      required this.lastPage,
      required this.perPage,
      this.total,
      this.summary = const {}});
  final List<SalesReportRow> rows;
  final int currentPage, lastPage, perPage;
  final int? total;

  /// Totals over every matching row (not just this page), as the API sends
  /// them in `data.summary` (`orders`, `order_value`); values that are not
  /// numbers are left out.
  final Map<String, double> summary;

  /// Reads `{status, data: [...], pagination|meta: {...}}` or a Laravel
  /// paginator `{status, data: {data: [...], pagination|current_page, ...,
  /// summary}}`. A missing pagination block means everything came on one page.
  static SalesReportResponse parse(Object? json) {
    if (json is! Map || json['status'] != 'success') {
      throw const FormatException('Invalid sales report envelope');
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
    if (list == null) throw const FormatException('Invalid sales report rows');
    final rows = [
      for (final item in list)
        if (item is Map<String, dynamic>)
          SalesReportRow.fromJson(item)
        else
          throw const FormatException('Invalid sales report row')
    ];
    final totals = <String, double>{
      if (summary is Map)
        for (final entry in summary.entries)
          if (reportAmount(entry.value) case final double value)
            '${entry.key}': value
    };
    if (meta == null || meta['current_page'] == null) {
      return SalesReportResponse(
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
      throw const FormatException('Invalid sales report pagination');
    }
    return SalesReportResponse(
        rows: rows,
        currentPage: current,
        lastPage: last < 1 ? 1 : last,
        perPage: per,
        total: reportInt(meta['total']),
        summary: totals);
  }
}
