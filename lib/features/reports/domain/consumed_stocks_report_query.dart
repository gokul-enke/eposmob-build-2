/// IDs and date-only bounds accepted by the consumed-stocks endpoint.
class ConsumedStocksReportQuery {
  const ConsumedStocksReportQuery(
      {this.productId, this.storeId, this.from, this.until});
  final String? productId, storeId;
  final DateTime? from, until;
  static String formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String? get apiFrom => from == null ? null : formatDate(from!);
  String? get apiUntil => until == null ? null : formatDate(until!);
  bool get isInverted =>
      apiFrom != null && apiUntil != null && apiFrom!.compareTo(apiUntil!) > 0;
  bool get isEmpty =>
      productId == null && storeId == null && from == null && until == null;
  bool matches(ConsumedStocksReportQuery other) =>
      productId == other.productId &&
      storeId == other.storeId &&
      apiFrom == other.apiFrom &&
      apiUntil == other.apiUntil;
}

typedef ConsumedStocksReportScope = ({
  String token,
  String? tenant,
  int? activeStoreId,
  String endpoint
});
