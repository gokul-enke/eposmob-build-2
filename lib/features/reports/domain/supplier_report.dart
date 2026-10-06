/// Supplier choices are local to the report, independent of profile selection.
class SupplierReportOption {
  const SupplierReportOption({required this.id, required this.name});
  final String id, name;
}

class SupplierReportQuery {
  const SupplierReportQuery({this.supplierId, this.fromDate, this.toDate});
  final String? supplierId, fromDate, toDate;
  bool matches(SupplierReportQuery other) =>
      supplierId == other.supplierId &&
      fromDate == other.fromDate &&
      toDate == other.toDate;
  bool get isDateRangeValid {
    final from = DateTime.tryParse(fromDate ?? '');
    final to = DateTime.tryParse(toDate ?? '');
    return from == null || to == null || !from.isAfter(to);
  }
}

class SupplierTransactionSummary {
  const SupplierTransactionSummary(
      {required this.supplierId,
      required this.displayName,
      required this.totalDebit,
      required this.totalCredit,
      required this.balance,
      required this.transactionCount});
  final String supplierId;
  final String? displayName;
  final double totalDebit, totalCredit, balance;
  final int transactionCount;
}

/// Keeps the grouped and legacy-list response contracts and ID-keyed ordering.
class SupplierReportPage {
  const SupplierReportPage(
      {required this.rows,
      required this.page,
      required this.pages,
      this.perPage = 20});
  final Map<String, SupplierTransactionSummary> rows;
  final int page, pages, perPage;
  factory SupplierReportPage.parse(Map<String, dynamic> response) {
    final data = response['data'];
    final List<dynamic> groups;
    int page = 1, pages = 1, perPage = 20;
    if (data is Map && data['data'] is List) {
      groups = List<dynamic>.from(data['data']);
      page = data['current_page'] is num
          ? (data['current_page'] as num).toInt()
          : int.tryParse('${data['current_page'] ?? 1}') ?? 1;
      pages = data['last_page'] is num
          ? (data['last_page'] as num).toInt()
          : int.tryParse('${data['last_page'] ?? 1}') ?? 1;
      perPage = data['per_page'] is num
          ? (data['per_page'] as num).toInt()
          : int.tryParse('${data['per_page'] ?? 20}') ?? 20;
    } else if (data is List) {
      groups = List<dynamic>.from(data);
    } else {
      throw const FormatException('Invalid supplier report data');
    }
    final rows = <String, SupplierTransactionSummary>{};
    double amount(dynamic value) =>
        value is num ? value.toDouble() : double.tryParse('${value ?? 0}') ?? 0;
    for (final group in groups) {
      if (group is! Map) continue;
      final id = '${group['supplier_id'] ?? ''}'.trim();
      if (id.isEmpty) continue;
      rows[id] = SupplierTransactionSummary(
          supplierId: id,
          displayName: group['supplier_name']?.toString(),
          totalDebit: amount(group['total_debit']),
          totalCredit: amount(group['total_credit']),
          balance: amount(group['balance']),
          transactionCount: group['transactions'] is List
              ? (group['transactions'] as List).length
              : 0);
    }
    return SupplierReportPage(
        rows: Map.unmodifiable(rows),
        page: page < 1 ? 1 : page,
        pages: pages < 1 ? 1 : pages,
        perPage: perPage < 1 ? 20 : perPage);
  }
}

/// Value equality lets the report reject exports across store/session changes.
typedef SupplierReportScope = ({
  String token,
  String? tenant,
  int? storeId,
  String endpoint,
});
