part of 'sales_return_list_view.dart';

extension _ListSection2 on SalesReturnListSections {
  Widget _buildDesktopTable(SalesReturnListController salesProvider) {
    return SalesReturnResponsiveTable(
      minWidth: 820,
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
              border: null,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1.5),
                5: FlexColumnWidth(1.5),
              },
              children: [_buildTableHeader()],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: salesProvider.salesReturnOrders.length,
              itemBuilder: (context, index) {
                SalesReturnOrder order = salesProvider.salesReturnOrders[index];
                debugPrint('order.orderId ${order.orderId}');
                return Table(
                  border: TableBorder(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.12),
                    ),
                  ),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const {
                    0: FlexColumnWidth(1.5),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(1),
                    4: FlexColumnWidth(1.5),
                    5: FlexColumnWidth(1.5),
                  },
                  children: [
                    _buildTableRow(order, index + 1),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      children: [
        'sales.order_number_hint'.tr,
        'sales_return.total_quantity'.tr,
        'sales_return.total_return_amount'.tr,
        'sales.status'.tr,
        'sales.date_col'.tr,
        'sales_return.action'.tr,
      ]
          .map((title) => TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(14),
                  child: Center(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s12,
                        0.18,
                        ColorManager.kPrimaryColor,
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  TableRow _buildTableRow(SalesReturnOrder order, int index) {
    int totalQuantity = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity.toInt(),
    );

    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.withOpacity(0.04),
      ),
      children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        order.displayNumber,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.13,
                          Colors.black,
                        ),
                      ),
                      if (order.receiptNumber != null)
                        Text(
                          order.originalOrderNumber,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s10,
                            0.13,
                            Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _copyNumber(order),
                  child: const Icon(
                    Icons.copy,
                    size: 14,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildTableCell(totalQuantity.toString()),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Center(
              child: Builder(
                builder: (context) {
                  final currency = this.currency;
                  final raw = order.totalAmount;
                  final parsed = double.tryParse(raw);
                  final amount =
                      parsed != null ? parsed.toStringAsFixed(2) : raw;
                  return Text(
                    '$currency $amount',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s12,
                      0.13,
                      Colors.black,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        _buildStatusCell(order.status.toString()),
        _buildTableCell(DateHelper.formatISODate(order.createdAt.toString())),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(8),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SalesReturnIconAction(
                    icon: Icons.visibility,
                    backgroundColor:
                        ColorManager.kPrimaryColor.withOpacity(0.9),
                    iconColor: Colors.white,
                    tooltip: 'billing.view_details'.tr,
                    onPressed: () {
                      onView(order);
                    },
                  ),
                  const SizedBox(width: 4),
                  SalesReturnIconAction(
                    icon: Icons.print,
                    backgroundColor: Colors.green.withOpacity(0.9),
                    iconColor: Colors.white,
                    tooltip: 'sales_return.print_bill_tooltip'.tr,
                    onPressed: () {
                      onPrint(order);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  TableCell _buildStatusCell(String text) {
    final bool isCompleted = text == '1' || text == 'true';
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(14),
        child: Center(
          child: SalesReturnStatusBadge(
            label: isCompleted
                ? 'sales_return.status_completed'.tr
                : 'sales_return.status_pending'.tr,
            isCompleted: isCompleted,
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(14),
        child: Center(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.13,
              Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls(SalesReturnListController salesProvider) {
    return PaginationControl(
      currentPage: salesProvider.salesReturnCurrentPage,
      totalPages: salesProvider.salesReturnTotalPages,
      onPageChanged: (int page) {
        _searchSalesReturns(page);
      },
    );
  }
}
