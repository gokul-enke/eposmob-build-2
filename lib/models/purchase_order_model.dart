class ListPurchaseOrderModel {
  String? status;
  String? message;
  ListPurchaseOrderData? data;

  ListPurchaseOrderModel({this.status, this.message, this.data});

  ListPurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null ? ListPurchaseOrderData.fromJson(json['data']) : null;
  }
}

class ListPurchaseOrderData {
  int? currentPage;
  int? lastPage;
  List<PurchaseOrderData>? data;

  ListPurchaseOrderData({this.currentPage, this.lastPage, this.data});

  ListPurchaseOrderData.fromJson(Map<String, dynamic> json) {
    currentPage = json['current_page'];
    lastPage = json['last_page'];
    if (json['data'] != null) {
      data = <PurchaseOrderData>[];
      json['data'].forEach((v) {
        data!.add(PurchaseOrderData.fromJson(v));
      });
    }
  }
}

class PurchaseOrderData {
  int? id;
  dynamic voucherNumber;
  String? purchaseDate;
  String? amountTotal;
  SimpleSupplier? supplier;
  SimpleStore? store;
  String? itemsReceived;
  String? status;
  String? createdAt;
  List<PurchaseOrderItemData>? items;

  PurchaseOrderData({
    this.id,
    this.voucherNumber,
    this.purchaseDate,
    this.amountTotal,
    this.supplier,
    this.store,
    this.itemsReceived,
    this.status,
    this.createdAt,
    this.items,
  });


  PurchaseOrderData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    voucherNumber = json['voucher_number'];
    purchaseDate = json['purchase_date'];
    amountTotal = json['amount_total'].toString();
    supplier = json['supplier'] != null ? SimpleSupplier.fromJson(json['supplier']) : null;
    store = json['store'] != null ? SimpleStore.fromJson(json['store']) : null;
    itemsReceived = json['items_received'];
    status = json['status'];
    createdAt = json['created_at'];
    if (json['items'] != null) {
      items = <PurchaseOrderItemData>[];
      json['items'].forEach((v) {
        items!.add(PurchaseOrderItemData.fromJson(v));
      });
    }
  }
}

class PurchaseOrderItemData {
  int? id;
  int? categoryId;
  int? productId;
  String? productName;
  int? storeId;
  int? supplierId;
  String? quantity;
  String? unitPrice;
  String? totalPrice;
  String? expiryDate;
  String? batchNumber;
  String? status;
  String? unit;

  PurchaseOrderItemData({
    this.id,
    this.categoryId,
    this.productId,
    this.productName,
    this.storeId,
    this.supplierId,
    this.quantity,
    this.unitPrice,
    this.totalPrice,
    this.expiryDate,
    this.batchNumber,
    this.status,
    this.unit,
  });


  PurchaseOrderItemData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    categoryId = json['category_id'];
    productId = json['product_id'];
    productName = json['product_name'];
    storeId = json['store_id'];
    supplierId = json['supplier_id'];
    quantity = json['quantity']?.toString();
    unitPrice = json['unit_price']?.toString();
    totalPrice = json['total_price']?.toString();
    expiryDate = json['expiry_date']?.toString();
    batchNumber = json['batch_number']?.toString();
    status = json['status'];
    unit = json['unit']?.toString();
  }
}



class SimpleSupplier {
  int? id;
  String? name;

  SimpleSupplier({this.id, this.name});

  SimpleSupplier.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }
}

class SimpleStore {
  int? id;
  String? name;

  SimpleStore({this.id, this.name});

  SimpleStore.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }
}
