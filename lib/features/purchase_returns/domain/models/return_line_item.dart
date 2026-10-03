import 'purchase_return.dart';
import '../purchase_return_pricing.dart';

class ReturnLineItem {
  ReturnLineItem(
      {required this.source,
      required this.unitPrice,
      required this.quantity,
      this.reason = ''});
  final ReturnableItem source;
  final double unitPrice;
  double quantity;
  String reason;
  double get amount =>
      PurchaseReturnPricing.roundCurrency(quantity * unitPrice);
  Map<String, dynamic> toPayload() => {
        'purchase_item_id': source.purchaseItemId,
        'quantity': quantity,
        if (reason.isNotEmpty) 'reason': reason,
      };
}
