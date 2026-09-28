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
    // Orders return customer KYC as a top-level `kyc_info` and the full
    // customer as `customer_details`; accept the same shapes here, added
    // alongside `customer`, so quotation prints match the order receipt.
    final kycInfo = json['kyc_info'] is Map
        ? Map<String, dynamic>.from(json['kyc_info'] as Map)
        : null;
    final customerDetailsMap = json['customer_details'] is Map
        ? Map<String, dynamic>.from(json['customer_details'] as Map)
        : null;
    final quotationCustomer = customerMap != null || customerDetailsMap != null
        ? QuotationCustomer.fromJson({
            // `customer` wins; `customer_details` fills what it leaves out.
            ...?customerDetailsMap,
            if (customerDetailsMap?['customer_id'] != null)
              'id': customerDetailsMap!['customer_id'],
            for (final entry in customerMap?.entries ??
                const <MapEntry<String, dynamic>>[])
              if (entry.value != null) entry.key: entry.value,
            if (customerMap?['id'] == null &&
                customerDetailsMap?['customer_id'] == null &&
                json['customer_id'] != null)
              'id': json['customer_id'],
            if (kycInfo != null && customerMap?['kyc_info'] == null)
              'kyc_info': kycInfo,
          })
        : (customerName != null || customerPhone != null
            ? QuotationCustomer(
                id: _parseInt(json['customer_id']),
                name: customerName,
                phone: customerPhone,
                vatNumber: _nonEmpty(kycInfo?['vat_number']),
                crNumber: _nonEmpty(kycInfo?['cr_number']),
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

  /// Printable customer address, same priority as the order receipt: the
  /// quotation's delivery `address` first, then the customer's own address.
  String? get customerAddressForDisplay =>
      formatQuotationAddress(address) ?? customer?.address;
}

/// Formats an address the way the order receipt does for
/// `customer_details.address`: address, landmark, city, state, pincode.
/// Accepts a plain string, an address map, or a list of either (first
/// non-empty entry wins).
String? formatQuotationAddress(dynamic raw) {
  if (raw == null) return null;
  if (raw is List) {
    for (final entry in raw) {
      final formatted = formatQuotationAddress(entry);
      if (formatted != null) return formatted;
    }
    return null;
  }
  if (raw is! Map) return _nonEmpty(raw);

  final parts = <String>[];
  void addPart(dynamic value) {
    final text = _nonEmpty(value is Map ? value['name'] : value);
    if (text != null && !parts.contains(text)) parts.add(text);
  }

  addPart(raw['address']);
  addPart(raw['landmark']);
  addPart(raw['city']);
  addPart(raw['state']);
  final pincode = raw['pincode'];
  addPart(pincode is Map ? pincode['pin_code'] : pincode);
  return parts.isEmpty ? null : parts.join(', ');
}

class QuotationCustomer {
  final int? id;
  final String? name;
  final String? phone;
  final String? email;
  final String? alternatePhone;
  final String? address;
  final String? customerType;
  final String? vatNumber;
  final String? crNumber;
  final bool isInline;

  QuotationCustomer({
    this.id,
    this.name,
    this.phone,
    this.email,
    this.alternatePhone,
    this.address,
    this.customerType,
    this.vatNumber,
    this.crNumber,
    this.isInline = false,
  });

  static const vatKycKeys = {'VAT', 'VAT NUMBER'};
  static const crKycKeys = {'CR', 'CR NUMBER', 'COMMERCIAL REGISTRATION'};

  factory QuotationCustomer.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;
    final kycInfo = json['kyc_info'] is Map
        ? Map<String, dynamic>.from(json['kyc_info'] as Map)
        : null;
    final kycList = json['kyc'] ?? user?['kyc'];
    return QuotationCustomer(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ??
          json['customer_name']?.toString() ??
          user?['name']?.toString(),
      phone: json['phone']?.toString() ??
          json['customer_phone']?.toString() ??
          user?['phone']?.toString(),
      email: _nonEmpty(json['email'] ?? user?['email']),
      alternatePhone: _nonEmpty(json['alternate_phone'] ??
          json['alt_phone'] ??
          user?['alternate_phone'] ??
          user?['alt_phone']),
      address: formatQuotationAddress(json['address'] ?? json['addresses']),
      customerType: _nonEmpty(json['customer_type'] ?? user?['customer_type']),
      vatNumber: _nonEmpty(json['vat_number']) ??
          _nonEmpty(kycInfo?['vat_number']) ??
          kycValue(kycList, vatKycKeys),
      crNumber: _nonEmpty(json['cr_number']) ??
          _nonEmpty(kycInfo?['cr_number']) ??
          kycValue(kycList, crKycKeys),
      isInline: json['is_inline'] == true,
    );
  }

  /// First non-empty value in a customer `kyc` list (`[{key, value}]`) whose
  /// key, normalised to upper case with `_` as space, is in [acceptedKeys].
  static String? kycValue(dynamic kycList, Set<String> acceptedKeys) {
    if (kycList is! List) return null;
    for (final item in kycList) {
      if (item is! Map) continue;
      final key =
          item['key']?.toString().trim().toUpperCase().replaceAll('_', ' ');
      final value = _nonEmpty(item['value']);
      if (key != null && acceptedKeys.contains(key) && value != null) {
        return value;
      }
    }
    return null;
  }
}

String? _nonEmpty(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
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
