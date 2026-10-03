part of 'purchase_return_list_view.dart';

extension _Section1 on PurchaseReturnListView {
  Widget _buildMobileCard(PurchaseReturnData item) {
    final isCompleted = item.status == 'completed';

    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.reference ?? '#${item.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s14,
                              0.20,
                              ColorManager.textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                              text: item.reference ?? item.id.toString(),
                            ));
                            showScaffold(
                              context: context,
                              message: 'purchase_return.copy_success'.tr,
                            );
                          },
                          child: const Icon(
                            Icons.copy,
                            size: 14,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.supplier?.name ?? '-'} • ${item.returnDate ?? ''}',
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s11,
                        0.15,
                        Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(isCompleted),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMobileMetric(
                  'purchase_return.voucher_number'.tr,
                  item.voucherNumber ?? '-',
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final currency = this.currency;
                    final amount =
                        item.totalAmount?.toStringAsFixed(2) ?? '0.00';
                    return _buildMobileMetric(
                      'purchase_return.total_amount'.tr,
                      '$currency $amount',
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: PurchaseOrdersIconAction(
              icon: Icons.visibility,
              backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.9),
              iconColor: Colors.white,
              tooltip: 'billing.view_details'.tr,
              onPressed: () {
                onView(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMetric(String label, String value) {
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
        const SizedBox(height: 2),
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

  Widget _buildDesktopTable(PurchaseReturnListController provider) {
    return PurchaseOrdersResponsiveTable(
      minWidth: 900,
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
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.2),
                4: FlexColumnWidth(1.3),
                5: FlexColumnWidth(1),
                6: FlexColumnWidth(0.8),
              },
              children: [_buildTableHeader()],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: provider.purchaseReturnsList.length,
              itemBuilder: (context, index) {
                final item = provider.purchaseReturnsList[index];
                return Table(
                  border: TableBorder(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.12),
                    ),
                  ),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(1.2),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1.2),
                    4: FlexColumnWidth(1.3),
                    5: FlexColumnWidth(1),
                    6: FlexColumnWidth(0.8),
                  },
                  children: [_buildTableRow(item, index)],
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
        'purchase_return.reference'.tr,
        'purchase_return.voucher_number'.tr,
        'purchase_return.supplier'.tr,
        'purchase_return.return_date'.tr,
        'purchase_return.total_amount'.tr,
        'purchase_return.status'.tr,
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

  TableRow _buildTableRow(PurchaseReturnData item, int index) {
    final isCompleted = item.status == 'completed';

    return TableRow(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.withOpacity(0.04),
      ),
      children: [
        _tableCell(item.reference ?? '-'),
        _tableCell(item.voucherNumber ?? '-'),
        _tableCell(item.supplier?.name ?? '-'),
        _tableCell(item.returnDate ?? '-'),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Center(
              child: Builder(
                builder: (context) {
                  final currency = this.currency;
                  final amount = item.totalAmount?.toStringAsFixed(2) ?? '0.00';
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
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(14),
            child: Center(child: _buildStatusBadge(isCompleted)),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(8),
            child: Center(
              child: PurchaseOrdersIconAction(
                icon: Icons.visibility,
                backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.9),
                iconColor: Colors.white,
                tooltip: 'billing.view_details'.tr,
                onPressed: () {
                  onView(item);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  TableCell _tableCell(String text) {
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
}
