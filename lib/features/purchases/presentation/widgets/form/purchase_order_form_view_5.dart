part of 'purchase_order_form_view.dart';

extension PurchaseOrderFormViewOperations5 on PurchaseOrderFormView {
  Widget _buildQtyField(PurchaseOrderItem item) {
    return Row(
      children: [
        InkWell(
          onTap: () {
            double current = double.tryParse(item.qtyCtrl.text) ?? 1;
            if (current > 1) {
              setState(() {
                item.qtyCtrl.text = (current - 1).toString();
                item.quantity = item.qtyCtrl.text;
                _syncPaidAmount();
              });
              _saveDraftToHive();
            }
          },
          child: Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Icon(Icons.remove, size: 14),
          ),
        ),
        const SizedBox(width: 5),
        _buildTableTextField(
          item.qtyCtrl,
          (v) {
            setState(() {
              item.quantity = v;
              _syncPaidAmount();
            });
          },
          width: 60,
          inputFormatters: quantityInputFormattersForUnit(item.unit),
        ),
        const SizedBox(width: 5),
        InkWell(
          onTap: () {
            double current = double.tryParse(item.qtyCtrl.text) ?? 1;
            setState(() {
              item.qtyCtrl.text = (current + 1).toString();
              item.quantity = item.qtyCtrl.text;
              _syncPaidAmount();
            });
            _saveDraftToHive();
          },
          child: Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Icon(Icons.add, size: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildAddedItemsTable() {
    final visibleItems = _isReceiveMode
        ? orderItems.where((i) => !i.alreadyReceived).toList()
        : orderItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: ColorManager.kPrimaryColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ColorManager.kPrimaryColor.withOpacity(0.30),
            ),
          ),
          child: Text(
            'purchase_order.items_added'.tr,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.27,
              ColorManager.kPrimaryColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (visibleItems.isEmpty)
          BuildBoxShadowContainer(
            circleRadius: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 50,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'purchase_order.no_items_added_yet'.tr,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.2,
                        Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          BuildBoxShadowContainer(
            circleRadius: 8,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth >
                        PurchaseOrderFormView._purchaseTableMinWidth
                    ? constraints.maxWidth
                    : PurchaseOrderFormView._purchaseTableMinWidth;

                return ScrollConfiguration(
                  behavior: _horizontalDragScrollBehavior,
                  child: Scrollbar(
                    thumbVisibility: true,
                    trackVisibility: true,
                    controller: _itemsTableScrollController,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _itemsTableScrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      child: SizedBox(
                        width: tableWidth,
                        child: Column(
                          children: [
                            _buildPurchaseListHeader(),
                            const SizedBox(height: 4),
                            ...visibleItems
                                .asMap()
                                .entries
                                .toList()
                                .reversed
                                .map(
                                  (e) => _buildPurchaseListRow(e.key, e.value),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPurchaseListHeader() {
    final unreceivedItems =
        orderItems.where((item) => !item.alreadyReceived).toList();
    final selectAllState = _getSelectAllReceiveState();
    final hasReceivableItems = unreceivedItems.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          _buildPurchaseListCell(
            "",
            width: 100,
            isHeader: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasReceivableItems)
                  Checkbox(
                    value: selectAllState,
                    tristate: true,
                    onChanged: (val) => _toggleSelectAllReceive(val),
                    visualDensity: VisualDensity.compact,
                    activeColor: ColorManager.kPrimaryColor,
                  ),
                Flexible(
                  child: Text(
                    'purchase_order.receive_col'.tr,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s12,
                      0.2,
                      ColorManager.kPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildPurchaseListCell(
            'purchase_order.product_col'.tr,
            width: 220,
            isHeader: true,
          ),
          _buildPurchaseListCell(
            'purchase_order.unit'.tr,
            width: 120,
            isHeader: true,
          ),
          _buildPurchaseListCell(
            'purchase_order.qty_col'.tr,
            width: 100,
            isHeader: true,
          ),
          _buildPurchaseListCell(
            'purchase_order.purchase_price_col'.tr,
            width: 170,
            isHeader: true,
          ),
          _buildPurchaseListCell(
            'purchase_order.retail_price'.tr,
            width: 170,
            isHeader: true,
          ),
          _buildPurchaseListCell(
            'purchase_order.mrp'.tr,
            width: 130,
            isHeader: true,
          ),
          _buildPurchaseListCell(
            'purchase_order.wholesale_price'.tr,
            width: 190,
            isHeader: true,
          ),
          _buildPurchaseListCell(
            'purchase_order.rack'.tr,
            width: 120,
            isHeader: true,
          ),
          _buildPurchaseListCell(
            'purchase_order.total_col_title'.tr,
            width: 130,
            isHeader: true,
          ),
          _buildPurchaseListCell(
            'purchase_order.actions_col'.tr,
            width: 170,
            isHeader: true,
          ),
        ],
      ),
    );
  }
}
