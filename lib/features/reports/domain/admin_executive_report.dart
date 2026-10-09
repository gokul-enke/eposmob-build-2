import 'package:pos_machine/models/sales_executive_report.dart';
import 'my_sales_report.dart';
import 'report_date_range.dart';

class AdminExecutiveScope {
  const AdminExecutiveScope(
      {required this.token,
      required this.tenant,
      required this.storeId,
      required this.actorId,
      required this.role,
      required this.endpoint});
  final String token, tenant, role, endpoint;
  final int storeId, actorId;
  bool sameAs(AdminExecutiveScope other) =>
      token == other.token &&
      tenant == other.tenant &&
      storeId == other.storeId &&
      actorId == other.actorId &&
      role == other.role &&
      endpoint == other.endpoint;
  bool get allowed =>
      token.isNotEmpty &&
      tenant.isNotEmpty &&
      storeId > 0 &&
      actorId > 0 &&
      role.isNotEmpty &&
      role != 'sales_executive';
}

abstract class AdminExecutiveSource {
  AdminExecutiveScope get scope;
  Future<List<SalesExecutiveReportData>> fetch(ReportDateRange range);
}

/// Reuse the report contract/parser without turning absent financial values
/// into zero. The shared detail model and its calculations stay untouched.
List<SalesExecutiveReportData> parseAdminExecutiveReport(dynamic json) {
  final parsed = parseMySalesReport(json);
  final rawRows = json['data'] as List;
  return List.unmodifiable(List.generate(parsed.length, (index) {
    final row = parsed[index], raw = rawRows[index] as Map<String, dynamic>;
    String? value(List<String> keys) {
      for (final key in keys) {
        if (raw[key] != null) return raw[key].toString();
      }
      return null;
    }

    String? breakdown(String key, List<String> fallbacks) {
      final data = raw['payment_breakdown'];
      return data is Map && data[key] != null
          ? data[key].toString()
          : value(fallbacks);
    }

    return SalesExecutiveReportData(
        name: row.name,
        phone: row.phone,
        orderCount: raw['order_count'] == null && raw['orderCount'] == null
            ? null
            : row.orderCount,
        totalSales: value(['total_sales', 'totalSales']),
        onlineSales: value(['online_sales', 'onlineSales']),
        cashSales: value(['cash_sales', 'cashSales']),
        creditSales: value(['credit_sales', 'creditSales']),
        collectedSales: value(['collected_sales', 'collectedSales']),
        upiSales: breakdown('UPI', ['upi_sales', 'upiSales']),
        cardSales: breakdown('CARD', ['card_sales', 'cardSales']),
        totalPaymentReceived: value([
          'total_payment_received',
          'payment_received',
          'totalPaymentReceived'
        ]),
        creditCollectedPrev: value([
          'credit_collected_prev',
          'prev_balance_collected',
          'creditCollectedPrev'
        ]),
        totalCollectedOnSale:
            value(['total_collected_on_sale', 'totalCollectedOnSale']));
  }));
}

bool completeAdminExecutiveRow(SalesExecutiveReportData row) =>
    row.name != null &&
    row.phone != null &&
    (row.orderCount ?? -1) >= 0 &&
    [
      row.totalSales,
      row.onlineSales,
      row.cashSales,
      row.creditSales,
      row.collectedSales
    ].every(
        (value) => value != null && double.tryParse(value)?.isFinite == true) &&
    [
      row.upiSales,
      row.cardSales,
      row.totalPaymentReceived,
      row.creditCollectedPrev,
      row.totalCollectedOnSale
    ].every(
        (value) => value == null || double.tryParse(value)?.isFinite == true);

List<SalesExecutiveReportData> filterAdminExecutives(
    List<SalesExecutiveReportData> rows, String name) {
  final query = name.trim().toLowerCase();
  return List.unmodifiable(query.isEmpty
      ? rows
      : rows.where((row) => (row.name ?? '').toLowerCase().contains(query)));
}
