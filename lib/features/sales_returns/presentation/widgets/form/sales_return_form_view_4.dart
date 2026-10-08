part of 'sales_return_form_view.dart';

extension _FormSection4 on SalesReturnFormSections {
  List<Widget> _buildOrderItemTableCells(SalesReturnCart item) {
    return [
      SizedBox(height: 55, child: _buildTableCell(item.productName)),
      SizedBox(height: 55, child: _buildTableCell(item.quantity)),
      SizedBox(height: 55, child: _buildTableCell(item.unitPrice)),
      SizedBox(height: 55, child: _buildTableCell(item.totalPrice)),
      SizedBox(
        height: 55,
        child: _buildTableCell(
          item.returnedQuantity == item.returnedQuantity.roundToDouble()
              ? item.returnedQuantity.toInt().toString()
              : item.returnedQuantity.toStringAsFixed(3),
        ),
      ),
      SizedBox(
          height: 55, child: _buildTableCell(item.returnedTotal.toString())),
      SizedBox(
        height: 55,
        child: Center(
          child: Icon(
            item.isReturned ? Icons.check_circle : Icons.cancel,
            color: item.isReturned ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
      ),
      SizedBox(
        height: 55,
        child: Center(
          child: item.cartItemId <= 0 ||
                  item.isReturned ||
                  SalesReturnCalculationHelper.remainingReturnableQuantity(
                          item) <=
                      0
              ? Text(
                  item.cartItemId <= 0
                      ? 'sales_return_form.status_unavailable'.tr
                      : 'sales_return_form.status_returned'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.20,
                    item.cartItemId <= 0 ? Colors.red : Colors.green,
                  ),
                )
              : TextButton(
                  onPressed: () {
                    _showReturnDialog(
                      context,
                      productName: item.productName.toString(),
                      unitPrice: item.unitPrice.toString(),
                      orderId: selectedOrderId.toString(),
                      cartItemId: item.cartItemId,
                      currency: '',
                      totalPrice: item.totalPrice.toString(),
                      quantity: item.quantity.toString(),
                      productUnit: resolvedProductUnit(item),
                      returnedQuantity: item.returnedQuantity,
                    );
                  },
                  child: Text('sales_return_form.btn_return'.tr),
                ),
        ),
      ),
    ];
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
          vertical: 14.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
          vertical: 14.0, horizontal: 12.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s11,
          0.18,
          Colors.black,
        ),
      ),
    );
  }

  Widget _buildCompleteReturnButton(Size size) {
    final canComplete = canCompleteReturn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!canComplete && isOrderSelected && !initLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'sales_return_form.hint_min_one_item'.tr,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s11,
                0.25,
                Colors.grey.shade600,
              ),
            ),
          ),
        Opacity(
          opacity: canComplete ? 1 : 0.45,
          child: CustomRoundButton(
            title: isCompletingReturn
                ? 'sales_return_form.btn_completing'.tr
                : 'sales_return_form.btn_complete_return'.tr,
            fct: canComplete
                ? () async {
                    final completed = await controller.completeCurrentReturn();
                    if (!mounted || !context.mounted || !completed) return;
                    showScaffold(
                        context: context,
                        message: 'sales_return_form.msg_return_created'.tr);
                    onBack();
                  }
                : () {},
            height: 48,
            width: size.width,
            fontSize: FontSize.s13,
            isLoading: isCompletingReturn,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetailItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: ColorManager.kPrimaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s10,
                  0.25,
                  Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.25,
              ColorManager.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
