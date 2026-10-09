class SupplierLedgerQuery {
  const SupplierLedgerQuery(
      {this.supplierId,
      this.supplierName = '',
      this.search = '',
      this.transactionType,
      this.type,
      this.status});
  final String? supplierId, transactionType, type, status;
  final String supplierName, search;
  bool get usesLocalFilters =>
      search.trim().isNotEmpty ||
      status != null ||
      (supplierName.trim().isNotEmpty && supplierId == null);
  (String?, String?, String?) get sourceKey =>
      (supplierId, transactionType, type);
  bool get hasActiveFilters =>
      search.isNotEmpty ||
      supplierName.isNotEmpty ||
      transactionType != null ||
      type != null ||
      status != null;
}
