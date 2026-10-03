part of 'purchase_return_form_view.dart';

extension _Section0 on PurchaseReturnFormView {
  void _showReturnItemDialog(ReturnableItem item) {
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
    final maxQty = item.returnableQuantity ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          item.productName ?? '-',
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s16,
            0.22,
            ColorManager.textColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'purchase_return.returnable_qty'.tr}: ${_formatQty(maxQty)}',
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.15,
                Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                labelText: 'purchase_return.return_qty'.tr,
                hintText: 'purchase_return.enter_qty'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'purchase_return.reason'.tr,
                hintText: 'purchase_return.enter_reason'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('confirmed_orders.close'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.kPrimaryColor,
            ),
            onPressed: () {
              final qty = double.tryParse(qtyController.text) ?? 0;
              if (qty <= 0) {
                showScaffoldError(
                  context: context,
                  message: 'purchase_return.qty_must_be_positive'.tr,
                );
                return;
              }
              if (qty > maxQty) {
                showScaffoldError(
                  context: context,
                  message:
                      '${'purchase_return.qty_exceeds'.tr} ${_formatQty(maxQty)}',
                );
                return;
              }
              controller.addItem(item, qty, reasonController.text.trim());
              Navigator.pop(ctx);
            },
            child: Text(
              'purchase_return.add_to_return'.tr,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'purchase_return.payment_details'.tr,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s13,
              0.20,
              ColorManager.kPrimaryColor,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'purchase_return.payment_method'.tr,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.2,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 6),
          if (controller.isLoadingPaymentMethods)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ColorManager.kPrimaryColor,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: controller.paymentMethods.map((method) {
                final isSelected =
                    controller.selectedPaymentMethod?.id == method.id;
                return GestureDetector(
                  onTap: () {
                    controller.update(() {
                      if (controller.selectedPaymentMethod?.id == method.id) {
                        controller.selectedPaymentMethod = null;
                      } else {
                        controller.selectedPaymentMethod = method;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ColorManager.kPrimaryColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? ColorManager.kPrimaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      method.description.isNotEmpty
                          ? method.description
                          : method.value,
                      style: buildCustomStyle(
                        FontWeightManager.medium,
                        FontSize.s12,
                        0.15,
                        isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 14),
          Text(
            'purchase_return.return_amount'.tr,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.2,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Builder(
            builder: (context) {
              final currency = this.currency;
              return TextField(
                controller: controller.paidAmountController,
                onChanged: (_) => controller.paidAmountManuallyEdited = true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  prefixText: '$currency ',
                  hintText: '0.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                ),
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s13,
                  0.15,
                  ColorManager.textColor,
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Builder(
            builder: (context) {
              final currency = this.currency;
              return Text(
                '${'purchase_return.max_return_amount'.tr}: $currency ${controller.totalReturnAmount.toStringAsFixed(2)}',
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s11,
                  0.15,
                  Colors.grey.shade500,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherSelection(bool isPhone) {
    final provider = controller;

    if (controller.isLoadingVouchers) {
      return const Center(
        child: CircularProgressIndicator(color: ColorManager.kPrimaryColor),
      );
    }

    if (provider.purchaseOrdersList.isEmpty) {
      return Center(
        child: Text(
          'purchase_order.no_orders_found'.tr,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s14,
            0.25,
            Colors.grey.shade600,
          ),
        ),
      );
    }

    final currentPg = provider.listPurchaseOrderCurrentPage;
    final totalPgs = provider.listPurchaseOrderTotalPages;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsetsDirectional.all(8),
            itemCount: provider.purchaseOrdersList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final voucher = provider.purchaseOrdersList[index];
              return _buildVoucherCard(voucher);
            },
          ),
        ),
        if (totalPgs > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentPg > 1)
                  TextButton(
                    onPressed: () =>
                        controller.loadVouchers(page: currentPg - 1),
                    child: Text('pagination.previous'.tr),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('$currentPg / $totalPgs'),
                ),
                if (currentPg < totalPgs)
                  TextButton(
                    onPressed: () =>
                        controller.loadVouchers(page: currentPg + 1),
                    child: Text('pagination.next'.tr),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
