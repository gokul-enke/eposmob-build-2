part of 'purchase_order_list_view.dart';

extension _PurchaseOrderListView2 on PurchaseOrderListView {
  Widget _buildMobileList({
    required List<PurchaseOrderData> purchases,
    required int startSerial,
    required String currency,
  }) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.all(12),
      itemCount: purchases.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = purchases[index];
        final serialNumber = startSerial + index + 1;
        return _buildMobilePurchaseCard(
          item: item,
          serialNumber: serialNumber,
          currency: currency,
        );
      },
    );
  }

  Widget _buildCompactFieldBox({
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
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
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.bold,
              FontSize.s12,
              0.18,
              ColorManager.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePurchaseCard({
    required PurchaseOrderData item,
    required int serialNumber,
    required String currency,
  }) {
    final canReceive = _canReceiveOrder(item);
    final itemsReceived = _itemsReceivedLabel(item);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.purchaseDate ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s14,
                        0.20,
                        ColorManager.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.supplier?.name ?? '—'} · #$serialNumber',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'purchase_order.view_order_tooltip'.tr,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: BuildBoxShadowContainer(
                        color: ColorManager.kPrimaryColor.withOpacity(0.9),
                        circleRadius: 6,
                        child: IconButton(
                          icon: const Icon(Icons.visibility,
                              size: 14, color: Colors.white),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => onOpen(
                              item, SideBarController.purchaseDetailsIndex),
                        ),
                      ),
                    ),
                  ),
                  if (canReceive) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'purchase_order.receive_items_tooltip'.tr,
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: BuildBoxShadowContainer(
                          color: const Color(0xFFE7F8EC),
                          circleRadius: 6,
                          child: IconButton(
                            icon: const Icon(Icons.add,
                                size: 14, color: Colors.green),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => onOpen(item,
                                SideBarController.createPurchaseOrderIndex),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCompactFieldBox(
                  label: 'purchase_order.store'.tr,
                  value: item.store?.name ?? '—',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCompactFieldBox(
                  label: 'purchase_order.total_price'.tr,
                  value: '$currency ${item.amountTotal ?? '0'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _buildReceivedBadgeWidget(itemsReceived),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable({
    required List<PurchaseOrderData> purchases,
    required int startSerial,
    required String currency,
  }) {
    return PurchaseOrdersResponsiveTable(
      table: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: ColorManager.tableBGColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 2),
                  blurRadius: 2.0,
                ),
              ],
            ),
            child: Table(
              columnWidths: const {
                0: FractionColumnWidth(0.08),
                1: FractionColumnWidth(0.14),
                2: FractionColumnWidth(0.16),
                3: FractionColumnWidth(0.20),
                4: FractionColumnWidth(0.12),
                5: FractionColumnWidth(0.14),
                6: FractionColumnWidth(0.16),
              },
              border: null,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    _buildTableHeader('purchase_order.sl_col'.tr),
                    _buildTableHeader('purchase_order.purchase_date'.tr),
                    _buildTableHeader('purchase_order.store'.tr),
                    _buildTableHeader('purchase_order.supplier'.tr),
                    _buildTableHeader('purchase_order.total_price'.tr),
                    _buildTableHeader('purchase_order.received_items_col'.tr),
                    _buildTableHeader('purchase_order.action_col'.tr),
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
                  0: FractionColumnWidth(0.08),
                  1: FractionColumnWidth(0.14),
                  2: FractionColumnWidth(0.16),
                  3: FractionColumnWidth(0.20),
                  4: FractionColumnWidth(0.12),
                  5: FractionColumnWidth(0.14),
                  6: FractionColumnWidth(0.16),
                },
                border: null,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  ...purchases.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final PurchaseOrderData item = entry.value;
                    final int serialNumber = startSerial + index + 1;
                    final canReceive = _canReceiveOrder(item);

                    return TableRow(
                      decoration: BoxDecoration(
                        color: index % 2 == 0
                            ? Colors.white
                            : Colors.grey.withOpacity(0.1),
                      ),
                      children: [
                        _buildTableCell(serialNumber.toString()),
                        _buildTableCell(item.purchaseDate ?? ""),
                        _buildTableCell(item.store?.name ?? ""),
                        _buildTableCell(item.supplier?.name ?? ""),
                        _buildTableCell("$currency ${item.amountTotal}"),
                        _buildReceivedBadge(_itemsReceivedLabel(item)),
                        _buildActionCell(
                          item: item,
                          canReceive: canReceive,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
