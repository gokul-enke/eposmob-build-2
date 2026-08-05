class ListPurchaseOrderModel {
  String? status;
  String? message;
  ListPurchaseOrderData? data;

  ListPurchaseOrderModel({this.status, this.message, this.data});

  ListPurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null
        ? ListPurchaseOrderData.fromJson(json['data'])
        : null;
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
  String? discount;
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
    this.discount,
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
    discount = json['discount']?.toString();
    supplier = json['supplier'] != null
        ? SimpleSupplier.fromJson(json['supplier'])
        : null;
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
  int? productVariantId;
  String? variantName;
  int? storeId;
  int? supplierId;
  String? quantity;
  String? unitPrice;
  String? totalPrice;
  String? calculatedPurchaseRate;
  bool? taxInclude;
  bool? taxIncludePurchase;
  String? expiryDate;
  String? batchNumber;
  String? status;
  String? unit;

  PurchaseOrderItemData({
    this.id,
    this.categoryId,
    this.productId,
    this.productName,
    this.productVariantId,
    this.variantName,
    this.storeId,
    this.supplierId,
    this.quantity,
    this.unitPrice,
    this.totalPrice,
    this.calculatedPurchaseRate,
    this.taxInclude,
    this.taxIncludePurchase,
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
    productVariantId = json['product_variant_id'] is int
        ? json['product_variant_id'] as int
        : json['product_variant_id'] != null
            ? int.tryParse(json['product_variant_id'].toString())
            : null;
    variantName = json['variant_name']?.toString();
    storeId = json['store_id'];
    supplierId = json['supplier_id'];
    quantity = json['quantity']?.toString();
    unitPrice = json['unit_price']?.toString();
    totalPrice = json['total_price']?.toString();
    calculatedPurchaseRate = json['calculated_purchase_rate']?.toString();
    taxInclude = _parseBool(json['tax_include']);
    taxIncludePurchase = _parseBool(
      json['tax_include_purchase'],
      fallback: taxInclude,
    );
    expiryDate = json['expiry_date']?.toString();
    batchNumber = json['batch_number']?.toString();
    status = json['status'];
    unit = json['unit']?.toString();
  }

  static bool? _parseBool(dynamic value, {bool? fallback}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;

    switch (value.toString().trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'y':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'n':
        return false;
      default:
        return fallback;
    }
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
