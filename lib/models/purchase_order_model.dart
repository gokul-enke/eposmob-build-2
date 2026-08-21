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
  // Payment state fields (new — from list-purchase-order API)
  double? paidTotal;
  double? outstandingAmount;
  String? paymentStatus; // "unpaid" | "partially_paid" | "paid"

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
    this.paidTotal,
    this.outstandingAmount,
    this.paymentStatus,
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
    paidTotal = double.tryParse(json['paid_total']?.toString() ?? '');
    outstandingAmount =
        double.tryParse(json['outstanding_amount']?.toString() ?? '');
    paymentStatus = json['payment_status']?.toString();
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
  String? retailPrice;
  String? wholesalePrice;
  String? mrp;
  String? rack;
  String? wholesaleMinUnit;
  String? pkgMfg;
  String? expiryDate;
  String? batchNumber;
  int? purchaseUnitId;
  String? purchaseUnitType;
  String? purchaseUnitConversionRate;
  String? purchaseQty;
  List<Map<String, dynamic>> unitPrices = const [];
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
    this.retailPrice,
    this.wholesalePrice,
    this.mrp,
    this.rack,
    this.wholesaleMinUnit,
    this.pkgMfg,
    this.expiryDate,
    this.batchNumber,
    this.purchaseUnitId,
    this.purchaseUnitType,
    this.purchaseUnitConversionRate,
    this.purchaseQty,
    this.unitPrices = const [],
    this.status,
    this.unit,
  });

  PurchaseOrderItemData.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    categoryId = _parseInt(json['category_id']);
    productId = _parseInt(json['product_id']);
    productName = json['product_name'];
    productVariantId = _parseInt(json['product_variant_id']);
    variantName = json['variant_name']?.toString();
    storeId = _parseInt(json['store_id']);
    supplierId = _parseInt(json['supplier_id']);
    quantity = json['quantity']?.toString();
    unitPrice = json['unit_price']?.toString();
    totalPrice = json['total_price']?.toString();
    calculatedPurchaseRate = json['calculated_purchase_rate']?.toString();
    taxInclude = _parseBool(json['tax_include']);
    taxIncludePurchase = _parseBool(
      json['tax_include_purchase'],
      fallback: taxInclude,
    );
    retailPrice = json['retail_price']?.toString();
    wholesalePrice = json['wholesale_price']?.toString();
    mrp = json['mrp']?.toString();
    rack = json['rack']?.toString();
    wholesaleMinUnit = json['wholesale_min_unit']?.toString();
    pkgMfg = json['pkg_mfg']?.toString();
    expiryDate = json['expiry_date']?.toString();
    batchNumber = json['batch_number']?.toString();
    purchaseUnitId = _parseInt(json['purchase_unit_id']);
    purchaseUnitType = json['purchase_unit_type']?.toString();
    purchaseUnitConversionRate =
        json['purchase_unit_conversion_rate']?.toString();
    purchaseQty = json['purchase_qty']?.toString();
    unitPrices = _parseUnitPrices(json['unit_prices']);
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

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static List<Map<String, dynamic>> _parseUnitPrices(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where((entry) =>
            _parseInt(entry['sale_unit_id']) != null &&
            double.tryParse(entry['price']?.toString() ?? '') != null)
        .map((entry) => {
              'sale_unit_id': _parseInt(entry['sale_unit_id']),
              'price': double.parse(entry['price'].toString()),
            })
        .toList();
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
