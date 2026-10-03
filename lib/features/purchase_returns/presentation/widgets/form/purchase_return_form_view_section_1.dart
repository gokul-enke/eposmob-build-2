part of 'purchase_return_form_view.dart';

extension _Section1 on PurchaseReturnFormView {
  Widget _buildVoucherCard(PurchaseOrderData voucher) {
    return InkWell(
      onTap: () => controller.onVoucherSelected(voucher),
      borderRadius: BorderRadius.circular(12),
      child: PurchaseOrdersContentCard(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${voucher.voucherNumber ?? voucher.id}',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.20,
                      ColorManager.textColor,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: ColorManager.kPrimaryColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _voucherMetric(
                    'purchase_return.supplier'.tr,
                    voucher.supplier?.name ?? '-',
                  ),
                ),
                Expanded(
                  child: _voucherMetric(
                    'purchase_return.return_date'.tr,
                    voucher.purchaseDate ?? '-',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _voucherMetric(
                    'nav.store'.tr,
                    voucher.store?.name ?? '-',
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final currency = this.currency;
                      return _voucherMetric(
                        'purchase_return.total_amount'.tr,
                        '$currency ${voucher.amountTotal ?? '0'}',
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _voucherMetric(String label, String value) {
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
            FontWeightManager.medium,
            FontSize.s12,
            0.15,
            ColorManager.textColor,
          ),
        ),
      ],
    );
  }

  // ── Step 2: Return Form ───────────────────────────────────────────
}
