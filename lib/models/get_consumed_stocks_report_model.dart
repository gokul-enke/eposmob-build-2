class GetConsumedStocksReportResponse {
  String? status;
  String? message;
  Data? data;

  GetConsumedStocksReportResponse({this.status, this.message, this.data});

  GetConsumedStocksReportResponse.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class Data {
  List<ConsumedStockData>? data;
  Pagination? pagination;

  Data({this.data, this.pagination});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <ConsumedStockData>[];
      json['data'].forEach((v) {
        data!.add(ConsumedStockData.fromJson(v));
      });
    }
    pagination = json['pagination'] != null
        ? Pagination.fromJson(json['pagination'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    if (pagination != null) {
      data['pagination'] = pagination!.toJson();
    }
    return data;
  }
}

class ConsumedStockData {
  int? id;
  String? product;
  String? store;
  String? quantityWithdrawn;
  dynamic oldQuantity;
  dynamic newQuantity;
  String? withdrawnBy;
  String? createdAt;

  ConsumedStockData(
      {this.id,
      this.product,
      this.store,
      this.quantityWithdrawn,
      this.oldQuantity,
      this.newQuantity,
      this.withdrawnBy,
      this.createdAt});

  ConsumedStockData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    product = json['product'];
    store = json['store'];
    quantityWithdrawn = json['quantity_withdrawn'];
    oldQuantity = json['old_quantity'];
    newQuantity = json['new_quantity'];
    withdrawnBy = json['withdrawn_by'];
    createdAt = json['created_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['product'] = product;
    data['store'] = store;
    data['quantity_withdrawn'] = quantityWithdrawn;
    data['old_quantity'] = oldQuantity;
    data['new_quantity'] = newQuantity;
    data['withdrawn_by'] = withdrawnBy;
    data['created_at'] = createdAt;
    return data;
  }
}

class Pagination {
  int? currentPage;
  int? lastPage;
  int? perPage;
  int? total;
  String? firstPageUrl;
  String? lastPageUrl;
  String? nextPageUrl;
  String? prevPageUrl;

  Pagination(
      {this.currentPage,
      this.lastPage,
      this.perPage,
      this.total,
      this.firstPageUrl,
      this.lastPageUrl,
      this.nextPageUrl,
      this.prevPageUrl});

  Pagination.fromJson(Map<String, dynamic> json) {
    currentPage = json['current_page'];
    lastPage = json['last_page'];
    perPage = json['per_page'];
    total = json['total'];
    firstPageUrl = json['first_page_url'];
    lastPageUrl = json['last_page_url'];
    nextPageUrl = json['next_page_url'];
    prevPageUrl = json['prev_page_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['current_page'] = currentPage;
    data['last_page'] = lastPage;
    data['per_page'] = perPage;
    data['total'] = total;
    data['first_page_url'] = firstPageUrl;
    data['last_page_url'] = lastPageUrl;
    data['next_page_url'] = nextPageUrl;
    data['prev_page_url'] = prevPageUrl;
    return data;
  }
}
