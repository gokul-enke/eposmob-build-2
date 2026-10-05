part of 'sales_return_form_view.dart';

extension _FormSection2 on SalesReturnFormSections {
  void _showReturnDialog(
    BuildContext context, {
    required String productName,
    required String unitPrice,
    required String orderId,
    required int cartItemId,
    required String currency,
    required String totalPrice,
    required String quantity,
    required String productUnit,
    required double returnedQuantity,
  }) {
    if (cartItemId <= 0) {
      showScaffoldError(
        context: context,
        message: 'sales_return_form.error_missing_cart_item_id'.tr,
      );
      return;
    }
    final inputs = SalesReturnItemDialogController(
        quantity: quantity,
        unitPrice: unitPrice,
        productUnit: productUnit,
        returnedQuantity: returnedQuantity);
    final quantityController = inputs.quantityController;
    final reasonController = inputs.reasonController;
    final returnTotalController = inputs.returnTotalController;
    final maxQuantity = inputs.maxQuantity;
    final allowsDecimals = inputs.allowsDecimals;
    final hasProductUnit = inputs.hasProductUnit;
    final maxTotal = inputs.maxTotal;
    if (maxQuantity <= 0) {
      showScaffoldError(
        context: context,
        message: 'sales_return_form.error_no_qty'.tr,
      );
      inputs.dispose();
      return;
    }
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: salesReturnIsPhone(context) ? 12 : 40,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                  ),
                  width: salesReturnIsPhone(context)
                      ? MediaQuery.of(context).size.width - 24
                      : MediaQuery.of(context).size.width * 0.9,
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: EdgeInsetsDirectional.all(
                      salesReturnIsPhone(context) ? 16 : 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'sales_return_form.dialog_title'
                                  .trParams({'id': orderId}),
                              style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                FontSize.s18,
                                0.28,
                                ColorManager.textColor,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SalesReturnContentCard(
                        padding: const EdgeInsetsDirectional.all(14),
                        child: salesReturnIsPhone(context)
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDialogProductRow(
                                      'sales_return_form.dialog_col_product'.tr,
                                      productName,
                                      bold: true),
                                  const SizedBox(height: 8),
                                  _buildDialogProductRow(
                                      'sales_return_form.dialog_col_price'.tr,
                                      '$currency $unitPrice'),
                                  const SizedBox(height: 8),
                                  _buildDialogProductRow(
                                      'sales_return_form.dialog_col_total'.tr,
                                      '$currency $totalPrice'),
                                  const SizedBox(height: 8),
                                  _buildDialogProductRow(
                                      'sales_return_form.dialog_col_order_qty'
                                          .tr,
                                      quantity),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'sales_return_form.dialog_col_product_name'
                                              .tr,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.20,
                                            Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'sales_return_form.dialog_col_price'
                                              .tr,
                                          textAlign: TextAlign.center,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.20,
                                            Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'sales_return_form.dialog_col_total_price'
                                              .tr,
                                          textAlign: TextAlign.center,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.20,
                                            Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'sales_return_form.dialog_col_order_quantity'
                                              .tr,
                                          textAlign: TextAlign.center,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.20,
                                            Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          productName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: buildCustomStyle(
                                            FontWeightManager.semiBold,
                                            FontSize.s13,
                                            0.20,
                                            ColorManager.textColor,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '$currency $unitPrice',
                                          textAlign: TextAlign.center,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.18,
                                            ColorManager.textColor,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '$currency $totalPrice',
                                          textAlign: TextAlign.center,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.18,
                                            ColorManager.textColor,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          quantity,
                                          textAlign: TextAlign.center,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s12,
                                            0.18,
                                            ColorManager.textColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: quantityController,
                        decoration: InputDecoration(
                          labelText: 'sales_return_form.field_quantity'.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          helperText: 'sales_return_form.helper_max_returnable'
                              .trParams({
                            'max':
                                '${allowsDecimals ? maxQuantity.toStringAsFixed(3) : maxQuantity.toInt()}'
                          }),
                          errorText:
                              (double.tryParse(quantityController.text) ?? 0) >
                                      maxQuantity
                                  ? 'sales_return_form.error_max_qty'.tr
                                  : null,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          if (hasProductUnit)
                            ...quantityInputFormattersForUnit(productUnit)
                          else if (allowsDecimals)
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,3}'))
                          else
                            FilteringTextInputFormatter.digitsOnly,
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            if (newValue.text.isEmpty) return newValue;
                            final parsed = double.tryParse(newValue.text);
                            if (parsed == null || parsed <= maxQuantity) {
                              return newValue;
                            }
                            return oldValue;
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: returnTotalController,
                        decoration: InputDecoration(
                          labelText: 'sales_return_form.field_return_total'.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          prefixText: '$currency ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            if (newValue.text.isEmpty) return newValue;
                            final doubleValue = double.tryParse(newValue.text);
                            if (doubleValue == null ||
                                doubleValue <= maxTotal) {
                              return newValue;
                            }
                            return oldValue;
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: reasonController,
                        decoration: InputDecoration(
                          labelText: 'sales_return_form.field_reason'.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 24),
                      SalesReturnActionRow(
                        children: [
                          TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: Text('general.cancel'.tr),
                          ),
                          ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => _submitItemDialog(
                                    dialogContext: dialogContext,
                                    orderId: orderId,
                                    unitPrice: unitPrice,
                                    cartItemId: cartItemId,
                                    maxQuantity: maxQuantity,
                                    quantityController: quantityController,
                                    reasonController: reasonController,
                                    setBusy: (value) => setDialogState(
                                        () => isSubmitting = value)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorManager.kPrimaryColor,
                              disabledBackgroundColor:
                                  ColorManager.kPrimaryColor.withOpacity(0.4),
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'sales_return_form.btn_submit'.tr,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    Navigator.of(context, rootNavigator: true).push(route);
    route.completed.whenComplete(inputs.dispose);
  }
}
