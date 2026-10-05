part of 'purchase_order_form_view.dart';

extension PurchaseOrderFormViewOperations7 on PurchaseOrderFormView {
  Widget _buildItemsToReceivePreview() {
    final receivedItems = orderItems
        .where((i) => i.receive && !i.alreadyReceived)
        .toList()
        .reversed
        .toList();
    if (receivedItems.isEmpty) return const SizedBox.shrink();

    double totalAmt = 0;
    double totalQty = 0;

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
            'purchase_order.items_to_receive_preview'.tr,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.27,
              ColorManager.kPrimaryColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        BuildBoxShadowContainer(
          circleRadius: 8,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const baseRowWidth = 1300.0;
              const rowOuterInset = 32.0; // 8 margin + 8 padding on both sides
              final minTableWidth = baseRowWidth + rowOuterInset;
              final tableWidth = constraints.maxWidth > minTableWidth
                  ? constraints.maxWidth
                  : minTableWidth;
              final scale = (tableWidth - rowOuterInset) / baseRowWidth;

              double colWidth(double baseWidth) => baseWidth * scale;

              return ScrollConfiguration(
                behavior: _horizontalDragScrollBehavior,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: ColorManager.kPrimaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              _buildPurchaseListCell(
                                'purchase_order.product_col'.tr,
                                width: colWidth(230),
                                isHeader: true,
                              ),
                              _buildPurchaseListCell(
                                'purchase_order.unit'.tr,
                                width: colWidth(100),
                                isHeader: true,
                              ),
                              _buildPurchaseListCell(
                                'purchase_order.qty_col'.tr,
                                width: colWidth(100),
                                isHeader: true,
                              ),
                              _buildPurchaseListCell(
                                'purchase_order.purchase_price_col'.tr,
                                width: colWidth(170),
                                isHeader: true,
                              ),
                              _buildPurchaseListCell(
                                'purchase_order.retail_price'.tr,
                                width: colWidth(170),
                                isHeader: true,
                              ),
                              _buildPurchaseListCell(
                                'purchase_order.mrp'.tr,
                                width: colWidth(130),
                                isHeader: true,
                              ),
                              _buildPurchaseListCell(
                                'purchase_order.wholesale_price'.tr,
                                width: colWidth(190),
                                isHeader: true,
                              ),
                              _buildPurchaseListCell(
                                'purchase_order.rack'.tr,
                                width: colWidth(100),
                                isHeader: true,
                              ),
                              _buildPurchaseListCell(
                                'purchase_order.total_col_title'.tr,
                                width: colWidth(110),
                                isHeader: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...receivedItems.asMap().entries.map((entry) {
                          final item = entry.value;
                          final qty = double.tryParse(item.quantity) ?? 0;
                          final purchaseRate = _effectivePurchaseRate(item);
                          final retailPrice = _getEffectiveRetailPrice(item);
                          final mrp = double.tryParse(item.mrp) ?? 0;
                          final wholesalePrice =
                              _getEffectiveWholesalePrice(item);
                          final rowTotal = _purchaseLineTotal(item);

                          totalQty += qty;
                          totalAmt += rowTotal;

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: entry.key.isEven
                                  ? Colors.white
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                _buildPurchaseListCell(
                                  "",
                                  width: colWidth(230),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      if (item.variantName != null &&
                                          item.variantName!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.variantName!.contains(' - ')
                                              ? item.variantName!
                                                  .split(' - ')
                                                  .last
                                              : item.variantName!,
                                          style: buildCustomStyle(
                                            FontWeightManager.regular,
                                            FontSize.s10,
                                            0.15,
                                            Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
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
                                  width: colWidth(100),
                                  child: Text(
                                    item.selectedPurchaseUnit?.unitName ??
                                        item.unit,
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
                                  width: colWidth(100),
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
                                  width: colWidth(170),
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
                                  width: colWidth(170),
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
                                  width: colWidth(130),
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
                                  width: colWidth(190),
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
                                  width: colWidth(100),
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
                                  width: colWidth(110),
                                  child: _buildPurchaseTotalBadge(rowTotal),
                                ),
                              ],
                            ),
                          );
                        }),
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              _buildPurchaseListCell(
                                "",
                                width: colWidth(230),
                                child: Text(
                                  'purchase_order.preview_total'.tr,
                                  style: buildCustomStyle(
                                    FontWeightManager.bold,
                                    FontSize.s13,
                                    0.2,
                                    ColorManager.textColor,
                                  ),
                                ),
                              ),
                              _buildPurchaseListCell("", width: colWidth(100)),
                              _buildPurchaseListCell(
                                "",
                                width: colWidth(100),
                                child: Text(
                                  totalQty.toStringAsFixed(
                                    totalQty % 1 == 0 ? 0 : 2,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: buildCustomStyle(
                                    FontWeightManager.bold,
                                    FontSize.s13,
                                    0.2,
                                    ColorManager.textColor,
                                  ),
                                ),
                              ),
                              _buildPurchaseListCell("", width: colWidth(170)),
                              _buildPurchaseListCell("", width: colWidth(170)),
                              _buildPurchaseListCell("", width: colWidth(130)),
                              _buildPurchaseListCell("", width: colWidth(190)),
                              _buildPurchaseListCell("", width: colWidth(100)),
                              _buildPurchaseListCell(
                                "",
                                width: colWidth(110),
                                child: Text(
                                  totalAmt.toStringAsFixed(2),
                                  textAlign: TextAlign.center,
                                  style: buildCustomStyle(
                                    FontWeightManager.bold,
                                    FontSize.s13,
                                    0.2,
                                    ColorManager.textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
}
