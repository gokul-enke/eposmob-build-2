import 'package:intl/intl.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

/// Shared quotation checkout helpers used by desktop billing and mobile billing
/// so payload shape and validation stay identical.
class QuotationCheckout {
  QuotationCheckout._();

  static const emptyCartMessage = 'Please add items to quote first.';
  static const missingCustomerMessage =
      'Please select or enter a customer before creating quotation.';
  static const expiryBeforeQuotationMessage =
      'Expiry date cannot be before quotation date.';

  static DateTime normalizeExpiryDate({
    required DateTime quotationDate,
    required DateTime expiryDate,
  }) {
    if (expiryDate.isBefore(quotationDate)) {
      return quotationDate.add(const Duration(days: 30));
    }
    return expiryDate;
  }

  static DateTime defaultExpiryFor(DateTime quotationDate) =>
      quotationDate.add(const Duration(days: 30));

  static String? validate({
    required bool cartIsEmpty,
    required bool hasExistingCustomer,
    required bool hasInlineCustomer,
    required DateTime quotationDate,
    required DateTime expiryDate,
  }) {
    if (cartIsEmpty) return emptyCartMessage;
    if (!hasExistingCustomer && !hasInlineCustomer) {
      return missingCustomerMessage;
    }
    if (expiryDate.isBefore(quotationDate)) {
      return expiryBeforeQuotationMessage;
    }
    return null;
  }

  static Map<String, dynamic> buildPayload({
    required bool hasExistingCustomer,
    required int? customerId,
    required String? customerName,
    required String? customerPhone,
    required int? storeId,
    required int? deliveryMethodId,
    required double deliveryCharge,
    required DateTime quotationDate,
    required DateTime expiryDate,
    required double discount,
    required String comment,
    required List<LocalCartItem> cartItems,
  }) {
    final quoteCustomerName = customerName?.trim();
    final quoteCustomerPhone = customerPhone?.trim();

    return <String, dynamic>{
      if (hasExistingCustomer) ...{
        'customer_type': 'existing',
        'customer_id': customerId,
      } else ...{
        'customer_type': 'new',
        'customer_name': quoteCustomerName,
        if (quoteCustomerPhone != null && quoteCustomerPhone.isNotEmpty)
          'customer_phone': quoteCustomerPhone,
      },
      'store_id': storeId,
      if (deliveryMethodId != null) 'delivery_method_id': deliveryMethodId,
      if (deliveryCharge > 0) 'shipping_cost': deliveryCharge,
      'quotation_date': DateFormat('yyyy-MM-dd').format(quotationDate),
      'expiry_date': DateFormat('yyyy-MM-dd').format(expiryDate),
      if (discount > 0) 'discount': discount,
      'comment': comment,
      'items': cartItems.map(_itemToMap).toList(),
    };
  }

  static Map<String, dynamic> _itemToMap(LocalCartItem item) {
    final productStockId = item.stockGroupIds.length == 1
        ? item.stockGroupIds.first
        : item.selectedStock?.id;
    final itemMap = <String, dynamic>{
      'product_id': item.product.productId,
      'quantity': item.hasSaleUnit ? item.displayQuantity : item.quantity,
      'price': item.hasSaleUnit ? item.displayPrice : item.price,
    };
    if (productStockId != null) {
      itemMap['product_stock_id'] = productStockId;
    }
    if (item.saleUnitId != null) {
      itemMap['product_sale_unit_id'] = item.saleUnitId;
    }
    if (item.variantId != null) {
      itemMap['product_variant_id'] = item.variantId;
    }
    return itemMap;
  }

  static dynamic extractCreatedQuotationId(Map<String, dynamic> response) {
    dynamic readPath(dynamic source, List<String> path) {
      dynamic current = source;
      for (final key in path) {
        if (current is! Map) return null;
        current = current[key];
      }
      return current;
    }

    final candidates = <dynamic>[
      response['quotation_id'],
      response['id'],
      readPath(response, ['data', 'quotation_id']),
      readPath(response, ['data', 'id']),
      readPath(response, ['data', 'quotation', 'id']),
      readPath(response, ['quotation', 'id']),
    ];

    final data = response['data'];
    if (data is int || data is String) {
      candidates.add(data);
    }

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final value = candidate.toString().trim();
      if (value.isNotEmpty) return candidate;
    }
    return null;
  }
}
