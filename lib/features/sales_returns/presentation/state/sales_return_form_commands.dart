part of 'sales_return_form_controller.dart';

extension SalesReturnFormCommands on SalesReturnFormController {
  Future<bool> completeCurrentReturn() async {
    if (!mounted || isCompletingReturn) return false;
    if (salesReturnItems.isEmpty) {
      ports.error('sales_return_form.error_no_return_items'.tr);
      return false;
    }
    final id = draftReturnOrderId;
    if (id == null) {
      ports.error('sales_return_form.error_no_return_order'.tr);
      return false;
    }
    final amount = double.tryParse(paidAmountController.text) ?? 0.0;
    if (hasPayment) {
      if (paidAmountController.text.isEmpty) {
        ports.error('sales_return_form.error_enter_amount'.tr);
        return false;
      }
      final maximum = refundSummaryFor(salesReturnItems,
              serverBreakdown: serverRefundBreakdown)
          .maxCashRefundAmount;
      if (amount <= 0) {
        ports.error('sales_return_form.error_amount_gt_zero'.tr);
        return false;
      }
      if (amount > maximum) {
        ports.error('sales_return_form.error_amount_exceeds'
            .trParams({'max': maximum.toStringAsFixed(2)}));
        return false;
      }
    }
    final request = detailsRequest;
    setState(() => isCompletingReturn = true);
    try {
      await completeSalesReturn(
          accessToken: ports.token(),
          returnOrderId: id,
          paymentMethod: hasPayment ? selectedPaymentMethod : null,
          paidAmount: hasPayment ? amount : null,
          hasPayment: hasPayment,
          isDeliveryRefundable: deliveryChargeRefundable);
      return mounted && request == detailsRequest;
    } catch (error) {
      if (mounted && request == detailsRequest)
        ports.error(error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'sales_return_form.error_create_failed'.tr);
      return false;
    } finally {
      setState(() => isCompletingReturn = false);
    }
  }
}
