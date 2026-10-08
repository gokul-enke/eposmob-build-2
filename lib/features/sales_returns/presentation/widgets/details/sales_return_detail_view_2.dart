part of 'sales_return_detail_view.dart';

extension _DetailSection2 on SalesReturnDetailSections {
  Widget _buildMobileItemCard(SalesReturnItem item) {
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
            salesReturnItemDisplayName(item, _loadedItems),
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
                child: _buildItemMetric(
                  'billing.table_qty'.tr,
                  item.quantity.toString(),
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final currency = this.currency;
                    final raw = salesReturnItemUnitPrice(item, _loadedItems);
                    final parsed = double.tryParse(raw);
                    final amount =
                        parsed != null ? parsed.toStringAsFixed(2) : raw;
                    return _buildItemMetric(
                      'sales.price'.tr,
                      '$currency $amount',
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Reason: ${salesReturnItemReason(item, _loadedItems)}',
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
      ),
    );
  }

  Widget _buildItemMetric(String label, String value) {
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

  Widget _buildItemsTable(BuildContext context) {
    return _buildItemsTableShell(
      Table(
        columnWidths: const {
          0: FlexColumnWidth(1.5),
          1: FixedColumnWidth(70),
          2: FixedColumnWidth(105),
          3: FlexColumnWidth(2.0),
        },
        children: [
          _buildItemsHeaderRow(),
          ...order.items.map((item) {
            return TableRow(
              children: [
                _buildTableValue(
                  salesReturnItemDisplayName(item, _loadedItems),
                ),
                _buildTableValue(item.quantity.toString()),
                _buildTableValueWidget(
                  Builder(
                    builder: (context) {
                      final currency = this.currency;
                      final raw = salesReturnItemUnitPrice(item, _loadedItems);
                      final parsed = double.tryParse(raw);
                      final amount =
                          parsed != null ? parsed.toStringAsFixed(2) : raw;
                      return Text('$currency $amount');
                    },
                  ),
                ),
                _buildTableValue(salesReturnItemReason(item, _loadedItems)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildItemsTableShell(Widget table) {
    return SalesReturnResponsiveTable(minWidth: 560, table: table);
  }

  TableRow _buildItemsHeaderRow() {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      children: [
        _SalesReturnTableHeaderCell('confirmed_orders.product'.tr),
        _SalesReturnTableHeaderCell('billing.table_qty'.tr),
        _SalesReturnTableHeaderCell('sales.price'.tr),
        _SalesReturnTableHeaderCell('sales_return.reason'.tr),
      ],
    );
  }

  Widget _buildTableValue(String value) {
    return _buildTableValueWidget(
      Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildTableValueWidget(Widget child) {
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
