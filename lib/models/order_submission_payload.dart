import 'dart:convert';

/// Canonical request contract for every POS order-submission surface.
///
/// UI pages must collect state only. This model is the single place that maps
/// supermarket, mobile, restaurant/attender and kiosk state to the existing
/// `add-to-order` API body. Keeping this model independent of Flutter makes it
/// possible to contract-test every field without mounting a billing screen.
class OrderSubmissionPayload {
  OrderSubmissionPayload({
    required List<Map<String, dynamic>> items,
    required this.transactionNumber,
    this.customerId,
    this.customerPhone,
    this.paymentMethod,
    this.paidAmount,
    List<String>? paymentMethods,
    List<Map<String, dynamic>>? paidMethods,
    this.creditSaleAmount,
    this.balanceAmount,
    this.couponId,
    this.orderId,
    this.comment,
    this.deliveryMethodId,
    this.tableId,
    this.carNumber,
    this.status,
    this.deliveryDate,
    this.deliveryTime,
    this.flatDiscount,
    this.percentageDiscount,
    this.discountAmount,
    this.toCustomerCredit,
    this.address,
    this.addressId,
    this.pincode,
    this.quotationId,
    this.deliveryCharge = 0,
    this.storeId,
    this.sourceType = 'executive',
  })  : items = _copyMaps(items),
        paymentMethods = paymentMethods == null
            ? null
            : List<String>.unmodifiable(paymentMethods),
        paidMethods = paidMethods == null ? null : _copyMaps(paidMethods);

  final List<Map<String, dynamic>> items;
  final int? customerId;
  final String? customerPhone;
  final String transactionNumber;
  final String? paymentMethod;
  final String? paidAmount;
  final List<String>? paymentMethods;
  final List<Map<String, dynamic>>? paidMethods;

  /// Amount intentionally left unpaid on the customer's account.
  ///
  /// This is distinct from [toCustomerCredit], which means that an
  /// overpayment is being added to an existing customer balance. The current
  /// API has no separate credit-sale field, so this amount is mapped to its
  /// existing `balance` field while the local snapshot can still retain the
  /// `DEBIT` metadata for receipts and reconciliation.
  final double? creditSaleAmount;
  final String? balanceAmount;
  final String? couponId;
  final String? orderId;
  final String? comment;
  final String? deliveryMethodId;
  final String? tableId;
  final String? carNumber;
  final String? status;
  final String? deliveryDate;
  final String? deliveryTime;
  final double? flatDiscount;
  final double? percentageDiscount;
  final double? discountAmount;
  final bool? toCustomerCredit;
  final String? address;
  final int? addressId;
  final String? pincode;
  final int? quotationId;
  final double deliveryCharge;
  final int? storeId;
  final String sourceType;

  double get _normalizedCreditSaleAmount =>
      creditSaleAmount != null && creditSaleAmount! > 0 ? creditSaleAmount! : 0;

  bool get usesMultiPayment =>
      paymentMethods != null && paidMethods != null && paidMethods!.isNotEmpty;

  String? get _apiBalanceAmount => _normalizedCreditSaleAmount > 0
      ? _normalizedCreditSaleAmount.toString()
      : balanceAmount;

  /// Produces the exact body accepted by the existing API.
  ///
  /// The backend expects items in reverse cart order. Callers always provide
  /// normal local-cart order so reversal cannot accidentally differ by page.
  Map<String, dynamic> toApiJson({int? fallbackStoreId}) {
    final resolvedStoreId = storeId ?? fallbackStoreId;
    final normalizedPincode = pincode?.trim();
    final body = <String, dynamic>{
      'items': items.reversed.map(Map<String, dynamic>.from).toList(),
      'phone': customerPhone,
      if (customerId != null) 'customer_id': customerId,
      'transaction_number': transactionNumber,
      'payment_method': usesMultiPayment ? paymentMethods : paymentMethod,
      if (usesMultiPayment)
        'paid_methods': paidMethods!.map(Map<String, dynamic>.from).toList()
      else
        'paid_amount': paidAmount,
      'source_type': sourceType,
      'balance': _apiBalanceAmount,
      'coupon_id': couponId,
      if (orderId != null) 'order_id': orderId,
      if (comment != null) 'comment': comment,
      if (deliveryMethodId != null) 'delivery_method_id': deliveryMethodId,
      if (tableId != null) 'table_id': tableId,
      if (carNumber != null) 'car_number': carNumber,
      if (status != null) 'status': status,
      if (deliveryDate != null) 'delivery_date': deliveryDate,
      if (deliveryTime != null) 'delivery_time': deliveryTime,
      if (tableId != null) 'table': tableId,
      if (flatDiscount != null) 'flat_discount': flatDiscount,
      if (percentageDiscount != null) 'percentage_discount': percentageDiscount,
      if (discountAmount != null) 'discount_amount': discountAmount,
      if (toCustomerCredit != null) 'to_customer_credit': toCustomerCredit,
      if (address != null) 'address': address,
      if (addressId != null) 'address_id': addressId,
      if (normalizedPincode != null && normalizedPincode.isNotEmpty)
        'pincode': normalizedPincode,
      if (quotationId != null) 'quotation_id': quotationId,
      'delivery_charge': deliveryCharge,
      if (resolvedStoreId != null) 'store_id': resolvedStoreId,
    };
    return _deepCopy(body);
  }

  /// Produces the existing `update-order` request contract used when a
  /// restaurant/attender confirms an order that already exists on the server.
  /// Items and customer identity are deliberately omitted because that API
  /// updates the existing order referenced by [orderId].
  Map<String, dynamic> toUpdateApiJson() {
    final body = <String, dynamic>{
      'phone': customerPhone,
      'transaction_number': transactionNumber,
      'payment_method': usesMultiPayment ? paymentMethods : paymentMethod,
      if (usesMultiPayment)
        'paid_methods': paidMethods!.map(Map<String, dynamic>.from).toList()
      else
        'paid_amount': paidAmount,
      'source_type': sourceType,
      'balance': _apiBalanceAmount,
      'coupon_id': couponId,
      if (orderId != null) 'order_id': orderId,
      if (comment != null) 'comment': comment,
      if (deliveryMethodId != null) 'delivery_method_id': deliveryMethodId,
      if (tableId != null) 'table_id': tableId,
      if (carNumber != null) 'car_number': carNumber,
      if (status != null) 'status': status,
      if (flatDiscount != null) 'flat_discount': flatDiscount,
      if (percentageDiscount != null) 'percentage_discount': percentageDiscount,
      if (discountAmount != null) 'discount_amount': discountAmount,
      if (toCustomerCredit != null) 'to_customer_credit': toCustomerCredit,
      'delivery_charge': deliveryCharge,
    };
    return _deepCopy(body);
  }

  static List<Map<String, dynamic>> _copyMaps(
    List<Map<String, dynamic>> values,
  ) =>
      List<Map<String, dynamic>>.unmodifiable(
        values.map((value) => _deepCopy(value)),
      );

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}
