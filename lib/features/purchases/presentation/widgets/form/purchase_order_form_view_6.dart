part of 'purchase_order_form_view.dart';

extension PurchaseOrderFormViewOperations6 on PurchaseOrderFormView {
  Widget _buildPurchaseListRow(int index, PurchaseOrderItem item) {
    final qty = double.tryParse(item.quantity) ?? 0;
    final purchaseRate = _effectivePurchaseRate(item);
    final retailPrice = _getEffectiveRetailPrice(item);
    final mrp = double.tryParse(item.mrp) ?? 0;
    final wholesalePrice = _getEffectiveWholesalePrice(item);
    final total = _purchaseLineTotal(item);
    final canEdit = !_isReceiveMode || !item.alreadyReceived;
    final canDelete = !_isReceiveMode && !item.alreadyReceived;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          _buildPurchaseListCell(
            "",
            width: 100,
            child: item.alreadyReceived
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F8EC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF43A95D)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'purchase_order.received'.tr,
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s11,
                            0.2,
                            const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  )
                : Checkbox(
                    value: item.receive,
                    onChanged: (value) {
                      setState(() {
                        item.receive = value ?? false;
                        _syncPaidAmount();
                      });
                      _saveDraftToHive();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
          ),
          _buildPurchaseListCell(
            "",
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productData?.productName ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s12,
                    0.2,
                    ColorManager.textColor,
                  ),
                ),
                if (item.variantName != null && item.variantName!.isNotEmpty)
                  Text(
                    item.variantName!.contains(' - ')
                        ? item.variantName!.split(' - ').last
                        : item.variantName!,
                    style: buildCustomStyle(
                      FontWeightManager.regular,
                      FontSize.s10,
                      0.15,
                      Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  item.barcode.isNotEmpty
                      ? item.barcode
                      : (item.productData?.barcode ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s10,
                    0.2,
                    Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 120,
            child: Text(
              item.selectedPurchaseUnit?.unitName ?? item.unit,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.2,
                ColorManager.textColor,
              ),
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 100,
            child: Text(
              qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2),
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.2,
                ColorManager.textColor,
              ),
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 170,
            child: Text(
              purchaseRate.toStringAsFixed(3),
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.2,
                ColorManager.textColor,
              ),
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 170,
            child: Text(
              retailPrice.toStringAsFixed(3),
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.2,
                ColorManager.textColor,
              ),
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 130,
            child: Text(
              mrp.toStringAsFixed(3),
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.2,
                ColorManager.textColor,
              ),
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 190,
            child: Text(
              wholesalePrice.toStringAsFixed(3),
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.2,
                ColorManager.textColor,
              ),
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 120,
            child: Text(
              item.rack.isEmpty ? '-' : item.rack,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.2,
                ColorManager.textColor,
              ),
            ),
          ),
          _buildPurchaseListCell(
            "",
            width: 130,
            child: _buildPurchaseTotalBadge(total),
          ),
          _buildPurchaseListCell(
            "",
            width: 170,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    color: canEdit ? Colors.blueAccent : Colors.grey,
                    size: 18,
                  ),
                  constraints: const BoxConstraints(minWidth: 30),
                  padding: EdgeInsets.zero,
                  onPressed: canEdit ? () => _editItem(index) : null,
                  tooltip: canEdit
                      ? 'purchase_order.edit_item_tooltip'.tr
                      : 'purchase_order.already_received_item_tooltip'.tr,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: canDelete ? Colors.red : Colors.grey,
                    size: 20,
                  ),
                  constraints: const BoxConstraints(minWidth: 30),
                  padding: EdgeInsets.zero,
                  onPressed: canDelete ? () => _removeItem(index) : null,
                  tooltip: canDelete
                      ? 'purchase_order.delete_item_tooltip'.tr
                      : (_isReceiveMode
                          ? 'purchase_order.delete_disabled_receive_mode'.tr
                          : 'purchase_order.already_received_item_tooltip'.tr),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseListCell(
    String title, {
    required double width,
    bool isHeader = false,
    Widget? child,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Center(
          child: child ??
              Text(
                title,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  isHeader
                      ? FontWeightManager.semiBold
                      : FontWeightManager.medium,
                  FontSize.s12,
                  0.2,
                  isHeader
                      ? ColorManager.kPrimaryColor
                      : ColorManager.textColor,
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildPurchaseTotalBadge(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        total.toStringAsFixed(2),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: buildCustomStyle(
          FontWeightManager.bold,
          FontSize.s12,
          0.2,
          Colors.green.shade800,
        ),
      ),
    );
  }

  Widget _buildSupplierBalanceDisplay() {
    final balance = _getSupplierBalance();
    final isToPay = balance > 0;
    final isToReceive = balance < 0;

    final textColor = isToPay
        ? Colors.red
        : isToReceive
            ? Colors.green
            : Colors.grey;

    final label = isToPay
        ? 'purchase_order.amount_to_pay'.tr
        : isToReceive
            ? 'purchase_order.amount_to_receive'.tr
            : 'purchase_order.no_balance'.tr;

    final icon = isToPay
        ? Icons.arrow_upward
        : isToReceive
            ? Icons.arrow_downward
            : Icons.balance;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: textColor),
        const SizedBox(width: 4),
        Text(
          '$label ${balance.abs().toStringAsFixed(2)}',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.27,
            textColor,
          ),
        ),
      ],
    );
  }
}
