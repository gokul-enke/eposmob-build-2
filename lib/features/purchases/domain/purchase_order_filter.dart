class PurchaseOrderFilter {
  const PurchaseOrderFilter(
      {this.storeId = 'all', this.supplierId, this.dateFrom, this.dateTo});
  final String storeId;
  final String? supplierId;
  final String? dateFrom;
  final String? dateTo;
}
