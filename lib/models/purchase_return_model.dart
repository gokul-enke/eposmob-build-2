import 'package:pos_machine/models/purchase_order_model.dart';

class ListPurchaseReturnModel {
  String? status;
  String? message;
  ListPurchaseReturnData? data;

  ListPurchaseReturnModel({this.status, this.message, this.data});

  ListPurchaseReturnModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null
        ? ListPurchaseReturnData.fromJson(json['data'])
        : null;
  }
}

class ListPurchaseReturnData {
  int? currentPage;
  int? lastPage;
  List<PurchaseReturnData>? data;

  ListPurchaseReturnData({this.currentPage, this.lastPage, this.data});

  ListPurchaseReturnData.fromJson(Map<String, dynamic> json) {
    currentPage = json['current_page'];
    lastPage = json['last_page'];
    if (json['data'] != null) {
      data = <PurchaseReturnData>[];
      json['data'].forEach((v) {
        data!.add(PurchaseReturnData.fromJson(v));
      });
    }
  }
}

class PurchaseReturnData {
  int? id;
  String? reference;
  int? purchaseVoucherId;
  String? voucherNumber;
  SimpleSupplier? supplier;
  String? returnDate;
  double? totalAmount;
  double? paidAmount;
  String? status;
  SimpleCreatedBy? createdBy;
  List<PurchaseReturnItemData>? items;
  String? createdAt;

  PurchaseReturnData({
    this.id,
    this.reference,
    this.purchaseVoucherId,
    this.voucherNumber,
    this.supplier,
    this.returnDate,
    this.totalAmount,
    this.paidAmount,
    this.status,
    this.createdBy,
    this.items,
    this.createdAt,
  });

  PurchaseReturnData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    reference = json['reference'];
    purchaseVoucherId = json['purchase_voucher_id'];
    voucherNumber = json['voucher_number'];
    supplier = json['supplier'] != null
        ? SimpleSupplier.fromJson(json['supplier'])
        : null;
    returnDate = json['return_date'];
    totalAmount = double.tryParse(json['total_amount']?.toString() ?? '');
    paidAmount = double.tryParse(json['paid_amount']?.toString() ?? '');
    status = json['status'];
    createdBy = json['created_by'] != null
        ? SimpleCreatedBy.fromJson(json['created_by'])
        : null;
    createdAt = json['created_at'];
    if (json['items'] != null && json['items'] is List) {
      items = <PurchaseReturnItemData>[];
      json['items'].forEach((v) {
        items!.add(PurchaseReturnItemData.fromJson(v));
      });
    }
  }
}

class PurchaseReturnItemData {
  int? id;
  int? purchaseItemId;
  int? productId;
  String? productName;
  int? productVariantId;
  String? variantName;
  double? quantity;
  double? amount;
  String? reason;

  PurchaseReturnItemData({
    this.id,
    this.purchaseItemId,
    this.productId,
    this.productName,
    this.productVariantId,
    this.variantName,
    this.quantity,
    this.amount,
    this.reason,
  });

  PurchaseReturnItemData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    purchaseItemId = json['purchase_item_id'];
    productId = json['product_id'];
    productName = json['product_name'];
    productVariantId = json['product_variant_id'];
    variantName = json['variant_name'];
    quantity = double.tryParse(json['quantity']?.toString() ?? '');
    amount = double.tryParse(json['amount']?.toString() ?? '');
    reason = json['reason'];
  }
}

class SimpleCreatedBy {
  int? id;
  String? name;

  SimpleCreatedBy({this.id, this.name});

  SimpleCreatedBy.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }
}

class ReturnableItemsResponse {
  String? status;
  String? message;
  ReturnableItemsData? data;

  ReturnableItemsResponse({this.status, this.message, this.data});

  ReturnableItemsResponse.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null
        ? ReturnableItemsData.fromJson(json['data'])
        : null;
  }
}

class ReturnableItemsData {
  int? purchaseVoucherId;
  String? voucherNumber;
  SimpleSupplier? supplier;
  SimpleStore? store;
  List<ReturnableItem>? items;

  ReturnableItemsData({
    this.purchaseVoucherId,
    this.voucherNumber,
    this.supplier,
    this.store,
    this.items,
  });

  ReturnableItemsData.fromJson(Map<String, dynamic> json) {
    purchaseVoucherId = json['purchase_voucher_id'];
    voucherNumber = json['voucher_number'];
    supplier = json['supplier'] != null
        ? SimpleSupplier.fromJson(json['supplier'])
        : null;
    store = json['store'] != null ? SimpleStore.fromJson(json['store']) : null;
    if (json['items'] != null) {
      items = <ReturnableItem>[];
      json['items'].forEach((v) {
        items!.add(ReturnableItem.fromJson(v));
      });
    }
  }
}

class ReturnableItem {
  int? purchaseItemId;
  int? productId;
  String? productName;
  int? productVariantId;
  String? variantName;
  double? purchasedQuantity;
  double? returnedQuantity;
  double? returnableQuantity;
  double? unitPrice;

  ReturnableItem({
    this.purchaseItemId,
    this.productId,
    this.productName,
    this.productVariantId,
    this.variantName,
    this.purchasedQuantity,
    this.returnedQuantity,
    this.returnableQuantity,
    this.unitPrice,
  });

  ReturnableItem.fromJson(Map<String, dynamic> json) {
    purchaseItemId = json['purchase_item_id'];
    productId = json['product_id'];
    productName = json['product_name'];
    productVariantId = json['product_variant_id'];
    variantName = json['variant_name'];
    purchasedQuantity =
        double.tryParse(json['purchased_quantity']?.toString() ?? '');
    returnedQuantity =
        double.tryParse(json['returned_quantity']?.toString() ?? '');
    returnableQuantity =
        double.tryParse(json['returnable_quantity']?.toString() ?? '');
    unitPrice = double.tryParse(json['unit_price']?.toString() ?? '');
  }
}
