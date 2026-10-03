part of 'purchase_return_form_view.dart';

extension _Section2 on PurchaseReturnFormView {
  Widget _buildReturnForm(bool isPhone) {
    final provider = controller;

    if (controller.isLoadingItems) {
      return const Center(
        child: CircularProgressIndicator(color: ColorManager.kPrimaryColor),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Returnable items section
          PurchaseOrdersSectionTitle(
            title: 'purchase_return.returnable_items'.tr,
          ),
          const SizedBox(height: 10),
          if (controller.itemsLoadError != null)
            PurchaseOrdersContentCard(
              padding: const EdgeInsetsDirectional.all(20),
              child: Column(
                children: [
                  Text(
                    controller.itemsLoadError!,
                    textAlign: TextAlign.center,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s13,
                      0.20,
                      Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CustomRoundButton(
                    title: 'restaurant.retry'.tr,
                    fct: controller.retryLoadReturnableItems,
                    fontSize: 12,
                    height: 40,
                    width: 120,
                  ),
                ],
              ),
            )
          else if (provider.returnableItemsList.isEmpty)
            PurchaseOrdersContentCard(
              padding: const EdgeInsetsDirectional.all(20),
              child: Center(
                child: Text(
                  'purchase_return.no_returnable_items'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s13,
                    0.20,
                    Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else
            ...provider.returnableItemsList.map(_buildReturnableItemCard),

          // Return summary section
          if (controller.returnItems.isNotEmpty) ...[
            const SizedBox(height: 24),
            PurchaseOrdersSectionTitle(
              title: 'purchase_return.return_summary'.tr,
            ),
            const SizedBox(height: 10),
            PurchaseOrdersContentCard(
              padding: const EdgeInsetsDirectional.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Return date picker
                  InkWell(
                    onTap: onPickDate,
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: ColorManager.kPrimaryColor),
                          const SizedBox(width: 10),
                          Text(
                            '${'purchase_return.return_date'.tr}: ${DateFormat('yyyy-MM-dd').format(controller.returnDate)}',
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s13,
                              0.20,
                              ColorManager.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Return items list
                  ...List.generate(controller.returnItems.length, (i) {
                    final item = controller.returnItems[i];
                    return Container(
                      margin: const EdgeInsetsDirectional.only(bottom: 10),
                      padding: const EdgeInsetsDirectional.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.grey.withOpacity(0.12)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.source.productName ?? '-',
                                  style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s13,
                                    0.20,
                                    ColorManager.textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Builder(
                                  builder: (context) {
                                    final currency = this.currency;
                                    return Text(
                                      '${'billing.table_qty'.tr}: ${_formatQty(item.quantity)} • '
                                      '$currency ${item.amount.toStringAsFixed(2)}',
                                      style: buildCustomStyle(
                                        FontWeightManager.regular,
                                        FontSize.s11,
                                        0.15,
                                        Colors.grey.shade600,
                                      ),
                                    );
                                  },
                                ),
                                if (item.reason.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${'purchase_return.reason'.tr}: ${item.reason}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s11,
                                      0.15,
                                      Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: Colors.red.shade400, size: 20),
                            onPressed: () => controller.removeReturnItem(i),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  const SizedBox(height: 8),
                  // Totals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'purchase_return.total_return_qty'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s13,
                          0.20,
                          Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        _formatQty(controller.totalReturnQty),
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.20,
                          ColorManager.textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final currency = this.currency;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'purchase_return.total_return_amount'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s13,
                              0.20,
                              Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            '$currency ${controller.totalReturnAmount.toStringAsFixed(2)}',
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s16,
                              0.22,
                              ColorManager.kPrimaryColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentSection(),
                  const SizedBox(height: 16),
                  CustomRoundButton(
                    title: controller.isSubmitting
                        ? 'purchase_return.submitting'.tr
                        : 'purchase_return.submit_return'.tr,
                    fct: controller.isSubmitting ? () {} : onSubmit,
                    fontSize: 14,
                    height: 48,
                    width: double.infinity,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
