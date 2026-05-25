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
    return Quotation(
      id: json['id'],
      quotationNumber: json['quotation_number']?.toString(),
      customerId: _parseInt(json['customer_id']),
      customer: json['customer']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
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
  final String? quotationDate;
  final String? expiryDate;
  final String? subTotal;
  final String? discount;
  final String? tax;
  final String? grandTotal;
  final int? invoiceId;
  final List<QuotationItem>? items;

  QuotationDetailsData({
    this.id,
    this.quotationNumber,
    this.status,
    this.customer,
    this.store,
    this.address,
    this.quotationDate,
    this.expiryDate,
    this.subTotal,
    this.discount,
    this.tax,
    this.grandTotal,
    this.invoiceId,
    this.items,
  });

  factory QuotationDetailsData.fromJson(Map<String, dynamic> json) {
    var itemList = json['items'] as List?;
    var parsedItems = itemList?.map((i) => QuotationItem.fromJson(i)).toList();
    return QuotationDetailsData(
      id: json['id'],
      quotationNumber: json['quotation_number']?.toString(),
      status: json['status']?.toString(),
      customer: json['customer'] != null
          ? QuotationCustomer.fromJson(json['customer'])
          : null,
      store:
          json['store'] != null ? QuotationStore.fromJson(json['store']) : null,
      address: json['address'],
      quotationDate: json['quotation_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      subTotal: json['sub_total']?.toString(),
      discount: json['discount']?.toString(),
      tax: json['tax']?.toString(),
      grandTotal: json['grand_total']?.toString(),
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
    return QuotationCustomer(
      id: _parseInt(json['id']),
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
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
  });

  factory QuotationItem.fromJson(Map<String, dynamic> json) {
    return QuotationItem(
      id: json['id'],
      productId: json['product_id'],
      productName: json['product_name']?.toString(),
      categoryId: json['category_id'],
      categoryName: json['category_name']?.toString(),
      unit: json['unit']?.toString(),
      unitPrice: json['unit_price']?.toString(),
      quantity: json['quantity']?.toString(),
      taxRate: json['tax_rate']?.toString(),
      taxAmount: json['tax_amount']?.toString(),
      totalPrice: json['total_price']?.toString(),
    );
  }
}
