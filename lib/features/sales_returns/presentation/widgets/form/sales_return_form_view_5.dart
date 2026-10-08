part of 'sales_return_form_view.dart';

extension _FormSection5 on SalesReturnFormSections {
  Widget _buildSummarySection() {
    return Builder(builder: (context) {
      final salesProvider = controller;
      final salesReturnItems = salesProvider.salesReturnItems;

      if (salesReturnItems.isEmpty) {
        return const SizedBox.shrink();
      }

      double orderTotal = 0.0;
      int totalItems = salesReturnItems.length; // Count of distinct items
      int totalQuantity = 0; // Total quantity of all items
      int returnedItems = 0;
      double returnedQuantity = 0; // Total returned quantity IN THIS SESSION

      for (var item in salesReturnItems) {
        final itemTotal = double.tryParse(item.totalPrice.toString()) ?? 0.0;
        final itemQuantity = double.tryParse(item.quantity) ?? 0;

        orderTotal += itemTotal;
        totalQuantity += itemQuantity.round();

        final initialReturnedQty =
            initialReturnedQuantities[item.cartItemId] ?? 0;

        final currentReturnedQty = item.returnedQuantity;

        final sessionReturnedQty = currentReturnedQty - initialReturnedQty;

        returnedQuantity += sessionReturnedQty;

        if (sessionReturnedQty > 0) {
          returnedItems += 1; // Count items returned in this session
        }
      }

      final refundSummary = refundSummaryFor(
        salesReturnItems,
        serverBreakdown: salesProvider.serverRefundBreakdown,
      );
      final returnDiscount = refundSummary.proRataDiscount;
      final returnedTotal = refundSummary.netRefundAmount;
      final shippingCost =
          (orderDetailsModelData?.deliveryCharge ?? 0).toDouble();

      if (orderDetailsModelData?.priceSummary?.netPayable != null) {
        orderTotal =
            (orderDetailsModelData!.priceSummary!.netPayable!).toDouble();
      }

      final returnedQtyLabel =
          returnedQuantity == returnedQuantity.roundToDouble()
              ? '${returnedQuantity.toInt()}'
              : returnedQuantity.toStringAsFixed(3);

      return SalesReturnTwoColumnLayout(
        start: SalesReturnContentCard(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.shopping_cart,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'sales_return_form.summary_order_title'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.25,
                      Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                  'sales_return_form.summary_total_items'.tr, '$totalItems'),
              const SizedBox(height: 6),
              _buildSummaryRow(
                  'sales_return_form.summary_total_qty'.tr, '$totalQuantity'),
              const SizedBox(height: 6),
              _buildSummaryRow('sales_return_form.summary_discount'.tr,
                  '${(orderDetailsModelData?.priceSummary?.discount ?? 0).toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _buildSummaryRow('sales_return_form.summary_delivery'.tr,
                  '${(orderDetailsModelData?.deliveryCharge ?? 0).toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _buildSummaryRow('sales_return_form.summary_order_total'.tr,
                  '${orderTotal.toStringAsFixed(2)}'),
            ],
          ),
        ),
        end: SalesReturnContentCard(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.assignment_return,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'sales_return_form.summary_return_title'.tr,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.25,
                      Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSummaryRow('sales_return_form.summary_returned_items'.tr,
                  '$returnedItems'),
              const SizedBox(height: 6),
              _buildSummaryRow('sales_return_form.summary_returned_qty'.tr,
                  returnedQtyLabel),
              const SizedBox(height: 6),
              _buildSummaryRow('sales_return_form.summary_discount'.tr,
                  returnDiscount.toStringAsFixed(2)),
              const SizedBox(height: 6),
              _buildSummaryRow('sales_return_form.summary_delivery'.tr,
                  '${(deliveryChargeRefundable ? shippingCost : 0.0).toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _buildSummaryRow('sales_return_form.summary_return_total'.tr,
                  '${returnedTotal.toStringAsFixed(2)}'),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.25,
            Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.25,
            ColorManager.textColor,
          ),
        ),
      ],
    );
  }
}
