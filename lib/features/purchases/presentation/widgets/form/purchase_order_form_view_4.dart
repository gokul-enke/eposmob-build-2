part of 'purchase_order_form_view.dart';

extension PurchaseOrderFormViewOperations4 on PurchaseOrderFormView {
  Widget _buildTaxDetails() {
    final item = currentItem;
    final retailInclusive =
        (item.calculatedTaxData?['price_including_tax_retail'] as num?)
                ?.toDouble() ??
            0.0;
    final retailExclusive =
        (item.calculatedTaxData?['price_excluding_tax_retail'] as num?)
                ?.toDouble() ??
            0.0;
    final retailTax =
        (item.calculatedTaxData?['retailTaxAmount'] as num?)?.toDouble() ?? 0.0;
    final wholesaleInclusive =
        (item.calculatedTaxData?['price_including_tax_wholesale'] as num?)
                ?.toDouble() ??
            0.0;
    final wholesaleExclusive =
        (item.calculatedTaxData?['price_excluding_tax_wholesale'] as num?)
                ?.toDouble() ??
            0.0;
    final wholesaleTax =
        (item.calculatedTaxData?['wholesaleTaxAmount'] as num?)?.toDouble() ??
            0.0;
    final purchaseInclusive =
        (item.calculatedTaxData?['price_including_tax_purchase'] as num?)
                ?.toDouble() ??
            0.0;
    final purchaseExclusive =
        (item.calculatedTaxData?['price_excluding_tax_purchase'] as num?)
                ?.toDouble() ??
            0.0;
    final purchaseTax =
        (item.calculatedTaxData?['purchaseTaxAmount'] as num?)?.toDouble() ??
            0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 18,
          runSpacing: 8,
          children: [
            _buildTaxSwitch(
              label: 'purchase_order.selling_prices_include_tax'.tr,
              value: includeTax,
              onChanged: _setSellingTaxInclusion,
            ),
            _buildTaxSwitch(
              label: 'purchase_order.purchase_price_includes_tax'.tr,
              value: includeTaxPurchase,
              onChanged: _setPurchaseTaxInclusion,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildTaxCard(
                'purchase_order.retail_price'.tr,
                "1",
                includeTax
                    ? retailInclusive.toStringAsFixed(2)
                    : retailExclusive.toStringAsFixed(2),
                'purchase_order.tax_rate_percent'.tr.replaceAll(
                      '@rate',
                      (item.calculatedTaxData?['tax_rate_retail'] as num?)
                              ?.toDouble()
                              .toStringAsFixed(2) ??
                          "0.00",
                    ),
                'purchase_order.tax_breakdown'
                    .tr
                    .replaceAll('@base', retailExclusive.toStringAsFixed(2))
                    .replaceAll('@tax', retailTax.toStringAsFixed(2)),
                retailTax,
                Colors.blue,
                includeTax,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildTaxCard(
                'purchase_order.wholesale_price'.tr,
                "2",
                includeTax
                    ? wholesaleInclusive.toStringAsFixed(2)
                    : wholesaleExclusive.toStringAsFixed(2),
                'purchase_order.tax_rate_percent'.tr.replaceAll(
                      '@rate',
                      (item.calculatedTaxData?['tax_rate_wholesale'] as num?)
                              ?.toDouble()
                              .toStringAsFixed(2) ??
                          "0.00",
                    ),
                'purchase_order.tax_breakdown'
                    .tr
                    .replaceAll('@base', wholesaleExclusive.toStringAsFixed(2))
                    .replaceAll('@tax', wholesaleTax.toStringAsFixed(2)),
                wholesaleTax,
                Colors.orange,
                includeTax,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _buildTaxCard(
                'purchase_order.purchase_rate'.tr,
                "3",
                includeTaxPurchase
                    ? purchaseInclusive.toStringAsFixed(2)
                    : purchaseExclusive.toStringAsFixed(2),
                'purchase_order.tax_rate_percent'.tr.replaceAll(
                      '@rate',
                      (item.calculatedTaxData?['tax_rate_purchase'] as num?)
                              ?.toDouble()
                              .toStringAsFixed(2) ??
                          '0.00',
                    ),
                'purchase_order.tax_breakdown'
                    .tr
                    .replaceAll('@base', purchaseExclusive.toStringAsFixed(2))
                    .replaceAll('@tax', purchaseTax.toStringAsFixed(2)),
                purchaseTax,
                Colors.green,
                includeTaxPurchase,
                footerTrailingText:
                    'Total: ${_purchaseLineTotal(item).toStringAsFixed(2)}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaxSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s11,
            0.2,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          height: 24,
          child: FittedBox(
            fit: BoxFit.fill,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: ColorManager.kPrimaryColor,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey.shade300,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaxCard(
    String title,
    String badgeText,
    String priceText,
    String taxText,
    String breakdownText,
    double taxAmount,
    Color color,
    bool isIncluding, {
    String? footerTrailingText,
  }) {
    // When tax is NOT included, show price + tax amount in big font
    final displayPrice = !isIncluding
        ? '${priceText} + ${taxAmount.toStringAsFixed(2)}'
        : priceText;

    return Container(
      height: 88,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Badge + Title + Tax%
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    badgeText,
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s10,
                      0.27,
                      Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s12,
                    0.27,
                    color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Main Price + Breakdown in same line
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  displayPrice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s16,
                    0.27,
                    Colors.black,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isIncluding ? '($breakdownText)' : '(${taxText})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s10,
                      0.2,
                      Colors.grey.shade700,
                    ),
                  ),
                ),
                if (footerTrailingText != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: color.withOpacity(0.35)),
                      ),
                      child: Text(
                        footerTrailingText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: buildCustomStyle(
                          FontWeightManager.bold,
                          FontSize.s10,
                          0.27,
                          color,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableTextField(
    TextEditingController controller,
    Function(String) onChanged, {
    double width = 80,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      width: width,
      height: 40, // Changed from 35 to 40 for consistency
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),

      child: Center(
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: inputFormatters,
          onChanged: (value) {
            onChanged(value);
            _saveDraftToHive();
          },
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.2,
            ColorManager.textColor,
          ),
        ),
      ),
    );
  }
}
