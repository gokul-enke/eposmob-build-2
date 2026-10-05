part of 'sales_return_form_view.dart';

extension _FormSection3 on SalesReturnFormSections {
  Widget _buildDialogProductRow(String label, String value,
      {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.18,
              Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              bold ? FontWeightManager.semiBold : FontWeightManager.medium,
              FontSize.s12,
              0.18,
              ColorManager.textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetails({required bool useItemCards}) {
    return Builder(builder: (context) {
      final salesProvider = controller;
      final salesReturnItems = salesProvider.salesReturnItems;

      if (salesReturnItems.isEmpty) {
        return SalesReturnContentCard(
          padding: const EdgeInsetsDirectional.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                Text(
                  initLoading
                      ? 'sales_return_form.empty_loading'.tr
                      : 'sales_return_form.empty_no_items'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s13,
                    0.25,
                    Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (useItemCards) {
        return Column(
          children: salesReturnItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildMobileReturnItemCard(item, index);
          }).toList(),
        );
      }

      return SalesReturnResponsiveTable(
        minWidth: kSalesReturnItemsTableMinWidth,
        table: SizedBox(
          height: _itemsTableHeight(salesReturnItems.length),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: ColorManager.tableBGColor.withOpacity(0.5),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
                  ),
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1.5),
                    4: FlexColumnWidth(1.5),
                    5: FlexColumnWidth(1.5),
                    6: FlexColumnWidth(1),
                    7: FlexColumnWidth(1.5),
                  },
                  border: null,
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      children: [
                        _buildTableHeader(
                            'sales_return_form.col_product_name'.tr),
                        _buildTableHeader('sales_return_form.col_quantity'.tr),
                        _buildTableHeader(
                            'sales_return_form.col_unit_price'.tr),
                        _buildTableHeader(
                            'sales_return_form.col_total_price'.tr),
                        _buildTableHeader(
                            'sales_return_form.col_returned_qty'.tr),
                        _buildTableHeader(
                            'sales_return_form.col_returned_total'.tr),
                        _buildTableHeader('sales_return_form.col_status'.tr),
                        _buildTableHeader('sales_return_form.col_action'.tr),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1.5),
                      3: FlexColumnWidth(1.5),
                      4: FlexColumnWidth(1.5),
                      5: FlexColumnWidth(1.5),
                      6: FlexColumnWidth(1),
                      7: FlexColumnWidth(1.5),
                    },
                    border: null,
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      ...salesReturnItems.asMap().entries.map((entry) {
                        int index = entry.key;
                        SalesReturnCart item = entry.value;
                        return TableRow(
                          decoration: BoxDecoration(
                            color: index % 2 == 0
                                ? Colors.white
                                : Colors.grey.withOpacity(0.06),
                          ),
                          children: _buildOrderItemTableCells(item),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildMobileReturnItemCard(SalesReturnCart item, int index) {
    final hasValidCartItemId = item.cartItemId > 0;
    final canReturn = hasValidCartItemId &&
        !item.isReturned &&
        SalesReturnCalculationHelper.remainingReturnableQuantity(item) > 0;

    return Container(
      margin: EdgeInsetsDirectional.only(bottom: index > 0 ? 10 : 0),
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s13,
                        0.20,
                        ColorManager.textColor,
                      ),
                    ),
                    if (item.formattedVariantAttributes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.formattedVariantAttributes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s11,
                          0.16,
                          Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                item.isReturned ? Icons.check_circle : Icons.cancel,
                color: item.isReturned ? Colors.green : Colors.red,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMobileItemMetric(
                  'sales_return_form.metric_qty'.tr, item.quantity),
              _buildMobileItemMetric(
                  'sales_return_form.metric_unit'.tr, item.unitPrice),
              _buildMobileItemMetric(
                  'sales_return_form.metric_total'.tr, item.totalPrice),
              _buildMobileItemMetric(
                'sales_return_form.metric_returned'.tr,
                item.returnedQuantity == item.returnedQuantity.roundToDouble()
                    ? item.returnedQuantity.toInt().toString()
                    : item.returnedQuantity.toStringAsFixed(3),
              ),
              _buildMobileItemMetric('sales_return_form.metric_ret_total'.tr,
                  item.returnedTotal.toString()),
            ],
          ),
          const SizedBox(height: 12),
          if (!canReturn)
            Text(
              hasValidCartItemId
                  ? 'sales_return_form.status_returned'.tr
                  : 'sales_return_form.status_unavailable'.tr,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.20,
                hasValidCartItemId ? Colors.green : Colors.red,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.1),
                  foregroundColor: ColorManager.kPrimaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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
                child: Text(
                  'sales_return_form.btn_return_item'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s12,
                    0.20,
                    ColorManager.kPrimaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileItemMetric(String label, String value) {
    return SizedBox(
      width: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s10,
              0.15,
              Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s11,
              0.15,
              ColorManager.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
