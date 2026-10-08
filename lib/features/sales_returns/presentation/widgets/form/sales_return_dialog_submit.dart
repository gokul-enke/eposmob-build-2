part of 'sales_return_form_view.dart';

extension _ReturnDialogSubmission on SalesReturnFormSections {
  Future<void> _submitItemDialog(
      {required BuildContext dialogContext,
      required String orderId,
      required String unitPrice,
      required int cartItemId,
      required double maxQuantity,
      required TextEditingController quantityController,
      required TextEditingController reasonController,
      required void Function(bool) setBusy}) async {
    if (!mounted || !dialogContext.mounted) return;

    final parsedOrderId = int.tryParse(orderId);
    if (parsedOrderId == null) {
      if (mounted && context.mounted)
        showScaffoldError(
          context: context,
          message: 'sales_return_form.error_invalid_order'.tr,
        );
      return;
    }

    final returnQty = double.tryParse(quantityController.text);
    if (returnQty == null || returnQty <= 0) {
      if (mounted && context.mounted)
        showScaffoldError(
          context: context,
          message: 'sales_return_form.error_invalid_qty'.tr,
        );
      return;
    }
    if (returnQty > maxQuantity) {
      if (mounted && context.mounted)
        showScaffoldError(
          context: context,
          message: 'sales_return_form.error_qty_exceeds'.tr,
        );
      return;
    }

    final selection = controller.detailsRequest;
    setBusy(true);

    try {
      final accessToken = controller.ports.token();

      await controller.submitSalesReturn(
        accessToken: accessToken,
        orderId: parsedOrderId,
        price: double.parse(unitPrice),
        quantity: returnQty,
        cartItemId: cartItemId,
        reason: reasonController.text,
        isDeliveryRefundable: deliveryChargeRefundable,
      );

      if (!mounted ||
          !dialogContext.mounted ||
          selection != controller.detailsRequest) return;

      showScaffold(
        context: context,
        message: 'sales_return_form.msg_item_returned'.tr,
      );

      await getOrderDetails(selectedOrderNumber.toString(),
          resetInitialState: false);

      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
    } catch (error, stackTrace) {
      debugPrint('Error submitting sales return: $error');
      debugPrint('Stack Trace for submitSalesReturn: $stackTrace');
      if (mounted && context.mounted)
        showScaffoldError(
          context: context,
          message: error is Exception
              ? error.toString().replaceFirst('Exception: ', '')
              : 'sales_return_form.error_submit_failed'.tr,
        );
    } finally {
      if (mounted && dialogContext.mounted) {
        setBusy(false);
      }
    }
  }
}
