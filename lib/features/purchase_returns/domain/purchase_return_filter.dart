/// Values sent unchanged to the return-list endpoint.
class PurchaseReturnFilter {
  const PurchaseReturnFilter({this.supplierId, this.dateFrom, this.dateTo});
  final String? supplierId;
  final String? dateFrom;
  final String? dateTo;
  static String? optional(String value) =>
      value.trim().isEmpty ? null : value.trim();
}
