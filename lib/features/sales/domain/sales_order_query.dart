class SalesOrderQuery {
  const SalesOrderQuery(
      {this.storeId,
      this.orderNumber,
      this.filterName,
      this.date,
      this.from,
      this.until,
      this.businessDate,
      this.customerId,
      this.productId,
      this.filterStatus,
      this.filterPrice,
      this.filterEmail,
      this.filterPhone,
      this.filterStore,
      this.filterCreatedBy,
      this.page,
      this.filterOnlineSales});
  final int? storeId;
  final String? orderNumber;
  final String? filterName;
  final String? date;
  final String? from;
  final String? until;
  final String? businessDate;
  final int? customerId;
  final int? productId;
  final String? filterStatus;
  final String? filterPrice;
  final String? filterEmail;
  final String? filterPhone;
  final String? filterStore;
  final String? filterCreatedBy;
  final int? page;
  final bool? filterOnlineSales;
  Map<String, String> parameters(int? activeStoreId) {
    final orderNumber = this.orderNumber;
    final filterName = this.filterName;
    final date = this.date;
    final from = this.from;
    final until = this.until;
    final businessDate = this.businessDate;
    final customerId = this.customerId;
    final productId = this.productId;
    final filterStatus = this.filterStatus;
    final filterPrice = this.filterPrice;
    final filterEmail = this.filterEmail;
    final filterPhone = this.filterPhone;
    final filterStore = this.filterStore;
    final filterCreatedBy = this.filterCreatedBy;
    final page = this.page;
    final filterOnlineSales = this.filterOnlineSales;
    final queryParameters = <String, String>{};
    final resolvedStore = storeId ?? activeStoreId;
    if (resolvedStore != null)
      queryParameters['store_id'] = resolvedStore.toString();
    if (orderNumber != null) queryParameters['number'] = orderNumber;
    if (filterName != null) queryParameters['filter_name'] = filterName;
    if (date != null && date.isNotEmpty) {
      queryParameters['order_date'] = date;
    }
    if (from != null && from.isNotEmpty) {
      queryParameters['filter_datetime[from]'] = from;
    }
    if (until != null && until.isNotEmpty) {
      queryParameters['filter_datetime[until]'] = until;
    }
    if (businessDate != null) queryParameters['business_date'] = businessDate;
    if (customerId != null) {
      queryParameters['customer_id'] = customerId.toString();
    }
    if (productId != null) queryParameters['product_id'] = productId.toString();
    if (filterStatus != null) queryParameters['filter_status'] = filterStatus;
    if (filterPrice != null) queryParameters['filter_price'] = filterPrice;
    if (filterEmail != null) queryParameters['filter_email'] = filterEmail;
    if (filterPhone != null) queryParameters['filter_phone'] = filterPhone;
    if (filterStore != null) queryParameters['filter_store'] = filterStore;
    if (filterCreatedBy != null) {
      queryParameters['filter_created_by'] = filterCreatedBy;
    }
    if (page != null) queryParameters['page'] = page.toString();
    if (filterOnlineSales != null) {
      queryParameters['filter_online_sales'] = filterOnlineSales.toString();
    }

    return queryParameters;
  }
}
