class QuotationListResponse {
  final String? status;
  final bool? success;
  final String? message;
  final QuotationDataWrapper? data;

  QuotationListResponse({this.status, this.success, this.message, this.data});

  factory QuotationListResponse.fromJson(Map<String, dynamic> json) {
    return QuotationListResponse(
      status: json['status']?.toString(),
      success: json['success'] == true,
      message: json['message']?.toString(),
      data: json['data'] != null
          ? QuotationDataWrapper.fromJson(json['data'])
          : null,
    );
  }
}

class QuotationDataWrapper {
  final int? currentPage;
  final List<Quotation>? data;
  final int? lastPage;
  final int? from;
  final int? to;
  final int? total;

  QuotationDataWrapper({
    this.currentPage,
    this.data,
    this.lastPage,
    this.from,
    this.to,
    this.total,
  });

  factory QuotationDataWrapper.fromJson(Map<String, dynamic> json) {
    var list = json['data'] as List?;
    List<Quotation>? quotationList =
        list?.map((i) => Quotation.fromJson(i)).toList();

    return QuotationDataWrapper(
      currentPage: json['current_page'],
      data: quotationList,
      lastPage: json['last_page'],
      from: json['from'],
      to: json['to'],
      total: json['total'],
    );
  }
}

class Quotation {
  final int? id;
  final String? quotationNumber;
  final int? customerId;
  final String? customer;
  final String? customerPhone;
  final String? store;
  final String? quotationDate;
  final String? expiryDate;
  final String? subTotal;
  final String? discount;
  final String? tax;
  final String? grandTotal;
  final String? status;
  final int? invoiceId;

  Quotation({
    this.id,
    this.quotationNumber,
    this.customerId,
    this.customer,
    this.customerPhone,
    this.store,
    this.quotationDate,
    this.expiryDate,
    this.subTotal,
    this.discount,
    this.tax,
    this.grandTotal,
    this.status,
    this.invoiceId,
  });

  factory Quotation.fromJson(Map<String, dynamic> json) {
    final rawCustomer = json['customer'];
    final customerMap =
        rawCustomer is Map ? Map<String, dynamic>.from(rawCustomer) : null;
    final customerName = customerMap?['name']?.toString() ??
        (rawCustomer is String ? rawCustomer : null) ??
        json['customer_name']?.toString();
    final customerPhone =
        customerMap?['phone']?.toString() ?? json['customer_phone']?.toString();
    return Quotation(
      id: json['id'],
      quotationNumber: json['quotation_number']?.toString(),
      customerId: _parseInt(json['customer_id'] ?? customerMap?['id']),
      customer: customerName,
      customerPhone: customerPhone,
      store: json['store']?.toString(),
      quotationDate: json['quotation_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      subTotal: json['sub_total']?.toString(),
      discount: json['discount']?.toString(),
      tax: json['tax']?.toString(),
      grandTotal: json['grand_total']?.toString(),
      status: json['status']?.toString(),
      invoiceId: json['invoice_id'],
    );
  }
}

class QuotationDetailsResponse {
  final String? status;
  final bool? success;
  final String? message;
  final QuotationDetailsData? data;

  QuotationDetailsResponse(
      {this.status, this.success, this.message, this.data});

  factory QuotationDetailsResponse.fromJson(Map<String, dynamic> json) {
    return QuotationDetailsResponse(
      status: json['status']?.toString(),
      success: json['success'] == true,
      message: json['message']?.toString(),
      data: json['data'] != null
          ? QuotationDetailsData.fromJson(json['data'])
          : null,
    );
  }
}

class QuotationDetailsData {
  final int? id;
  final String? quotationNumber;
  final String? status;
  final QuotationCustomer? customer;
  final QuotationStore? store;
  final dynamic address;
  final int? addressId;
  final String? quotationDate;
  final String? expiryDate;
  final String? subTotal;
  final String? discount;
  final String? tax;
  final String? grandTotal;
  final String? deliveryMethodId;
  final String? deliveryMethod;
  final String? deliveryCharge;
  final String? comment;
  final int? invoiceId;
  final List<QuotationItem>? items;

  QuotationDetailsData({
    this.id,
    this.quotationNumber,
    this.status,
    this.customer,
    this.store,
    this.address,
    this.addressId,
    this.quotationDate,
    this.expiryDate,
    this.subTotal,
    this.discount,
    this.tax,
    this.grandTotal,
    this.deliveryMethodId,
    this.deliveryMethod,
    this.deliveryCharge,
    this.comment,
    this.invoiceId,
    this.items,
  });

  factory QuotationDetailsData.fromJson(Map<String, dynamic> json) {
    var itemList = json['items'] as List?;
    var parsedItems = itemList?.map((i) => QuotationItem.fromJson(i)).toList();
    final dynamic deliveryMethodData = json['delivery_method'];
    final Map<String, dynamic>? deliveryMethodMap =
        deliveryMethodData is Map<String, dynamic> ? deliveryMethodData : null;
    final rawCustomer = json['customer'];
    final customerMap =
        rawCustomer is Map ? Map<String, dynamic>.from(rawCustomer) : null;
    final customerName = customerMap?['name']?.toString() ??
        (rawCustomer is String ? rawCustomer : null) ??
        json['customer_name']?.toString();
    final customerPhone =
        customerMap?['phone']?.toString() ?? json['customer_phone']?.toString();
    final quotationCustomer = customerMap != null
        ? QuotationCustomer.fromJson({
            ...customerMap,
            if (json['customer_id'] != null && customerMap['id'] == null)
              'id': json['customer_id'],
          })
        : (customerName != null || customerPhone != null
            ? QuotationCustomer(
                id: _parseInt(json['customer_id']),
                name: customerName,
                phone: customerPhone,
                isInline: true,
              )
            : null);
    return QuotationDetailsData(
      id: json['id'],
      quotationNumber: json['quotation_number']?.toString(),
      status: json['status']?.toString(),
      customer: quotationCustomer,
      store:
          json['store'] != null ? QuotationStore.fromJson(json['store']) : null,
      address: json['address'],
      addressId: _parseInt(json['address_id']),
      quotationDate: json['quotation_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      subTotal: json['sub_total']?.toString(),
      discount: json['discount']?.toString(),
      tax: json['tax']?.toString(),
      grandTotal: json['grand_total']?.toString(),
      deliveryMethodId: (json['delivery_method_id'] ??
              deliveryMethodMap?['id'] ??
              json['shipping_method_id'])
          ?.toString(),
      deliveryMethod: (json['delivery_method_name'] ??
              deliveryMethodMap?['name'] ??
              (deliveryMethodData is String ? deliveryMethodData : null))
          ?.toString(),
      deliveryCharge:
          (json['delivery_charge'] ?? json['shipping_cost'])?.toString(),
      comment: (json['comment'] ?? json['note'])?.toString(),
      invoiceId: json['invoice_id'],
      items: parsedItems,
    );
  }
}

class QuotationCustomer {
  final int? id;
  final String? name;
  final String? phone;
  final bool isInline;

  QuotationCustomer({this.id, this.name, this.phone, this.isInline = false});

  factory QuotationCustomer.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;
    return QuotationCustomer(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ??
          json['customer_name']?.toString() ??
          user?['name']?.toString(),
      phone: json['phone']?.toString() ??
          json['customer_phone']?.toString() ??
          user?['phone']?.toString(),
      isInline: json['is_inline'] == true,
    );
  }
}

class QuotationStore {
  final int? id;
  final String? name;

  QuotationStore({this.id, this.name});

  factory QuotationStore.fromJson(Map<String, dynamic> json) {
    return QuotationStore(
      id: json['id'],
      name: json['name']?.toString(),
    );
  }
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

class QuotationItem {
  final int? id;
  final int? productId;
  final String? productName;
  final int? categoryId;
  final String? categoryName;
  final String? unit;
  final String? unitPrice;
  final String? quantity;
  final String? taxRate;
  final String? taxAmount;
  final String? totalPrice;
  final int? productStockId;
  final int? productSaleUnitId;
  final String? saleUnitName;
  final String? saleUnitConversionRate;
  final String? comment;

  QuotationItem({
    this.id,
    this.productId,
    this.productName,
    this.categoryId,
    this.categoryName,
    this.unit,
    this.unitPrice,
    this.quantity,
    this.taxRate,
    this.taxAmount,
    this.totalPrice,
    this.productStockId,
    this.productSaleUnitId,
    this.saleUnitName,
    this.saleUnitConversionRate,
    this.comment,
  });

  factory QuotationItem.fromJson(Map<String, dynamic> json) {
    return QuotationItem(
      id: json['id'],
      productId: _parseInt(json['product_id']),
      productName: json['product_name']?.toString(),
      categoryId: _parseInt(json['category_id']),
      categoryName: json['category_name']?.toString(),
      unit: json['unit']?.toString(),
      unitPrice: json['unit_price']?.toString(),
      quantity: json['quantity']?.toString(),
      taxRate: json['tax_rate']?.toString(),
      taxAmount: json['tax_amount']?.toString(),
      totalPrice: json['total_price']?.toString(),
      productStockId: _parseInt(json['product_stock_id'] ?? json['stock_id']),
      productSaleUnitId:
          _parseInt(json['product_sale_unit_id'] ?? json['sale_unit_id']),
      saleUnitName: (json['sale_unit_name'] ?? json['product_sale_unit_name'])
          ?.toString(),
      saleUnitConversionRate: (json['sale_unit_conversion_rate'] ??
              json['product_sale_unit_conversion_rate'])
          ?.toString(),
      comment: (json['comment'] ?? json['note'])?.toString(),
    );
  }
}
