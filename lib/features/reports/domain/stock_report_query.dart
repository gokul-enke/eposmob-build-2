enum StockLevel { all, belowReorder }

enum StockExpiry { all, oneMonth, threeMonths, sixMonths, oneYear }

class StockReportOption {
  const StockReportOption(this.id, this.label);
  final String id, label;
}

/// Stock uses product names and date-only values, as the existing endpoint does.
class StockReportQuery {
  const StockReportQuery(
      {this.storeId,
      this.categoryId,
      this.product,
      this.stockLevel = StockLevel.all,
      this.expiry = StockExpiry.all,
      this.snapshot,
      this.from,
      this.until});
  final int? storeId, categoryId;
  final String? product;
  final StockLevel stockLevel;
  final StockExpiry expiry;
  final DateTime? snapshot, from, until;
  String? get stockLevelParameter =>
      stockLevel == StockLevel.all ? null : 'below_reorder';
  String? get expiryParameter => switch (expiry) {
        StockExpiry.all => null,
        StockExpiry.oneMonth => 'one_month',
        StockExpiry.threeMonths => 'three_months',
        StockExpiry.sixMonths => 'six_months',
        StockExpiry.oneYear => 'one_year',
      };
  static String? date(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  bool get valid =>
      from == null || until == null || date(from)!.compareTo(date(until)!) <= 0;
  bool get active =>
      storeId != null ||
      categoryId != null ||
      product != null ||
      stockLevel != StockLevel.all ||
      expiry != StockExpiry.all ||
      snapshot != null ||
      from != null ||
      until != null;
  bool matches(StockReportQuery other) =>
      storeId == other.storeId &&
      categoryId == other.categoryId &&
      product == other.product &&
      stockLevel == other.stockLevel &&
      expiry == other.expiry &&
      date(snapshot) == date(other.snapshot) &&
      date(from) == date(other.from) &&
      date(until) == date(other.until);
}

typedef StockReportScope = ({
  String token,
  String? tenant,
  int? activeStoreId,
  String endpoint
});
