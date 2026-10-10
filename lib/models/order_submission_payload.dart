import 'dart:convert';
import 'package:pos_machine/features/billing/domain/cart_discount_breakdown.dart';
import 'package:pos_machine/features/offers/domain/offer_money.dart';

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
    this.clientSaleId,
    this.receiptNumber,
    this.issuedAt,
    this.posDeviceId,
    this.counterNumber,
    this.customerId,
    this.customerPhone,
    this.paymentMethod,
    this.paidAmount,
    List<String>? paymentMethods,
    List<Map<String, dynamic>>? paidMethods,
    this.creditSaleAmount,
    this.balanceAmount,
    this.couponId,
    this.couponCode,
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
    this.grandTotal,
    this.roundOff,
    this.toCustomerCredit,
    this.address,
    this.addressId,
    this.pincode,
    this.quotationId,
    this.deliveryCharge = 0,
    this.storeId,
    this.sourceType = 'executive',
    this.whatsappReceipt = false,
  })  : items = _copyMaps(items),
        paymentMethods = paymentMethods == null
            ? null
            : List<String>.unmodifiable(paymentMethods),
        paidMethods = paidMethods == null ? null : _copyMaps(paidMethods);

  final List<Map<String, dynamic>> items;
  final String? clientSaleId;
  final String? receiptNumber;
  final String? issuedAt;
  final String? posDeviceId;
  final int? counterNumber;
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
  final String? couponCode;

  Map<String, dynamic> get _couponFields =>
      couponFields(couponId, code: couponCode);

  static Map<String, dynamic> couponFields(String? idValue, {String? code}) {
    code = code?.trim();
    // Existing callers store the code in couponId. Never send that string to
    // the integer-only backend field. New callers can supply both explicitly.
    final legacy = idValue?.trim();
    final id = int.tryParse(legacy ?? '');
    return {
      'coupon_id': id,
      if (code?.isNotEmpty == true)
        'coupon_code': code
      else if (legacy?.isNotEmpty == true && id == null)
        'coupon_code': legacy,
    };
  }

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
  final double? grandTotal;
  final double? roundOff;
  final bool? toCustomerCredit;
  final String? address;
  final int? addressId;
  final String? pincode;
  final int? quotationId;
  final double deliveryCharge;
  final int? storeId;
  final String sourceType;

  /// Set by the Confirm & WhatsApp action. The backend sends the invoice to
  /// the customer on WhatsApp when it receives `whatsapp_receipt: true`; every
  /// other confirm action omits the field entirely.
  final bool whatsappReceipt;

  double get _normalizedCreditSaleAmount =>
      creditSaleAmount != null && creditSaleAmount! > 0 ? creditSaleAmount! : 0;

  static const completedSalePricingMode = 'completed_sale';

  /// Per-line fields that only make sense for a completed sale: the receipt
  /// snapshot (standard price, tax and line total). Other orders are priced
  /// by the backend, so they never carry these.
  static const completedSaleLineKeys = <String>[
    'standard_unit_price',
    'tax_rate',
    'tax_amount',
    'total_price',
    'item_discount_amount',
    'discount_origin',
    'offer_name',
    'offer_names',
    'offer_discount_type',
    'offer_discount_value',
  ];

  /// Whether this is a frozen, printed sale being uploaded as a new order:
  /// no existing draft (`order_id`), an executive source, a store, and the
  /// full receipt identity. Only then does the backend keep the submitted
  /// prices instead of pricing the order itself with today's offers.
  bool isCompletedSale({int? fallbackStoreId}) {
    bool has(String? value) => value != null && value.trim().isNotEmpty;
    return orderId == null &&
        sourceType == 'executive' &&
        (storeId ?? fallbackStoreId) != null &&
        has(clientSaleId) &&
        has(receiptNumber) &&
        has(issuedAt) &&
        has(posDeviceId);
  }

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
    final completedSale = isCompletedSale(fallbackStoreId: fallbackStoreId);
    final body = <String, dynamic>{
      'items': items.reversed.map((item) {
        final line = Map<String, dynamic>.from(item);
        if (!completedSale) {
          line.removeWhere((key, _) => completedSaleLineKeys.contains(key));
        }
        return line;
      }).toList(),
      // A printed sale keeps its submitted prices, whether or not an offer
      // applied. The app never prints delivery tax, so the snapshot is zero.
      if (completedSale) 'pricing_mode': completedSalePricingMode,
      if (completedSale) 'delivery_tax_amount': 0,
      if (completedSale && grandTotal != null)
        'grand_total': roundMoney(grandTotal!),
      if (completedSale && roundOff != null) 'round_off': roundMoney(roundOff!),
      if (completedSale &&
          items.every(
              (item) => item['total_price'] is num && item['tax_rate'] is num))
        'tax_total': roundMoney(CartDiscountBreakdown.calculate([
          for (final item in items.reversed)
            (
              total: (item['total_price'] as num).toDouble(),
              taxRate: (item['tax_rate'] as num).toDouble()
            ),
        ], discountAmount ?? 0)
            .fold<double>(0, (sum, line) => sum + line.tax)),
      if (clientSaleId != null) 'client_sale_id': clientSaleId,
      if (receiptNumber != null) 'receipt_number': receiptNumber,
      if (issuedAt != null) 'issued_at': issuedAt,
      if (posDeviceId != null) 'pos_device_id': posDeviceId,
      if (counterNumber != null) 'counter_number': counterNumber,
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
      ..._couponFields,
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
      if (whatsappReceipt) 'whatsapp_receipt': true,
    };
    return _deepCopy(body);
  }

  /// Produces the existing `update-order` request contract used when a
  /// restaurant/attender confirms an order that already exists on the server.
  /// Items and customer identity are deliberately omitted because that API
  /// updates the existing order referenced by [orderId].
  Map<String, dynamic> toUpdateApiJson() {
    final body = <String, dynamic>{
      if (clientSaleId != null) 'client_sale_id': clientSaleId,
      if (receiptNumber != null) 'receipt_number': receiptNumber,
      if (issuedAt != null) 'issued_at': issuedAt,
      if (posDeviceId != null) 'pos_device_id': posDeviceId,
      if (counterNumber != null) 'counter_number': counterNumber,
      'phone': customerPhone,
      'transaction_number': transactionNumber,
      'payment_method': usesMultiPayment ? paymentMethods : paymentMethod,
      if (usesMultiPayment)
        'paid_methods': paidMethods!.map(Map<String, dynamic>.from).toList()
      else
        'paid_amount': paidAmount,
      'source_type': sourceType,
      'balance': _apiBalanceAmount,
      ..._couponFields,
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
      if (whatsappReceipt) 'whatsapp_receipt': true,
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
