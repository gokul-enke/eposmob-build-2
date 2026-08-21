import 'package:pos_machine/models/purchase_order_model.dart';

class ListPurchaseReturnModel {
  String? status;
  String? message;
  ListPurchaseReturnData? data;

  ListPurchaseReturnModel({this.status, this.message, this.data});

  ListPurchaseReturnModel.fromJson(Map<String, dynamic> json) {
    status = _parseString(json['status']);
    message = _parseString(json['message']);
    data = json['data'] is Map
        ? ListPurchaseReturnData.fromJson(
            Map<String, dynamic>.from(json['data']),
          )
        : null;
  }
}

class ListPurchaseReturnData {
  int? currentPage;
  int? lastPage;
  List<PurchaseReturnData>? data;

  ListPurchaseReturnData({this.currentPage, this.lastPage, this.data});

  ListPurchaseReturnData.fromJson(Map<String, dynamic> json) {
    currentPage = _parseInt(json['current_page']);
    lastPage = _parseInt(json['last_page']);
    if (json['data'] is List) {
      data = <PurchaseReturnData>[];
      for (final value in json['data']) {
        if (value is Map) {
          data!.add(
              PurchaseReturnData.fromJson(Map<String, dynamic>.from(value)));
        }
      }
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
    id = _parseInt(json['id']);
    reference = _parseString(json['reference']);
    purchaseVoucherId = _parseInt(json['purchase_voucher_id']);
    voucherNumber = _parseString(json['voucher_number']);
    supplier = json['supplier'] is Map
        ? SimpleSupplier.fromJson(Map<String, dynamic>.from(json['supplier']))
        : null;
    returnDate = _parseString(json['return_date']);
    totalAmount = double.tryParse(json['total_amount']?.toString() ?? '');
    paidAmount = double.tryParse(json['paid_amount']?.toString() ?? '');
    status = _parseString(json['status']);
    createdBy = json['created_by'] is Map
        ? SimpleCreatedBy.fromJson(
            Map<String, dynamic>.from(json['created_by']),
          )
        : null;
    createdAt = _parseString(json['created_at']);
    if (json['items'] is List) {
      items = <PurchaseReturnItemData>[];
      for (final value in json['items']) {
        if (value is Map) {
          items!.add(
            PurchaseReturnItemData.fromJson(Map<String, dynamic>.from(value)),
          );
        }
      }
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
    id = _parseInt(json['id']);
    purchaseItemId = _parseInt(json['purchase_item_id']);
    productId = _parseInt(json['product_id']);
    productName = _parseString(json['product_name']);
    productVariantId = _parseInt(json['product_variant_id']);
    variantName = _parseString(json['variant_name']);
    quantity = double.tryParse(json['quantity']?.toString() ?? '');
    amount = double.tryParse(json['amount']?.toString() ?? '');
    reason = _parseString(json['reason']);
  }
}

class SimpleCreatedBy {
  int? id;
  String? name;

  SimpleCreatedBy({this.id, this.name});

  SimpleCreatedBy.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    name = _parseString(json['name']);
  }
}

class ReturnableItemsResponse {
  String? status;
  String? message;
  ReturnableItemsData? data;

  ReturnableItemsResponse({this.status, this.message, this.data});

  ReturnableItemsResponse.fromJson(Map<String, dynamic> json) {
    status = _parseString(json['status']);
    message = _parseString(json['message']);
    data = json['data'] is Map
        ? ReturnableItemsData.fromJson(
            Map<String, dynamic>.from(json['data']),
          )
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
    purchaseVoucherId = _parseInt(json['purchase_voucher_id']);
    voucherNumber = _parseString(json['voucher_number']);
    supplier = json['supplier'] is Map
        ? SimpleSupplier.fromJson(Map<String, dynamic>.from(json['supplier']))
        : null;
    store = json['store'] is Map
        ? SimpleStore.fromJson(Map<String, dynamic>.from(json['store']))
        : null;
    if (json['items'] is List) {
      items = <ReturnableItem>[];
      for (final value in json['items']) {
        if (value is Map) {
          items!.add(ReturnableItem.fromJson(Map<String, dynamic>.from(value)));
        }
      }
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
    purchaseItemId = _parseInt(json['purchase_item_id']);
    productId = _parseInt(json['product_id']);
    productName = _parseString(json['product_name']);
    productVariantId = _parseInt(json['product_variant_id']);
    variantName = _parseString(json['variant_name']);
    purchasedQuantity =
        double.tryParse(json['purchased_quantity']?.toString() ?? '');
    returnedQuantity =
        double.tryParse(json['returned_quantity']?.toString() ?? '');
    returnableQuantity =
        double.tryParse(json['returnable_quantity']?.toString() ?? '');
    unitPrice = double.tryParse(json['unit_price']?.toString() ?? '');
  }
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim());
}

String? _parseString(dynamic value) => value?.toString();
