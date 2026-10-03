part of 'purchase_return_detail_view.dart';

extension _Section0 on PurchaseReturnDetailView {
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isStacked = constraints.maxWidth < 400;
          if (isStacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.18,
                    Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s13,
                    0.20,
                    ColorManager.textColor,
                  ),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  '$label:',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s13,
                    0.20,
                    Colors.grey.shade600,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText(
                  value,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s13,
                    0.20,
                    ColorManager.textColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    final isCompleted = status == 'completed';
    final color = isCompleted ? Colors.green.shade700 : Colors.orange.shade800;
    final bgColor = isCompleted
        ? Colors.green.withOpacity(0.1)
        : Colors.orange.withOpacity(0.1);
    final label = isCompleted
        ? 'purchase_return.status_completed'.tr
        : 'purchase_return.status_pending'.tr;

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.schedule,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s11,
              0.13,
              color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileItemCard(PurchaseReturnItemData item) {
    final displayName = item.variantName != null && item.variantName!.isNotEmpty
        ? '${item.productName ?? ''} (${item.variantName})'
        : item.productName ?? '-';

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 10),
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s13,
              0.20,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  'billing.table_qty'.tr,
                  PurchaseReturnPricing.formatQuantity(item.quantity),
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final currency = this.currency;
                    final amount = item.amount?.toStringAsFixed(2) ?? '0.00';
                    return _buildMetric(
                      'purchase_return.total_amount'.tr,
                      '$currency $amount',
                    );
                  },
                ),
              ),
            ],
          ),
          if (item.reason != null && item.reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${'purchase_return.reason'.tr}: ${item.reason}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.18,
                Colors.grey.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
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
            FontSize.s12,
            0.15,
            ColorManager.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsTable(List<PurchaseReturnItemData> items) {
    return PurchaseOrdersResponsiveTable(
      minWidth: 560,
      table: Column(
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
                0: FlexColumnWidth(2),
                1: FixedColumnWidth(70),
                2: FixedColumnWidth(110),
                3: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  children: [
                    _headerCell('confirmed_orders.product'.tr),
                    _headerCell('billing.table_qty'.tr),
                    _headerCell('purchase_return.total_amount'.tr),
                    _headerCell('purchase_return.reason'.tr),
                  ],
                ),
              ],
            ),
          ),
          ...items.map((item) {
            final displayName =
                item.variantName != null && item.variantName!.isNotEmpty
                    ? '${item.productName ?? ''} (${item.variantName})'
                    : item.productName ?? '-';
            return Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FixedColumnWidth(70),
                2: FixedColumnWidth(110),
                3: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  children: [
                    _valueCell(displayName),
                    _valueCell(
                        PurchaseReturnPricing.formatQuantity(item.quantity)),
                    _valueCellWidget(
                      Builder(
                        builder: (context) {
                          final currency = this.currency;
                          final amount =
                              item.amount?.toStringAsFixed(2) ?? '0.00';
                          return Text('$currency $amount');
                        },
                      ),
                    ),
                    _valueCell(item.reason ?? '-'),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _headerCell(String label) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: Text(
        label,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s12,
          0.18,
          ColorManager.kPrimaryColor,
        ),
      ),
    );
  }

  Widget _valueCell(String value) {
    return _valueCellWidget(
      Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _valueCellWidget(Widget child) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: DefaultTextStyle(
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s12,
          0.15,
          ColorManager.textColor,
        ),
        child: child,
      ),
    );
  }
}
