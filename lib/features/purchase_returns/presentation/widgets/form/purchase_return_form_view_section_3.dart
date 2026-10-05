part of 'purchase_return_form_view.dart';

extension _Section3 on PurchaseReturnFormView {
  Widget _buildReturnableItemCard(ReturnableItem item) {
    final alreadyAdded = controller.returnItems
        .any((e) => e.source.purchaseItemId == item.purchaseItemId);
    final displayName = item.variantName != null && item.variantName!.isNotEmpty
        ? '${item.productName ?? ''} (${item.variantName})'
        : item.productName ?? '-';

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 10),
      child: PurchaseOrdersContentCard(
        padding: const EdgeInsetsDirectional.all(14),
        child: Row(
          children: [
            Expanded(
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
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final currency = this.currency;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            '${'purchase_return.purchased'.tr}: ${_formatQty(item.purchasedQuantity)}',
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s11,
                              0.15,
                              Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '${'purchase_return.returned'.tr}: ${_formatQty(item.returnedQuantity)}',
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s11,
                              0.15,
                              Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '${'purchase_return.returnable'.tr}: ${_formatQty(item.returnableQuantity)}',
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s11,
                              0.15,
                              ColorManager.kPrimaryColor,
                            ),
                          ),
                          Text(
                            '$currency ${controller.returnUnitPrice(item).toStringAsFixed(2)}/${'purchase_return.unit'.tr}',
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s11,
                              0.15,
                              Colors.grey.shade600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: alreadyAdded
                      ? Colors.green.shade600
                      : ColorManager.kPrimaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: (item.returnableQuantity ?? 0) > 0
                    ? () => _showReturnItemDialog(item)
                    : null,
                child: Text(
                  alreadyAdded
                      ? 'purchase_return.added'.tr
                      : 'purchase_return.return_btn'.tr,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
